#include "include/zstd/zstd_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "zstd_plugin.h"

void ZstdPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  zstd::ZstdPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
