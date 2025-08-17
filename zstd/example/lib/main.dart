import 'package:flutter/widgets.dart';
import 'package:zstd/zstd.dart';

void main() {
  final value = List.generate(1024, (i) => 0xff);
  final encoded = zstd.encode(value);
  final decoded = zstd.decode(encoded);
  debugPrint('value: ${value.length}');
  debugPrint('encoded: ${encoded.length}');
  debugPrint('decoded: ${decoded.length}');
}
