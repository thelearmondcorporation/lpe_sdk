library lpe;

/// Main library entry point for Learmond Pay Element (LPE).
///
/// Exports the payment sheet and result classes.
/// Exports the Learmond singleton for programmatic UI presentation.
export 'learmond.dart' show Learmond;

/// Exports the main configuration class for global merchant/payment settings.
export 'lpe_sdk_config.dart' show LpeSDKConfig;

/// Exports the main payment sheet, native pay, and button widgets for SDK consumers.
export 'package:paysheet/paysheet.dart';
export 'learmondpaybuttons.dart' show LearmondPayButtons;
export 'learmond_native_pay.dart' show LearmondNativePay;
export 'learmondindividualbuttons.dart'
    show
        LearmondIndividualButtons,
        LearmondCardButton,
        LearmondUSBankButton,
        LearmondEUBankButton,
        LearmondApplePayButton,
        LearmondGooglePayButton;

/// Exports the summary line item model for merchant receipts.
export 'summary_line_item.dart' show SummaryLineItem;

/// Exports the merchant argument builder/controller utilities for advanced integrations.
export 'merchant_args_controller.dart' show MerchantArgsController;
export 'merchant_arg_builder.dart'
    show
        buildMerchantArgs,
        buildMerchantArgsFromAmount,
        setMerchantArgsBuilder,
        clearMerchantArgsBuilder;
