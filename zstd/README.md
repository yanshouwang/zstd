# zstd

`zstd` is a Flutter plugin that provides fast lossless compression and decompression using the [Zstandard (zstd)](https://facebook.github.io/zstd/) algorithm. It enables Dart and Flutter applications to efficiently compress and decompress data across multiple platforms, including Android, iOS, macOS, Windows and Linux.

## Features

- Compress and decompress data using the zstd algorithm
- Cross-platform support: Android, iOS, macOS, Windows, Linux
- Simple Dart API

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
	zstd: ^<latest_version>
```

Then run:

```sh
flutter pub get
```

## Usage

Import the package:

```dart
import 'package:zstd/zstd.dart';
```

Compress and decompress data:

```dart
final input = utf8.encode('Hello, zstd!');
final compressed = zstd.encode(input);
final decompressed = zstd.decode(compressed);
final output = utf8.decode(decompressed);
debugPrint(output); // Hello, zstd!
```

See the [example](../example/lib/main.dart) for more details.

## Platform Support

- Android
- iOS
- macOS
- Windows
- Linux

## Contributing

Contributions are welcome! Please open issues or submit pull requests for bug fixes, new features, or improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

