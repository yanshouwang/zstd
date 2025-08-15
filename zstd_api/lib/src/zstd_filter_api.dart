abstract interface class ZstdFilterApi {
  void process(List<int> data, int start, int end);
  List<int>? processd(bool flush, bool end);
}
