import Flutter
import ARKit
import RealityKit

/// Occlusion of virtual content by the real world.
///
/// - person: `frameSemantics` people segmentation (with depth when the device
///   supports it, A12+) — RealityKit composites people in front of content.
/// - depth: people segmentation with depth plus, on LiDAR devices, the
///   reconstructed scene mesh (`sceneUnderstanding.options.occlusion`).
///   Without LiDAR only people occlude.
/// - plane: invisible `OcclusionMaterial` geometry — automatically on every
///   detected plane while occlusion is enabled (when `enablePlaneOcclusion`),
///   and as explicit occluder quads created via `createOcclusion(type: plane)`.
///
/// Explicit `createOcclusion` records are always reflected in
/// `getOcclusions`; person/depth records additionally switch the matching
/// session semantics on while they are active.
final class AugenOcclusionFeature: AugenFeature {
    private weak var host: AugenARView?

    private var enabled = false
    private var occlusionType = "depth"
    private var confidence = 0.8
    private var enablePerson = true
    private var enablePlane = true
    private var enableDepth = true

    private struct Occlusion {
        let id: String
        let type: String
        var isActive: Bool
        var position: SIMD3<Float>
        var rotation: simd_quatf
        var scale: SIMD3<Float>
        var confidence: Double
        let createdAt: Int
        var lastUpdated: Int
        var metadata: [String: Any]
        var entity: AnchorEntity?
    }

    private var occlusions: [String: Occlusion] = [:]
    private var order: [String] = []
    /// Detected plane id → occluder following that plane, plus its extent.
    private var planeOccluders: [UUID: (anchor: AnchorEntity, model: ModelEntity, extent: SIMD3<Float>)] = [:]

    init(host: AugenARView) {
        self.host = host
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isOcclusionSupported":
            result(Self.supportsPerson || Self.supportsDepthPerson)
        case "getOcclusionCapabilities":
            let person = Self.supportsPerson
            let depth = Self.supportsDepthPerson
            result([
                "supported": person || depth,
                "personOcclusion": person,
                "depthOcclusion": depth,
                "sceneReconstructionOcclusion": Self.supportsSceneMesh,
                "planeOcclusion": ARWorldTrackingConfiguration.isSupported,
                "maxOcclusions": person ? 16 : 0,
            ])
        case "setOcclusionConfig":
            occlusionType = args["type"] as? String ?? occlusionType
            confidence = AugenCodec.double(args["confidence"], confidence)
            enablePerson = args["enablePersonOcclusion"] as? Bool ?? enablePerson
            enablePlane = args["enablePlaneOcclusion"] as? Bool ?? enablePlane
            enableDepth = args["enableDepthOcclusion"] as? Bool ?? enableDepth
            if enabled { apply() }
            result(nil)
        case "setOcclusionEnabled":
            let value = args["enabled"] as? Bool ?? false
            if enabled != value {
                enabled = value
                apply()
            }
            result(nil)
        case "isOcclusionEnabled":
            result(enabled)
        case "createOcclusion":
            createOcclusion(args, result: result)
        case "updateOcclusion":
            updateOcclusion(args, result: result)
        case "removeOcclusion":
            guard let id = args["occlusionId"] as? String else {
                result(AugenCodec.invalidArguments("Missing occlusionId"))
                return true
            }
            guard let removed = occlusions.removeValue(forKey: id) else {
                result(FlutterError(code: "OCCLUSION_NOT_FOUND", message: "Occlusion \(id) not found", details: nil))
                return true
            }
            order.removeAll { $0 == id }
            if let entity = removed.entity { host?.arView.scene.removeAnchor(entity) }
            if removed.type == "person" || removed.type == "depth" { apply() }
            emitOcclusions()
            result(nil)
        case "getOcclusion":
            let id = args["occlusionId"] as? String ?? ""
            result(occlusions[id].map(payload) ?? nil)
        case "getOcclusions":
            result(order.compactMap { occlusions[$0] }.map(payload))
        default:
            return false
        }
        return true
    }

    // MARK: - Capabilities

    private static var supportsPerson: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation)
    }

    private static var supportsDepthPerson: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
    }

    private static var supportsSceneMesh: Bool {
        if #available(iOS 13.4, *) { return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) }
        return false
    }

    // MARK: - Configuration

    private var wantsPerson: Bool {
        (enabled && (enablePerson || enableDepth) && occlusionType != "none")
            || occlusions.values.contains { $0.isActive && ($0.type == "person" || $0.type == "depth") }
    }

    private var wantsSceneDepth: Bool {
        (enabled && enableDepth && occlusionType != "none")
            || occlusions.values.contains { $0.isActive && $0.type == "depth" }
    }

    private var wantsPlanes: Bool { enabled && enablePlane && occlusionType != "none" }

    private func apply() {
        host?.applySessionConfiguration()
        applyRenderOptions(sceneMesh: wantsSceneDepth && Self.supportsSceneMesh)
        if !wantsPlanes { removePlaneOccluders() }
    }

    func configure(_ configuration: ARConfiguration) -> ARConfiguration {
        let configType = type(of: configuration)
        var semantics = configuration.frameSemantics
        semantics.remove(.personSegmentation)
        semantics.remove(.personSegmentationWithDepth)
        if wantsPerson {
            if configType.supportsFrameSemantics(.personSegmentationWithDepth) {
                semantics.insert(.personSegmentationWithDepth)
            } else if configType.supportsFrameSemantics(.personSegmentation) {
                semantics.insert(.personSegmentation)
            }
        }
        configuration.frameSemantics = semantics

        var sceneMesh = false
        if #available(iOS 13.4, *),
           wantsSceneDepth,
           let world = configuration as? ARWorldTrackingConfiguration,
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            world.sceneReconstruction = .mesh
            sceneMesh = true
        }
        applyRenderOptions(sceneMesh: sceneMesh)
        return configuration
    }

    /// Toggle only `.occlusion`, leaving other scene-understanding options
    /// (physics/collision) owned by other features untouched.
    private func applyRenderOptions(sceneMesh: Bool) {
        guard #available(iOS 13.4, *), let arView = host?.arView else { return }
        if sceneMesh {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
        }
    }

    // MARK: - Explicit occlusions

    private func createOcclusion(_ args: [String: Any], result: @escaping FlutterResult) {
        let type = args["type"] as? String ?? "plane"
        guard ["none", "depth", "person", "plane"].contains(type) else {
            result(AugenCodec.invalidArguments("Unknown occlusion type \(type)"))
            return
        }
        let now = AugenCodec.nowMillis()
        let id = "occlusion_\(UUID().uuidString)"
        var occlusion = Occlusion(
            id: id,
            type: type,
            isActive: true,
            position: AugenCodec.vector3(args["position"]),
            rotation: AugenCodec.quaternion(args["rotation"]),
            scale: AugenCodec.vector3(args["scale"], SIMD3<Float>(repeating: 1)),
            confidence: confidence,
            createdAt: now,
            lastUpdated: now,
            metadata: args["metadata"] as? [String: Any] ?? [:],
            entity: nil
        )
        if type == "plane", let host = host {
            // 1 m × 1 m horizontal occluder quad, sized by `scale` (x, z).
            let anchor = AnchorEntity(world: .zero)
            let model = ModelEntity(mesh: .generatePlane(width: 1, depth: 1), materials: [OcclusionMaterial()])
            anchor.addChild(model)
            host.arView.scene.addAnchor(anchor)
            occlusion.entity = anchor
            Self.applyTransform(occlusion)
        }
        occlusions[id] = occlusion
        order.append(id)
        if type == "person" || type == "depth" { apply() }

        var status: [String: Any] = [
            "occlusionId": id,
            "status": "ready",
            "progress": 1.0,
            "timestamp": now,
        ]
        if type == "depth" && !Self.supportsSceneMesh {
            status["metadata"] = ["note": "No LiDAR: depth occlusion limited to people"]
        }
        host?.sendEvent("onOcclusionStatusUpdated", status)
        emitOcclusions()
        result(id)
    }

    private func updateOcclusion(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["occlusionId"] as? String else {
            result(AugenCodec.invalidArguments("Missing occlusionId"))
            return
        }
        guard var occlusion = occlusions[id] else {
            result(FlutterError(code: "OCCLUSION_NOT_FOUND", message: "Occlusion \(id) not found", details: nil))
            return
        }
        if args["position"] != nil { occlusion.position = AugenCodec.vector3(args["position"]) }
        if args["rotation"] != nil { occlusion.rotation = AugenCodec.quaternion(args["rotation"]) }
        if args["scale"] != nil { occlusion.scale = AugenCodec.vector3(args["scale"], SIMD3<Float>(repeating: 1)) }
        if let metadata = args["metadata"] as? [String: Any] { occlusion.metadata = metadata }
        let wasActive = occlusion.isActive
        if let active = args["isActive"] as? Bool { occlusion.isActive = active }
        occlusion.lastUpdated = AugenCodec.nowMillis()
        occlusions[id] = occlusion
        Self.applyTransform(occlusion)
        if wasActive != occlusion.isActive && (occlusion.type == "person" || occlusion.type == "depth") { apply() }
        emitOcclusions()
        result(nil)
    }

    private static func applyTransform(_ occlusion: Occlusion) {
        guard let anchor = occlusion.entity else { return }
        anchor.transform = Transform(scale: occlusion.scale, rotation: occlusion.rotation, translation: occlusion.position)
        anchor.isEnabled = occlusion.isActive
    }

    private func payload(_ occlusion: Occlusion) -> [String: Any] {
        [
            "id": occlusion.id,
            "type": occlusion.type,
            "isActive": occlusion.isActive,
            "position": AugenCodec.map(occlusion.position),
            "rotation": AugenCodec.map(occlusion.rotation),
            "scale": AugenCodec.map(occlusion.scale),
            "confidence": occlusion.confidence,
            "createdAt": occlusion.createdAt,
            "lastUpdated": occlusion.lastUpdated,
            "metadata": occlusion.metadata,
        ]
    }

    private func emitOcclusions() {
        host?.sendEvent("onOcclusionsUpdated", order.compactMap { occlusions[$0] }.map(payload))
    }

    // MARK: - Plane occluders

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard wantsPlanes else { return }
        anchors.compactMap { $0 as? ARPlaneAnchor }.forEach(upsertPlaneOccluder)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard wantsPlanes else { return }
        anchors.compactMap { $0 as? ARPlaneAnchor }.forEach(upsertPlaneOccluder)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for plane in anchors.compactMap({ $0 as? ARPlaneAnchor }) {
            if let occluder = planeOccluders.removeValue(forKey: plane.identifier) {
                host?.arView.scene.removeAnchor(occluder.anchor)
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Planes detected before occlusion was enabled get occluders lazily.
        guard wantsPlanes else { return }
        for anchor in frame.anchors {
            if let plane = anchor as? ARPlaneAnchor, planeOccluders[plane.identifier] == nil {
                upsertPlaneOccluder(plane)
            }
        }
    }

    private func upsertPlaneOccluder(_ plane: ARPlaneAnchor) {
        guard let host = host else { return }
        let extent = plane.extent
        if var existing = planeOccluders[plane.identifier] {
            existing.model.position = plane.center - SIMD3<Float>(0, 0.001, 0)
            // Regenerating the mesh is costly; only when the plane grew/shrank noticeably.
            if simd_length(existing.extent - extent) > 0.05 {
                existing.model.model?.mesh = .generatePlane(width: extent.x, depth: extent.z)
                existing.extent = extent
                planeOccluders[plane.identifier] = existing
            }
            return
        }
        let anchor = AnchorEntity(anchor: plane)
        let model = ModelEntity(mesh: .generatePlane(width: extent.x, depth: extent.z), materials: [OcclusionMaterial()])
        // Sink 1 mm below the plane so content resting on it doesn't z-fight.
        model.position = plane.center - SIMD3<Float>(0, 0.001, 0)
        anchor.addChild(model)
        host.arView.scene.addAnchor(anchor)
        planeOccluders[plane.identifier] = (anchor, model, extent)
    }

    private func removePlaneOccluders() {
        planeOccluders.values.forEach { host?.arView.scene.removeAnchor($0.anchor) }
        planeOccluders.removeAll()
    }

    // MARK: - Lifecycle

    func reset() {
        removePlaneOccluders()
        occlusions.values.compactMap { $0.entity }.forEach { host?.arView.scene.removeAnchor($0) }
        let hadSessionOcclusions = occlusions.values.contains { $0.type == "person" || $0.type == "depth" }
        occlusions.removeAll()
        order.removeAll()
        if hadSessionOcclusions { apply() }
        emitOcclusions()
    }

    func dispose() {
        removePlaneOccluders()
        occlusions.values.compactMap { $0.entity }.forEach { host?.arView.scene.removeAnchor($0) }
        occlusions.removeAll()
        order.removeAll()
    }
}
