import 'dart:convert';
import 'lpe_sdk_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'merchant_args_controller.dart';
import 'summary_line_item.dart';
import 'merchant_arg_builder.dart';

/// Standard width for all LPE payment buttons.
const double lpeButtonWidth = 110.0;

/// Helper used by public button widgets to compute the effective merchant
/// args for display and for the WebView. It prefers an explicit
/// `merchantArgs` map when provided, otherwise it builds the canonical
/// map from `amount` and other parameters using `buildMerchantArgsFromAmount`.
Map<String, dynamic>? _computeEffectiveMerchantArgs({
  Map<String, dynamic>? merchantArgs,
  required String amount,
  String? merchantId,
  String? merchantName,
  String? merchantInfo,
  List<SummaryLineItem>? summaryItems,
}) {
  return merchantArgs ??
      buildMerchantArgsFromAmount(
        amount: amount,
        merchantId: merchantId,
        merchantName: merchantName,
        merchantInfo: merchantInfo,
        extraSummaryItems: summaryItems,
      );
}

/// Contains the result of a payment attempt, including status, intent ID, error, and raw response.
class StripePaymentResult {
  final bool success;
  final String? status;
  final String? paymentIntentId;
  final String? error;
  final Map<String, dynamic>? rawResult;

  StripePaymentResult({
    required this.success,
    this.status,
    this.paymentIntentId,
    this.error,
    this.rawResult,
  });
}

/// Native-pay helper that delegates Apple/Google Pay to platform code.
class LearmondNativePay {
  static const MethodChannel _channel = MethodChannel('lpe/native_pay');

  /// Presents native device pay UI using platform plugin and returns a [StripePaymentResult].
  static Future<StripePaymentResult> showNativePay(
      Map<String, dynamic> args) async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('presentNativePay', args);
      debugPrint('LPE LearmondNativePay.showNativePay res: $res');
      if (res == null) {
        return StripePaymentResult(success: false, error: 'no_response');
      }

      final bool success = res['success'] == true;
      final String? error = res['error']?.toString();
      final Map<String, dynamic>? raw =
          res['raw'] != null ? Map<String, dynamic>.from(res['raw']) : null;
      return StripePaymentResult(
          success: success, error: error, rawResult: raw);
    } on PlatformException catch (e) {
      return StripePaymentResult(
          success: false, error: e.message ?? e.toString());
    } catch (e) {
      return StripePaymentResult(success: false, error: e.toString());
    }
  }
}

// `SummaryLineItem` moved to `lib/summary_line_item.dart` to avoid circular imports.

/// Static helper to show payment sheet with a single line of code. Supports Stripe elements.
///
/// Usage:
/// ```dart
/// final result = await LearmondPaySheet.show(
///   context: context,
///   publishableKey: 'pk_...',
///   clientSecret: 'pi_..._secret_...',
///   method: 'card', // or 'us_bank', 'apple_pay', 'google_pay'
///   title: 'Pay \$10.00',
/// );
/// if (result.success) {
///   // Payment succeeded
/// }
/// ```
/// Main entry point for showing the Learmond Pay Sheet modal.
///
/// Use [show] to present the payment sheet and handle the result.
class LearmondPaySheet {
  /// Shows a modal bottom sheet with stripe Payment Element.
  /// Returns a [StripePaymentResult] when the sheet is closed.
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
    double initialChildSize = 0.7,
    double minChildSize = 0.4,
    double maxChildSize = 0.95,
  }) async {
    StripePaymentResult? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      isDismissible: false,
      enableDrag: false,
      builder: (modalContext) {
        return _LearmondPaySheetContent(
          publishableKey: publishableKey,
          clientSecret: clientSecret,
          merchantArgs: merchantArgs,
          method: method,
          title: title,
          amount: amount,
          buttonLabel: buttonLabel,
          mountOnShow: mountOnShow,
          enableStripeJs: enableStripeJs,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          onResult: (r) {
            result = r;
          },
        );
      },
    );

    return result ?? StripePaymentResult(success: false, error: 'dismissed');
  }
}

/// A small widget that renders a row/wrap of payment method buttons.
///
/// Use this to let customers show a card / bank / native pay flow with one
/// simple widget. Example:
///
/// LearmondPayButtons(
///   publishableKey: 'pk_test',
///   clientSecret: 'pi_..._secret...',
///   onResult: (res) { /* handle result */ },
/// )
class LearmondPayButtons extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;

  /// Optional Apple Pay merchant id (for example: 'merchant.com.yourdomain').
  ///
  /// When provided, this value will be forwarded to the native bridge when
  /// presenting device pay flows (Apple Pay). You can also pass a merchantId
  /// directly when calling `LearmondNativePay.showNativePay({...})`.
  final String? merchantId; // for Apple Pay
  /// Optional Google Pay gateway merchant id.
  /// When provided it will be forwarded when presenting Google Pay flows.
  final String? googleGatewayMerchantId;

  /// Optional merchant display name to show on native pay sheets (Apple Pay).
  final String? merchantName;

  /// Optional merchant info (one-line) to show beneath the merchant name on native pay sheets.
  final String? merchantInfo;

  /// Optional merchantArgs map that contains merchantName, merchantInfo, summaryItems, merchantId, etc.
  /// If provided, this map will be used as the single source of truth for merchant args
  /// and will override the separate `merchantName`, `merchantInfo`, and `summaryItems` fields.
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;
  final String amount; // e.g. '10.00'
  final String currency;
  final void Function(StripePaymentResult result)? onResult;

  /// When false, the native pay row (Apple Pay / Google Pay) is not rendered.
  final bool showNativePay;
  final ButtonStyle? buttonStyle;

  const LearmondPayButtons({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.merchantId,
    this.merchantArgs,
    this.merchantName,
    this.merchantInfo,
    this.summaryItems,
    this.googleGatewayMerchantId,
    this.amount = '0.00',
    this.currency = 'USD',
    this.onResult,
    this.showNativePay = true,
    this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Centralize merchant-args construction via package helpers so all
    // buttons and native flows use a single source of truth.
    // If the caller provided a complete `merchantArgs` map, prefer it.
    // Otherwise fall back to building merchantArgs from the widget fields
    // using `buildMerchantArgsFromAmount`, which parses `amount` and builds
    // the default Order line to avoid duplicating parsing logic in apps.
    final effectiveMerchantArgs = _computeEffectiveMerchantArgs(
      merchantArgs: merchantArgs,
      amount: amount,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );
    // default style: pill-shaped, modest horizontal padding, and consistent text size
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white, // white buttons
          foregroundColor: Colors.black, // dark text/icons
          elevation: 3,
          shadowColor: Colors.black12,
          minimumSize: const Size(
              56, 40), // smaller consistent height so a third button can fit
        );
    // Use a fixed width for all buttons for visual consistency
    const buttonWidth = lpeButtonWidth;
    const nativeHeight = 40.0;
    // nativeMinWidth is not used here; per-button sizing is handled below
    final nativeSideMargin = nativeHeight * 0.1; // 1/10 of height
    // Explicit two-row layout: row 1 => 3 buttons (card, us_bank, eu_bank); row 2 => 2 buttons (apple_pay, google_pay)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              child: LearmondCardButton(
                publishableKey: publishableKey,
                clientSecret: clientSecret,
                amount: amount,
                onResult: onResult,
                buttonStyle: style,
                merchantArgs: effectiveMerchantArgs,
              ),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: buttonWidth,
              child: LearmondUSBankButton(
                publishableKey: publishableKey,
                clientSecret: clientSecret,
                amount: amount,
                onResult: onResult,
                buttonStyle: style,
                merchantArgs: effectiveMerchantArgs,
              ),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: buttonWidth,
              child: LearmondEUBankButton(
                publishableKey: publishableKey,
                clientSecret: clientSecret,
                amount: amount,
                onResult: onResult,
                buttonStyle: style,
                merchantArgs: effectiveMerchantArgs,
              ),
            ),
          ],
        ),
        if (showNativePay) ...[
          const SizedBox(height: 8.0),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              SizedBox(
                width: lpeButtonWidth,
                child: LearmondApplePayButton(
                  publishableKey: publishableKey,
                  merchantId: merchantId,
                  merchantArgs: effectiveMerchantArgs,
                  amount: amount,
                  currency: currency,
                  onResult: onResult,
                  buttonStyle: style.copyWith(
                    padding: WidgetStateProperty.all(
                        EdgeInsets.symmetric(horizontal: nativeSideMargin)),
                    minimumSize: WidgetStateProperty.all(
                        const Size(lpeButtonWidth, nativeHeight)),
                  ),
                ),
              ),
              SizedBox(
                width: lpeButtonWidth,
                child: LearmondGooglePayButton(
                  publishableKey: publishableKey,
                  googleGatewayMerchantId: googleGatewayMerchantId,
                  merchantArgs: effectiveMerchantArgs,
                  amount: amount,
                  currency: currency,
                  onResult: onResult,
                  buttonStyle: style.copyWith(
                    padding: WidgetStateProperty.all(
                        EdgeInsets.symmetric(horizontal: nativeSideMargin)),
                    minimumSize: WidgetStateProperty.all(
                        const Size(lpeButtonWidth, nativeHeight)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------
// Shared helpers + individual button widgets
// ---------------------------

int _amountToCents(String a) {
  final d = double.tryParse(a.replaceAll(',', '')) ?? 0.0;
  return (d * 100).round();
}

Future<void> _showLpePaysheet(BuildContext context,
    {required String method,
    required String publishableKey,
    required String clientSecret,
    required String amount,
    Map<String, dynamic>? merchantArgs,
    bool mountOnShow = false,
    required void Function(StripePaymentResult)? onResult}) async {
  debugPrint(
      'LPE _showLpePaysheet method=$method publishableKey=$publishableKey clientSecret=$clientSecret amount=$amount merchantArgs=$merchantArgs');
  final res = await LearmondPaySheet.show(
    context: context,
    publishableKey: publishableKey,
    clientSecret: clientSecret,
    method: method,
    mountOnShow: mountOnShow,
    title: method.replaceAll('_', ' ').toUpperCase(),
    amount: amount,
    merchantArgs: merchantArgs,
  );
  debugPrint('LPE _showLpePaysheet result: $res');
  try {
    if (onResult != null) onResult(res);
  } catch (_) {}
}

Future<void> _showLpeNativePay(BuildContext context,
    {required String method,
    String? publishableKey,
    String? merchantId,
    String? googleGatewayMerchantId,
    String? merchantName,
    String? merchantInfo,
    Map<String, dynamic>? merchantArgsParam,
    required String amount,
    required String currency,
    required void Function(StripePaymentResult)? onResult}) async {
  final cents = _amountToCents(amount);
  final args = <String, dynamic>{
    'method': method,
    'amountCents': cents,
    'currency': currency,
  };
  debugPrint(
      'LPE _showLpeNativePay initial args: $args, merchantId=$merchantId, googleGatewayMerchantId=$googleGatewayMerchantId, merchantName=$merchantName, merchantInfo=$merchantInfo, merchantArgsParam=$merchantArgsParam');

  if (method == 'apple_pay' && merchantId != null && merchantId.isNotEmpty) {
    final effectiveMerchant =
        (merchantId.isNotEmpty) ? merchantId : LpeSDKConfig.appleMerchantId;
    if (effectiveMerchant != null && effectiveMerchant.isNotEmpty) {
      args['merchantId'] = effectiveMerchant;
    }
  }

  if (merchantName != null && merchantName.isNotEmpty) {
    args['merchantName'] = merchantName;
  } else if (LpeSDKConfig.defaultMerchantName != null &&
      LpeSDKConfig.defaultMerchantName!.isNotEmpty) {
    args['merchantName'] = LpeSDKConfig.defaultMerchantName;
  }

  if (merchantInfo != null && merchantInfo.isNotEmpty) {
    args['merchantInfo'] = merchantInfo;
  } else if (LpeSDKConfig.defaultMerchantInfo != null &&
      LpeSDKConfig.defaultMerchantInfo!.isNotEmpty) {
    args['merchantInfo'] = LpeSDKConfig.defaultMerchantInfo;
  }

  if (method == 'google_pay') {
    final effectiveGmid =
        (googleGatewayMerchantId != null && googleGatewayMerchantId.isNotEmpty)
            ? googleGatewayMerchantId
            : LpeSDKConfig.googleGatewayMerchantId;
    if (effectiveGmid != null && effectiveGmid.isNotEmpty) {
      args['gatewayMerchantId'] = effectiveGmid;
    }
  }

  // Build a normalized merchantArgs map using the centralized helper.
  final merged = buildMerchantArgs(
    merchantId: args['merchantId'] as String?,
    merchantName: args['merchantName'] as String?,
    merchantInfo: args['merchantInfo'] as String?,
    gatewayMerchantId: args['gatewayMerchantId'] as String?,
    builder: merchantArgsParam,
  );
  if (merged != null && merged.isNotEmpty) {
    args['merchantArgs'] = merged;
  }
  // Include publishableKey if present so native tokenizationSpec can use Stripe gateway
  if (publishableKey != null && publishableKey.isNotEmpty) {
    args['publishableKey'] = publishableKey;
    try {
      final masked = publishableKey.length > 8
          ? publishableKey.substring(0, 4) +
              '...' +
              publishableKey.substring(publishableKey.length - 4)
          : publishableKey;
      debugPrint(
          'LPE _showLpeNativePay publishing publishableKey_masked=$masked');
    } catch (_) {}
  }
  debugPrint('LPE _showLpeNativePay final args: $args');

  final res = await LearmondNativePay.showNativePay(args);
  debugPrint('LPE _showLpeNativePay result: $res');
  try {
    if (onResult != null) onResult(res);
  } catch (_) {}
}

/// Button: Card
class LearmondCardButton extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String amount;
  final void Function(StripePaymentResult)? onResult;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondCardButton({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.amount = '0.00',
    this.onResult,
    this.buttonStyle,
    this.label,
    this.merchantArgs,
    this.merchantName,
    this.merchantInfo,
    this.summaryItems,
  });

  Map<String, dynamic>? _buildMerchantArgs() {
    // Centralize construction via buildMerchantArgs so builder values come from one place.
    final args = buildMerchantArgs(
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
      builder: merchantArgs,
    );
    debugPrint('LPE LearmondCardButton._buildMerchantArgs computed: $args');
    return args;
  }

  @override
  Widget build(BuildContext context) {
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
        );
    return SizedBox(
      width: lpeButtonWidth,
      child: ElevatedButton(
        onPressed: () => _showLpePaysheet(
          context,
          method: 'card',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onResult: (result) {
            onResult?.call(result);
            if (!result.success) {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                  (result.error == 'unsupported_method' || result.error == null)
                      ? 'Unsupported method'
                      : result.error!,
                )),
              );
            }
          },
        ),
        style: style,
        child: Text(label ?? 'Card'),
      ),
    );
  }
}

/// Button: US Bank
class LearmondUSBankButton extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String amount;
  final void Function(StripePaymentResult)? onResult;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondUSBankButton({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.amount = '0.00',
    this.onResult,
    this.buttonStyle,
    this.label,
    this.merchantArgs,
    this.merchantName,
    this.merchantInfo,
    this.summaryItems,
  });

  Map<String, dynamic>? _buildMerchantArgs() {
    final args = buildMerchantArgs(
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
      builder: merchantArgs,
    );
    debugPrint('LPE LearmondUSBankButton._buildMerchantArgs computed: $args');
    return args;
  }

  @override
  Widget build(BuildContext context) {
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
        );
    return SizedBox(
      width: lpeButtonWidth,
      child: ElevatedButton(
        onPressed: () => _showLpePaysheet(
          context,
          method: 'us_bank',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onResult: (result) {
            onResult?.call(result);
            if (!result.success) {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                  (result.error == 'unsupported_method' || result.error == null)
                      ? 'Unsupported method'
                      : result.error!,
                )),
              );
            }
          },
        ),
        style: style,
        child: Text(label ?? 'US Bank'),
      ),
    );
  }
}

/// Button: EU Bank (IBAN)
class LearmondEUBankButton extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String amount;
  final void Function(StripePaymentResult)? onResult;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondEUBankButton({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.amount = '0.00',
    this.onResult,
    this.buttonStyle,
    this.label,
    this.merchantArgs,
    this.merchantName,
    this.merchantInfo,
    this.summaryItems,
  });

  Map<String, dynamic>? _buildMerchantArgs() {
    final args = buildMerchantArgs(
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
      builder: merchantArgs,
    );
    debugPrint('LPE LearmondEUBankButton._buildMerchantArgs computed: $args');
    return args;
  }

  @override
  Widget build(BuildContext context) {
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
        );
    return SizedBox(
      width: lpeButtonWidth,
      child: ElevatedButton(
        onPressed: () => _showLpePaysheet(
          context,
          method: 'eu_bank',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onResult: (result) {
            onResult?.call(result);
            if (!result.success) {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                  (result.error == 'unsupported_method' || result.error == null)
                      ? 'Unsupported method'
                      : result.error!,
                )),
              );
            }
          },
        ),
        style: style,
        child: Text(label ?? 'EU Bank (IBAN)'),
      ),
    );
  }
}

/// Button: Apple Pay
class LearmondApplePayButton extends StatelessWidget {
  final String? publishableKey;
  final String? merchantId;
  final String? merchantName;
  final String? merchantInfo;
  final String amount;
  final String currency;
  final void Function(StripePaymentResult)? onResult;
  final ButtonStyle? buttonStyle;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;

  const LearmondApplePayButton({
    super.key,
    this.publishableKey,
    this.merchantId,
    this.merchantName,
    this.merchantInfo,
    this.amount = '0.00',
    this.currency = 'USD',
    this.onResult,
    this.buttonStyle,
    this.merchantArgs,
    this.summaryItems,
  });

  @override
  Widget build(BuildContext context) {
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
        );
    return SizedBox(
      width: lpeButtonWidth,
      child: ElevatedButton(
        onPressed: () {
          final margs = buildMerchantArgs(
            merchantId: merchantId,
            merchantName: merchantName,
            merchantInfo: merchantInfo,
            summaryItems: summaryItems,
            builder: merchantArgs,
          );
          _showLpeNativePay(
            context,
            method: 'apple_pay',
            publishableKey: publishableKey,
            merchantId: merchantId,
            merchantArgsParam: margs,
            amount: amount,
            currency: currency,
            onResult: (result) {
              onResult?.call(result);
              if (!result.success) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                      content: Text(
                    (result.error == 'unsupported_method' ||
                            result.error == null)
                        ? 'Unsupported method'
                        : result.error!,
                  )),
                );
              }
            },
          );
        },
        style: style,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
                offset: const Offset(0, -2),
                child: const Icon(Icons.apple, size: 20)),
            Transform.translate(
                offset: const Offset(-1, 0), child: const Text('Pay')),
          ],
        ),
      ),
    );
  }
}

/// Button: Google Pay
class LearmondGooglePayButton extends StatelessWidget {
  final String? publishableKey;
  final String? googleGatewayMerchantId;
  final String? merchantName;
  final String? merchantInfo;
  final String amount;
  final String currency;
  final void Function(StripePaymentResult)? onResult;
  final ButtonStyle? buttonStyle;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;

  const LearmondGooglePayButton({
    super.key,
    this.publishableKey,
    this.googleGatewayMerchantId,
    this.merchantName,
    this.merchantInfo,
    this.amount = '0.00',
    this.currency = 'USD',
    this.onResult,
    this.buttonStyle,
    this.merchantArgs,
    this.summaryItems,
  });

  @override
  Widget build(BuildContext context) {
    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
        );
    return SizedBox(
      width: lpeButtonWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 40),
        child: ElevatedButton(
          onPressed: () {
            final margs = buildMerchantArgs(
              gatewayMerchantId: googleGatewayMerchantId,
              merchantName: merchantName,
              merchantInfo: merchantInfo,
              summaryItems: summaryItems,
              builder: merchantArgs,
            );
            _showLpeNativePay(
              context,
              method: 'google_pay',
              publishableKey: publishableKey,
              googleGatewayMerchantId: googleGatewayMerchantId,
              merchantArgsParam: margs,
              amount: amount,
              currency: currency,
              onResult: (result) {
                onResult?.call(result);
                if (!result.success) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                      (result.error == 'unsupported_method' ||
                              result.error == null)
                          ? 'Unsupported method'
                          : result.error!,
                    )),
                  );
                }
              },
            );
          },
          style: style,
          child: const Center(
            child: Image(
              image: AssetImage('static/assets/GPay_Acceptance_Mark_800.png',
                  package: 'lpe_sdk'),
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout helper that arranges the individual buttons using the same sizing
/// and spacing rules as `LearmondPayButtons` so apps can embed the individual
/// components while preserving a consistent appearance.
class LearmondIndividualButtons extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String? merchantId;
  final String? googleGatewayMerchantId;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;
  final String amount;
  final String currency;
  final void Function(StripePaymentResult result)? onResult;
  final ButtonStyle? buttonStyle;

  const LearmondIndividualButtons({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.merchantId,
    this.googleGatewayMerchantId,
    this.merchantArgs,
    this.merchantName,
    this.merchantInfo,
    this.summaryItems,
    this.amount = '0.00',
    this.currency = 'USD',
    this.onResult,
    this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0 * 2; // parent content padding on both sides
    const spacing = 8.0; // spacing between buttons
    final availableWidthForThree =
        screenWidth - horizontalPadding - (spacing * 2); // gaps between 3 items
    var buttonWidthThree = availableWidthForThree / 3.0;
    // clamp sensible min/max values
    if (buttonWidthThree < 88.0) {
      buttonWidthThree = 88.0;
    }
    if (buttonWidthThree > 360.0) {
      buttonWidthThree = 360.0;
    }

    // Native-pay sizing: ensure minimums required by design
    final nativeHeight = 40.0;
    final nativeMinWidth = buttonWidthThree < 100.0 ? 100.0 : buttonWidthThree;
    final nativeSideMargin = nativeHeight * 0.1; // 1/10 of height

    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white, // white buttons
          foregroundColor: Colors.black, // dark text/icons
          elevation: 3,
          shadowColor: Colors.black12,
          minimumSize: const Size(56, 40),
        );

    // Build merchant args: prefer the explicit map passed by the caller,
    // otherwise build it from the `amount` and optional `summaryItems`.
    final effectiveMerchantArgs = _computeEffectiveMerchantArgs(
      merchantArgs: merchantArgs,
      amount: amount,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // left (card)
            Expanded(
              flex: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: buttonWidthThree,
                    maxWidth: buttonWidthThree * 1.2),
                child: LearmondCardButton(
                  publishableKey: publishableKey,
                  clientSecret: clientSecret,
                  amount: amount,
                  onResult: onResult,
                  buttonStyle: style,
                  merchantArgs: effectiveMerchantArgs,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // middle (us bank)
            Expanded(
              flex: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: buttonWidthThree,
                    maxWidth: buttonWidthThree * 1.2),
                child: LearmondUSBankButton(
                  publishableKey: publishableKey,
                  clientSecret: clientSecret,
                  amount: amount,
                  onResult: onResult,
                  buttonStyle: style,
                  merchantArgs: effectiveMerchantArgs,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // right (eu bank) - give extra flex so it doesn't wrap
            Expanded(
              flex: 2,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: buttonWidthThree * 1.2),
                child: LearmondEUBankButton(
                  publishableKey: publishableKey,
                  clientSecret: clientSecret,
                  amount: amount,
                  onResult: onResult,
                  buttonStyle: style,
                  merchantArgs: effectiveMerchantArgs,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            SizedBox(
              width: nativeMinWidth,
              child: LearmondApplePayButton(
                merchantId: merchantId,
                merchantArgs: effectiveMerchantArgs,
                amount: amount,
                currency: currency,
                onResult: onResult,
                buttonStyle: style.copyWith(
                  padding: WidgetStateProperty.all(
                      EdgeInsets.symmetric(horizontal: nativeSideMargin)),
                  minimumSize: WidgetStateProperty.all(
                      Size(nativeMinWidth, nativeHeight)),
                ),
              ),
            ),
            SizedBox(
              width: nativeMinWidth,
              child: LearmondGooglePayButton(
                googleGatewayMerchantId: googleGatewayMerchantId,
                merchantArgs: effectiveMerchantArgs,
                amount: amount,
                currency: currency,
                onResult: onResult,
                buttonStyle: style.copyWith(
                  padding: WidgetStateProperty.all(
                      EdgeInsets.symmetric(horizontal: nativeSideMargin)),
                  minimumSize: WidgetStateProperty.all(
                      Size(nativeMinWidth, nativeHeight)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Internal StatefulWidget to properly manage WebView lifecycle
class _LearmondPaySheetContent extends StatefulWidget {
  final String publishableKey;
  final String clientSecret;
  final Map<String, dynamic>? merchantArgs;
  final String method;
  final String? title;
  final String? amount;
  final String? buttonLabel;
  final bool mountOnShow;
  final bool enableStripeJs;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final void Function(StripePaymentResult) onResult;

  const _LearmondPaySheetContent({
    Key? key,
    required this.publishableKey,
    required this.clientSecret,
    this.merchantArgs,
    required this.method,
    this.title,
    this.amount,
    this.buttonLabel,
    this.mountOnShow = false,
    this.enableStripeJs = false,
    this.initialChildSize = 0.7,
    this.minChildSize = 0.4,
    this.maxChildSize = 0.95,
    required this.onResult,
  }) : super(key: key);

  @override
  State<_LearmondPaySheetContent> createState() =>
      _LearmondPaySheetContentState();
}

class _LearmondPaySheetContentState extends State<_LearmondPaySheetContent> {
  InAppWebViewController? _webViewController;
  bool _showWebView = true;
  Map<String, dynamic>? _effectiveMerchantArgs;
  // Merchant args are server-side only; display read-only preview in the sheet.

  @override
  void initState() {
    super.initState();
    // Normalize merchantArgs from the provided map; editing is not allowed in UI.
    _effectiveMerchantArgs =
        MerchantArgsController.fromMap(widget.merchantArgs).toMap();
  }

  Future<void> _closeModal(StripePaymentResult result) async {
    if (!mounted) return;
    setState(() {
      _showWebView = false;
    });
    // Surface the result to the caller before tearing down the WebView/modal.
    try {
      widget.onResult(result);
    } catch (_) {}

    // Try to stop any ongoing loads
    try {
      await _webViewController?.stopLoading();
    } catch (_) {}

    // Give Flutter time to remove the WebView from the tree
    await Future.delayed(const Duration(milliseconds: 300));

    // Now pop the modal
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    if (kDebugMode) {
      debugPrint('LearmondPaySheet msg: $msg');
    }
    final type = msg['type'] ?? msg['event'];

    // Surface canMakePayment result back to Flutter as an error result when false
    if (type == 'canMakePayment') {
      final res = msg['result'];
      if (res == null || res == false) {
        widget.onResult(StripePaymentResult(
          success: false,
          error: 'canMakePayment:false',
          rawResult: msg,
        ));
      } else {
        // Send an informational message via onResult so caller can inspect
        widget.onResult(StripePaymentResult(
          success: false,
          status: 'canMakePayment:true',
          rawResult: msg,
        ));
      }
      return;
    }

    if (type == 'payment_confirm_result' || type == 'card_confirm_result') {
      final res = msg['result'];
      final pi =
          res is Map ? (res['paymentIntent'] ?? res['payment_intent']) : null;
      final status = (pi is Map ? pi['status'] : null) ??
          (res is Map ? res['status'] : null);
      final piId = pi is Map ? pi['id'] : null;

      if (status == 'succeeded' ||
          status == 'requires_capture' ||
          status == 'processing') {
        _closeModal(StripePaymentResult(
          success: true,
          status: status,
          paymentIntentId: piId,
          rawResult: msg,
        ));
      } else {
        // Don't auto-close on failed status, just update result
        widget.onResult(StripePaymentResult(
          success: false,
          status: status,
          paymentIntentId: piId,
          rawResult: msg,
        ));
      }
    } else if (type == 'payment_method_created') {
      _closeModal(StripePaymentResult(
        success: true,
        status: 'payment_method_created',
        rawResult: msg,
      ));
    } else if (type == 'bank_result' || type == 'payment_request_result') {
      _closeModal(StripePaymentResult(
        success: true,
        status: type,
        rawResult: msg,
      ));
    } else if (type == 'error' || msg['error'] != null) {
      widget.onResult(StripePaymentResult(
        success: false,
        error: msg['error']?.toString() ?? 'Unknown error',
        rawResult: msg,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title ??
                            widget.method.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _closeModal(StripePaymentResult(
                            success: false, error: 'cancelled'));
                      },
                    ),
                  ],
                ),
              ),

              // Merchant args preview (read-only — merchantArgs are server-side)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      (_effectiveMerchantArgs != null &&
                              (_effectiveMerchantArgs!['merchantName']
                                      as String?) !=
                                  null &&
                              (_effectiveMerchantArgs!['merchantName']
                                      as String)
                                  .isNotEmpty)
                          ? (_effectiveMerchantArgs!['merchantName'] as String)
                          : (LpeSDKConfig.defaultMerchantName ?? 'Source'),
                    ),
                    subtitle: (_effectiveMerchantArgs != null &&
                            (_effectiveMerchantArgs!['merchantInfo']
                                    as String?) !=
                                null &&
                            (_effectiveMerchantArgs!['merchantInfo'] as String)
                                .isNotEmpty)
                        ? Text(
                            _effectiveMerchantArgs!['merchantInfo'] as String)
                        : null,
                  ),
                ),
              ),

              // Stripe WebView - wrapped in visibility check
              Expanded(
                child: _showWebView
                    ? StripeWebview(
                        publishableKey: widget.publishableKey,
                        clientSecret: widget.clientSecret,
                        merchantArgs:
                            _effectiveMerchantArgs ?? widget.merchantArgs,
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                        },
                        method: widget.method,
                        buttonLabel: widget.buttonLabel,
                        mountOnShow: widget.mountOnShow,
                        enableStripeJs: widget.enableStripeJs,
                        onMessage: _handleMessage,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A lightweight widget that mounts Stripe Elements (card / bank / payment
/// request) in an in-app WebView. It loads a small local HTML page that
/// includes Stripe.js and mounts the requested element using the provided
/// `publishableKey` and `clientSecret` (where applicable).
///
/// Communication back to Flutter is done via the JS handler `window.flutter_inappwebview.callHandler('stripeCallback', {...})`.
class StripeWebview extends StatefulWidget {
  final String publishableKey;
  final String? clientSecret; // optional for PaymentIntent flows
  final String
      method; // 'card', 'us_bank', 'eu_bank', 'apple_pay', 'google_pay'
  final String? buttonLabel; // custom button text (default: 'Pay')
  final Map<String, dynamic>? merchantArgs;
  final void Function(Map<String, dynamic>) onMessage;
  final void Function(InAppWebViewController)? onWebViewCreated;
  final bool mountOnShow;

  /// When true, the page will attempt to load Stripe.js and mount Elements.
  /// Default is false to avoid unstable behavior in embedded WebViews.
  final bool enableStripeJs;

  const StripeWebview(
      {Key? key,
      required this.publishableKey,
      this.merchantArgs,
      this.clientSecret,
      required this.method,
      this.buttonLabel,
      this.mountOnShow = false,
      this.enableStripeJs = false,
      required this.onMessage,
      this.onWebViewCreated})
      : super(key: key);

  @override
  State<StripeWebview> createState() => _StripeWebviewState();
}

class _StripeWebviewState extends State<StripeWebview> {
  String _buildHtml() {
    // Basic HTML that loads Stripe.js and mounts elements based on `method`.
    // It uses a small JS bridge to post events back to Flutter.
    // The publishable key is passed directly from Flutter.
    // Encode runtime values safely for embedding into inline JS.
    // Use jsonEncode then sanitize sequences that can break HTML/JS when
    // embedded in <script> tags (notably '</' which can close scripts and
    // U+2028/U+2029 which are valid in JSON but illegal in JS string literals).
    String _jsSanitize(String s) {
      return s
          .replaceAll('\u2028', '\\u2028')
          .replaceAll('\u2029', '\\u2029')
          .replaceAll('</', '<\\/');
    }

    final pkJs = _jsSanitize(jsonEncode(widget.publishableKey));
    final csJs = widget.clientSecret != null
        ? _jsSanitize(jsonEncode(widget.clientSecret!))
        : "''";
    final method = widget.method;
    final buttonLabel = _jsSanitize(jsonEncode(widget.buttonLabel ?? 'Pay'));
    final merchantArgsJs = _jsSanitize(jsonEncode(widget.merchantArgs ?? {}));

    return '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <script>
      // Install an early error handler to capture parse/runtime errors
      try {
        window.addEventListener('error', function(e){
          try {
            window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', early: true, error: String(e.message || e), filename: e.filename || null, lineno: e.lineno || null, colno: e.colno || null });
          } catch(_){ }
          try {
            // Also capture a base64-encoded snapshot of the full document HTML
            // so the host can inspect the exact page that failed to parse.
            try {
              var html = document.documentElement && document.documentElement.outerHTML ? document.documentElement.outerHTML : null;
              if (html) {
                try {
                  var b64 = btoa(unescape(encodeURIComponent(html)));
                  try {
                    var CHUNK = 8000;
                    var total = Math.ceil(b64.length / CHUNK) || 1;
                    for (var i = 0; i < total; i++) {
                      var chunk = b64.slice(i * CHUNK, (i + 1) * CHUNK);
                      window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'full_page_snapshot_chunk', idx: i, total: total, chunk: chunk });
                    }
                    window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'full_page_snapshot_done', total: total });
                  } catch(e) { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'full_page_snapshot_error', error: String(e) }); }
                } catch(e) { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'full_page_snapshot_error', error: String(e) }); }
              }
            } catch(e) { /* ignore */ }
          } catch(_){}
        });
        window.addEventListener('unhandledrejection', function(e){ try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', early: true, error: String(e.reason || e) }); } catch(_){} });
        try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'early_error_handler_installed' }); } catch(_){ }
      } catch(e) {}
    </script>
    <script>
      // Predefine mount-related stubs and a quick status logger to help
      // diagnose situations where Stripe's script fails to execute and
      // prevents our inline scripts from defining mount(). The real
      // implementations are defined later; these stubs ensure the
      // page can still report status to Flutter.
      window.__lpe_shouldMount = window.__lpe_shouldMount || false;
      window.__lpe_method = window.__lpe_method || null;
      function mount() {
        try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:placeholder' }); } catch(e) {}
      }
      window.__lpe_invoke_mount = function() { try { if (typeof mount === 'function') mount(); } catch(e) {} };
      window.__lpe_mount = function(methodName) { try { if (methodName) window.__lpe_method = methodName; window.__lpe_shouldMount = true; if (typeof window.__lpe_invoke_mount === 'function') window.__lpe_invoke_mount(); } catch(e) {} };
      (function quickStatusLog(){
        try {
          var tries=0; var id = setInterval(function(){ tries++; try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'quick_status', hasStripe: typeof Stripe !== 'undefined', hasMount: typeof mount === 'function' }); } catch(e){} if (tries>=6) clearInterval(id); }, 200);
        } catch(e) {}
      })();
      // Provide a light-weight Stripe stub so references to `Stripe` do not
      // throw when Stripe.js hasn't loaded. The stub intentionally fails
      // tokenization/element creation so the page falls back to app-side
      // tokenization paths when Stripe is unavailable. The real Stripe.js
      // will overwrite `window.Stripe` when it loads.
      try {
        if (typeof Stripe === 'undefined') {
          window.Stripe = function(pkey){
            return {
              elements: function(){
                return {
                  create: function(type, opts){
                    return {
                      mount: function(){ /* no-op until real Stripe loads */ },
                      on: function(){}
                    };
                  }
                };
              },
              createToken: function(type, data){
                return Promise.reject(new Error('Stripe.js not loaded'));
              },
              createPaymentMethod: function(){
                return Promise.reject(new Error('Stripe.js not loaded'));
              }
            };
          };
        }
      } catch(e) { /* ignore */ }
    </script>
    <script>
      // Stripe loader moved to a callable function so Dart can opt-in to
      // load it. This avoids automatic loading on platforms where
      // Stripe.js causes WebView renderer instability (Android WebView).
      window.__lpe_load_stripe = function(){
        try {
          var url = 'https://js.stripe.com/v3/';
          function report(msg){ try{ window.flutter_inappwebview.callHandler('stripeCallback', msg); } catch(e) { console.warn('report failed', e); } }

          // Prevent multiple append attempts
          if (window.__lpe_load_attempted) { report({ type:'log', action: 'stripe:load_already_attempted' }); return; }
          window.__lpe_load_attempted = true;

          // If another load is currently in progress just return
          if (window.__lpe_load_in_progress) { report({ type:'log', action: 'stripe:load_already_in_progress' }); return; }
          window.__lpe_load_in_progress = true;
          

          function tryAppend(){
            report({ type: 'log', action: 'stripe:load_attempt' });
            // If a stripe script is already present (any src matching js.stripe.com/v3)
            // then don't append again to avoid Stripe.js duplicate-load warnings.
            try {
              var existing = document.querySelector('script[src^="https://js.stripe.com/v3"]');
              if (existing) { report({ type: 'log', action: 'stripe:script_tag_present', src: existing.src }); window.__lpe_load_in_progress = false; window.__lpe_stripe_loaded_once = true; return; }
              var prev = document.getElementById('__lpe_stripe_js'); if (prev && prev.parentNode) prev.parentNode.removeChild(prev);
            } catch(e) {}
            var s = document.createElement('script');
            s.id = '__lpe_stripe_js';
            s.setAttribute('data-lpe','1');
            s.src = url + '?t=' + Date.now(); // cache-bust
            s.async = true;
            s.onload = function(){
              try { window.__lpe_stripe_loaded_once = true; } catch(e) {}
              report({ type: 'log', action: 'stripe:loaded' });
              // Try to initialize the Stripe client automatically so the
              // page becomes self-contained. Some WebView environments
              // load the Stripe script but our Dart-side initRace means
              // mount() can run before Stripe is available — initialize
              // here and then invoke mount if requested.
              try {
                var pk = (window.STRIPE_PUBLISHABLE_KEY || (typeof STRIPE_PUBLISHABLE_KEY !== 'undefined' ? STRIPE_PUBLISHABLE_KEY : null));
                if (typeof Stripe === 'function') {
                  try {
                    window.stripe = Stripe(pk);
                    report({ type: 'log', action: 'stripe:inited_from_onload', pk: String(pk) });
                  } catch(e) {
                    report({ type: 'error', action: 'stripe:init_onload_error', error: String(e) });
                  }
                }
              } catch(e) {
                try { report({ type: 'error', action: 'stripe:onload_handler_error', error: String(e) }); } catch(_){}
              }
              window.__lpe_load_in_progress = false;
              try { if (window.__lpe_shouldMount && typeof window.__lpe_invoke_mount === 'function') { window.__lpe_invoke_mount(); } } catch(e) {}
            };
            s.onerror = function(ev){
              report({ type: 'error', action: 'stripe:load_error', message: String(ev && ev.message ? ev.message : ev) });
              window.__lpe_load_in_progress = false;
              report({ type: 'error', action: 'stripe:load_failed' });
            };
            document.head.appendChild(s);
          }

          // Also attempt a fetch for diagnostics (may be CORS-limited).
          try {
            fetch(url, { method: 'GET', cache: 'no-store' }).then(function(resp){
              var ct = resp.headers.get('content-type');
              resp.text().then(function(text){
                try { report({ type: 'log', action: 'stripe:fetch', status: resp.status, contentType: ct, snippet: text.slice(0,400) }); } catch(e){}
              }).catch(function(e){ report({ type: 'error', action: 'stripe:fetch_text_error', error: String(e) }); });
            }).catch(function(e){ report({ type: 'error', action: 'stripe:fetch_error', error: String(e) }); });
          } catch(e) { report({ type: 'error', action: 'stripe:fetch_sync_error', error: String(e) }); }

          // Start first attempt
          tryAppend();
        } catch(e) { try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', action: 'stripe_loader_error', error: String(e) }); } catch(_){} }
      };
      // Auto-load hook removed to avoid duplicate load attempts. Dart
      // will be responsible for invoking `window.__lpe_load_stripe()` once
      // after it injects the runtime values to ensure a single, deterministic
      // load. (Removed inline auto invocation to prevent double-loads.)
    </script>
    </script>
    <style>
      * { box-sizing: border-box; }
      body { 
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
        margin: 0; 
        padding: 16px; 
        background: #fff;
      }
      #container { max-width: 500px; margin: 0 auto; }
      #element-root { 
        min-height: 200px;
        margin-bottom: 16px;
      }
      #action {
        width: auto;
        min-width: 140px;
        padding: 12px 32px;
        font-size: 15px;
        font-weight: 600;
        color: #fff;
        background: #2196F3;
        border: none;
        border-radius: 24px;
        cursor: pointer;
        transition: background 0.2s, box-shadow 0.2s;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        display: block;
        margin: 0 auto;
      }
      #action:hover { background: #1976D2; }
      #action:disabled { background: #ccc; cursor: not-allowed; box-shadow: none; }
      #out { 
        margin-top: 12px; 
        padding: 8px; 
        font-size: 14px; 
        color: #666;
        text-align: center;
      }
      .loading { 
        display: flex; 
        justify-content: center; 
        align-items: center; 
        min-height: 150px;
        color: #999;
      }
      .error { color: #dc3545; }
      .success { color: #28a745; }
    </style>
  </head>
  <body>
    <div id="container">
      <div id="merchant-summary"></div>
      <div id="element-root"></div>
      <button id="action" disabled>${buttonLabel}</button>
      <div id="out"></div>
    </div>
    <style>
      /* Merchant summary styles */
      #merchant-summary { margin: 8px 0 12px 0; }
      .ms-card { background:#fff; border-radius:12px; padding:12px; box-shadow:0 1px 0 rgba(0,0,0,0.04); }
      .ms-merchant { display:flex; align-items:center; gap:12px; padding:8px; }
      .ms-logo { width:44px;height:44px;border-radius:10px;background:#FFD633;color:#000;display:flex;align-items:center;justify-content:center;font-weight:bold;font-size:20px }
      .ms-merchant-name { font-weight:600; font-size:16px; }
      .ms-summary { margin-top:10px; padding:8px; border-radius:10px; background:#fff; }
      .ms-sublabel { color:#999; font-size:13px; margin-top:4px; }
      .ms-row { display:flex; justify-content:space-between; padding:10px 6px; color:#333; font-size:15px; }
      .ms-divider { height:1px; background:#efefef; margin:0 4px; }
      .ms-total { margin-top:12px; display:flex; justify-content:space-between; padding:12px 16px; font-weight:700; font-size:20px; border-radius:10px; background:#fff; border:1px solid #f0f0f0; }
    </style>
    <script>
      // Publishable key passed directly from Flutter
      const STRIPE_PUBLISHABLE_KEY = ${pkJs};
      try { console.log('LPE: script init STRIPE_PUBLISHABLE_KEY ->', STRIPE_PUBLISHABLE_KEY); } catch (_) {}
      try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'script:init', STRIPE_PUBLISHABLE_KEY: String(STRIPE_PUBLISHABLE_KEY) }); } catch (e) {}
      
      // Client secret passed from Flutter (if available)
      window.STRIPE_CLIENT_SECRET = ${csJs};
      
      // Merchant args passed from Flutter (may be empty)
      const MERCHANT_ARGS = ${merchantArgsJs};
      window.MERCHANT_ARGS = MERCHANT_ARGS;
      
      // Global JS error hooks to forward failures to Flutter
      window.addEventListener('error', function(e) {
        try {
          var payload = { type: 'error', error: String(e.message || e), filename: e.filename || null, lineno: e.lineno || null, colno: e.colno || null };
          try { payload.stack = (e.error && e.error.stack) ? String(e.error.stack) : null; } catch(_) { }
          try { window.flutter_inappwebview.callHandler('stripeCallback', payload); } catch(_) {}
          // Also send a snapshot of script tags (src or first 400 chars of inline script)
          try {
            var scripts = Array.prototype.slice.call(document.scripts || []).map(function(s){ return { src: s.src || null, inline: (s.src ? null : (s.innerHTML ? s.innerHTML.slice(0,400) : null)) }; });
            try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'script_snapshot', scripts: scripts }); } catch(_) {}
          } catch(_) {}
        } catch (ex) { console.warn('error forward failed', ex); }
      });
      window.addEventListener('unhandledrejection', function(e) {
        try {
          var payload = { type: 'error', error: String(e.reason || e), reason: (e.reason && e.reason.stack) ? String(e.reason.stack) : null };
          window.flutter_inappwebview.callHandler('stripeCallback', payload);
        } catch (ex) { console.warn('rejection forward failed', ex); }
      });

      // Initialize Stripe immediately with the passed key
      let stripe = null;
      const out = document.getElementById('out');

      function renderMerchantSummary() {
          try {
          const m = window.MERCHANT_ARGS || {};
          if (!m || Object.keys(m).length === 0) return;
          const container = document.getElementById('merchant-summary');
          const merchantName = m.merchantName || m.merchant_args?.merchantName || '';
          const merchantInfo = m.merchantInfo || m.merchant_args?.merchantInfo || '';
          const amountLabel = m.amountLabel || '';
          const summary = m.summaryItems || m.merchant_args?.summaryItems || [];
          // Prefer authoritative total if provided via merchant args
          let total = 0.0;
          const lines = [];
          if (Array.isArray(summary) && summary.length > 0) {
            // Build lines; detect a zero-dollar corporate row ("The Learmond Corporation")
            // and attach it as a sublabel to the Taxes row when present.
            summary.forEach(s=>{
              try {
                const cents = Number(s.amountCents||s.amount||0);
                const amt = (cents/100.0);
                const label = (s.label||'').toString();
                // Treat a zero-dollar corporate row specially
                if (label.trim().toLowerCase() === 'the learmond corporation' && Math.abs(amt) < 0.005) {
                  lines.push({label: label, amount: amt, isCorp: true});
                } else {
                  total += amt;
                  lines.push({label: label, amount: amt});
                }
              } catch(e){}
            });
            // If a corporate zero-dollar row exists, render it as its own
            // Taxes row with the corporate name as a sublabel directly
            // after the Taxes row. If Taxes is not present, render the
            // Taxes row with the corporate sublabel by itself.
            try {
              const taxIdx = lines.findIndex(l=> (l.label||'').toString().toLowerCase().startsWith('tax'));
              const corpIdx = lines.findIndex(l=> l.isCorp === true);
              if (corpIdx !== -1) {
                const corp = lines[corpIdx];
                const corpLabel = corp.label || '';
                const corpAmount = corp.amount || 0.0;
                // remove original corp entry
                lines.splice(corpIdx, 1);
                if (taxIdx !== -1) {
                  // insert a Taxes row right after the existing Taxes row
                  lines.splice(taxIdx + 1, 0, {label: 'Taxes', amount: corpAmount, sublabel: corpLabel});
                } else {
                  // No taxes row present — append a Taxes row with corp sublabel
                  lines.push({label: 'Taxes', amount: corpAmount, sublabel: corpLabel});
                }
              }
            } catch(e){}
          } else if (amountLabel) {
          } else if (amountLabel) {
            const cleaned = (amountLabel+'').split('').filter(function(c){ return '0123456789.-'.indexOf(c) !== -1; }).join('');
            const num = parseFloat(cleaned) || 0.0; total = num;
            lines.push({label: merchantInfo || 'Amount', amount: num});
          }

          // If an authoritative amountCents was provided in merchant args use it
          if (typeof m.amountCents === 'number' && !isNaN(m.amountCents)) {
            total = Number(m.amountCents) / 100.0;
          }

          let html = '<div class="ms-card">';
          html += '<div class="ms-merchant"><div class="ms-logo">S</div><div class="ms-merchant-name">'+(merchantName||'Source')+'</div></div>';
          html += '<div class="ms-summary">';
          html += '<div style="color:#999;font-size:14px;margin-bottom:8px">Summary</div>';
          html += '<div style="border-radius:8px;overflow:hidden;background:#fff;">';
          lines.forEach((r,idx)=>{ html += '<div class="ms-row"><div style="min-width:0">'+(r.label? '<div>'+r.label+'</div>' : '') + (r.sublabel? '<div class="ms-sublabel">'+r.sublabel+'</div>' : '') + '</div><div style="color:#666">\$'+(r.amount.toFixed(2))+'</div></div>'; if (idx<lines.length-1) html += '<div class="ms-divider"></div>'; });
          html += '</div>';
          // Final total row should use merchant name (Source) instead of 'Total'
          const finalLabel = merchantName || 'Total';
          html += '<div class="ms-total"><div>'+finalLabel+'</div><div>\$'+(total.toFixed(2))+'</div></div>';

          html += '</div></div>';
          // (no-op) merchant summary rendering
          container.innerHTML = html;
        } catch(e) { console.warn('renderMerchantSummary failed', e); }
      }
      try { renderMerchantSummary(); try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'renderMerchantSummary' }); } catch (e2) {} } catch(e) { console.warn('renderMerchantSummary failed', e); try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'mount_error', error: String(e) }); } catch (e2) {} }

      
      function send(msg) {
        try {
          window.flutter_inappwebview.callHandler('stripeCallback', msg);
        } catch (e) {
          console.log('bridge missing', e, msg);
        }
      }

      // Initialize Stripe with the passed publishable key
      function initStripe() {
        try {
          if (!STRIPE_PUBLISHABLE_KEY || STRIPE_PUBLISHABLE_KEY === '') {
            out.textContent = 'No publishable key provided';
            out.className = 'error';
            try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', error: 'No publishable key provided' }); } catch(e){}
            return false;
          }
          out.textContent = 'Initializing...';
          if (typeof Stripe !== 'function' || (Stripe && Stripe._lpe_stub === true) || window.__lpe_stubbed_stripe === true) {
            // Treat a present Stripe stub as not-yet-loaded so we wait for the
            // real Stripe.js to arrive instead of initializing a no-op stub.
            out.textContent = 'Waiting for Stripe.js...';
            try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'initStripe:waiting', stubDetected: ((Stripe && Stripe._lpe_stub === true) || window.__lpe_stubbed_stripe === true) }); } catch (e) {}
            return false;
          }
          stripe = Stripe(STRIPE_PUBLISHABLE_KEY);
          window.STRIPE_PUBLISHABLE_KEY = STRIPE_PUBLISHABLE_KEY;
          window.SOURCE_STRIPE_PUBLISHABLE_KEY = STRIPE_PUBLISHABLE_KEY;
          try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'initStripe:ok' }); } catch (e) {}
          return true;
        } catch (err) {
          out.textContent = 'Error: ' + (err && err.message ? err.message : String(err));
          out.className = 'error';
          send({ type: 'error', error: 'Failed to initialize Stripe: ' + (err && err.message ? err.message : String(err)) });
          try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', error: 'Failed to initialize Stripe: ' + (err && err.message ? err.message : String(err)) }); } catch (e) {}
          return false;
        }
      }

      async function mount() {
        // Avoid double-mounting if we've already mounted once
        try { if (window.__lpe_mounted) { send({ type: 'log', action: 'mount:already' }); return; } } catch(e) {}
        // Initialize Stripe with the passed publishable key
        const stripeReady = initStripe();
        // Additional diagnostic log so Flutter can see runtime values when mount runs
        try { send({ type: 'log', action: 'mount:invoked', method: (window.__lpe_method || ${jsonEncode(method)}), publishableKey: (window.STRIPE_PUBLISHABLE_KEY || null), clientSecret: (window.STRIPE_CLIENT_SECRET || null), shouldMount: !!window.__lpe_shouldMount }); } catch (e) {}
        try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:start', method: (window.__lpe_method || ${jsonEncode(method)}) }); } catch (e) {}
        if (!stripeReady || !stripe) {
          return;
        }
        
        const method = ${jsonEncode(method)};
        out.textContent = 'Mounting ' + method;
        if (method === 'card') {
          // Mount Card Element for card-only entry
          let elementsOptions = {};
          if (window.STRIPE_CLIENT_SECRET && window.STRIPE_CLIENT_SECRET !== '') {
            elementsOptions = { clientSecret: window.STRIPE_CLIENT_SECRET };
          }
          const elements = stripe.elements(elementsOptions);
          window.elements = elements;
          const cardElement = elements.create('card', {
            style: {
              base: {
                fontSize: '16px',
                color: '#32325d',
                fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
                '::placeholder': { color: '#aab7c4' }
              },
              invalid: { color: '#fa755a', iconColor: '#fa755a' }
            }
          });
          window.cardElement = cardElement;
          
          cardElement.on('ready', function() {
            document.getElementById('action').disabled = false;
            out.textContent = '';
          });
          
          cardElement.on('change', function(event) {
            if (event.error) {
              out.textContent = event.error.message;
              out.className = 'error';
            } else {
              out.textContent = '';
              out.className = '';
            }
          });
          
          cardElement.mount('#element-root');
          try { window.__lpe_mounted = true; send({type:'log', action:'mount:done', method: 'card'}); } catch(e) {}
          try {
            var root = document.getElementById('element-root');
            send({ type: 'diagnostic', action: 'post_mount_snapshot', elementRootChildren: root ? root.children.length : 0, elementRootHtmlSnippet: root && root.innerHTML ? String(root.innerHTML).slice(0,800) : null });
          } catch(e) {}
          document.getElementById('action').addEventListener('click', async ()=>{
            try {
              if (window.STRIPE_CLIENT_SECRET) {
                out.textContent = 'Confirming payment...';
                const res = await stripe.confirmCardPayment(window.STRIPE_CLIENT_SECRET, {
                  payment_method: { card: cardElement }
                });
                send({ type: 'payment_confirm_result', result: res });
              } else {
                out.textContent = 'Creating payment method...';
                const { paymentMethod, error } = await stripe.createPaymentMethod({
                  type: 'card',
                  card: cardElement
                });
                if (error) {
                  send({ type: 'error', error: error.message });
                } else {
                  send({ type: 'payment_method_created', result: { paymentMethod } });
                }
              }
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          });
        } else if (method === 'payment') {
          // Mount full Payment Element for multiple payment methods
          let elementsOptions = {};
          if (window.STRIPE_CLIENT_SECRET && window.STRIPE_CLIENT_SECRET !== '') {
            elementsOptions = { clientSecret: window.STRIPE_CLIENT_SECRET };
          } else {
            elementsOptions = { mode: 'payment', currency: 'usd', amount: 100 };
          }
          const elements = stripe.elements(elementsOptions);
          window.elements = elements;
          const paymentElement = elements.create('payment');
          window.paymentElement = paymentElement;
          
          paymentElement.on('ready', function() {
            document.getElementById('action').disabled = false;
            out.textContent = '';
          });
          
          paymentElement.on('change', function(event) {
            if (event.error) {
              out.textContent = event.error.message;
              out.className = 'error';
            } else {
              out.textContent = '';
              out.className = '';
            }
          });
          
          paymentElement.mount('#element-root');
          try { window.__lpe_mounted = true; send({type:'log', action:'mount:done', method: 'payment'}); } catch(e) {}
          try {
            var root = document.getElementById('element-root');
            send({ type: 'diagnostic', action: 'post_mount_snapshot', elementRootChildren: root ? root.children.length : 0, elementRootHtmlSnippet: root && root.innerHTML ? String(root.innerHTML).slice(0,800) : null });
          } catch(e) {}
          document.getElementById('action').addEventListener('click', async ()=>{
            try {
              if (window.STRIPE_CLIENT_SECRET) {
                out.textContent = 'Confirming payment...';
                const res = await stripe.confirmPayment({ elements, clientSecret: window.STRIPE_CLIENT_SECRET });
                send({ type: 'payment_confirm_result', result: res });
              } else {
                const pmRes = await stripe.createPaymentMethod({ type: 'card' });
                send({ type: 'payment_method_created', result: pmRes });
              }
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          });
        } else if (method === 'us_bank') {
          // For US bank (ACH), use the Payment Element with us_bank_account support
          let elementsOptions = {};
          if (window.STRIPE_CLIENT_SECRET && window.STRIPE_CLIENT_SECRET !== '') {
            elementsOptions = { clientSecret: window.STRIPE_CLIENT_SECRET };
          } else {
            elementsOptions = { mode: 'payment', currency: 'usd', amount: 100, paymentMethodTypes: ['us_bank_account'] };
          }
          const elements = stripe.elements(elementsOptions);
          window.elements = elements;
          
          // Create a simple form for bank account info
          document.getElementById('element-root').innerHTML = 
            '<div style="margin-bottom:12px;">' +
            '<label style="display:block;margin-bottom:4px;font-size:14px;color:#333;">Account Holder Name</label>' +
            '<input type="text" id="account-holder-name" placeholder="John Doe" style="width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:16px;"/>' +
            '</div>' +
            '<div style="margin-bottom:12px;">' +
            '<label style="display:block;margin-bottom:4px;font-size:14px;color:#333;">Routing Number</label>' +
            '<input type="text" id="routing-number" placeholder="110000000" style="width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:16px;"/>' +
            '</div>' +
            '<div style="margin-bottom:12px;">' +
            '<label style="display:block;margin-bottom:4px;font-size:14px;color:#333;">Account Number</label>' +
            '<input type="text" id="account-number" placeholder="000123456789" style="width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:16px;"/>' +
            '</div>';
          
          document.getElementById('action').disabled = false;
          out.textContent = '';
          
          document.getElementById('action').addEventListener('click', async ()=>{
            try {
              const holderName = document.getElementById('account-holder-name').value;
              const routingNumber = document.getElementById('routing-number').value;
              const accountNumber = document.getElementById('account-number').value;
              
              if (!holderName || !routingNumber || !accountNumber) {
                out.textContent = 'Please fill in all fields';
                out.className = 'error';
                return;
              }
              
              out.textContent = 'Processing...';
              // Create payment method for US bank account
              const { paymentMethod, error } = await stripe.createPaymentMethod({
                type: 'us_bank_account',
                us_bank_account: {
                  account_holder_type: 'individual',
                  routing_number: routingNumber,
                  account_number: accountNumber,
                },
                billing_details: {
                  name: holderName,
                },
              });
              
              if (error) {
                out.textContent = error.message;
                out.className = 'error';
                send({ type: 'error', error: error.message });
              } else {
                send({ type: 'payment_method_created', result: { paymentMethod } });
              }
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          });
        } else if (method === 'eu_bank') {
          // For EU bank, use IBAN element
          const elements = stripe.elements();
          window.elements = elements;
          
          const ibanElement = elements.create('iban', {
            supportedCountries: ['SEPA'],
            placeholderCountry: 'DE',
            style: {
              base: {
                fontSize: '16px',
                color: '#32325d',
                fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
                '::placeholder': { color: '#aab7c4' }
              },
              invalid: { color: '#fa755a', iconColor: '#fa755a' }
            }
          });
          window.ibanElement = ibanElement;
          
          // Add name field above IBAN
          document.getElementById('element-root').innerHTML = 
            '<div style="margin-bottom:12px;">' +
            '<label style="display:block;margin-bottom:4px;font-size:14px;color:#333;">Account Holder Name</label>' +
            '<input type="text" id="account-holder-name" placeholder="Name" style="width:100%;padding:10px;border:1px solid #ccc;border-radius:4px;font-size:16px;margin-bottom:12px;"/>' +
            '</div>' +
            '<div id="iban-element"></div>';
          
          ibanElement.mount('#iban-element');
          
          ibanElement.on('ready', function() {
            document.getElementById('action').disabled = false;
            out.textContent = '';
          });
          
          ibanElement.on('change', function(event) {
            if (event.error) {
              out.textContent = event.error.message;
              out.className = 'error';
            } else {
              out.textContent = '';
              out.className = '';
            }
          });
          
          document.getElementById('action').addEventListener('click', async ()=>{
            try {
              const holderName = document.getElementById('account-holder-name').value;
              if (!holderName) {
                out.textContent = 'Please enter account holder name';
                out.className = 'error';
                return;
              }
              
              out.textContent = 'Processing...';
              const { paymentMethod, error } = await stripe.createPaymentMethod({
                type: 'sepa_debit',
                sepa_debit: ibanElement,
                billing_details: {
                  name: holderName,
                },
              });
              
              if (error) {
                out.textContent = error.message;
                out.className = 'error';
                send({ type: 'error', error: error.message });
              } else {
                send({ type: 'payment_method_created', result: { paymentMethod } });
              }
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          });
        } else if (method === 'apple_pay' || method === 'google_pay') {
          // Use Payment Request Button for Apple Pay / Google Pay
          const payType = method === 'apple_pay' ? 'Apple Pay' : 'Google Pay';
          
          // Allow canMakePayment to run even if a client secret is not present.
          // The Payment Request Button can be mounted and probed for availability
          // without a client secret; actual confirmation requires a client
          // secret and will be handled later. We still surface an informational
          // message if the client secret is missing.
          const hasClientSecret = (window.STRIPE_CLIENT_SECRET && window.STRIPE_CLIENT_SECRET !== '');
          
          // Create payment request (amount placeholder; real amount comes from server-side PaymentIntent)
          // Use merchant name as the total label when provided so the Apple Pay sheet
          // shows the expected merchant instead of a generic app name.
          const m = window.MERCHANT_ARGS || {};
          const merchantName = (m.merchantName || m.merchant_args?.merchantName || '').toString();
          const displayLabel = (merchantName && merchantName.length > 0) ? merchantName : 'Total';
          const paymentRequest = stripe.paymentRequest({
            country: 'US',
            currency: 'usd',
            total: {
              label: displayLabel,
              amount: 0, // Placeholder - will be set when payment is initiated
              pending: true, // Indicates amount may change
            },
            requestPayerName: true,
            requestPayerEmail: true,
          });
          
          // Check if device can make payment
          const canMakePaymentResult = await paymentRequest.canMakePayment();
          send({ type: 'canMakePayment', result: canMakePaymentResult });

          if (!canMakePaymentResult) {
            document.getElementById('element-root').innerHTML = 
              '<div style="text-align:center;padding:20px;color:#666;">' +
              '<p style="font-size:16px;margin-bottom:12px;">' + payType + ' is not available on this device.</p>' +
              '<p style="font-size:14px;color:#999;">Please ensure:</p>' +
              '<ul style="text-align:left;font-size:13px;color:#999;margin:12px auto;max-width:280px;">' +
              '<li>You have a supported card added to your wallet</li>' +
              '<li>You are using a compatible browser/device</li>' +
              '<li>' + payType + ' is enabled in your device settings</li>' +
              '</ul>' +
              '</div>';
            out.textContent = payType + ' not available';
            out.className = 'error';
            document.getElementById('action').style.display = 'none';
            return;
          }
          
          // Create the Payment Request Button element
          const elements = stripe.elements();
          const prButton = elements.create('paymentRequestButton', {
            paymentRequest: paymentRequest,
            style: {
              paymentRequestButton: {
                type: method === 'apple_pay' ? 'plain' : 'default',
                theme: 'dark',
                height: '48px',
              },
            },
          });
          
          // Hide our custom action button since the PR button handles everything
          document.getElementById('action').style.display = 'none';
          
          // Mount the button
          prButton.mount('#element-root');
          try { window.__lpe_mounted = true; send({type:'log', action:'mount:done', method: method}); } catch(e) {}
          try {
            var root = document.getElementById('element-root');
            send({ type: 'diagnostic', action: 'post_mount_snapshot', elementRootChildren: root ? root.children.length : 0, elementRootHtmlSnippet: root && root.innerHTML ? String(root.innerHTML).slice(0,800) : null });
          } catch(e) {}
          out.textContent = '';
          
          // Handle the payment method event from Apple Pay / Google Pay
          paymentRequest.on('paymentmethod', async (ev) => {
            try {
              out.textContent = 'Processing payment...';
              // If we don't have a client secret we cannot confirm a PaymentIntent
              // yet — inform Flutter and fail the client side confirmation. The
              // app can then request an intent from the server and retry.
              if (!hasClientSecret) {
                ev.complete('fail');
                out.textContent = 'Missing payment information';
                out.className = 'error';
                send({ type: 'error', error: 'Missing client secret for device payment' });
                return;
              }

              // Confirm the PaymentIntent with the payment method from Apple Pay / Google Pay
              const { paymentIntent, error: confirmError } = await stripe.confirmCardPayment(
                window.STRIPE_CLIENT_SECRET,
                { payment_method: ev.paymentMethod.id },
                { handleActions: false }
              );
              
              if (confirmError) {
                // Report failure to the browser
                ev.complete('fail');
                out.textContent = confirmError.message;
                out.className = 'error';
                send({ type: 'error', error: confirmError.message });
              } else {
                // Check if additional action is required (e.g., 3D Secure)
                if (paymentIntent.status === 'requires_action') {
                  ev.complete('success');
                  // Let Stripe handle the additional authentication
                  const { error: actionError, paymentIntent: confirmedIntent } = await stripe.confirmCardPayment(window.STRIPE_CLIENT_SECRET);
                  if (actionError) {
                    out.textContent = actionError.message;
                    out.className = 'error';
                    send({ type: 'error', error: actionError.message });
                  } else {
                    out.textContent = 'Payment successful!';
                    out.className = 'success';
                    send({ type: 'payment_confirm_result', result: { paymentIntent: confirmedIntent } });
                  }
                } else {
                  // Payment succeeded without additional action
                  ev.complete('success');
                  out.textContent = 'Payment successful!';
                  out.className = 'success';
                  send({ type: 'payment_confirm_result', result: { paymentIntent } });
                }
              }
            } catch (err) {
              ev.complete('fail');
              out.textContent = 'Payment failed: ' + err.message;
              out.className = 'error';
              send({ type: 'error', error: String(err) });
            }
          });
          
          // Handle cancel event
          paymentRequest.on('cancel', () => {
            out.textContent = 'Payment cancelled';
            send({ type: 'payment_cancelled' });
          });
        } else {
          out.textContent = 'Unknown method';
        }
      }
      // Expose an explicit mount trigger that Flutter will call after it has
      // injected any required runtime values (publishable key, client secret,
      // merchant args). This avoids race conditions where the script runs before
      // the WebView environment receives injected values.
      window.__lpe_mount = function(methodName) {
        try {
          if (methodName) { window.__lpe_method = methodName; }
          window.__lpe_shouldMount = true;
          if (typeof window.__lpe_invoke_mount === 'function') {
            try { window.__lpe_invoke_mount(); } catch(e) { send({type:'mount_error', error: String(e)}); }
          }
        } catch(e) {}
      };

      window.__lpe_invoke_mount = function() { mount().catch(e=>{ send({type:'mount_error', error: String(e)}); }); };

      // If Flutter has requested an immediate mount before we were ready,
      // honor it now. This avoids races where Dart sets a flag but the
      // inline mount function hasn't been defined yet.
      try {
        if (window.__lpe_shouldMount) {
          try { window.__lpe_invoke_mount(); } catch(e) { send({type:'mount_error', error: String(e)}); }
        }
      } catch(e) {}

      // Expose a teardown hook that Flutter can call before the native
      // WebView controller is disposed. This attempts to unmount Stripe
      // Elements and remove DOM references so the native teardown does
      // less work and reduces the chance of a plugin race/crash.
      window.__stripe_teardown = function() {
        try {
          if (window.card && typeof window.card.unmount === 'function') {
            try { window.card.unmount(); } catch(e) { }
          }
          try { if (window.elements) { /* best-effort clear */ window.elements = null; } } catch(e) {}
          try { if (window.SOURCE_STRIPE_PUBLISHABLE_KEY) { window.SOURCE_STRIPE_PUBLISHABLE_KEY = ''; } } catch(e) {}
          try { if (window.STRIPE_PUBLISHABLE_KEY) { window.STRIPE_PUBLISHABLE_KEY = ''; } } catch(e) {}
          try { if (window.STRIPE_CLIENT_SECRET) { window.STRIPE_CLIENT_SECRET = ''; } } catch(e) {}
          // Remove all children to minimize native view work.
          try { document.body.innerHTML = '<div id="out">Closing...</div>'; } catch(e) {}
        } catch (e) {
          // swallow
        }
      };

      // Auto-mount helper: if Flutter requested a mount (via __lpe_shouldMount)
      // but the mount function or Stripe isn't ready yet, poll and invoke
      // mount when conditions are satisfied.
      (function startAutoMountPoll(){
        try {
          var tries = 0;
          var max = 100; // max 10s (100 * 100ms)
          var id = setInterval(function(){
            try {
              var haveMount = (typeof mount === 'function');
              var haveStripe = (typeof Stripe !== 'undefined');
              var haveKey = !!(window.STRIPE_PUBLISHABLE_KEY && window.STRIPE_PUBLISHABLE_KEY !== '');
              if (haveMount && haveStripe && haveKey && !!window.__lpe_shouldMount) {
                clearInterval(id);
                try { mount(); send({type:'log', action:'auto_mount_called'}); } catch(e) { send({type:'mount_error', error:String(e)}); }
                return;
              }
              tries++;
              if (tries >= max) { clearInterval(id); console.log('LPE: auto_mount_giveup'); }
            } catch(e) { clearInterval(id); console.log('LPE: auto_mount_error '+String(e)); }
          }, 100);
        } catch(e) {}
      })();
    </script>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final htmlData = _buildHtml();
    return SizedBox(
      height: 360,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: htmlData,
          // Use a neutral base URL to avoid the WebView treating this page
          // as the stripe.js.com origin which can cause unexpected fetches
          // of Stripe's root page. Use a blank base to keep absolute URLs
          // working without changing origin behavior.
          baseUrl: WebUri('about:blank'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          allowFileAccess: true,
          allowContentAccess: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          // Allow third-party cookies; Stripe Elements uses cross-origin iframes
          // which can be affected by cookie blocking in some WebView configurations.
          thirdPartyCookiesEnabled: true,
        ),
        onWebViewCreated: (controller) {
          if (widget.onWebViewCreated != null) {
            widget.onWebViewCreated!(controller);
          }
          // register handler to receive messages from JS
          controller.addJavaScriptHandler(
              handlerName: 'stripeCallback',
              callback: (args) {
                if (args.isNotEmpty && args[0] is Map) {
                  final Map m = args[0];
                  widget.onMessage(Map<String, dynamic>.from(m));
                } else {
                  widget.onMessage({'args': args});
                }
              });
        },
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode) {
            debugPrint('StripeWebview console: ' + consoleMessage.toString());
          }
        },
        onLoadStop: (controller, url) async {
          try {
            debugPrint('StripeWebview onLoadStop: $url');
            // Small delay to let the page's inline script run (Stripe sometimes
            // injects code asynchronously and the WebView onLoadStop can fire
            // before all inline script has executed). This avoids races that
            // caused our mount functions to be undefined at injection time.
            await Future.delayed(const Duration(milliseconds: 150));

            final res = await controller.evaluateJavascript(
                source:
                    "(function(){ try{ return { hasStripe: (typeof Stripe!=='undefined'), hasCallHandler: (typeof window.flutter_inappwebview!=='undefined'), publishableKey: window.STRIPE_PUBLISHABLE_KEY || null, merchantArgs: (window.MERCHANT_ARGS? JSON.stringify(window.MERCHANT_ARGS): null) }; } catch(e){ return { error: String(e) }; } })();");
            debugPrint('StripeWebview env check: $res');
            try {
              controller.evaluateJavascript(
                  source:
                      "console.log('LPE: stripe env check ->', JSON.stringify({hasStripe: typeof Stripe!=='undefined', hasCallHandler: typeof window.flutter_inappwebview!=='undefined', publishableKey: window.STRIPE_PUBLISHABLE_KEY || null}));");
            } catch (_) {}
            // If Stripe failed to load, show a visual message inside the WebView to help debugging
            try {
              await controller.evaluateJavascript(source: '''
              (function(){
                try {
                  if (typeof Stripe === 'undefined') {
                    document.getElementById('element-root').innerHTML = '<div style="padding:20px;color:#900; font-weight:600; text-align:center;">Stripe.js failed to load</div>';
                    return 'stripe_missing';
                  } else {
                    return 'stripe_ok';
                  }
                } catch(e) { return 'env_eval_error-' + String(e); }
              })();
              ''');
            } catch (_) {}

            // Inject runtime values from Flutter into the WebView and then trigger
            // the explicit mount function we defined in the page. This avoids
            // races where mount() runs before Flutter-set values are visible.
            try {
              final pkLit = jsonEncode(widget.publishableKey);
              final csLit = jsonEncode(widget.clientSecret ?? '');
              final merchantArgsLit = jsonEncode(widget.merchantArgs ?? {});

              final inj = await controller.evaluateJavascript(source: '''
              (function(){
                try {
                  window.STRIPE_PUBLISHABLE_KEY = $pkLit;
                  window.STRIPE_CLIENT_SECRET = $csLit;
                  window.MERCHANT_ARGS = $merchantArgsLit;
                  // Ensure the page knows which payment `method` we want mounted
                  // so mount logic can run deterministically even if mount
                  // handlers are defined after this injection.
                  try { window.__lpe_method = ${jsonEncode(widget.method)}; } catch(e) {}
                  // Signal readiness to the page in case the mount function
                  // is defined after this injection. The page will call mount
                  // immediately when it observes this flag.
                  window.__lpe_shouldMount = true;
                  return {ok:true};
                } catch(e) { return {error:String(e)}; }
              })();
              ''');
              debugPrint('StripeWebview injection result: $inj');

              // Defensive: explicitly initialize Stripe in the page with the
              // injected publishable key if Stripe is loaded. We now avoid
              // auto-loading Stripe.js on platforms with known crashes (Android);
              // instead Dart will call `window.__lpe_load_stripe()` when it's
              // safe to do so. Attempt to initialize if Stripe is already
              // available (e.g., when running in Chrome). This also logs the
              // result for diagnostics.
              try {
                final initRes = await controller.evaluateJavascript(source: '''
                (function(){
                  try {
                    var pk = window.STRIPE_PUBLISHABLE_KEY || $pkLit;
                    if (typeof Stripe === 'function' && !(Stripe._lpe_stub === true || window.__lpe_stubbed_stripe === true)) {
                      try { window.stripe = Stripe(pk); window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'initStripeFromDart', pk: String(pk) }); } catch(e) { return { error: String(e) }; }
                      return { ok: true, pk: String(pk) };
                    } else if (typeof Stripe === 'function' && (Stripe._lpe_stub === true || window.__lpe_stubbed_stripe === true)) {
                      return { error: 'stripe_stub_present' };
                    } else {
                      return { error: 'no_stripe_global' };
                    }
                  } catch(e) { return { error: String(e) }; }
                })();
                ''');
                debugPrint('StripeWebview explicit init result: $initRes');
              } catch (e) {
                debugPrint('StripeWebview explicit init failed: $e');
              }
              // Decide whether to request Stripe.js to be loaded by the page.
              // We will attempt to load Stripe.js on all platforms when the
              // page provides the loader function. This removes platform-specific
              // skipping behavior so the page can mount Elements where supported.
              try {
                final loadRes = await controller.evaluateJavascript(
                    source:
                        '''(function(){ try { if (typeof window.__lpe_load_stripe === 'function') { if (window.__lpe_load_attempted || window.__lpe_stripe_loaded_once) { return { requested:false, alreadyAttempted: !!window.__lpe_load_attempted, alreadyLoaded: !!window.__lpe_stripe_loaded_once }; } window.__lpe_load_stripe(); return { requested:true }; } return { no_loader:true }; } catch(e) { return { error: String(e) }; } })();''');
                debugPrint(
                    'StripeWebview requested page load of stripe.js: $loadRes');
              } catch (e) {
                debugPrint('StripeWebview load request failed: $e');
              }

              // Force a visible plain-card fallback if Elements do not mount
              // after the explicit init. This ensures users can still enter
              // card details even when the Elements iframe is not rendered.
              try {
                final forceFallback =
                    await controller.evaluateJavascript(source: '''
                (function(){
                  try {
                    var root = document.getElementById('element-root');
                    if (!root) return { error: 'no_root' };
                    if (root.children.length > 0) { return { skipped:true, mounted: !!window.__lpe_mounted, children: root.children.length }; }
                    // If mounted flag is set but Elements did not create DOM children
                    // fall back to a visible plain-card UI so users can still enter
                    // card details. This handles stubbed or partially initialized
                    // Stripe.js where mount() runs but produces no inputs.
                    try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'diagnostic', action: 'mount_flag_but_no_children' }); } catch(e) {}
                    root.innerHTML = '\n<div style="padding:12px;">\n  <label style="display:block;margin-bottom:6px;font-weight:600;">Card number</label>\n  <input id="lpe_card_number" placeholder="4242 4242 4242 4242" style="width:100%;padding:10px;margin-bottom:8px;border:1px solid #ccc;border-radius:6px;font-size:16px;"/>\n  <div style="display:flex;gap:8px;">\n    <input id="lpe_card_exp" placeholder="MM/YY" style="flex:1;padding:10px;border:1px solid #ccc;border-radius:6px;font-size:16px;"/>\n    <input id="lpe_card_cvc" placeholder="CVC" style="width:110px;padding:10px;border:1px solid #ccc;border-radius:6px;font-size:16px;"/>\n  </div>\n  <button id="lpe_plain_pay" style="margin-top:12px;padding:10px 18px;border-radius:20px;border:none;background:#2196F3;color:#fff;font-weight:600;">Pay</button>\n  <div id="lpe_plain_out" style="margin-top:8px;color:#666;font-size:14px;"></div>\n</div>';

                    var btn = document.getElementById('lpe_plain_pay');
                    var out = document.getElementById('lpe_plain_out');
                      // Enable the sheet's main action button to delegate to our plain fallback
                      try {
                        var mainAction = document.getElementById('action');
                        if (mainAction) { mainAction.disabled = false; mainAction.onclick = function(){ try { btn.click(); } catch(e){} }; }
                      } catch(e) {}
                    btn.addEventListener('click', async function(){
                      try {
                        out.textContent = 'Processing...';
                        var number = document.getElementById('lpe_card_number').value.split('').filter(function(c){ return c.trim() !== ''; }).join('');
                        var exp = document.getElementById('lpe_card_exp').value.split('/');
                        var cvc = document.getElementById('lpe_card_cvc').value;
                        var exp_month = exp[0] ? parseInt(exp[0].trim()) : null;
                        var exp_year = exp[1] ? parseInt(('20'+exp[1].trim()).slice(-4)) : null;
                        var cardData = { number: number, exp_month: exp_month, exp_year: exp_year, cvc: cvc };
                        if (window.stripe && typeof window.stripe.createToken === 'function') {
                          try {
                            var res = await window.stripe.createToken('card', cardData);
                            window.flutter_inappwebview.callHandler('stripeCallback', { type: 'card_token_result', result: res });
                            if (res && res.error) {
                              out.textContent = res.error.message || 'Tokenization failed';
                              out.style.color = '#dc3545';
                            } else {
                              out.textContent = 'Token created'; out.style.color = '#28a745';
                            }
                          } catch(e) {
                            // If Stripe createToken throws (or renderer instability), fallback to sending raw card to Flutter
                            try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'plain_card_entered', card: cardData }); } catch(_) {}
                            out.textContent = 'Sent card to app for tokenization'; out.style.color = '#28a745';
                          }
                        } else {
                          // No Stripe available (or it caused a crash). Send raw card data
                          try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'plain_card_entered', card: cardData }); } catch(e) { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', error: String(e) }); }
                          out.textContent = 'Sent card to app for tokenization'; out.style.color = '#28a745';
                        }
                      } catch (e) { try { window.flutter_inappwebview.callHandler('stripeCallback', { type: 'error', error: String(e) }); } catch(_){} }
                    });
                    return { ok:true, children: root.children.length };
                  } catch (e) { return { error: String(e) }; }
                })();
                ''');
                debugPrint(
                    'StripeWebview forced plain fallback result: $forceFallback');
              } catch (e) {
                debugPrint(
                    'StripeWebview forced plain fallback eval failed: $e');
              }

              // Diagnostic snapshot right after injection to verify values in the page
              try {
                final snapshot = await controller.evaluateJavascript(source: '''
                (function(){
                  try {
                    return {
                      pk: (window.STRIPE_PUBLISHABLE_KEY || null),
                      cs: (window.STRIPE_CLIENT_SECRET || null),
                      merchantArgs: (window.MERCHANT_ARGS ? JSON.stringify(window.MERCHANT_ARGS) : null),
                      shouldMount: !!window.__lpe_shouldMount,
                      methodVar: (window.__lpe_method || null),
                      hasInvoke: (typeof window.__lpe_invoke_mount === 'function'),
                      hasMount: (typeof window.__lpe_mount === 'function')
                    };
                  } catch(e) { return {error: String(e)}; }
                })();
                ''');
                debugPrint('StripeWebview post-injection snapshot: $snapshot');
              } catch (e) {
                debugPrint('StripeWebview post-injection snapshot failed: $e');
              }

              // Also capture a trimmed HTML snapshot to help diagnose malformed inline scripts
              try {
                final pageHtml = await controller.evaluateJavascript(
                    source:
                        "(function(){ try{ return (document.documentElement && document.documentElement.outerHTML) ? document.documentElement.outerHTML.slice(0,2000) : null; } catch(e){ return 'outer_html_error:'+String(e); } })();");
                debugPrint(
                    'StripeWebview pageHtml snapshot (trimmed 2k): $pageHtml');
              } catch (e) {
                debugPrint('StripeWebview pageHtml snapshot failed: $e');
              }

              if (widget.mountOnShow) {
                final mountRes = await controller.evaluateJavascript(source: '''
                (function(){
                  try {
                    if (typeof window.__lpe_mount === 'function') {
                      try { window.__lpe_mount(${jsonEncode(widget.method)}); } catch(e) { return {error:String(e)}; }
                      return {called:true};
                    }
                    // If __lpe_mount isn't present, set the flag and let the page
                    // call mount when it defines the handler.
                    try { window.__lpe_method = ${jsonEncode(widget.method)}; window.__lpe_shouldMount = true; } catch(e) {}
                    return {deferred:true};
                  } catch(e) { return {error: String(e)}; }
                })();
                ''');
                debugPrint('StripeWebview mountOnShow call result: $mountRes');

                // Snapshot after requesting mount to confirm assignment
                try {
                  final post = await controller.evaluateJavascript(source: '''
                  (function(){
                    try {
                      return { methodVar: (window.__lpe_method || null), shouldMount: !!window.__lpe_shouldMount, hasMount: (typeof mount === 'function'), hasStripe: (typeof Stripe !== 'undefined') };
                    } catch(e) { return {error: String(e)}; }
                  })();
                  ''');
                  debugPrint(
                      'StripeWebview post-mount-request snapshot: $post');
                } catch (e) {
                  debugPrint(
                      'StripeWebview post-mount-request snapshot failed: $e');
                }

                // Try calling the mount trigger again a few times (in case the
                // real mount() replaces the earlier placeholder after our call).
                // This helps with races where the placeholder runs first and the
                // real mount isn't defined until slightly later.
                try {
                  for (final delay in [150, 350, 700]) {
                    await Future.delayed(Duration(milliseconds: delay));
                    final r = await controller.evaluateJavascript(source: '''
                      (function(){
                        try {
                          if (typeof window.__lpe_invoke_mount === 'function') { window.__lpe_invoke_mount(); return {called:true, at: ${delay}}; }
                          if (typeof mount === 'function') { try { mount(); return {called_mount:true, at: ${delay}}; } catch(e) { return {error: String(e), at: ${delay}}; } }
                          return {no_mount:true, at: ${delay}};
                        } catch(e) { return {error:String(e), at: ${delay}}; }
                      })();
                    ''');
                    debugPrint('StripeWebview mount retry ($delay ms): $r');
                  }
                } catch (e) {
                  debugPrint('StripeWebview mount retry series failed: $e');
                }
              } else {
                // Poll for the mount function for a short period and call it when available.
                final mountRes = await controller.evaluateJavascript(source: '''
                (function(){
                  try {
                    var tries = 0;
                    var max = 60; // ~3 seconds total
                    var interval = 50;
                    var id = setInterval(function(){
                      try {
                        if (typeof window.__lpe_invoke_mount === 'function') {
                          clearInterval(id);
                          try { window.__lpe_invoke_mount(); } catch(e) { console.log('LPE: mount_call_threw', String(e)); }
                          console.log('LPE: mount_called_via_poll');
                        } else {
                          tries++;
                          if (tries >= max) { clearInterval(id); console.log('LPE: mount_not_found_after_retries'); }
                        }
                      } catch(e) { clearInterval(id); console.log('LPE: mount_call_error_poll:' + String(e)); }
                    }, interval);
                    return {scheduled:true};
                  } catch(e) { return { error: String(e) }; }
                })();
                ''');
                debugPrint('StripeWebview mount call scheduled: $mountRes');

                // If mount still hasn't succeeded after the retries/polling, run a
                // deterministic fallback from Dart that mounts the appropriate
                // Stripe Element directly inside the page. This ensures input
                // fields appear for users even when timing or script issues
                // prevented the page's inline mount from running.
                try {
                  final fallbackRes =
                      await controller.evaluateJavascript(source: '''
                  (function(){
                    try {
                      if (window.__lpe_mounted) { return {already:true}; }
                      var method = ${jsonEncode(widget.method)};
                      if (typeof Stripe === 'undefined' || (Stripe && Stripe._lpe_stub === true) || window.__lpe_stubbed_stripe === true) { return {error: 'no_stripe'}; }
                      if (!window.STRIPE_PUBLISHABLE_KEY || window.STRIPE_PUBLISHABLE_KEY === '') { return {error: 'no_publishable_key'}; }

                      var stripe = Stripe(window.STRIPE_PUBLISHABLE_KEY);

                      if (method === 'card') {
                        var elements = stripe.elements();
                        window.elements = elements;
                        var card = elements.create('card', { style: { base: { fontSize: '16px', color: '#32325d', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif' } } });
                        window.cardElement = card;
                        card.mount('#element-root');
                        try { window.__lpe_mounted = true; window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:done', method: 'card' }); } catch(e) {}
                        return {ok:true, method: 'card'};
                      } else if (method === 'payment') {
                        var opts = {};
                        if (window.STRIPE_CLIENT_SECRET && window.STRIPE_CLIENT_SECRET !== '') { opts = { clientSecret: window.STRIPE_CLIENT_SECRET }; }
                        var elements = stripe.elements(opts);
                        window.elements = elements;
                        var paymentElement = elements.create('payment');
                        window.paymentElement = paymentElement;
                        paymentElement.mount('#element-root');
                        try { window.__lpe_mounted = true; window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:done', method: 'payment' }); } catch(e) {}
                        return {ok:true, method: 'payment'};
                      } else if (method === 'us_bank') {
                        // Fallback: render basic ACH form inputs so user can enter bank info.
                        document.getElementById('element-root').innerHTML = '<div style="margin-bottom:12px;"><label>Account Holder Name</label><input id="account-holder-name"/></div><div style="margin-bottom:12px;"><label>Routing Number</label><input id="routing-number"/></div><div style="margin-bottom:12px;"><label>Account Number</label><input id="account-number"/></div>';
                        try { window.__lpe_mounted = true; window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:done', method: 'us_bank' }); } catch(e) {}
                        return {ok:true, method: 'us_bank'};
                      } else if (method === 'eu_bank') {
                        var elements = stripe.elements();
                        window.elements = elements;
                        var ibanElement = elements.create('iban');
                        window.ibanElement = ibanElement;
                        document.getElementById('element-root').innerHTML = '<div id="iban-element"></div>';
                        ibanElement.mount('#iban-element');
                        try { window.__lpe_mounted = true; window.flutter_inappwebview.callHandler('stripeCallback', { type: 'log', action: 'mount:done', method: 'eu_bank' }); } catch(e) {}
                        return {ok:true, method: 'eu_bank'};
                      }
                      return {error: 'unsupported_method'};
                    } catch (e) { return {error: String(e)}; }
                  })();
                  ''');
                  debugPrint(
                      'StripeWebview fallback mount result: $fallbackRes');

                  // Additional diagnostics: capture element-root HTML snippet,
                  // children count, and runtime Stripe objects so we can
                  // determine whether Elements actually created DOM nodes.
                  try {
                    final diag = await controller.evaluateJavascript(source: '''
                      (function(){
                        try {
                          var root = document.getElementById('element-root');
                          var html = root ? (root.innerHTML ? root.innerHTML.slice(0,800) : null) : null;
                          var children = root ? root.children.length : 0;
                          return {
                            mountedFlag: !!window.__lpe_mounted,
                            stripeType: (typeof Stripe),
                            stripeObjType: (typeof window.stripe),
                            stripeCreateToken: (window.stripe && typeof window.stripe.createToken ? 'function' : (window.stripe && window.stripe.createToken ? String(window.stripe.createToken) : null)),
                            cardElementPresent: !!window.cardElement,
                            elementRootHtmlSnippet: html,
                            elementRootChildren: children
                          };
                        } catch(e) { return { error: String(e) }; }
                      })();
                      ''');
                    debugPrint('StripeWebview fallback diagnostics: $diag');
                  } catch (e) {
                    debugPrint(
                        'StripeWebview fallback diagnostics eval failed: $e');
                  }
                } catch (e) {
                  debugPrint('StripeWebview fallback mount eval failed: $e');
                }
              }
            } catch (e) {
              debugPrint('StripeWebview injection/mount call failed: $e');
            }
          } catch (e) {
            debugPrint('StripeWebview onLoadStop eval failed: $e');
          }
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT);
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
