import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zstd_compress_filter_api.dart';
import 'zstd_decompress_filter_api.dart';

abstract base class ZstdApi extends PlatformInterface {
  static final Object _token = Object();

  static ZstdApi? _instance;

  /// The default instance of [ZstdApi] to use.
  static ZstdApi get instance {
    final instance = _instance;
    if (instance == null) {
      throw UnimplementedError('ZstdApi is not implemented');
    }
    return instance;
  }

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZstdApi] when
  /// they register themselves.
  static set instance(ZstdApi instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Constructs a ZstdApi.
  ZstdApi.impl() : super(token: _token);

  ZstdCompressFilterApi newZstdCompressFilter();
  ZstdDecompressFilterApi newZstdDecompressFilter();
}
