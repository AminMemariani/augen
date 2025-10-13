import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'augen_method_channel.dart';

abstract class AugenPlatform extends PlatformInterface {
  /// Constructs a AugenPlatform.
  AugenPlatform() : super(token: _token);

  static final Object _token = Object();

  static AugenPlatform _instance = MethodChannelAugen();

  /// The default instance of [AugenPlatform] to use.
  ///
  /// Defaults to [MethodChannelAugen].
  static AugenPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AugenPlatform] when
  /// they register themselves.
  static set instance(AugenPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
