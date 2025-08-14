
import 'zstd_platform_interface.dart';

class Zstd {
  Future<String?> getPlatformVersion() {
    return ZstdPlatform.instance.getPlatformVersion();
  }
}
