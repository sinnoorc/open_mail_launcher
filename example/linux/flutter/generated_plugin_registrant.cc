//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <open_mail_launcher/open_mail_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) open_mail_launcher_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OpenMailLauncherPlugin");
  open_mail_launcher_plugin_register_with_registrar(open_mail_launcher_registrar);
}
