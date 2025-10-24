import 'vector3.dart';
import 'quaternion.dart';

/// Types of lighting sources in AR
enum ARLightType { directional, point, spot, ambient, environment }

/// Shadow quality levels
enum ShadowQuality { low, medium, high, ultra }

/// Shadow filtering modes
enum ShadowFilterMode { hard, soft, pcf, pcss }

/// Light intensity units
enum LightIntensityUnit { lux, candela, lumen, watt }

/// AR lighting source model
class ARLight {
  final String id;
  final ARLightType type;
  final Vector3 position;
  final Quaternion rotation;
  final Vector3 direction;
  final double intensity;
  final LightIntensityUnit intensityUnit;
  final Vector3 color;
  final double range;
  final double innerConeAngle;
  final double outerConeAngle;
  final bool isEnabled;
  final bool castShadows;
  final ShadowQuality shadowQuality;
  final ShadowFilterMode shadowFilterMode;
  final double shadowBias;
  final double shadowNormalBias;
  final double shadowNearPlane;
  final double shadowFarPlane;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> metadata;

  const ARLight({
    required this.id,
    required this.type,
    required this.position,
    required this.rotation,
    required this.direction,
    required this.intensity,
    this.intensityUnit = LightIntensityUnit.lux,
    this.color = const Vector3(1.0, 1.0, 1.0),
    this.range = 10.0,
    this.innerConeAngle = 0.0,
    this.outerConeAngle = 45.0,
    this.isEnabled = true,
    this.castShadows = true,
    this.shadowQuality = ShadowQuality.medium,
    this.shadowFilterMode = ShadowFilterMode.soft,
    this.shadowBias = 0.005,
    this.shadowNormalBias = 0.0,
    this.shadowNearPlane = 0.1,
    this.shadowFarPlane = 100.0,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
  });

  /// Check if this is a directional light
  bool get isDirectional => type == ARLightType.directional;

  /// Check if this is a point light
  bool get isPoint => type == ARLightType.point;

  /// Check if this is a spot light
  bool get isSpot => type == ARLightType.spot;

  /// Check if this is an ambient light
  bool get isAmbient => type == ARLightType.ambient;

  /// Check if this is an environment light
  bool get isEnvironment => type == ARLightType.environment;

  /// Get effective range for this light type
  double get effectiveRange {
    switch (type) {
      case ARLightType.directional:
        return double.infinity;
      case ARLightType.ambient:
        return double.infinity;
      case ARLightType.environment:
        return double.infinity;
      case ARLightType.point:
      case ARLightType.spot:
        return range;
    }
  }

  /// Get shadow map resolution based on quality
  int get shadowMapResolution {
    switch (shadowQuality) {
      case ShadowQuality.low:
        return 512;
      case ShadowQuality.medium:
        return 1024;
      case ShadowQuality.high:
        return 2048;
      case ShadowQuality.ultra:
        return 4096;
    }
  }

  /// Create a copy with modified properties
  ARLight copyWith({
    String? id,
    ARLightType? type,
    Vector3? position,
    Quaternion? rotation,
    Vector3? direction,
    double? intensity,
    LightIntensityUnit? intensityUnit,
    Vector3? color,
    double? range,
    double? innerConeAngle,
    double? outerConeAngle,
    bool? isEnabled,
    bool? castShadows,
    ShadowQuality? shadowQuality,
    ShadowFilterMode? shadowFilterMode,
    double? shadowBias,
    double? shadowNormalBias,
    double? shadowNearPlane,
    double? shadowFarPlane,
    DateTime? createdAt,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
  }) {
    return ARLight(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      direction: direction ?? this.direction,
      intensity: intensity ?? this.intensity,
      intensityUnit: intensityUnit ?? this.intensityUnit,
      color: color ?? this.color,
      range: range ?? this.range,
      innerConeAngle: innerConeAngle ?? this.innerConeAngle,
      outerConeAngle: outerConeAngle ?? this.outerConeAngle,
      isEnabled: isEnabled ?? this.isEnabled,
      castShadows: castShadows ?? this.castShadows,
      shadowQuality: shadowQuality ?? this.shadowQuality,
      shadowFilterMode: shadowFilterMode ?? this.shadowFilterMode,
      shadowBias: shadowBias ?? this.shadowBias,
      shadowNormalBias: shadowNormalBias ?? this.shadowNormalBias,
      shadowNearPlane: shadowNearPlane ?? this.shadowNearPlane,
      shadowFarPlane: shadowFarPlane ?? this.shadowFarPlane,
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
      'direction': direction.toMap(),
      'intensity': intensity,
      'intensityUnit': intensityUnit.name,
      'color': color.toMap(),
      'range': range,
      'innerConeAngle': innerConeAngle,
      'outerConeAngle': outerConeAngle,
      'isEnabled': isEnabled,
      'castShadows': castShadows,
      'shadowQuality': shadowQuality.name,
      'shadowFilterMode': shadowFilterMode.name,
      'shadowBias': shadowBias,
      'shadowNormalBias': shadowNormalBias,
      'shadowNearPlane': shadowNearPlane,
      'shadowFarPlane': shadowFarPlane,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  /// Create from map
  factory ARLight.fromMap(Map<String, dynamic> map) {
    return ARLight(
      id: map['id'] as String,
      type: ARLightType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ARLightType.directional,
      ),
      position: Vector3.fromMap(
        Map<String, dynamic>.from(map['position'] as Map),
      ),
      rotation: Quaternion.fromMap(
        Map<String, dynamic>.from(map['rotation'] as Map),
      ),
      direction: Vector3.fromMap(
        Map<String, dynamic>.from(map['direction'] as Map),
      ),
      intensity: (map['intensity'] as num).toDouble(),
      intensityUnit: LightIntensityUnit.values.firstWhere(
        (e) => e.name == map['intensityUnit'],
        orElse: () => LightIntensityUnit.lux,
      ),
      color: Vector3.fromMap(Map<String, dynamic>.from(map['color'] as Map)),
      range: (map['range'] as num).toDouble(),
      innerConeAngle: (map['innerConeAngle'] as num).toDouble(),
      outerConeAngle: (map['outerConeAngle'] as num).toDouble(),
      isEnabled: map['isEnabled'] as bool,
      castShadows: map['castShadows'] as bool,
      shadowQuality: ShadowQuality.values.firstWhere(
        (e) => e.name == map['shadowQuality'],
        orElse: () => ShadowQuality.medium,
      ),
      shadowFilterMode: ShadowFilterMode.values.firstWhere(
        (e) => e.name == map['shadowFilterMode'],
        orElse: () => ShadowFilterMode.soft,
      ),
      shadowBias: (map['shadowBias'] as num).toDouble(),
      shadowNormalBias: (map['shadowNormalBias'] as num).toDouble(),
      shadowNearPlane: (map['shadowNearPlane'] as num).toDouble(),
      shadowFarPlane: (map['shadowFarPlane'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['lastModified'] as int,
      ),
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map<Object?, Object?>,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARLight &&
        other.id == id &&
        other.type == type &&
        other.position == position &&
        other.rotation == rotation &&
        other.direction == direction &&
        other.intensity == intensity &&
        other.intensityUnit == intensityUnit &&
        other.color == color &&
        other.range == range &&
        other.innerConeAngle == innerConeAngle &&
        other.outerConeAngle == outerConeAngle &&
        other.isEnabled == isEnabled &&
        other.castShadows == castShadows &&
        other.shadowQuality == shadowQuality &&
        other.shadowFilterMode == shadowFilterMode &&
        other.shadowBias == shadowBias &&
        other.shadowNormalBias == shadowNormalBias &&
        other.shadowNearPlane == shadowNearPlane &&
        other.shadowFarPlane == shadowFarPlane &&
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
      direction,
      intensity,
      intensityUnit,
      color,
      range,
      innerConeAngle,
      outerConeAngle,
      isEnabled,
      castShadows,
      shadowQuality,
      shadowFilterMode,
      shadowBias,
      shadowNormalBias,
      shadowNearPlane,
      shadowFarPlane,
    );
  }

  @override
  String toString() {
    return 'ARLight(id: $id, type: $type, position: $position, intensity: $intensity, isEnabled: $isEnabled, castShadows: $castShadows)';
  }
}

/// Global lighting configuration
class ARLightingConfig {
  final bool enableGlobalIllumination;
  final bool enableShadows;
  final ShadowQuality globalShadowQuality;
  final ShadowFilterMode globalShadowFilterMode;
  final double ambientIntensity;
  final Vector3 ambientColor;
  final double shadowDistance;
  final int maxShadowCasters;
  final bool enableCascadedShadows;
  final int shadowCascadeCount;
  final List<double> shadowCascadeDistances;
  final bool enableContactShadows;
  final double contactShadowDistance;
  final bool enableScreenSpaceShadows;
  final bool enableRayTracedShadows;
  final Map<String, dynamic> metadata;

  const ARLightingConfig({
    this.enableGlobalIllumination = true,
    this.enableShadows = true,
    this.globalShadowQuality = ShadowQuality.medium,
    this.globalShadowFilterMode = ShadowFilterMode.soft,
    this.ambientIntensity = 0.3,
    this.ambientColor = const Vector3(1.0, 1.0, 1.0),
    this.shadowDistance = 50.0,
    this.maxShadowCasters = 4,
    this.enableCascadedShadows = true,
    this.shadowCascadeCount = 4,
    this.shadowCascadeDistances = const [10.0, 25.0, 50.0, 100.0],
    this.enableContactShadows = false,
    this.contactShadowDistance = 5.0,
    this.enableScreenSpaceShadows = false,
    this.enableRayTracedShadows = false,
    this.metadata = const {},
  });

  /// Create a copy with modified properties
  ARLightingConfig copyWith({
    bool? enableGlobalIllumination,
    bool? enableShadows,
    ShadowQuality? globalShadowQuality,
    ShadowFilterMode? globalShadowFilterMode,
    double? ambientIntensity,
    Vector3? ambientColor,
    double? shadowDistance,
    int? maxShadowCasters,
    bool? enableCascadedShadows,
    int? shadowCascadeCount,
    List<double>? shadowCascadeDistances,
    bool? enableContactShadows,
    double? contactShadowDistance,
    bool? enableScreenSpaceShadows,
    bool? enableRayTracedShadows,
    Map<String, dynamic>? metadata,
  }) {
    return ARLightingConfig(
      enableGlobalIllumination:
          enableGlobalIllumination ?? this.enableGlobalIllumination,
      enableShadows: enableShadows ?? this.enableShadows,
      globalShadowQuality: globalShadowQuality ?? this.globalShadowQuality,
      globalShadowFilterMode:
          globalShadowFilterMode ?? this.globalShadowFilterMode,
      ambientIntensity: ambientIntensity ?? this.ambientIntensity,
      ambientColor: ambientColor ?? this.ambientColor,
      shadowDistance: shadowDistance ?? this.shadowDistance,
      maxShadowCasters: maxShadowCasters ?? this.maxShadowCasters,
      enableCascadedShadows:
          enableCascadedShadows ?? this.enableCascadedShadows,
      shadowCascadeCount: shadowCascadeCount ?? this.shadowCascadeCount,
      shadowCascadeDistances:
          shadowCascadeDistances ?? this.shadowCascadeDistances,
      enableContactShadows: enableContactShadows ?? this.enableContactShadows,
      contactShadowDistance:
          contactShadowDistance ?? this.contactShadowDistance,
      enableScreenSpaceShadows:
          enableScreenSpaceShadows ?? this.enableScreenSpaceShadows,
      enableRayTracedShadows:
          enableRayTracedShadows ?? this.enableRayTracedShadows,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'enableGlobalIllumination': enableGlobalIllumination,
      'enableShadows': enableShadows,
      'globalShadowQuality': globalShadowQuality.name,
      'globalShadowFilterMode': globalShadowFilterMode.name,
      'ambientIntensity': ambientIntensity,
      'ambientColor': ambientColor.toMap(),
      'shadowDistance': shadowDistance,
      'maxShadowCasters': maxShadowCasters,
      'enableCascadedShadows': enableCascadedShadows,
      'shadowCascadeCount': shadowCascadeCount,
      'shadowCascadeDistances': shadowCascadeDistances,
      'enableContactShadows': enableContactShadows,
      'contactShadowDistance': contactShadowDistance,
      'enableScreenSpaceShadows': enableScreenSpaceShadows,
      'enableRayTracedShadows': enableRayTracedShadows,
      'metadata': metadata,
    };
  }

  /// Create from map
  factory ARLightingConfig.fromMap(Map<String, dynamic> map) {
    return ARLightingConfig(
      enableGlobalIllumination: map['enableGlobalIllumination'] as bool,
      enableShadows: map['enableShadows'] as bool,
      globalShadowQuality: ShadowQuality.values.firstWhere(
        (e) => e.name == map['globalShadowQuality'],
        orElse: () => ShadowQuality.medium,
      ),
      globalShadowFilterMode: ShadowFilterMode.values.firstWhere(
        (e) => e.name == map['globalShadowFilterMode'],
        orElse: () => ShadowFilterMode.soft,
      ),
      ambientIntensity: (map['ambientIntensity'] as num).toDouble(),
      ambientColor: Vector3.fromMap(
        Map<String, dynamic>.from(map['ambientColor'] as Map),
      ),
      shadowDistance: (map['shadowDistance'] as num).toDouble(),
      maxShadowCasters: map['maxShadowCasters'] as int,
      enableCascadedShadows: map['enableCascadedShadows'] as bool,
      shadowCascadeCount: map['shadowCascadeCount'] as int,
      shadowCascadeDistances: (map['shadowCascadeDistances'] as List)
          .cast<double>(),
      enableContactShadows: map['enableContactShadows'] as bool,
      contactShadowDistance: (map['contactShadowDistance'] as num).toDouble(),
      enableScreenSpaceShadows: map['enableScreenSpaceShadows'] as bool,
      enableRayTracedShadows: map['enableRayTracedShadows'] as bool,
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map<Object?, Object?>,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARLightingConfig &&
        other.enableGlobalIllumination == enableGlobalIllumination &&
        other.enableShadows == enableShadows &&
        other.globalShadowQuality == globalShadowQuality &&
        other.globalShadowFilterMode == globalShadowFilterMode &&
        other.ambientIntensity == ambientIntensity &&
        other.ambientColor == ambientColor &&
        other.shadowDistance == shadowDistance &&
        other.maxShadowCasters == maxShadowCasters &&
        other.enableCascadedShadows == enableCascadedShadows &&
        other.shadowCascadeCount == shadowCascadeCount &&
        other.shadowCascadeDistances == shadowCascadeDistances &&
        other.enableContactShadows == enableContactShadows &&
        other.contactShadowDistance == contactShadowDistance &&
        other.enableScreenSpaceShadows == enableScreenSpaceShadows &&
        other.enableRayTracedShadows == enableRayTracedShadows;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableGlobalIllumination,
      enableShadows,
      globalShadowQuality,
      globalShadowFilterMode,
      ambientIntensity,
      ambientColor,
      shadowDistance,
      maxShadowCasters,
      enableCascadedShadows,
      shadowCascadeCount,
      shadowCascadeDistances,
      enableContactShadows,
      contactShadowDistance,
      enableScreenSpaceShadows,
      enableRayTracedShadows,
    );
  }

  @override
  String toString() {
    return 'ARLightingConfig(enableGlobalIllumination: $enableGlobalIllumination, enableShadows: $enableShadows, globalShadowQuality: $globalShadowQuality)';
  }
}

/// Lighting status updates
class ARLightingStatus {
  final String status;
  final double progress;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ARLightingStatus({
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Check if the operation is in progress
  bool get isInProgress => status == 'in_progress';

  /// Check if the operation completed successfully
  bool get isCompleted => status == 'completed';

  /// Check if the operation failed
  bool get isFailed => status == 'failed';

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

  /// Create from map
  factory ARLightingStatus.fromMap(Map<String, dynamic> map) {
    return ARLightingStatus(
      status: map['status'] as String,
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map<Object?, Object?>,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ARLightingStatus &&
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
    return 'ARLightingStatus(status: $status, progress: $progress, errorMessage: $errorMessage)';
  }
}
