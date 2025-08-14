import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zstd_method_channel.dart';

abstract class ZstdPlatform extends PlatformInterface {
  /// Constructs a ZstdPlatform.
  ZstdPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZstdPlatform _instance = MethodChannelZstd();

  /// The default instance of [ZstdPlatform] to use.
  ///
  /// Defaults to [MethodChannelZstd].
  static ZstdPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZstdPlatform] when
  /// they register themselves.
  static set instance(ZstdPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
