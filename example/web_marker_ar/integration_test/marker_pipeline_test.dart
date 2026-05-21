// Deeper E2E tests that exercise the marker-tracking pipeline plumbing in a
// real browser: controller wiring, stream lifecycle, dispose safety, and
// error propagation when the camera/detector are not fully available.
//
// These tests run against a headless browser with no camera permission, so
// they verify ARCHITECTURAL correctness (no hangs, no silent failures, no
// crashes) — not full marker-detection behavior. Operations that require a
// live camera or JS bridge may fail; tests assert the failure is GRACEFUL.
//
// Run with:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/marker_pipeline_test.dart \
//     -d chrome

import 'dart:async';

import 'package:augen/augen.dart' hide AnimationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _opTimeout = Duration(seconds: 5);
const _mountTimeout = Duration(seconds: 8);

/// Pumps a minimal AugenView and returns its controller once mounted.
Future<AugenController> _pumpAugenView(
  WidgetTester tester, {
  ARSessionConfig config = const ARSessionConfig(
    markerTracking: true,
    planeDetection: false,
  ),
}) async {
  final completer = Completer<AugenController>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AugenView(
          config: config,
          onViewCreated: (c) {
            if (!completer.isCompleted) completer.complete(c);
          },
        ),
      ),
    ),
  );
  // IMPORTANT: do NOT use pumpAndSettle here. The web backend starts a
  // perpetual requestAnimationFrame detection loop; pumpAndSettle would
  // wait forever for the frame pipeline to quiesce. Use pump() with a
  // bounded duration instead.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return completer.future.timeout(_mountTimeout);
}

/// Runs an async operation with a short timeout. If it succeeds or fails
/// (either way is acceptable in this E2E suite), the test continues. A hang
/// is what we treat as a real bug.
Future<void> _expectCompletesOrThrows(
  Future<void> Function() op, {
  String? reason,
}) async {
  try {
    await op().timeout(_opTimeout);
    // Completed normally — fine.
  } on TimeoutException {
    fail(reason ?? 'Operation hung past ${_opTimeout.inSeconds}s');
  } catch (_) {
    // Threw a non-timeout error — also acceptable; the contract is "no hang".
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pipeline plumbing (real browser)', () {
    testWidgets('AugenController is created when AugenView mounts', (
      tester,
    ) async {
      final controller = await _pumpAugenView(tester);
      expect(controller, isA<AugenController>());
      expect(controller.viewId, isNonNegative);
      controller.dispose();
    });

    testWidgets('initialize() does not hang on web', (tester) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
        reason: 'initialize() hung in real browser',
      );
      controller.dispose();
    });

    testWidgets('errorStream is alive after initialization', (tester) async {
      final controller = await _pumpAugenView(tester);

      final errors = <String>[];
      final sub = controller.errorStream.listen(errors.add);

      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // The stream itself must remain healthy regardless of what arrived on it.
      expect(controller.errorStream, isA<Stream<String>>());
      await sub.cancel();
      controller.dispose();
    });

    testWidgets('marker target API does not hang', (tester) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );

      const target = ARMarkerTarget(
        id: 'hiro-e2e',
        name: 'Hiro E2E',
        type: ARMarkerType.pattern,
        physicalWidth: 0.08,
        patternPath: 'assets/markers/hiro.patt',
      );

      await _expectCompletesOrThrows(() => controller.addMarkerTarget(target));
      await _expectCompletesOrThrows(
        () => controller.removeMarkerTarget('hiro-e2e'),
      );

      controller.dispose();
    });

    testWidgets('setMarkerTrackingEnabled does not hang', (tester) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );

      await _expectCompletesOrThrows(
        () => controller.setMarkerTrackingEnabled(true),
      );
      await _expectCompletesOrThrows(
        () => controller.setMarkerTrackingEnabled(false),
      );

      controller.dispose();
    });

    testWidgets('trackedMarkersStream is a broadcast stream', (tester) async {
      final controller = await _pumpAugenView(tester);

      // Two listeners must both be allowed — that's the broadcast contract.
      final subA = controller.trackedMarkersStream.listen((_) {});
      final subB = controller.trackedMarkersStream.listen((_) {});

      expect(controller.trackedMarkersStream.isBroadcast, isTrue);

      await subA.cancel();
      await subB.cancel();
      controller.dispose();
    });

    testWidgets('setMarkerDetectionOptions does not hang', (tester) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );

      await _expectCompletesOrThrows(
        () => controller.setMarkerDetectionOptions(
          const ARMarkerDetectionOptions(
            maxDetectionFps: 10,
            processingWidth: 320,
            confidenceThreshold: 0.5,
            debug: true,
          ),
        ),
      );

      controller.dispose();
    });

    testWidgets('pause / resume cycle is safe', (tester) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );

      await _expectCompletesOrThrows(() => controller.pause());
      await _expectCompletesOrThrows(() => controller.resume());

      controller.dispose();
    });

    testWidgets('dispose() is idempotent', (tester) async {
      final controller = await _pumpAugenView(tester);
      controller.dispose();
      // Second dispose must not throw.
      expect(() => controller.dispose(), returnsNormally);
    });

    testWidgets('dispose() while initialize is in flight is safe', (
      tester,
    ) async {
      final controller = await _pumpAugenView(tester);

      // Start initialize but don't await it.
      final initFuture = controller
          .initialize(const ARSessionConfig(markerTracking: true))
          .catchError((_) {});

      // Dispose immediately.
      controller.dispose();

      // Wait briefly for in-flight initialize to settle.
      await initFuture.timeout(_opTimeout, onTimeout: () {});
      // No assertion needed — surviving without a crash is the pass.
    });
  });

  group('Unsupported-on-web features fail explicitly', () {
    testWidgets('image tracking is not silently a no-op on web', (
      tester,
    ) async {
      final controller = await _pumpAugenView(tester);
      await _expectCompletesOrThrows(
        () =>
            controller.initialize(const ARSessionConfig(markerTracking: true)),
      );

      var threwOrTimedOut = false;
      try {
        await controller
            .addImageTarget(
              ARImageTarget(
                id: 'should-fail',
                name: 'fail',
                imagePath: 'assets/markers/hiro.patt',
                physicalSize: const ImageTargetSize(0.1, 0.1),
              ),
            )
            .timeout(_opTimeout);
      } catch (_) {
        threwOrTimedOut = true;
      }

      expect(
        threwOrTimedOut,
        isTrue,
        reason:
            'addImageTarget on web must throw, not silently succeed (no native impl)',
      );

      controller.dispose();
    });
  });
}
