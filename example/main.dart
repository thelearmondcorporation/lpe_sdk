import 'package:flutter/material.dart';
import 'package:lpe_sdk/lpe_sdk.dart' show Learmond;

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
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => Learmond.instance.presentLearmondPayButtons(
                context: ctx,
                apiKey: 'api_test_1234567890',
                amount: '10.00',
              ),
            );
          },
        ),
      ),
    );
  }
}
