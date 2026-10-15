import 'package:change_case/change_case.dart';
import 'package:code_assets/code_assets.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';
import 'package:process/process.dart';

import 'build_mode.dart';
import 'linkmode.dart';
import 'logger.dart';
import 'tools.dart';
import '../utils/run_process.dart';

final class CMakeBuilder implements Builder {
  final String name;
  final String assetName;
  final String url;
  final String refspec;
  final String? subDir;
  final Map<String, String> variables;
  final BuildMode buildMode;

  CMakeBuilder({
    required this.name,
    required this.assetName,
    required this.url,
    required this.refspec,
    this.subDir,
    this.variables = const {},
    this.buildMode = .release,
  });

  @override
  Future<void> run({
    required BuildInput input,
    required BuildOutputBuilder output,
    Logger? logger,
    ProcessManager? processManager,
    FileSystem? fileSystem,
  }) async {
    logger ??= createDefaultLogger();
    processManager ??= const LocalProcessManager();
    fileSystem ??= const LocalFileSystem();
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
    await fileSystem.directory(srcDir).create(recursive: true);
    await fileSystem.directory(dstDir).create(recursive: true);
    await fileSystem.directory(outDir).create(recursive: true);

    // git init
    await runProcess(
      executable: git.uri,
      arguments: ['init'],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );
    // git remote
    final result = await runProcess(
      executable: git.uri,
      arguments: ['remote'],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );
    if (result.stdout.trim().isEmpty) {
      // git remote add origin <url>
      await runProcess(
        executable: git.uri,
        arguments: ['remote', 'add', 'origin', url],
        workingDirectory: srcDir,
        logger: logger,
        processManager: processManager,
        throwOnUnexpectedExitCode: true,
      );
    } else {
      // git remote set-url origin <url>
      await runProcess(
        executable: git.uri,
        arguments: ['remote', 'set-url', 'origin', url],
        workingDirectory: srcDir,
        logger: logger,
        processManager: processManager,
        throwOnUnexpectedExitCode: true,
      );
    }
    // git fetch origin <refspec>
    await runProcess(
      executable: git.uri,
      arguments: ['fetch', 'origin', refspec],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );
    // git reset --hard <commit>
    await runProcess(
      executable: git.uri,
      arguments: ['reset', '--hard', 'FETCH_HEAD'],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
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
        ...await _getTargetOsVariables(input.config.code),
        ...variables.entries.map((e) => '-D${e.key}=${e.value}'),
      ],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --build <dst> --config <type>
    final buildMode = this.buildMode.name.toCapitalCase();
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '--build',
        dstDir.toFilePath(),
        '--config',
        buildMode,
        ..._getTargetOsOptions(input.config.code),
      ],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
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
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );

    final linkMode = getLinkMode(input.config.code.linkModePreference);
    final libName = input.config.code.targetOS.libraryFileName(name, linkMode);
    final libAsset = CodeAsset(
      package: input.packageName,
      name: assetName,
      linkMode: linkMode,
      file: outDir.resolve('lib/$libName'),
    );
    output.assets.code.add(libAsset);
  }

  // https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling
  Future<List<String>> _getTargetOsVariables(
    CodeConfig config, {
    Logger? logger,
  }) async => switch (config.targetOS) {
    .macOS => [
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.macOS.targetVersion}',
    ],
    .iOS => [
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_ARCHITECTURES=${config.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${config.iOS.targetVersion}',
    ],
    .android => [
      '-DCMAKE_SYSTEM_NAME=Android',
      '-DCMAKE_SYSTEM_VERSION=${config.android.targetNdkApi}',
      '-DCMAKE_ANDROID_ARCH_ABI=${config.targetArchitecture.toAndroidAbi()}',
      '-DCMAKE_ANDROID_NDK=${await Tools.ndk.resolve(logger: logger).then((e) => e.uri.toFilePath())}',
    ],
    _ => [
      '-DCMAKE_SYSTEM_PROCESSOR=${config.targetArchitecture.toSystemProcessor()}',
    ],
  };

  List<String> _getTargetOsOptions(CodeConfig config) =>
      switch (config.targetOS) {
        .iOS => ['--', '-sdk', config.iOS.targetSdk.type],
        _ => [],
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
