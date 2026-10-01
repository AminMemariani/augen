import Flutter
import UIKit
import ARKit
import RealityKit
import Combine

/// Core AR platform view: owns the ARSession, the method channel, plane
/// detection, hit testing and the shared node/anchor registries.
///
/// Every richer capability (animation, physics, image/face tracking, lighting,
/// occlusion, environment probes, cloud anchors, multi-user) lives in its own
/// `AugenFeature` file and is wired in through `features`.
class AugenARView: NSObject, FlutterPlatformView {
    let arView: ARView
    let methodChannel: FlutterMethodChannel
    private let registrar: FlutterPluginRegistrar?

    /// Node id → root anchor of the node's entity hierarchy. The visible
    /// entity is `anchor.children.first` (a `ModelEntity` for primitives, the
    /// loaded entity for custom models). Features (physics, animation,
    /// multi-user, tracked images/faces) look nodes up here.
    var nodes: [String: AnchorEntity] = [:]
    private var anchors: [String: AnchorEntity] = [:]
    private var detectedPlanes: [ARPlaneAnchor] = []

    /// Last options passed to `initialize` (planeDetection, lightEstimation,
    /// depthData, autoFocus). Kept so the session can be rebuilt when a
    /// feature changes its contribution.
    private(set) var sessionOptions: [String: Any] = [:]
    private(set) var isSessionInitialized = false

    private(set) var features: [AugenFeature] = []
    lazy var modelLoader = AugenModelLoader(host: self)

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: [String: Any],
        binaryMessenger messenger: FlutterBinaryMessenger,
        registrar: FlutterPluginRegistrar? = nil
    ) {
        arView = ARView(frame: frame)
        methodChannel = FlutterMethodChannel(name: "augen_\(viewId)", binaryMessenger: messenger)
        self.registrar = registrar
        super.init()

        features = [
            AugenAnimationFeature(host: self),
            AugenPhysicsFeature(host: self),
            AugenImageTrackingFeature(host: self),
            AugenFaceTrackingFeature(host: self),
            AugenLightingFeature(host: self),
            AugenOcclusionFeature(host: self),
            AugenEnvironmentProbeFeature(host: self),
            AugenCloudAnchorFeature(host: self),
            AugenMultiUserFeature(host: self),
        ]

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
        arView.session.delegate = self
    }

    deinit {
        NSLog("AugenARView deinit — releasing AR session and channel")
        methodChannel.setMethodCallHandler(nil)
        features.forEach { $0.dispose() }
        features.removeAll()
        arView.session.delegate = nil
        arView.session.pause()
        nodes.values.forEach { arView.scene.removeAnchor($0) }
        nodes.removeAll()
        anchors.values.forEach { arView.scene.removeAnchor($0) }
        anchors.removeAll()
        detectedPlanes.removeAll()
    }

    func view() -> UIView { arView }

    // MARK: - Host API for features

    /// Send a native → Dart event on the main thread.
    func sendEvent(_ name: String, _ arguments: Any?) {
        if Thread.isMainThread {
            methodChannel.invokeMethod(name, arguments: arguments)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.methodChannel.invokeMethod(name, arguments: arguments)
            }
        }
    }

    /// Rebuild the session configuration from the base options plus every
    /// feature's contribution, and run it. Features call this whenever their
    /// contribution changes (e.g. image tracking toggled, new target added).
    /// No-op until Dart has called `initialize`.
    func applySessionConfiguration(resetTracking: Bool = false) {
        guard isSessionInitialized else { return }
        let previousType = arView.session.configuration.map { type(of: $0) }
        var configuration: ARConfiguration = makeBaseConfiguration()
        for feature in features {
            configuration = feature.configure(configuration)
        }
        // Switching configuration class (world ↔ face) changes the camera, so
        // existing anchors are meaningless — reset tracking in that case.
        let typeChanged = previousType.map { $0 != type(of: configuration) } ?? false
        let options: ARSession.RunOptions =
            (resetTracking || typeChanged) ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(configuration, options: options)
    }

    /// Resolve a Flutter asset key (e.g. `assets/models/robot.usdz`) to a
    /// path inside the app bundle. Returns nil when the key is not an asset.
    func assetPath(forKey key: String) -> String? {
        let lookup = registrar?.lookupKey(forAsset: key) ?? FlutterDartProject.lookupKey(forAsset: key)
        return Bundle.main.path(forResource: lookup, ofType: nil)
    }

    /// The visible entity of a node (child of its anchor), if any.
    func entity(forNode nodeId: String) -> Entity? {
        nodes[nodeId]?.children.first
    }

    private func makeBaseConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        let planeDetection = sessionOptions["planeDetection"] as? Bool ?? true
        configuration.planeDetection = planeDetection ? [.horizontal, .vertical] : []

        let lightEstimation = sessionOptions["lightEstimation"] as? Bool ?? true
        configuration.isLightEstimationEnabled = lightEstimation
        if #available(iOS 14.0, *) {
            configuration.environmentTexturing = lightEstimation ? .automatic : .none
        }

        let depthData = sessionOptions["depthData"] as? Bool ?? false
        if #available(iOS 14.0, *),
           depthData,
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        configuration.isAutoFocusEnabled = sessionOptions["autoFocus"] as? Bool ?? true
        return configuration
    }

    // MARK: - Method dispatch

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        for feature in features where feature.handle(call, result: result) {
            return
        }

        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "initialize": initialize(arguments: args, result: result)
        case "isARSupported": result(ARWorldTrackingConfiguration.isSupported)
        case "addNode": addNode(arguments: args, result: result)
        case "removeNode": removeNode(arguments: args, result: result)
        case "updateNode": updateNode(arguments: args, result: result)
        case "hitTest", "raycast": hitTest(arguments: args, result: result)
        case "addAnchor": addAnchor(arguments: args, result: result)
        case "removeAnchor": removeAnchor(arguments: args, result: result)
        case "pause":
            arView.session.pause()
            result(nil)
        case "resume": resume(result: result)
        case "reset": reset(result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(arguments: [String: Any], result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.isSupported else {
            result(FlutterError(
                code: "AR_NOT_SUPPORTED",
                message: "ARKit is not supported on this device",
                details: nil
            ))
            return
        }
        sessionOptions = arguments
        isSessionInitialized = true
        applySessionConfiguration(resetTracking: true)
        result(nil)
    }

    // MARK: - Nodes

    private func addNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["id"] as? String,
              let type = arguments["type"] as? String else {
            result(AugenCodec.invalidArguments("Missing required node parameters"))
            return
        }

        let position = AugenCodec.vector3(arguments["position"])
        let rotation = AugenCodec.quaternion(arguments["rotation"])
        let scale = AugenCodec.vector3(arguments["scale"], SIMD3<Float>(repeating: 1))

        if let existing = nodes.removeValue(forKey: nodeId) {
            arView.scene.removeAnchor(existing)
        }
        let anchor = AnchorEntity(world: position)
        anchor.name = nodeId
        arView.scene.addAnchor(anchor)
        nodes[nodeId] = anchor

        if type.lowercased() == "model" {
            modelLoader.load(arguments: arguments, into: anchor, scale: scale, rotation: rotation) { error in
                if let error = error {
                    result(FlutterError(code: "MODEL_LOAD_FAILED", message: error, details: nil))
                } else {
                    result(nil)
                }
            }
            return
        }

        let entity = AugenARView.makePrimitive(type: type)
        entity.name = nodeId
        entity.scale = scale
        entity.orientation = rotation
        anchor.addChild(entity)
        result(nil)
    }

    /// Primitive shapes for `sphere`, `cube`, `cylinder` (unknown → sphere).
    static func makePrimitive(type: String) -> ModelEntity {
        let mesh: MeshResource
        switch type.lowercased() {
        case "cube":
            mesh = .generateBox(size: 0.1)
        case "cylinder":
            if #available(iOS 18.0, *) {
                mesh = .generateCylinder(height: 0.2, radius: 0.05)
            } else {
                mesh = .generateBox(size: [0.1, 0.2, 0.1])
            }
        default:
            mesh = .generateSphere(radius: 0.1)
        }
        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    private func removeNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String else {
            result(AugenCodec.invalidArguments("Missing nodeId parameter"))
            return
        }
        guard let anchor = nodes.removeValue(forKey: nodeId) else {
            result(FlutterError(code: "NODE_NOT_FOUND", message: "Node with id \(nodeId) not found", details: nil))
            return
        }
        arView.scene.removeAnchor(anchor)
        result(nil)
    }

    private func updateNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["id"] as? String else {
            result(AugenCodec.invalidArguments("Missing id parameter"))
            return
        }
        guard nodes[nodeId] != nil else {
            result(FlutterError(code: "NODE_NOT_FOUND", message: "Node with id \(nodeId) not found", details: nil))
            return
        }
        addNode(arguments: arguments, result: result)
    }

    // MARK: - Hit testing & anchors

    private func hitTest(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let x = arguments["x"] as? NSNumber, let y = arguments["y"] as? NSNumber else {
            result(AugenCodec.invalidArguments("Missing x or y coordinate"))
            return
        }
        let point = CGPoint(x: x.doubleValue, y: y.doubleValue)
        var results: [[String: Any]] = []
        for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
            let hits = arView.raycast(from: point, allowing: target, alignment: .any)
            results = hits.map { hit in
                let transform = hit.worldTransform
                let cameraPosition = arView.cameraTransform.translation
                return [
                    "position": AugenCodec.map(AugenCodec.position(of: transform)),
                    "rotation": AugenCodec.map(simd_quatf(transform)),
                    "distance": Double(simd_distance(cameraPosition, AugenCodec.position(of: transform))),
                    "planeId": hit.anchor?.identifier.uuidString ?? NSNull(),
                ]
            }
            if !results.isEmpty { break }
        }
        result(results)
    }

    private func addAnchor(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let x = arguments["x"] as? NSNumber,
              let y = arguments["y"] as? NSNumber,
              let z = arguments["z"] as? NSNumber else {
            result(AugenCodec.invalidArguments("Missing position coordinates"))
            return
        }
        let position = SIMD3<Float>(x.floatValue, y.floatValue, z.floatValue)
        let anchor = AnchorEntity(world: position)
        let anchorId = UUID().uuidString
        // Named so features (e.g. cloud anchors) can resolve core anchors by id.
        anchor.name = anchorId
        arView.scene.addAnchor(anchor)
        anchors[anchorId] = anchor
        result([
            "id": anchorId,
            "position": AugenCodec.map(position),
            "rotation": ["x": 0, "y": 0, "z": 0, "w": 1],
            "timestamp": AugenCodec.nowMillis(),
        ])
    }

    private func removeAnchor(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let anchorId = arguments["anchorId"] as? String else {
            result(AugenCodec.invalidArguments("Missing anchorId parameter"))
            return
        }
        guard let anchor = anchors.removeValue(forKey: anchorId) else {
            result(FlutterError(code: "ANCHOR_NOT_FOUND", message: "Anchor with id \(anchorId) not found", details: nil))
            return
        }
        arView.scene.removeAnchor(anchor)
        result(nil)
    }

    // MARK: - Session lifecycle

    private func resume(result: @escaping FlutterResult) {
        guard isSessionInitialized else {
            result(FlutterError(code: "NO_CONFIGURATION", message: "AR session has no configuration", details: nil))
            return
        }
        applySessionConfiguration()
        result(nil)
    }

    private func reset(result: @escaping FlutterResult) {
        nodes.values.forEach { arView.scene.removeAnchor($0) }
        nodes.removeAll()
        anchors.values.forEach { arView.scene.removeAnchor($0) }
        anchors.removeAll()
        detectedPlanes.removeAll()
        features.forEach { $0.reset() }
        result(nil)
    }
}

// MARK: - ARSessionDelegate

extension AugenARView: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        features.forEach { $0.session(session, didUpdate: frame) }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planes.isEmpty {
            detectedPlanes.append(contentsOf: planes)
            notifyPlanesUpdated()
        }
        features.forEach { $0.session(session, didAdd: anchors) }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planes.isEmpty {
            for plane in planes {
                if let index = detectedPlanes.firstIndex(where: { $0.identifier == plane.identifier }) {
                    detectedPlanes[index] = plane
                }
            }
            notifyPlanesUpdated()
        }
        features.forEach { $0.session(session, didUpdate: anchors) }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = Set(anchors.compactMap { ($0 as? ARPlaneAnchor)?.identifier })
        if !removed.isEmpty {
            detectedPlanes.removeAll { removed.contains($0.identifier) }
            notifyPlanesUpdated()
        }
        features.forEach { $0.session(session, didRemove: anchors) }
    }

    private func notifyPlanesUpdated() {
        let planesData = detectedPlanes.map { plane -> [String: Any] in
            [
                "id": plane.identifier.uuidString,
                "center": AugenCodec.map(plane.center),
                "extent": AugenCodec.map(plane.extent),
                "type": plane.alignment == .horizontal ? "horizontal" : "vertical",
            ]
        }
        sendEvent("onPlanesUpdated", planesData)
    }

    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        features.forEach { ($0 as? AugenCollaborationDataReceiver)?.session(session, didOutputCollaborationData: data) }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        sendEvent("onError", error.localizedDescription)
    }
}
