/// Represents different animation blending modes
enum AnimationBlendMode {
  /// Replace the current animation completely
  replace,

  /// Add the animation on top of existing ones
  additive,

  /// Blend between animations using weights
  weighted,

  /// Override specific body parts
  override,

  /// Multiply with existing animations
  multiply,
}

/// Represents the blending type for combining animations
enum BlendType {
  /// Linear interpolation between animations
  linear,

  /// Spherical linear interpolation (for rotations)
  slerp,

  /// Cubic interpolation for smooth curves
  cubic,

  /// Step function (no interpolation)
  step,
}

/// Represents a weighted animation in a blend
class AnimationBlend {
  /// Animation ID to blend
  final String animationId;

  /// Weight of this animation in the blend (0.0 to 1.0)
  final double weight;

  /// Speed multiplier for this animation
  final double speed;

  /// Start time offset in seconds
  final double timeOffset;

  /// Blend mode for this animation
  final AnimationBlendMode blendMode;

  /// Whether this animation should loop
  final bool loop;

  /// Bone mask for selective animation (null = all bones)
  final List<String>? boneMask;

  /// Layer index (higher layers override lower ones)
  final int layer;

  const AnimationBlend({
    required this.animationId,
    required this.weight,
    this.speed = 1.0,
    this.timeOffset = 0.0,
    this.blendMode = AnimationBlendMode.weighted,
    this.loop = true,
    this.boneMask,
    this.layer = 0,
  }) : assert(
         weight >= 0.0 && weight <= 1.0,
         'Weight must be between 0.0 and 1.0',
       );

  factory AnimationBlend.fromMap(Map<dynamic, dynamic> map) {
    return AnimationBlend(
      animationId: map['animationId'] as String,
      weight: (map['weight'] as num).toDouble(),
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      timeOffset: (map['timeOffset'] as num?)?.toDouble() ?? 0.0,
      blendMode: _parseBlendMode(map['blendMode'] as String?),
      loop: map['loop'] as bool? ?? true,
      boneMask: (map['boneMask'] as List?)?.cast<String>(),
      layer: map['layer'] as int? ?? 0,
    );
  }

  static AnimationBlendMode _parseBlendMode(String? mode) {
    if (mode == null) return AnimationBlendMode.weighted;
    switch (mode.toLowerCase()) {
      case 'replace':
        return AnimationBlendMode.replace;
      case 'additive':
        return AnimationBlendMode.additive;
      case 'weighted':
        return AnimationBlendMode.weighted;
      case 'override':
        return AnimationBlendMode.override;
      case 'multiply':
        return AnimationBlendMode.multiply;
      default:
        return AnimationBlendMode.weighted;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'animationId': animationId,
      'weight': weight,
      'speed': speed,
      'timeOffset': timeOffset,
      'blendMode': blendMode.name,
      'loop': loop,
      if (boneMask != null) 'boneMask': boneMask,
      'layer': layer,
    };
  }

  AnimationBlend copyWith({
    String? animationId,
    double? weight,
    double? speed,
    double? timeOffset,
    AnimationBlendMode? blendMode,
    bool? loop,
    List<String>? boneMask,
    int? layer,
  }) {
    return AnimationBlend(
      animationId: animationId ?? this.animationId,
      weight: weight ?? this.weight,
      speed: speed ?? this.speed,
      timeOffset: timeOffset ?? this.timeOffset,
      blendMode: blendMode ?? this.blendMode,
      loop: loop ?? this.loop,
      boneMask: boneMask ?? this.boneMask,
      layer: layer ?? this.layer,
    );
  }

  @override
  String toString() => 'AnimationBlend($animationId, weight: $weight)';
}

/// Represents a collection of animations being blended together
class AnimationBlendSet {
  /// Unique identifier for this blend set
  final String id;

  /// List of animations to blend
  final List<AnimationBlend> animations;

  /// Blend type for interpolation
  final BlendType blendType;

  /// Whether to normalize weights (ensure they sum to 1.0)
  final bool normalizeWeights;

  /// Fade in duration when starting this blend set
  final double fadeInDuration;

  /// Fade out duration when stopping this blend set
  final double fadeOutDuration;

  const AnimationBlendSet({
    required this.id,
    required this.animations,
    this.blendType = BlendType.linear,
    this.normalizeWeights = true,
    this.fadeInDuration = 0.3,
    this.fadeOutDuration = 0.3,
  });

  factory AnimationBlendSet.fromMap(Map<dynamic, dynamic> map) {
    return AnimationBlendSet(
      id: map['id'] as String,
      animations: (map['animations'] as List)
          .map((e) => AnimationBlend.fromMap(e as Map))
          .toList(),
      blendType: _parseBlendType(map['blendType'] as String?),
      normalizeWeights: map['normalizeWeights'] as bool? ?? true,
      fadeInDuration: (map['fadeInDuration'] as num?)?.toDouble() ?? 0.3,
      fadeOutDuration: (map['fadeOutDuration'] as num?)?.toDouble() ?? 0.3,
    );
  }

  static BlendType _parseBlendType(String? type) {
    if (type == null) return BlendType.linear;
    switch (type.toLowerCase()) {
      case 'linear':
        return BlendType.linear;
      case 'slerp':
        return BlendType.slerp;
      case 'cubic':
        return BlendType.cubic;
      case 'step':
        return BlendType.step;
      default:
        return BlendType.linear;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animations': animations.map((a) => a.toMap()).toList(),
      'blendType': blendType.name,
      'normalizeWeights': normalizeWeights,
      'fadeInDuration': fadeInDuration,
      'fadeOutDuration': fadeOutDuration,
    };
  }

  /// Get the total weight of all animations
  double get totalWeight =>
      animations.fold(0.0, (sum, anim) => sum + anim.weight);

  /// Get normalized blend set where weights sum to 1.0
  AnimationBlendSet get normalized {
    if (!normalizeWeights || totalWeight == 0.0) return this;

    final normalizedAnimations = animations.map((anim) {
      return anim.copyWith(weight: anim.weight / totalWeight);
    }).toList();

    return AnimationBlendSet(
      id: id,
      animations: normalizedAnimations,
      blendType: blendType,
      normalizeWeights: false, // Already normalized
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
    );
  }

  AnimationBlendSet copyWith({
    String? id,
    List<AnimationBlend>? animations,
    BlendType? blendType,
    bool? normalizeWeights,
    double? fadeInDuration,
    double? fadeOutDuration,
  }) {
    return AnimationBlendSet(
      id: id ?? this.id,
      animations: animations ?? this.animations,
      blendType: blendType ?? this.blendType,
      normalizeWeights: normalizeWeights ?? this.normalizeWeights,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
    );
  }

  @override
  String toString() =>
      'AnimationBlendSet($id, ${animations.length} animations)';
}
