import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARMarkerDetectionOptions defaults and copyWith', () {
    test('default values are correct', () {
      const opts = ARMarkerDetectionOptions();
      expect(opts.maxDetectionFps, 15);
      expect(opts.processingWidth, 640);
      expect(opts.processingHeight, isNull);
      expect(opts.confidenceThreshold, 0.6);
      expect(opts.debug, false);
      expect(opts.smoothingEnabled, true);
      expect(opts.positionSmoothing, 0.6);
      expect(opts.rotationSmoothing, 0.6);
      expect(opts.lostTimeout, const Duration(milliseconds: 500));
      expect(opts.hideContentWhenLost, true);
    });

    test('copyWith preserves values when no args', () {
      const original = ARMarkerDetectionOptions(
        maxDetectionFps: 30,
        processingWidth: 320,
        confidenceThreshold: 0.8,
        debug: true,
        smoothingEnabled: false,
      );
      final copy = original.copyWith();
      expect(copy, original);
    });

    test('copyWith overrides specific values', () {
      const original = ARMarkerDetectionOptions();
      final copy = original.copyWith(maxDetectionFps: 60, debug: true);
      expect(copy.maxDetectionFps, 60);
      expect(copy.debug, true);
      expect(copy.processingWidth, 640); // preserved
    });
  });

  group('ARSessionConfig with markerTracking', () {
    test('markerTracking: true serializes in toMap', () {
      const config = ARSessionConfig(markerTracking: true);
      final map = config.toMap();
      expect(map['markerTracking'], true);
    });

    test('markerTracking: false is default', () {
      const config = ARSessionConfig();
      expect(config.markerTracking, false);
      expect(config.toMap()['markerTracking'], false);
    });

    test('fromMap roundtrips markerTracking', () {
      const config = ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(
          maxDetectionFps: 20,
          debug: true,
        ),
      );
      final map = config.toMap();
      final restored = ARSessionConfig.fromMap(map);
      expect(restored.markerTracking, true);
      expect(restored.markerDetectionOptions, isNotNull);
      expect(restored.markerDetectionOptions!.maxDetectionFps, 20);
      expect(restored.markerDetectionOptions!.debug, true);
    });

    test('fromMap without markerTracking defaults to false', () {
      final config = ARSessionConfig.fromMap({});
      expect(config.markerTracking, false);
      expect(config.markerDetectionOptions, isNull);
    });
  });

  group('ARTrackedMarker isTracked / isReliable', () {
    ARTrackedMarker _makeMarker({
      required ARMarkerTrackingState state,
      required double confidence,
    }) {
      return ARTrackedMarker(
        id: 'tm1',
        targetId: 't1',
        type: ARMarkerType.aruco,
        position: const Vector3(0, 0, 0),
        rotation: const Quaternion(0, 0, 0, 1),
        transform: List.filled(16, 0.0),
        corners: [
          const Vector2(0, 0),
          const Vector2(1, 0),
          const Vector2(1, 1),
          const Vector2(0, 1),
        ],
        confidence: confidence,
        trackingState: state,
        lastUpdated: DateTime(2025, 1, 1),
      );
    }

    test('isTracked returns true for tracked state', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.tracked,
        confidence: 0.9,
      );
      expect(m.isTracked, true);
    });

    test('isTracked returns false for notTracked state', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.notTracked,
        confidence: 0.9,
      );
      expect(m.isTracked, false);
    });

    test('isTracked returns false for paused state', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.paused,
        confidence: 0.9,
      );
      expect(m.isTracked, false);
    });

    test('isTracked returns false for failed state', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.failed,
        confidence: 0.9,
      );
      expect(m.isTracked, false);
    });

    test('isReliable requires tracked AND confidence > 0.7', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.tracked,
        confidence: 0.9,
      );
      expect(m.isReliable, true);
    });

    test('isReliable false when not tracked even with high confidence', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.notTracked,
        confidence: 0.9,
      );
      expect(m.isReliable, false);
    });

    test('confidence exactly 0.7 is NOT reliable (> not >=)', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.tracked,
        confidence: 0.7,
      );
      expect(m.isReliable, false);
    });

    test('confidence 0.71 IS reliable', () {
      final m = _makeMarker(
        state: ARMarkerTrackingState.tracked,
        confidence: 0.71,
      );
      expect(m.isReliable, true);
    });
  });

  group('ARMarkerTarget toMap by type', () {
    test('pattern type includes patternPath in toMap', () {
      const target = ARMarkerTarget(
        id: 'p1',
        name: 'Pattern',
        type: ARMarkerType.pattern,
        physicalWidth: 0.1,
        patternPath: 'assets/markers/hiro.patt',
      );
      final map = target.toMap();
      expect(map['type'], 'pattern');
      expect(map['patternPath'], 'assets/markers/hiro.patt');
    });

    test('barcode type includes barcodeId in toMap', () {
      const target = ARMarkerTarget(
        id: 'b1',
        name: 'Barcode',
        type: ARMarkerType.barcode,
        physicalWidth: 0.1,
        barcodeId: 42,
      );
      final map = target.toMap();
      expect(map['type'], 'barcode');
      expect(map['barcodeId'], 42);
    });

    test('aruco type includes arucoId and arucoDictionary in toMap', () {
      const target = ARMarkerTarget(
        id: 'a1',
        name: 'ArUco',
        type: ARMarkerType.aruco,
        physicalWidth: 0.1,
        arucoId: 7,
        arucoDictionary: ARArucoDictionary.dict5x5_100,
      );
      final map = target.toMap();
      expect(map['type'], 'aruco');
      expect(map['arucoId'], 7);
      expect(map['arucoDictionary'], 'dict5x5_100');
    });

    test('toMap omits null optional fields', () {
      const target = ARMarkerTarget(
        id: 'x1',
        name: 'Minimal',
        type: ARMarkerType.pattern,
        physicalWidth: 0.05,
      );
      final map = target.toMap();
      expect(map.containsKey('patternPath'), false);
      expect(map.containsKey('barcodeId'), false);
      expect(map.containsKey('arucoId'), false);
      expect(map.containsKey('arucoDictionary'), false);
      expect(map.containsKey('physicalHeight'), false);
      expect(map.containsKey('metadata'), false);
    });
  });
}
