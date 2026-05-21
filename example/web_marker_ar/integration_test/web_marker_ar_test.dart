// E2E integration tests for the Augen Web Marker AR example.
//
// Run with:
//   flutter test integration_test -d chrome
// or:
//   flutter test integration_test --platform chrome
//
// Notes:
//   - In a headless / permission-less browser, the camera will fail. The
//     tests intentionally tolerate that — they verify that the UI still
//     boots and remains intact when the camera/detector cannot start.

import 'package:augen/augen.dart' hide AnimationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_marker_ar_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Web Marker AR E2E', () {
    testWidgets('App boots and shows the AR Scaffold', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Debug overlay shows camera status', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The debug overlay row label is "📷 Camera". Whether the camera is
      // available or not, the label is rendered as long as the overlay is on.
      expect(find.textContaining('Camera'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Detector'), findsAtLeastNWidgets(1));
      expect(find.text('Augen Web Marker AR'), findsOneWidget);
    });

    testWidgets('AugenView platform view is in the tree', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(AugenView), findsOneWidget);
    });

    testWidgets(
      'Camera/permission errors do not crash the widget tree',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Even when initialization fails (headless browser, no permission),
        // the app should remain mounted and responsive.
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets('Debug FAB toggles the overlay', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The "Augen Web Marker AR" header is only present when overlay is on.
      expect(find.text('Augen Web Marker AR'), findsOneWidget);

      final debugFab = find.byTooltip('Toggle debug overlay');
      expect(debugFab, findsOneWidget);

      await tester.tap(debugFab);
      await tester.pumpAndSettle();

      // After toggling, the overlay header should be gone.
      expect(find.text('Augen Web Marker AR'), findsNothing);

      // Toggle back on.
      await tester.tap(debugFab);
      await tester.pumpAndSettle();
      expect(find.text('Augen Web Marker AR'), findsOneWidget);
    });

    testWidgets(
      'Tracking FAB tap is safe (when initialized)',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // The tracking FAB only appears once initialization succeeded.
        // It may not be present in a headless browser; in that case, this
        // test simply verifies the app still renders correctly.
        final pauseFab = find.byTooltip('Pause tracking');
        final resumeFab = find.byTooltip('Resume tracking');

        if (pauseFab.evaluate().isNotEmpty) {
          await tester.tap(pauseFab);
          await tester.pumpAndSettle();
        } else if (resumeFab.evaluate().isNotEmpty) {
          await tester.tap(resumeFab);
          await tester.pumpAndSettle();
        }

        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });

  group('Augen public API smoke test', () {
    test('ARMarkerTarget can be constructed', () {
      const target = ARMarkerTarget(
        id: 'test',
        name: 'Test',
        type: ARMarkerType.pattern,
        physicalWidth: 0.1,
        patternPath: 'assets/markers/hiro.patt',
      );
      expect(target.id, 'test');
      expect(target.type, ARMarkerType.pattern);
      expect(target.physicalWidth, 0.1);
    });

    test('ARMarkerDetectionOptions defaults are sane', () {
      const opts = ARMarkerDetectionOptions();
      expect(opts.maxDetectionFps, 15);
      expect(opts.processingWidth, 640);
      expect(opts.confidenceThreshold, 0.6);
    });

    test('ARSessionConfig with markerTracking serializes', () {
      const config = ARSessionConfig(markerTracking: true);
      final map = config.toMap();
      expect(map['markerTracking'], true);
    });
  });
}
