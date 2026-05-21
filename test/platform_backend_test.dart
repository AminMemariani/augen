import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform Backend (mobile method channel routing)', () {
    late AugenController controller;
    late MethodChannel channel;
    final int viewId = 789;
    final List<MethodCall> capturedCalls = [];

    setUp(() {
      capturedCalls.clear();
      controller = AugenController(viewId);
      channel = MethodChannel('augen_$viewId');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add(call);
        // Return sensible defaults per method
        switch (call.method) {
          case 'isARSupported':
            return true;
          case 'hitTest':
            return <Map<String, dynamic>>[];
          case 'addAnchor':
            return {
              'id': 'a1',
              'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
              'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };
          case 'createPhysicsBody':
            return 'body1';
          default:
            return null;
        }
      });
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // ===== Lifecycle methods =====

    test('initialize routes through backend with correct method name', () async {
      await controller.initialize(const ARSessionConfig());
      expect(capturedCalls.any((c) => c.method == 'initialize'), isTrue);
    });

    test('pause routes through backend', () async {
      await controller.pause();
      expect(capturedCalls.any((c) => c.method == 'pause'), isTrue);
    });

    test('resume routes through backend', () async {
      await controller.resume();
      expect(capturedCalls.any((c) => c.method == 'resume'), isTrue);
    });

    test('reset routes through backend', () async {
      await controller.reset();
      expect(capturedCalls.any((c) => c.method == 'reset'), isTrue);
    });

    // ===== Node methods =====

    test('addNode routes with method name "addNode"', () async {
      final node = ARNode(
        id: 'n1',
        type: NodeType.sphere,
        position: Vector3.zero(),
      );
      await controller.addNode(node);
      final call = capturedCalls.firstWhere((c) => c.method == 'addNode');
      expect(call.arguments['id'], 'n1');
    });

    test('removeNode routes with method name "removeNode"', () async {
      await controller.removeNode('n1');
      final call = capturedCalls.firstWhere((c) => c.method == 'removeNode');
      expect(call.arguments['nodeId'], 'n1');
    });

    test('updateNode routes with method name "updateNode"', () async {
      final node = ARNode(
        id: 'n1',
        type: NodeType.cube,
        position: Vector3(1, 2, 3),
      );
      await controller.updateNode(node);
      final call = capturedCalls.firstWhere((c) => c.method == 'updateNode');
      expect(call.arguments['id'], 'n1');
    });

    // ===== Hit test =====

    test('hitTest routes with method name "hitTest"', () async {
      await controller.hitTest(10.0, 20.0);
      final call = capturedCalls.firstWhere((c) => c.method == 'hitTest');
      expect(call.arguments['x'], 10.0);
      expect(call.arguments['y'], 20.0);
    });

    // ===== Anchor methods =====

    test('addAnchor routes with method name "addAnchor"', () async {
      await controller.addAnchor(Vector3(1, 2, 3));
      expect(capturedCalls.any((c) => c.method == 'addAnchor'), isTrue);
    });

    test('removeAnchor routes with method name "removeAnchor"', () async {
      await controller.removeAnchor('a1');
      final call = capturedCalls.firstWhere((c) => c.method == 'removeAnchor');
      expect(call.arguments['anchorId'], 'a1');
    });

    // ===== Physics uses createPhysicsBody (B1 fix) =====

    test('createPhysicsBody uses correct method name string', () async {
      await controller.createPhysicsBody(
        nodeId: 'n1',
        type: PhysicsBodyType.dynamic,
        material: const PhysicsMaterial(),
      );
      final call = capturedCalls.firstWhere(
        (c) => c.method == 'createPhysicsBody',
      );
      expect(call.arguments['nodeId'], 'n1');
    });

    // ===== Marker methods throw UnsupportedError on mobile =====

    test('addMarkerTarget throws UnsupportedError on mobile', () {
      const target = ARMarkerTarget(
        id: 'm1',
        name: 'Test',
        type: ARMarkerType.aruco,
        physicalWidth: 0.1,
        arucoId: 5,
        arucoDictionary: ARArucoDictionary.dict4x4_50,
      );
      expect(() => controller.addMarkerTarget(target), throwsUnsupportedError);
    });

    test('removeMarkerTarget throws UnsupportedError on mobile', () {
      expect(
        () => controller.removeMarkerTarget('m1'),
        throwsUnsupportedError,
      );
    });

    test('getTrackedMarkers throws UnsupportedError on mobile', () {
      expect(() => controller.getTrackedMarkers(), throwsUnsupportedError);
    });
  });
}
