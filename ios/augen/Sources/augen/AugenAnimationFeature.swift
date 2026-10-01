import Flutter
import ARKit
import RealityKit

/// Animation playback, blending, crossfades, blend trees and state machines.
///
/// Every node gets an `AugenNodeAnimator` that mixes tracks each AR frame:
/// - Models with baked clips (USDZ/Reality) play them through RealityKit
///   `AnimationPlaybackController`s; weights map to `blendFactor`, speed and
///   seeking to `speed`/`time` (iOS 15+; on iOS 13/14 only play/pause/stop).
/// - Any node can also play the built-in procedural clips
///   (`AugenProceduralClip`: idle, walk, run, jump, spin, bounce, pulse,
///   wobble), so primitives respond to the animation API visibly.
///
/// Blend sets, crossfades, blend trees and state machines are emulated on
/// top of per-track weights, so they behave consistently for both kinds.
/// Bone masks are stored and reported, but RealityKit cannot mask joints of a
/// playing clip, so they don't change the result.
///
/// If an animation is started on a node id that doesn't exist (the example
/// app drives `character_node` without ever adding it), a small demo entity is
/// created 60 cm in front of the camera and registered under that id.
final class AugenAnimationFeature: AugenFeature {
    private weak var host: AugenARView?
    private var animators: [String: AugenNodeAnimator] = [:]
    private var transitions: [String: CrossfadeState] = [:]
    private var blendSets: [String: BlendSetState] = [:]
    private var blendTrees: [String: BlendTreeState] = [:]
    private var stateMachines: [String: StateMachineState] = [:]
    private var lastFrameTime: TimeInterval?
    private var lastTransitionBroadcast: TimeInterval = 0

    init(host: AugenARView) {
        self.host = host
    }

    // MARK: - Emulated state

    private final class CrossfadeState {
        let id: String
        let nodeId: String
        let fromId: String?
        let toId: String
        let duration: Double
        let curve: String
        var elapsed: Double = 0
        var stateMachineId: String?
        init(id: String, nodeId: String, fromId: String?, toId: String, duration: Double, curve: String) {
            self.id = id; self.nodeId = nodeId; self.fromId = fromId; self.toId = toId
            self.duration = duration; self.curve = curve
        }
        var progress: Double { duration <= 0 ? 1 : min(1, elapsed / duration) }
    }

    private struct BlendSetState {
        let id: String
        let nodeId: String
        var weights: [String: Float]
        let normalize: Bool
        let fadeOut: Double
    }

    private struct BlendTreeState {
        let id: String
        let nodeId: String
        let root: [String: Any]
        var parameters: [String: Any]
        var animationIds: Set<String>
    }

    private struct SMTransition {
        let target: String
        let duration: Double
        let curve: String
        let conditions: [String: Any]
    }

    private struct SMState {
        let id: String
        let animationId: String
        let loop: Bool
        let speed: Double
        let transitions: [SMTransition]
    }

    private final class StateMachineState {
        let id: String
        let nodeId: String
        let states: [String: SMState]
        let anyTransitions: [SMTransition]
        var parameters: [String: Any]
        var current: String
        var previous: String?
        var enteredAt: Date = Date()
        var isActive = true
        var currentTransitionId: String?
        init(id: String, nodeId: String, states: [String: SMState], anyTransitions: [SMTransition],
             parameters: [String: Any], current: String) {
            self.id = id; self.nodeId = nodeId; self.states = states; self.anyTransitions = anyTransitions
            self.parameters = parameters; self.current = current
        }
    }

    // MARK: - Dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "playAnimation": playAnimation(args, result)
        case "pauseAnimation": setState(args, .paused, result)
        case "resumeAnimation": setState(args, .playing, result)
        case "stopAnimation": stopAnimation(args, result)
        case "seekAnimation": seekAnimation(args, result)
        case "setAnimationSpeed": setSpeed(args, result)
        case "getAvailableAnimations": getAvailable(args, result)
        case "playAdditiveAnimation": playAdditive(args, result)
        case "getAnimationLayers": getLayers(args, result)
        case "setAnimationLayerWeight": setLayerWeight(args, result)
        case "setAnimationBoneMask": setBoneMask(args, result)
        case "getBoneHierarchy": getBones(args, result)
        case "playBlendSet": playBlendSet(args, result)
        case "stopBlendSet": stopBlendSet(args, result)
        case "updateBlendWeights": updateBlendWeights(args, result)
        case "startCrossfadeTransition": startCrossfade(args, result)
        case "stopTransition": stopTransition(args, result)
        case "startBlendTree": startBlendTree(args, result)
        case "stopBlendTree": stopBlendTree(args, result)
        case "updateBlendTreeParameters": updateBlendTree(args, result)
        case "startStateMachine": startStateMachine(args, result)
        case "stopStateMachine": stopStateMachine(args, result)
        case "updateStateMachineParameters": updateStateMachine(args, result)
        case "triggerStateMachineTransition": triggerStateMachine(args, result)
        default: return false
        }
        return true
    }

    // MARK: - Node / clip resolution

    private func nodeError(_ nodeId: String) -> FlutterError {
        FlutterError(code: "NODE_NOT_FOUND", message: "Node with id \(nodeId) not found", details: nil)
    }

    /// Animator for an existing node; optionally spawns a demo entity when
    /// the node doesn't exist (only for calls that start playback).
    private func animator(for nodeId: String, create: Bool) -> AugenNodeAnimator? {
        guard let host = host else { return nil }
        var entity = host.entity(forNode: nodeId)
        if entity == nil && create {
            entity = spawnDemoNode(nodeId)
        }
        guard let resolved = entity else {
            animators[nodeId] = nil
            return nil
        }
        if let existing = animators[nodeId] {
            existing.rebind(to: resolved)
            return existing
        }
        let animator = AugenNodeAnimator(nodeId: nodeId, entity: resolved)
        animators[nodeId] = animator
        return animator
    }

    private func spawnDemoNode(_ nodeId: String) -> Entity? {
        guard let host = host, host.isSessionInitialized else { return nil }
        let camera = host.arView.cameraTransform.matrix
        let forward = -SIMD3<Float>(camera.columns.2.x, camera.columns.2.y, camera.columns.2.z)
        let position = AugenCodec.position(of: camera) + simd_normalize(forward) * 0.6
        let anchor = AnchorEntity(world: position)
        anchor.name = nodeId
        let entity = AugenARView.makePrimitive(type: "cube")
        entity.name = nodeId
        entity.model?.materials = [SimpleMaterial(color: .systemPurple, isMetallic: false)]
        anchor.addChild(entity)
        host.arView.scene.addAnchor(anchor)
        host.nodes[nodeId] = anchor
        NSLog("Augen: created demo entity for animation node %@", nodeId)
        return entity
    }

    /// Baked clips with stable names (`AnimationResource.name` on iOS 15+,
    /// otherwise `animation_<index>`).
    private func bakedClips(of entity: Entity) -> [(String, AnimationResource)] {
        entity.availableAnimations.enumerated().map { index, resource in
            var name = "animation_\(index)"
            if #available(iOS 15.0, *), let clipName = resource.name, !clipName.isEmpty { name = clipName }
            return (name, resource)
        }
    }

    private func availableNames(_ entity: Entity) -> [String] {
        bakedClips(of: entity).map { $0.0 } + AugenProceduralClip.allCases.map { $0.rawValue }
    }

    /// Start (or restart) a track for `animationId` on `animator`.
    private func makeTrack(
        _ animator: AugenNodeAnimator,
        animationId: String,
        loopMode: String,
        speed: Double,
        layer: Int = 0,
        additive: Bool = false,
        weight: Float = 1,
        fadeIn: Double = 0
    ) -> AugenAnimationTrack? {
        guard let entity = animator.entity else { return nil }
        if let old = animator.tracks[animationId] {
            old.controller?.stop()
            animator.tracks[animationId] = nil
        }
        let baked = bakedClips(of: entity)
        var track: AugenAnimationTrack
        if let clip = AugenProceduralClip(rawValue: animationId.lowercased()),
           !baked.contains(where: { $0.0 == animationId }) {
            if !animator.hasProcedural { animator.rest = entity.transform }
            track = AugenAnimationTrack(animationId: animationId, clip: clip)
        } else if let match = baked.first(where: { $0.0 == animationId }) ?? (baked.count == 1 ? baked.first : nil) {
            // A single-clip model plays its clip for any requested id.
            var resource = match.1
            var duration = 0.0
            if #available(iOS 15.0, *) {
                duration = resource.definition.duration
                if loopMode == "pingPong" {
                    var definition = resource.definition
                    definition.repeatMode = .autoReverse
                    if let generated = try? AnimationResource.generate(with: definition) { resource = generated }
                } else if loopMode != "once" {
                    resource = resource.repeat()
                }
            } else if loopMode != "once" {
                resource = resource.repeat()
            }
            track = AugenAnimationTrack(animationId: animationId, resource: resource, duration: duration)
            if #available(iOS 18.0, *) {
                // Compose so several baked clips can blend on separate layers.
                let controller = entity.playAnimation(
                    resource, transitionDuration: fadeIn, blendLayerOffset: layer,
                    separateAnimatedValue: false, startsPaused: false, clock: nil, handoffType: .compose
                )
                controller.speed = Float(speed)
                track.controller = controller
            } else if #available(iOS 15.0, *) {
                let controller = entity.playAnimation(resource, transitionDuration: fadeIn, startsPaused: false)
                controller.speed = Float(speed)
                track.controller = controller
            } else {
                track.controller = entity.playAnimation(resource, transitionDuration: fadeIn, startsPaused: false)
            }
        } else {
            return nil
        }
        track.loopMode = loopMode
        track.speed = speed
        track.layer = layer
        track.additive = additive
        track.weight = fadeIn > 0 ? 0 : weight
        track.fade(to: weight, over: fadeIn)
        animator.tracks[animationId] = track
        return track
    }

    private func emitStatus(_ nodeId: String, _ track: AugenAnimationTrack) {
        var status = track.statusMap()
        status["nodeId"] = nodeId
        host?.sendEvent("onAnimationStatus", status)
    }

    private func removeTrack(_ animator: AugenNodeAnimator, _ animationId: String) {
        guard let track = animator.tracks.removeValue(forKey: animationId) else { return }
        track.controller?.stop()
        track.state = .stopped
        if track.clip != nil {
            if animator.hasProcedural { animator.apply() } else { animator.entity?.transform = animator.rest }
        }
    }

    // MARK: - Basic playback

    private func playAnimation(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let animationId = args["animationId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and animationId are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        // A plain play replaces whatever the node's base layer was doing.
        for (id, track) in animator.tracks where id != animationId && track.layer == 0 && !track.additive {
            removeTrack(animator, id)
        }
        guard let track = makeTrack(
            animator, animationId: animationId,
            loopMode: args["loopMode"] as? String ?? "loop",
            speed: AugenCodec.double(args["speed"], 1)
        ) else {
            let names = animator.entity.map { availableNames($0).joined(separator: ", ") } ?? ""
            result(FlutterError(code: "ANIMATION_NOT_FOUND",
                                message: "Animation \(animationId) not found on \(nodeId). Available: \(names)", details: nil))
            return
        }
        animator.apply()
        emitStatus(nodeId, track)
        result(nil)
    }

    private func withTrack(_ args: [String: Any], _ result: @escaping FlutterResult,
                           _ body: (AugenNodeAnimator, AugenAnimationTrack) -> Void) {
        guard let nodeId = args["nodeId"] as? String, let animationId = args["animationId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and animationId are required")); return
        }
        guard let animator = animator(for: nodeId, create: false) else { result(nodeError(nodeId)); return }
        guard let track = animator.tracks[animationId] else {
            result(FlutterError(code: "ANIMATION_NOT_PLAYING",
                                message: "Animation \(animationId) is not active on \(nodeId)", details: nil))
            return
        }
        body(animator, track)
        emitStatus(nodeId, track)
        result(nil)
    }

    private func setState(_ args: [String: Any], _ state: AugenPlaybackState, _ result: @escaping FlutterResult) {
        withTrack(args, result) { _, track in
            if state == .paused {
                track.controller?.pause()
            } else {
                track.controller?.resume()
                if track.state == .stopped { track.time = 0; track.direction = 1 }
            }
            track.state = state
        }
    }

    private func stopAnimation(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let animationId = args["animationId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and animationId are required")); return
        }
        guard let animator = animator(for: nodeId, create: false) else { result(nodeError(nodeId)); return }
        if let track = animator.tracks[animationId] {
            removeTrack(animator, animationId)
            track.time = 0
            emitStatus(nodeId, track)
        }
        result(nil)
    }

    private func seekAnimation(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let time = max(0, AugenCodec.double(args["time"]))
        withTrack(args, result) { animator, track in
            let clamped = track.duration > 0 ? min(time, track.duration) : time
            track.time = clamped
            if let controller = track.controller, #available(iOS 15.0, *) { controller.time = clamped }
            animator.apply()
        }
    }

    private func setSpeed(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let speed = AugenCodec.double(args["speed"], 1)
        withTrack(args, result) { _, track in
            track.speed = speed
            if let controller = track.controller, #available(iOS 15.0, *) { controller.speed = Float(speed) }
        }
    }

    private func getAvailable(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String else { result(AugenCodec.invalidArguments("nodeId is required")); return }
        guard let entity = host?.entity(forNode: nodeId) else { result([String]()); return }
        result(availableNames(entity))
    }

    // MARK: - Layers

    private func playAdditive(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let animationId = args["animationId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and animationId are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        let layer = (args["targetLayer"] as? NSNumber)?.intValue ?? 1
        if let mask = args["boneMask"] as? [String] { animator.boneMasks[layer] = mask }
        guard let track = makeTrack(
            animator, animationId: animationId, loopMode: args["loopMode"] as? String ?? "loop", speed: 1,
            layer: layer, additive: true, weight: AugenCodec.float(args["weight"], 1)
        ) else {
            result(FlutterError(code: "ANIMATION_NOT_FOUND", message: "Animation \(animationId) not found on \(nodeId)", details: nil))
            return
        }
        animator.apply()
        emitStatus(nodeId, track)
        result(nil)
    }

    private func getLayers(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String else { result(AugenCodec.invalidArguments("nodeId is required")); return }
        guard let animator = animators[nodeId] else { result([[String: Any]]()); return }
        var layers = Set(animator.layerWeights.keys).union(animator.boneMasks.keys)
        animator.tracks.values.forEach { layers.insert($0.layer) }
        let list: [[String: Any]] = layers.sorted().map { layer in
            let tracks = animator.tracks.values.filter { $0.layer == layer }
            return [
                "layer": layer,
                "weight": Double(animator.layerWeights[layer] ?? 1),
                "animations": tracks.map { $0.animationId }.sorted(),
                "isAdditive": tracks.contains { $0.additive },
                "boneMask": animator.boneMasks[layer] ?? [String](),
            ]
        }
        result(list)
    }

    private func setLayerWeight(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let layer = (args["layer"] as? NSNumber)?.intValue else {
            result(AugenCodec.invalidArguments("nodeId and layer are required")); return
        }
        guard let animator = animator(for: nodeId, create: false) else { result(nodeError(nodeId)); return }
        animator.layerWeights[layer] = max(0, min(1, AugenCodec.float(args["weight"], 1)))
        animator.apply()
        result(nil)
    }

    private func setBoneMask(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let layer = (args["layer"] as? NSNumber)?.intValue else {
            result(AugenCodec.invalidArguments("nodeId and layer are required")); return
        }
        guard let animator = animator(for: nodeId, create: false) else { result(nodeError(nodeId)); return }
        // Stored/reported only: RealityKit can't restrict a clip to joints.
        animator.boneMasks[layer] = args["boneMask"] as? [String] ?? []
        result(nil)
    }

    private func getBones(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String else { result(AugenCodec.invalidArguments("nodeId is required")); return }
        guard let root = host?.entity(forNode: nodeId) else { result([String]()); return }
        var joints: [String] = []
        var hierarchy: [String] = []
        func walk(_ entity: Entity, _ path: String) {
            let name = entity.name.isEmpty ? "entity" : entity.name
            let fullPath = path.isEmpty ? name : "\(path)/\(name)"
            hierarchy.append(fullPath)
            if let model = entity as? ModelEntity { joints.append(contentsOf: model.jointNames) }
            entity.children.forEach { walk($0, fullPath) }
        }
        walk(root, "")
        // Skeleton joint paths when the model is rigged, else the entity tree.
        result(joints.isEmpty ? hierarchy : joints)
    }

    // MARK: - Blend sets

    private func playBlendSet(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let set = args["blendSet"] as? [String: Any],
              let setId = set["id"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and blendSet are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        let blends = set["animations"] as? [[String: Any]] ?? []
        let normalize = set["normalizeWeights"] as? Bool ?? true
        let fadeIn = AugenCodec.double(set["fadeInDuration"], 0.3)
        var weights: [String: Float] = [:]
        for blend in blends {
            guard let id = blend["animationId"] as? String else { continue }
            weights[id] = max(0, AugenCodec.float(blend["weight"], 1))
        }
        weights = normalized(weights, normalize)
        // The blend set owns the base layer.
        for (id, track) in animator.tracks where weights[id] == nil && !track.additive {
            removeTrack(animator, id)
        }
        var missing: [String] = []
        for blend in blends {
            guard let id = blend["animationId"] as? String else { continue }
            let loop = blend["loop"] as? Bool ?? true
            let weight = weights[id] ?? 0
            if let track = animator.tracks[id], track.state != .stopped {
                track.removeWhenFaded = false
                track.fade(to: weight, over: fadeIn)
            } else if let track = makeTrack(
                animator, animationId: id, loopMode: loop ? "loop" : "once",
                speed: AugenCodec.double(blend["speed"], 1),
                layer: (blend["layer"] as? NSNumber)?.intValue ?? 0,
                additive: (blend["blendMode"] as? String) == "additive",
                weight: weight, fadeIn: fadeIn
            ) {
                track.time = AugenCodec.double(blend["timeOffset"])
                emitStatus(nodeId, track)
            } else {
                missing.append(id)
            }
        }
        blendSets[setId] = BlendSetState(id: setId, nodeId: nodeId, weights: weights, normalize: normalize,
                                         fadeOut: AugenCodec.double(set["fadeOutDuration"], 0.3))
        if !missing.isEmpty { NSLog("Augen: blend set %@ skipped unknown animations %@", setId, missing.joined(separator: ",")) }
        result(nil)
    }

    private func normalized(_ weights: [String: Float], _ normalize: Bool) -> [String: Float] {
        let total = weights.values.reduce(0, +)
        guard normalize, total > 0 else { return weights }
        return weights.mapValues { $0 / total }
    }

    private func stopBlendSet(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let setId = args["blendSetId"] as? String else { result(AugenCodec.invalidArguments("blendSetId is required")); return }
        if let set = blendSets.removeValue(forKey: setId), let animator = animators[set.nodeId] {
            for id in set.weights.keys {
                guard let track = animator.tracks[id] else { continue }
                track.fade(to: 0, over: set.fadeOut)
                track.removeWhenFaded = true
            }
        }
        result(nil)
    }

    private func updateBlendWeights(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let setId = args["blendSetId"] as? String, var set = blendSets[setId] else {
            result(FlutterError(code: "BLEND_SET_NOT_FOUND", message: "Blend set not active", details: nil)); return
        }
        let raw = args["weights"] as? [String: Any] ?? [:]
        for (id, value) in raw { set.weights[id] = max(0, AugenCodec.float(value)) }
        set.weights = normalized(set.weights, set.normalize)
        blendSets[setId] = set
        if let animator = animators[set.nodeId] {
            for (id, weight) in set.weights {
                if let track = animator.tracks[id] {
                    track.fade(to: weight, over: 0.1)
                } else if weight > 0 {
                    _ = makeTrack(animator, animationId: id, loopMode: "loop", speed: 1, weight: weight, fadeIn: 0.1)
                }
            }
        }
        result(nil)
    }

    // MARK: - Crossfades

    private func startCrossfade(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let map = args["transition"] as? [String: Any],
              let id = map["id"] as? String, let toId = map["toAnimationId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and transition are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        let fromId = map["fromAnimationId"] as? String
        // Ensure the source is playing so there's something to fade from.
        if let fromId = fromId, animator.tracks[fromId] == nil {
            _ = makeTrack(animator, animationId: fromId, loopMode: "loop", speed: 1)
        }
        guard startCrossfade(id: id, animator: animator, fromId: fromId, toId: toId,
                             duration: AugenCodec.double(map["duration"], 0.3),
                             curve: map["curve"] as? String ?? "linear", loop: true, speed: 1) else {
            result(FlutterError(code: "ANIMATION_NOT_FOUND", message: "Animation \(toId) not found on \(nodeId)", details: nil))
            return
        }
        result(nil)
    }

    @discardableResult
    private func startCrossfade(id: String, animator: AugenNodeAnimator, fromId: String?, toId: String,
                                duration: Double, curve: String, loop: Bool, speed: Double) -> Bool {
        // Interrupt any transition already running on this node.
        for (key, other) in transitions where other.nodeId == animator.nodeId {
            transitions[key] = nil
            emitTransition(other, state: "interrupted")
        }
        let target: AugenAnimationTrack
        if let existing = animator.tracks[toId], existing.state != .stopped, toId != fromId {
            existing.removeWhenFaded = false
            target = existing
        } else if let made = makeTrack(animator, animationId: toId, loopMode: loop ? "loop" : "once",
                                       speed: speed, weight: 0) {
            target = made
        } else {
            return false
        }
        target.fadeRate = 0
        let transition = CrossfadeState(id: id, nodeId: animator.nodeId, fromId: fromId, toId: toId,
                                        duration: duration, curve: curve)
        transitions[id] = transition
        emitStatus(animator.nodeId, target)
        if duration <= 0 { finishTransition(transition, animator: animator) } else { emitTransition(transition, state: "transitioning") }
        return true
    }

    private func eased(_ t: Double, _ curve: String) -> Double {
        switch curve {
        case "easeIn": return t * t
        case "easeOut": return 1 - (1 - t) * (1 - t)
        case "easeInOut", "smooth": return t * t * (3 - 2 * t)
        case "step": return t < 1 ? 0 : 1
        default: return t
        }
    }

    private func applyTransitionWeights(_ transition: CrossfadeState, animator: AugenNodeAnimator) {
        let e = Float(eased(transition.progress, transition.curve))
        // Every other base-layer track (incl. `from`) fades out with the source weight.
        for (id, track) in animator.tracks where !track.additive && track.layer == 0 {
            if id == transition.toId {
                track.weight = e; track.targetWeight = e; track.fadeRate = 0
            } else if track.removeWhenFaded == false || id == transition.fromId {
                track.weight = min(track.weight, 1 - e); track.targetWeight = track.weight; track.fadeRate = 0
            }
        }
    }

    private func finishTransition(_ transition: CrossfadeState, animator: AugenNodeAnimator) {
        transition.elapsed = transition.duration
        applyTransitionWeights(transition, animator: animator)
        for (id, track) in animator.tracks where id != transition.toId && !track.additive && track.layer == 0 {
            if track.weight <= 0.0001 { removeTrack(animator, id) }
        }
        transitions[transition.id] = nil
        emitTransition(transition, state: "completed")
    }

    private func emitTransition(_ transition: CrossfadeState, state: String) {
        let e = eased(transition.progress, transition.curve)
        var payload: [String: Any] = [
            "transitionId": transition.id,
            "state": state,
            "toAnimationId": transition.toId,
            "progress": transition.progress,
            "elapsedTime": min(transition.elapsed, transition.duration),
            "totalDuration": transition.duration,
            "sourceWeight": 1 - e,
            "targetWeight": e,
            "nodeId": transition.nodeId,
        ]
        if let fromId = transition.fromId { payload["fromAnimationId"] = fromId }
        host?.sendEvent("onTransitionStatus", payload)
    }

    private func stopTransition(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["transitionId"] as? String else { result(AugenCodec.invalidArguments("transitionId is required")); return }
        if let transition = transitions.removeValue(forKey: id) {
            // Weights stay where they were; the node keeps blending both clips.
            emitTransition(transition, state: "interrupted")
        }
        result(nil)
    }

    // MARK: - Blend trees

    /// Evaluate a blend-tree node to per-animation weights.
    private func evaluate(_ node: [String: Any], _ params: [String: Any]) -> [String: Float] {
        func scaled(_ w: [String: Float], _ f: Float) -> [String: Float] { w.mapValues { $0 * f } }
        func merge(_ a: [String: Float], _ b: [String: Float]) -> [String: Float] { a.merging(b, uniquingKeysWith: +) }
        func number(_ name: String?) -> Float { name.flatMap { AugenCodec.float(params[$0]) } ?? 0 }

        switch node["type"] as? String ?? "" {
        case "animation":
            guard let id = node["animationId"] as? String else { return [:] }
            return [id: 1]
        case "blend1D":
            let value = number(node["parameterName"] as? String)
            let points = (node["blendPoints"] as? [[String: Any]] ?? [])
                .compactMap { p -> (Float, [String: Any])? in
                    guard let child = p["child"] as? [String: Any] else { return nil }
                    return (AugenCodec.float(p["value"]), child)
                }
                .sorted { $0.0 < $1.0 }
            guard let first = points.first, let last = points.last else { return [:] }
            if value <= first.0 { return evaluate(first.1, params) }
            if value >= last.0 { return evaluate(last.1, params) }
            for i in 0..<(points.count - 1) where value >= points[i].0 && value <= points[i + 1].0 {
                let span = points[i + 1].0 - points[i].0
                let t = span > 0 ? (value - points[i].0) / span : 0
                return merge(scaled(evaluate(points[i].1, params), 1 - t), scaled(evaluate(points[i + 1].1, params), t))
            }
            return [:]
        case "blend2D":
            let pos = SIMD2<Float>(number(node["parameterX"] as? String), number(node["parameterY"] as? String))
            let points = (node["blendPoints"] as? [[String: Any]] ?? []).compactMap { p -> (SIMD2<Float>, [String: Any])? in
                guard let child = p["child"] as? [String: Any] else { return nil }
                return (SIMD2<Float>(AugenCodec.float(p["x"]), AugenCodec.float(p["y"])), child)
            }
            // Inverse-distance weighting (exact point wins outright).
            var raw: [(Float, [String: Any])] = []
            for (point, child) in points {
                let d = simd_distance(point, pos)
                if d < 0.0001 { return evaluate(child, params) }
                raw.append((1 / (d * d), child))
            }
            let total = raw.reduce(0) { $0 + $1.0 }
            guard total > 0 else { return [:] }
            return raw.reduce([:]) { merge($0, scaled(evaluate($1.1, params), $1.0 / total)) }
        case "additive":
            let base = (node["baseLayer"] as? [String: Any]).map { evaluate($0, params) } ?? [:]
            let add = (node["additiveLayer"] as? [String: Any]).map { evaluate($0, params) } ?? [:]
            return merge(base, scaled(add, AugenCodec.float(node["additiveWeight"], 1)))
        case "override":
            let w = AugenCodec.float(node["overrideWeight"], 1)
            let base = (node["baseLayer"] as? [String: Any]).map { evaluate($0, params) } ?? [:]
            let over = (node["overrideLayer"] as? [String: Any]).map { evaluate($0, params) } ?? [:]
            return merge(scaled(base, 1 - w), scaled(over, w))
        case "selector":
            let children = node["children"] as? [[String: Any]] ?? []
            guard !children.isEmpty else { return [:] }
            var index = (node["defaultIndex"] as? NSNumber)?.intValue ?? 0
            if let name = node["parameterName"] as? String, let value = params[name] as? NSNumber { index = value.intValue }
            return evaluate(children[max(0, min(children.count - 1, index))], params)
        case "conditional":
            let name = node["conditionParameter"] as? String ?? ""
            let flag = (params[name] as? Bool) ?? ((params[name] as? NSNumber)?.boolValue ?? false)
            let child = (flag ? node["trueChild"] : node["falseChild"]) as? [String: Any]
            return child.map { evaluate($0, params) } ?? [:]
        default:
            return [:]
        }
    }

    /// All animation ids referenced anywhere in a blend tree.
    private func animationIds(in node: [String: Any]) -> Set<String> {
        var ids = Set<String>()
        if let id = node["animationId"] as? String { ids.insert(id) }
        for key in ["baseLayer", "additiveLayer", "overrideLayer", "trueChild", "falseChild"] {
            if let child = node[key] as? [String: Any] { ids.formUnion(animationIds(in: child)) }
        }
        for child in node["children"] as? [[String: Any]] ?? [] { ids.formUnion(animationIds(in: child)) }
        for point in node["blendPoints"] as? [[String: Any]] ?? [] {
            if let child = point["child"] as? [String: Any] { ids.formUnion(animationIds(in: child)) }
        }
        return ids
    }

    private func applyBlendTree(_ tree: BlendTreeState, fade: Double) {
        guard let animator = animators[tree.nodeId] else { return }
        let weights = evaluate(tree.root, tree.parameters)
        for id in tree.animationIds {
            let weight = max(0, min(1, weights[id] ?? 0))
            if let track = animator.tracks[id] {
                track.removeWhenFaded = false
                track.fade(to: weight, over: fade)
            } else {
                _ = makeTrack(animator, animationId: id, loopMode: "loop", speed: 1, weight: weight, fadeIn: fade)
            }
        }
    }

    private func startBlendTree(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let map = args["blendTree"] as? [String: Any],
              let id = map["id"] as? String, let root = map["rootNode"] as? [String: Any] else {
            result(AugenCodec.invalidArguments("nodeId and blendTree are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        var params = map["defaultValues"] as? [String: Any] ?? [:]
        if let declared = map["parameters"] as? [String: Any] {
            for (name, value) in declared where params[name] == nil {
                if let def = (value as? [String: Any])?["defaultValue"] { params[name] = def }
            }
        }
        (args["initialParameters"] as? [String: Any])?.forEach { params[$0.key] = $0.value }
        let ids = animationIds(in: root)
        for (trackId, track) in animator.tracks where !ids.contains(trackId) && !track.additive {
            removeTrack(animator, trackId)
        }
        let tree = BlendTreeState(id: id, nodeId: nodeId, root: root, parameters: params, animationIds: ids)
        blendTrees[id] = tree
        applyBlendTree(tree, fade: 0.2)
        result(nil)
    }

    private func stopBlendTree(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["blendTreeId"] as? String else { result(AugenCodec.invalidArguments("blendTreeId is required")); return }
        if let tree = blendTrees.removeValue(forKey: id), let animator = animators[tree.nodeId] {
            for animationId in tree.animationIds {
                guard let track = animator.tracks[animationId] else { continue }
                track.fade(to: 0, over: 0.2)
                track.removeWhenFaded = true
            }
        }
        result(nil)
    }

    private func updateBlendTree(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["blendTreeId"] as? String, var tree = blendTrees[id] else {
            result(FlutterError(code: "BLEND_TREE_NOT_FOUND", message: "Blend tree not active", details: nil)); return
        }
        (args["parameters"] as? [String: Any])?.forEach { tree.parameters[$0.key] = $0.value }
        blendTrees[id] = tree
        applyBlendTree(tree, fade: 0.1)
        result(nil)
    }

    // MARK: - State machines

    private func parseTransitions(_ value: Any?) -> [SMTransition] {
        (value as? [[String: Any]] ?? []).compactMap { map in
            guard let target = map["toAnimationId"] as? String else { return nil }
            return SMTransition(target: target, duration: AugenCodec.double(map["duration"], 0.25),
                                curve: map["curve"] as? String ?? "linear",
                                conditions: map["conditions"] as? [String: Any] ?? [:])
        }
    }

    private func startStateMachine(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let nodeId = args["nodeId"] as? String, let map = args["stateMachine"] as? [String: Any],
              let id = map["id"] as? String else {
            result(AugenCodec.invalidArguments("nodeId and stateMachine are required")); return
        }
        guard let animator = animator(for: nodeId, create: true) else { result(nodeError(nodeId)); return }
        let stateMaps = map["states"] as? [[String: Any]] ?? []
        var states: [String: SMState] = [:]
        var entry: String?
        for s in stateMaps {
            guard let sid = s["id"] as? String else { continue }
            states[sid] = SMState(id: sid, animationId: s["animationId"] as? String ?? sid,
                                  loop: s["loop"] as? Bool ?? true, speed: AugenCodec.double(s["speed"], 1),
                                  transitions: parseTransitions(s["transitions"]))
        }
        entry = stateMaps.first { $0["isEntryState"] as? Bool ?? false }?["id"] as? String
            ?? stateMaps.first?["id"] as? String
        guard let initial = entry else {
            result(AugenCodec.invalidArguments("State machine has no states")); return
        }
        var params = map["parameters"] as? [String: Any] ?? [:]
        (args["initialParameters"] as? [String: Any])?.forEach { params[$0.key] = $0.value }
        // One state machine per node.
        for (key, other) in stateMachines where other.nodeId == nodeId { stateMachines[key] = nil }
        let machine = StateMachineState(id: id, nodeId: nodeId, states: states,
                                        anyTransitions: parseTransitions(map["anyStateTransitions"]),
                                        parameters: params, current: initial)
        stateMachines[id] = machine
        let state = states[initial]!
        for trackId in Array(animator.tracks.keys) where !(animator.tracks[trackId]?.additive ?? false) {
            removeTrack(animator, trackId)
        }
        if let track = makeTrack(animator, animationId: state.animationId, loopMode: state.loop ? "loop" : "once", speed: state.speed) {
            emitStatus(nodeId, track)
        }
        animator.apply()
        evaluateStateMachine(machine)
        emitStateMachine(machine)
        result(nil)
    }

    private func conditionsMet(_ conditions: [String: Any], _ params: [String: Any]) -> Bool {
        // Bool/String conditions must match exactly; numeric conditions are
        // thresholds (parameter >= value).
        for (name, expected) in conditions {
            let actual = params[name]
            if let flag = expected as? Bool {
                let value = (actual as? Bool) ?? ((actual as? NSNumber)?.boolValue ?? false)
                if value != flag { return false }
            } else if let threshold = expected as? NSNumber {
                guard let value = actual as? NSNumber, value.doubleValue >= threshold.doubleValue else { return false }
            } else if let text = expected as? String {
                if (actual as? String) != text { return false }
            }
        }
        return true
    }

    /// Follow the first transition (state-specific, then any-state) whose
    /// conditions hold. Transitions without conditions fire when a
    /// non-looping state's clip has finished.
    private func evaluateStateMachine(_ machine: StateMachineState, clipFinished: Bool = false) {
        guard machine.isActive, machine.currentTransitionId == nil, let state = machine.states[machine.current] else { return }
        for transition in state.transitions + machine.anyTransitions where transition.target != machine.current {
            let unconditional = transition.conditions.isEmpty
            if unconditional ? clipFinished : conditionsMet(transition.conditions, machine.parameters) {
                enter(machine, target: transition.target, duration: transition.duration, curve: transition.curve)
                return
            }
        }
    }

    private func enter(_ machine: StateMachineState, target: String, duration: Double, curve: String) {
        // Targets may name a state id or (as in AnimationTransition) an animation id.
        let resolved = machine.states[target] ?? machine.states.values.first { $0.animationId == target }
        guard let state = resolved, let animator = animators[machine.nodeId] else { return }
        let from = machine.states[machine.current]?.animationId
        machine.previous = machine.current
        machine.current = state.id
        machine.enteredAt = Date()
        let transitionId = "\(machine.id)_\(machine.previous ?? "")_\(state.id)_\(AugenCodec.nowMillis())"
        machine.currentTransitionId = transitionId
        if startCrossfade(id: transitionId, animator: animator, fromId: from, toId: state.animationId,
                          duration: duration, curve: curve, loop: state.loop, speed: state.speed) {
            transitions[transitionId]?.stateMachineId = machine.id
        }
        if transitions[transitionId] == nil { machine.currentTransitionId = nil }
        emitStateMachine(machine)
    }

    private func emitStateMachine(_ machine: StateMachineState) {
        var payload: [String: Any] = [
            "stateMachineId": machine.id,
            "currentStateId": machine.current,
            "timeInState": Date().timeIntervalSince(machine.enteredAt),
            "parameters": machine.parameters,
            "isActive": machine.isActive,
            "isPaused": false,
            "nodeId": machine.nodeId,
        ]
        if let previous = machine.previous { payload["previousStateId"] = previous }
        if let tid = machine.currentTransitionId, let transition = transitions[tid] {
            let e = eased(transition.progress, transition.curve)
            var t: [String: Any] = [
                "transitionId": tid, "state": "transitioning", "toAnimationId": transition.toId,
                "progress": transition.progress, "elapsedTime": transition.elapsed,
                "totalDuration": transition.duration, "sourceWeight": 1 - e, "targetWeight": e,
            ]
            if let from = transition.fromId { t["fromAnimationId"] = from }
            payload["currentTransition"] = t
        }
        host?.sendEvent("onStateMachineStatus", payload)
    }

    private func stopStateMachine(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["stateMachineId"] as? String else { result(AugenCodec.invalidArguments("stateMachineId is required")); return }
        if let machine = stateMachines.removeValue(forKey: id) {
            machine.isActive = false
            if let tid = machine.currentTransitionId { transitions[tid] = nil }
            machine.currentTransitionId = nil
            if let animator = animators[machine.nodeId], let state = machine.states[machine.current],
               let track = animator.tracks[state.animationId] {
                removeTrack(animator, state.animationId)
                emitStatus(machine.nodeId, track)
            }
            emitStateMachine(machine)
        }
        result(nil)
    }

    private func updateStateMachine(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["stateMachineId"] as? String, let machine = stateMachines[id] else {
            result(FlutterError(code: "STATE_MACHINE_NOT_FOUND", message: "State machine not active", details: nil)); return
        }
        (args["parameters"] as? [String: Any])?.forEach { machine.parameters[$0.key] = $0.value }
        evaluateStateMachine(machine)
        emitStateMachine(machine)
        result(nil)
    }

    private func triggerStateMachine(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["stateMachineId"] as? String, let machine = stateMachines[id],
              let target = args["targetStateId"] as? String else {
            result(FlutterError(code: "STATE_MACHINE_NOT_FOUND", message: "State machine not active", details: nil)); return
        }
        (args["parameters"] as? [String: Any])?.forEach { machine.parameters[$0.key] = $0.value }
        guard machine.states[target] != nil || machine.states.values.contains(where: { $0.animationId == target }) else {
            result(FlutterError(code: "STATE_NOT_FOUND", message: "State \(target) not found", details: nil)); return
        }
        // Use the declared transition's timing when one exists.
        let declared = (machine.states[machine.current]?.transitions ?? []) + machine.anyTransitions
        let match = declared.first { $0.target == target }
        if let tid = machine.currentTransitionId { transitions[tid] = nil; machine.currentTransitionId = nil }
        enter(machine, target: target, duration: match?.duration ?? 0.25, curve: match?.curve ?? "linear")
        result(nil)
    }

    // MARK: - Frame loop

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = frame.timestamp
        let dt = lastFrameTime.map { max(0, min(0.1, now - $0)) } ?? 0
        lastFrameTime = now
        guard dt > 0, !animators.isEmpty else { return }

        // Drop animators whose node is gone; rebind ones that were rebuilt.
        for (nodeId, animator) in animators {
            guard let entity = host?.entity(forNode: nodeId) else {
                animators[nodeId] = nil
                continue
            }
            animator.rebind(to: entity)
        }

        // Crossfades drive their tracks' weights explicitly.
        let broadcast = now - lastTransitionBroadcast >= 0.1
        if broadcast { lastTransitionBroadcast = now }
        for transition in Array(transitions.values) {
            guard let animator = animators[transition.nodeId] else { transitions[transition.id] = nil; continue }
            transition.elapsed += dt
            if transition.progress >= 1 {
                finishTransition(transition, animator: animator)
                if let smId = transition.stateMachineId, let machine = stateMachines[smId] {
                    machine.currentTransitionId = nil
                    emitStateMachine(machine)
                    evaluateStateMachine(machine)
                }
            } else {
                applyTransitionWeights(transition, animator: animator)
                if broadcast { emitTransition(transition, state: "transitioning") }
            }
        }

        for (nodeId, animator) in animators {
            for track in animator.update(dt: dt) {
                emitStatus(nodeId, track)
                for machine in stateMachines.values where machine.nodeId == nodeId
                    && machine.states[machine.current]?.animationId == track.animationId {
                    evaluateStateMachine(machine, clipFinished: true)
                }
            }
        }
    }

    // MARK: - Lifecycle

    func reset() {
        animators.values.forEach { $0.stopAll() }
        animators.removeAll()
        transitions.removeAll()
        blendSets.removeAll()
        blendTrees.removeAll()
        stateMachines.removeAll()
        lastFrameTime = nil
    }

    func dispose() {
        reset()
    }
}
