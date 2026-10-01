import Flutter
import ARKit
import RealityKit

/// "Cloud" anchors on iOS — LOCAL PERSISTENCE, NO CLOUD BACKEND.
///
/// Augen ships no hosted anchor service for iOS (Google Cloud Anchors /
/// ARCore Geospatial are not bundled). Instead this feature uses ARKit's own
/// persistence primitive, `ARWorldMap`:
///
/// - `createCloudAnchor` adds a named `ARAnchor` at the local anchor's pose,
///   waits until ARKit has mapped enough of the environment
///   (`worldMappingStatus` `.mapped`/`.extending`), then archives the session's
///   `ARWorldMap` (which contains that anchor) to
///   `Application Support/augen/cloud_anchors/<id>.worldmap` + `<id>.json`.
/// - `resolveCloudAnchor` loads that world map into the next session
///   configuration (`initialWorldMap`) and rebuilds the session; the anchor is
///   reported `resolved` once ARKit relocalizes and re-adds it.
/// - `shareCloudAnchor` returns the anchor id as the session id; another app
///   run on the same device (or a device that received the world map file by
///   other means) can `joinCloudAnchorSession` with it. Cross-device sharing
///   without a backend is what the multi-user feature (ARKit collaboration
///   over MultipeerConnectivity) is for.
///
/// Anchors persist across app launches and are listed by `getCloudAnchors`.
final class AugenCloudAnchorFeature: AugenFeature {
    private weak var host: AugenARView?

    private static let anchorNamePrefix = "augen_cloud_"

    private var anchors: [String: [String: Any]] = [:]
    private var order: [String] = []
    private var loadedFromDisk = false

    /// Anchors waiting for a world map snapshot: cloud id → deadline.
    private var pendingCreations: [String: Date] = [:]
    private var captureInFlight = false
    /// Anchors being relocalized: cloud id → deadline.
    private var pendingResolutions: [String: Date] = [:]
    /// World map to inject on the next session rebuild (consumed once).
    private var pendingWorldMap: ARWorldMap?

    private var maxCloudAnchors = 10
    private var timeout: TimeInterval = 30
    private var enableSharing = true
    private var currentSessionId: String?

    init(host: AugenARView) {
        self.host = host
    }

    // MARK: - Dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isCloudAnchorsSupported":
            // World maps need ARWorldTrackingConfiguration (iOS 12+).
            result(ARWorldTrackingConfiguration.isSupported)
            return true
        case "setCloudAnchorConfig":
            maxCloudAnchors = (args["maxCloudAnchors"] as? NSNumber)?.intValue ?? maxCloudAnchors
            if let ms = args["timeoutMs"] as? NSNumber { timeout = max(1, ms.doubleValue / 1000) }
            enableSharing = args["enableSharing"] as? Bool ?? enableSharing
            result(nil)
            return true
        case "createCloudAnchor", "resolveCloudAnchor", "getCloudAnchors", "getCloudAnchor",
             "deleteCloudAnchor", "shareCloudAnchor", "joinCloudAnchorSession", "leaveCloudAnchorSession":
            loadFromDiskIfNeeded()
        default:
            return false
        }

        switch call.method {
        case "createCloudAnchor":
            create(localAnchorId: args["localAnchorId"] as? String, result: result)
        case "resolveCloudAnchor":
            guard let id = args["cloudAnchorId"] as? String else {
                result(AugenCodec.invalidArguments("Missing cloudAnchorId")); return true
            }
            resolve(id, result: result)
        case "getCloudAnchors":
            result(order.compactMap { anchors[$0] })
        case "getCloudAnchor":
            result((args["cloudAnchorId"] as? String).flatMap { anchors[$0] })
        case "deleteCloudAnchor":
            guard let id = args["cloudAnchorId"] as? String else {
                result(AugenCodec.invalidArguments("Missing cloudAnchorId")); return true
            }
            delete(id)
            result(nil)
        case "shareCloudAnchor":
            guard let id = args["cloudAnchorId"] as? String, let record = anchors[id] else {
                result(FlutterError(code: "CLOUD_ANCHOR_NOT_FOUND", message: "Unknown cloud anchor", details: nil))
                return true
            }
            guard enableSharing else {
                result(FlutterError(code: "SHARING_DISABLED", message: "Cloud anchor sharing is disabled", details: nil))
                return true
            }
            guard record["state"] as? String != "creating", record["state"] as? String != "failed" else {
                result(FlutterError(code: "CLOUD_ANCHOR_NOT_READY",
                                    message: "Cloud anchor has no saved world map yet", details: nil))
                return true
            }
            currentSessionId = id
            result(id)
        case "joinCloudAnchorSession":
            guard let sessionId = args["sessionId"] as? String, !sessionId.isEmpty else {
                result(AugenCodec.invalidArguments("Missing sessionId")); return true
            }
            currentSessionId = sessionId
            resolve(sessionId, result: result)
        case "leaveCloudAnchorSession":
            if let id = currentSessionId { pendingResolutions.removeValue(forKey: id) }
            currentSessionId = nil
            result(nil)
        default:
            break
        }
        return true
    }

    func configure(_ configuration: ARConfiguration) -> ARConfiguration {
        if let map = pendingWorldMap, let world = configuration as? ARWorldTrackingConfiguration {
            world.initialWorldMap = map
            pendingWorldMap = nil
        }
        return configuration
    }

    // MARK: - Create

    private func create(localAnchorId: String?, result: @escaping FlutterResult) {
        guard let host = host, let localAnchorId = localAnchorId else {
            result(AugenCodec.invalidArguments("Missing localAnchorId")); return
        }
        guard anchors.count < maxCloudAnchors else {
            result(FlutterError(code: "CLOUD_ANCHOR_LIMIT",
                                message: "Maximum of \(maxCloudAnchors) cloud anchors reached", details: nil))
            return
        }
        guard let transform = transform(forLocalAnchor: localAnchorId) else {
            result(FlutterError(code: "ANCHOR_NOT_FOUND",
                                message: "Local anchor \(localAnchorId) not found", details: nil))
            return
        }

        let cloudId = UUID().uuidString
        let arAnchor = ARAnchor(name: Self.anchorNamePrefix + cloudId, transform: transform)
        host.arView.session.add(anchor: arAnchor)

        let now = AugenCodec.nowMillis()
        anchors[cloudId] = [
            "id": cloudId,
            "localAnchorId": localAnchorId,
            "state": "creating",
            "position": AugenCodec.map(AugenCodec.position(of: transform)),
            "rotation": AugenCodec.map(simd_quatf(transform)),
            "scale": ["x": 1.0, "y": 1.0, "z": 1.0],
            "confidence": 0.0,
            "createdAt": now,
            "lastUpdated": now,
            "expiresAt": NSNull(),
            "isTracked": true,
            "isReliable": false,
        ]
        order.append(cloudId)
        pendingCreations[cloudId] = Date().addingTimeInterval(timeout)
        sendStatus(cloudId, state: "creating", progress: 0.1)
        notifyAnchors()
        result(cloudId)
    }

    /// Pose of a local anchor: core anchors (matched by entity name), nodes,
    /// or a raw ARKit anchor id.
    private func transform(forLocalAnchor id: String) -> simd_float4x4? {
        guard let host = host else { return nil }
        if let entity = host.arView.scene.anchors.first(where: { $0.name == id }) {
            return entity.transformMatrix(relativeTo: nil)
        }
        if let node = host.nodes[id] {
            return node.transformMatrix(relativeTo: nil)
        }
        if let anchor = host.arView.session.currentFrame?.anchors.first(where: { $0.identifier.uuidString == id }) {
            return anchor.transform
        }
        return nil
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = Date()

        for (id, deadline) in pendingResolutions where now > deadline {
            pendingResolutions.removeValue(forKey: id)
            update(id) { $0["state"] = "failed"; $0["isTracked"] = false }
            sendStatus(id, state: "failed", progress: 0,
                       error: "Could not relocalize against the saved world map. Move to where the anchor was created and try again.")
            notifyAnchors()
        }

        guard !pendingCreations.isEmpty, !captureInFlight else { return }
        for (id, deadline) in pendingCreations where now > deadline {
            pendingCreations.removeValue(forKey: id)
            update(id) { $0["state"] = "failed" }
            sendStatus(id, state: "failed", progress: 0,
                       error: "Not enough of the environment was mapped. Move the device around and try again.")
            notifyAnchors()
        }
        guard !pendingCreations.isEmpty else { return }

        switch frame.worldMappingStatus {
        case .mapped, .extending:
            // Only snapshot once ARKit has incorporated the new anchors,
            // otherwise the saved map would not contain them.
            let present = Set(frame.anchors.compactMap { cloudId(of: $0) })
            let ready = pendingCreations.keys.filter { present.contains($0) }
            guard !ready.isEmpty else { return }
            captureWorldMap(session: session, ids: ready,
                            confidence: frame.worldMappingStatus == .mapped ? 1.0 : 0.75)
        case .limited:
            for id in pendingCreations.keys { update(id) { $0["confidence"] = 0.4 } }
        default:
            break
        }
    }

    private func captureWorldMap(session: ARSession, ids: [String], confidence: Double) {
        captureInFlight = true
        session.getCurrentWorldMap { [weak self] map, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.captureInFlight = false
                guard let map = map else {
                    // Keep waiting until the deadline; mapping may improve.
                    NSLog("Augen cloud anchor: world map unavailable: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                for id in ids where self.pendingCreations[id] != nil {
                    self.pendingCreations.removeValue(forKey: id)
                    do {
                        try self.persist(id: id, map: map, confidence: confidence)
                        self.sendStatus(id, state: "created", progress: 1.0)
                    } catch {
                        self.update(id) { $0["state"] = "failed" }
                        self.sendStatus(id, state: "failed", progress: 0, error: error.localizedDescription)
                    }
                }
                self.notifyAnchors()
            }
        }
    }

    // MARK: - Resolve

    private func resolve(_ id: String, result: @escaping FlutterResult) {
        guard let host = host, var record = anchors[id] else {
            result(FlutterError(code: "CLOUD_ANCHOR_NOT_FOUND",
                                message: "No saved world map for \(id) on this device (local persistence only)",
                                details: nil))
            return
        }
        let map: ARWorldMap
        do {
            let data = try Data(contentsOf: Self.directory().appendingPathComponent("\(id).worldmap"))
            guard let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                throw NSError(domain: "augen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Corrupt world map"])
            }
            map = unarchived
        } catch {
            result(FlutterError(code: "CLOUD_ANCHOR_LOAD_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        guard host.isSessionInitialized else {
            result(FlutterError(code: "NO_CONFIGURATION", message: "AR session is not initialized", details: nil))
            return
        }

        record["state"] = "resolving"
        record["isTracked"] = false
        record["lastUpdated"] = AugenCodec.nowMillis()
        anchors[id] = record
        pendingResolutions[id] = Date().addingTimeInterval(max(timeout, 30))
        pendingWorldMap = map
        host.applySessionConfiguration(resetTracking: true)
        sendStatus(id, state: "resolving", progress: 0.2)
        notifyAnchors()
        result(nil)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        handleAnchorUpdates(anchors, added: true)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        handleAnchorUpdates(anchors, added: false)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        var changed = false
        for anchor in anchors {
            guard let id = cloudId(of: anchor), self.anchors[id] != nil else { continue }
            update(id) { $0["isTracked"] = false }
            changed = true
        }
        if changed { notifyAnchors() }
    }

    private func handleAnchorUpdates(_ arAnchors: [ARAnchor], added: Bool) {
        var changed = false
        for anchor in arAnchors {
            guard let id = cloudId(of: anchor), anchors[id] != nil else { continue }
            let wasResolving = pendingResolutions.removeValue(forKey: id) != nil
            update(id) {
                $0["position"] = AugenCodec.map(AugenCodec.position(of: anchor.transform))
                $0["rotation"] = AugenCodec.map(simd_quatf(anchor.transform))
                $0["isTracked"] = true
                if wasResolving {
                    $0["state"] = "resolved"
                    $0["isReliable"] = true
                }
            }
            if wasResolving { sendStatus(id, state: "resolved", progress: 1.0) }
            // Only report pose drift on add/resolve, not every frame.
            changed = changed || added || wasResolving
        }
        if changed { notifyAnchors() }
    }

    private func cloudId(of anchor: ARAnchor) -> String? {
        guard let name = anchor.name, name.hasPrefix(Self.anchorNamePrefix) else { return nil }
        return String(name.dropFirst(Self.anchorNamePrefix.count))
    }

    // MARK: - Delete / reset

    private func delete(_ id: String) {
        pendingCreations.removeValue(forKey: id)
        pendingResolutions.removeValue(forKey: id)
        if let session = host?.arView.session,
           let anchor = session.currentFrame?.anchors.first(where: { cloudId(of: $0) == id }) {
            session.remove(anchor: anchor)
        }
        anchors.removeValue(forKey: id)
        order.removeAll { $0 == id }
        let dir = Self.directory()
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id).worldmap"))
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id).json"))
        notifyAnchors()
    }

    func reset() {
        // Saved world maps survive a scene reset (they are persistent data);
        // only in-flight work is cancelled.
        for id in pendingCreations.keys {
            update(id) { $0["state"] = "failed" }
        }
        pendingCreations.removeAll()
        pendingResolutions.removeAll()
        for id in order { update(id) { $0["isTracked"] = false } }
        if !order.isEmpty { notifyAnchors() }
    }

    func dispose() {
        pendingCreations.removeAll()
        pendingResolutions.removeAll()
        pendingWorldMap = nil
    }

    // MARK: - Persistence

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("augen/cloud_anchors", isDirectory: true)
    }

    private func persist(id: String, map: ARWorldMap, confidence: Double) throws {
        let dir = Self.directory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
        try data.write(to: dir.appendingPathComponent("\(id).worldmap"), options: .atomic)
        update(id) {
            $0["state"] = "created"
            $0["confidence"] = confidence
            $0["isReliable"] = confidence >= 1.0
        }
        if let record = anchors[id] {
            let json = try JSONSerialization.data(withJSONObject: record)
            try json.write(to: dir.appendingPathComponent("\(id).json"), options: .atomic)
        }
    }

    private func loadFromDiskIfNeeded() {
        guard !loadedFromDisk else { return }
        loadedFromDisk = true
        let dir = Self.directory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        var loaded: [[String: Any]] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  var record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = record["id"] as? String,
                  anchors[id] == nil,
                  FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(id).worldmap").path)
            else { continue }
            // Saved in a previous session: map exists but is not tracked yet.
            record["state"] = "created"
            record["isTracked"] = false
            record["expiresAt"] = NSNull()
            // JSON drops the int/double distinction (1.0 → 1); restore Doubles.
            record["position"] = AugenCodec.map(AugenCodec.vector3(record["position"]))
            record["rotation"] = AugenCodec.map(AugenCodec.quaternion(record["rotation"]))
            record["scale"] = AugenCodec.map(AugenCodec.vector3(record["scale"], SIMD3<Float>(repeating: 1)))
            record["confidence"] = AugenCodec.double(record["confidence"])
            loaded.append(record)
        }
        loaded.sort { (($0["createdAt"] as? NSNumber)?.intValue ?? 0) < (($1["createdAt"] as? NSNumber)?.intValue ?? 0) }
        for record in loaded {
            guard let id = record["id"] as? String else { continue }
            anchors[id] = record
            order.append(id)
        }
    }

    // MARK: - Events

    private func update(_ id: String, _ change: (inout [String: Any]) -> Void) {
        guard var record = anchors[id] else { return }
        change(&record)
        record["lastUpdated"] = AugenCodec.nowMillis()
        anchors[id] = record
    }

    private func notifyAnchors() {
        host?.sendEvent("onCloudAnchorsUpdated", order.compactMap { anchors[$0] })
    }

    private func sendStatus(_ id: String, state: String, progress: Double, error: String? = nil) {
        host?.sendEvent("onCloudAnchorStatusUpdated", [
            "cloudAnchorId": id,
            "state": state,
            "progress": progress,
            "errorMessage": error ?? NSNull(),
            "timestamp": AugenCodec.nowMillis(),
        ] as [String: Any])
    }
}
