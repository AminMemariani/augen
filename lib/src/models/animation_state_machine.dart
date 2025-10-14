import 'animation_transition.dart';

/// Represents a state in an animation state machine
class AnimationState {
  /// Unique identifier for this state
  final String id;

  /// Display name for this state
  final String name;

  /// Animation ID or blend set ID to play in this state
  final String animationId;

  /// Whether this is the entry state (default state)
  final bool isEntryState;

  /// Whether this state can loop
  final bool loop;

  /// Speed multiplier for animations in this state
  final double speed;

  /// List of possible transitions from this state
  final List<AnimationTransition> transitions;

  /// Parameters that affect this state's behavior
  final Map<String, dynamic> parameters;

  /// Tags for categorizing this state
  final List<String> tags;

  /// Minimum time to stay in this state before allowing transitions
  final double minDuration;

  /// Maximum time to stay in this state (auto-transition if reached)
  final double? maxDuration;

  /// Action to perform when entering this state
  final String? onEnterAction;

  /// Action to perform when exiting this state
  final String? onExitAction;

  /// Action to perform while in this state (called every frame)
  final String? onUpdateAction;

  const AnimationState({
    required this.id,
    required this.name,
    required this.animationId,
    this.isEntryState = false,
    this.loop = true,
    this.speed = 1.0,
    this.transitions = const [],
    this.parameters = const {},
    this.tags = const [],
    this.minDuration = 0.0,
    this.maxDuration,
    this.onEnterAction,
    this.onExitAction,
    this.onUpdateAction,
  }) : assert(minDuration >= 0.0, 'Min duration cannot be negative'),
       assert(
         maxDuration == null || maxDuration > minDuration,
         'Max duration must be greater than min duration',
       );

  factory AnimationState.fromMap(Map<dynamic, dynamic> map) {
    return AnimationState(
      id: map['id'] as String,
      name: map['name'] as String,
      animationId: map['animationId'] as String,
      isEntryState: map['isEntryState'] as bool? ?? false,
      loop: map['loop'] as bool? ?? true,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      transitions:
          (map['transitions'] as List?)
              ?.map((e) => AnimationTransition.fromMap(e as Map))
              .toList() ??
          [],
      parameters: (map['parameters'] as Map?)?.cast<String, dynamic>() ?? {},
      tags: (map['tags'] as List?)?.cast<String>() ?? [],
      minDuration: (map['minDuration'] as num?)?.toDouble() ?? 0.0,
      maxDuration: (map['maxDuration'] as num?)?.toDouble(),
      onEnterAction: map['onEnterAction'] as String?,
      onExitAction: map['onExitAction'] as String?,
      onUpdateAction: map['onUpdateAction'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'animationId': animationId,
      'isEntryState': isEntryState,
      'loop': loop,
      'speed': speed,
      'transitions': transitions.map((t) => t.toMap()).toList(),
      'parameters': parameters,
      'tags': tags,
      'minDuration': minDuration,
      if (maxDuration != null) 'maxDuration': maxDuration,
      if (onEnterAction != null) 'onEnterAction': onEnterAction,
      if (onExitAction != null) 'onExitAction': onExitAction,
      if (onUpdateAction != null) 'onUpdateAction': onUpdateAction,
    };
  }

  /// Find a transition to the specified target state
  AnimationTransition? findTransitionTo(
    String targetStateId,
    Map<String, dynamic> parameters,
  ) {
    final validTransitions = transitions
        .where(
          (t) =>
              t.toAnimationId == targetStateId && t.checkConditions(parameters),
        )
        .toList();

    if (validTransitions.isEmpty) return null;

    // Sort by priority (highest first)
    validTransitions.sort((a, b) => b.priority.compareTo(a.priority));
    return validTransitions.first;
  }

  /// Get all possible target states from this state
  List<String> get possibleTargets =>
      transitions.map((t) => t.toAnimationId).toSet().toList();

  /// Check if this state has a specific tag
  bool hasTag(String tag) => tags.contains(tag);

  AnimationState copyWith({
    String? id,
    String? name,
    String? animationId,
    bool? isEntryState,
    bool? loop,
    double? speed,
    List<AnimationTransition>? transitions,
    Map<String, dynamic>? parameters,
    List<String>? tags,
    double? minDuration,
    double? maxDuration,
    String? onEnterAction,
    String? onExitAction,
    String? onUpdateAction,
  }) {
    return AnimationState(
      id: id ?? this.id,
      name: name ?? this.name,
      animationId: animationId ?? this.animationId,
      isEntryState: isEntryState ?? this.isEntryState,
      loop: loop ?? this.loop,
      speed: speed ?? this.speed,
      transitions: transitions ?? this.transitions,
      parameters: parameters ?? this.parameters,
      tags: tags ?? this.tags,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      onEnterAction: onEnterAction ?? this.onEnterAction,
      onExitAction: onExitAction ?? this.onExitAction,
      onUpdateAction: onUpdateAction ?? this.onUpdateAction,
    );
  }

  @override
  String toString() => 'AnimationState($id: $name)';
}

/// Represents a complete animation state machine
class AnimationStateMachine {
  /// Unique identifier for this state machine
  final String id;

  /// Display name for this state machine
  final String name;

  /// List of all states in this state machine
  final List<AnimationState> states;

  /// Global parameters for this state machine
  final Map<String, dynamic> parameters;

  /// Global transitions that can be triggered from any state
  final List<AnimationTransition> anyStateTransitions;

  /// Default entry state ID
  final String? entryStateId;

  /// Whether this state machine should automatically start
  final bool autoStart;

  /// Layer index for this state machine (higher layers override lower ones)
  final int layer;

  const AnimationStateMachine({
    required this.id,
    required this.name,
    required this.states,
    this.parameters = const {},
    this.anyStateTransitions = const [],
    this.entryStateId,
    this.autoStart = true,
    this.layer = 0,
  });

  factory AnimationStateMachine.fromMap(Map<dynamic, dynamic> map) {
    return AnimationStateMachine(
      id: map['id'] as String,
      name: map['name'] as String,
      states: (map['states'] as List)
          .map((e) => AnimationState.fromMap(e as Map))
          .toList(),
      parameters: (map['parameters'] as Map?)?.cast<String, dynamic>() ?? {},
      anyStateTransitions:
          (map['anyStateTransitions'] as List?)
              ?.map((e) => AnimationTransition.fromMap(e as Map))
              .toList() ??
          [],
      entryStateId: map['entryStateId'] as String?,
      autoStart: map['autoStart'] as bool? ?? true,
      layer: map['layer'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'states': states.map((s) => s.toMap()).toList(),
      'parameters': parameters,
      'anyStateTransitions': anyStateTransitions.map((t) => t.toMap()).toList(),
      if (entryStateId != null) 'entryStateId': entryStateId,
      'autoStart': autoStart,
      'layer': layer,
    };
  }

  /// Find a state by ID
  AnimationState? findState(String stateId) {
    try {
      return states.firstWhere((s) => s.id == stateId);
    } catch (e) {
      return null;
    }
  }

  /// Get the entry state (either specified or first state marked as entry)
  AnimationState? get entryState {
    if (entryStateId != null) {
      return findState(entryStateId!);
    }

    // Find first state marked as entry state
    try {
      return states.firstWhere((s) => s.isEntryState);
    } catch (e) {
      // If no entry state found, return first state
      return states.isNotEmpty ? states.first : null;
    }
  }

  /// Find a transition from one state to another
  AnimationTransition? findTransition(
    String fromStateId,
    String toStateId,
    Map<String, dynamic> currentParameters,
  ) {
    // First check any-state transitions
    final anyStateTransition = anyStateTransitions
        .where(
          (t) =>
              t.toAnimationId == toStateId &&
              t.checkConditions(currentParameters),
        )
        .toList();

    // Then check state-specific transitions
    final fromState = findState(fromStateId);
    final stateTransition = fromState?.findTransitionTo(
      toStateId,
      currentParameters,
    );

    // Combine and sort by priority
    final allTransitions = <AnimationTransition>[
      ...anyStateTransition,
      if (stateTransition != null) stateTransition,
    ];

    if (allTransitions.isEmpty) return null;

    allTransitions.sort((a, b) => b.priority.compareTo(a.priority));
    return allTransitions.first;
  }

  /// Get all states with a specific tag
  List<AnimationState> getStatesWithTag(String tag) {
    return states.where((s) => s.hasTag(tag)).toList();
  }

  /// Validate the state machine for consistency
  bool validate() {
    // Check if there's at least one state
    if (states.isEmpty) return false;

    // Check if entry state exists
    if (entryState == null) return false;

    // Check for duplicate state IDs
    final stateIds = states.map((s) => s.id).toList();
    if (stateIds.length != stateIds.toSet().length) return false;

    // Check if all transition targets exist
    for (final state in states) {
      for (final transition in state.transitions) {
        if (findState(transition.toAnimationId) == null) return false;
      }
    }

    // Check any-state transitions
    for (final transition in anyStateTransitions) {
      if (findState(transition.toAnimationId) == null) return false;
    }

    return true;
  }

  AnimationStateMachine copyWith({
    String? id,
    String? name,
    List<AnimationState>? states,
    Map<String, dynamic>? parameters,
    List<AnimationTransition>? anyStateTransitions,
    String? entryStateId,
    bool? autoStart,
    int? layer,
  }) {
    return AnimationStateMachine(
      id: id ?? this.id,
      name: name ?? this.name,
      states: states ?? this.states,
      parameters: parameters ?? this.parameters,
      anyStateTransitions: anyStateTransitions ?? this.anyStateTransitions,
      entryStateId: entryStateId ?? this.entryStateId,
      autoStart: autoStart ?? this.autoStart,
      layer: layer ?? this.layer,
    );
  }

  @override
  String toString() =>
      'AnimationStateMachine($id: $name, ${states.length} states)';
}

/// Represents the current status of a running state machine
class StateMachineStatus {
  /// State machine ID
  final String stateMachineId;

  /// Current state ID
  final String currentStateId;

  /// Previous state ID (null if this is the first state)
  final String? previousStateId;

  /// Time spent in current state (seconds)
  final double timeInState;

  /// Current transition being executed (null if not transitioning)
  final TransitionStatus? currentTransition;

  /// Current parameters
  final Map<String, dynamic> parameters;

  /// Whether the state machine is currently active
  final bool isActive;

  /// Whether the state machine is paused
  final bool isPaused;

  const StateMachineStatus({
    required this.stateMachineId,
    required this.currentStateId,
    this.previousStateId,
    required this.timeInState,
    this.currentTransition,
    this.parameters = const {},
    required this.isActive,
    this.isPaused = false,
  });

  factory StateMachineStatus.fromMap(Map<dynamic, dynamic> map) {
    return StateMachineStatus(
      stateMachineId: map['stateMachineId'] as String,
      currentStateId: map['currentStateId'] as String,
      previousStateId: map['previousStateId'] as String?,
      timeInState: (map['timeInState'] as num).toDouble(),
      currentTransition: map['currentTransition'] != null
          ? TransitionStatus.fromMap(map['currentTransition'] as Map)
          : null,
      parameters: (map['parameters'] as Map?)?.cast<String, dynamic>() ?? {},
      isActive: map['isActive'] as bool,
      isPaused: map['isPaused'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stateMachineId': stateMachineId,
      'currentStateId': currentStateId,
      if (previousStateId != null) 'previousStateId': previousStateId,
      'timeInState': timeInState,
      if (currentTransition != null)
        'currentTransition': currentTransition!.toMap(),
      'parameters': parameters,
      'isActive': isActive,
      'isPaused': isPaused,
    };
  }

  /// Whether the state machine is currently transitioning between states
  bool get isTransitioning =>
      currentTransition != null && currentTransition!.isActive;

  @override
  String toString() => 'StateMachineStatus($stateMachineId: $currentStateId)';
}
