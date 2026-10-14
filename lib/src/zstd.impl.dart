part of 'zstd.dart';

class ZstdError extends Error {
  final int errorCode;
  final String errorName;

  ZstdError(this.errorCode, this.errorName);

  @override
  String toString() {
    return "ZstdError: $errorCode, $errorName";
  }
}

abstract base class _ZstdFilter implements RawZstdFilter, ffi.Finalizable {
  static final _finalizer = ffi.NativeFinalizer(ffi.malloc.nativeFree);

  final ffi.Pointer<ffi.ZSTD_inBuffer> input;
  final ffi.Pointer<ffi.ZSTD_outBuffer> output;

  _ZstdFilter()
    : input = ffi.malloc<ffi.ZSTD_inBuffer>(),
      output = ffi.malloc<ffi.ZSTD_outBuffer>() {
    _finalizer.attach(this, input.cast<ffi.Void>());
    _finalizer.attach(this, output.cast<ffi.Void>());
  }

  @override
  void process(List<int> data, int start, int end) {
    final chunk = data.sublist(start, end);
    if (input.ref.pos != input.ref.size) {
      throw StateError('Call to Process while still processing data');
    }
    if (input.ref.src.isNotNull) {
      ffi.malloc.free(input.ref.src);
    }
    final src = ffi.malloc<ffi.Uint8>(chunk.length);
    src.asTypedList(chunk.length).setAll(0, chunk);
    input.ref.src = src.cast<ffi.Void>();
    input.ref.size = chunk.length;
    input.ref.pos = 0;
  }
}

final class _ZstdCompressFilter extends _ZstdFilter {
  static final _freeCCtx =
      ffi.Native.addressOf<
            ffi.NativeFunction<ffi.Size Function(ffi.Pointer<ffi.ZSTD_CCtx>)>
          >(ffi.ZSTD_freeCCtx)
          .cast<ffi.NativeFinalizerFunction>();
  static final _cctxFinalizer = ffi.NativeFinalizer(_freeCCtx);

  ffi.Pointer<ffi.ZSTD_CStream> cctx;

  _ZstdCompressFilter(int level, List<int>? dictionary)
    : cctx = ffi.ZSTD_createCCtx().checkNotNull('cctx') {
    _cctxFinalizer.attach(this, cctx.cast<ffi.Void>());
    _init(level, dictionary);
  }

  void _init(int level, List<int>? dictionary) {
    input.ref.src = ffi.nullptr;
    input.ref.size = 0;
    input.ref.pos = 0;
    ffi.ZSTD_CCtx_reset(
      cctx,
      ffi.ZSTD_ResetDirective.ZSTD_reset_session_only,
    ).checkError();
    ffi.ZSTD_CCtx_setParameter(
      cctx,
      ffi.ZSTD_cParameter.ZSTD_c_compressionLevel,
      level,
    ).checkError();
    ffi.ZSTD_CCtx_setParameter(
      cctx,
      ffi.ZSTD_cParameter.ZSTD_c_checksumFlag,
      1,
    ).checkError();
    if (dictionary == null) {
      ffi.ZSTD_CCtx_loadDictionary(cctx, ffi.nullptr, 0).checkError();
    } else {
      ffi.using((arena) {
        final dictSize = dictionary.length;
        final dict = arena<ffi.Uint8>(dictSize);
        dict.asTypedList(dictSize).setAll(0, dictionary);
        ffi.ZSTD_CCtx_loadDictionary(
          cctx,
          dict.cast<ffi.Void>(),
          dictSize,
        ).checkError();
      });
    }
  }

  @override
  List<int>? processed({bool flush = true, bool end = false}) {
    // Check is input is consumed completely.
    // Call ZSTD_compressStream2 until input pos == input size when end is false.
    // Call ZSTD_compressStream2 until input src is null when end is true.
    if (end ? input.ref.src.isNull : input.ref.pos == input.ref.size) {
      return null;
    }
    try {
      final dstSize = ffi.ZSTD_CStreamOutSize().checkError();
      output.ref.dst = ffi.malloc<ffi.Uint8>(dstSize).cast<ffi.Void>();
      output.ref.size = dstSize;
      output.ref.pos = 0;
      final endOp = end
          ? ffi.ZSTD_EndDirective.ZSTD_e_end
          : flush
          ? ffi.ZSTD_EndDirective.ZSTD_e_flush
          : ffi.ZSTD_EndDirective.ZSTD_e_continue;
      final remainingSize = ffi.ZSTD_compressStream2(
        cctx,
        output,
        input,
        endOp,
      ).checkError();
      // If we're on the last chunk we're finished when zstd returns 0,
      // which means its consumed all the input AND finished the frame.
      // Otherwise, we're finished when we've consumed all the input.
      if (end && remainingSize == 0) {
        if (input.ref.pos != input.ref.size) {
          throw StateError(
            'Impossible: zstd only returns 0 when the input is completely consumed!',
          );
        }
        ffi.malloc.free(input.ref.src);
        input.ref.src = ffi.nullptr;
        input.ref.size = 0;
        input.ref.pos = 0;
      }
      final value = output.ref.dst.cast<ffi.Uint8>().asTypedList(
        output.ref.pos,
        finalizer: ffi.malloc.nativeFree,
      );
      return value;
    } catch (e) {
      ffi.malloc.free(input.ref.src);
      input.ref.src = ffi.nullptr;
      input.ref.size = 0;
      input.ref.pos = 0;
      ffi.malloc.free(output.ref.dst);
      output.ref.size = 0;
      output.ref.pos = 0;
      rethrow;
    }
  }
}

final class _ZstdDecompressFilter extends _ZstdFilter {
  static final _freeDCtx =
      ffi.Native.addressOf<
            ffi.NativeFunction<ffi.Size Function(ffi.Pointer<ffi.ZSTD_DCtx>)>
          >(ffi.ZSTD_freeDCtx)
          .cast<ffi.NativeFinalizerFunction>();
  static final _dctxFinalizer = ffi.NativeFinalizer(_freeDCtx);

  final ffi.Pointer<ffi.ZSTD_DCtx> dctx;

  _ZstdDecompressFilter(List<int>? dictionary)
    : dctx = ffi.ZSTD_createDCtx().checkNotNull('dctx') {
    _dctxFinalizer.attach(this, dctx.cast<ffi.Void>());
    _init(dictionary);
  }

  void _init(List<int>? dictionary) {
    input.ref.src = ffi.nullptr;
    input.ref.size = 0;
    input.ref.pos = 0;
    ffi.ZSTD_DCtx_reset(
      dctx,
      ffi.ZSTD_ResetDirective.ZSTD_reset_session_only,
    ).checkError();
    if (dictionary == null) {
      ffi.ZSTD_DCtx_loadDictionary(dctx, ffi.nullptr, 0).checkError();
    } else {
      ffi.using((arena) {
        final dictSize = dictionary.length;
        final dict = arena<ffi.Uint8>(dictSize);
        dict.asTypedList(dictSize).setAll(0, dictionary);
        ffi.ZSTD_DCtx_loadDictionary(
          dctx,
          dict.cast<ffi.Void>(),
          dictSize,
        ).checkError();
      });
    }
  }

  @override
  List<int>? processed({bool flush = true, bool end = false}) {
    if (end ? input.ref.src.isNull : input.ref.pos == input.ref.size) {
      return null;
    }
    try {
      final dstSize = ffi.ZSTD_DStreamOutSize().checkError();
      output.ref.dst = ffi.malloc<ffi.Uint8>(dstSize).cast<ffi.Void>();
      output.ref.size = dstSize;
      output.ref.pos = 0;
      final remainingSize = ffi.ZSTD_decompressStream(
        dctx,
        output,
        input,
      ).checkError();
      // Given a valid frame, zstd won't consume the last byte of the frame
      // until it has flushed all of the decompressed data of the frame.
      // Therefore, instead of checking if the return code is 0, we can
      // decompress just check if input.pos < input.size.
      if (input.ref.pos == input.ref.size) {
        if (end && remainingSize != 0) {
          throw StateError('EOF before end of stream: $remainingSize');
        }
        ffi.malloc.free(input.ref.src);
        input.ref.src = ffi.nullptr;
        input.ref.size = 0;
        input.ref.pos = 0;
      }
      final value = output.ref.dst.cast<ffi.Uint8>().asTypedList(
        output.ref.pos,
        finalizer: ffi.malloc.nativeFree,
      );
      return value;
    } catch (e) {
      ffi.malloc.free(input.ref.src);
      input.ref.src = ffi.nullptr;
      input.ref.size = 0;
      input.ref.pos = 0;
      ffi.malloc.free(output.ref.dst);
      output.ref.size = 0;
      output.ref.pos = 0;
      rethrow;
    }
  }
}

extension _PointerX<T extends ffi.NativeType> on ffi.Pointer<T> {
  bool get isNull => this == ffi.nullptr;
  bool get isNotNull => !isNull;

  ffi.Pointer<T> checkNotNull([String? name]) =>
      isNull ? throw ArgumentError.notNull(name) : this;
}

extension on ffi.Pointer<ffi.Char> {
  String toDartString() => cast<ffi.Utf8>().toDartString();
}

extension on int {
  int checkError() {
    final isError = ffi.ZSTD_isError(this);
    if (isError == 0) return this;
    final errorCode = ffi.ZSTD_getErrorCode(this).value;
    final errorName = ffi.ZSTD_getErrorName(this).toDartString();
    throw ZstdError(errorCode, errorName);
  }
}
