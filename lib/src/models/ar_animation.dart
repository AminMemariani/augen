/// Represents an animation state
enum AnimationState { stopped, playing, paused }

/// Represents an animation loop mode
enum AnimationLoopMode {
  once, // Play once and stop
  loop, // Loop indefinitely
  pingPong, // Play forward, then backward, repeat
}

/// Represents an animation for a 3D model
class ARAnimation {
  /// Unique identifier for this animation
  final String id;

  /// Name of the animation (from the 3D model file)
  /// If null, plays the default/first animation
  final String? name;

  /// Duration of the animation in seconds
  final double? duration;

  /// Speed multiplier for the animation (1.0 = normal speed)
  final double speed;

  /// Loop mode for the animation
  final AnimationLoopMode loopMode;

  /// Whether the animation starts playing immediately
  final bool autoPlay;

  /// Start time offset in seconds
  final double startTime;

  /// End time in seconds (null = play to end)
  final double? endTime;

  const ARAnimation({
    required this.id,
    this.name,
    this.duration,
    this.speed = 1.0,
    this.loopMode = AnimationLoopMode.loop,
    this.autoPlay = true,
    this.startTime = 0.0,
    this.endTime,
  });

  factory ARAnimation.fromMap(Map<dynamic, dynamic> map) {
    return ARAnimation(
      id: map['id'] as String,
      name: map['name'] as String?,
      duration: (map['duration'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      loopMode: _parseLoopMode(map['loopMode'] as String?),
      autoPlay: map['autoPlay'] as bool? ?? true,
      startTime: (map['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (map['endTime'] as num?)?.toDouble(),
    );
  }

  static AnimationLoopMode _parseLoopMode(String? mode) {
    if (mode == null) return AnimationLoopMode.loop;
    switch (mode.toLowerCase()) {
      case 'once':
        return AnimationLoopMode.once;
      case 'loop':
        return AnimationLoopMode.loop;
      case 'pingpong':
        return AnimationLoopMode.pingPong;
      default:
        return AnimationLoopMode.loop;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (duration != null) 'duration': duration,
      'speed': speed,
      'loopMode': loopMode.name,
      'autoPlay': autoPlay,
      'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
    };
  }

  ARAnimation copyWith({
    String? id,
    String? name,
    double? duration,
    double? speed,
    AnimationLoopMode? loopMode,
    bool? autoPlay,
    double? startTime,
    double? endTime,
  }) {
    return ARAnimation(
      id: id ?? this.id,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      loopMode: loopMode ?? this.loopMode,
      autoPlay: autoPlay ?? this.autoPlay,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  String toString() =>
      'ARAnimation(id: $id, name: $name, speed: $speed, loopMode: $loopMode)';
}

/// Represents the current state of an animation
class AnimationStatus {
  /// Animation ID
  final String animationId;

  /// Current state
  final AnimationState state;

  /// Current playback time in seconds
  final double currentTime;

  /// Total duration in seconds
  final double? duration;

  /// Whether the animation is looping
  final bool isLooping;

  const AnimationStatus({
    required this.animationId,
    required this.state,
    required this.currentTime,
    this.duration,
    this.isLooping = false,
  });

  factory AnimationStatus.fromMap(Map<dynamic, dynamic> map) {
    return AnimationStatus(
      animationId: map['animationId'] as String,
      state: _parseAnimationState(map['state'] as String),
      currentTime: (map['currentTime'] as num).toDouble(),
      duration: (map['duration'] as num?)?.toDouble(),
      isLooping: map['isLooping'] as bool? ?? false,
    );
  }

  static AnimationState _parseAnimationState(String state) {
    switch (state.toLowerCase()) {
      case 'stopped':
        return AnimationState.stopped;
      case 'playing':
        return AnimationState.playing;
      case 'paused':
        return AnimationState.paused;
      default:
        return AnimationState.stopped;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'animationId': animationId,
      'state': state.name,
      'currentTime': currentTime,
      if (duration != null) 'duration': duration,
      'isLooping': isLooping,
    };
  }

  @override
  String toString() =>
      'AnimationStatus(id: $animationId, state: $state, time: $currentTime)';
}
