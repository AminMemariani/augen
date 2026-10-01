import Flutter
import ARKit
import RealityKit

/// Face tracking via `ARFaceTrackingConfiguration` (TrueDepth front camera).
///
/// While enabled this feature *replaces* the world-tracking configuration —
/// ARKit runs one camera at a time — so plane detection, image tracking and
/// world-anchored content are suspended until face tracking is disabled (the
/// core resets tracking automatically when the configuration class changes).
///
/// `ARFace` payloads carry world-space landmarks derived from the eye
/// transforms and fixed vertices of ARKit's canonical face mesh, plus the
/// ARKit blend shapes under `expressions` (extra key, ignored by `fromMap`).
/// `minFaceSize`/`maxFaceSize` have no ARKit equivalent and are stored only.
final class AugenFaceTrackingFeature: AugenFeature {
    private weak var host: AugenARView?

    private var enabled = false
    private var detectLandmarks = true
    private var detectExpressions = true
    private var minFaceSize = 0.1
    private var maxFaceSize = 1.0

    private var faces: [String: ARFaceAnchor] = [:]
    private var attachedNodes: [String: (entity: AnchorEntity, faceId: String)] = [:]
    private var lastEmit: TimeInterval = 0

    /// Vertex indices of the canonical ARKit face mesh (topology is fixed for
    /// every ARFaceGeometry), resolved once from the first face seen.
    private var landmarkVertexIndices: [(name: String, index: Int)]?

    init(host: AugenARView) {
        self.host = host
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isFaceTrackingSupported":
            result(ARFaceTrackingConfiguration.isSupported)
        case "setFaceTrackingEnabled":
            let value = args["enabled"] as? Bool ?? false
            if value && !ARFaceTrackingConfiguration.isSupported {
                result(FlutterError(code: "FACE_TRACKING_NOT_SUPPORTED",
                                    message: "Face tracking requires a TrueDepth camera or A12+ chip", details: nil))
                return true
            }
            if enabled != value {
                enabled = value
                if !value { clearFaces(emit: true) }
                host?.applySessionConfiguration()
            }
            result(nil)
        case "isFaceTrackingEnabled":
            result(enabled)
        case "setFaceTrackingConfig":
            detectLandmarks = args["detectLandmarks"] as? Bool ?? detectLandmarks
            detectExpressions = args["detectExpressions"] as? Bool ?? detectExpressions
            minFaceSize = AugenCodec.double(args["minFaceSize"], minFaceSize)
            maxFaceSize = AugenCodec.double(args["maxFaceSize"], maxFaceSize)
            result(nil)
        case "getTrackedFaces":
            result(facePayloads())
        case "getFaceLandmarks":
            guard let faceId = args["faceId"] as? String else {
                result(AugenCodec.invalidArguments("Missing faceId"))
                return true
            }
            guard let face = faces[faceId] else {
                result(FlutterError(code: "FACE_NOT_FOUND", message: "Face \(faceId) is not tracked", details: nil))
                return true
            }
            result(landmarks(for: face))
        case "addNodeToTrackedFace":
            addNode(args, result: result)
        case "removeNodeFromTrackedFace":
            guard let nodeId = args["nodeId"] as? String else {
                result(AugenCodec.invalidArguments("Missing nodeId"))
                return true
            }
            guard detachNode(nodeId) else {
                result(FlutterError(code: "NODE_NOT_FOUND", message: "Node \(nodeId) is not attached to a face", details: nil))
                return true
            }
            result(nil)
        default:
            return false
        }
        return true
    }

    // MARK: - Configuration

    func configure(_ configuration: ARConfiguration) -> ARConfiguration {
        guard enabled, ARFaceTrackingConfiguration.isSupported else { return configuration }
        let face = ARFaceTrackingConfiguration()
        face.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
        face.isLightEstimationEnabled = host?.sessionOptions["lightEstimation"] as? Bool ?? true
        return face
    }

    // MARK: - Session

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let added = anchors.compactMap { $0 as? ARFaceAnchor }
        guard !added.isEmpty else { return }
        added.forEach { faces[$0.identifier.uuidString] = $0 }
        emit(force: true)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let updated = anchors.compactMap { $0 as? ARFaceAnchor }
        guard !updated.isEmpty else { return }
        var stateChanged = false
        for face in updated {
            let id = face.identifier.uuidString
            if faces[id]?.isTracked != face.isTracked { stateChanged = true }
            faces[id] = face
        }
        emit(force: stateChanged)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.compactMap { $0 as? ARFaceAnchor }.map { $0.identifier.uuidString }
        guard !removed.isEmpty else { return }
        for id in removed {
            faces.removeValue(forKey: id)
            for (nodeId, attached) in attachedNodes where attached.faceId == id {
                detachNode(nodeId)
            }
        }
        emit(force: true)
    }

    /// Face anchors update at camera rate (60 Hz); throttle events to ~15 Hz.
    private func emit(force: Bool) {
        let now = Date().timeIntervalSince1970
        guard force || now - lastEmit >= 1.0 / 15.0 else { return }
        lastEmit = now
        host?.sendEvent("onFacesUpdated", facePayloads())
    }

    // MARK: - Payloads

    private func facePayloads() -> [[String: Any]] {
        faces.values.map { face in
            var payload: [String: Any] = [
                "id": face.identifier.uuidString,
                "position": AugenCodec.map(AugenCodec.position(of: face.transform)),
                "rotation": AugenCodec.map(simd_quatf(face.transform)),
                "scale": ["x": 1.0, "y": 1.0, "z": 1.0],
                "trackingState": face.isTracked ? "tracked" : "notTracked",
                "confidence": face.isTracked ? 1.0 : 0.0,
                "landmarks": detectLandmarks ? landmarks(for: face) : [[String: Any]](),
                "lastUpdated": AugenCodec.nowMillis(),
            ]
            if detectExpressions {
                var expressions: [String: Double] = [:]
                for (location, value) in face.blendShapes {
                    expressions[location.rawValue] = value.doubleValue
                }
                payload["expressions"] = expressions
            }
            return payload
        }
    }

    /// World-space landmarks: eyes from ARKit's eye transforms, the rest from
    /// canonical face-mesh vertices.
    private func landmarks(for face: ARFaceAnchor) -> [[String: Any]] {
        let confidence = face.isTracked ? 1.0 : 0.5
        func world(_ local: SIMD3<Float>) -> SIMD3<Float> {
            let p = face.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
            return SIMD3<Float>(p.x, p.y, p.z)
        }
        func entry(_ name: String, _ local: SIMD3<Float>) -> [String: Any] {
            ["name": name, "position": AugenCodec.map(world(local)), "confidence": confidence]
        }

        var result: [[String: Any]] = [
            entry("leftEye", AugenCodec.position(of: face.leftEyeTransform)),
            entry("rightEye", AugenCodec.position(of: face.rightEyeTransform)),
        ]
        let vertices = face.geometry.vertices
        if landmarkVertexIndices == nil { landmarkVertexIndices = Self.resolveLandmarkIndices(vertices) }
        for (name, index) in landmarkVertexIndices ?? [] where index < vertices.count {
            result.append(entry(name, vertices[index]))
        }
        return result
    }

    /// Picks characteristic vertices of the neutral-ish mesh: nose tip is the
    /// most forward (+z) point; chin/forehead are the lowest/highest points on
    /// the facial midline; the mouth is the midline point 45 % of the way from
    /// nose tip to chin; cheeks are the outermost points at nose height.
    private static func resolveLandmarkIndices(_ vertices: [SIMD3<Float>]) -> [(name: String, index: Int)] {
        guard !vertices.isEmpty else { return [] }
        let midline = vertices.indices.filter { abs(vertices[$0].x) < 0.004 }
        let nose = vertices.indices.max { vertices[$0].z < vertices[$1].z } ?? 0
        guard !midline.isEmpty else { return [("noseTip", nose)] }
        let chin = midline.min { vertices[$0].y < vertices[$1].y } ?? nose
        let forehead = midline.max { vertices[$0].y < vertices[$1].y } ?? nose
        let mouthY = vertices[nose].y + (vertices[chin].y - vertices[nose].y) * 0.45
        // Most forward midline vertex near mouth height (the lips' surface).
        let nearMouth = midline.filter { abs(vertices[$0].y - mouthY) < 0.008 }
        let mouth = nearMouth.max { vertices[$0].z < vertices[$1].z }
            ?? midline.min { abs(vertices[$0].y - mouthY) < abs(vertices[$1].y - mouthY) } ?? nose
        let noseBand = vertices.indices.filter { abs(vertices[$0].y - vertices[nose].y) < 0.01 }
        let leftCheek = noseBand.max { vertices[$0].x < vertices[$1].x } ?? nose
        let rightCheek = noseBand.min { vertices[$0].x < vertices[$1].x } ?? nose
        return [
            ("noseTip", nose),
            ("mouth", mouth),
            ("chin", chin),
            ("forehead", forehead),
            ("leftCheek", leftCheek),
            ("rightCheek", rightCheek),
        ]
    }

    // MARK: - Nodes on faces

    private func addNode(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let host = host,
              let nodeId = args["nodeId"] as? String,
              let faceId = args["faceId"] as? String else {
            result(AugenCodec.invalidArguments("Missing nodeId or faceId"))
            return
        }
        guard let face = faces[faceId] else {
            result(FlutterError(code: "FACE_NOT_FOUND", message: "Face \(faceId) is not tracked", details: nil))
            return
        }
        let nodeData = args["node"] as? [String: Any] ?? args["nodeData"] as? [String: Any] ?? [:]
        detachNode(nodeId)
        AugenTrackedAnchorNodes.attach(host: host, nodeId: nodeId, nodeData: nodeData, to: face) { [weak self] entity in
            self?.attachedNodes[nodeId] = (entity, faceId)
            result(nil)
        }
    }

    @discardableResult
    private func detachNode(_ nodeId: String) -> Bool {
        guard let attached = attachedNodes.removeValue(forKey: nodeId) else { return false }
        if let host = host { AugenTrackedAnchorNodes.detach(host: host, nodeId: nodeId, entity: attached.entity) }
        return true
    }

    private func clearFaces(emit: Bool) {
        Array(attachedNodes.keys).forEach { detachNode($0) }
        faces.removeAll()
        if emit { host?.sendEvent("onFacesUpdated", [[String: Any]]()) }
    }

    // MARK: - Lifecycle

    func reset() {
        clearFaces(emit: true)
    }

    func dispose() {
        clearFaces(emit: false)
    }
}
