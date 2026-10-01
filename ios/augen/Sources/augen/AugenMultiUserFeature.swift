import Flutter
import ARKit
import RealityKit
import MultipeerConnectivity
import UIKit

/// Receives ARKit collaboration data. `ARSession.CollaborationData` is only
/// delivered through `ARSessionDelegate.session(_:didOutputCollaborationData:)`,
/// which the core view owns; the core forwards it to features adopting this.
protocol AugenCollaborationDataReceiver: AnyObject {
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData)
}

/// Multi-user AR over the local network (no server):
///
/// - Discovery / transport: MultipeerConnectivity (Bonjour service
///   `_augen-ar._tcp`/`_udp`, see the example Info.plist). The host advertises
///   its session id; joiners browse for it and are invited (password checked
///   by the host). Participants, roles, names, shared-object records and app
///   messages travel as small JSON messages.
/// - Shared coordinate space: ARKit collaboration (`isCollaborationEnabled`)
///   — collaboration data is exchanged over the same MCSession, and remote
///   participants' poses come from `ARParticipantAnchor`s.
/// - Entity sync: RealityKit `MultipeerConnectivityService` on
///   `arView.scene.synchronizationService`. Note RealityKit synchronizes every
///   scene entity that has a `SynchronizationComponent` (the default), so
///   `shareObject` is mainly bookkeeping + lock/visibility/ownership control.
///
/// A session can be created with no peers present; the local participant is
/// the host and the only participant until someone joins.
final class AugenMultiUserFeature: NSObject, AugenFeature, AugenCollaborationDataReceiver {
    private weak var host: AugenARView?

    static let serviceType = "augen-ar"
    private static let jsonTag: UInt8 = 1
    private static let collaborationTag: UInt8 = 2

    private let localParticipantId = UUID().uuidString
    private var displayName = UIDevice.current.name
    private var localRole = "host"
    private var isHost = false

    private var peerID: MCPeerID?
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var joinPassword: String?
    private var joinAttempt = 0

    private var session: [String: Any]?
    private var participants: [String: [String: Any]] = [:]
    private var participantOrder: [String] = []
    private var peerToParticipant: [MCPeerID: String] = [:]
    private var arSessionToParticipant: [UUID: String] = [:]
    private var sharedObjects: [String: [String: Any]] = [:]
    private var sharedOrder: [String] = []
    private var config: [String: Any] = [:]
    private var lastLocalPoseUpdate = Date.distantPast

    init(host: AugenARView) {
        self.host = host
        super.init()
    }

    private var isActive: Bool { session != nil }

    // MARK: - Dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isMultiUserSupported":
            result(ARWorldTrackingConfiguration.isSupported)
        case "createMultiUserSession":
            createSession(args, result: result)
        case "joinMultiUserSession":
            joinSession(args, result: result)
        case "leaveMultiUserSession":
            leaveSession(notifyPeers: true, status: "disconnected")
            result(nil)
        case "getMultiUserSession":
            result(sessionMap())
        case "getMultiUserParticipants":
            result(participantList())
        case "setMultiUserConfig":
            for (key, value) in args { config[key] = value }
            if let max = args["maxParticipants"] as? NSNumber { session?["maxParticipants"] = max.intValue }
            if let name = args["displayName"] as? String { renameLocal(name) }
            result(nil)
        case "shareObject":
            shareObject(args, result: result)
        case "unshareObject":
            guard let id = args["objectId"] as? String ?? args["sharedObjectId"] as? String else {
                result(AugenCodec.invalidArguments("Missing objectId")); return true
            }
            guard let record = sharedObjects[id] else {
                result(FlutterError(code: "OBJECT_NOT_FOUND", message: "Shared object \(id) not found", details: nil))
                return true
            }
            guard canModify(record) else {
                result(FlutterError(code: "OBJECT_LOCKED", message: "Shared object is locked by its owner", details: nil))
                return true
            }
            removeSharedObject(id)
            broadcast(["type": "unshare", "id": id])
            result(nil)
        case "updateSharedObject":
            updateSharedObject(args, result: result)
        case "getSharedObjects":
            result(sharedOrder.compactMap { sharedObjects[$0] })
        case "kickParticipant":
            kick(args["participantId"] as? String, result: result)
        case "setParticipantRole":
            guard let id = args["participantId"] as? String, let role = args["role"] as? String,
                  ["host", "participant", "observer"].contains(role) else {
                result(AugenCodec.invalidArguments("Missing participantId or invalid role")); return true
            }
            guard participants[id] != nil else {
                result(FlutterError(code: "PARTICIPANT_NOT_FOUND", message: "Participant \(id) not found", details: nil))
                return true
            }
            applyRole(id, role)
            broadcast(["type": "role", "participantId": id, "role": role])
            result(nil)
        case "updateParticipantDisplayName":
            guard let id = args["participantId"] as? String, let name = args["displayName"] as? String else {
                result(AugenCodec.invalidArguments("Missing participantId or displayName")); return true
            }
            guard participants[id] != nil || id == localParticipantId else {
                result(FlutterError(code: "PARTICIPANT_NOT_FOUND", message: "Participant \(id) not found", details: nil))
                return true
            }
            if id == localParticipantId { renameLocal(name) } else { applyName(id, name) }
            broadcast(["type": "name", "participantId": id, "displayName": name])
            result(nil)
        case "sendMultiUserMessage":
            sendMessage(args, result: result)
        default:
            return false
        }
        return true
    }

    func configure(_ configuration: ARConfiguration) -> ARConfiguration {
        if isActive, let world = configuration as? ARWorldTrackingConfiguration {
            world.isCollaborationEnabled = true
        }
        return configuration
    }

    func reset() {
        // Core cleared every node — drop records whose local node is gone.
        let stale = sharedOrder.filter { id in
            guard let record = sharedObjects[id], let nodeId = record["nodeId"] as? String else { return true }
            return record["ownerId"] as? String == localParticipantId && host?.nodes[nodeId] == nil
        }
        for id in stale {
            removeSharedObject(id, notify: false)
            broadcast(["type": "unshare", "id": id])
        }
        if !stale.isEmpty { notifySharedObjects() }
    }

    func dispose() {
        leaveSession(notifyPeers: true, status: nil)
    }

    // MARK: - Session lifecycle

    private func makeTransport() -> MCSession {
        tearDownTransport()
        // MCPeerID display names are limited to 63 UTF-8 bytes.
        var name = displayName.isEmpty ? "Augen" : displayName
        while name.utf8.count > 63 { name.removeLast() }
        let peer = MCPeerID(displayName: name)
        let mc = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        mc.delegate = self
        peerID = peer
        mcSession = mc
        if let arView = host?.arView {
            arView.scene.synchronizationService = try? MultipeerConnectivityService(session: mc)
        }
        return mc
    }

    private func tearDownTransport() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        host?.arView.scene.synchronizationService = nil
        mcSession?.delegate = nil
        mcSession?.disconnect()
        mcSession = nil
        peerToParticipant.removeAll()
        arSessionToParticipant.removeAll()
    }

    private func createSession(_ args: [String: Any], result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.isSupported else {
            result(FlutterError(code: "MULTI_USER_NOT_SUPPORTED", message: "ARKit world tracking unavailable", details: nil))
            return
        }
        if isActive { leaveSession(notifyPeers: true, status: nil) }

        let sessionId = UUID().uuidString
        let name = args["name"] as? String ?? "Augen Session"
        let now = AugenCodec.nowMillis()
        isHost = true
        localRole = "host"
        session = [
            "id": sessionId,
            "name": name,
            "hostId": localParticipantId,
            "state": "connected",
            "capabilities": (args["capabilities"] as? [String])
                ?? ["spatialSharing", "objectSynchronization", "realTimeCollaboration"],
            "maxParticipants": (args["maxParticipants"] as? NSNumber)?.intValue ?? 8,
            "isPrivate": args["isPrivate"] as? Bool ?? false,
            "password": (args["password"] as? String) ?? NSNull(),
            "createdAt": now,
            "lastActivity": now,
            "metadata": ["transport": "multipeer", "serviceType": Self.serviceType],
        ]
        addLocalParticipant()

        let mc = makeTransport()
        var shortName = name
        while shortName.utf8.count > 100 { shortName.removeLast() }
        let adv = MCNearbyServiceAdvertiser(
            peer: mc.myPeerID,
            discoveryInfo: ["sessionId": sessionId, "name": shortName,
                            "private": (session?["isPrivate"] as? Bool ?? false) ? "1" : "0"],
            serviceType: Self.serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        host?.applySessionConfiguration()
        sendStatus("connected", progress: 1.0, metadata: ["role": "host", "sessionId": sessionId])
        notifySession()
        notifyParticipants()
        notifySharedObjects()
        result(sessionId)
    }

    private func joinSession(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let sessionId = args["sessionId"] as? String, !sessionId.isEmpty else {
            result(AugenCodec.invalidArguments("Missing sessionId")); return
        }
        if isActive { leaveSession(notifyPeers: true, status: nil) }
        if let name = args["displayName"] as? String, !name.isEmpty { displayName = name }
        joinPassword = args["password"] as? String
        isHost = false
        localRole = "participant"
        let now = AugenCodec.nowMillis()
        session = [
            "id": sessionId,
            "name": sessionId,
            "hostId": "",
            "state": "connecting",
            "capabilities": ["spatialSharing", "objectSynchronization", "realTimeCollaboration"],
            "maxParticipants": 8,
            "isPrivate": joinPassword != nil,
            "password": NSNull(),
            "createdAt": now,
            "lastActivity": now,
            "metadata": ["transport": "multipeer", "serviceType": Self.serviceType],
        ]
        addLocalParticipant()

        let mc = makeTransport()
        let br = MCNearbyServiceBrowser(peer: mc.myPeerID, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br

        host?.applySessionConfiguration()
        sendStatus("connecting", progress: 0.1, metadata: ["sessionId": sessionId])
        notifySession()
        notifyParticipants()

        joinAttempt += 1
        let attempt = joinAttempt
        let timeoutSeconds = AugenCodec.double(config["connectionTimeoutMs"], 30000) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            guard let self = self, self.joinAttempt == attempt,
                  self.session?["state"] as? String == "connecting" else { return }
            self.session?["state"] = "failed"
            self.sendStatus("failed", progress: 0, error: "No host found for session \(sessionId) on the local network")
            self.notifySession()
        }
        result(nil)
    }

    private func leaveSession(notifyPeers: Bool, status: String?) {
        guard isActive else { return }
        if notifyPeers { broadcast(["type": "leave", "participantId": localParticipantId]) }
        tearDownTransport()
        joinAttempt += 1
        session = nil
        isHost = false
        participants.removeAll()
        participantOrder.removeAll()
        sharedObjects.removeAll()
        sharedOrder.removeAll()
        host?.applySessionConfiguration()
        if let status = status {
            sendStatus(status, progress: 1.0)
            notifyParticipants()
            notifySharedObjects()
        }
    }

    private func addLocalParticipant() {
        participants.removeAll()
        participantOrder.removeAll()
        let now = AugenCodec.nowMillis()
        var position = SIMD3<Float>.zero
        var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        if let camera = host?.arView.session.currentFrame?.camera.transform {
            position = AugenCodec.position(of: camera)
            rotation = simd_quatf(camera)
        }
        upsertParticipant([
            "id": localParticipantId,
            "displayName": displayName,
            "role": localRole,
            "position": AugenCodec.map(position),
            "rotation": AugenCodec.map(rotation),
            "isActive": true,
            "isHost": isHost,
            "joinedAt": now,
            "lastSeen": now,
            "metadata": ["isLocal": true],
        ])
    }

    // MARK: - Participants

    private func upsertParticipant(_ record: [String: Any]) {
        guard let id = record["id"] as? String else { return }
        if participants[id] == nil { participantOrder.append(id) }
        participants[id] = record
    }

    private func removeParticipant(_ id: String) {
        participants.removeValue(forKey: id)
        participantOrder.removeAll { $0 == id }
        peerToParticipant = peerToParticipant.filter { $0.value != id }
        arSessionToParticipant = arSessionToParticipant.filter { $0.value != id }
    }

    private func applyRole(_ id: String, _ role: String) {
        participants[id]?["role"] = role
        participants[id]?["isHost"] = role == "host"
        if id == localParticipantId {
            localRole = role
            isHost = role == "host"
        }
        if role == "host" { session?["hostId"] = id }
        notifyParticipants()
        notifySession()
    }

    private func applyName(_ id: String, _ name: String) {
        participants[id]?["displayName"] = name
        notifyParticipants()
    }

    private func renameLocal(_ name: String) {
        displayName = name
        if participants[localParticipantId] != nil { applyName(localParticipantId, name) }
    }

    private func kick(_ participantId: String?, result: @escaping FlutterResult) {
        guard let id = participantId else {
            result(AugenCodec.invalidArguments("Missing participantId")); return
        }
        guard isHost else {
            result(FlutterError(code: "NOT_HOST", message: "Only the host can kick participants", details: nil)); return
        }
        guard id != localParticipantId else {
            result(FlutterError(code: "INVALID_TARGET", message: "The host cannot kick itself", details: nil)); return
        }
        guard participants[id] != nil else {
            result(FlutterError(code: "PARTICIPANT_NOT_FOUND", message: "Participant \(id) not found", details: nil)); return
        }
        // MCSession cannot drop a single peer; the kicked peer disconnects
        // itself on receipt, and the host forgets it immediately.
        if let peer = peerToParticipant.first(where: { $0.value == id })?.key {
            send(["type": "kick", "participantId": id], to: [peer])
        }
        removeParticipant(id)
        notifyParticipants()
        notifySession()
        result(nil)
    }

    // MARK: - Shared objects

    private func canModify(_ record: [String: Any]) -> Bool {
        !(record["isLocked"] as? Bool ?? false) || record["ownerId"] as? String == localParticipantId
    }

    private func shareObject(_ args: [String: Any], result: @escaping FlutterResult) {
        guard isActive else {
            result(FlutterError(code: "NO_SESSION", message: "Create or join a multi-user session first", details: nil))
            return
        }
        guard let nodeId = args["nodeId"] as? String, let anchor = host?.nodes[nodeId] else {
            result(FlutterError(code: "NODE_NOT_FOUND", message: "Node not found", details: nil)); return
        }
        if let existing = sharedOrder.first(where: { sharedObjects[$0]?["nodeId"] as? String == nodeId }) {
            result(existing); return
        }
        let isLocked = args["isLocked"] as? Bool ?? false
        let isVisible = args["isVisible"] as? Bool ?? true
        let entity: Entity = anchor.children.first ?? anchor
        entity.isEnabled = isVisible
        setOwnershipMode(anchor, locked: isLocked)

        let now = AugenCodec.nowMillis()
        let id = UUID().uuidString
        let record: [String: Any] = [
            "id": id,
            "nodeId": nodeId,
            "ownerId": localParticipantId,
            "position": AugenCodec.map(entity.position(relativeTo: nil)),
            "rotation": AugenCodec.map(entity.orientation(relativeTo: nil)),
            "scale": AugenCodec.map(entity.scale),
            "isLocked": isLocked,
            "isVisible": isVisible,
            "createdAt": now,
            "lastModified": now,
            "metadata": ["entityName": entity.name],
        ]
        sharedObjects[id] = record
        sharedOrder.append(id)
        broadcast(["type": "share", "object": record])
        notifySharedObjects()
        result(id)
    }

    private func updateSharedObject(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["sharedObjectId"] as? String, var record = sharedObjects[id] else {
            result(FlutterError(code: "OBJECT_NOT_FOUND", message: "Shared object not found", details: nil)); return
        }
        guard canModify(record) else {
            result(FlutterError(code: "OBJECT_LOCKED", message: "Shared object is locked by its owner", details: nil)); return
        }
        if args["position"] is [String: Any] { record["position"] = AugenCodec.map(AugenCodec.vector3(args["position"])) }
        if args["rotation"] is [String: Any] { record["rotation"] = AugenCodec.map(AugenCodec.quaternion(args["rotation"])) }
        if args["scale"] is [String: Any] { record["scale"] = AugenCodec.map(AugenCodec.vector3(args["scale"], SIMD3<Float>(repeating: 1))) }
        if let locked = args["isLocked"] as? Bool { record["isLocked"] = locked }
        if let visible = args["isVisible"] as? Bool { record["isVisible"] = visible }
        record["lastModified"] = AugenCodec.nowMillis()
        sharedObjects[id] = record
        applyToLocalNode(record, changed: args)
        broadcast(["type": "updateObject", "object": record])
        notifySharedObjects()
        result(nil)
    }

    /// Apply a shared-object record to the matching local node (if this
    /// device has it), taking RealityKit ownership so the change syncs.
    private func applyToLocalNode(_ record: [String: Any], changed: [String: Any]) {
        guard let nodeId = record["nodeId"] as? String, let anchor = host?.nodes[nodeId] else { return }
        let entity: Entity = anchor.children.first ?? anchor
        if entity.synchronization?.isOwner == false {
            entity.requestOwnership { _ in }
        }
        if changed["position"] is [String: Any] {
            entity.setPosition(AugenCodec.vector3(record["position"]), relativeTo: nil)
        }
        if changed["rotation"] is [String: Any] {
            entity.setOrientation(AugenCodec.quaternion(record["rotation"]), relativeTo: nil)
        }
        if changed["scale"] is [String: Any] {
            entity.scale = AugenCodec.vector3(record["scale"], SIMD3<Float>(repeating: 1))
        }
        entity.isEnabled = record["isVisible"] as? Bool ?? true
        setOwnershipMode(anchor, locked: record["isLocked"] as? Bool ?? false)
    }

    private func setOwnershipMode(_ root: Entity, locked: Bool) {
        let mode: SynchronizationComponent.OwnershipTransferMode = locked ? .manual : .autoAccept
        var stack: [Entity] = [root]
        while let entity = stack.popLast() {
            entity.synchronization?.ownershipTransferMode = mode
            stack.append(contentsOf: entity.children)
        }
    }

    private func removeSharedObject(_ id: String, notify: Bool = true) {
        sharedObjects.removeValue(forKey: id)
        sharedOrder.removeAll { $0 == id }
        if notify { notifySharedObjects() }
    }

    // MARK: - Messaging

    private func sendMessage(_ args: [String: Any], result: @escaping FlutterResult) {
        guard isActive else {
            result(FlutterError(code: "NO_SESSION", message: "Not in a multi-user session", details: nil)); return
        }
        guard JSONSerialization.isValidJSONObject(args) else {
            result(AugenCodec.invalidArguments("Message must be JSON-encodable")); return
        }
        let message: [String: Any] = ["type": "message", "senderId": localParticipantId, "payload": args]
        let target = args["targetParticipantId"] as? String ?? args["recipientId"] as? String
        if let target = target {
            let peers = peerToParticipant.filter { $0.value == target }.map { $0.key }
            send(message, to: peers)
        } else {
            broadcast(message)
        }
        session?["lastActivity"] = AugenCodec.nowMillis()
        // Delivered to every connected peer (none is fine for a solo session).
        result(nil)
    }

    private func broadcast(_ message: [String: Any]) {
        guard let mc = mcSession, !mc.connectedPeers.isEmpty else { return }
        send(message, to: mc.connectedPeers)
    }

    private func send(_ message: [String: Any], to peers: [MCPeerID], reliable: Bool = true) {
        guard let mc = mcSession, !peers.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: message) else { return }
        var data = Data([Self.jsonTag])
        data.append(json)
        do {
            try mc.send(data, toPeers: peers, with: reliable ? .reliable : .unreliable)
        } catch {
            NSLog("Augen multi-user send failed: \(error.localizedDescription)")
        }
    }

    private func helloMessage() -> [String: Any] {
        var hello: [String: Any] = [
            "type": "hello",
            "participant": participants[localParticipantId] ?? [:],
            "arSessionId": host?.arView.session.identifier.uuidString ?? "",
        ]
        if isHost, var info = session {
            info["password"] = NSNull()
            hello["session"] = info
            hello["participants"] = participantList()
            hello["sharedObjects"] = sharedOrder.compactMap { sharedObjects[$0] }
        }
        return hello
    }

    // MARK: - Incoming

    private func received(_ data: Data, from peer: MCPeerID) {
        guard let tag = data.first else { return }
        let body = data.dropFirst()
        if tag == Self.collaborationTag {
            if let collaboration = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARSession.CollaborationData.self, from: Data(body)) {
                host?.arView.session.update(with: collaboration)
            }
            return
        }
        guard tag == Self.jsonTag,
              let message = (try? JSONSerialization.jsonObject(with: Data(body))) as? [String: Any],
              let type = message["type"] as? String else { return }

        if let pid = peerToParticipant[peer] {
            participants[pid]?["lastSeen"] = AugenCodec.nowMillis()
        }
        session?["lastActivity"] = AugenCodec.nowMillis()

        switch type {
        case "hello":
            guard var participant = message["participant"] as? [String: Any],
                  let pid = participant["id"] as? String else { return }
            participant = normalizeParticipant(participant)
            participant["metadata"] = ["isLocal": false, "peerName": peer.displayName]
            peerToParticipant[peer] = pid
            if let arId = (message["arSessionId"] as? String).flatMap(UUID.init(uuidString:)) {
                arSessionToParticipant[arId] = pid
            }
            upsertParticipant(participant)
            if let info = message["session"] as? [String: Any], !isHost {
                for key in ["id", "name", "hostId", "capabilities", "maxParticipants", "isPrivate", "createdAt"] {
                    if let value = info[key] { session?[key] = value }
                }
                session?["state"] = "connected"
                for other in message["participants"] as? [[String: Any]] ?? [] {
                    guard let oid = other["id"] as? String, oid != localParticipantId, participants[oid] == nil else { continue }
                    upsertParticipant(normalizeParticipant(other))
                }
                for object in message["sharedObjects"] as? [[String: Any]] ?? [] {
                    storeRemoteObject(object)
                }
                notifySharedObjects()
            }
            notifySession()
            notifyParticipants()
        case "leave":
            if let pid = message["participantId"] as? String ?? peerToParticipant[peer] {
                removeParticipant(pid)
                notifyParticipants()
                notifySession()
            }
        case "kick":
            if message["participantId"] as? String == localParticipantId {
                leaveSession(notifyPeers: false, status: "kicked")
            }
        case "role":
            if let pid = message["participantId"] as? String, let role = message["role"] as? String {
                applyRole(pid, role)
            }
        case "name":
            if let pid = message["participantId"] as? String, let name = message["displayName"] as? String {
                if pid == localParticipantId { displayName = name }
                applyName(pid, name)
            }
        case "share", "updateObject":
            if let object = message["object"] as? [String: Any] {
                storeRemoteObject(object)
                if type == "updateObject" { applyToLocalNode(sharedObjects[object["id"] as? String ?? ""] ?? [:], changed: object) }
                notifySharedObjects()
            }
        case "unshare":
            if let id = message["id"] as? String { removeSharedObject(id) }
        case "message":
            sendStatus("messageReceived", progress: 1.0, metadata: [
                "senderId": message["senderId"] ?? peerToParticipant[peer] ?? peer.displayName,
                "payload": message["payload"] ?? [String: Any](),
            ])
        default:
            break
        }
    }

    /// JSON loses the int/double distinction; restore what the Dart models cast.
    private func normalizeParticipant(_ p: [String: Any]) -> [String: Any] {
        var out = p
        out["position"] = AugenCodec.map(AugenCodec.vector3(p["position"]))
        out["rotation"] = AugenCodec.map(AugenCodec.quaternion(p["rotation"]))
        out["joinedAt"] = (p["joinedAt"] as? NSNumber)?.intValue ?? AugenCodec.nowMillis()
        out["lastSeen"] = AugenCodec.nowMillis()
        out["isActive"] = p["isActive"] as? Bool ?? true
        out["isHost"] = p["isHost"] as? Bool ?? false
        out["role"] = p["role"] as? String ?? "participant"
        out["displayName"] = p["displayName"] as? String ?? "Peer"
        if !(p["metadata"] is [String: Any]) { out["metadata"] = [String: Any]() }
        return out
    }

    private func storeRemoteObject(_ object: [String: Any]) {
        guard let id = object["id"] as? String else { return }
        var record = object
        record["position"] = AugenCodec.map(AugenCodec.vector3(object["position"]))
        record["rotation"] = AugenCodec.map(AugenCodec.quaternion(object["rotation"]))
        record["scale"] = AugenCodec.map(AugenCodec.vector3(object["scale"], SIMD3<Float>(repeating: 1)))
        record["createdAt"] = (object["createdAt"] as? NSNumber)?.intValue ?? AugenCodec.nowMillis()
        record["lastModified"] = (object["lastModified"] as? NSNumber)?.intValue ?? AugenCodec.nowMillis()
        if !(object["metadata"] is [String: Any]) { record["metadata"] = [String: Any]() }
        if sharedObjects[id] == nil { sharedOrder.append(id) }
        sharedObjects[id] = record
    }

    private func peerChanged(_ peer: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            send(helloMessage(), to: [peer])
            if !isHost, session?["state"] as? String == "connecting" {
                session?["state"] = "connected"
                browser?.stopBrowsingForPeers()
                sendStatus("connected", progress: 1.0, metadata: ["role": localRole])
            }
            notifySession()
        case .connecting:
            if !isHost { sendStatus("connecting", progress: 0.5) }
        case .notConnected:
            if let pid = peerToParticipant[peer] {
                let wasHost = participants[pid]?["isHost"] as? Bool ?? false
                removeParticipant(pid)
                notifyParticipants()
                if wasHost && !isHost {
                    session?["state"] = "disconnected"
                    sendStatus("disconnected", progress: 0, error: "Host left the session")
                }
                notifySession()
            }
        @unknown default:
            break
        }
    }

    // MARK: - AR session hooks

    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        guard let mc = mcSession, !mc.connectedPeers.isEmpty,
              let encoded = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
        else { return }
        var payload = Data([Self.collaborationTag])
        payload.append(encoded)
        try? mc.send(payload, toPeers: mc.connectedPeers, with: data.priority == .critical ? .reliable : .unreliable)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isActive, Date().timeIntervalSince(lastLocalPoseUpdate) > 0.5 else { return }
        lastLocalPoseUpdate = Date()
        let camera = frame.camera.transform
        participants[localParticipantId]?["position"] = AugenCodec.map(AugenCodec.position(of: camera))
        participants[localParticipantId]?["rotation"] = AugenCodec.map(simd_quatf(camera))
        participants[localParticipantId]?["lastSeen"] = AugenCodec.nowMillis()
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateParticipantAnchors(anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updateParticipantAnchors(anchors)
    }

    private func updateParticipantAnchors(_ anchors: [ARAnchor]) {
        guard isActive else { return }
        for case let anchor as ARParticipantAnchor in anchors {
            guard let arId = anchor.sessionIdentifier, let pid = arSessionToParticipant[arId] else { continue }
            participants[pid]?["position"] = AugenCodec.map(AugenCodec.position(of: anchor.transform))
            participants[pid]?["rotation"] = AugenCodec.map(simd_quatf(anchor.transform))
            participants[pid]?["lastSeen"] = AugenCodec.nowMillis()
        }
    }

    // MARK: - Events

    private func participantList() -> [[String: Any]] {
        participantOrder.compactMap { participants[$0] }
    }

    private func sessionMap() -> [String: Any]? {
        guard var map = session else { return nil }
        map["participants"] = participantList()
        return map
    }

    private func notifySession() {
        if let map = sessionMap() { host?.sendEvent("onMultiUserSessionUpdated", map) }
    }

    private func notifyParticipants() {
        host?.sendEvent("onMultiUserParticipantsUpdated", participantList())
    }

    private func notifySharedObjects() {
        host?.sendEvent("onMultiUserSharedObjectsUpdated", sharedOrder.compactMap { sharedObjects[$0] })
    }

    private func sendStatus(_ status: String, progress: Double, error: String? = nil, metadata: [String: Any] = [:]) {
        host?.sendEvent("onMultiUserSessionStatusUpdated", [
            "status": status,
            "progress": progress,
            "errorMessage": error ?? NSNull(),
            "timestamp": AugenCodec.nowMillis(),
            "metadata": metadata,
        ] as [String: Any])
    }
}

// MARK: - MultipeerConnectivity delegates (callbacks arrive off-main)

extension AugenMultiUserFeature: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, session === self.mcSession else { return }
            self.peerChanged(peerID, state: state)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, session === self.mcSession else { return }
            self.received(data, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension AugenMultiUserFeature: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let mc = self.mcSession, let info = self.session else {
                invitationHandler(false, nil); return
            }
            let maxParticipants = info["maxParticipants"] as? Int ?? 8
            let full = self.participants.count >= maxParticipants
            var passwordOK = true
            if let password = info["password"] as? String, !password.isEmpty {
                passwordOK = context.flatMap { String(data: $0, encoding: .utf8) } == password
            }
            let accept = !full && passwordOK
            if !accept {
                self.sendStatus("invitationRejected", progress: 1.0, metadata: [
                    "peer": peerID.displayName, "reason": full ? "sessionFull" : "wrongPassword",
                ])
            }
            invitationHandler(accept, accept ? mc : nil)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.sendStatus("error", progress: 0, error: "Advertising failed: \(error.localizedDescription)")
        }
    }
}

extension AugenMultiUserFeature: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let mc = self.mcSession, browser === self.browser,
                  let wanted = self.session?["id"] as? String,
                  info?["sessionId"] == wanted else { return }
            if let name = info?["name"] { self.session?["name"] = name }
            let context = self.joinPassword.flatMap { $0.data(using: .utf8) }
            browser.invitePeer(peerID, to: mc, withContext: context, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.sendStatus("error", progress: 0, error: "Browsing failed: \(error.localizedDescription)")
        }
    }
}
