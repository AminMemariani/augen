import 'augen_platform_backend.dart';
import 'augen_platform_factory_stub.dart'
    if (dart.library.io) 'augen_platform_factory_mobile.dart'
    if (dart.library.js_interop) 'augen_platform_factory_web.dart';

/// Creates the appropriate platform backend for the current platform.
AugenPlatformBackend createPlatformBackend(int viewId) =>
    createBackend(viewId);
