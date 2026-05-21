// Test driver entry point for `flutter drive` + `package:integration_test`.
//
// Usage:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/web_marker_ar_test.dart \
//     -d chrome
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
