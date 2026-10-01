import Flutter
import ARKit
import RealityKit

/// Rigid-body physics on top of RealityKit's built-in simulation.
///
/// - Bodies: `PhysicsBodyComponent` (dynamic/static/kinematic) +
///   `PhysicsMotionComponent` + a `CollisionComponent` (existing shapes, or a
///   box fitted to the visual bounds) on the node's visible entity.
/// - Simulation space: every `AnchorEntity` is an isolated physics world by
///   default, and each Augen node is its own world anchor. On iOS 18+ body
///   anchors opt into the shared scene simulation
///   (`anchoring.physicsSimulation = .none`) so bodies of different nodes
///   collide and joints work. On iOS 13–17 bodies only interact with
///   entities under the same anchor.
/// - Ground: dynamic bodies would otherwise fall forever, so each body anchor
///   gets an invisible static ground slab. It sits at the lowest detected
///   horizontal plane, or 1 m below the session origin (≈ floor when the
///   phone started at chest height) until a plane is found.
/// - Gravity: RealityKit's default is -9.81 m/s² on Y. A different
///   `PhysicsWorldConfig.gravity` is emulated by integrating the difference
///   into dynamic bodies' velocity every frame.
/// - Pause/stop: there's no global pause, so dynamic bodies are switched to
///   kinematic with zero velocity and restored (with their velocity) on resume.
/// - `applyForce` is a one-shot call from Dart; a single frame of force is
///   imperceptible, so it is applied over `forceWindow` seconds.
/// - Constraints: real joints on iOS 18+ (fixed, hinge → revolute, ballSocket
///   → spherical, slider → prismatic, universal → custom joint); on older iOS
///   they're recorded with `isActive: false`.
/// - `timeStep`, `maxSubSteps`, `enableSleeping`, contact ERP/CFM are stored
///   and reported but RealityKit doesn't expose them.
final class AugenPhysicsFeature: AugenFeature {
    private weak var host: AugenARView?

    private static let defaultGravity = SIMD3<Float>(0, -9.81, 0)
    private static let groundName = "augen_physics_ground"
    private static let forceWindow: Double = 0.25

    private final class Body {
        let id: String
        let nodeId: String
        var type: String
        var material: [String: Double]
        var mass: Double
        let createdAt: Int
        var lastUpdated: Int
        var isActive = true
        /// Node was created by physics (unknown id from Dart) and is removed with the body.
        let ownsNode: Bool
        weak var entity: Entity?
        var savedLinear = SIMD3<Float>(repeating: 0)
        var savedAngular = SIMD3<Float>(repeating: 0)
        var pendingForce = SIMD3<Float>(repeating: 0)
        var pendingForceRemaining: Double = 0
        var lastPosition = SIMD3<Float>(repeating: 0)
        var lastRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        var lastScale = SIMD3<Float>(repeating: 1)
        var lastVelocity = SIMD3<Float>(repeating: 0)
        var lastAngularVelocity = SIMD3<Float>(repeating: 0)

        init(id: String, nodeId: String, type: String, material: [String: Double], mass: Double, ownsNode: Bool) {
            self.id = id; self.nodeId = nodeId; self.type = type; self.material = material
            self.mass = mass; self.ownsNode = ownsNode
            createdAt = AugenCodec.nowMillis(); lastUpdated = createdAt
        }
    }

    private struct Constraint {
        let id: String
        let bodyAId: String
        let bodyBId: String
        let type: String
        let anchorA: SIMD3<Float>
        let anchorB: SIMD3<Float>
        let axisA: SIMD3<Float>
        let axisB: SIMD3<Float>
        let lowerLimit: Double
        let upperLimit: Double
        var isActive: Bool
        let createdAt: Int
        var lastUpdated: Int
        var metadata: [String: Any]
        /// Entity holding the joint (returned by `addToSimulation`).
        weak var simulationEntity: Entity?
    }

    private var bodies: [String: Body] = [:]
    private var bodyOrder: [String] = []
    private var constraints: [String: Constraint] = [:]
    private var constraintOrder: [String] = []

    private var config: [String: Any] = [
        "gravity": AugenCodec.map(AugenPhysicsFeature.defaultGravity),
        "timeStep": 1.0 / 60.0,
        "maxSubSteps": 10,
        "enableSleeping": true,
        "enableContinuousCollision": true,
        "contactBreakingThreshold": 0.0,
        "contactERP": 0.2,
        "contactCFM": 0.0,
    ]
    private var isInitialized = false
    /// Simulation running (start/resume) vs. frozen (pause/stop/disabled).
    private var isRunning = true
    private var groundY: Float = -1.0
    private var groundFromPlane = false
    private var lastFrameTime: TimeInterval?
    private var lastBroadcast: TimeInterval = 0

    init(host: AugenARView) {
        self.host = host
    }

    // MARK: - Dispatch

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isPhysicsSupported":
            // RealityKit rigid-body physics is available on every ARKit device.
            result(true)
        case "initializePhysics":
            mergeConfig(args)
            isInitialized = true
            sendStatus("initialized", progress: 0)
            result(nil)
        case "startPhysics", "resumePhysics":
            isInitialized = true
            setRunning(true)
            sendStatus("running", progress: 0)
            result(nil)
        case "pausePhysics":
            setRunning(false)
            sendStatus("paused", progress: 0)
            result(nil)
        case "stopPhysics":
            setRunning(false)
            sendStatus("stopped", progress: 1)
            result(nil)
        case "setPhysicsEnabled":
            let enabled = args["enabled"] as? Bool ?? true
            setRunning(enabled)
            sendStatus(enabled ? "running" : "paused", progress: 0)
            result(nil)
        case "isPhysicsEnabled":
            result(isRunning)
        case "setPhysicsConfig", "updatePhysicsWorldConfig":
            mergeConfig(args)
            result(nil)
        case "getPhysicsWorldConfig":
            result(config)
        case "createPhysicsBody": createBody(args, result)
        case "removePhysicsBody": removeBody(args, result)
        case "updatePhysicsBody": updateBody(args, result)
        case "getPhysicsBodies":
            result(bodyOrder.compactMap { bodies[$0] }.map(bodyMap))
        case "getPhysicsBody":
            let id = args["bodyId"] as? String ?? ""
            result(bodies[id].map(bodyMap))
        case "applyForce": applyForce(args, result)
        case "applyImpulse": applyImpulse(args, result)
        case "applyTorque": applyTorque(args, result)
        case "setVelocity": setVelocity(args, angular: false, result)
        case "setAngularVelocity": setVelocity(args, angular: true, result)
        case "createPhysicsConstraint": createConstraint(args, result)
        case "removePhysicsConstraint": removeConstraint(args, result)
        case "getPhysicsConstraints":
            result(constraintOrder.compactMap { constraints[$0] }.map(constraintMap))
        default:
            return false
        }
        return true
    }

    // MARK: - Config & status

    private func mergeConfig(_ args: [String: Any]) {
        if let gravity = args["gravity"] as? [String: Any] {
            config["gravity"] = AugenCodec.map(AugenCodec.vector3(gravity, Self.defaultGravity))
        }
        for key in ["timeStep", "contactBreakingThreshold", "contactERP", "contactCFM"] {
            if let value = args[key] as? NSNumber { config[key] = value.doubleValue }
        }
        if let value = args["maxSubSteps"] as? NSNumber { config["maxSubSteps"] = value.intValue }
        for key in ["enableSleeping", "enableContinuousCollision"] {
            if let value = args[key] as? Bool { config[key] = value }
        }
        let ccd = config["enableContinuousCollision"] as? Bool ?? true
        for body in bodies.values {
            guard let entity = body.entity, var component = entity.components[PhysicsBodyComponent.self] else { continue }
            component.isContinuousCollisionDetectionEnabled = ccd
            entity.components.set(component)
        }
    }

    private var gravity: SIMD3<Float> { AugenCodec.vector3(config["gravity"], Self.defaultGravity) }

    private func sendStatus(_ status: String, progress: Double, error: String? = nil) {
        var payload: [String: Any] = [
            "status": status,
            "progress": progress,
            "timestamp": AugenCodec.nowMillis(),
            "metadata": ["bodyCount": bodies.count, "constraintCount": constraints.count],
        ]
        if let error = error { payload["errorMessage"] = error }
        host?.sendEvent("onPhysicsStatusUpdated", payload)
    }

    private func broadcastBodies() {
        host?.sendEvent("onPhysicsBodiesUpdated", bodyOrder.compactMap { bodies[$0] }.map(bodyMap))
    }

    private func broadcastConstraints() {
        host?.sendEvent("onPhysicsConstraintsUpdated", constraintOrder.compactMap { constraints[$0] }.map(constraintMap))
    }

    // MARK: - Serialization

    private func bodyMap(_ body: Body) -> [String: Any] {
        refreshSnapshot(body)
        return [
            "id": body.id,
            "nodeId": body.nodeId,
            "type": body.type,
            "material": body.material,
            "position": AugenCodec.map(body.lastPosition),
            "rotation": AugenCodec.map(body.lastRotation),
            "scale": AugenCodec.map(body.lastScale),
            "velocity": AugenCodec.map(body.lastVelocity),
            "angularVelocity": AugenCodec.map(body.lastAngularVelocity),
            "isActive": body.isActive,
            "mass": body.mass,
            "createdAt": body.createdAt,
            "lastUpdated": body.lastUpdated,
            "metadata": ["sharedSimulation": sharesSimulation] as [String: Any],
        ]
    }

    private func constraintMap(_ c: Constraint) -> [String: Any] {
        [
            "id": c.id,
            "bodyAId": c.bodyAId,
            "bodyBId": c.bodyBId,
            "type": c.type,
            "anchorA": AugenCodec.map(c.anchorA),
            "anchorB": AugenCodec.map(c.anchorB),
            "axisA": AugenCodec.map(c.axisA),
            "axisB": AugenCodec.map(c.axisB),
            "lowerLimit": c.lowerLimit,
            "upperLimit": c.upperLimit,
            "isActive": c.isActive,
            "createdAt": c.createdAt,
            "lastUpdated": c.lastUpdated,
            "metadata": c.metadata,
        ]
    }

    private var sharesSimulation: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    /// Cache world-space transform and velocities (kept when the entity is gone).
    private func refreshSnapshot(_ body: Body) {
        guard let entity = body.entity else { return }
        let world = entity.transformMatrix(relativeTo: nil)
        body.lastPosition = AugenCodec.position(of: world)
        body.lastRotation = entity.orientation(relativeTo: nil)
        body.lastScale = entity.scale(relativeTo: nil)
        if isRunning || body.type != "dynamic", let motion = entity.components[PhysicsMotionComponent.self] {
            body.lastVelocity = motion.linearVelocity
            body.lastAngularVelocity = motion.angularVelocity
        } else if !isRunning {
            body.lastVelocity = body.savedLinear
            body.lastAngularVelocity = body.savedAngular
        }
    }

    // MARK: - Bodies

    private func bodyError(_ id: String) -> FlutterError {
        FlutterError(code: "BODY_NOT_FOUND", message: "Physics body \(id) not found", details: nil)
    }

    private func createBody(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let host = host, let nodeId = args["nodeId"] as? String else {
            result(AugenCodec.invalidArguments("nodeId is required")); return
        }
        let type = (args["type"] as? String) ?? "dynamic"
        guard ["dynamic", "static", "kinematic"].contains(type) else {
            result(AugenCodec.invalidArguments("Unknown physics body type \(type)")); return
        }
        let hasPosition = args["position"] != nil
        let position = AugenCodec.vector3(args["position"], SIMD3<Float>(0, 0, -1))

        var ownsNode = false
        var entity = host.entity(forNode: nodeId)
        if entity == nil {
            if host.nodes[nodeId] != nil {
                result(FlutterError(code: "NODE_NOT_READY", message: "Node \(nodeId) has no entity yet (model still loading)", details: nil))
                return
            }
            // Unknown node id: create a visible box for the body (the example
            // app creates bodies for ids it never added as nodes).
            let anchor = AnchorEntity(world: position)
            anchor.name = nodeId
            let box = AugenARView.makePrimitive(type: "cube")
            box.name = nodeId
            box.model?.materials = [SimpleMaterial(color: .systemGreen, isMetallic: false)]
            anchor.addChild(box)
            host.arView.scene.addAnchor(anchor)
            host.nodes[nodeId] = anchor
            entity = box
            ownsNode = true
        } else if hasPosition, let existing = entity {
            existing.setPosition(position, relativeTo: nil)
        }
        guard let target = entity else { result(bodyError(nodeId)); return }
        if args["rotation"] != nil { target.setOrientation(AugenCodec.quaternion(args["rotation"]), relativeTo: nil) }
        if args["scale"] != nil { target.scale = AugenCodec.vector3(args["scale"], SIMD3<Float>(repeating: 1)) }

        // One body per node: replace an existing one.
        if let previous = bodies.values.first(where: { $0.nodeId == nodeId }) {
            bodies[previous.id] = nil
            bodyOrder.removeAll { $0 == previous.id }
        }
        let material = Self.material(args["material"] as? [String: Any])
        let bodyId = "body_\(nodeId)"
        let body = Body(id: bodyId, nodeId: nodeId, type: type, material: material,
                        mass: max(0.001, AugenCodec.double(args["mass"], 1.0)), ownsNode: ownsNode)
        bodies[bodyId] = body
        bodyOrder.append(bodyId)
        attach(body, to: target)
        broadcastBodies()
        result(bodyId)
    }

    private static func material(_ map: [String: Any]?) -> [String: Double] {
        let map = map ?? [:]
        return [
            "density": AugenCodec.double(map["density"], 1.0),
            "friction": AugenCodec.double(map["friction"], 0.5),
            "restitution": AugenCodec.double(map["restitution"], 0.3),
            "linearDamping": AugenCodec.double(map["linearDamping"], 0.1),
            "angularDamping": AugenCodec.double(map["angularDamping"], 0.1),
        ]
    }

    private static func mode(_ type: String) -> PhysicsBodyMode {
        switch type {
        case "static": return .static
        case "kinematic": return .kinematic
        default: return .dynamic
        }
    }

    /// Collision shape for the entity: existing shapes, else a box fitted to
    /// the visual bounds (in the entity's local space).
    private func collisionShapes(for entity: Entity) -> [ShapeResource] {
        if let existing = entity.components[CollisionComponent.self], !existing.shapes.isEmpty {
            return existing.shapes
        }
        let bounds = entity.visualBounds(recursive: true, relativeTo: entity)
        let extents = simd_max(bounds.extents, SIMD3<Float>(repeating: 0.01))
        let shape = ShapeResource.generateBox(size: extents).offsetBy(translation: bounds.center)
        entity.components.set(CollisionComponent(shapes: [shape]))
        return [shape]
    }

    /// Install (or re-install) the RealityKit components for `body` on `entity`.
    private func attach(_ body: Body, to entity: Entity) {
        body.entity = entity
        let shapes = collisionShapes(for: entity)
        let material = PhysicsMaterialResource.generate(
            friction: Float(body.material["friction"] ?? 0.5),
            restitution: Float(body.material["restitution"] ?? 0.3)
        )
        let mass = PhysicsMassProperties(shape: shapes[0], mass: Float(body.mass))
        let frozen = !isRunning && body.type == "dynamic"
        var component = PhysicsBodyComponent(massProperties: mass, material: material,
                                             mode: frozen ? .kinematic : Self.mode(body.type))
        component.isContinuousCollisionDetectionEnabled = config["enableContinuousCollision"] as? Bool ?? true
        if #available(iOS 18.0, *) {
            component.linearDamping = Float(body.material["linearDamping"] ?? 0.1)
            component.angularDamping = Float(body.material["angularDamping"] ?? 0.1)
        }
        entity.components.set(component)
        if entity.components[PhysicsMotionComponent.self] == nil {
            entity.components.set(PhysicsMotionComponent())
        }
        if let anchor = host?.nodes[body.nodeId] {
            if #available(iOS 18.0, *) {
                // Join the shared scene simulation instead of the anchor's isolated one.
                anchor.anchoring.physicsSimulation = .none
            }
            placeGround(in: anchor)
        }
    }

    /// Invisible static slab at `groundY`, as a child of `anchor` (after the
    /// visible entity, which must stay `children.first`).
    private func placeGround(in anchor: AnchorEntity) {
        let ground: Entity
        if let existing = anchor.children.first(where: { $0.name == Self.groundName }) {
            ground = existing
        } else {
            ground = Entity()
            ground.name = Self.groundName
            ground.components.set(CollisionComponent(shapes: [.generateBox(size: [40, 0.02, 40])]))
            ground.components.set(PhysicsBodyComponent(
                massProperties: .default,
                material: .generate(friction: 0.6, restitution: 0.3),
                mode: .static
            ))
            anchor.addChild(ground)
        }
        let anchorPosition = anchor.position(relativeTo: nil)
        ground.setPosition([anchorPosition.x, groundY - 0.01, anchorPosition.z], relativeTo: nil)
    }

    private func detach(_ body: Body) {
        guard let host = host else { return }
        if body.ownsNode {
            if let anchor = host.nodes.removeValue(forKey: body.nodeId) {
                host.arView.scene.removeAnchor(anchor)
            }
            return
        }
        if let entity = body.entity {
            entity.components.remove(PhysicsBodyComponent.self)
            entity.components.remove(PhysicsMotionComponent.self)
        }
        if let anchor = host.nodes[body.nodeId] {
            anchor.children.first(where: { $0.name == Self.groundName })?.removeFromParent()
        }
    }

    private func removeBody(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["bodyId"] as? String else { result(AugenCodec.invalidArguments("bodyId is required")); return }
        guard let body = bodies.removeValue(forKey: id) else { result(bodyError(id)); return }
        bodyOrder.removeAll { $0 == id }
        removeConstraints(involving: id)
        detach(body)
        broadcastBodies()
        result(nil)
    }

    private func updateBody(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["bodyId"] as? String ?? args["id"] as? String else {
            result(AugenCodec.invalidArguments("bodyId is required")); return
        }
        guard let body = bodies[id], let entity = body.entity else { result(bodyError(id)); return }
        if let type = args["type"] as? String, ["dynamic", "static", "kinematic"].contains(type) { body.type = type }
        if let material = args["material"] as? [String: Any] { body.material = Self.material(material) }
        if let mass = args["mass"] as? NSNumber { body.mass = max(0.001, mass.doubleValue) }
        if let active = args["isActive"] as? Bool { body.isActive = active }
        if args["position"] != nil { entity.setPosition(AugenCodec.vector3(args["position"]), relativeTo: nil) }
        if args["rotation"] != nil { entity.setOrientation(AugenCodec.quaternion(args["rotation"]), relativeTo: nil) }
        if args["scale"] != nil { entity.scale = AugenCodec.vector3(args["scale"], SIMD3<Float>(repeating: 1)) }
        if body.isActive {
            attach(body, to: entity)
        } else {
            entity.components.remove(PhysicsBodyComponent.self)
        }
        if var motion = entity.components[PhysicsMotionComponent.self] {
            if args["velocity"] != nil { motion.linearVelocity = AugenCodec.vector3(args["velocity"]) }
            if args["angularVelocity"] != nil { motion.angularVelocity = AugenCodec.vector3(args["angularVelocity"]) }
            entity.components.set(motion)
        }
        body.lastUpdated = AugenCodec.nowMillis()
        broadcastBodies()
        result(nil)
    }

    // MARK: - Forces

    private func withDynamicBody(_ args: [String: Any], _ result: @escaping FlutterResult, _ apply: (Body, Entity) -> Void) {
        guard let id = args["bodyId"] as? String else { result(AugenCodec.invalidArguments("bodyId is required")); return }
        guard let body = bodies[id], let entity = body.entity else { result(bodyError(id)); return }
        apply(body, entity)
        body.lastUpdated = AugenCodec.nowMillis()
        result(nil)
    }

    private func addVelocity(_ entity: Entity, linear: SIMD3<Float> = .zero, angular: SIMD3<Float> = .zero) {
        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity += linear
        motion.angularVelocity += angular
        entity.components.set(motion)
    }

    /// Approximate moment of inertia (solid box from the visual bounds).
    private func inertia(_ body: Body, _ entity: Entity) -> Float {
        let e = entity.visualBounds(recursive: true, relativeTo: nil).extents
        let size = max(0.01, (e.x * e.x + e.y * e.y + e.z * e.z) / 3)
        return Float(body.mass) * size / 6
    }

    private func applyForce(_ args: [String: Any], _ result: @escaping FlutterResult) {
        withDynamicBody(args, result) { body, _ in
            // Integrated in the frame loop over `forceWindow` seconds.
            body.pendingForce = AugenCodec.vector3(args["force"])
            body.pendingForceRemaining = Self.forceWindow
        }
    }

    private func applyImpulse(_ args: [String: Any], _ result: @escaping FlutterResult) {
        withDynamicBody(args, result) { body, entity in
            let impulse = AugenCodec.vector3(args["impulse"])
            guard isRunning, body.type == "dynamic" else {
                body.savedLinear += impulse / Float(body.mass)
                return
            }
            if let physical = entity as? HasPhysicsBody {
                if args["point"] != nil {
                    physical.applyImpulse(impulse, at: AugenCodec.vector3(args["point"]), relativeTo: nil)
                } else {
                    physical.applyLinearImpulse(impulse, relativeTo: nil)
                }
            } else {
                addVelocity(entity, linear: impulse / Float(body.mass))
            }
        }
    }

    private func applyTorque(_ args: [String: Any], _ result: @escaping FlutterResult) {
        withDynamicBody(args, result) { body, entity in
            let torque = AugenCodec.vector3(args["torque"])
            // A one-shot torque is applied as the angular impulse of `forceWindow` seconds.
            let angularImpulse = torque * Float(Self.forceWindow)
            guard isRunning, body.type == "dynamic" else {
                body.savedAngular += angularImpulse / inertia(body, entity)
                return
            }
            if let physical = entity as? HasPhysicsBody {
                physical.applyAngularImpulse(angularImpulse, relativeTo: nil)
            } else {
                addVelocity(entity, angular: angularImpulse / inertia(body, entity))
            }
        }
    }

    private func setVelocity(_ args: [String: Any], angular: Bool, _ result: @escaping FlutterResult) {
        withDynamicBody(args, result) { body, entity in
            let value = AugenCodec.vector3(args[angular ? "angularVelocity" : "velocity"])
            if !isRunning && body.type == "dynamic" {
                if angular { body.savedAngular = value } else { body.savedLinear = value }
                return
            }
            var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            if angular { motion.angularVelocity = value } else { motion.linearVelocity = value }
            entity.components.set(motion)
        }
    }

    // MARK: - Run state

    private func setRunning(_ running: Bool) {
        guard running != isRunning else { return }
        isRunning = running
        for body in bodies.values where body.type == "dynamic" {
            guard let entity = body.entity, var component = entity.components[PhysicsBodyComponent.self] else { continue }
            var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            if running {
                component.mode = .dynamic
                motion.linearVelocity = body.savedLinear
                motion.angularVelocity = body.savedAngular
            } else {
                body.savedLinear = motion.linearVelocity
                body.savedAngular = motion.angularVelocity
                component.mode = .kinematic
                motion.linearVelocity = .zero
                motion.angularVelocity = .zero
            }
            entity.components.set(component)
            entity.components.set(motion)
        }
        broadcastBodies()
    }

    // MARK: - Constraints

    private func createConstraint(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let aId = args["bodyAId"] as? String, let bId = args["bodyBId"] as? String,
              let type = args["type"] as? String else {
            result(AugenCodec.invalidArguments("bodyAId, bodyBId and type are required")); return
        }
        guard let bodyA = bodies[aId] else { result(bodyError(aId)); return }
        guard let bodyB = bodies[bId] else { result(bodyError(bId)); return }
        let id = "constraint_\(UUID().uuidString.prefix(8))"
        let now = AugenCodec.nowMillis()
        var constraint = Constraint(
            id: id, bodyAId: aId, bodyBId: bId, type: type,
            anchorA: AugenCodec.vector3(args["anchorA"]), anchorB: AugenCodec.vector3(args["anchorB"]),
            axisA: AugenCodec.vector3(args["axisA"], [0, 1, 0]), axisB: AugenCodec.vector3(args["axisB"], [0, 1, 0]),
            lowerLimit: AugenCodec.double(args["lowerLimit"]), upperLimit: AugenCodec.double(args["upperLimit"]),
            isActive: false, createdAt: now, lastUpdated: now, metadata: [:], simulationEntity: nil
        )
        if #available(iOS 18.0, *), let a = bodyA.entity, let b = bodyB.entity {
            do {
                // Joint APIs are strictly @MainActor; method channel calls arrive on main.
                let snapshot = constraint
                constraint.simulationEntity = try MainActor.assumeIsolated { try self.addJoint(snapshot, a, b) }
                constraint.isActive = true
            } catch {
                constraint.metadata["error"] = error.localizedDescription
                NSLog("Augen: joint %@ could not be added: %@", id, error.localizedDescription)
            }
        } else {
            constraint.metadata["error"] = "Physics joints require iOS 18"
        }
        constraints[id] = constraint
        constraintOrder.append(id)
        broadcastConstraints()
        result(id)
    }

    @available(iOS 18.0, *)
    @MainActor
    private func addJoint(_ c: Constraint, _ a: Entity, _ b: Entity) throws -> Entity {
        // Revolute/prismatic joints act along the pin's X axis.
        func orientation(_ axis: SIMD3<Float>) -> simd_quatf {
            let n = simd_length(axis) > 0 ? simd_normalize(axis) : SIMD3<Float>(1, 0, 0)
            return simd_quatf(from: [1, 0, 0], to: n)
        }
        let pinA = a.pins.set(named: "\(c.id)_a", position: c.anchorA, orientation: orientation(c.axisA))
        let pinB = b.pins.set(named: "\(c.id)_b", position: c.anchorB, orientation: orientation(c.axisB))
        let lower = Float(c.lowerLimit), upper = Float(c.upperLimit)
        let hasLimit = upper > lower
        let joint: any PhysicsJoint
        switch c.type {
        case "hinge":
            joint = PhysicsRevoluteJoint(pin0: pinA, pin1: pinB, angularLimit: hasLimit ? lower...upper : nil)
        case "ballSocket":
            joint = PhysicsSphericalJoint(pin0: pinA, pin1: pinB)
        case "slider":
            joint = PhysicsPrismaticJoint(pin0: pinA, pin1: pinB, linearLimit: hasLimit ? lower...upper : nil)
        case "universal":
            joint = PhysicsCustomJoint(pin0: pinA, pin1: pinB, angularMotionAroundY: .unlimited, angularMotionAroundZ: .unlimited)
        default:
            joint = PhysicsFixedJoint(pin0: pinA, pin1: pinB)
        }
        return try joint.addToSimulation()
    }

    private func removeConstraint(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let id = args["constraintId"] as? String else { result(AugenCodec.invalidArguments("constraintId is required")); return }
        guard let constraint = constraints.removeValue(forKey: id) else {
            result(FlutterError(code: "CONSTRAINT_NOT_FOUND", message: "Constraint \(id) not found", details: nil)); return
        }
        constraintOrder.removeAll { $0 == id }
        dropJoint(constraint)
        broadcastConstraints()
        result(nil)
    }

    private func dropJoint(_ c: Constraint) {
        guard #available(iOS 18.0, *) else { return }
        let a = bodies[c.bodyAId]?.entity, b = bodies[c.bodyBId]?.entity
        MainActor.assumeIsolated { Self.removeJoint(c, holder: c.simulationEntity, a: a, b: b) }
    }

    @available(iOS 18.0, *)
    @MainActor
    private static func removeJoint(_ c: Constraint, holder: Entity?, a: Entity?, b: Entity?) {
        if let holder = c.simulationEntity, var component = holder.components[PhysicsJointsComponent.self] {
            component.joints = PhysicsJoints(component.joints.filter { $0.pin0.name != "\(c.id)_a" })
            holder.components.set(component)
        }
        a?.pins.remove(named: "\(c.id)_a")
        b?.pins.remove(named: "\(c.id)_b")
    }

    private func removeConstraints(involving bodyId: String) {
        let ids = constraintOrder.filter { constraints[$0]?.bodyAId == bodyId || constraints[$0]?.bodyBId == bodyId }
        guard !ids.isEmpty else { return }
        for id in ids {
            if let c = constraints.removeValue(forKey: id) { dropJoint(c) }
        }
        constraintOrder.removeAll { ids.contains($0) }
        broadcastConstraints()
    }

    // MARK: - Session callbacks

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { updateGround(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { updateGround(anchors) }

    /// Track the lowest horizontal plane below the camera as the floor.
    private func updateGround(_ anchors: [ARAnchor]) {
        guard let host = host else { return }
        let cameraY = host.arView.cameraTransform.translation.y
        var lowest: Float?
        for case let plane as ARPlaneAnchor in anchors where plane.alignment == .horizontal {
            let y = (plane.transform * SIMD4<Float>(plane.center, 1)).y
            if y < cameraY - 0.3 { lowest = min(lowest ?? y, y) }
        }
        // First detected floor replaces the default; afterwards only move down
        // (a lower plane is the real floor, higher ones are tables etc.).
        guard let floor = lowest, !groundFromPlane || floor < groundY - 0.02 else { return }
        groundFromPlane = true
        groundY = floor
        for body in bodies.values {
            if let anchor = host.nodes[body.nodeId] { placeGround(in: anchor) }
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = frame.timestamp
        let dt = lastFrameTime.map { max(0, min(0.1, now - $0)) } ?? 0
        lastFrameTime = now
        guard let host = host, !bodies.isEmpty else { return }

        var changed = false
        for body in Array(bodies.values) {
            // Node removed by Dart → drop the body.
            guard host.nodes[body.nodeId] != nil else {
                bodies[body.id] = nil
                bodyOrder.removeAll { $0 == body.id }
                removeConstraints(involving: body.id)
                changed = true
                continue
            }
            // Node rebuilt by updateNode → re-install components on the new entity.
            if let current = host.entity(forNode: body.nodeId), current !== body.entity {
                attach(body, to: current)
            }
            guard isRunning, body.isActive, body.type == "dynamic", let entity = body.entity, dt > 0 else { continue }

            var deltaV = SIMD3<Float>(repeating: 0)
            let gravityDelta = gravity - Self.defaultGravity
            if simd_length(gravityDelta) > 0.0001 { deltaV += gravityDelta * Float(dt) }
            if body.pendingForceRemaining > 0 {
                let step = min(dt, body.pendingForceRemaining)
                deltaV += body.pendingForce / Float(body.mass) * Float(step)
                body.pendingForceRemaining -= step
            }
            if deltaV != .zero { addVelocity(entity, linear: deltaV) }
        }

        // ~10 Hz position/velocity updates while simulating.
        if changed || (isRunning && now - lastBroadcast >= 0.1) {
            lastBroadcast = now
            let time = AugenCodec.nowMillis()
            for body in bodies.values where body.type != "static" { body.lastUpdated = time }
            broadcastBodies()
        }
    }

    // MARK: - Lifecycle

    func reset() {
        // Core already removed every node anchor (incl. ones physics created).
        bodies.removeAll()
        bodyOrder.removeAll()
        constraints.removeAll()
        constraintOrder.removeAll()
        groundY = -1.0
        groundFromPlane = false
        lastFrameTime = nil
        broadcastBodies()
        broadcastConstraints()
    }

    func dispose() {
        bodies.removeAll()
        constraints.removeAll()
    }
}
