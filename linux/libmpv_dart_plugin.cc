#include "include/libmpv_dart/libmpv_dart_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <locale.h>
#include <cstring>

#include "libmpv_dart_plugin_private.h"

#define LIBMPV_DART_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), libmpv_dart_plugin_get_type(), \
                              LibmpvDartPlugin))

struct _LibmpvDartPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(LibmpvDartPlugin, libmpv_dart_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void libmpv_dart_plugin_handle_method_call(
    LibmpvDartPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void libmpv_dart_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(libmpv_dart_plugin_parent_class)->dispose(object);
}

static void libmpv_dart_plugin_class_init(LibmpvDartPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = libmpv_dart_plugin_dispose;
}

static void libmpv_dart_plugin_init(LibmpvDartPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  LibmpvDartPlugin* plugin = LIBMPV_DART_PLUGIN(user_data);
  libmpv_dart_plugin_handle_method_call(plugin, method_call);
}

void libmpv_dart_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  setlocale(LC_NUMERIC, "C");
  LibmpvDartPlugin* plugin = LIBMPV_DART_PLUGIN(
      g_object_new(libmpv_dart_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "libmpv_dart",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
