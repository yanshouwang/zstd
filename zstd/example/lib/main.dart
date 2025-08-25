import 'dart:convert';

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
            final input = utf8.encode(
              'Hello, zstd! Hello, zstd! Hello, zstd! Hello, zstd! Hello, zstd!',
            );
            final compressed = zstd.encode(input);
            final decompressed = zstd.decode(compressed);
            final output = utf8.decode(decompressed);
            debugPrint('input: $input');
            debugPrint('compressed: $compressed');
            debugPrint('decompressed: $decompressed');
            debugPrint(output);
          },
        ),
      ),
    );
  }
}
