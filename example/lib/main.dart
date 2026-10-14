import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              child: Text('ZSTD'),
              onPressed: () async {
                final input = await rootBundle
                    .load('assets/github/user.0AdXA5MNzW.json')
                    .then((e) => Uint8List.sublistView(e));
                final encoded = zstd.encode(input);
                final ratio = input.length / encoded.length;
                log('encode ratio is $ratio');
                final decoded = zstd.decode(encoded);
                log('decode length is ${decoded.length}');
                final text = utf8.decode(decoded);
                log('decode text is $text');
              },
            ),
            CupertinoButton(
              child: Text('ZSTD with dictionary'),
              onPressed: () async {
                final dictionary = await rootBundle
                    .load('assets/dictionary')
                    .then((e) => Uint8List.sublistView(e));
                final zstd = ZstdCodec(dictionary: dictionary);
                final input = await rootBundle
                    .load('assets/github/user.0AdXA5MNzW.json')
                    .then((e) => Uint8List.sublistView(e));
                final encoded = zstd.encode(input);
                final ratio = input.length / encoded.length;
                log('encode ratio with dictionary is $ratio');
                final decoded = zstd.decode(encoded);
                log('decode length is ${decoded.length}');
                final text = utf8.decode(decoded);
                log('decode text is $text');
              },
            ),
          ],
        ),
      ),
    );
  }
}
