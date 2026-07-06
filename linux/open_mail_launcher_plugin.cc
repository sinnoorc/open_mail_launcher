#include "include/open_mail_launcher/open_mail_launcher_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>

#include <cstring>

#define OPEN_MAIL_LAUNCHER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), open_mail_launcher_plugin_get_type(), \
                              OpenMailLauncherPlugin))

// Mail apps are the registered handlers for this MIME type — the same list
// `xdg-mime query default x-scheme-handler/mailto` consults.
static const char kMailtoType[] = "x-scheme-handler/mailto";

struct _OpenMailLauncherPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(OpenMailLauncherPlugin, open_mail_launcher_plugin, g_object_get_type())

// Joins a string-list entry of the emailContent map ("to"/"cc"/"bcc") into a
// comma-separated, percent-escaped string. Returns nullptr if absent/empty.
// '@' and ',' stay literal — both are legal in mailto: and keep URIs readable.
static gchar* joined_escaped_list(FlValue* content, const char* key) {
  FlValue* list = fl_value_lookup_string(content, key);
  if (list == nullptr || fl_value_get_type(list) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(list) == 0) {
    return nullptr;
  }
  g_autoptr(GString) joined = g_string_new(nullptr);
  for (size_t i = 0; i < fl_value_get_length(list); i++) {
    FlValue* item = fl_value_get_list_value(list, i);
    if (fl_value_get_type(item) != FL_VALUE_TYPE_STRING) continue;
    const gchar* address = fl_value_get_string(item);
    if (strlen(address) == 0) continue;
    g_autofree gchar* escaped = g_uri_escape_string(address, "@", TRUE);
    if (joined->len > 0) g_string_append_c(joined, ',');
    g_string_append(joined, escaped);
  }
  return joined->len > 0 ? g_strdup(joined->str) : nullptr;
}

// Percent-escaped string entry of the emailContent map, nullptr if absent/empty.
static gchar* escaped_string(FlValue* content, const char* key) {
  FlValue* value = fl_value_lookup_string(content, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING ||
      strlen(fl_value_get_string(value)) == 0) {
    return nullptr;
  }
  return g_uri_escape_string(fl_value_get_string(value), nullptr, TRUE);
}

static void append_query(GString* uri, const char* name, const gchar* value) {
  if (value == nullptr) return;
  g_string_append_c(uri, strchr(uri->str, '?') == nullptr ? '?' : '&');
  g_string_append_printf(uri, "%s=%s", name, value);
}

// Builds a mailto: URI from an emailContent map, or nullptr for null content
// ("open the app", not "compose" — issue #18 semantics, same as other platforms).
static gchar* build_mailto_uri(FlValue* content) {
  if (content == nullptr || fl_value_get_type(content) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  g_autofree gchar* to = joined_escaped_list(content, "to");
  g_autofree gchar* cc = joined_escaped_list(content, "cc");
  g_autofree gchar* bcc = joined_escaped_list(content, "bcc");
  g_autofree gchar* subject = escaped_string(content, "subject");
  g_autofree gchar* body = escaped_string(content, "body");

  g_autoptr(GString) uri = g_string_new("mailto:");
  if (to != nullptr) g_string_append(uri, to);
  append_query(uri, "cc", cc);
  append_query(uri, "bcc", bcc);
  append_query(uri, "subject", subject);
  append_query(uri, "body", body);
  return g_strdup(uri->str);
}

// Caller owns the list: g_list_free_full(list, g_object_unref).
static GList* mail_app_infos() {
  return g_app_info_get_all_for_type(kMailtoType);
}

static GAppInfo* default_mail_app() {
  return g_app_info_get_default_for_uri_scheme("mailto");
}

// name/id/icon/isDefault map matching the channel contract. Icons from
// .desktop files are theme references, not files — returned as null like iOS.
static FlValue* mail_app_to_value(GAppInfo* app, GAppInfo* default_app) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "name",
      fl_value_new_string(g_app_info_get_display_name(app)));
  fl_value_set_string_take(map, "id",
      fl_value_new_string(g_app_info_get_id(app)));
  fl_value_set_string_take(map, "icon", fl_value_new_null());
  fl_value_set_string_take(map, "isDefault",
      fl_value_new_bool(default_app != nullptr && g_app_info_equal(app, default_app)));
  return map;
}

static FlValue* get_mail_apps_value() {
  g_autoptr(GAppInfo) default_app = default_mail_app();
  GList* apps = mail_app_infos();
  FlValue* list = fl_value_new_list();
  for (GList* l = apps; l != nullptr; l = l->next) {
    fl_value_append_take(list, mail_app_to_value(G_APP_INFO(l->data), default_app));
  }
  g_list_free_full(apps, g_object_unref);
  return list;
}

static GAppInfo* find_mail_app(const gchar* app_id) {
  GList* apps = mail_app_infos();
  GAppInfo* found = nullptr;
  for (GList* l = apps; l != nullptr; l = l->next) {
    GAppInfo* app = G_APP_INFO(l->data);
    if (g_strcmp0(g_app_info_get_id(app), app_id) == 0) {
      found = G_APP_INFO(g_object_ref(app));
      break;
    }
  }
  g_list_free_full(apps, g_object_unref);
  return found;
}

// Launches [app] with the mailto URI (compose), or bare (inbox / main window)
// when uri is nullptr.
static gboolean launch_mail_app(GAppInfo* app, const gchar* uri) {
  if (uri == nullptr) {
    return g_app_info_launch(app, nullptr, nullptr, nullptr);
  }
  GList* uris = g_list_append(nullptr, const_cast<gchar*>(uri));
  gboolean ok = g_app_info_launch_uris(app, uris, nullptr, nullptr);
  g_list_free(uris);
  return ok;
}

static FlMethodResponse* open_mail_app(FlValue* args) {
  g_autofree gchar* uri = build_mailto_uri(args);
  g_autoptr(FlValue) result = fl_value_new_map();
  g_autoptr(FlValue) options = get_mail_apps_value();

  g_autoptr(GAppInfo) app = default_mail_app();
  if (app == nullptr && fl_value_get_length(options) > 0) {
    // No default registered in mimeapps.list — fall back to the first handler.
    GList* apps = mail_app_infos();
    app = G_APP_INFO(g_object_ref(apps->data));
    g_list_free_full(apps, g_object_unref);
  }

  // Linux has an authoritative system default (mimeapps.list), so open it
  // directly — same default-first behavior as Android and macOS.
  gboolean did_open = app != nullptr && launch_mail_app(app, uri);
  fl_value_set_string_take(result, "didOpen", fl_value_new_bool(did_open));
  fl_value_set_string_take(result, "canOpen", fl_value_new_bool(app != nullptr));
  fl_value_set_string(result, "options", options);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* open_specific_mail_app(FlValue* args) {
  FlValue* app_id_value =
      args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
          ? fl_value_lookup_string(args, "appId")
          : nullptr;
  gboolean ok = FALSE;
  if (app_id_value != nullptr &&
      fl_value_get_type(app_id_value) == FL_VALUE_TYPE_STRING) {
    g_autoptr(GAppInfo) app = find_mail_app(fl_value_get_string(app_id_value));
    if (app != nullptr) {
      g_autofree gchar* uri =
          build_mailto_uri(fl_value_lookup_string(args, "emailContent"));
      ok = launch_mail_app(app, uri);
    }
  }
  g_autoptr(FlValue) result = fl_value_new_bool(ok);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* compose_email(FlValue* args) {
  g_autofree gchar* uri = build_mailto_uri(args);
  gboolean ok =
      uri != nullptr && g_app_info_launch_default_for_uri(uri, nullptr, nullptr);
  g_autoptr(FlValue) result = fl_value_new_bool(ok);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_mail_app_available() {
  g_autoptr(GAppInfo) app = default_mail_app();
  gboolean available = app != nullptr;
  if (!available) {
    GList* apps = mail_app_infos();
    available = apps != nullptr;
    g_list_free_full(apps, g_object_unref);
  }
  g_autoptr(FlValue) result = fl_value_new_bool(available);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void open_mail_launcher_plugin_handle_method_call(
    OpenMailLauncherPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getMailApps") == 0) {
    g_autoptr(FlValue) apps = get_mail_apps_value();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(apps));
  } else if (strcmp(method, "openMailApp") == 0) {
    response = open_mail_app(args);
  } else if (strcmp(method, "openSpecificMailApp") == 0) {
    response = open_specific_mail_app(args);
  } else if (strcmp(method, "composeEmail") == 0) {
    response = compose_email(args);
  } else if (strcmp(method, "isMailAppAvailable") == 0) {
    response = is_mail_app_available();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void open_mail_launcher_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(open_mail_launcher_plugin_parent_class)->dispose(object);
}

static void open_mail_launcher_plugin_class_init(OpenMailLauncherPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = open_mail_launcher_plugin_dispose;
}

static void open_mail_launcher_plugin_init(OpenMailLauncherPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  OpenMailLauncherPlugin* plugin = OPEN_MAIL_LAUNCHER_PLUGIN(user_data);
  open_mail_launcher_plugin_handle_method_call(plugin, method_call);
}

void open_mail_launcher_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  OpenMailLauncherPlugin* plugin = OPEN_MAIL_LAUNCHER_PLUGIN(
      g_object_new(open_mail_launcher_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "open_mail_launcher",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
