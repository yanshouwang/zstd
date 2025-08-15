import 'zstd_filter_api.dart';

abstract interface class ZstdDecompressFilterApi implements ZstdFilterApi {
  void init(List<int>? dictionary);
}
