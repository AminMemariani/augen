import 'vector3.dart';
import 'quaternion.dart';

/// Types of occlusion supported by the AR system
enum OcclusionType {
  /// No occlusion - virtual objects appear in front of real objects
  none,

  /// Depth-based occlusion using depth maps
  depth,

  /// Person occlusion using person segmentation
  person,

  /// Plane occlusion using detected planes
  plane,
}

/// Occlusion configuration for realistic rendering
class AROcclusion {
  /// Unique identifier for the occlusion
  final String id;

  /// Type of occlusion being used
  final OcclusionType type;

  /// Whether occlusion is currently active
  final bool isActive;

  /// Position of the occlusion in 3D space
  final Vector3 position;

  /// Rotation of the occlusion
  final Quaternion rotation;

  /// Scale of the occlusion
  final Vector3 scale;

  /// Confidence level of the occlusion (0.0 to 1.0)
  final double confidence;

  /// Timestamp when occlusion was created
  final DateTime createdAt;

  /// Timestamp when occlusion was last updated
  final DateTime lastUpdated;

  /// Additional metadata for the occlusion
  final Map<String, dynamic> metadata;

  const AROcclusion({
    required this.id,
    required this.type,
    required this.isActive,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.confidence,
    required this.createdAt,
    required this.lastUpdated,
    this.metadata = const {},
  });

  /// Creates an AROcclusion from a map
  factory AROcclusion.fromMap(Map<String, dynamic> map) {
    return AROcclusion(
      id: map['id'] as String,
      type: OcclusionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OcclusionType.none,
      ),
      isActive: map['isActive'] as bool,
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      scale: Vector3.fromMap(Map<String, dynamic>.from(map['scale'] as Map)),
      confidence: (map['confidence'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        map['lastUpdated'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Converts the AROcclusion to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'isActive': isActive,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'confidence': confidence,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  /// Creates a copy of this AROcclusion with the given fields replaced
  AROcclusion copyWith({
    String? id,
    OcclusionType? type,
    bool? isActive,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    double? confidence,
    DateTime? createdAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return AROcclusion(
      id: id ?? this.id,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Whether the occlusion is reliable based on confidence
  bool get isReliable => confidence > 0.7;

  /// Whether the occlusion is recent (updated within last 5 seconds)
  bool get isRecent => DateTime.now().difference(lastUpdated).inSeconds < 5;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AROcclusion &&
        other.id == id &&
        other.type == type &&
        other.isActive == isActive &&
        other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.confidence == confidence &&
        other.createdAt == createdAt &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      isActive,
      position,
      rotation,
      scale,
      confidence,
      createdAt,
      lastUpdated,
    );
  }

  @override
  String toString() {
    return 'AROcclusion(id: $id, type: $type, isActive: $isActive, '
        'position: $position, rotation: $rotation, scale: $scale, '
        'confidence: $confidence, createdAt: $createdAt, '
        'lastUpdated: $lastUpdated)';
  }
}

/// Occlusion status for real-time updates
class OcclusionStatus {
  /// ID of the occlusion this status refers to
  final String occlusionId;

  /// Current status of the occlusion
  final String status;

  /// Progress of occlusion processing (0.0 to 1.0)
  final double progress;

  /// Error message if any
  final String? errorMessage;

  /// Timestamp of this status update
  final DateTime timestamp;

  const OcclusionStatus({
    required this.occlusionId,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
  });

  /// Creates an OcclusionStatus from a map
  factory OcclusionStatus.fromMap(Map<String, dynamic> map) {
    return OcclusionStatus(
      occlusionId: map['occlusionId'] as String,
      status: map['status'] as String,
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Converts the OcclusionStatus to a map
  Map<String, dynamic> toMap() {
    return {
      'occlusionId': occlusionId,
      'status': status,
      'progress': progress,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Whether the occlusion processing is complete
  bool get isComplete => progress >= 1.0;

  /// Whether the occlusion processing was successful
  bool get isSuccessful => isComplete && errorMessage == null;

  /// Whether the occlusion processing failed
  bool get isFailed => errorMessage != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OcclusionStatus &&
        other.occlusionId == occlusionId &&
        other.status == status &&
        other.progress == progress &&
        other.errorMessage == errorMessage &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(occlusionId, status, progress, errorMessage, timestamp);
  }

  @override
  String toString() {
    return 'OcclusionStatus(occlusionId: $occlusionId, status: $status, '
        'progress: $progress, errorMessage: $errorMessage, '
        'timestamp: $timestamp)';
  }
}
