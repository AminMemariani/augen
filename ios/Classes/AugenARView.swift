import Flutter
import UIKit
import ARKit
import RealityKit
import Combine

class AugenARView: NSObject, FlutterPlatformView {
    private var arView: ARView
    private var methodChannel: FlutterMethodChannel
    private var nodes: [String: AnchorEntity] = [:]
    private var anchors: [String: AnchorEntity] = [:]
    private var detectedPlanes: [ARPlaneAnchor] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: [String: Any],
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        arView = ARView(frame: frame)
        methodChannel = FlutterMethodChannel(
            name: "augen_\(viewId)",
            binaryMessenger: messenger
        )
        
        super.init()
        
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
        
        setupARSession(config: args)
    }
    
    func view() -> UIView {
        return arView
    }
    
    private func setupARSession(config: [String: Any]) {
        // ARSession delegate setup happens during initialization
        arView.session.delegate = self
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "isARSupported":
            isARSupported(result: result)
        case "addNode":
            addNode(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "removeNode":
            removeNode(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "updateNode":
            updateNode(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "hitTest":
            hitTest(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "addAnchor":
            addAnchor(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "removeAnchor":
            removeAnchor(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "pause":
            pause(result: result)
        case "resume":
            resume(result: result)
        case "reset":
            reset(result: result)
        case "playAnimation":
            playAnimation(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "pauseAnimation":
            pauseAnimation(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "stopAnimation":
            stopAnimation(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "resumeAnimation":
            resumeAnimation(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "seekAnimation":
            seekAnimation(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "getAvailableAnimations":
            getAvailableAnimations(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        case "setAnimationSpeed":
            setAnimationSpeed(arguments: call.arguments as? [String: Any] ?? [:], result: result)
        default:
            result(FlutterMethodNotImplemented)
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
        
        let configuration = ARWorldTrackingConfiguration()
        
        // Apply configuration
        let planeDetection = arguments["planeDetection"] as? Bool ?? true
        if planeDetection {
            configuration.planeDetection = [.horizontal, .vertical]
        } else {
            configuration.planeDetection = []
        }
        
        let lightEstimation = arguments["lightEstimation"] as? Bool ?? true
        if #available(iOS 14.0, *) {
            configuration.environmentTexturing = lightEstimation ? .automatic : .none
        }
        
        let depthData = arguments["depthData"] as? Bool ?? false
        if #available(iOS 14.0, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) && depthData {
                configuration.sceneReconstruction = .mesh
            }
        }
        
        let autoFocus = arguments["autoFocus"] as? Bool ?? true
        if autoFocus {
            configuration.isAutoFocusEnabled = true
        }
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        result(nil)
    }
    
    private func isARSupported(result: @escaping FlutterResult) {
        result(ARWorldTrackingConfiguration.isSupported)
    }
    
    private func addNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["id"] as? String,
              let type = arguments["type"] as? String,
              let positionData = arguments["position"] as? [String: Any],
              let rotationData = arguments["rotation"] as? [String: Any],
              let scaleData = arguments["scale"] as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required node parameters",
                details: nil
            ))
            return
        }
        
        let position = SIMD3<Float>(
            x: (positionData["x"] as? NSNumber)?.floatValue ?? 0,
            y: (positionData["y"] as? NSNumber)?.floatValue ?? 0,
            z: (positionData["z"] as? NSNumber)?.floatValue ?? 0
        )
        
        let rotation = simd_quatf(
            ix: (rotationData["x"] as? NSNumber)?.floatValue ?? 0,
            iy: (rotationData["y"] as? NSNumber)?.floatValue ?? 0,
            iz: (rotationData["z"] as? NSNumber)?.floatValue ?? 0,
            r: (rotationData["w"] as? NSNumber)?.floatValue ?? 1
        )
        
        let scale = SIMD3<Float>(
            x: (scaleData["x"] as? NSNumber)?.floatValue ?? 1,
            y: (scaleData["y"] as? NSNumber)?.floatValue ?? 1,
            z: (scaleData["z"] as? NSNumber)?.floatValue ?? 1
        )
        
        let anchor = AnchorEntity(world: position)
        
        // Handle custom 3D model loading
        if type.lowercased() == "model" {
            let modelPath = arguments["modelPath"] as? String
            let modelData = arguments["modelData"] as? FlutterStandardTypedData
            let modelFormat = arguments["modelFormat"] as? String
            
            loadCustomModel(
                modelPath: modelPath,
                modelData: modelData?.data,
                modelFormat: modelFormat,
                scale: scale,
                rotation: rotation,
                anchor: anchor,
                result: result
            )
            
            arView.scene.addAnchor(anchor)
            nodes[nodeId] = anchor
            result(nil)
            return
        }
        
        // Create mesh based on type for primitive shapes
        let mesh: MeshResource
        let material = SimpleMaterial(color: .blue, isMetallic: false)
        
        switch type.lowercased() {
        case "sphere":
            mesh = MeshResource.generateSphere(radius: 0.1)
        case "cube":
            mesh = MeshResource.generateBox(size: 0.1)
        case "cylinder":
            mesh = MeshResource.generateCylinder(height: 0.2, radius: 0.05)
        default:
            mesh = MeshResource.generateSphere(radius: 0.1)
        }
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.scale = scale
        modelEntity.orientation = rotation
        
        anchor.addChild(modelEntity)
        arView.scene.addAnchor(anchor)
        nodes[nodeId] = anchor
        
        result(nil)
    }
    
    private func loadCustomModel(
        modelPath: String?,
        modelData: Data?,
        modelFormat: String?,
        scale: SIMD3<Float>,
        rotation: simd_quatf,
        anchor: AnchorEntity,
        result: @escaping FlutterResult
    ) {
        // Load custom 3D model (USDZ, Reality, or other formats)
        // RealityKit natively supports USDZ and Reality file formats
        //
        // Implementation for loading 3D models:
        // 1. For USDZ files: Use ModelEntity.loadAsync()
        // 2. For GLB/GLTF: Convert to USDZ or use a third-party loader
        // 3. Apply scale and rotation transformations
        //
        // Example implementation for USDZ:
        // if let path = modelPath, let url = URL(string: path) {
        //     ModelEntity.loadAsync(contentsOf: url).sink(
        //         receiveCompletion: { completion in
        //             if case .failure(let error) = completion {
        //                 print("Failed to load model: \(error)")
        //             }
        //         },
        //         receiveValue: { [weak self] model in
        //             model.scale = scale
        //             model.orientation = rotation
        //             anchor.addChild(model)
        //         }
        //     ).store(in: &cancellables)
        // } else if let data = modelData {
        //     // Load from data bytes
        //     // Create temporary file and load from it
        // }
        
        // For now, add a placeholder cube to indicate custom model position
        let mesh = MeshResource.generateBox(size: 0.1)
        let material = SimpleMaterial(color: .orange, isMetallic: false)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.scale = scale
        modelEntity.orientation = rotation
        anchor.addChild(modelEntity)
    }
    
    private func removeNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing nodeId parameter",
                details: nil
            ))
            return
        }
        
        if let anchor = nodes[nodeId] {
            arView.scene.removeAnchor(anchor)
            nodes.removeValue(forKey: nodeId)
            result(nil)
        } else {
            result(FlutterError(
                code: "NODE_NOT_FOUND",
                message: "Node with id \(nodeId) not found",
                details: nil
            ))
        }
    }
    
    private func updateNode(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["id"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing id parameter",
                details: nil
            ))
            return
        }
        
        if nodes[nodeId] != nil {
            // Remove old node and add new one
            removeNode(arguments: ["nodeId": nodeId], result: { _ in })
            addNode(arguments: arguments, result: result)
        } else {
            result(FlutterError(
                code: "NODE_NOT_FOUND",
                message: "Node with id \(nodeId) not found",
                details: nil
            ))
        }
    }
    
    private func hitTest(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let x = arguments["x"] as? NSNumber,
              let y = arguments["y"] as? NSNumber else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing x or y coordinate",
                details: nil
            ))
            return
        }
        
        let point = CGPoint(x: CGFloat(x.doubleValue), y: CGFloat(y.doubleValue))
        let hits = arView.hitTest(point, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
        
        let results = hits.map { hit -> [String: Any] in
            let transform = hit.worldTransform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let rotation = simd_quatf(transform)
            
            return [
                "position": [
                    "x": position.x,
                    "y": position.y,
                    "z": position.z
                ],
                "rotation": [
                    "x": rotation.imag.x,
                    "y": rotation.imag.y,
                    "z": rotation.imag.z,
                    "w": rotation.real
                ],
                "distance": hit.distance,
                "planeId": hit.anchor?.identifier.uuidString ?? NSNull()
            ]
        }
        
        result(results)
    }
    
    private func addAnchor(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let x = arguments["x"] as? NSNumber,
              let y = arguments["y"] as? NSNumber,
              let z = arguments["z"] as? NSNumber else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing position coordinates",
                details: nil
            ))
            return
        }
        
        let position = SIMD3<Float>(
            x: x.floatValue,
            y: y.floatValue,
            z: z.floatValue
        )
        
        let anchor = AnchorEntity(world: position)
        let anchorId = UUID().uuidString
        
        arView.scene.addAnchor(anchor)
        anchors[anchorId] = anchor
        
        let anchorData: [String: Any] = [
            "id": anchorId,
            "position": [
                "x": position.x,
                "y": position.y,
                "z": position.z
            ],
            "rotation": [
                "x": 0,
                "y": 0,
                "z": 0,
                "w": 1
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        
        result(anchorData)
    }
    
    private func removeAnchor(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let anchorId = arguments["anchorId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing anchorId parameter",
                details: nil
            ))
            return
        }
        
        if let anchor = anchors[anchorId] {
            arView.scene.removeAnchor(anchor)
            anchors.removeValue(forKey: anchorId)
            result(nil)
        } else {
            result(FlutterError(
                code: "ANCHOR_NOT_FOUND",
                message: "Anchor with id \(anchorId) not found",
                details: nil
            ))
        }
    }
    
    private func pause(result: @escaping FlutterResult) {
        arView.session.pause()
        result(nil)
    }
    
    private func resume(result: @escaping FlutterResult) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration)
            result(nil)
        } else {
            result(FlutterError(
                code: "NO_CONFIGURATION",
                message: "AR session has no configuration",
                details: nil
            ))
        }
    }
    
    private func reset(result: @escaping FlutterResult) {
        nodes.values.forEach { arView.scene.removeAnchor($0) }
        nodes.removeAll()
        
        anchors.values.forEach { arView.scene.removeAnchor($0) }
        anchors.removeAll()
        
        detectedPlanes.removeAll()
        result(nil)
    }
    
    // MARK: - Animation Methods
    
    private func playAnimation(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        let speed = (arguments["speed"] as? NSNumber)?.floatValue ?? 1.0
        let loopMode = arguments["loopMode"] as? String ?? "loop"
        
        // Implementation for playing animations
        // RealityKit supports animations through AnimationResource
        // Example:
        // if let anchor = nodes[nodeId],
        //    let modelEntity = anchor.children.first as? ModelEntity {
        //     let animation = modelEntity.availableAnimations.first(where: { $0.name == animationId })
        //     if let animation = animation {
        //         let controller = modelEntity.playAnimation(animation.repeat(count: .infinity))
        //         controller.speed = speed
        //     }
        // }
        
        result(nil)
    }
    
    private func pauseAnimation(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        // Pause animation
        result(nil)
    }
    
    private func stopAnimation(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        // Stop animation and reset
        result(nil)
    }
    
    private func resumeAnimation(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        // Resume animation
        result(nil)
    }
    
    private func seekAnimation(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String,
              let time = arguments["time"] as? NSNumber else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        // Seek to time
        result(nil)
    }
    
    private func getAvailableAnimations(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing nodeId parameter",
                details: nil
            ))
            return
        }
        
        // Get available animations from model
        // Example:
        // if let anchor = nodes[nodeId],
        //    let modelEntity = anchor.children.first as? ModelEntity {
        //     let animationNames = modelEntity.availableAnimations.map { $0.name }
        //     result(animationNames)
        // } else {
        //     result([])
        // }
        
        result([])
    }
    
    private func setAnimationSpeed(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let nodeId = arguments["nodeId"] as? String,
              let animationId = arguments["animationId"] as? String,
              let speed = arguments["speed"] as? NSNumber else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required parameters",
                details: nil
            ))
            return
        }
        
        // Set animation speed
        result(nil)
    }
}

// MARK: - ARSessionDelegate
extension AugenARView: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planes.isEmpty {
            detectedPlanes.append(contentsOf: planes)
            notifyPlanesUpdated()
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planes.isEmpty {
            // Update existing planes
            for plane in planes {
                if let index = detectedPlanes.firstIndex(where: { $0.identifier == plane.identifier }) {
                    detectedPlanes[index] = plane
                }
            }
            notifyPlanesUpdated()
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planes.isEmpty {
            for plane in planes {
                detectedPlanes.removeAll { $0.identifier == plane.identifier }
            }
            notifyPlanesUpdated()
        }
    }
    
    private func notifyPlanesUpdated() {
        let planesData = detectedPlanes.map { plane -> [String: Any] in
            let center = plane.center
            let extent = plane.extent
            
            return [
                "id": plane.identifier.uuidString,
                "center": [
                    "x": center.x,
                    "y": center.y,
                    "z": center.z
                ],
                "extent": [
                    "x": extent.x,
                    "y": extent.y,
                    "z": extent.z
                ],
                "type": plane.alignment == .horizontal ? "horizontal" : "vertical"
            ]
        }
        
        methodChannel.invokeMethod("onPlanesUpdated", arguments: planesData)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        methodChannel.invokeMethod("onError", arguments: error.localizedDescription)
    }
}

