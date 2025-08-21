#ifndef FLUTTER_PLUGIN_ZSTD_PLUGIN_H_
#define FLUTTER_PLUGIN_ZSTD_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace zstd {

class ZstdPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ZstdPlugin();

  virtual ~ZstdPlugin();

  // Disallow copy and assign.
  ZstdPlugin(const ZstdPlugin&) = delete;
  ZstdPlugin& operator=(const ZstdPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace zstd

#endif  // FLUTTER_PLUGIN_ZSTD_PLUGIN_H_
