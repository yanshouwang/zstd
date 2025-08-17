import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zstd/zstd.dart';

void main() {
  final r = math.Random();
  final input = List.generate(1024, (i) => r.nextInt(0xff));
  final output = zstd.encode(input);
  debugPrint('input: $input');
  debugPrint('output: $output');
}
