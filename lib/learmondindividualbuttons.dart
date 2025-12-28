import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Web interop helpers used to detect Apple/Google payment SDK presence.
import 'src/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'src/js_util_stub.dart' if (dart.library.js) 'dart:js_util' as js_util;
import 'merchant_arg_builder.dart';
import 'summary_line_item.dart';
import 'package:paysheet/paysheet.dart'
    show StripePaymentResult, showLpePaysheet, computeEffectiveMerchantArgs;
// web_run_payment_request not required by the native-pay buttons after migration
import 'learmond_native_pay.dart' show LearmondNativePay;

const double lpeButtonWidth = 110.0;

/// Centralized result handler used by the individual buttons.
/// Calls the user callback first, then shows a SnackBar with a friendly
/// message if available.
void _handlePaymentResult(BuildContext context, StripePaymentResult result,
    void Function(StripePaymentResult)? userCallback) {
  try {
    if (userCallback != null) {
      userCallback(result);
    }
  } catch (e) {
    debugPrint('User onResult callback threw: $e');
  }

  final message = result.errorMessage ?? result.error ?? '';
  if (message.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Button: Card
class LearmondCardButton extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String amount;
  final void Function(StripePaymentResult)? onResult;
  final Future<void> Function()? onPay;
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
    this.onPay,
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
        onPressed: () => showLpePaysheet(
          context,
          method: 'card',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onPay: onPay,
          onResult: (result) => _handlePaymentResult(context, result, onResult),
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
  final Future<void> Function()? onPay;
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
    this.onPay,
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
        onPressed: () => showLpePaysheet(
          context,
          method: 'us_bank',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onPay: onPay,
          onResult: (result) => _handlePaymentResult(context, result, onResult),
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
  final Future<void> Function()? onPay;
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
    this.onPay,
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
        onPressed: () => showLpePaysheet(
          context,
          method: 'eu_bank',
          publishableKey: publishableKey ?? '',
          clientSecret: clientSecret ?? '',
          amount: amount,
          merchantArgs: _buildMerchantArgs(),
          mountOnShow: true,
          onPay: onPay,
          onResult: (result) => _handlePaymentResult(context, result, onResult),
        ),
        style: style,
        child: Center(
          child: Text(
            label ?? 'EU Bank (IBAN)',
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
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
  final Future<void> Function()? onPay;
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
    this.onPay,
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
        onPressed: () async {
          final margs = buildMerchantArgs(
            merchantId: merchantId,
            merchantName: merchantName,
            merchantInfo: merchantInfo,
            summaryItems: summaryItems,
            builder: merchantArgs,
          );
          final double amt = double.tryParse(amount) ?? 0.0;
          final int amountCents = (amt * 100).round();
          final args = <String, dynamic>{
            'method': 'apple_pay',
            'publishableKey': publishableKey ?? '',
            'merchantArgs': margs ?? <String, dynamic>{},
            'amountCents': amountCents,
            'amount': amount,
            'currency': currency,
            'merchantId': merchantId,
          };
          final result = await LearmondNativePay.showNativePay(args);
          _handlePaymentResult(context, result, onResult);
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
  final Future<void> Function()? onPay;
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
    this.onPay,
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
          onPressed: () async {
            // On web, avoid invoking the Google Pay / PaymentRequest flow
            // when Safari / ApplePaySession is present but the Google Pay
            // JS SDK is not available. Safari will attempt to start an
            // Apple Pay session which requires merchant validation and
            // a secure context; to prevent the "insecure button" error
            // we show a friendly message instead of starting the flow.
            if (kIsWeb) {
              try {
                final hasApple =
                    js_util.hasProperty(html.window, 'ApplePaySession');
                final hasGoogle = js_util.hasProperty(html.window, 'google') &&
                    js_util.hasProperty(
                        js_util.getProperty(html.window, 'google'), 'payments');
                if (hasApple && !hasGoogle) {
                  // Inform the user/developer that Google Pay isn't available
                  // on this browser and Apple Pay requires merchant validation.
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Payment Unavailable'),
                      content: const Text(
                          'This browser supports Apple Pay but Google Pay is not available. Apple Pay requires merchant validation and a secure (HTTPS) origin. Use Chrome/Edge for Google Pay, or configure Apple Pay merchant validation for this domain.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('OK'))
                      ],
                    ),
                  );
                  return;
                }
              } catch (_) {}
            }
            final margs = buildMerchantArgs(
              gatewayMerchantId: googleGatewayMerchantId,
              merchantName: merchantName,
              merchantInfo: merchantInfo,
              summaryItems: summaryItems,
              builder: merchantArgs,
            );
            final double amt = double.tryParse(amount) ?? 0.0;
            final int amountCents = (amt * 100).round();
            final args = <String, dynamic>{
              'method': 'google_pay',
              'publishableKey': publishableKey ?? '',
              'merchantArgs': margs ?? <String, dynamic>{},
              'amountCents': amountCents,
              'amount': amount,
              'currency': currency,
              'gatewayMerchantId': googleGatewayMerchantId,
            };
            final result = await LearmondNativePay.showNativePay(args);
            _handlePaymentResult(context, result, onResult);
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
  final Future<void> Function()? onPay;
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
    this.onPay,
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

    final effectiveMerchantArgs = computeEffectiveMerchantArgs(
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
                  onPay: onPay,
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
                  onPay: onPay,
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
                  onPay: onPay,
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
                onPay: onPay,
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
                onPay: onPay,
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
