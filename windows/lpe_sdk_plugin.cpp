// Minimal Windows plugin registration stub for lpe_sdk.
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace lpe_sdk {

class LpeSdkPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "lpe/native_pay",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue> &call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          result->NotImplemented();
        });

    registrar->AddPlugin(std::make_unique<LpeSdkPlugin>());
  }

  LpeSdkPlugin() {}
  virtual ~LpeSdkPlugin() {}
};

}  // namespace lpe_sdk
