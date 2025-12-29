// Small helper to build the final merchantArgs map using the
// `MerchantArgsController` normalization rules. Supports optional
// builder values which are merged before explicit params.
import 'merchant_args_controller.dart';
import 'lpe_sdk_config.dart';
import 'summary_line_item.dart';

// Internal in-app builder store. Use `setMerchantArgsBuilder` to provide
// app-wide builder values that `buildMerchantArgs` will merge when called
// without an explicit `builder` map.
Map<String, dynamic>? _appBuilder;

/// Set application-wide merchant args builder to be used by
/// `buildMerchantArgs` when no explicit `builder` is provided.
/// Set application-wide merchant args builder to be used by
/// [buildMerchantArgs] when no explicit `builder` is provided.
void setMerchantArgsBuilder(Map<String, dynamic>? m) {
  _appBuilder = (m == null) ? null : Map<String, dynamic>.from(m);
}

/// Clear the application-wide merchant args builder.
/// Clear the application-wide merchant args builder.
void clearMerchantArgsBuilder() {
  _appBuilder = null;
}

/// Build a normalized merchantArgs map (or null if empty).
///
/// Merge order (lowest -> highest priority):
/// 1. `builder` map (if provided)
/// 2. `LpeSDKConfig` defaults (used only when value still missing)
/// 3. Explicit parameters passed to this function
/// Build a normalized merchantArgs map (or null if empty).
///
/// Merge order (lowest -> highest priority):
/// 1. `builder` map (if provided)
/// 2. [LpeSDKConfig] defaults (used only when value still missing)
/// 3. Explicit parameters passed to this function
///
/// Returns a [Map<String, dynamic>] suitable for passing to payment sheet or native pay.
Map<String, dynamic>? buildMerchantArgs({
  String? appleMerchantId,
  String? googleMerchantId,
  String? sourceAccountId,
  String? merchantName,
  String? merchantInfo,
  List<SummaryLineItem>? summaryItems,
  Map<String, dynamic>? builder,
}) {
  // Start from builder map if provided, otherwise use the app-wide builder
  final ctrl = MerchantArgsController.fromMap(builder ?? _appBuilder);

  // Apply LpeSDKConfig defaults if not present in fallback
  final current = ctrl.toMap();
  if ((current == null || !current.containsKey('merchantName')) &&
      LpeSDKConfig.defaultMerchantName != null &&
      LpeSDKConfig.defaultMerchantName!.isNotEmpty) {
    ctrl.merge({'merchantName': LpeSDKConfig.defaultMerchantName});
  }
  if ((current == null || !current.containsKey('merchantInfo')) &&
      LpeSDKConfig.defaultMerchantInfo != null &&
      LpeSDKConfig.defaultMerchantInfo!.isNotEmpty) {
    ctrl.merge({'merchantInfo': LpeSDKConfig.defaultMerchantInfo});
  }

  // Explicit params override fallback/defaults
  if (appleMerchantId != null && appleMerchantId.isNotEmpty) {
    ctrl.merge({'appleMerchantId': appleMerchantId});
  }
  if (googleMerchantId != null && googleMerchantId.isNotEmpty) {
    ctrl.merge({'googleMerchantId': googleMerchantId});
  }
  if (sourceAccountId != null && sourceAccountId.isNotEmpty) {
    ctrl.merge({'sourceAccountId': sourceAccountId});
  }
  if (merchantName != null && merchantName.isNotEmpty) {
    ctrl.merge({'merchantName': merchantName});
  }
  if (merchantInfo != null && merchantInfo.isNotEmpty) {
    ctrl.merge({'merchantInfo': merchantInfo});
  }
  if (summaryItems != null && summaryItems.isNotEmpty) {
    ctrl.merge({'summaryItems': summaryItems.map((s) => s.toJson()).toList()});
  }

  return ctrl.toMap();
}

/// Convenience helper: build merchantArgs from common form fields like
/// an amount string and optional summary items. This keeps callers from
/// reimplementing amount-to-cents and ensures the package remains the
/// single source of truth for merchant args construction.
/// Convenience helper: build merchantArgs from common form fields like
/// an amount string and optional summary items. This keeps callers from
/// reimplementing amount-to-cents and ensures the package remains the
/// single source of truth for merchant args construction.
///
/// Returns a [Map<String, dynamic>] with normalized summary and merchant info.
Map<String, dynamic>? buildMerchantArgsFromAmount({
  required String amount,
  String? appleMerchantId,
  String? googleMerchantId,
  String? merchantName,
  String? merchantInfo,
  List<SummaryLineItem>? extraSummaryItems,
  Map<String, dynamic>? builder,
}) {
  final a = double.tryParse(amount.replaceAll(',', '')) ?? 0.0;
  final cents = (a * 100).round();
  final summary = <SummaryLineItem>[];
  // Primary order line
  summary.add(SummaryLineItem(label: 'Order', amountCents: cents));
  // Append any additional lines provided by the caller
  if (extraSummaryItems != null && extraSummaryItems.isNotEmpty) {
    summary.addAll(extraSummaryItems);
  }
  return buildMerchantArgs(
    appleMerchantId: appleMerchantId,
    googleMerchantId: googleMerchantId,
    merchantName: merchantName,
    merchantInfo: merchantInfo,
    summaryItems: summary,
    builder: (builder == null)
        ? {'amountCents': cents}
        : {...builder, 'amountCents': cents},
  );
}
