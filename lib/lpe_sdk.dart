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
export 'package:lpe/lpe.dart' show LearmondPayButtons;
export 'learmond_native_pay.dart' show LearmondNativePay;
export 'learmondindividualbuttons.dart'
    show
        LearmondCardButton,
        LearmondUSBankButton,
        LearmondEUBankButton,
        LearmondApplePayButton,
        LearmondGooglePayButton;

/// Summary line item model for merchant receipts (re-export from package:lpe).

/// Exports the merchant argument builder/controller utilities for advanced integrations.
// Use canonical implementations from the published `lpe` package to avoid
// duplication and keep behavior consistent with the upstream library.
export 'package:lpe/lpe.dart'
    show
        MerchantArgsController,
        buildMerchantArgs,
        buildMerchantArgsFromAmount,
        setMerchantArgsBuilder,
        clearMerchantArgsBuilder,
        SummaryLineItem;
