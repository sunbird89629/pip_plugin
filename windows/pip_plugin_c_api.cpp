#include "include/pip_plugin/pip_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "pip_plugin.h"

void PipPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  pip_plugin::PipPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
