import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main(List<String> args) async {
  final rootUri = Platform.script.resolve('../');
  final generator = FfiGenerator(
    input: Input(
      entryPoints: [
        rootUri.resolve('src/include/zdict.h'),
        rootUri.resolve('src/include/zstd_errors.h'),
        rootUri.resolve('src/include/zstd.h'),
      ],
    ),
    output: Output(
      dart: DartOutput(path: rootUri.resolve('lib/src/zstd.ffi.dart')),
    ),
    visitors: [
      Visitor(
        func: (node) => node.isIncluded = !node.originalName.startsWith('_'),
        struct: (node) => node.isIncluded = !node.originalName.startsWith('_'),
        union: (node) => node.isIncluded = !node.originalName.startsWith('_'),
        enumClass: (node) => node
          ..isIncluded = !node.originalName.startsWith('_')
          ..silenceWarning = true,
        global: (node) => node.isIncluded = !node.originalName.startsWith('_'),
        macroConstant: (node) =>
            node.isIncluded = !node.originalName.startsWith('_'),
        typealias: (node) => node.originalName.startsWith('_')
            ? node.isIncluded = .never
            : node.isIncluded = .ifUsed,
      ),
    ],
  );
  await generator.generate();
}
