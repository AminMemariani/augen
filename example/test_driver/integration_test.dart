import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver so integration tests can run in profile mode on iOS
/// devices, where debug builds require an attached debugger:
///   flutter drive --profile --driver=test_driver/integration_test.dart \
///     --target=integration_test/ios_features_e2e_test.dart -d DEVICE_ID
Future<void> main() => integrationDriver();
