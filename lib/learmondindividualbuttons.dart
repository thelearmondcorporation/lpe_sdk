import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Web interop helpers used to detect Apple/Google payment SDK presence.
import 'src/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'src/js_util_stub.dart' if (dart.library.js) 'dart:js_util' as js_util;
import 'package:lpe/lpe.dart' show buildMerchantArgs, SummaryLineItem;
import 'package:paysheet/paysheet.dart' show PaymentResult, Paysheet, UIAdjust;
// web_run_payment_request not required by the native-pay buttons after migration
import 'learmond_native_pay.dart' show LearmondNativePay;

const double lpeButtonWidth = 110.0;

/// Centralized result handler used by the individual buttons.
/// Calls the user callback first, then shows a SnackBar with a friendly
/// message if available.
void _handlePaymentResult(BuildContext context, PaymentResult result,
    void Function(PaymentResult)? userCallback) {
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
  final String? apiKey;
  final String? clientSecret;
  final String amount;
  final void Function(PaymentResult)? onResult;
  final Future<void> Function()? onPay;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondCardButton({
    super.key,
    this.apiKey,
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
        onPressed: () async {
          final numberCtrl = TextEditingController();
          final expiryCtrl = TextEditingController();
          final cvcCtrl = TextEditingController();

          final uiAdjust = UIAdjust(u: [
            const SizedBox(height: 8),
            const Text('Card Details',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: numberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Card number',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: expiryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'MM/YY',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: cvcCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
          ]);
          final result = await Paysheet.instance.present(
            context,
            method: 'card',
            amount: amount,
            merchantArgs: _buildMerchantArgs(),
            uiAdjust: uiAdjust,
            mountOnShow: true,
            onPay: onPay,
          );
          if (result != null) _handlePaymentResult(context, result, onResult);
        },
        style: style,
        child: Text(label ?? 'Card'),
      ),
    );
  }
}

/// Button: US Bank
class LearmondUSBankButton extends StatelessWidget {
  final String? apiKey;
  final String? clientSecret;
  final String amount;
  final void Function(PaymentResult)? onResult;
  final Future<void> Function()? onPay;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondUSBankButton({
    super.key,
    this.apiKey,
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
        onPressed: () async {
          final routingCtrl = TextEditingController();
          final accountCtrl = TextEditingController();

          final uiAdjust = UIAdjust(u: [
            const SizedBox(height: 8),
            const Text('Bank Account',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: routingCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Routing Number',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: accountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Account Number',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 0),
          ]);
          final result = await Paysheet.instance.present(
            context,
            method: 'us_bank',
            amount: amount,
            merchantArgs: _buildMerchantArgs(),
            uiAdjust: uiAdjust,
            mountOnShow: true,
            onPay: onPay,
          );
          if (result != null) _handlePaymentResult(context, result, onResult);
        },
        style: style,
        child: Text(label ?? 'US Bank'),
      ),
    );
  }
}

/// Button: EU Bank (IBAN)
class LearmondEUBankButton extends StatelessWidget {
  final String? apiKey;
  final String? clientSecret;
  final String amount;
  final void Function(PaymentResult)? onResult;
  final Future<void> Function()? onPay;
  final ButtonStyle? buttonStyle;
  final String? label;
  final Map<String, dynamic>? merchantArgs;
  final String? merchantName;
  final String? merchantInfo;
  final List<SummaryLineItem>? summaryItems;

  const LearmondEUBankButton({
    super.key,
    this.apiKey,
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
        onPressed: () async {
          final ibanCtrl = TextEditingController();

          final uiAdjust = UIAdjust(u: [
            const SizedBox(height: 8),
            const Text('SEPA', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: ibanCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                hintText: 'DE89 3704 0044 0532 0130 00',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 0),
          ]);
          final result = await Paysheet.instance.present(
            context,
            method: 'eu_bank',
            amount: amount,
            merchantArgs: _buildMerchantArgs(),
            uiAdjust: uiAdjust,
            mountOnShow: true,
            onPay: onPay,
          );
          if (result != null) _handlePaymentResult(context, result, onResult);
        },
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
  final String? apiKey;
  final String? appleMerchantId;
  final String? merchantName;
  final String? merchantInfo;
  final String amount;
  final String currency;
  final void Function(PaymentResult)? onResult;
  final Future<void> Function()? onPay;
  final ButtonStyle? buttonStyle;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;

  const LearmondApplePayButton({
    super.key,
    this.apiKey,
    this.appleMerchantId,
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
            merchantId: appleMerchantId,
            merchantName: merchantName,
            merchantInfo: merchantInfo,
            summaryItems: summaryItems,
            builder: merchantArgs,
          );
          final double amt = double.tryParse(amount) ?? 0.0;
          final int amountCents = (amt * 100).round();
          final args = <String, dynamic>{
            'method': 'apple_pay',
            'apiKey': apiKey ?? '',
            'merchantArgs': margs ?? <String, dynamic>{},
            'amountCents': amountCents,
            'amount': amount,
            'currency': currency,
            'merchantId': appleMerchantId,
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
  final String? apiKey;
  final String? googleMerchantId;
  final String? merchantName;
  final String? merchantInfo;
  final String amount;
  final String currency;
  final void Function(PaymentResult)? onResult;
  final Future<void> Function()? onPay;
  final ButtonStyle? buttonStyle;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;

  const LearmondGooglePayButton({
    super.key,
    this.apiKey,
    this.googleMerchantId,
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
              gatewayMerchantId: googleMerchantId,
              merchantName: merchantName,
              merchantInfo: merchantInfo,
              summaryItems: summaryItems,
              builder: merchantArgs,
            );
            final double amt = double.tryParse(amount) ?? 0.0;
            final int amountCents = (amt * 100).round();
            final args = <String, dynamic>{
              'method': 'google_pay',
              'apiKey': apiKey ?? '',
              'merchantArgs': margs ?? <String, dynamic>{},
              'amountCents': amountCents,
              'amount': amount,
              'currency': currency,
              'googleMerchantId': googleMerchantId,
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
