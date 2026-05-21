import 'augen_platform_backend.dart';
import 'augen_platform_mobile.dart';

/// Mobile factory — returns MethodChannel-backed backend.
AugenPlatformBackend createBackend(int viewId) =>
    AugenPlatformMobile(viewId);
