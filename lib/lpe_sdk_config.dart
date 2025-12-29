/// Global configuration for LPE (Learmond Pay Element).
///
/// Use `LpeSDKConfig.init(...)` at app startup to provide default values such
/// as Apple Pay merchant id or a Google Pay gateway merchant id. These
/// defaults are used when individual calls do not provide explicit values.
class LpeSDKConfig {
  /// Apple merchant id used for presenting Apple Pay (e.g. 'merchant.com.example')
  static String? appleMerchantId;

  /// Optional default merchant display name shown in in-app/web paysheets
  static String? defaultMerchantName;

  /// Optional default merchant info (one-line) shown beneath the merchant name
  static String? defaultMerchantInfo;

  /// Google Pay gateway merchant id (gateway-specific merchant identifier)
  /// For Stripe gateway flows this may be a value you obtain from Google Pay
  /// console or your gateway configuration.
  static String? googleMerchantId;

  /// Initialize common settings. Call once at app startup.
  static void init(
      {String? appleMerchantId,
      String? googleMerchantId,
      String? defaultMerchantName,
      String? defaultMerchantInfo}) {
    LpeSDKConfig.appleMerchantId = appleMerchantId;
    LpeSDKConfig.googleMerchantId = googleMerchantId;
    LpeSDKConfig.defaultMerchantName = defaultMerchantName;
    LpeSDKConfig.defaultMerchantInfo = defaultMerchantInfo;
  }
}
