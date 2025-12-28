import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'LPE SDK Example',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LPE SDK Example')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Show Pay Sheet'),
          onPressed: () async {
            final result = await showLpePaysheet(
              context,
              publishableKey: 'pk_test_...', // Replace with your key
              clientSecret: 'pi_..._secret_...', // Replace with your secret
              method: 'card',
              amount: '10.00',
            );
            if (context.mounted) {
              final success = result?.success == true;
              final message = success
                  ? 'Payment succeeded!'
                  : 'Payment failed: ${result?.errorMessage ?? (result?.error ?? 'Unknown error').replaceAll('_', ' ')}';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
