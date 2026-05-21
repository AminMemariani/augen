// Skipped: WasmMarkerDetector lives under lib/src/web/ and depends on
// `dart:js_interop`, `package:web`, and `dart:ui_web`. Those libraries are not
// importable from the Dart VM test runner (`flutter test`), so a pure-Dart
// unit test cannot exercise dispose-after-add or error-stream propagation.
//
// This coverage is intentionally deferred to:
//   * an integration test running with `flutter test --platform chrome`, or
//   * a dedicated `test/wasm_detector_lifecycle_test.web.dart` that gets
//     wired up once the web test harness is in place.
//
// The placeholder test below exists so the file is picked up by the runner
// and the rationale is discoverable from `flutter test` output.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'WasmMarkerDetector lifecycle is covered on the web target only',
    () {
      // Intentionally a no-op. See file header for details.
      expect(true, isTrue);
    },
    skip: 'Web-only: requires dart:js_interop / dart:ui_web; '
        'run via flutter test --platform chrome with a web harness.',
  );
}
