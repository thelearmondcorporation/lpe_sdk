// Helper to build and normalize merchantArgs passed to paysheet and native pay.
//
// Usage examples:
// ```dart
// final controller = MerchantArgsController(merchantName: 'Source', merchantInfo: 'Order #1234', summaryItems: [SummaryLineItem(label: 'Subtotal', amountCents: 1000)]);
// final m = controller.toMap(); // Map<String, dynamic> or null
// ```

import 'summary_line_item.dart';

/// Controller for building and normalizing merchantArgs passed to paysheet and native pay.
///
/// Use this to construct merchant argument maps for payment flows. Supports merging and normalization.
class MerchantArgsController {
  final Map<String, dynamic> _args;

  MerchantArgsController._(this._args);

  /// Creates a controller from individual merchant fields.
  factory MerchantArgsController({
    String? merchantId,
    String? merchantName,
    String? merchantInfo,
    String? gatewayMerchantId,
    List<SummaryLineItem>? summaryItems,
  }) {
    final m = <String, dynamic>{};
    if (merchantId != null && merchantId.isNotEmpty) {
      m['merchantId'] = merchantId;
    }
    if (merchantName != null && merchantName.isNotEmpty) {
      m['merchantName'] = merchantName;
    }
    if (merchantInfo != null && merchantInfo.isNotEmpty) {
      m['merchantInfo'] = merchantInfo;
    }
    if (gatewayMerchantId != null && gatewayMerchantId.isNotEmpty) {
      m['gatewayMerchantId'] = gatewayMerchantId;
    }
    if (summaryItems != null && summaryItems.isNotEmpty) {
      m['summaryItems'] = summaryItems.map((s) => s.toJson()).toList();
    }
    return MerchantArgsController._(m);
  }

  /// Creates a controller from an existing map.
  factory MerchantArgsController.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MerchantArgsController._({});
    return MerchantArgsController._(Map<String, dynamic>.from(map));
  }

  /// Merge other values into this controller. Values in [other] overwrite existing ones.
  void merge(Map<String, dynamic>? other) {
    if (other == null || other.isEmpty) return;
    _args.addAll(other);
  }

  /// Returns the normalized map or null if empty.
  Map<String, dynamic>? toMap() =>
      _args.isEmpty ? null : Map<String, dynamic>.from(_args);

  @override
  String toString() => _args.toString();
}
