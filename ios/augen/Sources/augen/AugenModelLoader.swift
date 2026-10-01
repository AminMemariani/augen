import Flutter
import Foundation
import RealityKit
import SceneKit
import SceneKit.ModelIO
import ModelIO
import Combine

/// Loads custom models for `addNode(type: model)`.
///
/// Sources (Dart `ARNode.toMap`): `modelPath` (Flutter asset key, absolute
/// file path / `file://` URL, or `http(s)` URL) and optionally raw bytes in
/// `modelData` (`Uint8List`); `modelFormat` is one of `gltf`, `glb`, `obj`,
/// `usdz` (otherwise inferred from the file extension).
///
/// Format support on iOS:
/// - `usdz` / `usd` / `usda` / `usdc` / `reality`: loaded natively by RealityKit
///   (hierarchy and baked animations preserved).
/// - `obj`: converted on a background queue via ModelIO → SceneKit → USDZ export,
///   then loaded by RealityKit.
/// - `gltf` / `glb`: neither RealityKit nor ModelIO can read glTF, so a clearly
///   visible placeholder (orange box) is attached instead and the call succeeds
///   (logged with NSLog). Convert assets to USDZ for real rendering on iOS.
final class AugenModelLoader {
    private weak var host: AugenARView?
    private var loadRequests: [UUID: AnyCancellable] = [:]
    private let workQueue = DispatchQueue(label: "augen.model-loader", qos: .userInitiated)

    init(host: AugenARView) {
        self.host = host
    }

    private static let realityKitExtensions: Set<String> = ["usdz", "usd", "usda", "usdc", "reality"]

    /// Load the model described by `arguments` and attach it to `anchor`.
    /// `completion(nil)` on success, `completion(errorMessage)` on failure.
    /// `completion` is always invoked exactly once, on the main thread.
    func load(
        arguments: [String: Any],
        into anchor: AnchorEntity,
        scale: SIMD3<Float>,
        rotation: simd_quatf,
        completion: @escaping (String?) -> Void
    ) {
        var completed = false
        let finish: (String?) -> Void = { message in
            let deliver = {
                guard !completed else { return }
                completed = true
                completion(message)
            }
            if Thread.isMainThread { deliver() } else { DispatchQueue.main.async(execute: deliver) }
        }

        let nodeId = arguments["id"] as? String ?? anchor.name
        let path = (arguments["modelPath"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = (arguments["modelData"] as? FlutterStandardTypedData)?.data
        let format = Self.format(declared: arguments["modelFormat"] as? String, path: path)
        let autoPlay = Self.autoPlayAnimations(arguments["animations"])

        let attach: (Entity) -> Void = { [weak self] entity in
            self?.attach(entity, nodeId: nodeId, to: anchor, scale: scale, rotation: rotation, autoPlay: autoPlay)
            finish(nil)
        }

        if path == nil && bytes == nil {
            finish("Model node \(nodeId) has neither modelPath nor modelData")
            return
        }

        // glTF/GLB cannot be decoded on iOS — don't bother downloading it.
        if format == "gltf" || format == "glb" {
            NSLog("Augen: %@ models are not supported by RealityKit/ModelIO; showing placeholder for node %@. Convert the asset to USDZ.", format, nodeId)
            attach(Self.makePlaceholder())
            return
        }

        resolveLocalURL(path: path, bytes: bytes, format: format) { [weak self] url, error in
            guard let self = self else { finish("AR view was disposed"); return }
            guard let url = url else { finish(error ?? "Unable to resolve model source"); return }
            let ext = Self.realityKitExtensions.contains(format) ? format : url.pathExtension.lowercased()
            if Self.realityKitExtensions.contains(ext) {
                self.loadWithRealityKit(url: url, completion: { entity, error in
                    if let entity = entity { attach(entity) } else { finish(error) }
                })
            } else if ext == "obj" || format == "obj" {
                self.convertOBJ(url: url) { usdzURL in
                    guard let usdzURL = usdzURL else {
                        NSLog("Augen: OBJ conversion failed for node %@; showing placeholder", nodeId)
                        attach(Self.makePlaceholder())
                        return
                    }
                    self.loadWithRealityKit(url: usdzURL, completion: { entity, error in
                        if let entity = entity { attach(entity) } else { finish(error) }
                    })
                }
            } else {
                NSLog("Augen: unsupported model format '%@' for node %@; showing placeholder", ext, nodeId)
                attach(Self.makePlaceholder())
            }
        }
    }

    // MARK: - Source resolution

    private static func format(declared: String?, path: String?) -> String {
        if let declared = declared?.lowercased(), !declared.isEmpty { return declared }
        guard let path = path else { return "usdz" }
        let clean = path.components(separatedBy: "?").first ?? path
        let ext = (clean as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "usdz" : ext
    }

    private static func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("augen_model_\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    private func resolveLocalURL(
        path: String?,
        bytes: Data?,
        format: String,
        completion: @escaping (URL?, String?) -> Void
    ) {
        if let bytes = bytes {
            let url = Self.temporaryURL(extension: format)
            do {
                try bytes.write(to: url)
                completion(url, nil)
            } catch {
                completion(nil, "Failed to write model data: \(error.localizedDescription)")
            }
            return
        }
        guard let path = path else { completion(nil, "Missing modelPath"); return }

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            guard let remote = URL(string: path) else { completion(nil, "Invalid model URL: \(path)"); return }
            URLSession.shared.downloadTask(with: remote) { tempURL, response, error in
                if let error = error {
                    completion(nil, "Model download failed: \(error.localizedDescription)")
                    return
                }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    completion(nil, "Model download failed: HTTP \(http.statusCode)")
                    return
                }
                guard let tempURL = tempURL else { completion(nil, "Model download returned no file"); return }
                let ext = remote.pathExtension.isEmpty ? format : remote.pathExtension.lowercased()
                let destination = Self.temporaryURL(extension: ext)
                do {
                    // The system deletes `tempURL` when this handler returns.
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    completion(destination, nil)
                } catch {
                    completion(nil, "Failed to store downloaded model: \(error.localizedDescription)")
                }
            }.resume()
            return
        }

        if path.hasPrefix("file://"), let url = URL(string: path), FileManager.default.fileExists(atPath: url.path) {
            completion(url, nil)
            return
        }
        if path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) {
            completion(URL(fileURLWithPath: path), nil)
            return
        }
        if let assetPath = host?.assetPath(forKey: path), FileManager.default.fileExists(atPath: assetPath) {
            completion(URL(fileURLWithPath: assetPath), nil)
            return
        }
        // Bare file name shipped in the app bundle (e.g. native resources).
        if let bundled = Bundle.main.url(forResource: path, withExtension: nil) {
            completion(bundled, nil)
            return
        }
        completion(nil, "Model not found: \(path)")
    }

    // MARK: - Loading

    private func loadWithRealityKit(url: URL, completion: @escaping (Entity?, String?) -> Void) {
        let start = { [weak self] in
            guard let self = self else { completion(nil, "AR view was disposed"); return }
            let token = UUID()
            var finished = false
            let cancellable = Entity.loadAsync(contentsOf: url).sink(
                receiveCompletion: { [weak self] outcome in
                    self?.loadRequests[token] = nil
                    if case .failure(let error) = outcome, !finished {
                        finished = true
                        completion(nil, "Failed to load model: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] entity in
                    self?.loadRequests[token] = nil
                    guard !finished else { return }
                    finished = true
                    completion(entity, nil)
                }
            )
            if !finished { self.loadRequests[token] = cancellable }
        }
        // RealityKit loading must start on the main thread.
        if Thread.isMainThread { start() } else { DispatchQueue.main.async(execute: start) }
    }

    /// OBJ → USDZ through ModelIO and SceneKit (both read OBJ natively; SceneKit
    /// writes USDZ since iOS 12). Runs off the main thread.
    private func convertOBJ(url: URL, completion: @escaping (URL?) -> Void) {
        workQueue.async {
            let asset = MDLAsset(url: url)
            asset.loadTextures()
            let scene = SCNScene(mdlAsset: asset)
            let destination = Self.temporaryURL(extension: "usdz")
            var ok = scene.write(to: destination, options: nil, delegate: nil, progressHandler: nil)
            if !ok, MDLAsset.canExportFileExtension("usdz") {
                ok = (try? asset.export(to: destination)) != nil
            }
            DispatchQueue.main.async {
                completion(ok && FileManager.default.fileExists(atPath: destination.path) ? destination : nil)
            }
        }
    }

    private func attach(
        _ entity: Entity,
        nodeId: String,
        to anchor: AnchorEntity,
        scale: SIMD3<Float>,
        rotation: simd_quatf,
        autoPlay: [String]?
    ) {
        // The node may have been removed/replaced while the model was loading.
        guard let host = host, host.nodes[nodeId] === anchor else {
            NSLog("Augen: node %@ changed while its model was loading; discarding result", nodeId)
            return
        }
        entity.name = nodeId
        entity.scale = scale
        entity.orientation = rotation
        entity.generateCollisionShapes(recursive: true)
        // Visible entity must be the anchor's first child (host contract).
        anchor.children.removeAll()
        anchor.addChild(entity)

        if let autoPlay = autoPlay, !entity.availableAnimations.isEmpty {
            let clips = entity.availableAnimations
            var played = false
            if #available(iOS 15.0, *) {
                for clip in clips where clip.name.map(autoPlay.contains) ?? false {
                    entity.playAnimation(clip.repeat(), transitionDuration: 0, startsPaused: false)
                    played = true
                }
            }
            if !played, let first = clips.first {
                entity.playAnimation(first.repeat(), transitionDuration: 0, startsPaused: false)
            }
        }
    }

    /// Animation ids flagged `autoPlay` in `ARNode.animations` (nil if none).
    private static func autoPlayAnimations(_ value: Any?) -> [String]? {
        guard let list = value as? [[String: Any]] else { return nil }
        let ids = list.filter { ($0["autoPlay"] as? Bool) ?? true }.compactMap { $0["id"] as? String }
        return ids.isEmpty ? nil : ids
    }

    static func makePlaceholder() -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateBox(size: 0.1, cornerRadius: 0.01),
            materials: [SimpleMaterial(color: .orange, isMetallic: false)]
        )
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    func dispose() {
        loadRequests.values.forEach { $0.cancel() }
        loadRequests.removeAll()
    }
}
