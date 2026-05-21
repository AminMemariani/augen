import 'augen_platform_backend.dart';
import 'augen_platform_web.dart';

/// Web factory — returns JS interop-backed backend.
AugenPlatformBackend createBackend(int viewId) => AugenPlatformWeb(viewId);
