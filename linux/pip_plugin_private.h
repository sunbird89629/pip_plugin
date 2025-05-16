#ifndef FLUTTER_PLUGIN_PIP_PLUGIN_PRIVATE_H_
#define FLUTTER_PLUGIN_PIP_PLUGIN_PRIVATE_H_

#include <flutter_linux/flutter_linux.h>

// Function declarations for plugin methods
FlMethodResponse* get_platform_version();
FlMethodResponse* setup_pip(FlValue* args);
FlMethodResponse* update_pip(FlValue* args);
FlMethodResponse* start_pip();
FlMethodResponse* stop_pip();
FlMethodResponse* is_pip_supported();
FlMethodResponse* update_text(FlValue* args);

#endif  // FLUTTER_PLUGIN_PIP_PLUGIN_PRIVATE_H_