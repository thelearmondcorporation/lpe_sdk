Apple Pay Merchant Validation Proxy
=================================

This folder contains two small example servers that perform Apple Pay merchant
validation on behalf of a browser. Apple requires merchant validation to be
performed from a server holding your merchant identity certificate (.p12).

Files
- `node_server.js` — Node/Express server using the `.p12` as `pfx` (recommended).
- `python_server.py` — Flask server that calls `curl` with the `.p12` (easy to run).

Common setup
------------
1. Create and download your Merchant Identity Certificate from Apple Developer
   and export it as a PKCS#12 file (.p12).
2. Host `/.well-known/apple-developer-merchantid-domain-association` on your
   domain and verify the domain in Apple Developer (see Apple's docs).

Environment variables (examples)

```bash
export APPLE_P12_PATH=./merchant_id.p12
export APPLE_P12_PASSWORD='p12password'
export MERCHANT_IDENTIFIER='merchant.com.example'
export DOMAIN_NAME='your-domain.com'
export DISPLAY_NAME='The Learmond Corporation'
export PORT=3000
```

Node server
-----------
Install and run:

```bash
cd example/apple_validation_server
npm install express
node node_server.js
```

Python server
-------------
Requires `curl` available on the host (macOS / Linux). Run:

```bash
cd example/apple_validation_server
python3 -m venv venv
source venv/bin/activate
pip install flask
python3 python_server.py
```

Using the server
----------------
From the browser, when creating an ApplePaySession the `onvalidatemerchant`
handler should POST `{ validationURL }` to `https://your-server/apple/validate`.
The server will call Apple's validation URL with your merchant certificate and
return the `merchantSession` JSON which you should pass back into
`session.completeMerchantValidation(merchantSession)`.

Security notes
--------------
- Keep your `.p12` private and never commit it to source control.
- Use HTTPS for your server and restrict access appropriately.
