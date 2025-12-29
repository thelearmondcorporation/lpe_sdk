import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LPE Test App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Builder(
            builder: (ctx) {
              final args = buildMerchantArgs(
                merchantName: 'Your Name',
                merchantInfo: 'Test Transaction',
                summaryItems: const [
                  SummaryLineItem(label: 'Subtotal', amountCents: 2000),
                  SummaryLineItem(label: 'Tax', amountCents: 335),
                  SummaryLineItem(label: 'Total', amountCents: 2335),
                ],
              );
              return Learmond.instance.presentApplePayButton(
                context: ctx,
                publishableKey: 'pk_test_12345',
                amount: '23.35',
                merchantArgs: args,
                onResult: (res) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        res.success
                            ? 'Payment succeeded'
                            : (res.errorMessage ??
                                  res.error ??
                                  'Payment failed'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
