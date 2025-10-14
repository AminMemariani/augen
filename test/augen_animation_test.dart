import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Animation Tests', () {
    group('ARAnimation', () {
      test('creates animation with default values', () {
        const animation = ARAnimation(id: 'anim1');

        expect(animation.id, 'anim1');
        expect(animation.name, isNull);
        expect(animation.duration, isNull);
        expect(animation.speed, 1.0);
        expect(animation.loopMode, AnimationLoopMode.loop);
        expect(animation.autoPlay, true);
        expect(animation.startTime, 0.0);
        expect(animation.endTime, isNull);
      });

      test('creates animation with custom values', () {
        const animation = ARAnimation(
          id: 'anim1',
          name: 'walk',
          duration: 2.5,
          speed: 1.5,
          loopMode: AnimationLoopMode.once,
          autoPlay: false,
          startTime: 0.5,
          endTime: 2.0,
        );

        expect(animation.id, 'anim1');
        expect(animation.name, 'walk');
        expect(animation.duration, 2.5);
        expect(animation.speed, 1.5);
        expect(animation.loopMode, AnimationLoopMode.once);
        expect(animation.autoPlay, false);
        expect(animation.startTime, 0.5);
        expect(animation.endTime, 2.0);
      });

      test('converts to and from map', () {
        const animation = ARAnimation(
          id: 'anim1',
          name: 'run',
          duration: 3.0,
          speed: 2.0,
          loopMode: AnimationLoopMode.pingPong,
        );

        final map = animation.toMap();
        final fromMap = ARAnimation.fromMap(map);

        expect(fromMap.id, animation.id);
        expect(fromMap.name, animation.name);
        expect(fromMap.duration, animation.duration);
        expect(fromMap.speed, animation.speed);
        expect(fromMap.loopMode, animation.loopMode);
        expect(fromMap.autoPlay, animation.autoPlay);
      });

      test('copyWith creates modified copy', () {
        const original = ARAnimation(
          id: 'anim1',
          speed: 1.0,
          loopMode: AnimationLoopMode.loop,
        );

        final modified = original.copyWith(
          speed: 2.0,
          loopMode: AnimationLoopMode.once,
        );

        expect(modified.id, original.id);
        expect(modified.speed, 2.0);
        expect(modified.loopMode, AnimationLoopMode.once);
      });

      test('toString returns correct format', () {
        const animation = ARAnimation(
          id: 'anim1',
          name: 'walk',
          speed: 1.5,
          loopMode: AnimationLoopMode.loop,
        );

        final str = animation.toString();
        expect(str, contains('ARAnimation'));
        expect(str, contains('anim1'));
        expect(str, contains('walk'));
      });
    });

    group('AnimationLoopMode', () {
      test('all modes are available', () {
        expect(AnimationLoopMode.values.length, 3);
        expect(AnimationLoopMode.values, contains(AnimationLoopMode.once));
        expect(AnimationLoopMode.values, contains(AnimationLoopMode.loop));
        expect(AnimationLoopMode.values, contains(AnimationLoopMode.pingPong));
      });

      test('mode names are correct', () {
        expect(AnimationLoopMode.once.name, 'once');
        expect(AnimationLoopMode.loop.name, 'loop');
        expect(AnimationLoopMode.pingPong.name, 'pingPong');
      });
    });

    group('AnimationState', () {
      test('all states are available', () {
        expect(AnimationState.values.length, 3);
        expect(AnimationState.values, contains(AnimationState.stopped));
        expect(AnimationState.values, contains(AnimationState.playing));
        expect(AnimationState.values, contains(AnimationState.paused));
      });

      test('state names are correct', () {
        expect(AnimationState.stopped.name, 'stopped');
        expect(AnimationState.playing.name, 'playing');
        expect(AnimationState.paused.name, 'paused');
      });
    });

    group('AnimationStatus', () {
      test('creates status with correct values', () {
        const status = AnimationStatus(
          animationId: 'anim1',
          state: AnimationState.playing,
          currentTime: 1.5,
          duration: 3.0,
          isLooping: true,
        );

        expect(status.animationId, 'anim1');
        expect(status.state, AnimationState.playing);
        expect(status.currentTime, 1.5);
        expect(status.duration, 3.0);
        expect(status.isLooping, true);
      });

      test('converts to and from map', () {
        const status = AnimationStatus(
          animationId: 'anim1',
          state: AnimationState.playing,
          currentTime: 2.0,
          duration: 5.0,
          isLooping: true,
        );

        final map = status.toMap();
        final fromMap = AnimationStatus.fromMap(map);

        expect(fromMap.animationId, status.animationId);
        expect(fromMap.state, status.state);
        expect(fromMap.currentTime, status.currentTime);
        expect(fromMap.duration, status.duration);
        expect(fromMap.isLooping, status.isLooping);
      });

      test('parses all animation states correctly', () {
        final stopped = AnimationStatus.fromMap({
          'animationId': 'anim1',
          'state': 'stopped',
          'currentTime': 0.0,
        });
        expect(stopped.state, AnimationState.stopped);

        final playing = AnimationStatus.fromMap({
          'animationId': 'anim2',
          'state': 'playing',
          'currentTime': 1.5,
        });
        expect(playing.state, AnimationState.playing);

        final paused = AnimationStatus.fromMap({
          'animationId': 'anim3',
          'state': 'paused',
          'currentTime': 2.5,
        });
        expect(paused.state, AnimationState.paused);
      });

      test('toString returns correct format', () {
        const status = AnimationStatus(
          animationId: 'anim1',
          state: AnimationState.playing,
          currentTime: 1.5,
        );

        final str = status.toString();
        expect(str, contains('AnimationStatus'));
        expect(str, contains('anim1'));
        expect(str, contains('playing'));
      });
    });

    group('ARNode with Animations', () {
      test('creates node with animations', () {
        final node = ARNode.fromModel(
          id: 'character1',
          modelPath: 'assets/models/character.glb',
          position: Vector3.zero(),
          animations: [
            const ARAnimation(id: 'walk', name: 'walk'),
            const ARAnimation(id: 'run', name: 'run'),
          ],
        );

        expect(node.animations, isNotNull);
        expect(node.animations!.length, 2);
        expect(node.animations![0].name, 'walk');
        expect(node.animations![1].name, 'run');
      });

      test('serializes node with animations', () {
        final node = ARNode.fromModel(
          id: 'character1',
          modelPath: 'assets/models/character.glb',
          position: Vector3.zero(),
          animations: [const ARAnimation(id: 'idle', name: 'idle', speed: 0.5)],
        );

        final map = node.toMap();
        expect(map['animations'], isNotNull);
        expect(map['animations'], isA<List>());

        final animations = map['animations'] as List;
        expect(animations.length, 1);
        expect(animations[0]['id'], 'idle');
        expect(animations[0]['name'], 'idle');
        expect(animations[0]['speed'], 0.5);
      });

      test('deserializes node with animations', () {
        final map = {
          'id': 'character1',
          'type': 'model',
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
          'modelPath': 'assets/models/character.glb',
          'modelFormat': 'glb',
          'animations': [
            {
              'id': 'walk',
              'name': 'walk',
              'speed': 1.0,
              'loopMode': 'loop',
              'autoPlay': true,
              'startTime': 0.0,
            },
          ],
        };

        final node = ARNode.fromMap(map);
        expect(node.animations, isNotNull);
        expect(node.animations!.length, 1);
        expect(node.animations![0].id, 'walk');
        expect(node.animations![0].name, 'walk');
      });

      test('copyWith preserves animations', () {
        final original = ARNode.fromModel(
          id: 'model1',
          modelPath: 'assets/models/animated.glb',
          position: Vector3.zero(),
          animations: [const ARAnimation(id: 'anim1', name: 'animate')],
        );

        final modified = original.copyWith(position: Vector3(1, 2, 3));

        expect(modified.animations, isNotNull);
        expect(modified.animations!.length, 1);
        expect(modified.animations![0].id, 'anim1');
      });
    });
  });
}
