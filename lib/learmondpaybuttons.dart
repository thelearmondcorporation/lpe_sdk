import 'package:flutter/material.dart';
import 'learmondindividualbuttons.dart';
import 'paysheet.dart' show StripePaymentResult, computeEffectiveMerchantArgs;
import 'summary_line_item.dart';

/// Composite widget that renders a compact set of payment method buttons.
class LearmondPayButtons extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String? merchantId;
  final String? googleGatewayMerchantId;
  final String? merchantName;
  final String? merchantInfo;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;
  final String amount;
  final String currency;
  final void Function(StripePaymentResult result)? onResult;
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
    final effectiveMerchantArgs = computeEffectiveMerchantArgs(
      merchantArgs: merchantArgs,
      amount: amount,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );

    final style = buttonStyle ??
        ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14.0),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
          shadowColor: Colors.black12,
          minimumSize: const Size(56, 40),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: lpeButtonWidth,
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
              width: lpeButtonWidth,
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
              width: lpeButtonWidth,
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
                        const EdgeInsets.symmetric(horizontal: 4.0)),
                    minimumSize: WidgetStateProperty.all(
                        const Size(lpeButtonWidth, 40.0)),
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
                        const EdgeInsets.symmetric(horizontal: 4.0)),
                    minimumSize: WidgetStateProperty.all(
                        const Size(lpeButtonWidth, 40.0)),
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
