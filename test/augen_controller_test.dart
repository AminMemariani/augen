import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

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
              capturedArgs = methodCall.arguments as Map?;
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
              capturedArgs = methodCall.arguments as Map?;
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
              capturedArgs = methodCall.arguments as Map?;
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
              capturedArgs = methodCall.arguments as Map?;
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
              capturedArgs = methodCall.arguments as Map?;
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
  });
}
