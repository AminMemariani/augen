import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARMarkerDetectionOptions fps validation', () {
    test('maxDetectionFps = 0 triggers assertion error', () {
      expect(
        () => ARMarkerDetectionOptions(maxDetectionFps: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('maxDetectionFps = -1 triggers assertion error', () {
      expect(
        () => ARMarkerDetectionOptions(maxDetectionFps: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('maxDetectionFps = 1 succeeds', () {
      final opts = ARMarkerDetectionOptions(maxDetectionFps: 1);
      expect(opts.maxDetectionFps, 1);
    });

    test('maxDetectionFps = 30 succeeds', () {
      final opts = ARMarkerDetectionOptions(maxDetectionFps: 30);
      expect(opts.maxDetectionFps, 30);
    });

    test('fromMap clamps fps 0 to 1', () {
      final opts = ARMarkerDetectionOptions.fromMap({'maxDetectionFps': 0});
      expect(opts.maxDetectionFps, 1);
    });

    test('fromMap clamps fps -5 to 1', () {
      final opts = ARMarkerDetectionOptions.fromMap({'maxDetectionFps': -5});
      expect(opts.maxDetectionFps, 1);
    });

    test('fromMap preserves valid fps', () {
      final opts = ARMarkerDetectionOptions.fromMap({'maxDetectionFps': 20});
      expect(opts.maxDetectionFps, 20);
    });

    test('fromMap uses default 15 when key missing', () {
      final opts = ARMarkerDetectionOptions.fromMap({});
      expect(opts.maxDetectionFps, 15);
    });
  });
}
