import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'merchant_arg_builder.dart';
import 'summary_line_item.dart';

/// Clean, minimal paysheet implementation for the SDK.

class StripePaymentResult {
  final bool success;
  final String? status;
  final String? paymentIntentId;
  final String? error;
  final String? errorMessage;
  final dynamic rawResult;

  const StripePaymentResult({
    required this.success,
    this.status,
    this.paymentIntentId,
    this.error,
    this.errorMessage,
    this.rawResult,
  });
}

int amountToCents(double amount) => (amount * 100).round();

Map<String, dynamic> computeEffectiveMerchantArgs({
  Map<String, dynamic>? merchantArgs,
  String? amount,
  String? merchantId,
  String? merchantName,
  String? merchantInfo,
  List<SummaryLineItem>? summaryItems,
  String? currency,
}) {
  if (merchantArgs != null) return merchantArgs;
  if (amount != null) {
    final m = buildMerchantArgsFromAmount(
      amount: amount,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      extraSummaryItems: summaryItems,
    );
    return m ?? <String, dynamic>{};
  }
  final m2 = buildMerchantArgs(
    merchantId: merchantId,
    merchantName: merchantName,
    merchantInfo: merchantInfo,
    summaryItems: summaryItems,
  );
  return m2 ?? <String, dynamic>{};
}

Future<StripePaymentResult?> showLpePaysheet(
  BuildContext context, {
  required String publishableKey,
  String? clientSecret,
  required String method,
  String? amount,
  Map<String, dynamic>? merchantArgs,
  bool mountOnShow = false,
  bool enableStripeJs = false,
  void Function(StripePaymentResult)? onResult,
}) {
  return showModalBottomSheet<StripePaymentResult>(
    context: context,
    isScrollControlled: true,
    builder: (modalContext) {
      return SizedBox(
        height: 420,
        child: StripeWebview(
          publishableKey: publishableKey,
          clientSecret: clientSecret,
          method: method,
          merchantArgs: merchantArgs,
          mountOnShow: mountOnShow,
          enableStripeJs: enableStripeJs,
          onMessage: (msg) {
            try {
              final t = msg['type']?.toString();
              if (t == 'card_token_result' ||
                  t == 'payment_result' ||
                  t == 'plain_card_entered') {
                final res = msg['result'] ?? msg['card'] ?? msg;
                final r = StripePaymentResult(success: true, rawResult: res);
                onResult?.call(r);
                Navigator.of(modalContext).pop(r);
                return;
              }
              if (t == 'error') {
                final rawErr = msg['error']?.toString();
                final friendly = _formatWebError(rawErr);
                final r = StripePaymentResult(
                  success: false,
                  error: rawErr,
                  errorMessage: friendly,
                  rawResult: msg,
                );
                onResult?.call(r);
                Navigator.of(modalContext).pop(r);
                return;
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('showLpePaysheet message handler error: $e');
              }
            }
          },
        ),
      );
    },
  );
}

String _formatWebError(String? err) {
  if (err == null) return 'An unknown error occurred.';
  final s = err.trim();
  // Map known codes to user-friendly sentences
  const Map<String, String> map = {
    'unsupported_method': 'This payment method is not supported.',
    'stripe_load_error': 'Failed to load Stripe.js.',
    'stripe_error': 'A Stripe error occurred.',
    'native_pay_not_implemented':
        'Native pay is not implemented on this platform.',
  };
  if (map.containsKey(s)) return map[s]!;
  // If it looks like a snake_case code, convert to sentence
  if (RegExp(r'^[a-z0-9_]+$').hasMatch(s)) {
    final spaced = s.replaceAll('_', ' ');
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}.';
  }
  // Otherwise assume it's already a readable message
  return s;
}

/// Backwards-compatible shim classes (small surface area)
class LearmondNativePay {
  static const MethodChannel _channel = MethodChannel('lpe/native_pay');

  /// Presents native device pay UI using platform plugin and returns a [StripePaymentResult].
  static Future<StripePaymentResult> showNativePay(
      Map<String, dynamic> args) async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('presentNativePay', args);
      if (res == null) {
        return const StripePaymentResult(
            success: false,
            error: 'no_response',
            errorMessage: 'No response from native pay');
      }

      final bool success = res['success'] == true;
      final String? error = res['error']?.toString();
      final Map<String, dynamic>? raw =
          res['raw'] != null ? Map<String, dynamic>.from(res['raw']) : null;
      final friendly = _formatWebError(error);
      return StripePaymentResult(
          success: success,
          error: error,
          errorMessage: friendly,
          rawResult: raw);
    } on PlatformException catch (e) {
      final msg = e.message?.toString();
      return StripePaymentResult(
          success: false, error: msg, errorMessage: _formatWebError(msg));
    } catch (e) {
      final s = e.toString();
      return StripePaymentResult(
          success: false, error: s, errorMessage: _formatWebError(s));
    }
  }
}

class LearmondPaySheet {
  static Future<StripePaymentResult> show({
    required BuildContext context,
    required String publishableKey,
    required String clientSecret,
    Map<String, dynamic>? merchantArgs,
    String method = 'card',
    String? title,
    String? amount,
    String? buttonLabel,
    bool mountOnShow = false,
    bool enableStripeJs = false,
  }) async {
    final res = await showLpePaysheet(
      context,
      publishableKey: publishableKey,
      clientSecret: clientSecret,
      method: method,
      amount: amount,
      merchantArgs: merchantArgs,
      mountOnShow: mountOnShow,
      enableStripeJs: enableStripeJs,
    );
    return res ?? const StripePaymentResult(success: false, error: 'dismissed');
  }
}

/// Top-level helper to invoke native-pay integrations. This wraps the
/// platform shim `LearmondNativePay.showNativePay` and normalizes the
/// arguments used by the button widgets.
Future<void> showLpeNativePay(
  BuildContext context, {
  required String method,
  String? publishableKey,
  String? merchantId,
  String? googleGatewayMerchantId,
  Map<String, dynamic>? merchantArgsParam,
  required String amount,
  required String currency,
  required void Function(StripePaymentResult) onResult,
}) async {
  final args = <String, dynamic>{
    'method': method,
    if (publishableKey != null) 'publishableKey': publishableKey,
    if (merchantId != null) 'merchantId': merchantId,
    if (googleGatewayMerchantId != null)
      'googleGatewayMerchantId': googleGatewayMerchantId,
    'merchantArgs': merchantArgsParam ?? {},
    'amount': amount,
    'currency': currency,
  };

  try {
    final res = await LearmondNativePay.showNativePay(args);
    // Ensure friendly message available
    final propagated = StripePaymentResult(
      success: res.success,
      status: res.status,
      paymentIntentId: res.paymentIntentId,
      error: res.error,
      errorMessage: res.errorMessage ?? _formatWebError(res.error),
      rawResult: res.rawResult,
    );
    onResult(propagated);
  } catch (e) {
    onResult(const StripePaymentResult(
        success: false,
        error: 'native_pay_error',
        errorMessage: 'An error occurred while invoking native pay.'));
  }
}

class StripeWebview extends StatefulWidget {
  final String publishableKey;
  final String? clientSecret;
  final String method;
  final Map<String, dynamic>? merchantArgs;
  final void Function(Map<String, dynamic>) onMessage;
  final void Function(WebViewController)? onWebViewCreated;
  final bool mountOnShow;
  final bool enableStripeJs;

  const StripeWebview({
    Key? key,
    required this.publishableKey,
    this.clientSecret,
    required this.method,
    this.merchantArgs,
    this.onWebViewCreated,
    this.onMessage = _noopOnMessage,
    this.mountOnShow = false,
    this.enableStripeJs = false,
  }) : super(key: key);

  static void _noopOnMessage(Map<String, dynamic> _) {}

  @override
  State<StripeWebview> createState() => _StripeWebviewState();
}

class _StripeWebviewState extends State<StripeWebview> {
  String _buildHtml() {
    final publishableKeyEsc = jsonEncode(widget.publishableKey);
    final clientSecretEsc = jsonEncode(widget.clientSecret ?? '');
    final merchantArgsEsc = jsonEncode(widget.merchantArgs ?? {});
    final methodEsc = jsonEncode(widget.method);
    final buttonLabel = jsonEncode('Pay');

    return '''<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 12px; }
      #element-root { min-height: 180px; margin-bottom: 12px; }
      #action { padding: 10px 20px; border-radius: 20px; background: #2196F3; color: white; border: none; cursor: pointer; }
      #out { margin-top: 8px; color: #666; }
    </style>
    <script>
      function send(msg) { try { StripeCallback.postMessage(JSON.stringify(msg)); } catch(e) {} }

      window.STRIPE_PUBLISHABLE_KEY = $publishableKeyEsc;
      window.STRIPE_CLIENT_SECRET = $clientSecretEsc;
      window.MERCHANT_ARGS = $merchantArgsEsc;
      window.__lpe_method = $methodEsc;
      window.__lpe_shouldMount = false;

      window.__lpe_load_stripe = function(){
        if (window.__lpe_load_attempted) return; window.__lpe_load_attempted = true;
        var s = document.createElement('script');
        s.src = 'https://js.stripe.com/v3/'; s.async = true;
        s.onload = function(){ try { if (typeof Stripe === 'function') { window.stripe = Stripe(window.STRIPE_PUBLISHABLE_KEY); send({ type: 'log', action: 'stripe_loaded' }); } } catch(e){ send({ type: 'error', error: String(e) }); } };
        s.onerror = function(e){ send({ type: 'error', action: 'stripe_load_error', error: String(e) }); };
        document.head.appendChild(s);
      };

      function mount() {
        try {
          if (window.__lpe_mounted) return; window.__lpe_mounted = true;
          var root = document.getElementById('element-root'); if (!root) return;
          root.innerHTML = '<div style="padding:12px"><label>Card number</label><input id="card_number" style="width:100%;padding:8px;margin:6px 0;" placeholder="4242 4242 4242 4242"/><div style="display:flex;gap:8px"><input id="card_exp" placeholder="MM/YY" style="flex:1;padding:8px;"/><input id="card_cvc" placeholder="CVC" style="width:100px;padding:8px;"/></div></div>';
          var btn = document.getElementById('action'); if (btn) btn.disabled = false;
          document.getElementById('action').addEventListener('click', function(){
            try {
              var card = { number: document.getElementById('card_number').value, exp: document.getElementById('card_exp').value, cvc: document.getElementById('card_cvc').value };
              send({ type: 'plain_card_entered', card: card });
              var out = document.getElementById('out'); if (out) out.textContent = 'Sent card to app for tokenization';
            } catch(e) { send({ type: 'error', error: String(e) }); }
          });
          send({ type: 'log', action: 'mounted_fallback' });
        } catch(e) { send({ type: 'error', error: String(e) }); }
      }

      window.__lpe_invoke_mount = function(){ try { mount(); } catch(e){ send({ type: 'error', error: String(e) }); } };
      window.__lpe_mount = function(){ window.__lpe_shouldMount = true; if (typeof window.__lpe_invoke_mount === 'function') window.__lpe_invoke_mount(); };
    </script>
  </head>
  <body>
    <div id="element-root"></div>
    <div style="text-align:center"><button id="action" disabled>$buttonLabel</button></div>
    <div id="out"></div>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final htmlData = _buildHtml();
    final controller = WebViewController();

    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.addJavaScriptChannel('StripeCallback', onMessageReceived: (msg) {
      try {
        final decoded = msg.message;
        try {
          final dynamic parsedRaw = jsonDecode(decoded);
          if (parsedRaw is Map) {
            final parsed = Map<String, dynamic>.from(parsedRaw);
            widget.onMessage(parsed);
          } else {
            widget.onMessage({'message': parsedRaw});
          }
        } catch (_) {
          widget.onMessage({'message': decoded});
        }
      } catch (e) {
        if (kDebugMode) debugPrint('StripeCallback parse error: $e');
      }
    });

    controller
        .setNavigationDelegate(NavigationDelegate(onPageFinished: (url) async {
      await Future.delayed(const Duration(milliseconds: 150));
      try {
        final pkLit = jsonEncode(widget.publishableKey);
        final csLit = jsonEncode(widget.clientSecret ?? '');
        final merchantArgsLit = jsonEncode(widget.merchantArgs ?? {});

        await controller
            .runJavaScript('window.STRIPE_PUBLISHABLE_KEY = ' + pkLit + ';');
        await controller
            .runJavaScript('window.STRIPE_CLIENT_SECRET = ' + csLit + ';');
        await controller
            .runJavaScript('window.MERCHANT_ARGS = ' + merchantArgsLit + ';');
        await controller.runJavaScript('window.__lpe_shouldMount = true;');

        try {
          await controller.runJavaScript(
              'if (typeof window.__lpe_load_stripe === "function") { window.__lpe_load_stripe(); }');
        } catch (_) {}

        try {
          await controller.runJavaScript(
              'if (typeof window.__lpe_invoke_mount === "function") { window.__lpe_invoke_mount(); }');
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) debugPrint('StripeWebview onPageFinished error: $e');
      }
    }));

    controller.loadHtmlString(htmlData, baseUrl: 'about:blank');

    if (widget.onWebViewCreated != null) {
      try {
        widget.onWebViewCreated!(controller);
      } catch (_) {}
    }

    return SizedBox(height: 360, child: WebViewWidget(controller: controller));
  }

  @override
  void dispose() {
    super.dispose();
  }
}
