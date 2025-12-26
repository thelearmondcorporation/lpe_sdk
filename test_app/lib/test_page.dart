import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart';
import 'package:lpe_sdk/learmond_individual_button_source_pay_button.dart';

class MerchantArgsStore extends ChangeNotifier {
  Map<String, dynamic>? _merchantArgs;
  Map<String, dynamic>? get merchantArgs => _merchantArgs;

  void setMerchantArgs(Map<String, dynamic>? args) {
    _merchantArgs = args;
    notifyListeners();
  }
}

final merchantArgsStore = MerchantArgsStore();

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LPE Test App'),
        leading: IconButton(
          icon: const Text(
            'MA',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          tooltip: 'Merchant Args',
          onPressed: () {
            Learmond.instance.presentMerchantArgs(
              context: context,
              initialArgs: merchantArgsStore.merchantArgs,
              onSubmit: (args) {
                merchantArgsStore.setMerchantArgs(args);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved merchantArgs: ${args ?? '{}'}'),
                  ),
                );
              },
            );
          },
        ),
      ),
      body: AnimatedBuilder(
        animation: merchantArgsStore,
        builder: (context, _) {
          final args =
              merchantArgsStore.merchantArgs ??
              buildMerchantArgs(
                merchantId: 'merchant.com.learmond.merchant.brand',
                merchantName: 'The Learmond Corporation',
                merchantInfo: 'Test Transaction',
              );
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LearmondCardButton(
                      publishableKey: 'pk_test_12345',
                      amount: '23.35',
                      merchantArgs: args,
                      onResult: (res) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.success
                                  ? 'Payment flow succeeded'
                                  : (res.errorMessage ??
                                        res.error ??
                                        'Payment failed'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    LearmondApplePayButton(
                      merchantId:
                          args?['merchantId'] ??
                          'merchant.com.learmond.merchant.brand',
                      merchantArgs: args,
                      amount: '10.00',
                      currency: 'USD',
                      onResult: null,
                    ),
                    const SizedBox(width: 12),
                    LearmondGooglePayButton(
                      googleGatewayMerchantId:
                          args?['gatewayMerchantId'] as String?,
                      merchantArgs: args,
                      amount: '23.35',
                      currency: 'USD',
                      onResult: null,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LearmondEUBankButton(
                      publishableKey: 'pk_test_12345',
                      amount: '10.00',
                      merchantArgs: args,
                      onResult: (res) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.success
                                  ? 'Bank flow succeeded'
                                  : (res.errorMessage ??
                                        res.error ??
                                        'Bank flow failed'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    LearmondUSBankButton(
                      publishableKey: 'pk_test_12345',
                      amount: '10.00',
                      merchantArgs: args,
                      onResult: (res) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.success
                                  ? 'US Bank flow succeeded'
                                  : (res.errorMessage ??
                                        res.error ??
                                        'US Bank flow failed'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    LearmondSourcePayButton(
                      publishableKey: 'pk_test_12345',
                      merchantId: args?['merchantId'] as String?,
                      merchantArgs: args,
                      amount: '10.00',
                      currency: 'USD',
                      onResult: (res) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.success
                                  ? 'Source Pay succeeded'
                                  : (res.errorMessage ??
                                        res.error ??
                                        'Source Pay failed'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      // Merchant args editing is available via the MA button in the AppBar
    );
  }
}
