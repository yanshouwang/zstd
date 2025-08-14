import 'package:flutter_test/flutter_test.dart';
import 'package:zstd/zstd.dart';
import 'package:zstd/zstd_platform_interface.dart';
import 'package:zstd/zstd_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockZstdPlatform
    with MockPlatformInterfaceMixin
    implements ZstdPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ZstdPlatform initialPlatform = ZstdPlatform.instance;

  test('$MethodChannelZstd is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZstd>());
  });

  test('getPlatformVersion', () async {
    Zstd zstdPlugin = Zstd();
    MockZstdPlatform fakePlatform = MockZstdPlatform();
    ZstdPlatform.instance = fakePlatform;

    expect(await zstdPlugin.getPlatformVersion(), '42');
  });
}
