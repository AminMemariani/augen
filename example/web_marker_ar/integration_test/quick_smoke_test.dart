// Smallest possible smoke test for the pipeline — just verifies that the
// AugenView mounts, the controller is created, and dispose works. This is
// what we run in CI to verify the integration_test pipeline is alive.

import 'dart:async';

import 'package:augen/augen.dart' hide AnimationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AugenView mounts and creates a controller', (tester) async {
    final completer = Completer<AugenController>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AugenView(
            config: const ARSessionConfig(
              markerTracking: true,
              planeDetection: false,
            ),
            onViewCreated: (c) {
              if (!completer.isCompleted) completer.complete(c);
            },
          ),
        ),
      ),
    );

    // Bounded pumps only — never pumpAndSettle (RAF loop is perpetual).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final controller = await completer.future.timeout(
      const Duration(seconds: 5),
    );
    expect(controller, isA<AugenController>());
    expect(controller.viewId, isNonNegative);
    controller.dispose();
  });

  testWidgets('Dispose is idempotent', (tester) async {
    final completer = Completer<AugenController>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AugenView(
            onViewCreated: (c) {
              if (!completer.isCompleted) completer.complete(c);
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final controller = await completer.future.timeout(
      const Duration(seconds: 5),
    );
    controller.dispose();
    expect(() => controller.dispose(), returnsNormally);
  });

  testWidgets('Two AugenViews can mount sequentially', (tester) async {
    // Mount and dispose first.
    var c1 = Completer<AugenController>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AugenView(
            onViewCreated: (c) {
              if (!c1.isCompleted) c1.complete(c);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final controller1 = await c1.future.timeout(const Duration(seconds: 5));
    controller1.dispose();

    // Mount again.
    var c2 = Completer<AugenController>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AugenView(
            onViewCreated: (c) {
              if (!c2.isCompleted) c2.complete(c);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final controller2 = await c2.future.timeout(const Duration(seconds: 5));
    expect(controller2.viewId, isNot(controller1.viewId));
    controller2.dispose();
  });
}
