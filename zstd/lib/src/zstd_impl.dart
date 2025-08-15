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
  ZstdCompressFilterApi makeZstdCompressFilter() => ZstdCompressFilterImpl();

  @override
  ZstdDecompressFilterApi makeZstdDecompressFilter() =>
      ZstdDecompressFilterImpl();
}

abstract base class ZstdFilterImpl implements ZstdFilterApi {
  final Pointer<ZSTD_outBuffer> output;
  final Pointer<ZSTD_inBuffer> input;
  bool initialized;

  ZstdFilterImpl()
    : output =
          malloc<ZSTD_outBuffer>()..ref.size = _bindings.ZSTD_CStreamOutSize(),
      input = malloc<ZSTD_inBuffer>(),
      initialized = false;
}

final class ZstdCompressFilterImpl extends ZstdFilterImpl
    implements ZstdCompressFilterApi {
  List<int> currentBuffer;
  Pointer<ZSTD_CStream> cctx;

  ZstdCompressFilterImpl()
    : cctx = _bindings.ZSTD_createCCtx().checkNotNull('cctx');

  @override
  void init(int level, List<int>? dictionary) {
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
  void process(List<int> data, int start, int end) {
    final chunkLength = end - start;
    int length;
    if (currentBuffer != null)
      throw StateError('Call to Process while still processing data');
    currentBuffer = data;
  }

  @override
  List<int>? processd(bool flush, bool end) {
    _bindings.ZSTD_compressStream2(cctx, output, input, endOp).checkError();
  }
}

final class ZstdDecompressFilterImpl extends ZstdFilterImpl
    implements ZstdDecompressFilterApi {
  final Pointer<ZSTD_DCtx> dctx;

  ZstdDecompressFilterImpl()
    : dctx = _bindings.ZSTD_createDCtx().checkNotNull('dctx');

  @override
  void init(List<int>? dictionary) {
    _bindings.ZSTD_DCtx_reset(
      dctx,
      ZSTD_ResetDirective.ZSTD_reset_session_only,
    ).checkError();
    // TODO: implement init with dictionary
    if (dictionary != null) throw UnimplementedError();
  }

  @override
  void process(List<int> data, int start, int end) {
    // TODO: implement process
  }

  @override
  List<int>? processd(bool flush, bool end) {
    // TODO: implement processd
    throw UnimplementedError();
  }
}

extension _PointerX<T extends NativeType> on Pointer<T> {
  bool get isNull => this == nullptr;

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
