import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('ARSessionConfig', () {
    test('default values', () {
      const config = ARSessionConfig();
      expect(config.planeDetection, true);
      expect(config.lightEstimation, true);
      expect(config.depthData, false);
      expect(config.autoFocus, true);
      expect(config.markerTracking, false);
      expect(config.markerDetectionOptions, isNull);
    });

    test('markerTracking field defaults to false', () {
      const config = ARSessionConfig();
      expect(config.markerTracking, false);
    });

    test('markerDetectionOptions defaults to null', () {
      const config = ARSessionConfig();
      expect(config.markerDetectionOptions, isNull);
    });

    test('toMap includes marker fields', () {
      const config = ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(maxDetectionFps: 30),
      );
      final map = config.toMap();
      expect(map['markerTracking'], true);
      expect(map['markerDetectionOptions'], isNotNull);
      expect((map['markerDetectionOptions'] as Map)['maxDetectionFps'], 30);
    });

    test('toMap omits markerDetectionOptions when null', () {
      const config = ARSessionConfig(markerTracking: true);
      final map = config.toMap();
      expect(map['markerTracking'], true);
      expect(map.containsKey('markerDetectionOptions'), false);
    });

    test('fromMap includes marker fields', () {
      final config = ARSessionConfig.fromMap({
        'markerTracking': true,
        'markerDetectionOptions': {
          'maxDetectionFps': 25,
          'debug': true,
        },
      });
      expect(config.markerTracking, true);
      expect(config.markerDetectionOptions, isNotNull);
      expect(config.markerDetectionOptions!.maxDetectionFps, 25);
      expect(config.markerDetectionOptions!.debug, true);
    });

    test('fromMap without marker fields uses defaults', () {
      final config = ARSessionConfig.fromMap({});
      expect(config.markerTracking, false);
      expect(config.markerDetectionOptions, isNull);
    });

    test('toMap/fromMap round-trip with marker fields', () {
      const original = ARSessionConfig(
        planeDetection: false,
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(
          maxDetectionFps: 20,
          debug: true,
        ),
      );
      final restored = ARSessionConfig.fromMap(original.toMap());
      expect(restored, original);
    });

    test('copyWith with marker fields', () {
      const original = ARSessionConfig();
      final modified = original.copyWith(
        markerTracking: true,
        markerDetectionOptions: const ARMarkerDetectionOptions(debug: true),
      );
      expect(modified.markerTracking, true);
      expect(modified.markerDetectionOptions!.debug, true);
      expect(modified.planeDetection, true); // unchanged
    });

    test('copyWith no changes returns equal', () {
      const original = ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(),
      );
      final copied = original.copyWith();
      expect(copied, original);
    });

    test('backward compatibility - existing fields unchanged', () {
      const config = ARSessionConfig(
        planeDetection: false,
        lightEstimation: false,
        depthData: true,
        autoFocus: false,
      );
      final map = config.toMap();
      expect(map['planeDetection'], false);
      expect(map['lightEstimation'], false);
      expect(map['depthData'], true);
      expect(map['autoFocus'], false);

      final restored = ARSessionConfig.fromMap(map);
      expect(restored.planeDetection, false);
      expect(restored.lightEstimation, false);
      expect(restored.depthData, true);
      expect(restored.autoFocus, false);
    });

    test('equality with marker fields', () {
      const a = ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(),
      );
      const b = ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality on marker fields', () {
      const a = ARSessionConfig(markerTracking: true);
      const b = ARSessionConfig(markerTracking: false);
      expect(a, isNot(b));
    });
  });
}
