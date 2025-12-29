import 'package:flutter/material.dart';
import 'learmondindividualbuttons.dart';
import 'package:paysheet/paysheet.dart' show StripePaymentResult;
import 'merchant_arg_builder.dart' show buildMerchantArgs;
import 'summary_line_item.dart';

/// Composite widget that renders a compact set of payment method buttons.
class LearmondPayButtons extends StatelessWidget {
  final String? publishableKey;
  final String? clientSecret;
  final String? appleMerchantId;
  final String? googleMerchantId;
  final String? merchantName;
  final String? merchantInfo;
  final Map<String, dynamic>? merchantArgs;
  final List<SummaryLineItem>? summaryItems;
  final String amount;
  final String currency;
  final void Function(StripePaymentResult result)? onResult;
  final Future<void> Function()? onPay;
  final bool showNativePay;
  final ButtonStyle? buttonStyle;

  const LearmondPayButtons({
    super.key,
    this.publishableKey,
    this.clientSecret,
    this.appleMerchantId,
    this.googleMerchantId,
    this.merchantName,
    this.merchantInfo,
    this.merchantArgs,
    this.summaryItems,
    this.amount = '0.00',
    this.currency = 'USD',
    this.onResult,
    this.onPay,
    this.showNativePay = true,
    this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMerchantArgs = buildMerchantArgs(
      appleMerchantId: appleMerchantId,
      googleMerchantId: googleMerchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
      builder: merchantArgs,
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

    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      const horizontalPadding =
          16.0 * 2; // parent content padding on both sides
      const spacing = 8.0; // spacing between buttons
      final availableWidthForThree = screenWidth -
          horizontalPadding -
          (spacing * 2); // gaps between 3 items
      var buttonWidthThree = availableWidthForThree / 3.0;
      if (buttonWidthThree < 88.0) buttonWidthThree = 88.0;
      if (buttonWidthThree > 360.0) buttonWidthThree = 360.0;

      // Native-pay sizing: ensure minimums required by design
      final nativeHeight = 40.0;
      final nativeMinWidth =
          buttonWidthThree < 100.0 ? 100.0 : buttonWidthThree;
      final nativeSideMargin = nativeHeight * 0.1;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
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
              const SizedBox(width: 8.0),
              Expanded(
                flex: 1,
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
              const SizedBox(width: 8.0),
              Expanded(
                flex: 2,
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
                  width: nativeMinWidth,
                  child: LearmondApplePayButton(
                    publishableKey: publishableKey,
                    appleMerchantId: appleMerchantId,
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
                    publishableKey: publishableKey,
                    googleMerchantId: googleMerchantId,
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
        ],
      );
    });
  }
}
