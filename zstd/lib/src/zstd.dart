import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:zstd_api/zstd_api.dart';

/// Exposes zstd options for input parameters.
///
/// See http://facebook.github.io/zstd/doc/api_manual_latest.html for more documentation.
abstract final class ZstdOption {
  /// Minimal value for [ZstdCodec.level] and [ZstdEncoder.level].
  static const int minLevel = -(1 << 17);

  /// Maximal value for [ZstdCodec.level] and [ZstdEncoder.level]
  static const int maxLevel = 22;

  /// Default value for [ZstdCodec.level] and [ZstdEncoder.level].
  static const int defaultLevel = 3;
}

/// An instance of the default implementation of the [ZstdCodec].
const ZstdCodec zstd = ZstdCodec._default();

/// The [ZstdCodec] encodes raw bytes to zstd compressed bytes and decodes zstd
/// compressed bytes to raw bytes.
final class ZstdCodec extends Codec<List<int>, List<int>> {
  /// The compression-[level] can be set in the range of `-1..9`, with `6` being
  /// the default compression level. Levels above `6` will have higher
  /// compression rates at the cost of more CPU and memory usage. Levels below
  /// `6` will use less CPU and memory at the cost of lower compression rates.
  final int level;

  /// Initial compression dictionary.
  ///
  /// It should consist of strings (byte sequences) that are likely to be
  /// encountered later in the data to be compressed, with the most commonly used
  /// strings preferably put towards the end of the dictionary. Using a
  /// dictionary is most useful when the data to be compressed is short and can
  /// be predicted with good accuracy; the data can then be compressed better
  /// than with the default empty dictionary.
  final List<int>? dictionary;

  ZstdCodec({this.level = ZstdOption.defaultLevel, this.dictionary}) {
    _validateZstdLevel(level);
  }

  const ZstdCodec._default()
    : level = ZstdOption.defaultLevel,
      dictionary = null;

  /// Get a [ZstdEncoder] for encoding to `zstd` compressed data.
  @override
  ZstdEncoder get encoder => ZstdEncoder(level: level, dictionary: dictionary);

  /// Get a [ZstdDecoder] for decoding `zstd` compressed data.
  @override
  ZstdDecoder get decoder => ZstdDecoder(dictionary: dictionary);
}

/// The [ZstdEncoder] encoder is used by [ZstdCodec] and [GZipCodec] to compress
/// data.
final class ZstdEncoder extends Converter<List<int>, List<int>> {
  /// The compression-[level] can be set in the range of `-1..9`, with `6` being
  /// the default compression level. Levels above `6` will have higher
  /// compression rates at the cost of more CPU and memory usage. Levels below
  /// `6` will use less CPU and memory at the cost of lower compression rates.
  final int level;

  /// Initial compression dictionary.
  ///
  /// It should consist of strings (byte sequences) that are likely to be
  /// encountered later in the data to be compressed, with the most commonly used
  /// strings preferably put towards the end of the dictionary. Using a
  /// dictionary is most useful when the data to be compressed is short and can
  /// be predicted with good accuracy; the data can then be compressed better
  /// than with the default empty dictionary.
  final List<int>? dictionary;

  ZstdEncoder({this.level = ZstdOption.defaultLevel, this.dictionary}) {
    _validateZstdLevel(level);
  }

  /// Convert a list of bytes using the options given to the ZstdEncoder
  /// constructor.
  @override
  List<int> convert(List<int> bytes) {
    final sink = _BufferSink();
    startChunkedConversion(sink)
      ..add(bytes)
      ..close();
    return sink.builder.takeBytes();
  }

  /// Start a chunked conversion using the options given to the [ZstdEncoder]
  /// constructor.
  ///
  /// Accepts any `Sink<List<int>>`, but prefers a [ByteConversionSink],
  /// and converts any other sink to a [ByteConversionSink] before
  /// using it.
  @override
  ByteConversionSink startChunkedConversion(Sink<List<int>> sink) {
    if (sink is! ByteConversionSink) {
      sink = ByteConversionSink.from(sink);
    }
    return _ZstdEncoderSink._(sink, level, dictionary);
  }
}

/// The [ZstdDecoder] is used by [ZstdCodec] and [GZipCodec] to decompress data.
final class ZstdDecoder extends Converter<List<int>, List<int>> {
  /// Initial compression dictionary.
  ///
  /// It should consist of strings (byte sequences) that are likely to be
  /// encountered later in the data to be compressed, with the most commonly used
  /// strings preferably put towards the end of the dictionary. Using a
  /// dictionary is most useful when the data to be compressed is short and can
  /// be predicted with good accuracy; the data can then be compressed better
  /// than with the default empty dictionary.
  final List<int>? dictionary;

  ZstdDecoder({this.dictionary});

  /// Convert a list of bytes using the options given to the [ZstdDecoder]
  /// constructor.
  @override
  List<int> convert(List<int> bytes) {
    _BufferSink sink = _BufferSink();
    startChunkedConversion(sink)
      ..add(bytes)
      ..close();
    return sink.builder.takeBytes();
  }

  /// Start a chunked conversion.
  ///
  /// Accepts any `Sink<List<int>>`, but prefers a [ByteConversionSink],
  /// and converts any other sink to a [ByteConversionSink] before
  /// using it.
  @override
  ByteConversionSink startChunkedConversion(Sink<List<int>> sink) {
    if (sink is! ByteConversionSink) {
      sink = ByteConversionSink.from(sink);
    }
    return _ZstdDecoderSink._(sink, dictionary);
  }
}

/// The [RawZstdFilter] class provides a low-level interface to zstd.
abstract interface class RawZstdFilter {
  /// Returns a [RawZstdFilter] whose [process] and [processed] methods
  /// compress data.
  factory RawZstdFilter.compressFilter({
    int level = ZstdOption.defaultLevel,
    List<int>? dictionary,
  }) {
    return _makeZstdCompressFilter(level, dictionary);
  }

  /// Returns a [RawZstdFilter] whose [process] and [processed] methods
  /// decompress data.
  factory RawZstdFilter.decompressFilter({List<int>? dictionary}) {
    return _makeZstdDecompressFilter(dictionary);
  }

  /// Process a chunk of data.
  ///
  /// This method must only be called when [processed] returns `null`.
  void process(List<int> data, int start, int end);

  /// Get a chunk of processed data.
  ///
  /// When there are no more data available, [processed] will return `null`.
  /// Set [flush] to `false` for non-final calls
  /// to improve performance of some filters.
  ///
  /// The last call to [processed] should have [end] set to `true`. This will
  /// make sure an 'end' packet is written on the stream.
  List<int>? processed({bool flush = true, bool end = false});

  static RawZstdFilter _makeZstdCompressFilter(
    int level,
    List<int>? dictionary,
  ) => _ZstdCompressFilter(level, dictionary);

  static RawZstdFilter _makeZstdDecompressFilter(List<int>? dictionary) =>
      _ZstdDecompressFilter(dictionary);
}

class _BufferSink extends ByteConversionSink {
  final BytesBuilder builder = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    builder.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    if (chunk is Uint8List) {
      Uint8List list = chunk;
      builder.add(
        Uint8List.view(list.buffer, list.offsetInBytes + start, end - start),
      );
    } else {
      builder.add(chunk.sublist(start, end));
    }
  }

  @override
  void close() {}
}

class _ZstdEncoderSink extends _FilterSink {
  _ZstdEncoderSink._(ByteConversionSink sink, int level, List<int>? dictionary)
    : super(sink, RawZstdFilter._makeZstdCompressFilter(level, dictionary));
}

class _ZstdDecoderSink extends _FilterSink {
  _ZstdDecoderSink._(ByteConversionSink sink, List<int>? dictionary)
    : super(sink, RawZstdFilter._makeZstdDecompressFilter(dictionary));
}

class _FilterSink extends ByteConversionSink {
  final RawZstdFilter _filter;
  final ByteConversionSink _sink;
  bool _closed = false;
  bool _empty = true;

  _FilterSink(this._sink, this._filter);

  @override
  void add(List<int> data) {
    addSlice(data, 0, data.length, false);
  }

  @override
  void addSlice(List<int> data, int start, int end, bool isLast) {
    if (_closed) return;
    RangeError.checkValidRange(start, end, data.length);
    try {
      _empty = false;
      final bufferAndStart = _ensureFastAndSerializableByteData(
        data,
        start,
        end,
      );
      _filter.process(
        bufferAndStart.buffer,
        bufferAndStart.start,
        end - (start - bufferAndStart.start),
      );
      while (true) {
        final out = _filter.processed(flush: false);
        if (out == null) break;
        _sink.add(out);
      }
    } catch (e) {
      _closed = true;
      rethrow;
    }

    if (isLast) close();
  }

  @override
  void close() {
    if (_closed) return;
    // Be sure to send process an empty chunk of data. Without this, the empty
    // message would not have a GZip frame (if compressed with GZip).
    if (_empty) _filter.process(const [], 0, 0);
    try {
      while (true) {
        final out = _filter.processed(end: true);
        if (out == null) break;
        _sink.add(out);
      }
    } catch (e) {
      // TODO(kevmoo): not sure why this isn't a try/finally
      _closed = true;
      rethrow;
    }
    _closed = true;
    _sink.close();
  }
}

abstract base class _FilterImpl implements RawZstdFilter {
  ZstdFilterApi get api;

  @override
  void process(List<int> data, int start, int end) =>
      api.process(data, start, end);

  @override
  List<int>? processed({bool flush = true, bool end = false}) =>
      api.processd(flush, end);
}

final class _ZstdCompressFilter extends _FilterImpl {
  @override
  final ZstdCompressFilterApi api;

  _ZstdCompressFilter(int level, List<int>? dictionary)
    : api = ZstdApi.instance.newZstdCompressFilter() {
    _init(level, dictionary);
  }

  void _init(int level, List<int>? dictionary) => api.init(level, dictionary);
}

final class _ZstdDecompressFilter extends _FilterImpl {
  @override
  final ZstdDecompressFilterApi api;

  _ZstdDecompressFilter(List<int>? dictionary)
    : api = ZstdApi.instance.newZstdDecompressFilter() {
    _init(dictionary);
  }

  void _init(List<int>? dictionary) => api.init(dictionary);
}

// Object for holding a buffer and an offset.
class _BufferAndStart {
  List<int> buffer;
  int start;
  _BufferAndStart(this.buffer, this.start);
}

// Ensure that the input List can be serialized through a native port.
_BufferAndStart _ensureFastAndSerializableByteData(
  List<int> buffer,
  int start,
  int end,
) {
  if ((buffer is Uint8List) && (buffer.buffer.lengthInBytes == buffer.length)) {
    // Send typed data directly, unless it is a partial view, in which case we
    // would rather copy than drag in the potentially much large backing store.
    // See issue 50206.
    return _BufferAndStart(buffer, start);
  }
  int length = end - start;
  var newBuffer = Uint8List(length);
  newBuffer.setRange(0, length, buffer, start);
  return _BufferAndStart(newBuffer, 0);
}

void _validateZstdLevel(int level) {
  if (ZstdOption.minLevel > level || ZstdOption.maxLevel < level) {
    throw RangeError.range(level, ZstdOption.minLevel, ZstdOption.maxLevel);
  }
}
