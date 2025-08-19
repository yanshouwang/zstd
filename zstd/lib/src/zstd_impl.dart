import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:zstd_api/zstd_api.dart';

import 'zstd_bindings.g.dart';

const String _libName = 'zstd';

/// The dynamic library in which the symbols for [ZstdBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final ZstdBindings _bindings = ZstdBindings(_dylib);

class ZstdError extends Error {
  final int errorCode;
  final String errorName;

  ZstdError(this.errorCode, this.errorName);

  @override
  String toString() {
    return "ZstdError: $errorCode, $errorName";
  }
}

final class ZstdImpl extends ZstdApi {
  ZstdImpl() : super.impl();

  @override
  ZstdCompressFilterApi makeZstdCompressFilter() {
    return ZstdCompressFilterImpl();
  }

  @override
  ZstdDecompressFilterApi makeZstdDecompressFilter() =>
      ZstdDecompressFilterImpl();
}

abstract base class ZstdFilterImpl implements ZstdFilterApi, Finalizable {
  static final _finalizer = NativeFinalizer(malloc.nativeFree);

  final Pointer<ZSTD_inBuffer> input;
  final Pointer<ZSTD_outBuffer> output;

  ZstdFilterImpl()
    : input = malloc<ZSTD_inBuffer>(),
      output = malloc<ZSTD_outBuffer>() {
    _finalizer.attach(this, input.cast<Void>());
    _finalizer.attach(this, output.cast<Void>());
  }

  @override
  void process(List<int> data, int start, int end) {
    final chunk = data.sublist(start, end);
    if (input.ref.pos != input.ref.size) {
      throw StateError('Call to Process while still processing data');
    }
    if (input.ref.src.isNotNull) {
      malloc.free(input.ref.src);
    }
    final src = malloc<Uint8>(chunk.length);
    src.asTypedList(chunk.length).setAll(0, chunk);
    input.ref.src = src.cast<Void>();
    input.ref.size = chunk.length;
    input.ref.pos = 0;
  }
}

final class ZstdCompressFilterImpl extends ZstdFilterImpl
    implements ZstdCompressFilterApi {
  static final _freeCCtx =
      _dylib
          .lookup<NativeFunction<Size Function(Pointer<ZSTD_CCtx>)>>(
            'ZSTD_freeCCtx',
          )
          .cast<NativeFinalizerFunction>();
  static final _cctxFinalizer = NativeFinalizer(_freeCCtx);

  Pointer<ZSTD_CStream> cctx;

  ZstdCompressFilterImpl()
    : cctx = _bindings.ZSTD_createCCtx().checkNotNull('cctx') {
    _cctxFinalizer.attach(this, cctx.cast<Void>());
  }

  @override
  void init(int level, List<int>? dictionary) {
    input.ref.src = nullptr;
    input.ref.size = 0;
    input.ref.pos = 0;
    final outSize = _bindings.ZSTD_CStreamOutSize().checkError();
    output.ref.dst = malloc<Uint8>(outSize).cast<Void>();
    output.ref.size = outSize;
    output.ref.pos = 0;
    _bindings.ZSTD_CCtx_reset(
      cctx,
      ZSTD_ResetDirective.ZSTD_reset_session_only,
    ).checkError();
    _bindings.ZSTD_CCtx_setParameter(
      cctx,
      ZSTD_cParameter.ZSTD_c_compressionLevel,
      level,
    ).checkError();
    // TODO: implement init with dictionary
    if (dictionary != null) throw UnimplementedError();
  }

  @override
  List<int>? processd(bool flush, bool end) {
    // Check is input is consumed completely.
    // Call ZSTD_compressStream2 until input pos == inpu size when end is false.
    // Call ZSTD_compressStream2 until input src is null when end is true.
    if (end ? input.ref.src.isNull : input.ref.pos == input.ref.size) {
      return null;
    }
    try {
      final endOp =
          end
              ? ZSTD_EndDirective.ZSTD_e_end
              : flush
              ? ZSTD_EndDirective.ZSTD_e_flush
              : ZSTD_EndDirective.ZSTD_e_continue;
      final remainingSize =
          _bindings.ZSTD_compressStream2(
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
        malloc.free(input.ref.src);
        input.ref.src = nullptr;
        input.ref.size = 0;
        input.ref.pos = 0;
      }
      final value = output.ref.dst.cast<Uint8>().asTypedList(output.ref.pos);
      output.ref.pos = 0;
      return value;
    } catch (e) {
      malloc.free(input.ref.src);
      input.ref.src = nullptr;
      input.ref.size = 0;
      input.ref.pos = 0;
      output.ref.pos = 0;
      rethrow;
    }
  }
}

final class ZstdDecompressFilterImpl extends ZstdFilterImpl
    implements ZstdDecompressFilterApi {
  static final _freeDCtx =
      _dylib
          .lookup<NativeFunction<Size Function(Pointer<ZSTD_DCtx>)>>(
            'ZSTD_freeDCtx',
          )
          .cast<NativeFinalizerFunction>();
  static final _dctxFinalizer = NativeFinalizer(_freeDCtx);

  final Pointer<ZSTD_DCtx> dctx;

  ZstdDecompressFilterImpl()
    : dctx = _bindings.ZSTD_createDCtx().checkNotNull('dctx') {
    _dctxFinalizer.attach(this, dctx.cast<Void>());
  }

  @override
  void init(List<int>? dictionary) {
    input.ref.src = nullptr;
    input.ref.size = 0;
    input.ref.pos = 0;
    final outSize = _bindings.ZSTD_DStreamOutSize().checkError();
    output.ref.dst = malloc<Uint8>(outSize).cast<Void>();
    output.ref.size = outSize;
    output.ref.pos = 0;
    _bindings.ZSTD_DCtx_reset(
      dctx,
      ZSTD_ResetDirective.ZSTD_reset_session_only,
    ).checkError();
    // TODO: implement init with dictionary
    if (dictionary != null) throw UnimplementedError();
  }

  @override
  List<int>? processd(bool flush, bool end) {
    if (end ? input.ref.src.isNull : input.ref.pos == input.ref.size) {
      return null;
    }
    try {
      final remainingSize =
          _bindings.ZSTD_decompressStream(dctx, output, input).checkError();
      // Given a valid frame, zstd won't consume the last byte of the frame
      // until it has flushed all of the decompressed data of the frame.
      // Therefore, instead of checking if the return code is 0, we can
      // decompress just check if input.pos < input.size.
      if (input.ref.pos == input.ref.size) {
        if (end && remainingSize != 0) {
          throw StateError('EOF before end of stream: $remainingSize');
        }
        malloc.free(input.ref.src);
        input.ref.src = nullptr;
        input.ref.size = 0;
        input.ref.pos = 0;
      }
      final value = output.ref.dst.cast<Uint8>().asTypedList(output.ref.pos);
      output.ref.pos = 0;
      return value;
    } catch (e) {
      malloc.free(input.ref.src);
      input.ref.src = nullptr;
      input.ref.size = 0;
      input.ref.pos = 0;
      output.ref.pos = 0;
      rethrow;
    }
  }
}

extension _PointerX<T extends NativeType> on Pointer<T> {
  bool get isNull => this == nullptr;
  bool get isNotNull => !isNull;

  Pointer<T> checkNotNull([String? name]) =>
      isNull ? throw ArgumentError.notNull(name) : this;
}

extension on Pointer<Char> {
  String toDartString() => cast<Utf8>().toDartString();
}

extension on int {
  int checkError() {
    final isError = _bindings.ZSTD_isError(this);
    if (isError == 0) return this;
    final errorCode = _bindings.ZSTD_getErrorCode(this).value;
    final errorName = _bindings.ZSTD_getErrorName(this).toDartString();
    throw ZstdError(errorCode, errorName);
  }
}
