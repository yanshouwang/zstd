import 'package:change_case/change_case.dart';
import 'package:code_assets/code_assets.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/src/logger.dart';
import 'package:process/process.dart';

import 'build_mode.dart';
import 'compiler_resolver.dart';
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
    final buildMode = this.buildMode.name.toCapitalCase();
    await runProcess(
      executable: cmake.uri,
      arguments: [
        '-S',
        subDir == null
            ? srcDir.toFilePath()
            : srcDir.resolve(subDir).toFilePath(),
        '-B',
        dstDir.toFilePath(),
        ..._getTargetOsOptions(input.config.code.targetOS),
        '-DCMAKE_BUILD_TYPE=$buildMode',
        // '-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON',
        ...await _getTargetOsVariables(
          codeConfig: input.config.code,
          logger: logger,
          processManager: processManager,
          fileSystem: fileSystem,
        ),
        ...variables.entries.map((e) => '-D${e.key}=${e.value}'),
      ],
      workingDirectory: srcDir,
      logger: logger,
      processManager: processManager,
      throwOnUnexpectedExitCode: true,
    );
    // cmake --build <dst> --config <type>
    await runProcess(
      executable: cmake.uri,
      arguments: ['--build', dstDir.toFilePath(), '--config', buildMode],
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
    final libPath = input.config.code.targetOS.libraryDirectoryPath(linkMode);
    final libName = input.config.code.targetOS.libraryFileName(name, linkMode);
    final libAsset = CodeAsset(
      package: input.packageName,
      name: assetName,
      linkMode: linkMode,
      file: outDir.resolve('$libPath/$libName'),
    );
    output.assets.code.add(libAsset);
  }

  List<String> _getTargetOsOptions(OS targetOS) => switch (targetOS) {
    .iOS => ['-G', 'Xcode'],
    _ => [],
  };

  // https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling
  // https://developer.android.com/studio/projects/configure-cmake?hl=zh-cn#call-cmake-cli
  // https://developer.android.com/ndk/guides/cmake?hl=zh-cn#command-line
  Future<List<String>> _getTargetOsVariables({
    required CodeConfig codeConfig,
    Logger? logger,
    ProcessManager? processManager,
    FileSystem? fileSystem,
  }) async => switch (codeConfig.targetOS) {
    .android => _getAndroidVariables(
      codeConfig: codeConfig,
      logger: logger,
      processManager: processManager,
      fileSystem: fileSystem,
    ),
    .iOS => [
      '-DCMAKE_SYSTEM_NAME=iOS',
      '-DCMAKE_OSX_SYSROOT=${codeConfig.iOS.targetSdk.type}',
      '-DCMAKE_OSX_ARCHITECTURES=${codeConfig.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${codeConfig.iOS.targetVersion}',
    ],
    .macOS => [
      '-DCMAKE_OSX_ARCHITECTURES=${codeConfig.targetArchitecture.toOsxArchitecture()}',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=${codeConfig.macOS.targetVersion}',
    ],
    .windows => [
      '-DCMAKE_GENERATOR_PLATFORM=${codeConfig.targetArchitecture.toWindowsPlatform()}',
    ],
    .linux => await _getLinuxVariables(
      codeConfig: codeConfig,
      logger: logger,
      processManager: processManager,
      fileSystem: fileSystem,
    ),
    _ => [],
  };

  Future<List<String>> _getAndroidVariables({
    required CodeConfig codeConfig,
    Logger? logger,
    ProcessManager? processManager,
    FileSystem? fileSystem,
  }) async {
    final ndk = await Tools.ndk.resolve(
      logger: logger,
      processManager: processManager,
      fileSystem: fileSystem,
    );
    return [
      // '-DCMAKE_SYSTEM_NAME=Android',
      // '-DCMAKE_SYSTEM_VERSION=${config.android.targetNdkApi}',
      // '-DCMAKE_ANDROID_ARCH_ABI=${config.targetArchitecture.toAndroidAbi()}',
      // '-DCMAKE_ANDROID_NDK=${await Tools.ndk.resolve(logger: logger).then((e) => e.uri.toFilePath())}',
      '-DCMAKE_TOOLCHAIN_FILE=${ndk.uri.resolve('/build/cmake/android.toolchain.cmake').toFilePath()}',
      '-DANDROID_ABI=${codeConfig.targetArchitecture.toAndroidAbi()}',
      '-DANDROID_PLATFORM=android-${codeConfig.android.targetNdkApi}',
    ];
  }

  Future<List<String>> _getLinuxVariables({
    required CodeConfig codeConfig,
    Logger? logger,
    ProcessManager? processManager,
    FileSystem? fileSystem,
  }) async {
    final resolver = CompilerResolver(
      codeConfig: codeConfig,
      logger: logger,
      processManager: processManager,
      fileSystem: fileSystem,
    );
    final compiler = await resolver.resolveCompiler();
    if (compiler.launcher != null) {
      throw UnsupportedError('${compiler.launcher} is not supported.');
    }
    return [
      '-DCMAKE_SYSTEM_NAME=Linux',
      '-DCMAKE_SYSTEM_PROCESSOR=${codeConfig.targetArchitecture.toSystemProcessor()}',
      '-DCMAKE_C_COMPILER=${compiler.uri.toFilePath()}',
      '-DCMAKE_CXX_COMPILER=${compiler.uri.toCxxCompilerPath()}',
    ];
  }
}

extension on OS {
  String libraryDirectoryPath(LinkMode linkMode) => switch (this) {
    .android => 'lib',
    .iOS => 'lib',
    .macOS => 'lib',
    .windows => linkMode is DynamicLoadingBundled ? 'bin' : 'lib',
    .linux => 'lib',
    _ => throw UnsupportedError('$this is not supported'),
  };
}

extension on Architecture {
  String toOsxArchitecture() => switch (this) {
    .arm64 => 'arm64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('$this is not supported'),
  };

  String toAndroidAbi() => switch (this) {
    .arm => 'armeabi-v7a',
    .arm64 => 'arm64-v8a',
    .ia32 => 'x86',
    .x64 => 'x86_64',
    .riscv64 => 'riscv64',
    _ => throw UnsupportedError('$this is not supported'),
  };

  String toSystemProcessor() => switch (this) {
    .arm => 'arm',
    .arm64 => 'aarch64',
    .ia32 => 'i686',
    .riscv32 => 'riscv32',
    .riscv64 => 'riscv64',
    .x64 => 'x86_64',
    _ => throw UnsupportedError('$this is not supported'),
  };

  String toWindowsPlatform() => switch (this) {
    .arm => 'ARM',
    .arm64 => 'ARM64',
    .ia32 => 'Win32',
    .x64 => 'x64',
    _ => throw UnsupportedError('$this is not supported'),
  };
}

extension on Uri {
  String toCxxCompilerPath() {
    final cCompilerPath = toFilePath();
    if (cCompilerPath.endsWith('gcc')) {
      return '${cCompilerPath.substring(0, cCompilerPath.length - 3)}g++';
    }
    if (cCompilerPath.endsWith('clang')) {
      return '${cCompilerPath.substring(0, cCompilerPath.length - 5)}clang++';
    }
    throw ArgumentError.value(cCompilerPath);
  }
}
