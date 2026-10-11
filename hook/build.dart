import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';

import 'cmake/cmake_builder.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final name = input.packageName;
    final builder = CMakeBuilder(
      // url: 'https://github.com/facebook/zstd.git',
      url: 'git@github.com:facebook/zstd.git',
      refspec: 'v1.5.7',
      subDir: 'build/cmake/',
      defines: {
        'ZSTD_BUILD_PROGRAMS': 'OFF',
        'ZSTD_BUILD_STATIC': 'OFF',
        'ZSTD_BUILD_SHARED': 'ON',
      },
      name: name,
      assetName: '${name}_bindings_generated.dart',
    );
    await builder.run(input: input, output: output);
  });
}
