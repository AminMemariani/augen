import ARKit
import RealityKit

// Playback primitives for AugenAnimationFeature: procedural clips, tracks and
// the per-node mixer.

/// Additive pose offset produced by a procedural clip (relative to the
/// entity's rest transform). `rotation` is Euler XYZ in radians, `scale` is a
/// delta (0 = unchanged).
struct AugenPose {
    var translation = SIMD3<Float>(repeating: 0)
    var rotation = SIMD3<Float>(repeating: 0)
    var scale = SIMD3<Float>(repeating: 0)

    static func + (a: AugenPose, b: AugenPose) -> AugenPose {
        AugenPose(translation: a.translation + b.translation, rotation: a.rotation + b.rotation, scale: a.scale + b.scale)
    }

    func weighted(_ w: Float) -> AugenPose {
        AugenPose(translation: translation * w, rotation: rotation * w, scale: scale * w)
    }

    var quaternion: simd_quatf {
        simd_quatf(angle: rotation.y, axis: [0, 1, 0])
            * simd_quatf(angle: rotation.x, axis: [1, 0, 0])
            * simd_quatf(angle: rotation.z, axis: [0, 0, 1])
    }
}

/// Built-in transform animations so nodes without baked clips (primitives,
/// static models, placeholders) still animate visibly. Names match the ones
/// the example app uses (`idle`, `walk`, `run`, `jump`) plus a few extras.
enum AugenProceduralClip: String, CaseIterable {
    case idle, walk, run, jump, spin, bounce, pulse, wobble

    var duration: Double {
        switch self {
        case .idle, .spin: return 2.0
        case .walk, .jump, .pulse, .wobble: return 1.0
        case .run: return 0.5
        case .bounce: return 0.8
        }
    }

    func pose(at time: Double) -> AugenPose {
        let p = Float(max(0, min(1, time / duration)))
        let theta = 2 * Float.pi * p
        var pose = AugenPose()
        switch self {
        case .idle:
            pose.translation.y = 0.01 * sin(theta)
            pose.scale = SIMD3<Float>(repeating: 0.03 * sin(theta))
        case .walk:
            pose.translation.y = 0.015 * abs(sin(theta))
            pose.translation.x = 0.02 * sin(theta)
            pose.rotation.z = 0.12 * sin(theta)
        case .run:
            pose.translation.y = 0.035 * abs(sin(theta))
            pose.rotation.x = -0.15
            pose.rotation.z = 0.15 * sin(theta)
        case .jump:
            let arc = 4 * p * (1 - p)
            pose.translation.y = 0.25 * arc
            pose.scale = SIMD3<Float>(-0.05 * arc, 0.12 * arc, -0.05 * arc)
        case .spin:
            pose.rotation.y = theta
        case .bounce:
            pose.translation.y = 0.15 * sin(Float.pi * p)
        case .pulse:
            pose.scale = SIMD3<Float>(repeating: 0.2 * sin(theta))
        case .wobble:
            pose.rotation.z = 0.3 * sin(theta)
            pose.rotation.x = 0.15 * cos(theta)
        }
        return pose
    }
}

enum AugenPlaybackState: String {
    case stopped, playing, paused
}

/// One playing animation on a node — either a procedural clip or a baked
/// RealityKit clip driven through an `AnimationPlaybackController`.
final class AugenAnimationTrack {
    let animationId: String
    let clip: AugenProceduralClip?
    let resource: AnimationResource?
    var controller: AnimationPlaybackController?
    let duration: Double
    var time: Double = 0
    var speed: Double = 1
    var loopMode = "loop"
    var direction: Double = 1
    var state: AugenPlaybackState = .playing
    var layer = 0
    var additive = false

    /// Current mix weight and the weight it is fading towards.
    var weight: Float = 1
    var targetWeight: Float = 1
    /// Weight units per second (0 = jump immediately).
    var fadeRate: Float = 0
    /// Remove the track once its weight reaches zero.
    var removeWhenFaded = false

    init(animationId: String, clip: AugenProceduralClip) {
        self.animationId = animationId
        self.clip = clip
        self.resource = nil
        self.duration = clip.duration
    }

    init(animationId: String, resource: AnimationResource, duration: Double) {
        self.animationId = animationId
        self.clip = nil
        self.resource = resource
        self.duration = duration
    }

    var isLooping: Bool { loopMode != "once" }

    func fade(to target: Float, over seconds: Double) {
        targetWeight = max(0, target)
        if seconds <= 0 {
            weight = targetWeight
            fadeRate = 0
        } else {
            fadeRate = Float(Double(abs(targetWeight - weight)) / seconds)
        }
    }

    /// Advance time; returns true when a `once` animation just finished.
    func advance(_ dt: Double) -> Bool {
        if fadeRate > 0, weight != targetWeight {
            let step = fadeRate * Float(dt)
            weight = weight < targetWeight ? min(targetWeight, weight + step) : max(targetWeight, weight - step)
        } else {
            weight = targetWeight
        }
        guard state == .playing else { return false }

        if let controller = controller {
            if #available(iOS 15.0, *) {
                time = controller.time
                if loopMode == "once", !controller.isPlaying, time > 0 {
                    state = .stopped
                    return true
                }
            }
            return false
        }

        guard duration > 0 else { return false }
        time += dt * speed * direction
        switch loopMode {
        case "once":
            if time >= duration || time < 0 {
                time = max(0, min(duration, time))
                state = .stopped
                return true
            }
        case "pingPong":
            if time >= duration {
                time = duration - (time - duration)
                direction = -direction
            } else if time < 0 {
                time = -time
                direction = -direction
            }
        default:
            time = time.truncatingRemainder(dividingBy: duration)
            if time < 0 { time += duration }
        }
        return false
    }

    func statusMap() -> [String: Any] {
        [
            "animationId": animationId,
            "state": state.rawValue,
            "currentTime": time,
            "duration": duration,
            "isLooping": isLooping,
        ]
    }
}

/// Mixes the tracks of a single node and writes the result to its entity.
final class AugenNodeAnimator {
    let nodeId: String
    private(set) weak var entity: Entity?
    var rest: Transform
    var tracks: [String: AugenAnimationTrack] = [:]
    var layerWeights: [Int: Float] = [:]
    var boneMasks: [Int: [String]] = [:]

    init(nodeId: String, entity: Entity) {
        self.nodeId = nodeId
        self.entity = entity
        self.rest = entity.transform
    }

    /// Re-bind to a new entity (e.g. after `updateNode` rebuilt the node).
    func rebind(to entity: Entity) {
        guard self.entity !== entity else { return }
        tracks.values.forEach { $0.controller?.stop(); $0.controller = nil }
        tracks = tracks.filter { $0.value.clip != nil }
        self.entity = entity
        rest = entity.transform
    }

    var hasProcedural: Bool { tracks.values.contains { $0.clip != nil && $0.state != .stopped } }

    /// Advance all tracks. Returns tracks that finished (state changed to
    /// stopped by reaching the end of a `once` clip).
    func update(dt: Double) -> [AugenAnimationTrack] {
        var finished: [AugenAnimationTrack] = []
        for track in tracks.values where track.advance(dt) {
            finished.append(track)
        }
        // Drop tracks that were faded out on purpose.
        for (key, track) in tracks where track.removeWhenFaded && track.weight <= 0.0001 {
            track.controller?.stop()
            tracks[key] = nil
        }
        apply()
        return finished
    }

    /// Write the blended procedural pose (and baked blend factors) to the entity.
    func apply() {
        guard let entity = entity else { return }
        var base = AugenPose()
        var baseWeight: Float = 0
        var additive = AugenPose()
        var anyProcedural = false

        for track in tracks.values {
            let layerWeight = layerWeights[track.layer] ?? 1
            let w = track.weight * layerWeight
            if let controller = track.controller {
                if #available(iOS 15.0, *) { controller.blendFactor = max(0, min(1, w)) }
                continue
            }
            guard let clip = track.clip, track.state != .stopped else { continue }
            anyProcedural = true
            let pose = clip.pose(at: track.time).weighted(w)
            if track.additive {
                additive = additive + pose
            } else {
                base = base + pose
                baseWeight += w
            }
        }
        guard anyProcedural else {
            if !tracks.values.contains(where: { $0.clip != nil }) { return }
            entity.transform = rest
            return
        }
        // Normalise only when weights over-sum, so partial weights blend
        // towards the rest pose (fade in/out).
        if baseWeight > 1 { base = base.weighted(1 / baseWeight) }
        let pose = base + additive
        var transform = rest
        transform.translation = rest.translation + pose.translation
        transform.rotation = rest.rotation * pose.quaternion
        transform.scale = rest.scale * (SIMD3<Float>(repeating: 1) + pose.scale)
        entity.transform = transform
    }

    /// Stop everything and restore the rest pose.
    func stopAll() {
        tracks.values.forEach { $0.controller?.stop() }
        let hadProcedural = tracks.values.contains { $0.clip != nil }
        tracks.removeAll()
        if hadProcedural { entity?.transform = rest }
    }
}
