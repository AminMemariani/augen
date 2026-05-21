import 'augen_platform_backend.dart';

/// Stub factory for unsupported platforms.
AugenPlatformBackend createBackend(int viewId) {
  throw UnsupportedError('No AR platform backend for this platform.');
}
