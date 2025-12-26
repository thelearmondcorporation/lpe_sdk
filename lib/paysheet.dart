import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter/services.dart';
import 'merchant_arg_builder.dart';
import 'summary_line_item.dart';
import 'learmondindividualbuttons.dart' show lpeButtonWidth;

/// Clean, minimal paysheet implementation for the SDK.

class StripePaymentResult {
  final bool success;
  final String? status;
  final String? paymentIntentId;
  final String? error;
  final String? errorMessage;
  final dynamic rawResult;

  const StripePaymentResult({
    required this.success,
    this.status,
    this.paymentIntentId,
    this.error,
    this.errorMessage,
    this.rawResult,
  });
}

/// Simple Flutter-only card input used as an Android fallback when the
/// native `stripe.CardField` platform view cannot be mounted.
// Native `stripe.CardField` is used for card entry. A Flutter-only fallback
// was previously added for Android; it has been removed to rely on the
// platform view implementation directly.

int amountToCents(double amount) => (amount * 100).round();

String _formatAmountFromCents(int cents, {String currency = 'USD'}) {
  final dollars = (cents / 100).toStringAsFixed(2);
  if (currency.toUpperCase() == 'USD') return '\$' + dollars;
  return '$dollars $currency';
}

Map<String, dynamic> computeEffectiveMerchantArgs({
  Map<String, dynamic>? merchantArgs,
  String? amount,
  String? merchantId,
  String? merchantName,
  String? merchantInfo,
  List<SummaryLineItem>? summaryItems,
  String? currency,
}) {
  if (merchantArgs != null) return merchantArgs;
  if (amount != null) {
    final m = buildMerchantArgsFromAmount(
      amount: amount,
      merchantId: merchantId,
      merchantName: merchantName,
      merchantInfo: merchantInfo,
      extraSummaryItems: summaryItems,
    );
    return m ?? <String, dynamic>{};
  }
  final m2 = buildMerchantArgs(
    merchantId: merchantId,
    merchantName: merchantName,
    merchantInfo: merchantInfo,
    summaryItems: summaryItems,
  );
  return m2 ?? <String, dynamic>{};
}

Future<StripePaymentResult?> showLpePaysheet(
  BuildContext context, {
  required String publishableKey,
  String? clientSecret,
  required String method,
  String? amount,
  Map<String, dynamic>? merchantArgs,
  bool mountOnShow = false,
  bool enableStripeJs = false,
  void Function(StripePaymentResult)? onResult,
}) async {
  // Configure Stripe publishable key at runtime if provided
  try {
    stripe.Stripe.publishableKey = publishableKey;
  } catch (_) {}

  return showModalBottomSheet<StripePaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: _NativePaysheet(
              method: method,
              clientSecret: clientSecret,
              amount: amount,
              merchantArgs: merchantArgs,
              scrollController: scrollController,
              onResult: (r) {
                onResult?.call(r);
              },
            ),
          );
        },
      );
    },
  );
}

String _formatWebError(String? err) {
  if (err == null) return 'An unknown error occurred.';
  final s = err.trim();
  // Map known codes to user-friendly sentences
  const Map<String, String> map = {
    'unsupported_method': 'This payment method is not supported.',
    'stripe_load_error': 'Failed to load Stripe.js.',
    'stripe_error': 'A Stripe error occurred.',
    'native_pay_not_implemented':
        'Native pay is not implemented on this platform.',
  };
  if (map.containsKey(s)) return map[s]!;
  // If it looks like a snake_case code, convert to sentence
  if (RegExp(r'^[a-z0-9_]+$').hasMatch(s)) {
    final spaced = s.replaceAll('_', ' ');
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}.';
  }
  // Otherwise assume it's already a readable message
  return s;
}

/// Backwards-compatible shim classes (small surface area)
class LearmondNativePay {
  static const MethodChannel _channel = MethodChannel('lpe/native_pay');

  /// Presents native device pay UI using platform plugin and returns a [StripePaymentResult].
  static Future<StripePaymentResult> showNativePay(
      Map<String, dynamic> args) async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('presentNativePay', args);
      if (res == null) {
        return const StripePaymentResult(
            success: false,
            error: 'no_response',
            errorMessage: 'No response from native pay');
      }

      final bool success = res['success'] == true;
      final String? error = res['error']?.toString();
      final Map<String, dynamic>? raw =
          res['raw'] != null ? Map<String, dynamic>.from(res['raw']) : null;
      final friendly = _formatWebError(error);
      return StripePaymentResult(
          success: success,
          error: error,
          errorMessage: friendly,
          rawResult: raw);
    } on PlatformException catch (e) {
      final msg = e.message?.toString();
      return StripePaymentResult(
          success: false, error: msg, errorMessage: _formatWebError(msg));
    } catch (e) {
      final s = e.toString();
      return StripePaymentResult(
          success: false, error: s, errorMessage: _formatWebError(s));
    }
  }
}

class LearmondPaySheet {
  static Future<StripePaymentResult> show({
    required BuildContext context,
    required String publishableKey,
    required String clientSecret,
    Map<String, dynamic>? merchantArgs,
    String method = 'card',
    String? title,
    String? amount,
    String? buttonLabel,
    bool mountOnShow = false,
    bool enableStripeJs = false,
  }) async {
    final res = await showLpePaysheet(
      context,
      publishableKey: publishableKey,
      clientSecret: clientSecret,
      method: method,
      amount: amount,
      merchantArgs: merchantArgs,
      mountOnShow: mountOnShow,
      enableStripeJs: enableStripeJs,
    );
    return res ?? const StripePaymentResult(success: false, error: 'dismissed');
  }
}

/// Top-level helper to invoke native-pay integrations. This wraps the
/// platform shim `LearmondNativePay.showNativePay` and normalizes the
/// arguments used by the button widgets.
Future<void> showLpeNativePay(
  BuildContext context, {
  required String method,
  String? publishableKey,
  String? merchantId,
  String? googleGatewayMerchantId,
  Map<String, dynamic>? merchantArgsParam,
  required String amount,
  required String currency,
  required void Function(StripePaymentResult) onResult,
}) async {
  final args = <String, dynamic>{
    'method': method,
    if (publishableKey != null) 'publishableKey': publishableKey,
    if (merchantId != null) 'merchantId': merchantId,
    if (googleGatewayMerchantId != null)
      'googleGatewayMerchantId': googleGatewayMerchantId,
    'merchantArgs': merchantArgsParam ?? {},
    'amount': amount,
    'currency': currency,
  };

  try {
    final res = await LearmondNativePay.showNativePay(args);
    // Ensure friendly message available
    final propagated = StripePaymentResult(
      success: res.success,
      status: res.status,
      paymentIntentId: res.paymentIntentId,
      error: res.error,
      errorMessage: res.errorMessage ?? _formatWebError(res.error),
      rawResult: res.rawResult,
    );
    onResult(propagated);
  } catch (e) {
    onResult(const StripePaymentResult(
        success: false,
        error: 'native_pay_error',
        errorMessage: 'An error occurred while invoking native pay.'));
  }
}

class _NativePaysheet extends StatefulWidget {
  final String method;
  final String? clientSecret;
  final String? amount;
  final Map<String, dynamic>? merchantArgs;
  final ScrollController? scrollController;
  final void Function(StripePaymentResult) onResult;

  const _NativePaysheet({
    Key? key,
    required this.method,
    this.clientSecret,
    this.amount,
    this.merchantArgs,
    this.scrollController,
    required this.onResult,
  }) : super(key: key);

  @override
  State<_NativePaysheet> createState() => _NativePaysheetState();
}

class _NativePaysheetState extends State<_NativePaysheet> {
  bool _inProgress = false;
  String? _error;
  stripe.CardFieldInputDetails? _card;
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _usRoutingController = TextEditingController();
  final TextEditingController _usAccountController = TextEditingController();
  final TextEditingController _usHolderController = TextEditingController();

  Future<void> _handleNativePay() async {
    setState(() {
      _inProgress = true;
      _error = null;
    });
    final completer = Completer<StripePaymentResult>();
    showLpeNativePay(
      context,
      method: widget.method,
      publishableKey: stripe.Stripe.publishableKey,
      merchantArgsParam: widget.merchantArgs,
      amount: widget.amount ?? '0.00',
      currency: 'USD',
      onResult: (r) => completer.complete(r),
    );
    try {
      final r = await completer.future;
      widget.onResult(r);
      Navigator.of(context).pop(r);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _inProgress = false;
      });
    }
  }

  bool _looksLikeIban(String v) {
    final s = v.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    // Very small heuristic: starts with 2 letters then 10-30 alnum chars
    return RegExp(r'^[A-Z]{2}[0-9A-Z]{10,30}$').hasMatch(s);
  }

  Widget _buildBody() {
    // Compute effective merchant args to display
    final effective = computeEffectiveMerchantArgs(
      merchantArgs: widget.merchantArgs,
      amount: widget.amount,
    );
    final merchantName = (effective['merchantName'] ??
        effective['merchant'] ??
        'Merchant') as String?;
    final merchantInfo = (effective['merchantInfo'] ?? '') as String?;
    final summaryRaw = effective['summaryItems'];
    final List<SummaryLineItem> summaryItems = [];
    if (summaryRaw is List) {
      for (final s in summaryRaw) {
        try {
          if (s is SummaryLineItem) {
            summaryItems.add(s);
          } else if (s is Map) {
            summaryItems
                .add(SummaryLineItem.fromJson(Map<String, dynamic>.from(s)));
          }
        } catch (_) {
          // ignore malformed summary items
        }
      }
    }

    switch (widget.method) {
      case 'card':
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Merchant header with elevation
              Material(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchantName ?? 'Merchant',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((merchantInfo ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(merchantInfo ?? '',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Summary list
              if (summaryItems.isNotEmpty) ...[
                const Text('Summary', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ...summaryItems.map((item) {
                  final label = item.label;
                  final amount = _formatAmountFromCents(item.amountCents);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(label), Text(amount)],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              // Card field
              const Text('Pay with card', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              stripe.CardField(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onCardChanged: (details) {
                  setState(() {
                    _card = details;
                    _error = null;
                  });
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: lpeButtonWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: ElevatedButton(
                      onPressed: _inProgress
                          ? null
                          : () async {
                              // If a clientSecret is provided, confirm; otherwise create a PM
                              setState(() {
                                _inProgress = true;
                                _error = null;
                              });
                              try {
                                if (widget.clientSecret != null) {
                                  final resp = await stripe.Stripe.instance
                                      .confirmPayment(
                                    paymentIntentClientSecret:
                                        widget.clientSecret!,
                                    data: const stripe.PaymentMethodParams.card(
                                      paymentMethodData:
                                          const stripe.PaymentMethodData(),
                                    ),
                                  );
                                  final r = StripePaymentResult(
                                      success: true,
                                      status: 'succeeded',
                                      rawResult: resp);
                                  widget.onResult(r);
                                  Navigator.of(context).pop(r);
                                } else {
                                  // No `clientSecret` provided — return collected card details
                                  final r = StripePaymentResult(
                                      success: true, rawResult: _card);
                                  widget.onResult(r);
                                  Navigator.of(context).pop(r);
                                }
                              } on stripe.StripeException catch (e) {
                                final String msg =
                                    (e.error.localizedMessage ?? e.toString())
                                        .toString();
                                setState(() {
                                  _error = msg;
                                });
                              } catch (e) {
                                setState(() {
                                  _error = e.toString();
                                });
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _inProgress = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 3,
                      ),
                      child: _inProgress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Pay'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'source_pay':
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Merchant header with elevation
              Material(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchantName ?? 'Merchant',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((merchantInfo ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(merchantInfo ?? '',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Summary list
              if (summaryItems.isNotEmpty) ...[
                const Text('Summary', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ...summaryItems.map((item) {
                  final label = item.label;
                  final amount = _formatAmountFromCents(item.amountCents);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(label), Text(amount)],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              const Text('Source Pay', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: lpeButtonWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: ElevatedButton(
                      onPressed: _inProgress ? null : _handleNativePay,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 3,
                      ),
                      child: _inProgress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Pay'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'eu_bank':
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Merchant header with elevation
              Material(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchantName ?? 'Merchant',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((merchantInfo ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(merchantInfo ?? '',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Summary list
              if (summaryItems.isNotEmpty) ...[
                const Text('Summary', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ...summaryItems.map((item) {
                  final label = item.label;
                  final amount = _formatAmountFromCents(item.amountCents);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(label), Text(amount)],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              const Text('Pay with bank (SEPA)',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _ibanController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'IBAN',
                  hintText: 'DE00 0000 0000 0000 00',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (_) {
                  setState(() {
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _holderController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (_) {
                  setState(() {
                    _error = null;
                  });
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: lpeButtonWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: ElevatedButton(
                      onPressed: _inProgress
                          ? null
                          : () async {
                              setState(() {
                                _inProgress = true;
                                _error = null;
                              });
                              try {
                                final ibanRaw = _ibanController.text.trim();
                                final holder = _holderController.text.trim();
                                final ibanNorm = ibanRaw
                                    .replaceAll(RegExp(r'\s+'), '')
                                    .toUpperCase();
                                if (ibanNorm.isEmpty) {
                                  setState(
                                      () => _error = 'Please enter your IBAN');
                                  return;
                                }
                                if (!_looksLikeIban(ibanNorm)) {
                                  setState(() =>
                                      _error = 'Please enter a valid IBAN');
                                  return;
                                }
                                if (holder.isEmpty) {
                                  setState(() => _error =
                                      'Please enter account holder name');
                                  return;
                                }

                                // Return collected IBAN data. Server-side can attach/confirm as needed.
                                final r = StripePaymentResult(
                                    success: true,
                                    rawResult: {
                                      'iban': ibanNorm,
                                      'accountHolderName': holder,
                                    });
                                widget.onResult(r);
                                Navigator.of(context).pop(r);
                              } catch (e) {
                                setState(() {
                                  _error = e.toString();
                                });
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _inProgress = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 3,
                      ),
                      child: _inProgress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Pay'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'us_bank':
        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Merchant header with elevation
              Material(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchantName ?? 'Merchant',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if ((merchantInfo ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(merchantInfo ?? '',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Summary list
              if (summaryItems.isNotEmpty) ...[
                const Text('Summary', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                ...summaryItems.map((item) {
                  final label = item.label;
                  final amount = _formatAmountFromCents(item.amountCents);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(label), Text(amount)],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              const Text('Pay with US bank account',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _usRoutingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Routing number',
                  hintText: '9-digit routing number',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usAccountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  hintText: 'Account number',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usHolderController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: lpeButtonWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: ElevatedButton(
                      onPressed: _inProgress
                          ? null
                          : () async {
                              setState(() {
                                _inProgress = true;
                                _error = null;
                              });
                              try {
                                final routing =
                                    _usRoutingController.text.trim();
                                final account =
                                    _usAccountController.text.trim();
                                final holder = _usHolderController.text.trim();
                                if (!RegExp(r'^\d{9}').hasMatch(routing)) {
                                  setState(() => _error =
                                      'Please enter a valid 9-digit routing number');
                                  return;
                                }
                                if (account.isEmpty || account.length < 4) {
                                  setState(() => _error =
                                      'Please enter a valid account number');
                                  return;
                                }
                                if (holder.isEmpty) {
                                  setState(() => _error =
                                      'Please enter account holder name');
                                  return;
                                }

                                final r = StripePaymentResult(
                                    success: true,
                                    rawResult: {
                                      'routing_number': routing,
                                      'account_number': account,
                                      'accountHolderName': holder,
                                    });
                                widget.onResult(r);
                                Navigator.of(context).pop(r);
                              } catch (e) {
                                setState(() {
                                  _error = e.toString();
                                });
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _inProgress = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 14.0),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 3,
                      ),
                      child: _inProgress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Pay'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'apple_pay':
      case 'google_pay':
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Pay with ${widget.method.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleNativePay,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      default:
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unsupported payment method',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              Text(widget.method),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final r = const StripePaymentResult(
                        success: false,
                        error: 'unsupported_method',
                        errorMessage: 'This payment method is not supported.');
                    widget.onResult(r);
                    Navigator.of(context).pop(r);
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _holderController.dispose();
    _usRoutingController.dispose();
    _usAccountController.dispose();
    _usHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Material(
          color: Colors.white,
          child: _buildBody(),
        ),
      ),
    );
  }
}
