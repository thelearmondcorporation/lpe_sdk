/// Lightweight representation of a merchant summary line item.
///
/// Use `SummaryLineItem(label: 'Subtotal', amountCents: 1000)` to add lines to
/// the merchant summary that appears above the payment element in the paysheet.
class SummaryLineItem {
  final String label;
  final int amountCents;
  final String? sublabel;

  const SummaryLineItem({
    required this.label,
    required this.amountCents,
    this.sublabel,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'amountCents': amountCents,
        if (sublabel != null) 'sublabel': sublabel,
      };

  /// Construct a [SummaryLineItem] from a JSON-like map produced by
  /// [toJson]. This is used when merchantArgs are passed through
  /// platform channels or stored as normalized maps.
  factory SummaryLineItem.fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString() ?? '';
    final amount = json['amountCents'];
    final amountCents = (amount is int)
        ? amount
        : (amount is String ? int.tryParse(amount) ?? 0 : 0);
    return SummaryLineItem(
      label: label,
      amountCents: amountCents,
      sublabel: json['sublabel']?.toString(),
    );
  }
}
