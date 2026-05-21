import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('ARMarkerDetectionOptions', () {
    test('default values', () {
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

    test('custom values', () {
      const opts = ARMarkerDetectionOptions(
        maxDetectionFps: 30,
        processingWidth: 1280,
        processingHeight: 720,
        confidenceThreshold: 0.8,
        debug: true,
        smoothingEnabled: false,
        positionSmoothing: 0.3,
        rotationSmoothing: 0.4,
        lostTimeout: Duration(seconds: 2),
        hideContentWhenLost: false,
      );
      expect(opts.maxDetectionFps, 30);
      expect(opts.processingWidth, 1280);
      expect(opts.processingHeight, 720);
      expect(opts.confidenceThreshold, 0.8);
      expect(opts.debug, true);
      expect(opts.smoothingEnabled, false);
      expect(opts.positionSmoothing, 0.3);
      expect(opts.rotationSmoothing, 0.4);
      expect(opts.lostTimeout, const Duration(seconds: 2));
      expect(opts.hideContentWhenLost, false);
    });

    test('toMap produces correct map', () {
      const opts = ARMarkerDetectionOptions();
      final map = opts.toMap();
      expect(map['maxDetectionFps'], 15);
      expect(map['processingWidth'], 640);
      expect(map.containsKey('processingHeight'), false);
      expect(map['confidenceThreshold'], 0.6);
      expect(map['debug'], false);
      expect(map['smoothingEnabled'], true);
      expect(map['positionSmoothing'], 0.6);
      expect(map['rotationSmoothing'], 0.6);
      expect(map['lostTimeoutMs'], 500);
      expect(map['hideContentWhenLost'], true);
    });

    test('toMap includes processingHeight when set', () {
      const opts = ARMarkerDetectionOptions(processingHeight: 480);
      expect(opts.toMap()['processingHeight'], 480);
    });

    test('fromMap parses correctly', () {
      final map = {
        'maxDetectionFps': 20,
        'processingWidth': 800,
        'processingHeight': 600,
        'confidenceThreshold': 0.75,
        'debug': true,
        'smoothingEnabled': false,
        'positionSmoothing': 0.5,
        'rotationSmoothing': 0.4,
        'lostTimeoutMs': 1000,
        'hideContentWhenLost': false,
      };
      final opts = ARMarkerDetectionOptions.fromMap(map);
      expect(opts.maxDetectionFps, 20);
      expect(opts.processingWidth, 800);
      expect(opts.processingHeight, 600);
      expect(opts.confidenceThreshold, 0.75);
      expect(opts.debug, true);
      expect(opts.smoothingEnabled, false);
      expect(opts.positionSmoothing, 0.5);
      expect(opts.rotationSmoothing, 0.4);
      expect(opts.lostTimeout, const Duration(seconds: 1));
      expect(opts.hideContentWhenLost, false);
    });

    test('fromMap with empty map uses defaults', () {
      final opts = ARMarkerDetectionOptions.fromMap({});
      expect(opts, const ARMarkerDetectionOptions());
    });

    test('toMap/fromMap round-trip', () {
      const original = ARMarkerDetectionOptions(
        maxDetectionFps: 25,
        processingWidth: 320,
        confidenceThreshold: 0.9,
        debug: true,
        smoothingEnabled: false,
        positionSmoothing: 0.2,
        rotationSmoothing: 0.3,
        lostTimeout: Duration(milliseconds: 750),
        hideContentWhenLost: false,
      );
      final restored = ARMarkerDetectionOptions.fromMap(original.toMap());
      expect(restored, original);
    });

    test('copyWith', () {
      const original = ARMarkerDetectionOptions();
      final modified = original.copyWith(
        maxDetectionFps: 30,
        debug: true,
      );
      expect(modified.maxDetectionFps, 30);
      expect(modified.debug, true);
      expect(modified.processingWidth, 640); // unchanged
      expect(modified.confidenceThreshold, 0.6); // unchanged
    });

    test('copyWith no changes returns equal', () {
      const original = ARMarkerDetectionOptions();
      final copied = original.copyWith();
      expect(copied, original);
    });

    test('equality', () {
      const a = ARMarkerDetectionOptions();
      const b = ARMarkerDetectionOptions();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inequality', () {
      const a = ARMarkerDetectionOptions();
      const b = ARMarkerDetectionOptions(maxDetectionFps: 30);
      expect(a, isNot(b));
    });
  });
}
