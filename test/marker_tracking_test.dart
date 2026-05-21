import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Marker Tracking Controller Methods (mobile platform)', () {
    late AugenController controller;
    late MethodChannel channel;
    final int viewId = 456;

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

    // On mobile, marker methods should throw UnsupportedError
    test('addMarkerTarget throws UnsupportedError on mobile', () async {
      const target = ARMarkerTarget(
        id: 'marker-1',
        name: 'Test',
        type: ARMarkerType.aruco,
        physicalWidth: 0.1,
        arucoId: 5,
        arucoDictionary: ARArucoDictionary.dict4x4_50,
      );
      expect(
        () => controller.addMarkerTarget(target),
        throwsUnsupportedError,
      );
    });

    test('removeMarkerTarget throws UnsupportedError on mobile', () {
      expect(
        () => controller.removeMarkerTarget('marker-1'),
        throwsUnsupportedError,
      );
    });

    test('getMarkerTargets throws UnsupportedError on mobile', () {
      expect(
        () => controller.getMarkerTargets(),
        throwsUnsupportedError,
      );
    });

    test('setMarkerTrackingEnabled throws UnsupportedError on mobile', () {
      expect(
        () => controller.setMarkerTrackingEnabled(true),
        throwsUnsupportedError,
      );
    });

    test('isMarkerTrackingEnabled throws UnsupportedError on mobile', () {
      expect(
        () => controller.isMarkerTrackingEnabled(),
        throwsUnsupportedError,
      );
    });

    test('getTrackedMarkers throws UnsupportedError on mobile', () {
      expect(
        () => controller.getTrackedMarkers(),
        throwsUnsupportedError,
      );
    });

    test('setMarkerDetectionOptions throws UnsupportedError on mobile', () {
      const opts = ARMarkerDetectionOptions(maxDetectionFps: 30, debug: true);
      expect(
        () => controller.setMarkerDetectionOptions(opts),
        throwsUnsupportedError,
      );
    });

    test('addNodeToTrackedMarker throws UnsupportedError on mobile', () {
      final node = ARNode(
        id: 'node-1',
        type: NodeType.model,
        modelPath: 'https://example.com/cube.glb',
        position: const Vector3(0, 0, 0),
      );
      expect(
        () => controller.addNodeToTrackedMarker(
          trackedMarkerId: 'marker-1',
          nodeId: 'node-1',
          node: node,
        ),
        throwsUnsupportedError,
      );
    });

    test('removeNodeFromTrackedMarker throws UnsupportedError on mobile', () {
      expect(
        () => controller.removeNodeFromTrackedMarker('node-1'),
        throwsUnsupportedError,
      );
    });

    // Streams and disposal should work on all platforms
    test('trackedMarkersStream is accessible', () {
      expect(
        controller.trackedMarkersStream,
        isA<Stream<List<ARTrackedMarker>>>(),
      );
    });

    test('markerTargetsStream is accessible', () {
      expect(
        controller.markerTargetsStream,
        isA<Stream<List<ARMarkerTarget>>>(),
      );
    });

    test('dispose closes streams without error', () {
      expect(() => controller.dispose(), returnsNormally);
    });
  });
}
