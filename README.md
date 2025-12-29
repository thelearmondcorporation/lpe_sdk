# LPE (Learmond Pay Element) SDK

A reusable Flutter SDK that provides a unified UI and helpers for collecting payments via stripe Elements, Apple Pay, Google Pay and the Source Pay button.

This README documents the SDK's major features and how to integrate and inegrate the package.

## Major features
- Composite payment widget: `LearmondPayButtons` (Card / Bank / Apple Pay / Google Pay)
- Individual buttons: `LearmondCardButton`, `LearmondUSBankButton`, `LearmondEUBankButton`, `LearmondApplePayButton`, `LearmondGooglePayButton`, 
`LearmondSourcePayButton`.
 - Programmatic pay sheet: `showLpePaysheet(...)` (from the published `paysheet` package)
- Native device pay bridge: `LearmondNativePay.showNativePay(...)`
- Merchant args helpers: `buildMerchantArgs`, `buildMerchantArgsFromAmount`
- Lightweight merchant-args editor: `Learmond.instance.presentMerchantArgs(...)` (used by the example/test app)

## Installation

Add the package to your `pubspec.yaml` (use local path for development):

```bash
flutter pub add lpe_sdk
```

Install dependencies:

```bash
flutter pub get
```

Note: The plugin uses native functionality for Apple/Google Pay; follow platform-specific setup steps for iOS and Android when integrating into a real app.

## Initialization

Set global defaults with `LpeSDKConfig.init(...)` at app startup so the SDK
has Apple/Google merchant identifiers available for native flows. Call this
before `runApp(...)` in your app `main.dart` (after any required
`WidgetsFlutterBinding.ensureInitialized()`):

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LpeSDKConfig.init(
    appleMerchantId: 'merchant.com.example',
    googleMerchantId: 'yourGoogleMerchantId',
    defaultMerchantName: 'My Shop',
    defaultMerchantInfo: 'Order',
  );
  runApp(const MyApp());
}
```

## Usage

### Composite Widget (recommended)

Use `LearmondPayButtons` to show a compact set of payment options; it handles wiring to Stripe and native pay flows for you.

```dart
LearmondPayButtons(
  publishableKey: 'pk_test_...',
  clientSecret: 'pi_..._secret_...',
  appleMerchantId: 'merchant.com.example',
  googleMerchantId: 'ABCD123459'
  merchantName: 'My Shop',
  merchantInfo: 'Order 1234',
  summaryItems: [
    SummaryLineItem(label: 'Subtotal', amountCents: 1000),
    SummaryLineItem(label: 'Tax', amountCents: 80),
  ],
  amount: '10.80',
  onResult: (res) {
    // handle result
  },
)
```

### Individual Buttons

Use per-button widgets for custom layout and styling.

### Programmatic: Payment sheet

Show the full Stripe-based sheet (webview) programmatically using the published `paysheet` API:

```dart
final result = await showLpePaysheet(
  context,
  publishableKey: 'pk_test...',
  clientSecret: 'pi_..._secret_...',
  method: 'card',
  amount: '10.00',
  merchantArgs: buildMerchantArgs(...),
  // Optional: pass `onPay` (async hook) to run your payment flow when the paysheet requests it,
  // and/or `onResult` to receive the final `StripePaymentResult` outcome.
);
```

### Programmatic: Native pay

Call the native bridge to present Apple/Google Pay directly and receive a token/result:

```dart
final res = await LearmondNativePay.showNativePay({
  'method': 'google_pay',
  'amountCents': 1000,
  'currency': 'USD',
  'gatewayMerchantId': 'yourGatewayMerchantId',
});
```

### Programmatic: Singleton presenters (convenience)

The SDK exposes a `Learmond` singleton with presenter helpers that show the same
button sets or single-button sheets used by the widgets. Use these when you want
to present the sheet from non-widget code or centralize presentation logic.

Example — present the single Card button sheet:

```dart
Learmond.instance.presentCardButton(
  context: context,
  publishableKey: 'pk_test_...',
  amount: '9.99',
  merchantArgs: buildMerchantArgs(merchantName: 'My Shop'),
  onResult: (res) { /* handle StripePaymentResult */ },
);
```

show single-method sheets.
 - `Learmond.instance.presentLearmondPayButtons(...)` — embed the composite pay buttons widget.
 - `Learmond.instance.presentIndividualButtons(...)` — embed the individual buttons group widget.
 - `Learmond.instance.presentApplePayButton(...)`, `presentGooglePayButton(...)`, `presentUSBankButton(...)`, `presentEUBankButton(...)`, `presentSourcePayButton(...)` — embed the single-method button widgets.

Use the same `onPay` (async pre-pay hook) and `onResult` callback parameters as the widgets.

## Web Support (Google Pay & Apple Pay)

This SDK now includes a web implementation for native-like payments:

- Google Pay: prefers the Google Pay JS SDK when available (`window.google.payments.api.PaymentsClient`) and falls back to the standard `PaymentRequest` API using the Google Pay method identifier (`https://google.com/pay`). This enables a native Google Pay flow in Chrome/Edge and a PaymentRequest fallback for other browsers.
- Apple Pay: the web plugin supports starting an `ApplePaySession` and performing merchant validation via a server-side endpoint. Because Apple requires merchant validation using a merchant identity certificate, you must provide a validation endpoint in `merchantArgs` (see example below).

Example usage (pass validation endpoint in `merchantArgs`):

```dart
runWebPaymentRequest(
  context,
  publishableKey: 'pk_test_...',
  method: 'apple_pay',
  amount: '10.00',
  merchantArgs: {
    'merchantName': 'The Learmond Corporation',
    'appleMerchantValidationUrl': 'https://your-server.example.com/apple/validate'
  },
  onResult: (result) { /* handle result */ },
);
```

Example servers for merchant validation are provided in `example/apple_validation_server`:

- `node_server.js` — Node/Express example that forwards the browser `validationURL` to Apple using a PKCS#12 certificate (`.p12`). Set `APPLE_P12_PATH`, `MERCHANT_IDENTIFIER` and `DOMAIN_NAME` in the environment.
- `python_server.py` — small Flask proxy that uses `curl` with the `.p12` to perform validation (minimal Python deps).

Security notes

- Apple merchant validation requires your merchant identity certificate — keep it on your server only and never commit it to source control.
- You must host the `/.well-known/apple-developer-merchantid-domain-association` file on your domain and verify the domain in Apple Developer for Apple Pay to work.
- Test Google Pay in Chrome/Edge; Safari will prefer Apple Pay and may intercept `PaymentRequest` unless you provide the Google Pay JS SDK.


### Merchant args

Use `buildMerchantArgs` or `buildMerchantArgsFromAmount` to construct the merchant arguments map. A `SummaryLineItem` is a simple model:

```dart
final item = SummaryLineItem(label: 'Subtotal', amountCents: 1000);
```

`buildMerchantArgsFromAmount(amount: '10.00', ...)` converts dollars to cents and can generate a default summary item.

## Example app

The `example/` directory contains a working integration and a merchant-args editor. Run it to preview the SDK behavior:

```bash
cd example
flutter run
```

## Development & testing

Useful commands:

```bash
# Format
dart format .

# Static analysis
flutter analyze

# Tests
flutter test
```

## Troubleshooting

- Use `dart fix --apply` to apply automatic suggestions.
- If Android manifest/resource merge issues occur, check for duplicated dependencies (e.g., `play-services-wallet`) declared by both the app and the plugin.
- If native pay buttons appear visually incorrect, check your app layout wrappers; the SDK provides consistent sizing but extra parent constraints can alter appearance.

## Contributing

Contributions and bug reports welcome. Please use the `example/` app to reproduce UI issues and include steps in PRs.

## License

MIT

## Author

The Learmond Corporation
