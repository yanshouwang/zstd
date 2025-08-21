import 'package:zstd_api/zstd_api.dart';

import 'zstd_impl.dart';

abstract final class ZstdNativePlugin {
  static void registerWith() {
    ZstdApi.instance = ZstdImpl();
  }
}
