import 'package:flutter/material.dart';

import 'merchant_arg_builder.dart';
import 'package:paysheet/paysheet.dart'
    show StripePaymentResult, showLpePaysheet;
import 'summary_line_item.dart' show SummaryLineItem;
import 'learmondindividualbuttons.dart' show lpeButtonWidth;

/// Learmond Source Pay button — matches individual button sizing and style.
class LearmondSourcePayButton extends StatelessWidget {
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

  const LearmondSourcePayButton({
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
        onPressed: () {
          final margs = buildMerchantArgs(
            merchantId: merchantId,
            merchantName: merchantName,
            merchantInfo: merchantInfo,
            summaryItems: summaryItems,
            builder: merchantArgs,
          );

          showLpePaysheet(
            context,
            method: 'source_pay',
            publishableKey: publishableKey ?? '',
            clientSecret: '',
            amount: amount,
            merchantArgs: margs,
            mountOnShow: true,
            onPay: onPay,
            onResult: (result) {
              try {
                if (onResult != null) onResult!(result);
              } catch (_) {}
              final message = result.errorMessage ?? result.error ?? '';
              if (message.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
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
              child: SizedBox(
                width: 20,
                height: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    // ignore: prefer_const_constructors
                    border: Border.all(color: Color(0xFFFFD700), width: 1.5),
                  ),
                  child: const Center(
                    child: const Text(
                      'S',
                      style: const TextStyle(
                        color: const Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Text('Pay'),
          ],
        ),
      ),
    );
  }
}
