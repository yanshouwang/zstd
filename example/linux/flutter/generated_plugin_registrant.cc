//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <zstd/zstd_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) zstd_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ZstdPlugin");
  zstd_plugin_register_with_registrar(zstd_registrar);
}
