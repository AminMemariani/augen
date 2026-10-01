import Flutter
import ARKit
import RealityKit
import UIKit

/// Custom lights, shadows and ambient lighting on top of ARKit's light
/// estimation.
///
/// - Directional / point / spot lights are real RealityKit light entities.
/// - Shadows use `DirectionalLightComponent.Shadow` / `SpotLightComponent.Shadow`
///   (RealityKit has no point-light shadows on iOS) plus ARView's grounding
///   shadows. RealityKit exposes no shadow-map resolution knob, so
///   `ShadowQuality` is emulated through the directional shadow's
///   `maximumDistance` (smaller distance → denser shadow map → crisper shadows).
/// - `ambient` / `environment` lights have no RealityKit entity. Ambient light
///   is ARKit's estimated environment lighting; Augen adds the requested fill
///   on top of it via `arView.environment.lighting.intensityExponent`
///   (exponent = log2(1 + fill), so the scene is never darker than reality).
///   RealityKit cannot tint the environment, so ambient colour is stored and
///   reported but not rendered.
///
/// The Dart light map is kept verbatim in the registry so `getLight(s)` round
/// trips through `ARLight.fromMap`. Disabled lights keep their record but
/// their entity is removed from the scene.
final class AugenLightingFeature: AugenFeature {
    private weak var host: AugenARView?

    private var lights: [String: [String: Any]] = [:]
    private var lightOrder: [String] = []
    private var lightAnchors: [String: AnchorEntity] = [:]

    private var lightingEnabled = true
    private var config: [String: Any] = AugenLightingFeature.defaultConfig()
    private var ambientIntensity: Double = 0.3
    private var ambientColor: [String: Any] = ["x": 1.0, "y": 1.0, "z": 1.0]

    init(host: AugenARView) {
        self.host = host
    }

    // MARK: - Dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isLightingSupported":
            result(ARWorldTrackingConfiguration.isSupported)
        case "getLightingCapabilities":
            result(capabilities())
        case "setLightingEnabled":
            lightingEnabled = args["enabled"] as? Bool ?? true
            rebuildAllLights()
            applyAmbient()
            sendStatus(lightingEnabled ? "enabled" : "disabled")
            result(nil)
        case "isLightingEnabled":
            result(lightingEnabled)
        case "setLightingConfig":
            setLightingConfig(args)
            result(nil)
        case "getLightingConfig":
            result(config)
        case "addLight":
            addLight(args, result: result)
        case "updateLight":
            updateLight(args, result: result)
        case "removeLight":
            guard let id = args["lightId"] as? String ?? args["id"] as? String else {
                result(AugenCodec.invalidArguments("Missing lightId parameter")); return true
            }
            removeLight(id)
            notifyLights()
            result(nil)
        case "getLights":
            result(lightOrder.compactMap { lights[$0] })
        case "getLight":
            guard let id = args["lightId"] as? String else {
                result(AugenCodec.invalidArguments("Missing lightId parameter")); return true
            }
            result(lights[id])
        case "clearLights":
            for id in lightOrder { removeLight(id) }
            notifyLights()
            result(nil)
        case "setAmbientLight", "setAmbientLighting":
            if let intensity = args["intensity"] as? NSNumber { ambientIntensity = intensity.doubleValue }
            if let color = args["color"] as? [String: Any] { ambientColor = normalizedVector(color) }
            config["ambientIntensity"] = ambientIntensity
            config["ambientColor"] = ambientColor
            applyAmbient()
            host?.sendEvent("onLightingConfigUpdated", config)
            result(nil)
        case "getAmbientLight":
            result(ambientLightInfo())
        case "setShadowsEnabled":
            config["enableShadows"] = args["enabled"] as? Bool ?? true
            rebuildAllLights()
            host?.sendEvent("onLightingConfigUpdated", config)
            result(nil)
        case "setShadowQuality":
            config["globalShadowQuality"] = args["quality"] as? String ?? "medium"
            rebuildAllLights()
            host?.sendEvent("onLightingConfigUpdated", config)
            result(nil)
        case "updateLightPosition":
            mutateLight(args, result: result) { $0["position"] = self.normalizedVector(args["position"]) }
        case "updateLightRotation":
            mutateLight(args, result: result) { light in
                let q = AugenCodec.quaternion(args["rotation"])
                light["rotation"] = AugenCodec.map(q)
                // Keep `direction` consistent: lights emit along local -Z.
                light["direction"] = AugenCodec.map(q.act(SIMD3<Float>(0, 0, -1)))
            }
        case "updateLightIntensity":
            mutateLight(args, result: result) { $0["intensity"] = AugenCodec.double(args["intensity"], 1000) }
        case "updateLightColor":
            mutateLight(args, result: result) { $0["color"] = self.normalizedVector(args["color"]) }
        case "setLightEnabled":
            mutateLight(args, result: result) { $0["isEnabled"] = args["enabled"] as? Bool ?? true }
        case "setLightCastShadows":
            mutateLight(args, result: result) { $0["castShadows"] = args["castShadows"] as? Bool ?? false }
        default:
            return false
        }
        return true
    }

    func reset() {
        for id in lightOrder { removeLight(id) }
        notifyLights()
    }

    func dispose() {
        lightAnchors.values.forEach { host?.arView.scene.removeAnchor($0) }
        lightAnchors.removeAll()
        lights.removeAll()
        lightOrder.removeAll()
    }

    // MARK: - Capabilities & config

    private func capabilities() -> [String: Any] {
        let supported = ARWorldTrackingConfiguration.isSupported
        var environmentTexturing = false
        if #available(iOS 14.0, *) { environmentTexturing = supported }
        return [
            "supported": supported,
            "maxLights": supported ? 8 : 0,
            "shadowQuality": config["globalShadowQuality"] as? String ?? "medium",
            "supportsLightEstimation": supported,
            "supportsEnvironmentTexturing": environmentTexturing,
            "supportsShadows": supported,
            "supportsDirectionalShadows": supported,
            "supportsSpotShadows": supported,
            "supportsPointShadows": false,
            "supportsContactShadows": false,
            "supportsAmbientColor": false,
            "maxShadowCasters": supported ? 4 : 0,
            "lightTypes": ["directional", "point", "spot", "ambient", "environment"],
        ]
    }

    private static func defaultConfig() -> [String: Any] {
        [
            "enableGlobalIllumination": true,
            "enableShadows": true,
            "globalShadowQuality": "medium",
            "globalShadowFilterMode": "soft",
            "ambientIntensity": 0.3,
            "ambientColor": ["x": 1.0, "y": 1.0, "z": 1.0],
            "shadowDistance": 50.0,
            "maxShadowCasters": 4,
            "enableCascadedShadows": false,
            "shadowCascadeCount": 4,
            "shadowCascadeDistances": [10.0, 25.0, 50.0, 100.0],
            "enableContactShadows": false,
            "contactShadowDistance": 5.0,
            "enableScreenSpaceShadows": false,
            "enableRayTracedShadows": false,
            "metadata": [String: Any](),
        ]
    }

    private func setLightingConfig(_ args: [String: Any]) {
        var merged = config
        for (key, value) in args where !(value is NSNull) { merged[key] = value }
        // Normalise number types so ARLightingConfig.fromMap's casts hold
        // (`as int`, `.cast<double>()`).
        for key in ["ambientIntensity", "shadowDistance", "contactShadowDistance"] {
            merged[key] = AugenCodec.double(merged[key])
        }
        for key in ["maxShadowCasters", "shadowCascadeCount"] {
            merged[key] = (merged[key] as? NSNumber)?.intValue ?? 4
        }
        merged["shadowCascadeDistances"] = (merged["shadowCascadeDistances"] as? [Any] ?? [])
            .map { AugenCodec.double($0) }
        merged["ambientColor"] = normalizedVector(merged["ambientColor"])
        if !(merged["metadata"] is [String: Any]) { merged["metadata"] = [String: Any]() }
        config = merged
        ambientIntensity = AugenCodec.double(merged["ambientIntensity"], 0.3)
        ambientColor = merged["ambientColor"] as? [String: Any] ?? ambientColor

        rebuildAllLights()
        applyAmbient()
        host?.sendEvent("onLightingConfigUpdated", config)
    }

    private var shadowsEnabled: Bool { config["enableShadows"] as? Bool ?? true }

    // MARK: - Lights

    private func addLight(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["id"] as? String, args["type"] is String else {
            result(AugenCodec.invalidArguments("Missing required light parameters (id, type)"))
            return
        }
        let record = normalizedLight(args, existing: lights[id])
        if lights[id] == nil { lightOrder.append(id) }
        lights[id] = record
        rebuildLight(id)
        applyAmbient()
        notifyLights()
        result(record)
    }

    private func updateLight(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["id"] as? String else {
            result(AugenCodec.invalidArguments("Missing id parameter")); return
        }
        guard lights[id] != nil else {
            result(FlutterError(code: "LIGHT_NOT_FOUND", message: "Light \(id) not found", details: nil)); return
        }
        var merged = lights[id] ?? [:]
        for (key, value) in args where !(value is NSNull) { merged[key] = value }
        lights[id] = normalizedLight(merged, existing: lights[id])
        rebuildLight(id)
        applyAmbient()
        notifyLights()
        result(nil)
    }

    private func mutateLight(
        _ args: [String: Any],
        result: @escaping FlutterResult,
        _ change: (inout [String: Any]) -> Void
    ) {
        guard let id = args["lightId"] as? String else {
            result(AugenCodec.invalidArguments("Missing lightId parameter")); return
        }
        guard var light = lights[id] else {
            result(FlutterError(code: "LIGHT_NOT_FOUND", message: "Light \(id) not found", details: nil)); return
        }
        change(&light)
        light["lastModified"] = AugenCodec.nowMillis()
        lights[id] = light
        rebuildLight(id)
        applyAmbient()
        notifyLights()
        result(nil)
    }

    private func removeLight(_ id: String) {
        if let anchor = lightAnchors.removeValue(forKey: id) {
            host?.arView.scene.removeAnchor(anchor)
        }
        lights.removeValue(forKey: id)
        lightOrder.removeAll { $0 == id }
        applyAmbient()
    }

    /// Fill every key `ARLight.fromMap` requires, with the Dart types it casts to.
    private func normalizedLight(_ input: [String: Any], existing: [String: Any]?) -> [String: Any] {
        let now = AugenCodec.nowMillis()
        var light = input
        light["type"] = (input["type"] as? String)?.lowercased() ?? "point"
        light["position"] = normalizedVector(input["position"], default: ["x": 0.0, "y": 1.0, "z": 0.0])
        light["rotation"] = AugenCodec.map(AugenCodec.quaternion(input["rotation"]))
        light["direction"] = normalizedVector(input["direction"], default: ["x": 0.0, "y": -1.0, "z": 0.0])
        light["color"] = normalizedVector(input["color"])
        light["intensity"] = AugenCodec.double(input["intensity"], 1000)
        light["intensityUnit"] = input["intensityUnit"] as? String ?? "lux"
        light["range"] = AugenCodec.double(input["range"], 10)
        light["innerConeAngle"] = AugenCodec.double(input["innerConeAngle"], 0)
        light["outerConeAngle"] = AugenCodec.double(input["outerConeAngle"], 45)
        light["isEnabled"] = input["isEnabled"] as? Bool ?? true
        light["castShadows"] = input["castShadows"] as? Bool ?? false
        light["shadowQuality"] = input["shadowQuality"] as? String ?? "medium"
        light["shadowFilterMode"] = input["shadowFilterMode"] as? String ?? "soft"
        light["shadowBias"] = AugenCodec.double(input["shadowBias"], 0.005)
        light["shadowNormalBias"] = AugenCodec.double(input["shadowNormalBias"], 0.0)
        light["shadowNearPlane"] = AugenCodec.double(input["shadowNearPlane"], 0.1)
        light["shadowFarPlane"] = AugenCodec.double(input["shadowFarPlane"], 100)
        light["createdAt"] = (existing?["createdAt"] as? NSNumber)?.intValue
            ?? (input["createdAt"] as? NSNumber)?.intValue ?? now
        light["lastModified"] = now
        if !(input["metadata"] is [String: Any]) { light["metadata"] = [String: Any]() }
        return light
    }

    private func normalizedVector(_ value: Any?, default fallback: [String: Any] = ["x": 1.0, "y": 1.0, "z": 1.0]) -> [String: Any] {
        guard let map = value as? [String: Any] else { return fallback }
        return [
            "x": AugenCodec.double(map["x"], AugenCodec.double(fallback["x"])),
            "y": AugenCodec.double(map["y"], AugenCodec.double(fallback["y"])),
            "z": AugenCodec.double(map["z"], AugenCodec.double(fallback["z"])),
        ]
    }

    private func rebuildAllLights() {
        lightOrder.forEach { rebuildLight($0) }
        if let arView = host?.arView {
            if shadowsEnabled && lightingEnabled {
                arView.renderOptions.remove(.disableGroundingShadows)
            } else {
                arView.renderOptions.insert(.disableGroundingShadows)
            }
        }
    }

    /// (Re)create the RealityKit entity for a light record.
    private func rebuildLight(_ id: String) {
        guard let arView = host?.arView else { return }
        if let old = lightAnchors.removeValue(forKey: id) {
            arView.scene.removeAnchor(old)
        }
        guard lightingEnabled, let light = lights[id], light["isEnabled"] as? Bool ?? true else { return }

        let type = light["type"] as? String ?? "point"
        let color = uiColor(light["color"])
        let intensity = Float(AugenCodec.double(light["intensity"], 1000))
        let castShadows = shadowsEnabled && (light["castShadows"] as? Bool ?? false)
        let entity: Entity

        switch type {
        case "directional":
            let directional = DirectionalLight()
            directional.light.color = color
            directional.light.intensity = intensity
            if castShadows {
                directional.shadow = DirectionalLightComponent.Shadow(
                    maximumDistance: shadowMaximumDistance(light["shadowQuality"] as? String),
                    depthBias: 1
                )
            }
            entity = directional
        case "spot":
            let spot = SpotLight()
            spot.light.color = color
            spot.light.intensity = intensity
            spot.light.attenuationRadius = Float(AugenCodec.double(light["range"], 10))
            let outer = Float(min(max(AugenCodec.double(light["outerConeAngle"], 45), 1), 179))
            let inner = Float(min(max(AugenCodec.double(light["innerConeAngle"], 0), 0), Double(outer)))
            spot.light.outerAngleInDegrees = outer
            spot.light.innerAngleInDegrees = inner
            if castShadows { spot.shadow = SpotLightComponent.Shadow() }
            entity = spot
        case "point":
            let point = PointLight()
            point.light.color = color
            point.light.intensity = intensity
            point.light.attenuationRadius = Float(AugenCodec.double(light["range"], 10))
            entity = point
        default:
            // ambient / environment: handled by applyAmbient(), no entity.
            return
        }

        orient(entity, light: light)
        let anchor = AnchorEntity(world: AugenCodec.vector3(light["position"]))
        anchor.name = "augen_light_\(id)"
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        lightAnchors[id] = anchor
    }

    private func orient(_ entity: Entity, light: [String: Any]) {
        let direction = AugenCodec.vector3(light["direction"])
        if simd_length(direction) > 0.0001 {
            // RealityKit lights emit along their local -Z axis.
            entity.orientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: simd_normalize(direction))
        } else {
            entity.orientation = AugenCodec.quaternion(light["rotation"])
        }
    }

    private func shadowMaximumDistance(_ quality: String?) -> Float {
        let configured = Float(AugenCodec.double(config["shadowDistance"], 50))
        let byQuality: Float
        switch quality ?? config["globalShadowQuality"] as? String ?? "medium" {
        case "low": byQuality = 10
        case "high": byQuality = 3
        case "ultra": byQuality = 2
        default: byQuality = 5
        }
        return max(0.5, min(configured, byQuality))
    }

    private func uiColor(_ value: Any?) -> UIColor {
        let v = AugenCodec.vector3(value, SIMD3<Float>(1, 1, 1))
        return UIColor(red: CGFloat(v.x), green: CGFloat(v.y), blue: CGFloat(v.z), alpha: 1)
    }

    // MARK: - Ambient

    private func applyAmbient() {
        guard let arView = host?.arView else { return }
        guard lightingEnabled else {
            arView.environment.lighting.intensityExponent = 0
            return
        }
        var fill = max(0, ambientIntensity)
        for id in lightOrder {
            guard let light = lights[id],
                  light["isEnabled"] as? Bool ?? true,
                  let type = light["type"] as? String,
                  type == "ambient" || type == "environment" else { continue }
            // Ambient lights are specified in lux; 1000 lux ≈ one extra
            // "unit" of fill on top of the estimated environment.
            fill += max(0, AugenCodec.double(light["intensity"])) / 1000
        }
        arView.environment.lighting.intensityExponent = Float(min(3, log2(1 + fill)))
    }

    private func ambientLightInfo() -> [String: Any] {
        var info: [String: Any] = [
            "intensity": ambientIntensity,
            "color": ambientColor,
            "intensityExponent": Double(host?.arView.environment.lighting.intensityExponent ?? 0),
            "enabled": lightingEnabled,
        ]
        if let estimate = host?.arView.session.currentFrame?.lightEstimate {
            info["estimatedIntensity"] = Double(estimate.ambientIntensity)
            info["estimatedColorTemperature"] = Double(estimate.ambientColorTemperature)
        }
        return info
    }

    // MARK: - Events

    private func notifyLights() {
        host?.sendEvent("onLightsUpdated", lightOrder.compactMap { lights[$0] })
    }

    private func sendStatus(_ status: String) {
        host?.sendEvent("onLightingStatusUpdated", [
            "status": status,
            "progress": 1.0,
            "errorMessage": NSNull(),
            "timestamp": AugenCodec.nowMillis(),
            "metadata": ["lightCount": lights.count],
        ] as [String: Any])
    }
}
