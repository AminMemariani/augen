import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';
import 'package:augen/src/models/animation_state_machine.dart' as sm;

void main() {
  group('Animation Blending Tests', () {
    group('AnimationBlend', () {
      test('creates animation blend with default values', () {
        const blend = AnimationBlend(animationId: 'walk', weight: 0.7);

        expect(blend.animationId, 'walk');
        expect(blend.weight, 0.7);
        expect(blend.speed, 1.0);
        expect(blend.timeOffset, 0.0);
        expect(blend.blendMode, AnimationBlendMode.weighted);
        expect(blend.loop, true);
        expect(blend.boneMask, isNull);
        expect(blend.layer, 0);
      });

      test('creates animation blend with custom values', () {
        const blend = AnimationBlend(
          animationId: 'run',
          weight: 0.5,
          speed: 1.5,
          timeOffset: 0.2,
          blendMode: AnimationBlendMode.additive,
          loop: false,
          boneMask: ['arm_left', 'arm_right'],
          layer: 1,
        );

        expect(blend.animationId, 'run');
        expect(blend.weight, 0.5);
        expect(blend.speed, 1.5);
        expect(blend.timeOffset, 0.2);
        expect(blend.blendMode, AnimationBlendMode.additive);
        expect(blend.loop, false);
        expect(blend.boneMask, ['arm_left', 'arm_right']);
        expect(blend.layer, 1);
      });

      test('validates weight range', () {
        expect(
          () => AnimationBlend(animationId: 'test', weight: -0.1),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => AnimationBlend(animationId: 'test', weight: 1.1),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => AnimationBlend(animationId: 'test', weight: 0.0),
          returnsNormally,
        );
        expect(
          () => AnimationBlend(animationId: 'test', weight: 1.0),
          returnsNormally,
        );
      });

      test('converts to and from map', () {
        const blend = AnimationBlend(
          animationId: 'jump',
          weight: 0.8,
          speed: 1.2,
          blendMode: AnimationBlendMode.override,
          boneMask: ['leg_left', 'leg_right'],
        );

        final map = blend.toMap();
        final fromMap = AnimationBlend.fromMap(map);

        expect(fromMap.animationId, blend.animationId);
        expect(fromMap.weight, blend.weight);
        expect(fromMap.speed, blend.speed);
        expect(fromMap.blendMode, blend.blendMode);
        expect(fromMap.boneMask, blend.boneMask);
      });

      test('copyWith creates modified copy', () {
        const original = AnimationBlend(animationId: 'idle', weight: 0.3);

        final modified = original.copyWith(weight: 0.7, speed: 2.0);

        expect(modified.animationId, original.animationId);
        expect(modified.weight, 0.7);
        expect(modified.speed, 2.0);
        expect(modified.blendMode, original.blendMode);
      });
    });

    group('AnimationBlendSet', () {
      test('creates blend set with animations', () {
        const blendSet = AnimationBlendSet(
          id: 'movement',
          animations: [
            AnimationBlend(animationId: 'walk', weight: 0.6),
            AnimationBlend(animationId: 'run', weight: 0.4),
          ],
        );

        expect(blendSet.id, 'movement');
        expect(blendSet.animations.length, 2);
        expect(blendSet.totalWeight, 1.0);
        expect(blendSet.blendType, BlendType.linear);
        expect(blendSet.normalizeWeights, true);
      });

      test('calculates total weight correctly', () {
        const blendSet = AnimationBlendSet(
          id: 'test',
          animations: [
            AnimationBlend(animationId: 'a', weight: 0.3),
            AnimationBlend(animationId: 'b', weight: 0.5),
            AnimationBlend(animationId: 'c', weight: 0.2),
          ],
        );

        expect(blendSet.totalWeight, 1.0);
      });

      test('normalizes weights when requested', () {
        final blendSet = AnimationBlendSet(
          id: 'test',
          animations: [
            AnimationBlend(animationId: 'a', weight: 0.3),
            AnimationBlend(animationId: 'b', weight: 0.5),
          ],
          normalizeWeights: true,
        );

        // Test that normalization works correctly when total weight != 1.0
        expect(blendSet.totalWeight, 0.8);

        final normalized = blendSet.normalized;
        expect(normalized.animations[0].weight, closeTo(0.3 / 0.8, 0.001));
        expect(normalized.animations[1].weight, closeTo(0.5 / 0.8, 0.001));
        expect(normalized.totalWeight, closeTo(1.0, 0.001));
      });

      test('converts to and from map', () {
        const blendSet = AnimationBlendSet(
          id: 'combat',
          animations: [
            AnimationBlend(animationId: 'guard', weight: 0.7),
            AnimationBlend(animationId: 'ready', weight: 0.3),
          ],
          blendType: BlendType.cubic,
          fadeInDuration: 0.5,
        );

        final map = blendSet.toMap();
        final fromMap = AnimationBlendSet.fromMap(map);

        expect(fromMap.id, blendSet.id);
        expect(fromMap.animations.length, blendSet.animations.length);
        expect(fromMap.blendType, blendSet.blendType);
        expect(fromMap.fadeInDuration, blendSet.fadeInDuration);
      });
    });

    group('AnimationTransition', () {
      test('creates transition with required parameters', () {
        const transition = AnimationTransition(
          id: 'walk_to_run',
          fromAnimationId: 'walk',
          toAnimationId: 'run',
          duration: 0.5,
        );

        expect(transition.id, 'walk_to_run');
        expect(transition.fromAnimationId, 'walk');
        expect(transition.toAnimationId, 'run');
        expect(transition.duration, 0.5);
        expect(transition.curve, TransitionCurve.linear);
        expect(transition.fadeOut, true);
        expect(transition.fadeIn, true);
      });

      test('validates duration is positive', () {
        expect(
          () => AnimationTransition(
            id: 'test',
            toAnimationId: 'target',
            duration: 0.0,
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => AnimationTransition(
            id: 'test',
            toAnimationId: 'target',
            duration: -0.1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('can transition from specified animation', () {
        const transition = AnimationTransition(
          id: 'specific',
          fromAnimationId: 'idle',
          toAnimationId: 'walk',
          duration: 0.3,
        );

        expect(transition.canTransitionFrom('idle'), true);
        expect(transition.canTransitionFrom('run'), false);
      });

      test(
        'can transition from any animation when fromAnimationId is null',
        () {
          const transition = AnimationTransition(
            id: 'any_to_stop',
            toAnimationId: 'stop',
            duration: 0.2,
          );

          expect(transition.canTransitionFrom('idle'), true);
          expect(transition.canTransitionFrom('walk'), true);
          expect(transition.canTransitionFrom('run'), true);
        },
      );

      test('checks conditions correctly', () {
        const transition = AnimationTransition(
          id: 'conditional',
          toAnimationId: 'special',
          duration: 0.3,
          conditions: {'speed': 5.0, 'grounded': true},
        );

        expect(
          transition.checkConditions({'speed': 5.0, 'grounded': true}),
          true,
        );
        expect(
          transition.checkConditions({'speed': 3.0, 'grounded': true}),
          false,
        );
        expect(
          transition.checkConditions({'speed': 5.0, 'grounded': false}),
          false,
        );
      });

      test('converts to and from map', () {
        const transition = AnimationTransition(
          id: 'test_transition',
          fromAnimationId: 'idle',
          toAnimationId: 'walk',
          duration: 0.4,
          curve: TransitionCurve.easeInOut,
          priority: 5,
        );

        final map = transition.toMap();
        final fromMap = AnimationTransition.fromMap(map);

        expect(fromMap.id, transition.id);
        expect(fromMap.fromAnimationId, transition.fromAnimationId);
        expect(fromMap.toAnimationId, transition.toAnimationId);
        expect(fromMap.duration, transition.duration);
        expect(fromMap.curve, transition.curve);
        expect(fromMap.priority, transition.priority);
      });
    });

    group('TransitionStatus', () {
      test('creates status with correct values', () {
        const status = TransitionStatus(
          transitionId: 'fade1',
          state: TransitionState.transitioning,
          toAnimationId: 'run',
          progress: 0.5,
          elapsedTime: 0.15,
          totalDuration: 0.3,
          sourceWeight: 0.5,
          targetWeight: 0.5,
        );

        expect(status.transitionId, 'fade1');
        expect(status.state, TransitionState.transitioning);
        expect(status.isActive, true);
        expect(status.progress, 0.5);
        expect(status.remainingTime, 0.15);
      });

      test('validates progress range', () {
        expect(
          () => TransitionStatus(
            transitionId: 'test',
            state: TransitionState.transitioning,
            toAnimationId: 'target',
            progress: -0.1,
            elapsedTime: 0.0,
            totalDuration: 1.0,
            sourceWeight: 1.0,
            targetWeight: 0.0,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('converts to and from map', () {
        const status = TransitionStatus(
          transitionId: 'transition1',
          state: TransitionState.completed,
          fromAnimationId: 'walk',
          toAnimationId: 'idle',
          progress: 1.0,
          elapsedTime: 0.5,
          totalDuration: 0.5,
          sourceWeight: 0.0,
          targetWeight: 1.0,
        );

        final map = status.toMap();
        final fromMap = TransitionStatus.fromMap(map);

        expect(fromMap.transitionId, status.transitionId);
        expect(fromMap.state, status.state);
        expect(fromMap.fromAnimationId, status.fromAnimationId);
        expect(fromMap.progress, status.progress);
      });
    });

    group('CrossfadeTransition', () {
      test('creates crossfade with default values', () {
        const crossfade = CrossfadeTransition(
          id: 'fade1',
          fromAnimationId: 'walk',
          toAnimationId: 'run',
          duration: 0.3,
        );

        expect(crossfade.id, 'fade1');
        expect(crossfade.fromAnimationId, 'walk');
        expect(crossfade.toAnimationId, 'run');
        expect(crossfade.duration, 0.3);
        expect(crossfade.fadeOut, true);
        expect(crossfade.fadeIn, true);
        expect(crossfade.blendMode, AnimationBlendMode.weighted);
      });

      test('calculates weights at progress points', () {
        const crossfade = CrossfadeTransition(
          id: 'test',
          toAnimationId: 'target',
          duration: 1.0,
        );

        // At 0% progress
        expect(crossfade.getSourceWeightAtProgress(0.0), 1.0);
        expect(crossfade.getTargetWeightAtProgress(0.0), 0.0);

        // At 50% progress
        expect(crossfade.getSourceWeightAtProgress(0.5), 0.5);
        expect(crossfade.getTargetWeightAtProgress(0.5), 0.5);

        // At 100% progress
        expect(crossfade.getSourceWeightAtProgress(1.0), 0.0);
        expect(crossfade.getTargetWeightAtProgress(1.0), 1.0);
      });

      test('uses custom weight curves when provided', () {
        const crossfade = CrossfadeTransition(
          id: 'custom',
          toAnimationId: 'target',
          duration: 1.0,
          sourceWeightCurve: [1.0, 0.8, 0.3, 0.0],
          targetWeightCurve: [0.0, 0.2, 0.7, 1.0],
        );

        expect(crossfade.getSourceWeightAtProgress(0.0), 1.0);
        expect(crossfade.getTargetWeightAtProgress(1.0), 1.0);
      });
    });

    group('AnimationStateMachine', () {
      late AnimationStateMachine stateMachine;

      setUp(() {
        stateMachine = AnimationStateMachine(
          id: 'character_fsm',
          name: 'Character State Machine',
          states: [
            sm.AnimationState(
              id: 'idle',
              name: 'Idle',
              animationId: 'idle_anim',
              isEntryState: true,
              transitions: [
                AnimationTransition(
                  id: 'idle_to_walk',
                  toAnimationId: 'walk',
                  duration: 0.2,
                  conditions: {'moving': true},
                ),
              ],
            ),
            sm.AnimationState(
              id: 'walk',
              name: 'Walk',
              animationId: 'walk_anim',
              transitions: [
                AnimationTransition(
                  id: 'walk_to_idle',
                  toAnimationId: 'idle',
                  duration: 0.2,
                  conditions: {'moving': false},
                ),
                AnimationTransition(
                  id: 'walk_to_run',
                  toAnimationId: 'run',
                  duration: 0.3,
                  conditions: {'speed': 5.0},
                ),
              ],
            ),
            sm.AnimationState(id: 'run', name: 'Run', animationId: 'run_anim'),
            sm.AnimationState(
              id: 'stop',
              name: 'Stop',
              animationId: 'stop_anim',
            ),
          ],
          anyStateTransitions: [
            AnimationTransition(
              id: 'any_to_stop',
              toAnimationId: 'stop',
              duration: 0.1,
              priority: 10,
              conditions: {'emergency_stop': true},
            ),
          ],
        );
      });

      test('finds states correctly', () {
        final idle = stateMachine.findState('idle');
        expect(idle, isNotNull);
        expect(idle!.name, 'Idle');

        final invalid = stateMachine.findState('invalid');
        expect(invalid, isNull);
      });

      test('identifies entry state correctly', () {
        final entry = stateMachine.entryState;
        expect(entry, isNotNull);
        expect(entry!.id, 'idle');
      });

      test('finds transitions correctly', () {
        final transition = stateMachine.findTransition('idle', 'walk', {
          'moving': true,
        });
        expect(transition, isNotNull);
        expect(transition!.id, 'idle_to_walk');

        final noTransition = stateMachine.findTransition('idle', 'walk', {
          'moving': false,
        });
        expect(noTransition, isNull);
      });

      test('prioritizes any-state transitions', () {
        final transition = stateMachine.findTransition('walk', 'stop', {
          'emergency_stop': true,
        });
        expect(transition, isNotNull);
        expect(transition!.id, 'any_to_stop');
        expect(transition.priority, 10);
      });

      test('validates state machine correctly', () {
        expect(stateMachine.validate(), true);

        // Test invalid state machine (duplicate IDs)
        final invalidMachine = AnimationStateMachine(
          id: 'invalid',
          name: 'Invalid',
          states: [
            sm.AnimationState(
              id: 'duplicate',
              name: 'State1',
              animationId: 'anim1',
            ),
            sm.AnimationState(
              id: 'duplicate',
              name: 'State2',
              animationId: 'anim2',
            ),
          ],
        );
        expect(invalidMachine.validate(), false);
      });

      test('converts to and from map', () {
        final map = stateMachine.toMap();
        final fromMap = AnimationStateMachine.fromMap(map);

        expect(fromMap.id, stateMachine.id);
        expect(fromMap.name, stateMachine.name);
        expect(fromMap.states.length, stateMachine.states.length);
        expect(
          fromMap.anyStateTransitions.length,
          stateMachine.anyStateTransitions.length,
        );
      });
    });

    group('StateMachineStatus', () {
      test('creates status with correct values', () {
        const status = StateMachineStatus(
          stateMachineId: 'fsm1',
          currentStateId: 'walk',
          previousStateId: 'idle',
          timeInState: 2.5,
          isActive: true,
          parameters: {'speed': 3.0},
        );

        expect(status.stateMachineId, 'fsm1');
        expect(status.currentStateId, 'walk');
        expect(status.previousStateId, 'idle');
        expect(status.timeInState, 2.5);
        expect(status.isActive, true);
        expect(status.isTransitioning, false);
      });

      test('detects transitioning state', () {
        const status = StateMachineStatus(
          stateMachineId: 'fsm1',
          currentStateId: 'walk',
          timeInState: 1.0,
          currentTransition: TransitionStatus(
            transitionId: 'transition1',
            state: TransitionState.transitioning,
            toAnimationId: 'run',
            progress: 0.5,
            elapsedTime: 0.15,
            totalDuration: 0.3,
            sourceWeight: 0.5,
            targetWeight: 0.5,
          ),
          isActive: true,
        );

        expect(status.isTransitioning, true);
      });

      test('converts to and from map', () {
        const status = StateMachineStatus(
          stateMachineId: 'test_fsm',
          currentStateId: 'running',
          timeInState: 1.5,
          isActive: true,
        );

        final map = status.toMap();
        final fromMap = StateMachineStatus.fromMap(map);

        expect(fromMap.stateMachineId, status.stateMachineId);
        expect(fromMap.currentStateId, status.currentStateId);
        expect(fromMap.timeInState, status.timeInState);
        expect(fromMap.isActive, status.isActive);
      });
    });

    group('Enum Tests', () {
      test('AnimationBlendMode has all expected values', () {
        expect(AnimationBlendMode.values.length, 5);
        expect(AnimationBlendMode.values, contains(AnimationBlendMode.replace));
        expect(
          AnimationBlendMode.values,
          contains(AnimationBlendMode.additive),
        );
        expect(
          AnimationBlendMode.values,
          contains(AnimationBlendMode.weighted),
        );
        expect(
          AnimationBlendMode.values,
          contains(AnimationBlendMode.override),
        );
        expect(
          AnimationBlendMode.values,
          contains(AnimationBlendMode.multiply),
        );
      });

      test('BlendType has all expected values', () {
        expect(BlendType.values.length, 4);
        expect(BlendType.values, contains(BlendType.linear));
        expect(BlendType.values, contains(BlendType.slerp));
        expect(BlendType.values, contains(BlendType.cubic));
        expect(BlendType.values, contains(BlendType.step));
      });

      test('TransitionCurve has all expected values', () {
        expect(TransitionCurve.values.length, 7);
        expect(TransitionCurve.values, contains(TransitionCurve.linear));
        expect(TransitionCurve.values, contains(TransitionCurve.easeIn));
        expect(TransitionCurve.values, contains(TransitionCurve.easeOut));
        expect(TransitionCurve.values, contains(TransitionCurve.easeInOut));
      });

      test('TransitionState has all expected values', () {
        expect(TransitionState.values.length, 4);
        expect(TransitionState.values, contains(TransitionState.idle));
        expect(TransitionState.values, contains(TransitionState.transitioning));
        expect(TransitionState.values, contains(TransitionState.completed));
        expect(TransitionState.values, contains(TransitionState.interrupted));
      });
    });
  });
}
