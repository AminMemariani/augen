import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'augen_platform_interface.dart';

/// An implementation of [AugenPlatform] that uses method channels.
class MethodChannelAugen extends AugenPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('augen');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
