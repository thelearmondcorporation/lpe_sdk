// Singleton entry point for presenting Learmond Pay UI elements programmatically.

// Example usage:
//   Learmond.instance.presentLearmondPayButtons(context: ..., ...);
//   Learmond.instance.presentCardButton(context: ..., ...);

import 'package:flutter/material.dart';
import 'lpe_sdk.dart';

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

  // presentCardButton removed; use the `LearmondCardButton` widget directly in your UI or the `LearmondPayButtons` composite.

  // presentUSBankButton removed; use the `LearmondUSBankButton` widget directly in your UI or the `LearmondPayButtons` composite.

  // presentEUBankButton removed; use the `LearmondEUBankButton` widget directly in your UI or the `LearmondPayButtons` composite.

  // presentApplePayButton removed; use the `LearmondApplePayButton` widget directly in your UI or the `LearmondPayButtons` composite.

  // presentGooglePayButton removed; use the `LearmondGooglePayButton` widget directly in your UI or the `LearmondPayButtons` composite.
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
