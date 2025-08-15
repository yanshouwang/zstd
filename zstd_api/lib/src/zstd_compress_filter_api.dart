import 'zstd_filter_api.dart';

abstract interface class ZstdCompressFilterApi implements ZstdFilterApi {
  void init(int level, List<int>? dictionary);
}
