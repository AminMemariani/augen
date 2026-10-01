import Flutter
import UIKit
import ARKit
import RealityKit

/// Image tracking on ARKit: registered `ARImageTarget`s become
/// `ARReferenceImage`s contributed as `detectionImages` to the world-tracking
/// configuration; detected `ARImageAnchor`s are reported as `ARTrackedImage`s
/// and nodes can be attached to them (they follow the physical image).
///
/// Image sources accepted for `imagePath`: Flutter asset key, absolute file
/// path / `file://` URL, or `http(s)` URL. When a remote image cannot be
/// downloaded, the bundled asset `assets/images/<file name>` is tried as a
/// fallback (the example app references placeholder `example.com` URLs whose
/// files ship in `example/assets/images`). Raw bytes may also be passed under
/// `imageData`.
final class AugenImageTrackingFeature: AugenFeature {
    private weak var host: AugenARView?

    private struct Target {
        let id: String
        let name: String
        let imagePath: String
        let width: Double
        let height: Double
        var isActive: Bool
        let referenceImage: ARReferenceImage
    }

    private var targets: [String: Target] = [:]
    private var targetOrder: [String] = []
    private var enabled = false

    /// Image anchor id → latest anchor.
    private var trackedImages: [String: ARImageAnchor] = [:]
    /// Node id → (anchor entity following the image, image anchor id).
    private var attachedNodes: [String: (entity: AnchorEntity, anchorId: String)] = [:]
    private var lastTrackedEmit: TimeInterval = 0

    init(host: AugenARView) {
        self.host = host
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isImageTrackingSupported":
            result(ARWorldTrackingConfiguration.isSupported)
        case "addImageTarget":
            addImageTarget(args, result: result)
        case "removeImageTarget":
            guard let id = args["targetId"] as? String ?? args["id"] as? String else {
                result(AugenCodec.invalidArguments("Missing targetId"))
                return true
            }
            guard targets.removeValue(forKey: id) != nil else {
                result(FlutterError(code: "TARGET_NOT_FOUND", message: "Image target \(id) not found", details: nil))
                return true
            }
            targetOrder.removeAll { $0 == id }
            // Drop detections of the removed target (ARKit keeps stale anchors).
            let stale = trackedImages.filter { $0.value.referenceImage.name == id }.map { $0.key }
            if !stale.isEmpty {
                stale.forEach { trackedImages.removeValue(forKey: $0) }
                for (nodeId, attached) in attachedNodes where stale.contains(attached.anchorId) {
                    detachNode(nodeId)
                }
                emitTracked(force: true)
            }
            targetsChanged()
            result(nil)
        case "getImageTargets":
            result(targetPayloads())
        case "setImageTrackingEnabled":
            let value = args["enabled"] as? Bool ?? false
            if value && !ARWorldTrackingConfiguration.isSupported {
                result(FlutterError(code: "IMAGE_TRACKING_NOT_SUPPORTED",
                                    message: "Image tracking is not supported on this device", details: nil))
                return true
            }
            if enabled != value {
                enabled = value
                if !value { clearTrackedImages(emit: true) }
                host?.applySessionConfiguration()
            }
            result(nil)
        case "isImageTrackingEnabled":
            result(enabled)
        case "getTrackedImages":
            result(trackedPayloads())
        case "addNodeToTrackedImage":
            addNodeToTrackedImage(args, result: result)
        case "removeNodeFromTrackedImage":
            guard let nodeId = args["nodeId"] as? String else {
                result(AugenCodec.invalidArguments("Missing nodeId"))
                return true
            }
            guard detachNode(nodeId) else {
                result(FlutterError(code: "NODE_NOT_FOUND", message: "Node \(nodeId) is not attached to a tracked image", details: nil))
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
        guard enabled, let world = configuration as? ARWorldTrackingConfiguration else { return configuration }
        let images = Set(targetOrder.compactMap { id -> ARReferenceImage? in
            guard let target = targets[id], target.isActive else { return nil }
            return target.referenceImage
        })
        guard !images.isEmpty else { return configuration }
        world.detectionImages = images
        // Continuous tracking (follows moving images) for a few images at a time.
        world.maximumNumberOfTrackedImages = min(images.count, 4)
        return world
    }

    // MARK: - Targets

    private func addImageTarget(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["id"] as? String else {
            result(AugenCodec.invalidArguments("Missing image target id"))
            return
        }
        let name = args["name"] as? String ?? id
        let imagePath = args["imagePath"] as? String ?? ""
        let size = args["physicalSize"] as? [String: Any] ?? [:]
        let width = AugenCodec.double(size["width"], 0)
        let height = AugenCodec.double(size["height"], 0)
        guard width > 0 else {
            result(AugenCodec.invalidArguments("physicalSize.width must be > 0 (meters)"))
            return
        }
        let isActive = args["isActive"] as? Bool ?? true
        let data = (args["imageData"] as? FlutterStandardTypedData)?.data

        AugenImageTrackingAssets.loadCGImage(path: imagePath, data: data, host: host) { [weak self] cgImage, error in
            guard let self = self else { return }
            guard let cgImage = cgImage else {
                result(FlutterError(code: "IMAGE_LOAD_FAILED",
                                    message: error ?? "Could not load image for target \(id)", details: imagePath))
                return
            }
            let reference = ARReferenceImage(cgImage, orientation: .up, physicalWidth: CGFloat(width))
            reference.name = id
            // An invalid reference image (too few features, too small) makes
            // the whole session fail, so validate before contributing it.
            reference.validate { validationError in
                DispatchQueue.main.async {
                    if let validationError = validationError {
                        result(FlutterError(code: "INVALID_IMAGE_TARGET",
                                            message: validationError.localizedDescription, details: id))
                        return
                    }
                    let measuredHeight = height > 0 ? height : width * Double(cgImage.height) / Double(max(cgImage.width, 1))
                    if self.targets[id] == nil { self.targetOrder.append(id) }
                    self.targets[id] = Target(id: id, name: name, imagePath: imagePath, width: width,
                                              height: measuredHeight, isActive: isActive, referenceImage: reference)
                    self.targetsChanged()
                    result(nil)
                }
            }
        }
    }

    private func targetsChanged() {
        host?.sendEvent("onImageTargetsUpdated", targetPayloads())
        if enabled { host?.applySessionConfiguration() }
    }

    private func targetPayloads() -> [[String: Any]] {
        targetOrder.compactMap { targets[$0] }.map { target in
            [
                "id": target.id,
                "name": target.name,
                "imagePath": target.imagePath,
                "physicalSize": ["width": target.width, "height": target.height],
                "isActive": target.isActive,
            ]
        }
    }

    // MARK: - Tracked images

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let images = anchors.compactMap { $0 as? ARImageAnchor }
        guard enabled, !images.isEmpty else { return }
        images.forEach { trackedImages[$0.identifier.uuidString] = $0 }
        emitTracked(force: true)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let images = anchors.compactMap { $0 as? ARImageAnchor }
        guard enabled, !images.isEmpty else { return }
        var trackingChanged = false
        for image in images {
            let id = image.identifier.uuidString
            if trackedImages[id]?.isTracked != image.isTracked { trackingChanged = true }
            trackedImages[id] = image
        }
        emitTracked(force: trackingChanged)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = anchors.compactMap { $0 as? ARImageAnchor }.map { $0.identifier.uuidString }
        guard !removed.isEmpty else { return }
        for id in removed {
            trackedImages.removeValue(forKey: id)
            for (nodeId, attached) in attachedNodes where attached.anchorId == id {
                detachNode(nodeId)
            }
        }
        emitTracked(force: true)
    }

    /// Image anchors update every frame; throttle to ~10 Hz unless the
    /// tracked set or tracking state changed.
    private func emitTracked(force: Bool) {
        let now = Date().timeIntervalSince1970
        guard force || now - lastTrackedEmit >= 0.1 else { return }
        lastTrackedEmit = now
        host?.sendEvent("onTrackedImagesUpdated", trackedPayloads())
    }

    private func trackedPayloads() -> [[String: Any]] {
        trackedImages.values.map { anchor in
            var scale = 1.0
            if #available(iOS 13.0, *) { scale = Double(anchor.estimatedScaleFactor) }
            let size = anchor.referenceImage.physicalSize
            return [
                "id": anchor.identifier.uuidString,
                "targetId": anchor.referenceImage.name ?? "",
                "position": AugenCodec.map(AugenCodec.position(of: anchor.transform)),
                "rotation": AugenCodec.map(simd_quatf(anchor.transform)),
                "estimatedSize": ["width": Double(size.width) * scale, "height": Double(size.height) * scale],
                "trackingState": anchor.isTracked ? "tracked" : "notTracked",
                "confidence": anchor.isTracked ? 1.0 : 0.0,
                "lastUpdated": AugenCodec.nowMillis(),
            ]
        }
    }

    private func clearTrackedImages(emit: Bool) {
        Array(attachedNodes.keys).forEach { detachNode($0) }
        trackedImages.removeAll()
        if emit { host?.sendEvent("onTrackedImagesUpdated", [[String: Any]]()) }
    }

    // MARK: - Nodes on tracked images

    private func addNodeToTrackedImage(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let host = host,
              let nodeId = args["nodeId"] as? String,
              let nodeData = args["nodeData"] as? [String: Any] else {
            result(AugenCodec.invalidArguments("Missing nodeId or nodeData"))
            return
        }
        let trackedId = nodeData["trackedImageId"] as? String ?? args["trackedImageId"] as? String ?? ""
        // Accept either the tracked image (anchor) id or the target id.
        guard let anchor = trackedImages[trackedId]
            ?? trackedImages.values.first(where: { $0.referenceImage.name == trackedId }) else {
            result(FlutterError(code: "TRACKED_IMAGE_NOT_FOUND",
                                message: "Tracked image \(trackedId) is not currently detected", details: nil))
            return
        }
        detachNode(nodeId)
        let anchorId = anchor.identifier.uuidString
        AugenTrackedAnchorNodes.attach(host: host, nodeId: nodeId, nodeData: nodeData, to: anchor) { [weak self] entity in
            self?.attachedNodes[nodeId] = (entity, anchorId)
            result(nil)
        }
    }

    @discardableResult
    private func detachNode(_ nodeId: String) -> Bool {
        guard let attached = attachedNodes.removeValue(forKey: nodeId) else { return false }
        if let host = host { AugenTrackedAnchorNodes.detach(host: host, nodeId: nodeId, entity: attached.entity) }
        return true
    }

    // MARK: - Lifecycle

    func reset() {
        clearTrackedImages(emit: true)
    }

    func dispose() {
        clearTrackedImages(emit: false)
        targets.removeAll()
        targetOrder.removeAll()
    }
}

// MARK: - Shared helpers (also used by face tracking / environment map)

/// Resolves image sources (asset key, file path, URL, raw bytes) to a CGImage.
enum AugenImageTrackingAssets {
    /// `completion` is always called on the main thread.
    static func loadCGImage(
        path: String,
        data: Data?,
        host: AugenARView?,
        completion: @escaping (CGImage?, String?) -> Void
    ) {
        let finish: (CGImage?, String?) -> Void = { image, error in
            if Thread.isMainThread { completion(image, error) } else {
                DispatchQueue.main.async { completion(image, error) }
            }
        }
        if let data = data, let image = UIImage(data: data)?.cgImage {
            finish(image, nil)
            return
        }
        let fallbackAsset = "assets/images/" + (path as NSString).lastPathComponent
        let localPaths: (String) -> [String] = { key in
            var paths: [String] = []
            if key.hasPrefix("file://"), let url = URL(string: key) { paths.append(url.path) }
            if key.hasPrefix("/") { paths.append(key) }
            if let asset = host?.assetPath(forKey: key) { paths.append(asset) }
            return paths
        }
        let fromDisk: ([String]) -> CGImage? = { paths in
            for candidate in paths where FileManager.default.fileExists(atPath: candidate) {
                if let image = UIImage(contentsOfFile: candidate)?.cgImage { return image }
            }
            return nil
        }

        if path.hasPrefix("http://") || path.hasPrefix("https://"), let url = URL(string: path) {
            // Resolve the bundled fallback up front (asset lookup touches Flutter APIs on main).
            let fallbackPaths = localPaths(fallbackAsset)
            URLSession.shared.dataTask(with: url) { data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                if let data = data, (200..<300).contains(status), let image = UIImage(data: data)?.cgImage {
                    finish(image, nil)
                } else if let image = fromDisk(fallbackPaths) {
                    NSLog("Augen: could not download \(path); using bundled \(fallbackAsset)")
                    finish(image, nil)
                } else {
                    finish(nil, "Could not download image from \(path): \(error?.localizedDescription ?? "HTTP \(status)")")
                }
            }.resume()
            return
        }

        let paths = localPaths(path) + (path == fallbackAsset ? [] : localPaths(fallbackAsset))
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = fromDisk(paths) {
                finish(image, nil)
            } else {
                finish(nil, "Image not found (asset key, file path or URL): \(path)")
            }
        }
    }
}

/// Attaches Dart nodes to ARKit anchors (images, faces) so they follow them.
/// The node is also registered in `host.nodes` so other features (animation,
/// physics) can find it; removing it via the core `removeNode` also works.
enum AugenTrackedAnchorNodes {
    static func attach(
        host: AugenARView,
        nodeId: String,
        nodeData: [String: Any],
        to arAnchor: ARAnchor,
        completion: @escaping (AnchorEntity) -> Void
    ) {
        let position = AugenCodec.vector3(nodeData["position"])
        let rotation = AugenCodec.quaternion(nodeData["rotation"])
        let scale = AugenCodec.vector3(nodeData["scale"], SIMD3<Float>(repeating: 1))
        let type = (nodeData["type"] as? String ?? "sphere").lowercased()

        if let existing = host.nodes.removeValue(forKey: nodeId) {
            host.arView.scene.removeAnchor(existing)
        }
        let anchorEntity = AnchorEntity(anchor: arAnchor)
        anchorEntity.name = nodeId
        host.arView.scene.addAnchor(anchorEntity)
        host.nodes[nodeId] = anchorEntity

        // Node position is an offset in the tracked anchor's local space.
        let finish = {
            if anchorEntity.children.isEmpty {
                let placeholder = AugenARView.makePrimitive(type: "cube")
                placeholder.scale = scale
                placeholder.orientation = rotation
                anchorEntity.addChild(placeholder)
            }
            anchorEntity.children.forEach { $0.position = position }
            anchorEntity.children.first?.name = nodeId
            completion(anchorEntity)
        }

        guard type == "model" else {
            let entity = AugenARView.makePrimitive(type: type)
            entity.scale = scale
            entity.orientation = rotation
            anchorEntity.addChild(entity)
            finish()
            return
        }
        host.modelLoader.load(arguments: nodeData, into: anchorEntity, scale: scale, rotation: rotation) { error in
            if let error = error {
                // Keep the flow working (e.g. unreachable demo URLs) with a
                // visible placeholder instead of failing the attachment.
                NSLog("Augen: model for tracked node \(nodeId) failed to load (\(error)); using placeholder")
            }
            if Thread.isMainThread { finish() } else { DispatchQueue.main.async(execute: finish) }
        }
    }

    static func detach(host: AugenARView, nodeId: String, entity: AnchorEntity) {
        host.arView.scene.removeAnchor(entity)
        if host.nodes[nodeId] === entity { host.nodes.removeValue(forKey: nodeId) }
    }
}
