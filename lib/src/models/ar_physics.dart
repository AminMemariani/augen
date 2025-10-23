import 'vector3.dart';
import 'quaternion.dart';

/// Physics body types for AR objects
enum PhysicsBodyType { static, dynamic, kinematic }

/// Physics material properties
class PhysicsMaterial {
  final double density;
  final double friction;
  final double restitution;
  final double linearDamping;
  final double angularDamping;

  const PhysicsMaterial({
    this.density = 1.0,
    this.friction = 0.5,
    this.restitution = 0.0,
    this.linearDamping = 0.0,
    this.angularDamping = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'density': density,
      'friction': friction,
      'restitution': restitution,
      'linearDamping': linearDamping,
      'angularDamping': angularDamping,
    };
  }

  factory PhysicsMaterial.fromMap(Map<String, dynamic> map) {
    return PhysicsMaterial(
      density: (map['density'] as num).toDouble(),
      friction: (map['friction'] as num).toDouble(),
      restitution: (map['restitution'] as num).toDouble(),
      linearDamping: (map['linearDamping'] as num).toDouble(),
      angularDamping: (map['angularDamping'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhysicsMaterial &&
        other.density == density &&
        other.friction == friction &&
        other.restitution == restitution &&
        other.linearDamping == linearDamping &&
        other.angularDamping == angularDamping;
  }

  @override
  int get hashCode => Object.hash(
    density,
    friction,
    restitution,
    linearDamping,
    angularDamping,
  );

  @override
  String toString() {
    return 'PhysicsMaterial(density: $density, friction: $friction, restitution: $restitution, linearDamping: $linearDamping, angularDamping: $angularDamping)';
  }
}

/// Physics body for AR objects
class ARPhysicsBody {
  final String id;
  final String nodeId;
  final PhysicsBodyType type;
  final PhysicsMaterial material;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 scale;
  final Vector3 velocity;
  final Vector3 angularVelocity;
  final bool isActive;
  final double mass;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final Map<String, dynamic> metadata;

  ARPhysicsBody({
    required this.id,
    required this.nodeId,
    required this.type,
    required this.material,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.velocity,
    required this.angularVelocity,
    required this.isActive,
    required this.mass,
    required this.createdAt,
    required this.lastUpdated,
    this.metadata = const {},
  });

  bool get isStatic => type == PhysicsBodyType.static;
  bool get isDynamic => type == PhysicsBodyType.dynamic;
  bool get isKinematic => type == PhysicsBodyType.kinematic;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nodeId': nodeId,
      'type': type.name,
      'material': material.toMap(),
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'velocity': velocity.toMap(),
      'angularVelocity': angularVelocity.toMap(),
      'isActive': isActive,
      'mass': mass,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ARPhysicsBody.fromMap(Map<String, dynamic> map) {
    return ARPhysicsBody(
      id: map['id'] as String,
      nodeId: map['nodeId'] as String,
      type: PhysicsBodyType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PhysicsBodyType.static,
      ),
      material: PhysicsMaterial.fromMap(
        Map<String, dynamic>.from(map['material'] as Map),
      ),
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      scale: Vector3.fromMap(Map<String, dynamic>.from(map['scale'] as Map)),
      velocity: Vector3.fromMap(
        Map<String, dynamic>.from(map['velocity'] as Map),
      ),
      angularVelocity: Vector3.fromMap(
        Map<String, dynamic>.from(map['angularVelocity'] as Map),
      ),
      isActive: map['isActive'] as bool,
      mass: (map['mass'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARPhysicsBody &&
        other.id == id &&
        other.nodeId == nodeId &&
        other.type == type &&
        other.material == material &&
        other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.velocity == velocity &&
        other.angularVelocity == angularVelocity &&
        other.isActive == isActive &&
        other.mass == mass &&
        other.createdAt.millisecondsSinceEpoch ==
            createdAt.millisecondsSinceEpoch &&
        other.lastUpdated.millisecondsSinceEpoch ==
            lastUpdated.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    nodeId,
    type,
    material,
    position,
    rotation,
    scale,
    velocity,
    angularVelocity,
    isActive,
    mass,
    createdAt.millisecondsSinceEpoch,
    lastUpdated.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'ARPhysicsBody(id: $id, nodeId: $nodeId, type: $type, material: $material, position: $position, rotation: $rotation, scale: $scale, velocity: $velocity, angularVelocity: $angularVelocity, isActive: $isActive, mass: $mass, createdAt: $createdAt, lastUpdated: $lastUpdated, metadata: $metadata)';
  }
}

/// Physics constraint types
enum PhysicsConstraintType { fixed, hinge, ballSocket, slider, universal }

/// Physics constraint between two bodies
class PhysicsConstraint {
  final String id;
  final String bodyAId;
  final String bodyBId;
  final PhysicsConstraintType type;
  final Vector3 anchorA;
  final Vector3 anchorB;
  final Vector3 axisA;
  final Vector3 axisB;
  final double lowerLimit;
  final double upperLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final Map<String, dynamic> metadata;

  PhysicsConstraint({
    required this.id,
    required this.bodyAId,
    required this.bodyBId,
    required this.type,
    required this.anchorA,
    required this.anchorB,
    required this.axisA,
    required this.axisB,
    required this.lowerLimit,
    required this.upperLimit,
    required this.isActive,
    required this.createdAt,
    required this.lastUpdated,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bodyAId': bodyAId,
      'bodyBId': bodyBId,
      'type': type.name,
      'anchorA': anchorA.toMap(),
      'anchorB': anchorB.toMap(),
      'axisA': axisA.toMap(),
      'axisB': axisB.toMap(),
      'lowerLimit': lowerLimit,
      'upperLimit': upperLimit,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory PhysicsConstraint.fromMap(Map<String, dynamic> map) {
    return PhysicsConstraint(
      id: map['id'] as String,
      bodyAId: map['bodyAId'] as String,
      bodyBId: map['bodyBId'] as String,
      type: PhysicsConstraintType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PhysicsConstraintType.fixed,
      ),
      anchorA: Vector3.fromMap(
        Map<String, dynamic>.from(map['anchorA'] as Map),
      ),
      anchorB: Vector3.fromMap(
        Map<String, dynamic>.from(map['anchorB'] as Map),
      ),
      axisA: Vector3.fromMap(Map<String, dynamic>.from(map['axisA'] as Map)),
      axisB: Vector3.fromMap(Map<String, dynamic>.from(map['axisB'] as Map)),
      lowerLimit: (map['lowerLimit'] as num).toDouble(),
      upperLimit: (map['upperLimit'] as num).toDouble(),
      isActive: map['isActive'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhysicsConstraint &&
        other.id == id &&
        other.bodyAId == bodyAId &&
        other.bodyBId == bodyBId &&
        other.type == type &&
        other.anchorA == anchorA &&
        other.anchorB == anchorB &&
        other.axisA == axisA &&
        other.axisB == axisB &&
        other.lowerLimit == lowerLimit &&
        other.upperLimit == upperLimit &&
        other.isActive == isActive &&
        other.createdAt.millisecondsSinceEpoch ==
            createdAt.millisecondsSinceEpoch &&
        other.lastUpdated.millisecondsSinceEpoch ==
            lastUpdated.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    bodyAId,
    bodyBId,
    type,
    anchorA,
    anchorB,
    axisA,
    axisB,
    lowerLimit,
    upperLimit,
    isActive,
    createdAt.millisecondsSinceEpoch,
    lastUpdated.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'PhysicsConstraint(id: $id, bodyAId: $bodyAId, bodyBId: $bodyBId, type: $type, anchorA: $anchorA, anchorB: $anchorB, axisA: $axisA, axisB: $axisB, lowerLimit: $lowerLimit, upperLimit: $upperLimit, isActive: $isActive, createdAt: $createdAt, lastUpdated: $lastUpdated, metadata: $metadata)';
  }
}

/// Physics world configuration
class PhysicsWorldConfig {
  final Vector3 gravity;
  final double timeStep;
  final int maxSubSteps;
  final bool enableSleeping;
  final bool enableContinuousCollision;
  final double contactBreakingThreshold;
  final double contactERP;
  final double contactCFM;

  const PhysicsWorldConfig({
    this.gravity = const Vector3(0, -9.81, 0),
    this.timeStep = 1.0 / 60.0,
    this.maxSubSteps = 10,
    this.enableSleeping = true,
    this.enableContinuousCollision = true,
    this.contactBreakingThreshold = 0.0,
    this.contactERP = 0.2,
    this.contactCFM = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'gravity': gravity.toMap(),
      'timeStep': timeStep,
      'maxSubSteps': maxSubSteps,
      'enableSleeping': enableSleeping,
      'enableContinuousCollision': enableContinuousCollision,
      'contactBreakingThreshold': contactBreakingThreshold,
      'contactERP': contactERP,
      'contactCFM': contactCFM,
    };
  }

  factory PhysicsWorldConfig.fromMap(Map<String, dynamic> map) {
    return PhysicsWorldConfig(
      gravity: Vector3.fromMap(
        Map<String, dynamic>.from(map['gravity'] as Map),
      ),
      timeStep: (map['timeStep'] as num).toDouble(),
      maxSubSteps: map['maxSubSteps'] as int,
      enableSleeping: map['enableSleeping'] as bool,
      enableContinuousCollision: map['enableContinuousCollision'] as bool,
      contactBreakingThreshold: (map['contactBreakingThreshold'] as num)
          .toDouble(),
      contactERP: (map['contactERP'] as num).toDouble(),
      contactCFM: (map['contactCFM'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhysicsWorldConfig &&
        other.gravity == gravity &&
        other.timeStep == timeStep &&
        other.maxSubSteps == maxSubSteps &&
        other.enableSleeping == enableSleeping &&
        other.enableContinuousCollision == enableContinuousCollision &&
        other.contactBreakingThreshold == contactBreakingThreshold &&
        other.contactERP == contactERP &&
        other.contactCFM == contactCFM;
  }

  @override
  int get hashCode => Object.hash(
    gravity,
    timeStep,
    maxSubSteps,
    enableSleeping,
    enableContinuousCollision,
    contactBreakingThreshold,
    contactERP,
    contactCFM,
  );

  @override
  String toString() {
    return 'PhysicsWorldConfig(gravity: $gravity, timeStep: $timeStep, maxSubSteps: $maxSubSteps, enableSleeping: $enableSleeping, enableContinuousCollision: $enableContinuousCollision, contactBreakingThreshold: $contactBreakingThreshold, contactERP: $contactERP, contactCFM: $contactCFM)';
  }
}

/// Physics simulation status
class PhysicsStatus {
  final String status;
  final double progress;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PhysicsStatus({
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
    this.metadata = const {},
  });

  bool get isComplete => progress >= 1.0;
  bool get isSuccessful => isComplete && errorMessage == null;
  bool get isFailed => errorMessage != null;

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'progress': progress,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory PhysicsStatus.fromMap(Map<String, dynamic> map) {
    return PhysicsStatus(
      status: map['status'] as String,
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhysicsStatus &&
        other.status == status &&
        other.progress == progress &&
        other.errorMessage == errorMessage &&
        other.timestamp.millisecondsSinceEpoch ==
            timestamp.millisecondsSinceEpoch &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    status,
    progress,
    errorMessage,
    timestamp.millisecondsSinceEpoch,
    Object.hashAll(metadata.entries),
  );

  @override
  String toString() {
    return 'PhysicsStatus(status: $status, progress: $progress, errorMessage: $errorMessage, timestamp: $timestamp, metadata: $metadata)';
  }
}

bool _mapEquals(Map? a, Map? b) {
  if (a == b) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}
