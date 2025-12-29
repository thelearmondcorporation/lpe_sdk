// Minimal Linux plugin registration stub for lpe_sdk.
#include "flutter_linux/flutter_linux.h"
#include <gtk/gtk.h>

static void lpe_sdk_plugin_handle_method_call(FlMethodChannel* channel,
                                              FlMethodCall* method_call,
                                              gpointer user_data) {
  // Respond NotImplemented for all methods.
  FlMethodResponse* response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void lpe_sdk_plugin_dispose(gpointer data) {}

static void lpe_sdk_plugin_class_init(gpointer klass) {}

static void lpe_sdk_plugin_init(gpointer instance) {}

void lpe_sdk_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "lpe_sdk/native_pay",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));

  g_signal_connect(channel, "method-call", G_CALLBACK(lpe_sdk_plugin_handle_method_call), nullptr);

  g_object_unref(channel);
}
