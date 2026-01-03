// Singleton entry point for presenting Learmond Pay UI elements programmatically.
//
// Usage
// - Present the composite pay buttons sheet (compact set of payment methods):
//     Learmond.instance.presentLearmondPayButtons(
//       context: context,
//       amount: '12.34',
//       merchantArgs: buildMerchantArgs(...),
//     );
//
// - Present the individual buttons group (same buttons arranged together):
//     Learmond.instance.presentIndividualButtons(
//       context: context,
//       amount: '12.34',
//       merchantArgs: buildMerchantArgs(...),
//     );
//
// - Present a single button programmatically (examples):
//     Learmond.instance.presentCardButton(context: context, amount: '12.34', merchantArgs: ...);
//     Learmond.instance.presentUSBankButton(context: context, amount: '10.00', merchantArgs: ...);
//     Learmond.instance.presentEUBankButton(context: context, amount: '10.00', merchantArgs: ...);
//     Learmond.instance.presentApplePayButton(context: context, appleMerchantId: 'merchant.com.yourdomain', amount: '9.99', merchantArgs: ...);
//     Learmond.instance.presentGooglePayButton(context: context, googleMerchantId: '0123456789', amount: '9.99', merchantArgs: ...);
//     Learmond.instance.presentSourcePayButton(context: context, sourceAccountId: 'acct_123', amount: '5.00', merchantArgs: ...);
//
// Notes:
// - To show summary line items in the paysheet, pass `merchantArgs` produced by
//   `buildMerchantArgs(...)` (summary lines appear under the `summaryItems` key).
// - Set SDK defaults with `LpeSDKConfig.init(...)` at app startup (apple/google ids,
//   default merchant name/info).

import 'package:flutter/material.dart';
import 'package:lpe/lpe.dart'
    show LearmondPayButtons, buildMerchantArgs, SummaryLineItem;
import 'lpe_sdk_config.dart' show LpeSDKConfig;
import 'learmondindividualbuttons.dart'
    show
        LearmondCardButton,
        LearmondUSBankButton,
        LearmondEUBankButton,
        LearmondApplePayButton,
        LearmondGooglePayButton;
import 'learmond_individual_button_source_pay_button.dart'
    show LearmondSourcePayButton;

import 'package:paysheet/paysheet.dart' show PaymentResult;

class Learmond {
  Learmond._private();
  static final Learmond instance = Learmond._private();

  /// Presents a modal sheet for entering merchantArgs (name, info, multiple line items).
  Future<void> presentMerchantArgs({
    required BuildContext context,
    void Function(Map<String, dynamic>? merchantArgs)? onSubmit,
    Map<String, dynamic>? initialArgs,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _MerchantArgsSheet(onSubmit: onSubmit, initialArgs: initialArgs),
    );
  }

  /// Presents the composite `LearmondPayButtons` widget in a bottom sheet.
  Widget presentLearmondPayButtons({
    required BuildContext context,
    String? apiKey,
    String? clientSecret,
    String? appleMerchantId,
    String? googleMerchantId,
    Map<String, dynamic>? merchantArgs,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
    String amount = '0.00',
    String currency = 'USD',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    bool showNativePay = true,
    ButtonStyle? buttonStyle,
  }) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: LearmondPayButtons(
        apiKey: apiKey,
        appleMerchantId: appleMerchantId ?? LpeSDKConfig.appleMerchantId,
        googleMerchantId: googleMerchantId ?? LpeSDKConfig.googleMerchantId,
        merchantArgs: merchantArgs,
        merchantName: merchantName,
        merchantInfo: merchantInfo,
        summaryItems: summaryItems,
        amount: amount,
        currency: currency,
        onResult: onResult == null
            ? null
            : (dynamic r) => onResult(r as PaymentResult),
        onPay: onPay,
        showNativePay: showNativePay,
        buttonStyle: buttonStyle,
      ),
    );
  }

  /// Presents the `LearmondIndividualButtons` composite in a bottom sheet.
  Widget presentIndividualButtons({
    required BuildContext context,
    String? apiKey,
    String? clientSecret,
    String? appleMerchantId,
    String? googleMerchantId,
    Map<String, dynamic>? merchantArgs,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
    String amount = '0.00',
    String currency = 'USD',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
  }) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: LearmondPayButtons(
        apiKey: apiKey,
        appleMerchantId: appleMerchantId ?? LpeSDKConfig.appleMerchantId,
        googleMerchantId: googleMerchantId ?? LpeSDKConfig.googleMerchantId,
        merchantArgs: merchantArgs,
        merchantName: merchantName,
        merchantInfo: merchantInfo,
        summaryItems: summaryItems,
        amount: amount,
        currency: currency,
        onResult: onResult == null
            ? null
            : (dynamic r) => onResult(r as PaymentResult),
        onPay: onPay,
        buttonStyle: buttonStyle,
      ),
    );
  }

  /// Returns a configured `LearmondCardButton` widget.
  ///
  /// Note: this keeps the same parameter list as the previous presenter
  /// so callers that used `Learmond.instance.presentCardButton(...)` inside
  /// build() can now `return Learmond.instance.presentCardButton(...)`.
  Widget presentCardButton({
    required BuildContext context,
    String? apiKey,
    String? clientSecret,
    String amount = '0.00',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
    Map<String, dynamic>? merchantArgs,
    String? label,
  }) {
    return LearmondCardButton(
      apiKey: apiKey,
      clientSecret: clientSecret,
      amount: amount,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      label: label,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );
  }

  Widget presentUSBankButton({
    required BuildContext context,
    String? apiKey,
    String? clientSecret,
    String amount = '0.00',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    String? label,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
    Map<String, dynamic>? merchantArgs,
  }) {
    return LearmondUSBankButton(
      apiKey: apiKey,
      clientSecret: clientSecret,
      amount: amount,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      label: label,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );
  }

  Widget presentEUBankButton({
    required BuildContext context,
    String? apiKey,
    String? clientSecret,
    String amount = '0.00',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    String? label,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
    Map<String, dynamic>? merchantArgs,
  }) {
    return LearmondEUBankButton(
      apiKey: apiKey,
      clientSecret: clientSecret,
      amount: amount,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      label: label,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );
  }

  Widget presentApplePayButton({
    required BuildContext context,
    String? apiKey,
    String? appleMerchantId,
    String amount = '0.00',
    String currency = 'USD',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    Map<String, dynamic>? merchantArgs,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
  }) {
    return LearmondApplePayButton(
      apiKey: apiKey,
      appleMerchantId: appleMerchantId ?? LpeSDKConfig.appleMerchantId,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      amount: amount,
      currency: currency,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      summaryItems: summaryItems,
    );
  }

  Widget presentGooglePayButton({
    required BuildContext context,
    String? apiKey,
    String? googleMerchantId,
    String amount = '0.00',
    String currency = 'USD',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    Map<String, dynamic>? merchantArgs,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
  }) {
    return LearmondGooglePayButton(
      apiKey: apiKey,
      googleMerchantId: googleMerchantId ?? LpeSDKConfig.googleMerchantId,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      amount: amount,
      currency: currency,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      summaryItems: summaryItems,
    );
  }

  Widget presentSourcePayButton({
    required BuildContext context,
    String? apiKey,
    String? sourceAccountId,
    String amount = '0.00',
    String currency = 'USD',
    void Function(PaymentResult result)? onResult,
    Future<void> Function()? onPay,
    ButtonStyle? buttonStyle,
    Map<String, dynamic>? merchantArgs,
    String? merchantName,
    String? merchantInfo,
    List<SummaryLineItem>? summaryItems,
  }) {
    return LearmondSourcePayButton(
      apiKey: apiKey,
      sourceAccountId: sourceAccountId,
      amount: amount,
      onResult: onResult,
      onPay: onPay,
      buttonStyle: buttonStyle,
      merchantArgs: merchantArgs,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      summaryItems: summaryItems,
    );
  }
}

// --- MerchantArgsSheet widget ---
class _MerchantArgsSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>? merchantArgs)? onSubmit;
  final Map<String, dynamic>? initialArgs;
  const _MerchantArgsSheet({this.onSubmit, this.initialArgs});

  @override
  State<_MerchantArgsSheet> createState() => _MerchantArgsSheetState();
}

class _MerchantArgsSheetState extends State<_MerchantArgsSheet> {
  final _nameCtrl = TextEditingController();
  final _infoCtrl = TextEditingController();
  final List<TextEditingController> _labelCtrls = [TextEditingController()];
  final List<TextEditingController> _amountCtrls = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    final args = widget.initialArgs;
    if (args != null) {
      _nameCtrl.text = (args['merchantName'] ?? '') as String;
      _infoCtrl.text = (args['merchantInfo'] ?? '') as String;
      final summary = args['summaryItems'];
      if (summary is List && summary.isNotEmpty) {
        _labelCtrls.clear();
        _amountCtrls.clear();
        for (final s in summary) {
          final label =
              (s is Map && s['label'] != null) ? s['label'].toString() : '';
          final cents = (s is Map && s['amountCents'] != null)
              ? int.tryParse(s['amountCents'].toString()) ?? 0
              : 0;
          final dollars = (cents / 100).toStringAsFixed(2);
          _labelCtrls.add(TextEditingController(text: label));
          _amountCtrls.add(TextEditingController(text: dollars));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _infoCtrl.dispose();
    for (final c in _labelCtrls) {
      c.dispose();
    }
    for (final c in _amountCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _labelCtrls.add(TextEditingController());
      _amountCtrls.add(TextEditingController());
    });
  }

  void _removeLineItem(int i) {
    setState(() {
      if (_labelCtrls.length > 1) _labelCtrls.removeAt(i);
      if (_amountCtrls.length > 1) _amountCtrls.removeAt(i);
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final info = _infoCtrl.text.trim();
    final items = <SummaryLineItem>[];
    for (var i = 0; i < _labelCtrls.length; i++) {
      final label = _labelCtrls[i].text.trim();
      final raw = _amountCtrls[i].text.trim().replaceAll(',', '');
      final dollars = double.tryParse(raw) ?? 0.0;
      final amountCents = (dollars * 100).round();
      if (label.isNotEmpty) {
        items.add(SummaryLineItem(label: label, amountCents: amountCents));
      }
    }
    final args = buildMerchantArgs(
      merchantName: name.isEmpty ? null : name,
      merchantInfo: info.isEmpty ? null : info,
      summaryItems: items.isEmpty ? null : items,
    );
    widget.onSubmit?.call(args);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Merchant Args',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Merchant Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _infoCtrl,
              decoration: const InputDecoration(labelText: 'Merchant Info'),
            ),
            const SizedBox(height: 16),
            const Text('Line Items',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate(
                _labelCtrls.length,
                (i) => Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _labelCtrls[i],
                            decoration:
                                const InputDecoration(labelText: 'Label'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _amountCtrls[i],
                            decoration: const InputDecoration(
                                labelText: 'Amount (dollars)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _labelCtrls.length > 1
                              ? () => _removeLineItem(i)
                              : null,
                        ),
                      ],
                    )),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Line Item'),
                onPressed: _addLineItem,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
