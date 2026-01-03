import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LPE Test App')),
      body: Builder(
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
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Methods',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      LearmondCardButton(
                        apiKey: 'pk_test_12345',
                        merchantArgs: args,
                        amount: '23.35',
                        onResult: (res) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res.success ? 'Success' : 'Failed'),
                            ),
                          );
                        },
                      ),
                      LearmondUSBankButton(
                        apiKey: 'pk_test_12345',
                        merchantArgs: args,
                        amount: '23.35',
                        onResult: (res) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res.success ? 'Success' : 'Failed'),
                            ),
                          );
                        },
                      ),
                      LearmondEUBankButton(
                        apiKey: 'pk_test_12345',
                        merchantArgs: args,
                        amount: '23.35',
                        onResult: (res) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res.success ? 'Success' : 'Failed'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LearmondApplePayButton(
                        apiKey: 'pk_test_12345',
                        appleMerchantId: 'merchant.com.example',
                        merchantArgs: args,
                        amount: '23.35',
                        onResult: (res) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res.success ? 'Success' : 'Failed'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      LearmondGooglePayButton(
                        apiKey: 'pk_test_12345',
                        googleMerchantId: 'gateway_merchant_id',
                        merchantArgs: args,
                        amount: '23.35',
                        onResult: (res) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res.success ? 'Success' : 'Failed'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
