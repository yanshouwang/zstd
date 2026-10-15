import 'package:hooks/hooks.dart';

import 'native_toolchain_cmake/native_toolchain_cmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final name = input.packageName;
    final builder = CMakeBuilder(
      // url: 'https://github.com/facebook/zstd.git',
      url: 'git@github.com:facebook/zstd.git',
      refspec: 'v1.5.7',
      subDir: 'build/cmake/',
      variables: {
        'BUILD_SHARED_LIBS': 'ON',
        'ZSTD_BUILD_PROGRAMS': 'OFF',
        'ZSTD_BUILD_STATIC': 'OFF',
        'ZSTD_BUILD_SHARED': 'ON',
      },
      name: name,
      assetName: 'src/$name.ffi.dart',
    );
    await builder.run(input: input, output: output);
  });
}
