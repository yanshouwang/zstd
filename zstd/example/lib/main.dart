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
            final value = List.generate(1024, (i) => 0xff);
            final encoded = zstd.encode(value);
            final decoded = zstd.decode(encoded);
            log('value: ${value.length}');
            log('encoded: ${encoded.length}');
            log('decoded: ${decoded.length}');
          },
        ),
      ),
    );
  }
}
