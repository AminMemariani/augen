import 'dart:async';

import 'package:augen/augen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ARTrackedMarker _makeMarker(String id) {
  return ARTrackedMarker(
    id: id,
    targetId: 'target-$id',
    type: ARMarkerType.aruco,
    position: const Vector3(0.1, 0.2, 0.3),
    rotation: const Quaternion(0, 0, 0, 1),
    transform: List<double>.filled(16, 0)..[0] = 1,
    corners: const [
      Vector2(0, 0),
      Vector2(1, 0),
      Vector2(1, 1),
      Vector2(0, 1),
    ],
    confidence: 0.95,
    trackingState: ARMarkerTrackingState.tracked,
    lastUpdated: DateTime.fromMillisecondsSinceEpoch(1234567890),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W14 onTrackedMarkersUpdated dispatch', () {
    late AugenController controller;
    late MethodChannel channel;
    const int viewId = 9001;

    setUp(() {
      controller = AugenController(viewId);
      channel = const MethodChannel('augen_9001');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('fast path: typed List<ARTrackedMarker> is forwarded unchanged',
        () async {
      final completer = Completer<List<ARTrackedMarker>>();
      controller.trackedMarkersStream.listen((markers) {
        if (!completer.isCompleted) completer.complete(markers);
      });

      final typed = <ARTrackedMarker>[_makeMarker('a'), _makeMarker('b')];
      controller.debugHandlePlatformCallback(
        'onTrackedMarkersUpdated',
        typed,
      );

      final received = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      expect(received.length, 2);
      // Fast-path: identity preserved (no fromMap copy).
      expect(identical(received[0], typed[0]), isTrue);
      expect(identical(received[1], typed[1]), isTrue);
      expect(received[0].id, 'a');
      expect(received[1].id, 'b');
    });

    test('slow path: List<Map> is converted via ARTrackedMarker.fromMap',
        () async {
      final completer = Completer<List<ARTrackedMarker>>();
      controller.trackedMarkersStream.listen((markers) {
        if (!completer.isCompleted) completer.complete(markers);
      });

      final raw = <Map<String, dynamic>>[
        _makeMarker('m1').toMap(),
        _makeMarker('m2').toMap(),
      ];
      controller.debugHandlePlatformCallback('onTrackedMarkersUpdated', raw);

      final received = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      expect(received.length, 2);
      expect(received[0], isA<ARTrackedMarker>());
      expect(received[0].id, 'm1');
      expect(received[1].id, 'm2');
      expect(received[0].trackingState, ARMarkerTrackingState.tracked);
    });

    test('slow path via MethodChannel codec also emits markers', () async {
      final completer = Completer<List<ARTrackedMarker>>();
      controller.trackedMarkersStream.listen((markers) {
        if (!completer.isCompleted) completer.complete(markers);
      });

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'augen_$viewId',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onTrackedMarkersUpdated', [_makeMarker('mc').toMap()]),
        ),
        (_) {},
      );

      final received = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      expect(received.length, 1);
      expect(received[0].id, 'mc');
    });
  });
}
