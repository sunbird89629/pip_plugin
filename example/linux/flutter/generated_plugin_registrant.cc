//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <pip_plugin/pip_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) pip_plugin_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PipPlugin");
  pip_plugin_register_with_registrar(pip_plugin_registrar);
}
