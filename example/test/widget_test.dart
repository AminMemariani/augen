// Smoke test for the Augen AR demo app.
//
// Verifies the app boots and renders its home scaffold. The AR view itself is
// a platform view that cannot be instantiated in a widget test, so we force a
// non-AR target platform — AugenView then renders its plain fallback and the
// rest of the UI (app bar, tabs, status overlay) builds normally.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:augen_example/main.dart';

void main() {
  testWidgets('App renders the AR demo home page', (WidgetTester tester) async {
    // Reset inside the body (not addTearDown) so the framework's end-of-test
    // invariant check sees the debug variable restored.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    try {
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      // App bar title renders.
      expect(find.text('Augen AR Demo - Complete Features'), findsOneWidget);

      // The first feature tab is present.
      expect(find.text('AR View'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
