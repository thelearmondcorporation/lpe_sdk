import 'package:flutter/services.dart';
import 'package:paysheet/paysheet.dart' show StripePaymentResult;

/// Dart wrapper for the platform native-pay bridge (`lpe_sdk/native_pay`).
/// Calls the platform implementation and normalizes the result into a
/// `StripePaymentResult` instance used throughout the SDK.
class LearmondNativePay {
  static const MethodChannel _channel = MethodChannel('lpe_sdk/native_pay');

  /// Present the native pay sheet on the device (Apple/Google) via
  /// platform channels. The `args` map should include at least:
  /// - `method`: 'apple_pay' | 'google_pay'
  /// - `amountCents`: integer amount in cents
  /// - `currency`: currency code
  /// - `merchantArgs`: normalized merchant args map
  /// Other fields (publishableKey, merchantId) are optional and forwarded.
  static Future<StripePaymentResult> showNativePay(
      Map<String, dynamic> args) async {
    try {
      final dynamic resp =
          await _channel.invokeMethod('presentNativePay', args);
      if (resp is Map) {
        final success = resp['success'] == true;
        final error = resp['error']?.toString();
        final errorMessage = resp['errorMessage']?.toString();
        return StripePaymentResult(
          success: success,
          error: error,
          errorMessage: errorMessage,
        );
      }
      return const StripePaymentResult(
          success: false, error: 'No response', errorMessage: 'No response');
    } on PlatformException catch (e) {
      return StripePaymentResult(
          success: false, error: e.code, errorMessage: e.message);
    } catch (e) {
      return StripePaymentResult(
          success: false,
          error: 'Native pay error.',
          errorMessage: e.toString());
    }
  }
}
