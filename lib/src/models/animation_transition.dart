import 'animation_blend.dart';

/// Represents different transition curves for animation blending
enum TransitionCurve {
  /// Linear transition
  linear,

  /// Ease in (slow start)
  easeIn,

  /// Ease out (slow end)
  easeOut,

  /// Ease in and out
  easeInOut,

  /// Cubic bezier curve
  cubic,

  /// Elastic curve
  elastic,

  /// Bounce curve
  bounce,
}

/// Represents the current state of an animation transition
enum TransitionState {
  /// No transition is occurring
  idle,

  /// Transition is currently in progress
  transitioning,

  /// Transition has completed
  completed,

  /// Transition was interrupted
  interrupted,
}

/// Represents a transition between two animations or blend sets
class AnimationTransition {
  /// Unique identifier for this transition
  final String id;

  /// Source animation ID (null for from-any transition)
  final String? fromAnimationId;

  /// Target animation ID
  final String toAnimationId;

  /// Duration of the transition in seconds
  final double duration;

  /// Curve type for the transition
  final TransitionCurve curve;

  /// Whether the source animation should fade out
  final bool fadeOut;

  /// Whether the target animation should fade in
  final bool fadeIn;

  /// Blend mode during transition
  final AnimationBlendMode blendMode;

  /// Priority of this transition (higher values override lower ones)
  final int priority;

  /// Conditions that must be met for this transition to occur
  final Map<String, dynamic>? conditions;

  /// Whether this transition can be interrupted by other transitions
  final bool interruptible;

  /// Minimum time before this transition can be interrupted
  final double minDuration;

  const AnimationTransition({
    required this.id,
    this.fromAnimationId,
    required this.toAnimationId,
    required this.duration,
    this.curve = TransitionCurve.linear,
    this.fadeOut = true,
    this.fadeIn = true,
    this.blendMode = AnimationBlendMode.weighted,
    this.priority = 0,
    this.conditions,
    this.interruptible = true,
    this.minDuration = 0.0,
  }) : assert(duration > 0.0, 'Duration must be positive'),
       assert(minDuration >= 0.0, 'Min duration cannot be negative');

  factory AnimationTransition.fromMap(Map<dynamic, dynamic> map) {
    return AnimationTransition(
      id: map['id'] as String,
      fromAnimationId: map['fromAnimationId'] as String?,
      toAnimationId: map['toAnimationId'] as String,
      duration: (map['duration'] as num).toDouble(),
      curve: _parseTransitionCurve(map['curve'] as String?),
      fadeOut: map['fadeOut'] as bool? ?? true,
      fadeIn: map['fadeIn'] as bool? ?? true,
      blendMode: _parseBlendMode(map['blendMode'] as String?),
      priority: map['priority'] as int? ?? 0,
      conditions: map['conditions'] as Map<String, dynamic>?,
      interruptible: map['interruptible'] as bool? ?? true,
      minDuration: (map['minDuration'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static TransitionCurve _parseTransitionCurve(String? curve) {
    if (curve == null) return TransitionCurve.linear;
    switch (curve.toLowerCase()) {
      case 'linear':
        return TransitionCurve.linear;
      case 'easein':
        return TransitionCurve.easeIn;
      case 'easeout':
        return TransitionCurve.easeOut;
      case 'easeinout':
        return TransitionCurve.easeInOut;
      case 'cubic':
        return TransitionCurve.cubic;
      case 'elastic':
        return TransitionCurve.elastic;
      case 'bounce':
        return TransitionCurve.bounce;
      default:
        return TransitionCurve.linear;
    }
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
      'id': id,
      if (fromAnimationId != null) 'fromAnimationId': fromAnimationId,
      'toAnimationId': toAnimationId,
      'duration': duration,
      'curve': curve.name,
      'fadeOut': fadeOut,
      'fadeIn': fadeIn,
      'blendMode': blendMode.name,
      'priority': priority,
      if (conditions != null) 'conditions': conditions,
      'interruptible': interruptible,
      'minDuration': minDuration,
    };
  }

  /// Check if this transition can be applied from the given animation
  bool canTransitionFrom(String? currentAnimationId) {
    return fromAnimationId == null || fromAnimationId == currentAnimationId;
  }

  /// Check if the conditions for this transition are met
  bool checkConditions(Map<String, dynamic> parameters) {
    if (conditions == null) return true;

    for (final entry in conditions!.entries) {
      final key = entry.key;
      final expectedValue = entry.value;
      final actualValue = parameters[key];

      if (actualValue != expectedValue) {
        return false;
      }
    }

    return true;
  }

  AnimationTransition copyWith({
    String? id,
    String? fromAnimationId,
    String? toAnimationId,
    double? duration,
    TransitionCurve? curve,
    bool? fadeOut,
    bool? fadeIn,
    AnimationBlendMode? blendMode,
    int? priority,
    Map<String, dynamic>? conditions,
    bool? interruptible,
    double? minDuration,
  }) {
    return AnimationTransition(
      id: id ?? this.id,
      fromAnimationId: fromAnimationId ?? this.fromAnimationId,
      toAnimationId: toAnimationId ?? this.toAnimationId,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      fadeOut: fadeOut ?? this.fadeOut,
      fadeIn: fadeIn ?? this.fadeIn,
      blendMode: blendMode ?? this.blendMode,
      priority: priority ?? this.priority,
      conditions: conditions ?? this.conditions,
      interruptible: interruptible ?? this.interruptible,
      minDuration: minDuration ?? this.minDuration,
    );
  }

  @override
  String toString() =>
      'AnimationTransition($id: ${fromAnimationId ?? 'any'} -> $toAnimationId)';
}

/// Represents the current status of an ongoing transition
class TransitionStatus {
  /// Unique identifier of the transition
  final String transitionId;

  /// Current state of the transition
  final TransitionState state;

  /// Source animation ID
  final String? fromAnimationId;

  /// Target animation ID
  final String toAnimationId;

  /// Current progress of the transition (0.0 to 1.0)
  final double progress;

  /// Elapsed time since transition started
  final double elapsedTime;

  /// Total duration of the transition
  final double totalDuration;

  /// Current blend weight of the source animation
  final double sourceWeight;

  /// Current blend weight of the target animation
  final double targetWeight;

  const TransitionStatus({
    required this.transitionId,
    required this.state,
    this.fromAnimationId,
    required this.toAnimationId,
    required this.progress,
    required this.elapsedTime,
    required this.totalDuration,
    required this.sourceWeight,
    required this.targetWeight,
  }) : assert(
         progress >= 0.0 && progress <= 1.0,
         'Progress must be between 0.0 and 1.0',
       );

  factory TransitionStatus.fromMap(Map<dynamic, dynamic> map) {
    return TransitionStatus(
      transitionId: map['transitionId'] as String,
      state: _parseTransitionState(map['state'] as String),
      fromAnimationId: map['fromAnimationId'] as String?,
      toAnimationId: map['toAnimationId'] as String,
      progress: (map['progress'] as num).toDouble(),
      elapsedTime: (map['elapsedTime'] as num).toDouble(),
      totalDuration: (map['totalDuration'] as num).toDouble(),
      sourceWeight: (map['sourceWeight'] as num).toDouble(),
      targetWeight: (map['targetWeight'] as num).toDouble(),
    );
  }

  static TransitionState _parseTransitionState(String state) {
    switch (state.toLowerCase()) {
      case 'idle':
        return TransitionState.idle;
      case 'transitioning':
        return TransitionState.transitioning;
      case 'completed':
        return TransitionState.completed;
      case 'interrupted':
        return TransitionState.interrupted;
      default:
        return TransitionState.idle;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'transitionId': transitionId,
      'state': state.name,
      if (fromAnimationId != null) 'fromAnimationId': fromAnimationId,
      'toAnimationId': toAnimationId,
      'progress': progress,
      'elapsedTime': elapsedTime,
      'totalDuration': totalDuration,
      'sourceWeight': sourceWeight,
      'targetWeight': targetWeight,
    };
  }

  /// Whether the transition is currently active
  bool get isActive => state == TransitionState.transitioning;

  /// Whether the transition has finished
  bool get isCompleted => state == TransitionState.completed;

  /// Remaining time until transition completes
  double get remainingTime => totalDuration - elapsedTime;

  @override
  String toString() =>
      'TransitionStatus($transitionId: ${(progress * 100).toStringAsFixed(1)}%)';
}

/// Represents a crossfade transition between two specific animations
class CrossfadeTransition extends AnimationTransition {
  /// Weight curve for the source animation during crossfade
  final List<double>? sourceWeightCurve;

  /// Weight curve for the target animation during crossfade
  final List<double>? targetWeightCurve;

  const CrossfadeTransition({
    required super.id,
    super.fromAnimationId,
    required super.toAnimationId,
    required super.duration,
    super.curve = TransitionCurve.linear,
    super.priority = 0,
    super.conditions,
    super.interruptible = true,
    super.minDuration = 0.0,
    this.sourceWeightCurve,
    this.targetWeightCurve,
  }) : super(
         fadeOut: true,
         fadeIn: true,
         blendMode: AnimationBlendMode.weighted,
       );

  factory CrossfadeTransition.fromMap(Map<dynamic, dynamic> map) {
    return CrossfadeTransition(
      id: map['id'] as String,
      fromAnimationId: map['fromAnimationId'] as String?,
      toAnimationId: map['toAnimationId'] as String,
      duration: (map['duration'] as num).toDouble(),
      curve: AnimationTransition._parseTransitionCurve(map['curve'] as String?),
      priority: map['priority'] as int? ?? 0,
      conditions: map['conditions'] as Map<String, dynamic>?,
      interruptible: map['interruptible'] as bool? ?? true,
      minDuration: (map['minDuration'] as num?)?.toDouble() ?? 0.0,
      sourceWeightCurve: (map['sourceWeightCurve'] as List?)?.cast<double>(),
      targetWeightCurve: (map['targetWeightCurve'] as List?)?.cast<double>(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = super.toMap();
    if (sourceWeightCurve != null) {
      result['sourceWeightCurve'] = sourceWeightCurve;
    }
    if (targetWeightCurve != null) {
      result['targetWeightCurve'] = targetWeightCurve;
    }
    return result;
  }

  /// Calculate the source weight at a given progress point (0.0 to 1.0)
  double getSourceWeightAtProgress(double progress) {
    if (sourceWeightCurve == null || sourceWeightCurve!.isEmpty) {
      return 1.0 - progress; // Simple linear fade out
    }

    final index = (progress * (sourceWeightCurve!.length - 1)).round();
    return sourceWeightCurve![index.clamp(0, sourceWeightCurve!.length - 1)];
  }

  /// Calculate the target weight at a given progress point (0.0 to 1.0)
  double getTargetWeightAtProgress(double progress) {
    if (targetWeightCurve == null || targetWeightCurve!.isEmpty) {
      return progress; // Simple linear fade in
    }

    final index = (progress * (targetWeightCurve!.length - 1)).round();
    return targetWeightCurve![index.clamp(0, targetWeightCurve!.length - 1)];
  }
}
