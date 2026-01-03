# LPE Example

This minimal Flutter app demonstrates embedding `LearmondPayButtons` from the `lpe` package. It shows how to pass `apiKey`, `clientSecret`, `merchantId`, and `amount` and listens to `onResult` for success/failure.

Run:

```bash
cd lpe/example
flutter pub get
flutter run
```

Notes:
- For iOS Apple Pay testing you must run on a real device and configure the Merchant ID in `Runner.xcworkspace` → Signing & Capabilities. Add the merchant ID and ensure your provisioning profile includes the capability.
- For Android Google Pay testing, use a real device with Google Pay and `ENVIRONMENT_TEST` during development.

Quick integration tip:

Place `LearmondPayButtons` in your checkout page (under totals, above the final confirmation button). The example's `ExampleHome` shows `LearmondPayButtons` directly in the column with live text fields for inputs.

The example also includes two manual buttons that demonstrate programmatic integration:
- **Manual Card Paysheet** — calls `LearmondPaySheet.show(...)` directly (useful when you fetch a client secret from your server first).
- **Manual Apple Pay** — calls `LearmondNativePay.showNativePay(...)` and logs the returned device token (which your server must verify).
