import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';
import 'package:augen/src/models/animation_state_machine.dart' as sm;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AugenController', () {
    late AugenController controller;
    late MethodChannel channel;
    final int viewId = 123;

    setUp(() {
      controller = AugenController(viewId);
      channel = MethodChannel('augen_$viewId');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('creates controller with correct viewId', () {
      expect(controller.viewId, viewId);
    });

    test('initialize sends correct config', () async {
      const config = ARSessionConfig(
        planeDetection: true,
        lightEstimation: false,
        depthData: true,
        autoFocus: false,
      );

      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.initialize(config);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['planeDetection'], true);
      expect(capturedArgs!['lightEstimation'], false);
      expect(capturedArgs!['depthData'], true);
      expect(capturedArgs!['autoFocus'], false);
    });

    test('isARSupported returns true when supported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'isARSupported') {
              return true;
            }
            return null;
          });

      final result = await controller.isARSupported();
      expect(result, true);
    });

    test('isARSupported returns false when not supported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'isARSupported') {
              return false;
            }
            return null;
          });

      final result = await controller.isARSupported();
      expect(result, false);
    });

    test('addNode sends correct node data', () async {
      final node = ARNode(
        id: 'node1',
        type: NodeType.sphere,
        position: Vector3(1.0, 2.0, 3.0),
        rotation: Quaternion(0.1, 0.2, 0.3, 0.4),
        scale: Vector3(2.0, 2.0, 2.0),
      );

      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'addNode') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.addNode(node);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['id'], 'node1');
      expect(capturedArgs!['type'], 'sphere');
    });

    test('removeNode sends correct nodeId', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'removeNode') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.removeNode('node1');

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
    });

    test('updateNode sends correct node data', () async {
      final node = ARNode(
        id: 'node1',
        type: NodeType.cube,
        position: Vector3(4.0, 5.0, 6.0),
      );

      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'updateNode') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.updateNode(node);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['id'], 'node1');
    });

    test('hitTest returns results', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'hitTest') {
              return [
                {
                  'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                  'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                  'distance': 1.5,
                  'planeId': 'plane1',
                },
              ];
            }
            return null;
          });

      final results = await controller.hitTest(100.0, 200.0);

      expect(results.length, 1);
      expect(results[0].distance, 1.5);
      expect(results[0].planeId, 'plane1');
    });

    test('hitTest returns empty list on null result', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'hitTest') {
              return null;
            }
            return null;
          });

      final results = await controller.hitTest(100.0, 200.0);
      expect(results, isEmpty);
    });

    test('addAnchor returns anchor', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'addAnchor') {
              return {
                'id': 'anchor1',
                'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
            }
            return null;
          });

      final anchor = await controller.addAnchor(Vector3(1.0, 2.0, 3.0));

      expect(anchor, isNotNull);
      expect(anchor!.id, 'anchor1');
    });

    test('addAnchor returns null on null result', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'addAnchor') {
              return null;
            }
            return null;
          });

      final anchor = await controller.addAnchor(Vector3(1.0, 2.0, 3.0));
      expect(anchor, isNull);
    });

    test('removeAnchor sends correct anchorId', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'removeAnchor') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.removeAnchor('anchor1');

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['anchorId'], 'anchor1');
    });

    test('pause calls platform method', () async {
      bool pauseCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'pause') {
              pauseCalled = true;
            }
            return null;
          });

      await controller.pause();
      expect(pauseCalled, true);
    });

    test('resume calls platform method', () async {
      bool resumeCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'resume') {
              resumeCalled = true;
            }
            return null;
          });

      await controller.resume();
      expect(resumeCalled, true);
    });

    test('reset calls platform method', () async {
      bool resetCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'reset') {
              resetCalled = true;
            }
            return null;
          });

      await controller.reset();
      expect(resetCalled, true);
    });

    test('planesStream emits planes from platform', () async {
      final completer = Completer<List<ARPlane>>();

      controller.planesStream.listen((planes) {
        if (!completer.isCompleted) {
          completer.complete(planes);
        }
      });

      // Simulate platform callback
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'augen_$viewId',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onPlanesUpdated', [
            {
              'id': 'plane1',
              'center': {'x': 0.0, 'y': 0.0, 'z': 0.0},
              'extent': {'x': 1.0, 'y': 0.1, 'z': 1.0},
              'type': 'horizontal',
            },
          ]),
        ),
        (data) {},
      );

      final planes = await completer.future.timeout(Duration(seconds: 2));
      expect(planes.length, 1);
      expect(planes[0].id, 'plane1');
    });

    test('anchorsStream emits anchors from platform', () async {
      final completer = Completer<List<ARAnchor>>();

      controller.anchorsStream.listen((anchors) {
        if (!completer.isCompleted) {
          completer.complete(anchors);
        }
      });

      // Simulate platform callback
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'augen_$viewId',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onAnchorsUpdated', [
            {
              'id': 'anchor1',
              'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
              'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          ]),
        ),
        (data) {},
      );

      final anchors = await completer.future.timeout(Duration(seconds: 2));
      expect(anchors.length, 1);
      expect(anchors[0].id, 'anchor1');
    });

    test('errorStream emits errors from platform', () async {
      final completer = Completer<String>();

      controller.errorStream.listen((error) {
        if (!completer.isCompleted) {
          completer.complete(error);
        }
      });

      // Simulate platform callback
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'augen_$viewId',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onError', 'Test error message'),
        ),
        (data) {},
      );

      final error = await completer.future.timeout(Duration(seconds: 2));
      expect(error, 'Test error message');
    });

    test('throws StateError when used after dispose', () async {
      controller.dispose();

      expect(
        () => controller.initialize(ARSessionConfig()),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.isARSupported(), throwsA(isA<StateError>()));
      expect(
        () => controller.addNode(
          ARNode(id: 'n1', type: NodeType.sphere, position: Vector3.zero()),
        ),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.removeNode('n1'), throwsA(isA<StateError>()));
      expect(
        () => controller.updateNode(
          ARNode(id: 'n1', type: NodeType.sphere, position: Vector3.zero()),
        ),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.hitTest(0, 0), throwsA(isA<StateError>()));
      expect(
        () => controller.addAnchor(Vector3.zero()),
        throwsA(isA<StateError>()),
      );
      expect(() => controller.removeAnchor('a1'), throwsA(isA<StateError>()));
      expect(() => controller.pause(), throwsA(isA<StateError>()));
      expect(() => controller.resume(), throwsA(isA<StateError>()));
      expect(() => controller.reset(), throwsA(isA<StateError>()));
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      // Should not throw, but should add to error stream
      final errorCompleter = Completer<String>();
      controller.errorStream.listen((error) {
        if (!errorCompleter.isCompleted) {
          errorCompleter.complete(error);
        }
      });

      expect(
        controller.initialize(ARSessionConfig()),
        throwsA(isA<PlatformException>()),
      );

      final error = await errorCompleter.future.timeout(Duration(seconds: 2));
      expect(error, contains('Failed to initialize AR'));
    });

    test('dispose can be called multiple times safely', () {
      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
    });

    test('addModelFromAsset creates model node with correct parameters', () {
      // Test that ARNode.fromModel factory creates the correct structure
      final model = ARNode.fromModel(
        id: 'model1',
        modelPath: 'assets/models/test.glb',
        position: Vector3(1, 2, 3),
        scale: Vector3(0.5, 0.5, 0.5),
      );

      expect(model.id, 'model1');
      expect(model.type, NodeType.model);
      expect(model.modelPath, 'assets/models/test.glb');
      expect(model.modelFormat, ModelFormat.glb);
      expect(model.position, Vector3(1, 2, 3));
      expect(model.scale, Vector3(0.5, 0.5, 0.5));
    });

    test('addModelFromUrl creates correct model node', () async {
      bool nodeAdded = false;
      Map? capturedNodeData;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'addNode') {
              nodeAdded = true;
              capturedNodeData = methodCall.arguments as Map?;
            }
            return null;
          });

      await controller.addModelFromUrl(
        id: 'model2',
        url: 'https://example.com/model.glb',
        position: Vector3(4, 5, 6),
        modelFormat: ModelFormat.glb,
      );

      expect(nodeAdded, true);
      expect(capturedNodeData!['id'], 'model2');
      expect(capturedNodeData!['type'], 'model');
      expect(capturedNodeData!['modelPath'], 'https://example.com/model.glb');
      expect(capturedNodeData!['modelFormat'], 'glb');
    });

    test('playAnimation sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'playAnimation') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.playAnimation(
        nodeId: 'node1',
        animationId: 'walk',
        speed: 1.5,
        loopMode: AnimationLoopMode.loop,
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
      expect(capturedArgs!['speed'], 1.5);
      expect(capturedArgs!['loopMode'], 'loop');
    });

    test('pauseAnimation sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'pauseAnimation') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.pauseAnimation(nodeId: 'node1', animationId: 'walk');

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
    });

    test('stopAnimation sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'stopAnimation') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.stopAnimation(nodeId: 'node1', animationId: 'walk');

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
    });

    test('resumeAnimation sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'resumeAnimation') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.resumeAnimation(nodeId: 'node1', animationId: 'walk');

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
    });

    test('seekAnimation sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'seekAnimation') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.seekAnimation(
        nodeId: 'node1',
        animationId: 'walk',
        time: 2.5,
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
      expect(capturedArgs!['time'], 2.5);
    });

    test('getAvailableAnimations returns list', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'getAvailableAnimations') {
              return ['walk', 'run', 'idle'];
            }
            return null;
          });

      final animations = await controller.getAvailableAnimations('node1');

      expect(animations, isA<List<String>>());
      expect(animations.length, 3);
      expect(animations, contains('walk'));
      expect(animations, contains('run'));
      expect(animations, contains('idle'));
    });

    test('setAnimationSpeed sends correct parameters', () async {
      Map? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'setAnimationSpeed') {
              capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
            }
            return null;
          });

      await controller.setAnimationSpeed(
        nodeId: 'node1',
        animationId: 'walk',
        speed: 2.0,
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['nodeId'], 'node1');
      expect(capturedArgs!['animationId'], 'walk');
      expect(capturedArgs!['speed'], 2.0);
    });

    test('animationStatusStream emits status from platform', () async {
      final completer = Completer<AnimationStatus>();

      controller.animationStatusStream.listen((status) {
        if (!completer.isCompleted) {
          completer.complete(status);
        }
      });

      // Simulate platform callback
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'augen_$viewId',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onAnimationStatus', {
            'animationId': 'walk',
            'state': 'playing',
            'currentTime': 1.5,
            'duration': 3.0,
            'isLooping': true,
          }),
        ),
        (data) {},
      );

      final status = await completer.future.timeout(Duration(seconds: 2));
      expect(status.animationId, 'walk');
      expect(status.state, AnimationState.playing);
      expect(status.currentTime, 1.5);
    });

    // ===== ANIMATION BLENDING TESTS =====

    group('Animation Blending Methods', () {
      test('playBlendSet sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'playBlendSet') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final blendSet = AnimationBlendSet(
          id: 'test_blend',
          animations: [
            AnimationBlend(animationId: 'walk', weight: 0.6),
            AnimationBlend(animationId: 'run', weight: 0.4),
          ],
        );

        await controller.playBlendSet(nodeId: 'character1', blendSet: blendSet);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['blendSet'], isA<Map>());
        expect(capturedArgs!['blendSet']['id'], 'test_blend');
      });

      test('stopBlendSet sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'stopBlendSet') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.stopBlendSet(
          nodeId: 'character1',
          blendSetId: 'test_blend',
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['blendSetId'], 'test_blend');
      });

      test('updateBlendWeights sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'updateBlendWeights') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.updateBlendWeights(
          nodeId: 'character1',
          blendSetId: 'test_blend',
          weights: {'walk': 0.3, 'run': 0.7},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['blendSetId'], 'test_blend');
        expect(capturedArgs!['weights'], {'walk': 0.3, 'run': 0.7});
      });

      test('startCrossfadeTransition sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'startCrossfadeTransition') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final transition = CrossfadeTransition(
          id: 'walk_to_run',
          fromAnimationId: 'walk',
          toAnimationId: 'run',
          duration: 0.5,
        );

        await controller.startCrossfadeTransition(
          nodeId: 'character1',
          transition: transition,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['transition'], isA<Map>());
      });

      test('startStateMachine sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'startStateMachine') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final stateMachine = AnimationStateMachine(
          id: 'character_fsm',
          name: 'Character FSM',
          states: [
            sm.AnimationState(
              id: 'idle',
              name: 'Idle',
              animationId: 'idle_anim',
              isEntryState: true,
            ),
          ],
        );

        await controller.startStateMachine(
          nodeId: 'character1',
          stateMachine: stateMachine,
          initialParameters: {'speed': 0.0},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['stateMachine'], isA<Map>());
        expect(capturedArgs!['initialParameters'], {'speed': 0.0});
      });

      test('updateStateMachineParameters sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'updateStateMachineParameters') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.updateStateMachineParameters(
          nodeId: 'character1',
          stateMachineId: 'character_fsm',
          parameters: {'speed': 2.5, 'grounded': true},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['stateMachineId'], 'character_fsm');
        expect(capturedArgs!['parameters'], {'speed': 2.5, 'grounded': true});
      });

      test('startBlendTree sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'startBlendTree') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final blendTree = AnimationBlendTree(
          id: 'movement_tree',
          name: 'Movement Tree',
          rootNode: AnimationNode(
            id: 'root',
            name: 'Root',
            animationId: 'idle',
          ),
        );

        await controller.startBlendTree(
          nodeId: 'character1',
          blendTree: blendTree,
          initialParameters: {'speed': 1.0},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['blendTree'], isA<Map>());
        expect(capturedArgs!['initialParameters'], {'speed': 1.0});
      });

      test('playAdditiveAnimation sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'playAdditiveAnimation') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.playAdditiveAnimation(
          nodeId: 'character1',
          animationId: 'wave',
          targetLayer: 1,
          weight: 0.8,
          boneMask: ['arm_left', 'arm_right'],
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['animationId'], 'wave');
        expect(capturedArgs!['targetLayer'], 1);
        expect(capturedArgs!['weight'], 0.8);
        expect(capturedArgs!['boneMask'], ['arm_left', 'arm_right']);
      });

      test('setAnimationLayerWeight sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setAnimationLayerWeight') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setAnimationLayerWeight(
          nodeId: 'character1',
          layer: 2,
          weight: 0.6,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        expect(capturedArgs!['layer'], 2);
        expect(capturedArgs!['weight'], 0.6);
      });

      test('getAnimationLayers returns layers', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getAnimationLayers') {
                return [
                  <String, dynamic>{
                    'layer': 0,
                    'weight': 1.0,
                    'animations': ['idle'],
                  },
                  <String, dynamic>{
                    'layer': 1,
                    'weight': 0.5,
                    'animations': ['wave'],
                  },
                ];
              }
              return null;
            });

        final layers = await controller.getAnimationLayers('character1');

        expect(layers.length, 2);
        expect(layers[0]['layer'], 0);
        expect(layers[0]['weight'], 1.0);
        expect(layers[1]['layer'], 1);
        expect(layers[1]['weight'], 0.5);
      });

      test('getBoneHierarchy returns bone names', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getBoneHierarchy') {
                return [
                  'root',
                  'spine',
                  'arm_left',
                  'arm_right',
                  'leg_left',
                  'leg_right',
                ];
              }
              return null;
            });

        final bones = await controller.getBoneHierarchy('character1');

        expect(bones.length, 6);
        expect(bones, contains('root'));
        expect(bones, contains('spine'));
        expect(bones, contains('arm_left'));
      });

      test('crossfadeToAnimation creates and starts transition', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'startCrossfadeTransition') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.crossfadeToAnimation(
          nodeId: 'character1',
          fromAnimationId: 'idle',
          toAnimationId: 'walk',
          duration: 0.4,
          curve: TransitionCurve.easeInOut,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        final transitionData = capturedArgs!['transition'] as Map;
        expect(transitionData['fromAnimationId'], 'idle');
        expect(transitionData['toAnimationId'], 'walk');
        expect(transitionData['duration'], 0.4);
      });

      test('blendAnimations creates and starts blend set', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'playBlendSet') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.blendAnimations(
          nodeId: 'character1',
          animationWeights: {'walk': 0.7, 'run': 0.3},
          fadeInDuration: 0.5,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'character1');
        final blendSetData = capturedArgs!['blendSet'] as Map;
        expect(blendSetData['fadeInDuration'], 0.5);
        final animations = blendSetData['animations'] as List;
        expect(animations.length, 2);
      });
    });

    group('Animation Blending Streams', () {
      test(
        'transitionStatusStream emits transition status from platform',
        () async {
          final completer = Completer<TransitionStatus>();

          controller.transitionStatusStream.listen((status) {
            if (!completer.isCompleted) {
              completer.complete(status);
            }
          });

          // Simulate platform callback
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          await messenger.handlePlatformMessage(
            'augen_$viewId',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onTransitionStatus', {
                'transitionId': 'fade1',
                'state': 'transitioning',
                'toAnimationId': 'run',
                'progress': 0.5,
                'elapsedTime': 0.15,
                'totalDuration': 0.3,
                'sourceWeight': 0.5,
                'targetWeight': 0.5,
              }),
            ),
            (data) {},
          );

          final status = await completer.future.timeout(Duration(seconds: 2));
          expect(status.transitionId, 'fade1');
          expect(status.state, TransitionState.transitioning);
          expect(status.progress, 0.5);
        },
      );

      test(
        'stateMachineStatusStream emits state machine status from platform',
        () async {
          final completer = Completer<StateMachineStatus>();

          controller.stateMachineStatusStream.listen((status) {
            if (!completer.isCompleted) {
              completer.complete(status);
            }
          });

          // Simulate platform callback
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          await messenger.handlePlatformMessage(
            'augen_$viewId',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onStateMachineStatus', {
                'stateMachineId': 'character_fsm',
                'currentStateId': 'walk',
                'previousStateId': 'idle',
                'timeInState': 2.5,
                'isActive': true,
                'parameters': {'speed': 3.0},
              }),
            ),
            (data) {},
          );

          final status = await completer.future.timeout(Duration(seconds: 2));
          expect(status.stateMachineId, 'character_fsm');
          expect(status.currentStateId, 'walk');
          expect(status.previousStateId, 'idle');
          expect(status.timeInState, 2.5);
        },
      );
    });

    group('Image Tracking Methods', () {
      test('addImageTarget sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'addImageTarget') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final target = ARImageTarget(
          id: 'target1',
          name: 'Test Target',
          imagePath: 'assets/images/test.jpg',
          physicalSize: const ImageTargetSize(10.0, 20.0),
        );

        await controller.addImageTarget(target);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['id'], 'target1');
        expect(capturedArgs!['name'], 'Test Target');
        expect(capturedArgs!['imagePath'], 'assets/images/test.jpg');
        expect(capturedArgs!['physicalSize']['width'], 10.0);
        expect(capturedArgs!['physicalSize']['height'], 20.0);
      });

      test('removeImageTarget sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removeImageTarget') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removeImageTarget('target1');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['targetId'], 'target1');
      });

      test('getImageTargets returns parsed targets', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getImageTargets') {
                return [
                  {
                    'id': 'target1',
                    'name': 'Test Target 1',
                    'imagePath': 'assets/images/test1.jpg',
                    'physicalSize': {'width': 10.0, 'height': 20.0},
                    'isActive': true,
                  },
                  {
                    'id': 'target2',
                    'name': 'Test Target 2',
                    'imagePath': 'assets/images/test2.jpg',
                    'physicalSize': {'width': 15.0, 'height': 25.0},
                    'isActive': false,
                  },
                ];
              }
              return null;
            });

        final targets = await controller.getImageTargets();

        expect(targets.length, 2);
        expect(targets[0].id, 'target1');
        expect(targets[0].name, 'Test Target 1');
        expect(targets[0].physicalSize.width, 10.0);
        expect(targets[0].isActive, true);
        expect(targets[1].id, 'target2');
        expect(targets[1].isActive, false);
      });

      test('getTrackedImages returns parsed tracked images', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getTrackedImages') {
                return [
                  {
                    'id': 'tracked1',
                    'targetId': 'target1',
                    'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'estimatedSize': {'width': 10.0, 'height': 20.0},
                    'trackingState': 'tracked',
                    'confidence': 0.85,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  },
                ];
              }
              return null;
            });

        final trackedImages = await controller.getTrackedImages();

        expect(trackedImages.length, 1);
        expect(trackedImages[0].id, 'tracked1');
        expect(trackedImages[0].targetId, 'target1');
        expect(trackedImages[0].position, const Vector3(1.0, 2.0, 3.0));
        expect(trackedImages[0].trackingState, ImageTrackingState.tracked);
        expect(trackedImages[0].confidence, 0.85);
      });

      test('setImageTrackingEnabled sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setImageTrackingEnabled') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setImageTrackingEnabled(true);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['enabled'], true);
      });

      test('isImageTrackingEnabled returns correct value', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isImageTrackingEnabled') {
                return true;
              }
              return null;
            });

        final enabled = await controller.isImageTrackingEnabled();

        expect(enabled, true);
      });

      test('addNodeToTrackedImage sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'addNodeToTrackedImage') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final node = ARNode.fromModel(
          id: 'node1',
          modelPath: 'https://example.com/models/test.glb',
          position: const Vector3(0, 0, 0),
        );

        await controller.addNodeToTrackedImage(
          nodeId: 'node1',
          trackedImageId: 'tracked1',
          node: node,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'node1');
        expect(capturedArgs!['nodeData']['id'], 'node1');
        expect(capturedArgs!['nodeData']['trackedImageId'], 'tracked1');
      });

      test('removeNodeFromTrackedImage sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removeNodeFromTrackedImage') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removeNodeFromTrackedImage('node1');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'node1');
      });
    });

    group('Image Tracking Streams', () {
      test('imageTargetsStream emits image targets from platform', () async {
        final completer = Completer<List<ARImageTarget>>();

        controller.imageTargetsStream.listen((targets) {
          if (!completer.isCompleted) {
            completer.complete(targets);
          }
        });

        // Simulate platform callback
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        await messenger.handlePlatformMessage(
          'augen_$viewId',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onImageTargetsUpdated', [
              {
                'id': 'target1',
                'name': 'Test Target',
                'imagePath': 'assets/images/test.jpg',
                'physicalSize': {'width': 10.0, 'height': 20.0},
                'isActive': true,
              },
            ]),
          ),
          (data) {},
        );

        final targets = await completer.future.timeout(Duration(seconds: 2));
        expect(targets.length, 1);
        expect(targets[0].id, 'target1');
        expect(targets[0].name, 'Test Target');
        expect(targets[0].physicalSize.width, 10.0);
      });

      test('trackedImagesStream emits tracked images from platform', () async {
        final completer = Completer<List<ARTrackedImage>>();

        controller.trackedImagesStream.listen((trackedImages) {
          if (!completer.isCompleted) {
            completer.complete(trackedImages);
          }
        });

        // Simulate platform callback
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        await messenger.handlePlatformMessage(
          'augen_$viewId',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onTrackedImagesUpdated', [
              {
                'id': 'tracked1',
                'targetId': 'target1',
                'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                'estimatedSize': {'width': 10.0, 'height': 20.0},
                'trackingState': 'tracked',
                'confidence': 0.85,
                'lastUpdated': 1672531200000, // Fixed timestamp
              },
            ]),
          ),
          (data) {},
        );

        final trackedImages = await completer.future.timeout(
          Duration(seconds: 2),
        );
        expect(trackedImages.length, 1);
        expect(trackedImages[0].id, 'tracked1');
        expect(trackedImages[0].targetId, 'target1');
        expect(trackedImages[0].trackingState, ImageTrackingState.tracked);
        expect(trackedImages[0].confidence, 0.85);
      });
    });

    group('Face Tracking Methods', () {
      test('setFaceTrackingEnabled sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setFaceTrackingEnabled') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setFaceTrackingEnabled(true);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['enabled'], true);
      });

      test('isFaceTrackingEnabled returns correct value', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isFaceTrackingEnabled') {
                return true;
              }
              return null;
            });

        final isEnabled = await controller.isFaceTrackingEnabled();
        expect(isEnabled, true);
      });

      test('getTrackedFaces returns parsed faces', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getTrackedFaces') {
                return [
                  {
                    'id': 'face1',
                    'position': {'x': 0.0, 'y': 0.0, 'z': -0.5},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'scale': {'x': 0.2, 'y': 0.3, 'z': 0.1},
                    'trackingState': 'tracked',
                    'confidence': 0.85,
                    'landmarks': [
                      {
                        'name': 'left_eye',
                        'position': {'x': -0.05, 'y': 0.1, 'z': 0.0},
                        'confidence': 0.9,
                      },
                    ],
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  },
                ];
              }
              return null;
            });

        final faces = await controller.getTrackedFaces();
        expect(faces.length, 1);
        expect(faces[0].id, 'face1');
        expect(faces[0].trackingState, FaceTrackingState.tracked);
        expect(faces[0].confidence, 0.85);
        expect(faces[0].landmarks.length, 1);
        expect(faces[0].landmarks[0].name, 'left_eye');
      });

      test('addNodeToTrackedFace sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'addNodeToTrackedFace') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        final node = ARNode(
          id: 'test_node',
          type: NodeType.sphere,
          position: const Vector3(0, 0, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(0.1, 0.1, 0.1),
        );

        await controller.addNodeToTrackedFace(
          nodeId: 'test_node',
          faceId: 'face1',
          node: node,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'test_node');
        expect(capturedArgs!['faceId'], 'face1');
        expect(capturedArgs!['node'], isA<Map>());
      });

      test('removeNodeFromTrackedFace sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removeNodeFromTrackedFace') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removeNodeFromTrackedFace(
          nodeId: 'test_node',
          faceId: 'face1',
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'test_node');
        expect(capturedArgs!['faceId'], 'face1');
      });

      test('getFaceLandmarks returns parsed landmarks', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getFaceLandmarks') {
                return [
                  {
                    'name': 'nose_tip',
                    'position': {'x': 0.0, 'y': 0.0, 'z': 0.1},
                    'confidence': 0.92,
                  },
                  {
                    'name': 'chin',
                    'position': {'x': 0.0, 'y': -0.1, 'z': 0.0},
                    'confidence': 0.88,
                  },
                ];
              }
              return null;
            });

        final landmarks = await controller.getFaceLandmarks('face1');
        expect(landmarks.length, 2);
        expect(landmarks[0].name, 'nose_tip');
        expect(landmarks[0].confidence, 0.92);
        expect(landmarks[1].name, 'chin');
        expect(landmarks[1].confidence, 0.88);
      });

      test('setFaceTrackingConfig sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setFaceTrackingConfig') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setFaceTrackingConfig(
          detectLandmarks: true,
          detectExpressions: false,
          minFaceSize: 0.15,
          maxFaceSize: 0.8,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['detectLandmarks'], true);
        expect(capturedArgs!['detectExpressions'], false);
        expect(capturedArgs!['minFaceSize'], 0.15);
        expect(capturedArgs!['maxFaceSize'], 0.8);
      });
    });

    group('Face Tracking Streams', () {
      test('facesStream can be listened to', () {
        // Test that the stream can be created and listened to
        final subscription = controller.facesStream.listen((faces) {
          // Stream is working
        });

        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Cloud Anchor Methods', () {
      test('createCloudAnchor sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'createCloudAnchor') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'cloud_anchor_123';
              }
              return null;
            });

        final cloudAnchorId = await controller.createCloudAnchor(
          'local_anchor_1',
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['localAnchorId'], 'local_anchor_1');
        expect(cloudAnchorId, 'cloud_anchor_123');
      });

      test('resolveCloudAnchor sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'resolveCloudAnchor') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.resolveCloudAnchor('cloud_anchor_123');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['cloudAnchorId'], 'cloud_anchor_123');
      });

      test('getCloudAnchors returns parsed anchors', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getCloudAnchors') {
                return [
                  {
                    'id': 'anchor_1',
                    'localAnchorId': 'local_1',
                    'state': 'created',
                    'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
                    'confidence': 0.9,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                    'isTracked': true,
                    'isReliable': true,
                  },
                ];
              }
              return null;
            });

        final anchors = await controller.getCloudAnchors();

        expect(anchors, isA<List<ARCloudAnchor>>());
        expect(anchors.length, 1);
        expect(anchors.first.id, 'anchor_1');
        expect(anchors.first.state, CloudAnchorState.created);
      });

      test('getCloudAnchor returns parsed anchor', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getCloudAnchor') {
                return {
                  'id': 'anchor_1',
                  'localAnchorId': 'local_1',
                  'state': 'created',
                  'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                  'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                  'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
                  'confidence': 0.9,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  'isTracked': true,
                  'isReliable': true,
                };
              }
              return null;
            });

        final anchor = await controller.getCloudAnchor('anchor_1');

        expect(anchor, isA<ARCloudAnchor>());
        expect(anchor!.id, 'anchor_1');
        expect(anchor.state, CloudAnchorState.created);
      });

      test('deleteCloudAnchor sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'deleteCloudAnchor') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.deleteCloudAnchor('cloud_anchor_123');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['cloudAnchorId'], 'cloud_anchor_123');
      });

      test('isCloudAnchorsSupported returns correct value', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isCloudAnchorsSupported') {
                return true;
              }
              return null;
            });

        final isSupported = await controller.isCloudAnchorsSupported();

        expect(isSupported, true);
      });

      test('setCloudAnchorConfig sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setCloudAnchorConfig') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setCloudAnchorConfig(
          maxCloudAnchors: 5,
          timeout: const Duration(seconds: 60),
          enableSharing: false,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['maxCloudAnchors'], 5);
        expect(capturedArgs!['timeoutMs'], 60000);
        expect(capturedArgs!['enableSharing'], false);
      });

      test('shareCloudAnchor returns session ID', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'shareCloudAnchor') {
                return 'session_123';
              }
              return null;
            });

        final sessionId = await controller.shareCloudAnchor('cloud_anchor_123');

        expect(sessionId, 'session_123');
      });

      test('joinCloudAnchorSession sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'joinCloudAnchorSession') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.joinCloudAnchorSession('session_123');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['sessionId'], 'session_123');
      });

      test('leaveCloudAnchorSession calls correct method', () async {
        bool methodCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'leaveCloudAnchorSession') {
                methodCalled = true;
              }
              return null;
            });

        await controller.leaveCloudAnchorSession();

        expect(methodCalled, true);
      });
    });

    group('Cloud Anchor Streams', () {
      test('cloudAnchorsStream can be listened to', () {
        // Test that the stream can be created and listened to
        final subscription = controller.cloudAnchorsStream.listen((anchors) {
          // Stream is working
        });

        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('cloudAnchorStatusStream can be listened to', () {
        // Test that the stream can be created and listened to
        final subscription = controller.cloudAnchorStatusStream.listen((
          status,
        ) {
          // Stream is working
        });

        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Occlusion Methods', () {
      test('setOcclusionEnabled sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setOcclusionEnabled') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setOcclusionEnabled(true);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['enabled'], true);
      });

      test('isOcclusionEnabled returns correct value', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isOcclusionEnabled') {
                return true;
              }
              return null;
            });

        final enabled = await controller.isOcclusionEnabled();
        expect(enabled, true);
      });

      test('setOcclusionConfig sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setOcclusionConfig') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setOcclusionConfig(
          type: OcclusionType.depth,
          confidence: 0.8,
          enablePersonOcclusion: true,
          enablePlaneOcclusion: false,
          enableDepthOcclusion: true,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['type'], 'depth');
        expect(capturedArgs!['confidence'], 0.8);
        expect(capturedArgs!['enablePersonOcclusion'], true);
        expect(capturedArgs!['enablePlaneOcclusion'], false);
        expect(capturedArgs!['enableDepthOcclusion'], true);
      });

      test('getOcclusions returns parsed occlusions', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getOcclusions') {
                return [
                  {
                    'id': 'occlusion_1',
                    'type': 'depth',
                    'isActive': true,
                    'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
                    'confidence': 0.8,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                    'metadata': {},
                  },
                ];
              }
              return null;
            });

        final occlusions = await controller.getOcclusions();
        expect(occlusions.length, 1);
        expect(occlusions.first.id, 'occlusion_1');
        expect(occlusions.first.type, OcclusionType.depth);
      });

      test('getOcclusion returns parsed occlusion', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getOcclusion') {
                return {
                  'id': 'occlusion_1',
                  'type': 'person',
                  'isActive': true,
                  'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
                  'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                  'scale': {'x': 2.0, 'y': 2.0, 'z': 2.0},
                  'confidence': 0.9,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  'metadata': {'test': 'value'},
                };
              }
              return null;
            });

        final occlusion = await controller.getOcclusion('occlusion_1');
        expect(occlusion, isNotNull);
        expect(occlusion!.id, 'occlusion_1');
        expect(occlusion.type, OcclusionType.person);
        expect(occlusion.position, const Vector3(1, 2, 3));
      });

      test('createOcclusion sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'createOcclusion') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'occlusion_123';
              }
              return null;
            });

        final occlusionId = await controller.createOcclusion(
          type: OcclusionType.plane,
          position: const Vector3(0, 0, -1),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          metadata: {'test': 'value'},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['type'], 'plane');
        expect(capturedArgs!['position'], isA<Map>());
        expect(capturedArgs!['rotation'], isA<Map>());
        expect(capturedArgs!['scale'], isA<Map>());
        expect(capturedArgs!['metadata'], {'test': 'value'});
        expect(occlusionId, 'occlusion_123');
      });

      test('updateOcclusion sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'updateOcclusion') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.updateOcclusion(
          occlusionId: 'occlusion_1',
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(2, 2, 2),
          metadata: {'updated': true},
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['occlusionId'], 'occlusion_1');
        expect(capturedArgs!['position'], isA<Map>());
        expect(capturedArgs!['rotation'], isA<Map>());
        expect(capturedArgs!['scale'], isA<Map>());
        expect(capturedArgs!['metadata'], {'updated': true});
      });

      test('removeOcclusion sends correct parameters', () async {
        Map? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removeOcclusion') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removeOcclusion('occlusion_1');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['occlusionId'], 'occlusion_1');
      });

      test('isOcclusionSupported returns correct value', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isOcclusionSupported') {
                return true;
              }
              return null;
            });

        final supported = await controller.isOcclusionSupported();
        expect(supported, true);
      });

      test('getOcclusionCapabilities returns capabilities', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getOcclusionCapabilities') {
                return {
                  'depthOcclusion': true,
                  'personOcclusion': true,
                  'planeOcclusion': false,
                  'maxOcclusions': 10,
                };
              }
              return null;
            });

        final capabilities = await controller.getOcclusionCapabilities();
        expect(capabilities['depthOcclusion'], true);
        expect(capabilities['personOcclusion'], true);
        expect(capabilities['planeOcclusion'], false);
        expect(capabilities['maxOcclusions'], 10);
      });
    });

    group('Occlusion Streams', () {
      test('occlusionsStream can be listened to', () {
        // Test that the stream can be created and listened to
        final subscription = controller.occlusionsStream.listen((occlusions) {
          // Stream is working
        });

        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('occlusionStatusStream can be listened to', () {
        // Test that the stream can be created and listened to
        final subscription = controller.occlusionStatusStream.listen((status) {
          // Stream is working
        });

        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Physics Methods', () {
      test('isPhysicsSupported sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isPhysicsSupported') {
                return true;
              }
              return null;
            });

        final result = await controller.isPhysicsSupported();
        expect(result, true);
      });

      test('initializePhysics sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'initializePhysics') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        const config = PhysicsWorldConfig(
          gravity: Vector3(0, -9.81, 0),
          timeStep: 1.0 / 60.0,
        );
        await controller.initializePhysics(config);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['gravity'], isNotNull);
        expect(capturedArgs!['timeStep'], 1.0 / 60.0);
      });

      test('startPhysics calls correct method', () async {
        String? calledMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'startPhysics') {
                calledMethod = methodCall.method;
              }
              return null;
            });

        await controller.startPhysics();
        expect(calledMethod, 'startPhysics');
      });

      test('stopPhysics calls correct method', () async {
        String? calledMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'stopPhysics') {
                calledMethod = methodCall.method;
              }
              return null;
            });

        await controller.stopPhysics();
        expect(calledMethod, 'stopPhysics');
      });

      test('pausePhysics calls correct method', () async {
        String? calledMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'pausePhysics') {
                calledMethod = methodCall.method;
              }
              return null;
            });

        await controller.pausePhysics();
        expect(calledMethod, 'pausePhysics');
      });

      test('resumePhysics calls correct method', () async {
        String? calledMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'resumePhysics') {
                calledMethod = methodCall.method;
              }
              return null;
            });

        await controller.resumePhysics();
        expect(calledMethod, 'resumePhysics');
      });

      test('createPhysicsBody sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'createPhysicsBody') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'body_id_123';
              }
              return null;
            });

        const material = PhysicsMaterial(
          density: 1.0,
          friction: 0.5,
          restitution: 0.0,
        );
        final bodyId = await controller.createPhysicsBody(
          nodeId: 'node1',
          type: PhysicsBodyType.dynamic,
          material: material,
          position: const Vector3(0, 0, 0),
          mass: 1.0,
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'node1');
        expect(capturedArgs!['type'], 'dynamic');
        expect(capturedArgs!['mass'], 1.0);
        expect(bodyId, 'body_id_123');
      });

      test('removePhysicsBody sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removePhysicsBody') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removePhysicsBody('body1');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyId'], 'body1');
      });

      test('applyForce sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'applyForce') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.applyForce(
          bodyId: 'body1',
          force: const Vector3(1, 0, 0),
          point: const Vector3(0, 1, 0),
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyId'], 'body1');
        expect(capturedArgs!['force'], isNotNull);
        expect(capturedArgs!['point'], isNotNull);
      });

      test('applyImpulse sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'applyImpulse') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.applyImpulse(
          bodyId: 'body1',
          impulse: const Vector3(1, 0, 0),
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyId'], 'body1');
        expect(capturedArgs!['impulse'], isNotNull);
      });

      test('setVelocity sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setVelocity') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setVelocity(
          bodyId: 'body1',
          velocity: const Vector3(1, 0, 0),
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyId'], 'body1');
        expect(capturedArgs!['velocity'], isNotNull);
      });

      test('setAngularVelocity sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'setAngularVelocity') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.setAngularVelocity(
          bodyId: 'body1',
          angularVelocity: const Vector3(0, 1, 0),
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyId'], 'body1');
        expect(capturedArgs!['angularVelocity'], isNotNull);
      });

      test('createPhysicsConstraint sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'createPhysicsConstraint') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'constraint_id_123';
              }
              return null;
            });

        final constraintId = await controller.createPhysicsConstraint(
          bodyAId: 'bodyA',
          bodyBId: 'bodyB',
          type: PhysicsConstraintType.hinge,
          anchorA: const Vector3(0, 0, 0),
          anchorB: const Vector3(1, 0, 0),
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['bodyAId'], 'bodyA');
        expect(capturedArgs!['bodyBId'], 'bodyB');
        expect(capturedArgs!['type'], 'hinge');
        expect(constraintId, 'constraint_id_123');
      });

      test('removePhysicsConstraint sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'removePhysicsConstraint') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.removePhysicsConstraint('constraint1');

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['constraintId'], 'constraint1');
      });

      test('getPhysicsBodies returns parsed bodies', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getPhysicsBodies') {
                return [
                  {
                    'id': 'body_1',
                    'nodeId': 'node_1',
                    'type': 'dynamic',
                    'material': {
                      'density': 1.0,
                      'friction': 0.5,
                      'restitution': 0.0,
                      'linearDamping': 0.0,
                      'angularDamping': 0.0,
                    },
                    'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'scale': {'x': 1.0, 'y': 1.0, 'z': 1.0},
                    'velocity': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'angularVelocity': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'isActive': true,
                    'mass': 1.0,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                    'metadata': {},
                  },
                ];
              }
              return null;
            });

        final bodies = await controller.getPhysicsBodies();
        expect(bodies.length, 1);
        expect(bodies.first.id, 'body_1');
        expect(bodies.first.type, PhysicsBodyType.dynamic);
      });

      test('getPhysicsConstraints returns parsed constraints', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getPhysicsConstraints') {
                return [
                  {
                    'id': 'constraint_1',
                    'bodyAId': 'bodyA',
                    'bodyBId': 'bodyB',
                    'type': 'hinge',
                    'anchorA': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'anchorB': {'x': 1.0, 'y': 0.0, 'z': 0.0},
                    'axisA': {'x': 0.0, 'y': 1.0, 'z': 0.0},
                    'axisB': {'x': 0.0, 'y': 1.0, 'z': 0.0},
                    'lowerLimit': -1.0,
                    'upperLimit': 1.0,
                    'isActive': true,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                    'metadata': {},
                  },
                ];
              }
              return null;
            });

        final constraints = await controller.getPhysicsConstraints();
        expect(constraints.length, 1);
        expect(constraints.first.id, 'constraint_1');
        expect(constraints.first.type, PhysicsConstraintType.hinge);
      });

      test('getPhysicsWorldConfig returns parsed config', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getPhysicsWorldConfig') {
                return {
                  'gravity': {'x': 0.0, 'y': -9.81, 'z': 0.0},
                  'timeStep': 1.0 / 60.0,
                  'maxSubSteps': 10,
                  'enableSleeping': true,
                  'enableContinuousCollision': true,
                  'contactBreakingThreshold': 0.0,
                  'contactERP': 0.2,
                  'contactCFM': 0.0,
                };
              }
              return null;
            });

        final config = await controller.getPhysicsWorldConfig();
        expect(config.gravity, const Vector3(0, -9.81, 0));
        expect(config.timeStep, 1.0 / 60.0);
        expect(config.maxSubSteps, 10);
      });

      test('updatePhysicsWorldConfig sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'updatePhysicsWorldConfig') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        const config = PhysicsWorldConfig(
          gravity: Vector3(0, -9.81, 0),
          timeStep: 1.0 / 60.0,
        );
        await controller.updatePhysicsWorldConfig(config);

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['gravity'], isNotNull);
        expect(capturedArgs!['timeStep'], 1.0 / 60.0);
      });
    });

    group('Physics Streams', () {
      test('physicsBodiesStream can be listened to', () {
        final subscription = controller.physicsBodiesStream.listen((bodies) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('physicsConstraintsStream can be listened to', () {
        final subscription = controller.physicsConstraintsStream.listen(
          (constraints) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('physicsStatusStream can be listened to', () {
        final subscription = controller.physicsStatusStream.listen((status) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Multi-User Methods', () {
      test('isMultiUserSupported sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'isMultiUserSupported') {
                return true;
              }
              return null;
            });

        final result = await controller.isMultiUserSupported();
        expect(result, true);
      });

      test('createMultiUserSession sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'createMultiUserSession') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'session123';
              }
              return null;
            });

        final sessionId = await controller.createMultiUserSession(
          name: 'Test Session',
          maxParticipants: 4,
          isPrivate: true,
          password: 'secret',
        );

        expect(sessionId, 'session123');
        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['name'], 'Test Session');
        expect(capturedArgs!['maxParticipants'], 4);
        expect(capturedArgs!['isPrivate'], true);
        expect(capturedArgs!['password'], 'secret');
      });

      test('joinMultiUserSession sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'joinMultiUserSession') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
              }
              return null;
            });

        await controller.joinMultiUserSession(
          sessionId: 'session123',
          displayName: 'Test User',
          password: 'secret',
        );

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['sessionId'], 'session123');
        expect(capturedArgs!['displayName'], 'Test User');
        expect(capturedArgs!['password'], 'secret');
      });

      test('leaveMultiUserSession calls correct method', () async {
        String? calledMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              calledMethod = methodCall.method;
              return null;
            });

        await controller.leaveMultiUserSession();
        expect(calledMethod, 'leaveMultiUserSession');
      });

      test('shareObject sends correct parameters', () async {
        Map<Object?, Object?>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'shareObject') {
                capturedArgs = methodCall.arguments as Map<Object?, Object?>?;
                return 'sharedObject123';
              }
              return null;
            });

        final objectId = await controller.shareObject(
          nodeId: 'node1',
          isLocked: true,
          isVisible: true,
        );

        expect(objectId, 'sharedObject123');
        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['nodeId'], 'node1');
        expect(capturedArgs!['isLocked'], true);
        expect(capturedArgs!['isVisible'], true);
      });

      test('getMultiUserParticipants returns parsed participants', () async {
        final now = DateTime.now();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'getMultiUserParticipants') {
                return [
                  {
                    'id': 'participant1',
                    'displayName': 'User 1',
                    'role': 'participant',
                    'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
                    'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
                    'isActive': true,
                    'isHost': false,
                    'joinedAt': now.millisecondsSinceEpoch,
                    'lastSeen': now.millisecondsSinceEpoch,
                    'metadata': {},
                  },
                ];
              }
              return null;
            });

        final participants = await controller.getMultiUserParticipants();
        expect(participants.length, 1);
        expect(participants[0].id, 'participant1');
        expect(participants[0].displayName, 'User 1');
      });
    });

    group('Multi-User Streams', () {
      test('multiUserSessionStream can be listened to', () {
        final subscription = controller.multiUserSessionStream.listen(
          (session) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('multiUserParticipantsStream can be listened to', () {
        final subscription = controller.multiUserParticipantsStream.listen(
          (participants) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('multiUserSharedObjectsStream can be listened to', () {
        final subscription = controller.multiUserSharedObjectsStream.listen(
          (objects) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('multiUserSessionStatusStream can be listened to', () {
        final subscription = controller.multiUserSessionStatusStream.listen(
          (status) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Lighting Methods', () {
      test('isLightingSupported sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'isLightingSupported');
              return true;
            });

        final result = await controller.isLightingSupported();
        expect(result, true);
      });

      test('getLightingCapabilities returns capabilities', () async {
        final capabilities = {
          'supportsShadows': true,
          'maxLights': 8,
          'supportsGlobalIllumination': true,
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'getLightingCapabilities');
              return capabilities;
            });

        final result = await controller.getLightingCapabilities();
        expect(result, capabilities);
      });

      test('addLight sends correct light data', () async {
        final now = DateTime.now();
        final light = ARLight(
          id: 'test_light',
          type: ARLightType.directional,
          position: const Vector3(0, 5, 0),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 1000.0,
          createdAt: now,
          lastModified: now,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'addLight');
              expect(call.arguments, light.toMap());
              return light.toMap();
            });

        final result = await controller.addLight(light);
        expect(result.id, light.id);
        expect(result.type, light.type);
      });

      test('removeLight sends correct lightId', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'removeLight');
              expect(call.arguments, {'lightId': 'test_light'});
              return null;
            });

        await controller.removeLight('test_light');
      });

      test('updateLight sends correct light data', () async {
        final now = DateTime.now();
        final light = ARLight(
          id: 'test_light',
          type: ARLightType.point,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          direction: const Vector3(0, -1, 0),
          intensity: 500.0,
          createdAt: now,
          lastModified: now,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'updateLight');
              expect(call.arguments, light.toMap());
              return light.toMap();
            });

        final result = await controller.updateLight(light);
        expect(result.id, light.id);
        expect(result.type, light.type);
      });

      test('getLights returns parsed lights', () async {
        final now = DateTime.now();
        final lightsData = [
          {
            'id': 'light_1',
            'type': 'directional',
            'position': {'x': 0, 'y': 5, 'z': 0},
            'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
            'direction': {'x': 0, 'y': -1, 'z': 0},
            'intensity': 1000.0,
            'intensityUnit': 'lux',
            'color': {'x': 1, 'y': 1, 'z': 1},
            'range': 10.0,
            'innerConeAngle': 0.0,
            'outerConeAngle': 45.0,
            'isEnabled': true,
            'castShadows': true,
            'shadowQuality': 'medium',
            'shadowFilterMode': 'soft',
            'shadowBias': 0.005,
            'shadowNormalBias': 0.0,
            'shadowNearPlane': 0.1,
            'shadowFarPlane': 100.0,
            'createdAt': now.millisecondsSinceEpoch,
            'lastModified': now.millisecondsSinceEpoch,
            'metadata': {},
          },
        ];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'getLights');
              return lightsData;
            });

        final result = await controller.getLights();
        expect(result.length, 1);
        expect(result.first.id, 'light_1');
        expect(result.first.type, ARLightType.directional);
      });

      test('getLight returns specific light', () async {
        final now = DateTime.now();
        final lightData = {
          'id': 'test_light',
          'type': 'spot',
          'position': {'x': 1, 'y': 2, 'z': 3},
          'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
          'direction': {'x': 0, 'y': -1, 'z': 0},
          'intensity': 750.0,
          'intensityUnit': 'lux',
          'color': {'x': 1, 'y': 1, 'z': 1},
          'range': 15.0,
          'innerConeAngle': 10.0,
          'outerConeAngle': 30.0,
          'isEnabled': true,
          'castShadows': true,
          'shadowQuality': 'high',
          'shadowFilterMode': 'pcf',
          'shadowBias': 0.01,
          'shadowNormalBias': 0.005,
          'shadowNearPlane': 0.5,
          'shadowFarPlane': 200.0,
          'createdAt': now.millisecondsSinceEpoch,
          'lastModified': now.millisecondsSinceEpoch,
          'metadata': {},
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'getLight');
              expect(call.arguments, {'lightId': 'test_light'});
              return lightData;
            });

        final result = await controller.getLight('test_light');
        expect(result, isNotNull);
        expect(result!.id, 'test_light');
        expect(result.type, ARLightType.spot);
      });

      test('setLightingConfig sends correct config', () async {
        const config = ARLightingConfig(
          enableGlobalIllumination: true,
          enableShadows: true,
          globalShadowQuality: ShadowQuality.high,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setLightingConfig');
              expect(call.arguments, config.toMap());
              return null;
            });

        await controller.setLightingConfig(config);
      });

      test('getLightingConfig returns parsed config', () async {
        const configData = {
          'enableGlobalIllumination': true,
          'enableShadows': true,
          'globalShadowQuality': 'high',
          'globalShadowFilterMode': 'pcf',
          'ambientIntensity': 0.5,
          'ambientColor': {'x': 0.8, 'y': 0.9, 'z': 1.0},
          'shadowDistance': 100.0,
          'maxShadowCasters': 8,
          'enableCascadedShadows': true,
          'shadowCascadeCount': 4,
          'shadowCascadeDistances': [10.0, 25.0, 50.0, 100.0],
          'enableContactShadows': true,
          'contactShadowDistance': 10.0,
          'enableScreenSpaceShadows': true,
          'enableRayTracedShadows': false,
          'metadata': {},
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'getLightingConfig');
              return configData;
            });

        final result = await controller.getLightingConfig();
        expect(result.enableGlobalIllumination, true);
        expect(result.enableShadows, true);
        expect(result.globalShadowQuality, ShadowQuality.high);
      });

      test('setShadowsEnabled sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setShadowsEnabled');
              expect(call.arguments, {'enabled': true});
              return null;
            });

        await controller.setShadowsEnabled(true);
      });

      test('setShadowQuality sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setShadowQuality');
              expect(call.arguments, {'quality': 'ultra'});
              return null;
            });

        await controller.setShadowQuality(ShadowQuality.ultra);
      });

      test('setAmbientLighting sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setAmbientLighting');
              expect(call.arguments, {
                'intensity': 0.7,
                'color': {'x': 0.9, 'y': 0.8, 'z': 0.7},
              });
              return null;
            });

        await controller.setAmbientLighting(
          intensity: 0.7,
          color: const Vector3(0.9, 0.8, 0.7),
        );
      });

      test('updateLightPosition sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'updateLightPosition');
              expect(call.arguments, {
                'lightId': 'test_light',
                'position': {'x': 2, 'y': 3, 'z': 4},
              });
              return null;
            });

        await controller.updateLightPosition(
          lightId: 'test_light',
          position: const Vector3(2, 3, 4),
        );
      });

      test('updateLightRotation sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'updateLightRotation');
              expect(call.arguments, {
                'lightId': 'test_light',
                'rotation': {'x': 0.1, 'y': 0.2, 'z': 0.3, 'w': 0.9},
              });
              return null;
            });

        await controller.updateLightRotation(
          lightId: 'test_light',
          rotation: const Quaternion(0.1, 0.2, 0.3, 0.9),
        );
      });

      test('updateLightIntensity sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'updateLightIntensity');
              expect(call.arguments, {
                'lightId': 'test_light',
                'intensity': 1500.0,
              });
              return null;
            });

        await controller.updateLightIntensity(
          lightId: 'test_light',
          intensity: 1500.0,
        );
      });

      test('updateLightColor sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'updateLightColor');
              expect(call.arguments, {
                'lightId': 'test_light',
                'color': {'x': 1.0, 'y': 0.5, 'z': 0.2},
              });
              return null;
            });

        await controller.updateLightColor(
          lightId: 'test_light',
          color: const Vector3(1.0, 0.5, 0.2),
        );
      });

      test('setLightEnabled sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setLightEnabled');
              expect(call.arguments, {
                'lightId': 'test_light',
                'enabled': false,
              });
              return null;
            });

        await controller.setLightEnabled(lightId: 'test_light', enabled: false);
      });

      test('setLightCastShadows sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'setLightCastShadows');
              expect(call.arguments, {
                'lightId': 'test_light',
                'castShadows': true,
              });
              return null;
            });

        await controller.setLightCastShadows(
          lightId: 'test_light',
          castShadows: true,
        );
      });

      test('clearLights calls correct method', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'clearLights');
              return null;
            });

        await controller.clearLights();
      });
    });

    group('Lighting Streams', () {
      test('lightsStream can be listened to', () {
        final subscription = controller.lightsStream.listen((lights) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('lightingConfigStream can be listened to', () {
        final subscription = controller.lightingConfigStream.listen(
          (config) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('lightingStatusStream can be listened to', () {
        final subscription = controller.lightingStatusStream.listen(
          (status) {},
        );
        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });

    group('Environmental Probes Methods', () {
      test('isEnvironmentalProbesSupported sends correct parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'isEnvironmentalProbesSupported') {
            return true;
          }
          return null;
        });

        final result = await controller.isEnvironmentalProbesSupported();
        expect(result, true);
      });

      test('getEnvironmentalProbesCapabilities returns capabilities', () async {
        final capabilities = {
          'maxProbes': 8,
          'supportedTypes': ['spherical', 'box', 'planar'],
          'maxTextureResolution': 2048,
        };
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getEnvironmentalProbesCapabilities') {
            return capabilities;
          }
          return null;
        });

        final result = await controller.getEnvironmentalProbesCapabilities();
        expect(result, capabilities);
      });

      test('addEnvironmentalProbe sends correct probe data', () async {
        final now = DateTime.now();
        final probe = AREnvironmentalProbe(
          id: 'test_probe',
          type: ARProbeType.spherical,
          position: const Vector3(1, 2, 3),
          rotation: const Quaternion(0, 0, 0, 1),
          scale: const Vector3(1, 1, 1),
          influenceRadius: 5.0,
          updateMode: ARProbeUpdateMode.automatic,
          quality: ARProbeQuality.medium,
          isActive: true,
          captureReflections: true,
          captureLighting: true,
          textureResolution: 512,
          isRealTime: true,
          updateFrequency: 1.0,
          confidence: 0.8,
          createdAt: now,
          lastModified: now,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'addEnvironmentalProbe') {
            return probe.toMap();
          }
          return null;
        });

        final result = await controller.addEnvironmentalProbe(probe);
        expect(result.id, 'test_probe');
      });

      test('removeEnvironmentalProbe sends correct probeId', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'removeEnvironmentalProbe') {
            return null;
          }
          return null;
        });

        await controller.removeEnvironmentalProbe('test_probe');
      });

      test('clearEnvironmentalProbes calls correct method', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'clearEnvironmentalProbes') {
            return null;
          }
          return null;
        });

        await controller.clearEnvironmentalProbes();
      });
    });

    group('Environmental Probes Streams', () {
      test('probesStream can be listened to', () {
        final subscription = controller.probesStream.listen((probes) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('probeConfigStream can be listened to', () {
        final subscription = controller.probeConfigStream.listen((config) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });

      test('probeStatusStream can be listened to', () {
        final subscription = controller.probeStatusStream.listen((status) {});
        expect(subscription, isNotNull);
        subscription.cancel();
      });
    });
  });
}
