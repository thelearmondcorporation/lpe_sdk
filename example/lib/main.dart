import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart';
// Removed unused imports: dart:convert and http; add them when implementing server calls

void main() {
  // Initialize default merchant identifiers for the example app so the
  // `LearmondPayButtons` and native pay flows have default values if not
  // provided explicitly by the caller.
  LpeSDKConfig.init(
    appleMerchantId: 'merchant.com.example',
    googleGatewayMerchantId: 'yourGatewayMerchantId',
  );
  runApp(const ExampleApp());
}

// Note: You may call `LpeSDKConfig.init(...)` at app startup to set defaults
// for Apple/Google merchant ids. Example usage is shown above in `main()`.

class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPE SDK Example',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = buildMerchantArgs(
      merchantId: 'merchant.com.example.merchant',
      merchantName: 'Example Merchant',
      merchantInfo: 'Example Transaction',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LPE SDK Example')),
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LearmondApplePayButton(
              merchantId:
                  args?['merchantId'] ?? 'merchant.com.learmond.merchant.brand',
              merchantArgs: args,
              amount: '10.00',
              currency: 'USD',
              onResult: null,
            ),
            const SizedBox(width: 12),
            LearmondGooglePayButton(
              googleGatewayMerchantId: args?['gatewayMerchantId'] as String?,
              merchantArgs: args,
              amount: '10.00',
              currency: 'USD',
              onResult: null,
            ),
          ],
        ),
      ),
    );
  }
}
