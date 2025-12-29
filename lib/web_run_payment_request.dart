import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:paysheet/paysheet.dart'
    show showLpePaysheet, StripePaymentResult;
// `dart:html` is used intentionally for the web helper. Suppress the analyzer
// informational deprecation here because this code only runs on the web.
// ignore: deprecated_member_use
import 'src/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'src/js_util_stub.dart' if (dart.library.js) 'dart:js_util' as js_util;

/// Helper for web to run a payment flow.
/// NOTE: `showLpePaysheet` uses `webview_flutter` (which requires a
/// platform implementation). On web browsers we cannot construct that
/// WebView controller, so prefer a native web flow. If a full PaymentRequest
/// implementation is not available, we return a friendly failure instead of
/// crashing.
Future<void> runWebPaymentRequest(
  BuildContext context, {
  required String publishableKey,
  String? clientSecret,
  required String method,
  required String amount,
  Map<String, dynamic>? merchantArgs,
  void Function(StripePaymentResult)? onResult,
  Future<void> Function()? onPay,
}) async {
  if (!kIsWeb) {
    await showLpePaysheet(
      context,
      publishableKey: publishableKey,
      clientSecret: clientSecret,
      method: method,
      amount: amount,
      merchantArgs: merchantArgs,
      mountOnShow: true,
      enableStripeJs: true,
      onPay: onPay,
      onResult: onResult,
    );
    return;
  }

  // Running on web: attempt PaymentRequest if available (Chrome/Edge),
  // otherwise fall back to a friendly error. We deliberately avoid
  // instantiating WebViewController to prevent the platform assertion.
  try {
    final hasPR = js_util.hasProperty(html.window, 'PaymentRequest') ||
        (js_util.hasProperty(html.window, 'google') &&
            js_util.hasProperty(
                js_util.getProperty(html.window, 'google'), 'payments'));
    if (hasPR) {
      // Delegate to the platform shim (MethodChannel) which on web is
      // implemented by `lpe_sdk_web.dart`. This allows the existing
      // web PaymentRequest / Google Pay logic to run instead of returning
      // a not-implemented error.
      try {
        // parsed amount available if needed: final double amt = double.tryParse(amount) ?? 0.0;

        final StripePaymentResult? result = await showLpePaysheet(
          context,
          publishableKey: publishableKey,
          clientSecret: clientSecret,
          method: method,
          amount: amount,
          merchantArgs: merchantArgs,
          mountOnShow: true,
          enableStripeJs: true,
          onPay: onPay,
        );
        onResult?.call(result ??
            const StripePaymentResult(
                success: false,
                error: 'Payment request failed',
                errorMessage: 'Payment request failed'));
        return;
      } catch (e) {
        final err = e.toString();
        onResult?.call(StripePaymentResult(
          success: false,
          error: 'Payment request failed',
          errorMessage: err,
        ));
        return;
      }
    }
  } catch (_) {}

  // Generic web fallback: show a dialog and return an error result.
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Web Payment Unavailable'),
      content: const Text(
          'This browser does not support the built-in web payment flow. Please try Chrome or use the native app.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
      ],
    ),
  );

  const fallback = StripePaymentResult(
    success: false,
    error: 'web_payment_unavailable',
    errorMessage:
        'Web payment is unavailable in this browser. Try Chrome or the native app.',
  );
  onResult?.call(fallback);
}
