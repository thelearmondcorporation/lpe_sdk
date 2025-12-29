import FlutterMacOS
import Cocoa

public class LearmondSDKNativePayPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "lpe_sdk/native_pay", binaryMessenger: registrar.messenger)
    let instance = LearmondSDKNativePayPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Minimal stub: forward unsupported methods to FlutterMethodNotImplemented.
    // Full native Apple Pay integration can be added here mirroring iOS implementation.
    result(FlutterMethodNotImplemented)
  }
}
