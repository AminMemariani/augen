import Flutter
import ARKit
import RealityKit

/// A self-contained slice of Augen's iOS functionality (physics, image
/// tracking, multi-user, …).
///
/// `AugenARView` owns the ARSession, the method channel and the shared node
/// registry. Features receive every method call first (in registration order)
/// and claim the ones they implement by returning `true` from `handle`.
///
/// The ARSession has exactly one configuration at a time, but several features
/// need to influence it (detection images, face tracking, frame semantics,
/// collaboration…). Instead of each feature calling `session.run` directly —
/// which would silently clobber the others' settings — features contribute to
/// a single configuration via `configure(_:)` and request a rebuild through
/// `AugenARView.applySessionConfiguration()`.
protocol AugenFeature: AnyObject {
    /// Handle a Dart method call. Return `false` if this feature does not own
    /// `call.method`; return `true` once `result` has been (or will be) called.
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool

    /// Contribute to (or replace) the session configuration. Called every time
    /// the session is (re)built. `configuration` is the result of the previous
    /// features in the chain; the returned value is passed to the next one.
    func configure(_ configuration: ARConfiguration) -> ARConfiguration

    func session(_ session: ARSession, didUpdate frame: ARFrame)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor])
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor])
    func session(_ session: ARSession, didRemove anchors: [ARAnchor])

    /// Called by the Dart `reset` call after core nodes/anchors are cleared.
    func reset()

    /// Release every resource (entities, timers, network sessions). Called
    /// from `AugenARView.deinit`.
    func dispose()
}

extension AugenFeature {
    func configure(_ configuration: ARConfiguration) -> ARConfiguration { configuration }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {}
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {}
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {}
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {}
    func reset() {}
    func dispose() {}
}

// MARK: - Shared conversion helpers

enum AugenCodec {
    static func float(_ value: Any?, _ fallback: Float = 0) -> Float {
        (value as? NSNumber)?.floatValue ?? fallback
    }

    static func double(_ value: Any?, _ fallback: Double = 0) -> Double {
        (value as? NSNumber)?.doubleValue ?? fallback
    }

    static func vector3(_ value: Any?, _ fallback: SIMD3<Float> = .zero) -> SIMD3<Float> {
        guard let map = value as? [String: Any] else { return fallback }
        return SIMD3<Float>(
            float(map["x"], fallback.x),
            float(map["y"], fallback.y),
            float(map["z"], fallback.z)
        )
    }

    static func quaternion(_ value: Any?) -> simd_quatf {
        guard let map = value as? [String: Any] else { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        return simd_quatf(
            ix: float(map["x"]), iy: float(map["y"]), iz: float(map["z"]), r: float(map["w"], 1)
        )
    }

    static func map(_ v: SIMD3<Float>) -> [String: Any] {
        ["x": Double(v.x), "y": Double(v.y), "z": Double(v.z)]
    }

    static func map(_ q: simd_quatf) -> [String: Any] {
        ["x": Double(q.imag.x), "y": Double(q.imag.y), "z": Double(q.imag.z), "w": Double(q.real)]
    }

    static func position(of transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    static func nowMillis() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

    static func invalidArguments(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil)
    }
}
