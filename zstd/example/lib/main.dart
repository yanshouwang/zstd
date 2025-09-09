import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';

import 'package:zstd/zstd.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(home: HomeView());
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: CupertinoButton(
          child: Text('ZSTD'),
          onPressed: () {
            final input =
                "Zstandard, or zstd as short version, is a fast lossless compression algorithm, targeting real-time compression scenarios at zlib-level and better compression ratios. It's backed by a very fast entropy stage, provided by Huff0 and FSE library.";
            final value = utf8.encode(input);
            final compressed = zstd.encode(value);
            final decompressed = zstd.decode(compressed);
            final output = utf8.decode(decompressed);
            log('input: $input');
            log('compressed: $compressed');
            log('decompressed: $decompressed');
            log('output: $output');
          },
        ),
      ),
    );
  }
}
