//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <zstd/zstd_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  ZstdPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ZstdPluginCApi"));
}
