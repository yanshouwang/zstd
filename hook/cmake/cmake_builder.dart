import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';
import 'package:path/path.dart' as path;

import 'build_mode.dart';
import 'link_mode.dart';
import 'logger.dart';
import 'tools.dart';
import 'utils/run_process.dart';

final class CMakeBuilder implements Builder {
  final String name;
  final String assetName;
  final String url;
  final String refspec;
  final String? subDir;
  final Map<String, String?> defines;
  final BuildMode buildMode;

  CMakeBuilder({
    required this.name,
    required this.assetName,
    required this.url,
    required this.refspec,
    this.subDir,
    this.defines = const {},
    this.buildMode = .release,
  });

  @override
  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
    Logger? logger,
  }) async {
    logger ??= createDefaultLogger();
    if (!input.config.buildCodeAssets) {
      logger.info(
        'config.buildAssetTypes did not contain CodeAssets, '
        'skipping CodeAsset $assetName build.',
      );
      return;
    }

    final git = await Tools.git.resolve(logger: logger);
    final cmake = await Tools.cmake.resolve(logger: logger);

    final srcDir = input.outputDirectoryShared.resolve('src/');
    final dstDir = input.outputDirectory.resolve('dst/');
    final outDir = input.outputDirectory.resolve('out/');
    await Directory.fromUri(srcDir).create(recursive: true);
    await Directory.fromUri(dstDir).create(recursive: true);
    await Directory.fromUri(outDir).create(recursive: true);

    // git init
    await runProcess(
      executable: git.uri,
      arguments: ['init'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // git remote add origin <url>
    await runProcess(
      executable: git.uri,
      arguments: ['remote', 'add', 'origin', url],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: false,
    );
    // git fetch origin <refspec>
    await runProcess(
      executable: git.uri,
      arguments: ['fetch', 'origin', refspec],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // git reset --hard <commit>
    await runProcess(
      executable: git.uri,
      arguments: ['reset', '--hard', 'FETCH_HEAD'],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake -S <src> -B <dst>
    final subDir = this.subDir;
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '-S',
        subDir == null
            ? srcDir.toFilePath()
            : srcDir.resolve(subDir).toFilePath(),
        '-B',
        dstDir.toFilePath(),
        // '-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON',
        // '-DCMAKE_BUILD_TYPE=Release',
        ..._getTargetDefines(input.config.code),
        ...defines.entries.map(
          (e) => e.value == null ? '-D${e.key}' : '-D${e.key}=${e.value}',
        ),
      ],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --build <dst> --config <type>
    final buildMode = this.buildMode.name.toCapitalCase();
    await runProcess(
      executable: cmake.uri,
      arguments: ['--build', dstDir.toFilePath(), '--config', buildMode],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --install <dst> --config <type> --prefix <out>
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '--install',
        dstDir.toFilePath(),
        '--config',
        buildMode,
        '--prefix',
        outDir.toFilePath(),
      ],
      workingDirectory: srcDir,
      logger: logger,
      throwOnUnexpectedExitCode: true,
    );

    // final linkMode = getLinkMode(input.config.code.linkModePreference);
    // final libDir = outDir.resolve('lib/');
    // final libName = input.config.code.targetOS.libraryFileName(name, linkMode);
    // final libExt = path.extension(libName);
    // final libAsset = CodeAsset(
    //   package: input.packageName,
    //   name: assetName,
    //   linkMode: linkMode,
    //   file: libDir.resolve(libName),
    // );
    // output.assets.code.add(libAsset);

    // final entities = await Directory.fromUri(libDir).list().toList();
    // final files = entities.whereType<File>().toList();
    // for (final file in files) {
    //   final filePath = file.path;
    //   final fileName = path.basename(filePath);
    //   final fileNameWithoutExt = path.basenameWithoutExtension(filePath);
    //   final fileExt = path.extension(filePath);
    //   if (fileName == libName || fileExt != libExt) continue;
    //   final fileAsset = CodeAsset(
    //     package: input.packageName,
    //     name: 'src/ffi/$fileNameWithoutExt.g.dart',
    //     linkMode: linkMode,
    //     file: file.uri,
    //   );
    //   output.assets.code.add(fileAsset);
    // }
  }

  List<String> _getTargetDefines(
    CodeConfig config,
  ) => switch (config.targetOS) {
    .macOS => [
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.macOS.targetVersion}',
    ],
    .iOS => [
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_SYSROOT=${config.iOS.targetSdk.type}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.iOS.targetVersion}',
    ],
    .android => [
      '-DCMAKE_SYSTEM_NAME=Android',
      '-DANDROID_ABI=${config.targetArchitecture.toAndroidAbi()}',
    ],
    _ => [
      '-DCMAKE_SYSTEM_PROCESSOR=${config.targetArchitecture.toSystemProcessor()}',
    ],
  };
}

extension on Architecture {
  String toOsxArchitecture() => switch (this) {
    .arm64 => 'arm64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };

  String toAndroidAbi() => switch (this) {
    .arm => 'armeabi-v7a',
    .arm64 => 'arm64-v8a',
    .ia32 => 'x86',
    .x64 => 'x86_64',
    .riscv64 => 'riscv64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };

  String toSystemProcessor() => switch (this) {
    .arm => 'arm',
    .arm64 => 'arm64',
    .ia32 => 'x86',
    .riscv32 => 'riscv32',
    .riscv64 => 'riscv64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported architecture: $this'),
  };
}
