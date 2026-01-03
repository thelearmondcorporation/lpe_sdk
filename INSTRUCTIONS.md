# LPE (Learmond Pay Element) SDK Implementation Instructions

## Overview
Learmond Pay Element (LPE) SDK provides a reusable Paysheet for any app framework. It uses a modal bottom sheet to securely collect payment details and confirm payments. Built for modern payment flows.

Note: The SDK now re-exports merchant-args utilities and `SummaryLineItem` from the published `lpe` package. The published `paysheet` API (`Paysheet.instance.present`) is used to render the sheet, and `UIAdjust` is used to inject input fields (card number / expiry / CVC, routing/account, IBAN) into the paysheet body.

## Main Operations
**sPaysheet.instance.present(...)** (from the published `paysheet` package): Main entry point. Presents the paysheet and returns a PaymentResult, `PaymentResult` (or your PSP Provider).
**PaymentResult**: Published package returns a minimal result object (commonly `success`, optional `error` and `errorMessage`). For native/pay-token flows your code should rely on the `onPay` hook to receive and send tokens to your server, and handle final outcome via `onResult`.
**Supported methods**: 'card', 'us_bank', 'eu_bank', 'apple_pay', 'google_pay', 'source_pay'.
**FlutterUI**: Used to render secure payment elements.

## How to Implement

### 1. Add Dependency
In your app's `pubspec.yaml`:
```yaml
dependencies:
  lpe_sdk: 4.1.0+6
```

### 2. Import the Package
```dart
import 'package:lpe_sdk/lpe_sdk.dart';
```

### 3. Show the Payment Sheet
```dart
final result = await showLpePaysheet(
  context,
  apiKey: 'your_publishable_key',
  clientSecret: 'your_client_secret',
  method: 'card', // or 'us_bank', 'eu_bank', 'apple_pay', 'google_pay', 'source_pay'
  amount: '10.00',
  // Optional: onPay is an async hook the paysheet calls when it needs the host
  // app to perform the payment action (e.g., exchange tokens with your server).
  onPay: () async {
    // fetch client secret or send token to your server here
  },
  // Optional: onResult receives the final PaymentResult outcome
  onResult: (res) {
    if (res.success) {
      // handle success
    }
  },
);
if (result?.success == true) {
  // Payment succeeded
}
```

### Using the single-line buttons widget (recommended)

For most apps we recommend embedding the `LearmondPayButtons` widget directly in your checkout UI. It renders a compact, consistent set of pay method buttons and wires them to both the paysheet and native pay flows:

```dart
LearmondPayButtons(
  apiKey: 'api_test_...', // optional fallback
  clientSecret: 'pi_test_client_secret', // optional
  merchantId: 'merchant.com.yourdomain', // required for Apple Pay
  amount: '10.00',
  currency: 'USD',
  // Optional async hook invoked when the paysheet asks the host app to run
  // the payment action (e.g., exchange tokens with your server). Use this
  // for native-token flows or when you need to perform server-side work
  // before the paysheet continues.
  onPay: () async {
    // fetch client secret, send token to server, or perform other async work
  },
  onResult: (PaymentResult r) {
    if (r.success) {
      // Handle success. Note: published `PaymentResult` is minimal;
      // continue to inspect server-side confirmations if you used `onPay`.
    } else {
      // Handle error r.error or r.errorMessage
    }
  },
)

If you want direct control over placement or styling, you can instantiate individual buttons instead of `LearmondPayButtons`:

```dart
Row(
  children: [
    LearmondCardButton(
      apiKey: 'api_test_...',
      clientSecret: 'pi_test_client_secret',
      amount: '10.00',
      merchantName: 'My Shop',
      merchantInfo: 'Order #1234',
      summaryItems: [
        SummaryLineItem(label: 'Subtotal', amountCents: 1000),
        SummaryLineItem(label: 'Tax', amountCents: 80),
        SummaryLineItem(label: 'Total', amountCents: 1080),
      ],
      onPay: () async {
        // optional: prepare payment server-side or refresh client secret
      },
      onResult: _handleResult,
    ),
    SizedBox(width: 8),
    LearmondApplePayButton(
      merchantId: 'merchant.com.yourdomain',
      merchantName: 'My Shop',
      merchantInfo: 'Order #1234',
      amount: '10.00',
      currency: 'USD',
      onPay: () async {
        // optional: send device-pay token to server here when invoked
      },
      onResult: _handleResult,
    ),
  ],
)
```

### Using the `Learmond` singleton presenters

If you prefer to present the same sheets programmatically (for example from
non-widget logic or centralized UI flows), use the `Learmond.instance` helpers.

Example — embed the single Card button directly in your widget tree:

```dart
// return the pre-styled card button from your build method:
return Learmond.instance.presentCardButton(
  context: context,
  apiKey: 'api_test_...',
  amount: '12.34',
  merchantArgs: buildMerchantArgs(merchantName: 'My Shop'),
  onResult: (r) { /* handle PaymentResult */ },
);
```

You can also embed the composite or individual button groups directly in
your widget tree:

```dart
// embed the composite pay buttons
return Learmond.instance.presentLearmondPayButtons(context: context, amount: '9.99', merchantArgs: buildMerchantArgs(...));

// or embed the individual buttons group
return Learmond.instance.presentIndividualButtons(context: context, amount: '9.99', merchantArgs: buildMerchantArgs(...));
```

The presenter methods accept the same `onPay` and `onResult` parameters as the widgets.


When you pass `summaryItems`, the paysheet HTML will render them above the element and prefer the provided total if present; always verify amounts server-side.```

Notes:
- The widget uses a responsive layout (three buttons on the first row, two centered buttons on the second row) and keeps consistent button sizing.
- Use `onResult` to process the returned `PaymentResult` whether the flow was web-based (card/bank) or native (apple/google). Native flows return raw tokens in `result.rawResult` which you MUST send to your server for verification.
- Do not rely on client-supplied amounts — always verify amounts server-side.

### Embedding `LearmondPayButtons` into your UI (step-by-step)

1) Import the package:

```dart
import 'package:lpe/lpe.dart';
```

2) Add the widget where you want the pay buttons to appear (e.g., checkout, product page):

```dart
LearmondPayButtons(
  apiKey: 'api_test_...', // optional fallback
  clientSecret: 'pi_test_client_secret', // optional (used by web flows)
  merchantId: 'merchant.com.yourdomain', // required for Apple Pay
  amount: '10.00', // display amount; server must verify final amount
  currency: 'USD',
  onResult: (PaymentResult r) {
    if (r.success) {
      // Payment succeeded. You may have r.paymentIntentId or r.rawResult (native token)
    } else {
      // Handle error r.error
    }
  },
)
```

3) Pass dynamic values from your form (amount, merchantId, apiKey, clientSecret). If you use `TextField` controllers, call `setState()` in `onChanged` so the widget rebuilds with the latest inputs.

4) Handling the `onResult` callback:
- For web-based card and bank flows `PaymentResult` usually includes `success`, `status`, and `paymentIntentId`.
- For native Apple/Google Pay flows the widget returns a `rawResult` containing the device token (Apple: `paymentDataBase64`; Google: `paymentToken`/`paymentDataJson`). **Send these tokens to your server** and finalize the payment there using your payment gateway's API.

5) Apple Pay & Google Pay setup reminders:
- iOS: enable Apple Pay in Xcode (`Signing & Capabilities`), add the Merchant ID, and test on a physical device using Apple Sandbox testers.
- Android: configure Google Pay console for production and test using `ENVIRONMENT_TEST` on a real Android device.

### Web: Google Pay and Apple Pay

The SDK ships a web implementation for Google Pay and Apple Pay. Key points:

- Google Pay: the SDK prefers the Google Pay JS SDK (`window.google.payments.api.PaymentsClient`) when present and falls back to `PaymentRequest` using the Google Pay method identifier (`https://google.com/pay`) when necessary.
- Apple Pay: the SDK can instantiate `ApplePaySession` and run the Apple Pay flow, but Apple requires server-side merchant validation. You must provide a merchant validation endpoint that the browser can POST the `validationURL` to — the server will call Apple's validation URL with your merchant identity certificate (.p12) and return the `merchantSession` JSON.

See `example/apple_validation_server` for Node and Python example servers that demonstrate how to accept `{ "validationURL": "..." }` and return Apple's `merchantSession` JSON. Keep your `.p12` and credentials private; do not commit them to source control.

6) UX guidance:
- Show clear errors for native availability checks (e.g., "Apple Pay is not available on this device").
- UI: The plugin now displays the Apple icon followed by the text `Pay` (icon + label) for Apple Pay and uses the included Google Pay acceptance mark image for Google Pay. The GPay asset is included under `static/assets/GPay_Acceptance_Mark_800.png` and is bundled as a plugin asset. Buttons are white with consistent sizing by default.
 - Global initialization: Set SDK defaults (Apple/Google merchant ids and optional display defaults) at app startup by calling `LpeSDKConfig.init(...)` before `runApp()` in your `main.dart`. Example:

  ```dart
  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    LpeSDKConfig.init(
      appleMerchantId: 'merchant.com.yourdomain',
      googleMerchantId: 'yourGatewayMerchantId',
      defaultMerchantName: 'My Shop',
      defaultMerchantInfo: 'Order #',
    );
    runApp(const MyApp());
  }
  ```

  Values provided directly to `LearmondPayButtons`, `Learmond.instance` presenters,
  or `LearmondNativePay.showNativePay(...)` override these defaults.
- Provide a fallback flow (card) when native pay is unavailable.

7) Testing & security:
- Always verify amounts & tokens server-side and never finalize a charge from the client alone.
- Log debugging info but never print your secret keys in production logs.

If you want a concrete server-side example for exchanging Apple/Google tokens with Stripe or another gateway, see the server examples near the end of this file and adapt them to your provider.

### Connecting custom buttons to the paysheet logic

If you prefer custom-styled buttons or need programmatic control (for example to fetch a client secret before showing the sheet), follow these patterns.

Imports you'll likely need:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lpe/lpe.dart';
```

Card / Bank (web paysheet)

1. Create a PaymentIntent on your server and return the `client_secret`.
2. Call `LearmondPaySheet.show(...)` and pass the `clientSecret`.

```dart
final resp = await http.post(
  Uri.parse('https://your-server.example/create-payment-intent(send-payment-intent)'),
  body: jsonEncode({'amount_cents': 1000, 'currency': 'usd'}),
  headers: {'Content-Type': 'application/json'},
);
final clientSecret = jsonDecode(resp.body)['client_secret'];

final result = await LearmondPaySheet.show(
  context: context,
  apiKey: 'api_test_...',
  clientSecret: clientSecret,
  method: 'card',
  title: 'Pay \$10.00',
  amount: '10.00',
);
if (result.success) {
  // show confirmation
} else {
  // handle error
}
```

Native device pay (Apple Pay / Google Pay)

The SDK provides a Dart wrapper around the platform native-pay bridge: `LearmondNativePay.showNativePay(...)`.

Recommended flow (preferred): use the paysheet's `onPay` async hook so the paysheet can request the host app to perform server-side work (exchange device tokens with your backend) before finishing the flow. This keeps token exchange and verification on the server and avoids embedding raw tokens in the published `PaymentResult`.

Example — using the `onPay` hook (recommended):

```dart
LearmondPayButtons(
  ...,
  onPay: () async {
    // The paysheet will call this when it needs the host app to
    // perform an async device-token exchange with your server.
    // Perform the network call here and return when complete.
    await http.post(Uri.parse('https://your-server.example/device-pay'),
      body: jsonEncode({'/* token or client secret exchange */': '...'}),
      headers: {'Content-Type': 'application/json'},
    );
  },
  onResult: (r) {
    // The published PaymentResult is minimal — use onPay for
    // device-token exchanges and server confirmations.
  },
)
```

Direct native bridge usage

If you need to call the native bridge directly (for example in a custom flow), the package exposes a MethodChannel under `lpe_sdk/native_pay`. The `LearmondNativePay` wrapper calls this channel for you and returns a `PaymentResult` (note: the published `PaymentResult` is minimal and does not include device-token payloads). If you require the raw device token map returned by the platform, call the MethodChannel directly and inspect the returned `raw` map:

```dart
import 'package:flutter/services.dart';

final channel = MethodChannel('lpe_sdk/native_pay');
final args = {
  'method': 'apple_pay',
  'merchantId': 'merchant.com.yourdomain',
  'amountCents': 1000,
  'currency': 'USD',
  'merchantArgs': {
    'merchantName': 'My Shop',
    'summaryItems': [
      {'label': 'Subtotal', 'amountCents': 1000},
      {'label': 'Tax', 'amountCents': 80},
      {'label': 'Total', 'amountCents': 1080},
    ]
  }
};

final dynamic resp = await channel.invokeMethod('presentNativePay', args);
if (resp is Map && resp['success'] == true) {
  final raw = (resp['raw'] is Map) ? Map<String, dynamic>.from(resp['raw']) : null;
  final token = raw?['paymentDataBase64'] ?? raw?['paymentToken'];
  // Send `token` to your server and finalize the payment there.
} else {
  // handle error/unsupported
}
```

Note: The Kotlin/Swift plugin implementations return a `raw` map containing device-token payloads (Apple: `paymentDataBase64`, Google: `paymentToken`/`paymentDataJson`). The published `PaymentResult` returned by `LearmondNativePay.showNativePay` is intentionally minimal — use `onPay` or the platform channel approach above to obtain raw token payloads for server-side exchange.

Note: The Kotlin plugin reads `merchantArgs` and will prefer `merchantArgs.summaryItems` and `merchantArgs.merchantName` when building the Google Pay request; Apple Pay also honors `summaryItems` and `merchantName`.
Using `LearmondPayButtons`'s `onResult`

If you embed `LearmondPayButtons`, prefer handling payments in the `onResult` callback — the widget will call the correct flow for each method and return a `PaymentResult`. For native flows `r.rawResult` contains the device token to send to your server.

```dart
LearmondPayButtons(
  ...,
  onPay: () async {
    // optional async hook invoked when the paysheet requests the host app
    // to perform the payment action. For native-token flows, send the token
    // to your server here and await confirmation before returning.
  },
  onResult: (r) async {
    if (r.success) {
      if (r.rawResult != null) {
        // send r.rawResult to server for verification if not already handled
      }
      // show success UI
    } else {
      // show r.error
    }
  },
)
```

UX tips

- Disable the button that launches a flow while an operation is in progress to prevent double submissions.
- Provide a clear fallback to card entry if native pay is unavailable.
- Always validate amounts and tokens on your server and never finalize charges from the client.

### 4. Handle the Result
- `result.success`: `true` if payment succeeded.
- `result.status`: Payment status string.
- `result.paymentIntentId`: Payment intent ID.
- `result.error`: Error message if any.
- `result.rawResult`: Full payment response.

### 5. Supported Payment Methods
- `'card'`: Card entry via secure payment element.
- `'us_bank'`: US bank account (ACH).
- `'eu_bank'`: EU bank (SEPA/IBAN).
- `'apple_pay'`, `'google_pay'`: Payment Request Button (if supported).

### 6. Customization
- You can set `title`, `amount`, and `buttonLabel` for the sheet.
- The modal sheet size can be adjusted with `initialChildSize`, `minChildSize`, and `maxChildSize`.

### 7. Requirements
- You must provide a valid publishable key and client secret from your payment provider.
- Your backend should create payment intents and provide the client secret.

### 8. Example
See the README and example folder for a full integration.

See the README and the `example/` app for a full integration. To run the included example:

```bash
cd lpe/example
flutter pub get
flutter run
```

The example demonstrates embedding `LearmondPayButtons` with live input fields for amount, publishable key, client secret, and merchant ID.
## Native Pay (Apple Pay / Google Pay) — Setup & Usage

This package exposes a native MethodChannel bridge (`lpe_sdk/native_pay`) so apps can present device-native pay flows without performing on-device Stripe confirmation. The native flows return device tokens which your backend must exchange/confirm with your chosen payment gateway.

Summary of behavior
- iOS (Apple Pay): presents `PKPaymentAuthorizationController`, returns the Apple payment token as base64 (`raw.paymentDataBase64`) and metadata (transaction identifier, payment method). Does NOT use Stripe on-device.
- Android (Google Pay): launches Google Pay `PaymentDataRequest`, returns the tokenization payload (`raw.paymentToken`) and the full `paymentDataJson`. Does NOT use Stripe on-device.

Important: These native flows intentionally do not confirm payments on-device. Your server must accept the returned token and create/confirm a charge or PaymentIntent with your gateway.

1) iOS (Xcode) setup
- Add an Apple Merchant ID in Apple Developer portal (e.g. `merchant.com.yourdomain`).
- In Xcode enable the Apple Pay capability for your app target and add the Merchant ID to the entitlements.
- Ensure the app's bundle identifier is configured for Apple Pay and the provisioning profile includes the merchant.
- When calling the plugin from Dart pass `merchantId` in the `presentNativePay` args. Example:

```dart
final res = await LearmondNativePay.showNativePay({
  'method': 'apple_pay',
  'merchantId': 'merchant.com.yourdomain',
  'amountCents': 1000,
  'currency': 'USD',
  'country': 'US',
});
```

On success `res.raw['paymentDataBase64']` will contain the Apple payment token (PKPaymentToken.paymentData) encoded in base64.

Server-side handling (recommended): send the base64 token to your server; the server should decode and exchange the Apple token with your payment provider (e.g., create/confirm a PaymentIntent with Stripe, or call your gateway's Apple Pay verification endpoint). Do not attempt to finalize the charge from the client.

2) Android (Gradle / Google Pay) setup
- Add Google Play Services Wallet dependency to your app-level `build.gradle` only if you
  explicitly need to control the version. Most apps can rely on the plugin declaring this
  dependency; declare it at the app level only when you need a specific version. If you do, ensure the
  version is aligned with the plugin to avoid manifest/resource merge issues:

```gradle
dependencies {
  implementation 'com.google.android.gms:play-services-wallet:19.2.0' // keep versions aligned
}
```

If your build fails with manifest/resource merge errors that reference `play-services-wallet`, check
for duplicate declarations (plugin + app) and prefer a single declaration with aligned versions to
avoid conflicts.

- Configure Google Pay in the Google Pay Console for production. For testing use the `ENVIRONMENT_TEST` setup provided in the plugin.
- The plugin builds a `PaymentDataRequest` with `PAYMENT_GATEWAY` tokenization placeholders. Replace `gateway` / `gatewayMerchantId` with your payment gateway values (or implement direct tokenization if supported).

Example Dart call (Google Pay):

```dart
final res = await LearmondNativePay.showNativePay({
  'method': 'google_pay',
  'amountCents': 1000,
  'currency': 'USD',
});
```

On success `res.raw['paymentToken']` will contain the tokenization `token` string; `res.raw['paymentDataJson']` has the full JSON returned by Google Pay. Send the `paymentToken`/JSON to your server for verification and processing.

3) Backend: exchanging device tokens
- Apple Pay: decode `paymentDataBase64` then call your payment processor's Apple Pay endpoint to create/confirm a payment. Example with Stripe (server-side): use `stripe.tokens.create({client_secret, ...})` or create a PaymentMethod from the Apple Pay token and confirm a PaymentIntent server-side.
- Google Pay: the tokenization payload returned must be exchanged with the gateway. If using `PAYMENT_GATEWAY` tokenization with Stripe, you'll receive a Stripe token payload that the server can use to create/confirm a PaymentIntent.
- Always validate amounts and metadata server-side and never rely on client-supplied amount values for final charge amounts.

4) Plugin registration & pubspec
- The `lpe_sdk` package declares plugin platforms in `pubspec.yaml` (android package `com.learmond.lpe_sdk`, plugin class `LearmondSDKNativePayPlugin`). Ensure the package structure matches the `package` value on Android and `ios/Classes` contains the Swift file.
- Confirm the `example/` app demonstrates calling `LearmondSDKNativePay.showNativePay(...)` for both methods.

Optional: initialize global merchant ids
--------------------------------------
If you prefer to set default merchant ids (Apple or Google) application-wide, you may call `LpeConfig.init` at app startup before calling `runApp(...)`. `LearmondPayButtons` will use these defaults for native pay flows when explicit merchant ids are not supplied.

Example:

```dart
void main() {
  // IMPORTANT: Do NOT commit real merchant IDs in your app's source if the
  // repository is public or the package will be published. Use placeholders
  // during development and set real values via CI or private configuration
  // at build/deploy time.
  // LpeConfig.init(
  //   appleMerchantId: 'merchant.com.example',
  //   googleGatewayMerchantId: 'yourGatewayMerchantId',
  // );
  runApp(const MyApp());
}
```

### In-app merchantArgs builder

If you want to configure merchant arguments inside the app (no server required), the package exposes `setMerchantArgsBuilder(...)` and `clearMerchantArgsBuilder()` along with `buildMerchantArgs(...)` to construct the final normalized map.

Example (set builder values at startup in `main()`):

```dart
import 'package:lpe/lpe.dart';

void main() {
  // set application-wide merchant args builder values
  setMerchantArgsBuilder({
    'merchantId': 'merchant.com.example',
    'merchantName': 'My Builder Shop',
    'merchantInfo': 'Builder order info',
    'summaryItems': [
      {'label': 'Subtotal', 'amountCents': 1000},
    ],
  });

  runApp(const MyApp());
}
```

Later, build the final normalized args (explicit params override builder values):

```dart
final args = buildMerchantArgs(
  // explicit overrides (optional)
  merchantName: 'Override Shop',
  summaryItems: [ SummaryLineItem(label: 'Total', amountCents: 1200) ],
);

await LearmondPaySheet.show(..., merchantArgs: args);
```

You can also construct and normalize merchant args directly using `MerchantArgsController` if you need programmatic control:

```dart
final ctrl = MerchantArgsController(merchantName: 'My Shop', merchantInfo: 'Order #1234');
ctrl.merge({'summaryItems': [SummaryLineItem(label: 'Total', amountCents: 1200).toJson()]});
final args = ctrl.toMap();
```

To remove builder values at runtime call:

```dart
clearMerchantArgsBuilder();
```

5) Fallbacks & UX
- The package also provides a WebView-based Payment Request Button as a fallback. If native availability checks fail, detect and gracefully fall back to the WebView flow.
- Surface clear messages to users when native pay is unavailable (e.g., "Apple Pay is not available — add a card to Wallet" or "Google Pay not configured on this device").

## Example server snippet (Node/Express) — receive Apple/Google token and confirm with Stripe
This is a simple example that shows how your server might accept the token and confirm a PaymentIntent with Stripe. Adjust to your gateway.

```js
// POST /api/device-pay
// body: { method: 'apple_pay'|'google_pay', token: '<token>', amount_cents: 1000, currency: 'usd' }
app.post('/api/device-pay', async (req, res) => {
  const { method, token, amount_cents, currency } = req.body;
  try {
    // Create PaymentIntent server-side and confirm with the token as payment_method
    const pi = await stripe.paymentIntents.create({
      amount: amount_cents,
      currency,
      payment_method_data: {
        type: 'card',
        // If your gateway supports direct tokenized device payment objects,
        // attach the token payload here according to the gateway's API.
      },
      confirm: true,
    });
    res.json({ success: true, paymentIntent: pi });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});
```

Note: The exact server-side flow depends on your gateway. For Stripe you may need to create a `PaymentMethod` from the device token or use `stripe.tokens.create` with the token payload first.

## QA & Testing Recommendations
- Test Apple Pay on a real iOS device with Apple Sandbox tester accounts or cards.
- Test Google Pay on a real Android device with Google Pay configured; use `ENVIRONMENT_TEST` for early testing.
- Verify the `example/` app demonstrates both device flows and the fallback WebView flow.
- Log debug info (careful not to print secrets) to help troubleshoot device availability issues.

## Advanced
The package uses a WebView to securely render payment elements and handle payment confirmation.
Communication between Flutter and JS is handled via `window.flutter_inappwebview.callHandler('paymentCallback', {...})`.
- You can extend or customize the UI by modifying the modal sheet or WebView widget.

### Troubleshooting

- If `flutter analyze` reports `The name 'LpeSDKConfig' is defined in the libraries ... ambiguous_export`, check `lib/lpe_sdk.dart` and ensure it's exporting symbols explicitly via `show` or by only exporting the files needed. For example:

  ```dart
    export 'lpe_sdk_config.dart' show LpeSDKConfig;
    // Prefer importing the published paysheet package directly to avoid
    // ambiguous exports and to use the published API (showLpePaysheet).
    export 'package:paysheet/paysheet.dart' show showLpePaysheet, PaymentResult;
    export 'learmondpaybuttons.dart' show LearmondPayButtons;
  ```

- To fix analyzer issues about unused imports, remove duplicate or unused `import` lines (e.g., avoid importing `lpe_config.dart` twice in `paysheet.dart`).
- If `flutter analyze` reports `The method 'init' isn't defined for the type 'LpeConfig'`, ensure `LpeConfig` is exported by `lib/lpe.dart` and you imported `package:lpe/lpe.dart` in your app.


## License
MIT

## Author
The Learmond Corporation
