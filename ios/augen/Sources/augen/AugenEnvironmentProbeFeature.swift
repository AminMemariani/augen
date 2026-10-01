import Flutter
import ARKit
import RealityKit

/// Environment probes on ARKit.
///
/// Global probes map to `environmentTexturing` on the world-tracking
/// configuration (`.automatic` when `autoCreateProbes`, otherwise `.manual`);
/// RealityKit lights/reflects content from the resulting cube maps. Manual
/// probes become `AREnvironmentProbeAnchor`s (extent = |scale| × 2 ×
/// influenceRadius). Anchors are immutable, so updates replace the anchor —
/// which also makes ARKit regenerate the texture. `quality` high/ultra
/// requests HDR textures; `textureResolution`, `updateFrequency` and
/// capture flags are stored for Dart but ARKit chooses resolution/cadence.
/// A probe reports status `completed` once ARKit populated its texture.
final class AugenEnvironmentProbeFeature: AugenFeature {
    private weak var host: AugenARView?

    private struct Probe {
        var data: [String: Any]
        var anchor: AREnvironmentProbeAnchor?
        var textureReady = false
    }

    private var probes: [String: Probe] = [:]
    private var order: [String] = []
    private var config: [String: Any] = AugenEnvironmentProbeFeature.defaultConfig
    /// Whether Dart has explicitly configured/toggled probes. Until then the
    /// base configuration's environment texturing is left untouched.
    private var explicitlyConfigured = false
    private var needsAnchorSync = false
    private var environmentMap: [String: Any]?

    private static let types = ["spherical", "box", "planar"]
    private static let updateModes = ["automatic", "manual", "onMovement"]
    private static let qualities = ["low", "medium", "high", "ultra"]

    private static let defaultConfig: [String: Any] = [
        "enableProbes": true,
        "defaultQuality": "medium",
        "defaultUpdateMode": "automatic",
        "defaultTextureResolution": 512,
        "maxActiveProbes": 8,
        "defaultInfluenceRadius": 5.0,
        "defaultRealTime": true,
        "defaultUpdateFrequency": 1.0,
        "autoCreateProbes": true,
        "optimizePlacement": true,
        "metadata": [String: Any](),
    ]

    init(host: AugenARView) {
        self.host = host
    }

    private static var isSupported: Bool {
        if #available(iOS 14.0, *) { return ARWorldTrackingConfiguration.isSupported }
        return false
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isEnvironmentalProbesSupported":
            result(Self.isSupported)
        case "getEnvironmentalProbesCapabilities":
            let supported = Self.isSupported
            result([
                "supported": supported,
                "automaticPlacement": supported,
                "manualPlacement": supported,
                "realTimeUpdates": supported,
                "hdrTextures": supported,
                "maxActiveProbes": supported ? 8 : 0,
                "supportedResolutions": supported ? [256, 512, 1024] : [Int](),
                "maxTextureResolution": supported ? 1024 : 0,
            ])
        case "setEnvironmentalProbesEnabled":
            setGlobalEnabled(args["enabled"] as? Bool ?? false)
            result(nil)
        case "isEnvironmentalProbesEnabled":
            result(isGloballyEnabled)
        case "setEnvironmentalProbeConfig":
            config = normalizedConfig(args)
            explicitlyConfigured = true
            applyConfiguration()
            host?.sendEvent("onProbeConfigUpdated", config)
            result(nil)
        case "getEnvironmentalProbeConfig":
            result(config)
        case "addEnvironmentalProbe":
            addProbe(args, result: result)
        case "removeEnvironmentalProbe":
            guard let id = probeId(args, result) else { return true }
            removeAnchor(of: id)
            probes.removeValue(forKey: id)
            order.removeAll { $0 == id }
            emitProbes()
            result(nil)
        case "clearEnvironmentalProbes":
            clearProbes()
            emitProbes()
            result(nil)
        case "getEnvironmentalProbes":
            result(order.compactMap { probes[$0]?.data })
        case "getEnvironmentalProbe":
            let id = args["probeId"] as? String ?? ""
            result(probes[id]?.data ?? nil)
        case "updateEnvironmentalProbe":
            guard let id = args["probeId"] as? String ?? args["id"] as? String, probes[id] != nil else {
                result(FlutterError(code: "PROBE_NOT_FOUND", message: "Environmental probe not found", details: nil))
                return true
            }
            var fields = args
            fields.removeValue(forKey: "probeId")
            update(id, fields: fields, result: result)
        case "updateEnvironmentalProbePosition":
            guard let id = probeId(args, result) else { return true }
            update(id, fields: ["position": args["position"] as Any], result: result)
        case "updateEnvironmentalProbeRotation":
            guard let id = probeId(args, result) else { return true }
            update(id, fields: ["rotation": args["rotation"] as Any], result: result)
        case "updateEnvironmentalProbeInfluenceRadius":
            guard let id = probeId(args, result) else { return true }
            update(id, fields: ["influenceRadius": args["influenceRadius"] as Any], result: result)
        case "updateEnvironmentalProbeQuality":
            guard let id = probeId(args, result) else { return true }
            update(id, fields: ["quality": args["quality"] as Any], result: result)
        case "updateEnvironmentalProbeCaptureSettings":
            guard let id = probeId(args, result) else { return true }
            var fields: [String: Any] = [:]
            if let value = args["captureReflections"] as? Bool { fields["captureReflections"] = value }
            if let value = args["captureLighting"] as? Bool { fields["captureLighting"] = value }
            update(id, fields: fields, result: result)
        case "setEnvironmentalProbeEnabled":
            // Per-probe toggle; without a probeId treat it as the global switch.
            guard args["probeId"] != nil else {
                setGlobalEnabled(args["enabled"] as? Bool ?? false)
                result(nil)
                return true
            }
            guard let id = probeId(args, result) else { return true }
            update(id, fields: ["isActive": args["enabled"] as? Bool ?? false], result: result)
        case "forceEnvironmentalProbeUpdate":
            guard let id = probeId(args, result) else { return true }
            removeAnchor(of: id)
            needsAnchorSync = true
            sendStatus("in_progress", progress: 0, probeId: id)
            result(nil)
        case "setEnvironmentMap":
            setEnvironmentMap(args, result: result)
        case "getEnvironmentMap":
            result(environmentMap)
        default:
            return false
        }
        return true
    }

    // MARK: - Global configuration

    private var isGloballyEnabled: Bool {
        if explicitlyConfigured { return config["enableProbes"] as? Bool ?? true }
        return host?.sessionOptions["lightEstimation"] as? Bool ?? true
    }

    private func setGlobalEnabled(_ enabled: Bool) {
        config["enableProbes"] = enabled
        explicitlyConfigured = true
        applyConfiguration()
        host?.sendEvent("onProbeConfigUpdated", config)
    }

    private func applyConfiguration() {
        host?.applySessionConfiguration()
        needsAnchorSync = true
    }

    func configure(_ configuration: ARConfiguration) -> ARConfiguration {
        needsAnchorSync = true
        guard let world = configuration as? ARWorldTrackingConfiguration,
              explicitlyConfigured || !probes.isEmpty else { return configuration }
        let enabled = explicitlyConfigured ? (config["enableProbes"] as? Bool ?? true) : true
        guard enabled else {
            world.environmentTexturing = .none
            return world
        }
        world.environmentTexturing = (config["autoCreateProbes"] as? Bool ?? true) ? .automatic : .manual
        let qualities = [config["defaultQuality"] as? String] + probes.values.map { $0.data["quality"] as? String }
        world.wantsHDREnvironmentTextures = qualities.contains { $0 == "high" || $0 == "ultra" }
        return world
    }

    private func normalizedConfig(_ args: [String: Any]) -> [String: Any] {
        var result = config
        for key in ["enableProbes", "defaultRealTime", "autoCreateProbes", "optimizePlacement"] {
            if let value = args[key] as? Bool { result[key] = value }
        }
        for key in ["defaultTextureResolution", "maxActiveProbes"] {
            if let value = args[key] as? NSNumber { result[key] = value.intValue }
        }
        for key in ["defaultInfluenceRadius", "defaultUpdateFrequency"] {
            if let value = args[key] as? NSNumber { result[key] = value.doubleValue }
        }
        if let value = args["defaultQuality"] as? String, Self.qualities.contains(value) { result["defaultQuality"] = value }
        if let value = args["defaultUpdateMode"] as? String, Self.updateModes.contains(value) { result["defaultUpdateMode"] = value }
        if let value = args["metadata"] as? [String: Any] { result["metadata"] = value }
        return result
    }

    // MARK: - Probes

    private func probeId(_ args: [String: Any], _ result: FlutterResult) -> String? {
        guard let id = args["probeId"] as? String else {
            result(AugenCodec.invalidArguments("Missing probeId"))
            return nil
        }
        guard probes[id] != nil else {
            result(FlutterError(code: "PROBE_NOT_FOUND", message: "Environmental probe \(id) not found", details: nil))
            return nil
        }
        return id
    }

    private func addProbe(_ args: [String: Any], result: @escaping FlutterResult) {
        guard Self.isSupported else {
            result(FlutterError(code: "PROBES_NOT_SUPPORTED", message: "Environment probes require iOS 14+ world tracking", details: nil))
            return
        }
        let maxActive = config["maxActiveProbes"] as? Int ?? 8
        let active = probes.values.filter { $0.data["isActive"] as? Bool ?? true }.count
        if (args["isActive"] as? Bool ?? true) && active >= maxActive {
            result(FlutterError(code: "MAX_PROBES_REACHED",
                                message: "maxActiveProbes (\(maxActive)) reached", details: nil))
            return
        }
        let now = AugenCodec.nowMillis()
        let id = (args["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "probe_\(UUID().uuidString)"
        var defaults: [String: Any] = [
            "id": id,
            "type": "spherical",
            "position": AugenCodec.map(SIMD3<Float>.zero),
            "rotation": AugenCodec.map(simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)),
            "scale": AugenCodec.map(SIMD3<Float>(repeating: 1)),
            "influenceRadius": config["defaultInfluenceRadius"] as? Double ?? 5.0,
            "updateMode": config["defaultUpdateMode"] as? String ?? "automatic",
            "quality": config["defaultQuality"] as? String ?? "medium",
            "isActive": true,
            "captureReflections": true,
            "captureLighting": true,
            "textureResolution": config["defaultTextureResolution"] as? Int ?? 512,
            "isRealTime": config["defaultRealTime"] as? Bool ?? true,
            "updateFrequency": config["defaultUpdateFrequency"] as? Double ?? 1.0,
            "confidence": 1.0,
            "createdAt": now,
            "lastModified": now,
            "metadata": [String: Any](),
        ]
        merge(args, into: &defaults)
        defaults["id"] = id
        removeAnchor(of: id)
        if probes[id] == nil { order.append(id) }
        let hadProbes = !probes.isEmpty
        probes[id] = Probe(data: defaults)
        // The first manual probe may require enabling environment texturing.
        if !hadProbes && !explicitlyConfigured { host?.applySessionConfiguration() }
        needsAnchorSync = true
        sendStatus("in_progress", progress: 0, probeId: id)
        emitProbes()
        result(defaults)
    }

    private func update(_ id: String, fields: [String: Any], result: FlutterResult) {
        guard var probe = probes[id] else {
            result(FlutterError(code: "PROBE_NOT_FOUND", message: "Environmental probe \(id) not found", details: nil))
            return
        }
        merge(fields, into: &probe.data)
        probe.data["id"] = id
        probe.data["lastModified"] = AugenCodec.nowMillis()
        probes[id] = probe
        // Placement changes require a new (immutable) anchor.
        let placementKeys: Set<String> = ["position", "rotation", "scale", "influenceRadius", "isActive", "type"]
        if !placementKeys.isDisjoint(with: fields.keys) {
            removeAnchor(of: id)
            needsAnchorSync = true
        }
        if fields["quality"] != nil { host?.applySessionConfiguration() }
        emitProbes()
        result(nil)
    }

    /// Copy recognised probe fields with the exact Dart types.
    private func merge(_ source: [String: Any], into data: inout [String: Any]) {
        if let value = source["type"] as? String, Self.types.contains(value) { data["type"] = value }
        if let value = source["updateMode"] as? String, Self.updateModes.contains(value) { data["updateMode"] = value }
        if let value = source["quality"] as? String, Self.qualities.contains(value) { data["quality"] = value }
        if source["position"] is [String: Any] { data["position"] = AugenCodec.map(AugenCodec.vector3(source["position"])) }
        if source["rotation"] is [String: Any] { data["rotation"] = AugenCodec.map(AugenCodec.quaternion(source["rotation"])) }
        if source["scale"] is [String: Any] {
            data["scale"] = AugenCodec.map(AugenCodec.vector3(source["scale"], SIMD3<Float>(repeating: 1)))
        }
        for key in ["influenceRadius", "updateFrequency", "confidence"] {
            if let value = source[key] as? NSNumber { data[key] = value.doubleValue }
        }
        for key in ["textureResolution", "createdAt", "lastModified"] {
            if let value = source[key] as? NSNumber { data[key] = value.intValue }
        }
        for key in ["isActive", "captureReflections", "captureLighting", "isRealTime"] {
            if let value = source[key] as? Bool { data[key] = value }
        }
        if let value = source["metadata"] as? [String: Any] { data["metadata"] = value }
    }

    private func makeAnchor(for probe: Probe, id: String) -> AREnvironmentProbeAnchor {
        let position = AugenCodec.vector3(probe.data["position"])
        let rotation = AugenCodec.quaternion(probe.data["rotation"])
        let scale = AugenCodec.vector3(probe.data["scale"], SIMD3<Float>(repeating: 1))
        let radius = Float(AugenCodec.double(probe.data["influenceRadius"], 5))
        let extent = simd_max(simd_abs(scale) * 2 * radius, SIMD3<Float>(repeating: 0.1))
        let transform = Transform(scale: .one, rotation: rotation, translation: position).matrix
        return AREnvironmentProbeAnchor(name: id, transform: transform, extent: extent)
    }

    private func removeAnchor(of id: String) {
        guard var probe = probes[id], let anchor = probe.anchor else { return }
        probe.anchor = nil
        probe.textureReady = false
        probes[id] = probe
        host?.arView.session.remove(anchor: anchor)
    }

    /// Add/remove ARKit anchors so they match the active probes. Deferred to
    /// the frame callback so it runs after any session (re)configuration.
    private func syncAnchors(_ session: ARSession) {
        needsAnchorSync = false
        guard let world = session.configuration as? ARWorldTrackingConfiguration,
              world.environmentTexturing != .none else { return }
        for id in order {
            guard var probe = probes[id] else { continue }
            let active = probe.data["isActive"] as? Bool ?? true
            if active, probe.anchor == nil {
                let anchor = makeAnchor(for: probe, id: id)
                probe.anchor = anchor
                probe.textureReady = false
                probes[id] = probe
                session.add(anchor: anchor)
            } else if !active, probe.anchor != nil {
                removeAnchor(of: id)
            }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if needsAnchorSync { syncAnchors(session) }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        checkTextures(anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        checkTextures(anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Anchors dropped by the session (e.g. tracking reset) get re-added.
        let removed = Set(anchors.compactMap { ($0 as? AREnvironmentProbeAnchor)?.identifier })
        guard !removed.isEmpty else { return }
        for id in order {
            guard var probe = probes[id], let anchor = probe.anchor, removed.contains(anchor.identifier) else { continue }
            probe.anchor = nil
            probe.textureReady = false
            probes[id] = probe
            needsAnchorSync = true
        }
    }

    private func checkTextures(_ anchors: [ARAnchor]) {
        var changed = false
        for case let anchor as AREnvironmentProbeAnchor in anchors {
            guard let id = anchor.name, var probe = probes[id],
                  probe.anchor?.identifier == anchor.identifier,
                  !probe.textureReady, let texture = anchor.environmentTexture else { continue }
            probe.textureReady = true
            probe.data["lastModified"] = AugenCodec.nowMillis()
            probes[id] = probe
            sendStatus("completed", progress: 1, probeId: id, extra: [
                "textureWidth": texture.width,
                "textureHeight": texture.height,
            ])
            changed = true
        }
        if changed { emitProbes() }
    }

    private func clearProbes() {
        for id in order { removeAnchor(of: id) }
        probes.removeAll()
        order.removeAll()
    }

    private func emitProbes() {
        host?.sendEvent("onProbesUpdated", order.compactMap { probes[$0]?.data })
    }

    private func sendStatus(_ status: String, progress: Double, probeId: String, extra: [String: Any] = [:]) {
        var metadata = extra
        metadata["probeId"] = probeId
        host?.sendEvent("onProbeStatusUpdated", [
            "status": status,
            "progress": progress,
            "timestamp": AugenCodec.nowMillis(),
            "metadata": metadata,
        ])
    }

    // MARK: - Environment map

    /// Stores the map and applies what RealityKit supports: `intensity`
    /// (linear, applied as an exposure offset) and, on iOS 18+, an
    /// equirectangular image (`imagePath` asset/file/URL or `imageData`) as
    /// the image-based-lighting resource.
    private func setEnvironmentMap(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let host = host else {
            result(nil)
            return
        }
        environmentMap = args
        if let intensity = args["intensity"] as? NSNumber, intensity.doubleValue > 0 {
            host.arView.environment.lighting.intensityExponent = Float(log2(intensity.doubleValue))
        }
        let path = args["imagePath"] as? String ?? args["path"] as? String ?? args["url"] as? String
        let data = (args["imageData"] as? FlutterStandardTypedData)?.data
        guard path != nil || data != nil else {
            result(nil)
            return
        }
        guard #available(iOS 18.0, *) else {
            result(nil) // stored only; custom IBL images need iOS 18 RealityKit
            return
        }
        AugenImageTrackingAssets.loadCGImage(path: path ?? "", data: data, host: host) { [weak host] image, error in
            guard let image = image else {
                result(FlutterError(code: "ENVIRONMENT_MAP_LOAD_FAILED", message: error, details: path))
                return
            }
            do {
                let resource = try EnvironmentResource(equirectangular: image)
                host?.arView.environment.lighting.resource = resource
                result(nil)
            } catch {
                result(FlutterError(code: "ENVIRONMENT_MAP_INVALID", message: error.localizedDescription, details: path))
            }
        }
    }

    // MARK: - Lifecycle

    func reset() {
        clearProbes()
        emitProbes()
    }

    func dispose() {
        clearProbes()
    }
}
