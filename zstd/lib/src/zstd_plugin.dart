import 'package:zstd_api/zstd_api.dart';

import 'zstd_impl.dart';

abstract final class ZstdPlugin {
  static void registerWith() {
    ZstdApi.instance = ZstdImpl();
  }
}
