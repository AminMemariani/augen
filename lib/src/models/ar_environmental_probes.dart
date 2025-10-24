import 'package:augen/src/models/vector3.dart';
import 'package:augen/src/models/quaternion.dart';

/// Types of environmental probes
enum ARProbeType {
  /// Spherical probe for omnidirectional reflections
  spherical,

  /// Box probe for directional reflections
  box,

  /// Planar probe for flat surface reflections
  planar,
}

/// Environmental probe update modes
enum ARProbeUpdateMode {
  /// Update probe automatically based on scene changes
  automatic,

  /// Update probe manually when requested
  manual,

  /// Update probe when objects move within influence radius
  onMovement,
}

/// Environmental probe quality levels
enum ARProbeQuality {
  /// Low quality, fast processing
  low,

  /// Medium quality, balanced performance
  medium,

  /// High quality, detailed reflections
  high,

  /// Ultra quality, maximum detail
  ultra,
}

/// Environmental probe data model
class AREnvironmentalProbe {
  /// Unique identifier for the probe
  final String id;

  /// Type of environmental probe
  final ARProbeType type;

  /// Position of the probe in 3D space
  final Vector3 position;

  /// Rotation of the probe
  final Quaternion rotation;

  /// Scale of the probe
  final Vector3 scale;

  /// Influence radius of the probe
  final double influenceRadius;

  /// Update mode for the probe
  final ARProbeUpdateMode updateMode;

  /// Quality level of the probe
  final ARProbeQuality quality;

  /// Whether the probe is active
  final bool isActive;

  /// Whether the probe captures reflections
  final bool captureReflections;

  /// Whether the probe captures lighting
  final bool captureLighting;

  /// Resolution of the probe texture
  final int textureResolution;

  /// Whether the probe is real-time
  final bool isRealTime;

  /// Update frequency in seconds (for real-time probes)
  final double updateFrequency;

  /// Confidence level of the probe (0.0 to 1.0)
  final double confidence;

  /// Timestamp when the probe was created
  final DateTime createdAt;

  /// Timestamp when the probe was last updated
  final DateTime lastModified;

  /// Additional metadata for the probe
  final Map<String, dynamic> metadata;

  const AREnvironmentalProbe({
    required this.id,
    required this.type,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.influenceRadius,
    required this.updateMode,
    required this.quality,
    required this.isActive,
    required this.captureReflections,
    required this.captureLighting,
    required this.textureResolution,
    required this.isRealTime,
    required this.updateFrequency,
    required this.confidence,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
  });

  /// Create a copy of this probe with modified properties
  AREnvironmentalProbe copyWith({
    String? id,
    ARProbeType? type,
    Vector3? position,
    Quaternion? rotation,
    Vector3? scale,
    double? influenceRadius,
    ARProbeUpdateMode? updateMode,
    ARProbeQuality? quality,
    bool? isActive,
    bool? captureReflections,
    bool? captureLighting,
    int? textureResolution,
    bool? isRealTime,
    double? updateFrequency,
    double? confidence,
    DateTime? createdAt,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
  }) {
    return AREnvironmentalProbe(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      influenceRadius: influenceRadius ?? this.influenceRadius,
      updateMode: updateMode ?? this.updateMode,
      quality: quality ?? this.quality,
      isActive: isActive ?? this.isActive,
      captureReflections: captureReflections ?? this.captureReflections,
      captureLighting: captureLighting ?? this.captureLighting,
      textureResolution: textureResolution ?? this.textureResolution,
      isRealTime: isRealTime ?? this.isRealTime,
      updateFrequency: updateFrequency ?? this.updateFrequency,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'position': position.toMap(),
      'rotation': rotation.toMap(),
      'scale': scale.toMap(),
      'influenceRadius': influenceRadius,
      'updateMode': updateMode.name,
      'quality': quality.name,
      'isActive': isActive,
      'captureReflections': captureReflections,
      'captureLighting': captureLighting,
      'textureResolution': textureResolution,
      'isRealTime': isRealTime,
      'updateFrequency': updateFrequency,
      'confidence': confidence,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  /// Create from map for deserialization
  factory AREnvironmentalProbe.fromMap(Map<String, dynamic> map) {
    return AREnvironmentalProbe(
      id: map['id'] as String,
      type: ARProbeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ARProbeType.spherical,
      ),
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      scale: Vector3.fromMap(Map<String, dynamic>.from(map['scale'] as Map)),
      influenceRadius: (map['influenceRadius'] as num).toDouble(),
      updateMode: ARProbeUpdateMode.values.firstWhere(
        (e) => e.name == map['updateMode'],
        orElse: () => ARProbeUpdateMode.automatic,
      ),
      quality: ARProbeQuality.values.firstWhere(
        (e) => e.name == map['quality'],
        orElse: () => ARProbeQuality.medium,
      ),
      isActive: map['isActive'] as bool,
      captureReflections: map['captureReflections'] as bool,
      captureLighting: map['captureLighting'] as bool,
      textureResolution: map['textureResolution'] as int,
      isRealTime: map['isRealTime'] as bool,
      updateFrequency: (map['updateFrequency'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['lastModified'] as int,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Check if probe is reliable based on confidence
  bool get isReliable => confidence >= 0.7;

  /// Check if probe is high quality
  bool get isHighQuality =>
      quality == ARProbeQuality.high || quality == ARProbeQuality.ultra;

  /// Check if probe needs updating
  bool get needsUpdate {
    if (!isRealTime) return false;
    final now = DateTime.now();
    final timeSinceUpdate = now.difference(lastModified).inSeconds;
    return timeSinceUpdate >= updateFrequency;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AREnvironmentalProbe &&
        other.id == id &&
        other.type == type &&
        other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.influenceRadius == influenceRadius &&
        other.updateMode == updateMode &&
        other.quality == quality &&
        other.isActive == isActive &&
        other.captureReflections == captureReflections &&
        other.captureLighting == captureLighting &&
        other.textureResolution == textureResolution &&
        other.isRealTime == isRealTime &&
        other.updateFrequency == updateFrequency &&
        other.confidence == confidence &&
        other.createdAt == createdAt &&
        other.lastModified == lastModified;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      position,
      rotation,
      scale,
      influenceRadius,
      updateMode,
      quality,
      isActive,
      captureReflections,
      captureLighting,
      textureResolution,
      isRealTime,
      updateFrequency,
      confidence,
      createdAt,
      lastModified,
    );
  }

  @override
  String toString() {
    return 'AREnvironmentalProbe(id: $id, type: $type, position: $position, '
        'influenceRadius: $influenceRadius, quality: $quality, isActive: $isActive)';
  }
}

/// Environmental probe configuration
class AREnvironmentalProbeConfig {
  /// Whether environmental probes are enabled globally
  final bool enableProbes;

  /// Default probe quality
  final ARProbeQuality defaultQuality;

  /// Default probe update mode
  final ARProbeUpdateMode defaultUpdateMode;

  /// Default texture resolution
  final int defaultTextureResolution;

  /// Maximum number of active probes
  final int maxActiveProbes;

  /// Default influence radius
  final double defaultInfluenceRadius;

  /// Whether to use real-time updates by default
  final bool defaultRealTime;

  /// Default update frequency in seconds
  final double defaultUpdateFrequency;

  /// Whether to automatically create probes
  final bool autoCreateProbes;

  /// Whether to optimize probe placement
  final bool optimizePlacement;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  const AREnvironmentalProbeConfig({
    required this.enableProbes,
    required this.defaultQuality,
    required this.defaultUpdateMode,
    required this.defaultTextureResolution,
    required this.maxActiveProbes,
    required this.defaultInfluenceRadius,
    required this.defaultRealTime,
    required this.defaultUpdateFrequency,
    required this.autoCreateProbes,
    required this.optimizePlacement,
    this.metadata = const {},
  });

  /// Create a copy of this config with modified properties
  AREnvironmentalProbeConfig copyWith({
    bool? enableProbes,
    ARProbeQuality? defaultQuality,
    ARProbeUpdateMode? defaultUpdateMode,
    int? defaultTextureResolution,
    int? maxActiveProbes,
    double? defaultInfluenceRadius,
    bool? defaultRealTime,
    double? defaultUpdateFrequency,
    bool? autoCreateProbes,
    bool? optimizePlacement,
    Map<String, dynamic>? metadata,
  }) {
    return AREnvironmentalProbeConfig(
      enableProbes: enableProbes ?? this.enableProbes,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultUpdateMode: defaultUpdateMode ?? this.defaultUpdateMode,
      defaultTextureResolution:
          defaultTextureResolution ?? this.defaultTextureResolution,
      maxActiveProbes: maxActiveProbes ?? this.maxActiveProbes,
      defaultInfluenceRadius:
          defaultInfluenceRadius ?? this.defaultInfluenceRadius,
      defaultRealTime: defaultRealTime ?? this.defaultRealTime,
      defaultUpdateFrequency:
          defaultUpdateFrequency ?? this.defaultUpdateFrequency,
      autoCreateProbes: autoCreateProbes ?? this.autoCreateProbes,
      optimizePlacement: optimizePlacement ?? this.optimizePlacement,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'enableProbes': enableProbes,
      'defaultQuality': defaultQuality.name,
      'defaultUpdateMode': defaultUpdateMode.name,
      'defaultTextureResolution': defaultTextureResolution,
      'maxActiveProbes': maxActiveProbes,
      'defaultInfluenceRadius': defaultInfluenceRadius,
      'defaultRealTime': defaultRealTime,
      'defaultUpdateFrequency': defaultUpdateFrequency,
      'autoCreateProbes': autoCreateProbes,
      'optimizePlacement': optimizePlacement,
      'metadata': metadata,
    };
  }

  /// Create from map for deserialization
  factory AREnvironmentalProbeConfig.fromMap(Map<String, dynamic> map) {
    return AREnvironmentalProbeConfig(
      enableProbes: map['enableProbes'] as bool,
      defaultQuality: ARProbeQuality.values.firstWhere(
        (e) => e.name == map['defaultQuality'],
        orElse: () => ARProbeQuality.medium,
      ),
      defaultUpdateMode: ARProbeUpdateMode.values.firstWhere(
        (e) => e.name == map['defaultUpdateMode'],
        orElse: () => ARProbeUpdateMode.automatic,
      ),
      defaultTextureResolution: map['defaultTextureResolution'] as int,
      maxActiveProbes: map['maxActiveProbes'] as int,
      defaultInfluenceRadius: (map['defaultInfluenceRadius'] as num).toDouble(),
      defaultRealTime: map['defaultRealTime'] as bool,
      defaultUpdateFrequency: (map['defaultUpdateFrequency'] as num).toDouble(),
      autoCreateProbes: map['autoCreateProbes'] as bool,
      optimizePlacement: map['optimizePlacement'] as bool,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AREnvironmentalProbeConfig &&
        other.enableProbes == enableProbes &&
        other.defaultQuality == defaultQuality &&
        other.defaultUpdateMode == defaultUpdateMode &&
        other.defaultTextureResolution == defaultTextureResolution &&
        other.maxActiveProbes == maxActiveProbes &&
        other.defaultInfluenceRadius == defaultInfluenceRadius &&
        other.defaultRealTime == defaultRealTime &&
        other.defaultUpdateFrequency == defaultUpdateFrequency &&
        other.autoCreateProbes == autoCreateProbes &&
        other.optimizePlacement == optimizePlacement;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableProbes,
      defaultQuality,
      defaultUpdateMode,
      defaultTextureResolution,
      maxActiveProbes,
      defaultInfluenceRadius,
      defaultRealTime,
      defaultUpdateFrequency,
      autoCreateProbes,
      optimizePlacement,
    );
  }

  @override
  String toString() {
    return 'AREnvironmentalProbeConfig(enableProbes: $enableProbes, '
        'defaultQuality: $defaultQuality, maxActiveProbes: $maxActiveProbes)';
  }
}

/// Environmental probe status updates
class AREnvironmentalProbeStatus {
  /// Current status of the probe operation
  final String status;

  /// Progress of the operation (0.0 to 1.0)
  final double progress;

  /// Error message if operation failed
  final String? errorMessage;

  /// Timestamp of the status update
  final DateTime timestamp;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  const AREnvironmentalProbeStatus({
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Check if operation is in progress
  bool get isInProgress => status == 'in_progress';

  /// Check if operation completed successfully
  bool get isCompleted => status == 'completed';

  /// Check if operation failed
  bool get isFailed => status == 'failed';

  /// Create a copy of this status with modified properties
  AREnvironmentalProbeStatus copyWith({
    String? status,
    double? progress,
    String? errorMessage,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return AREnvironmentalProbeStatus(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'progress': progress,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  /// Create from map for deserialization
  factory AREnvironmentalProbeStatus.fromMap(Map<String, dynamic> map) {
    return AREnvironmentalProbeStatus(
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
    return other is AREnvironmentalProbeStatus &&
        other.status == status &&
        other.progress == progress &&
        other.errorMessage == errorMessage &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(status, progress, errorMessage, timestamp);
  }

  @override
  String toString() {
    return 'AREnvironmentalProbeStatus(status: $status, progress: $progress, '
        'errorMessage: $errorMessage, timestamp: $timestamp)';
  }
}
