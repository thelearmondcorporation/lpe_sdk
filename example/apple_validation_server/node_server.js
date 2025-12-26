// Simple Node/Express merchant validation proxy for Apple Pay
// Usage: set environment variables APPLE_P12_PATH, APPLE_P12_PASSWORD,
// MERCHANT_IDENTIFIER, DOMAIN_NAME, DISPLAY_NAME, and run `node node_server.js`.

const express = require('express');
const https = require('https');
const fs = require('fs');
const { URL } = require('url');

const app = express();
app.use(express.json());

const P12_PATH = process.env.APPLE_P12_PATH || './merchant_id.p12';
const P12_PASS = process.env.APPLE_P12_PASSWORD || '';
const MERCHANT_ID = process.env.MERCHANT_IDENTIFIER || 'merchant.com.example';
const DOMAIN_NAME = process.env.DOMAIN_NAME || 'localhost';
const DISPLAY_NAME = process.env.DISPLAY_NAME || 'The Learmond Corporation';

if (!fs.existsSync(P12_PATH)) {
  console.warn('Warning: merchant p12 not found at', P12_PATH);
}

app.post('/apple/validate', (req, res) => {
  const { validationURL } = req.body;
  if (!validationURL) return res.status(400).send('missing validationURL');

  const url = new URL(validationURL);
  const postBody = JSON.stringify({
    merchantIdentifier: MERCHANT_ID,
    domainName: DOMAIN_NAME,
    displayName: DISPLAY_NAME,
  });

  const opts = {
    hostname: url.hostname,
    port: url.port || 443,
    path: url.pathname + (url.search || ''),
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postBody),
    },
    pfx: fs.existsSync(P12_PATH) ? fs.readFileSync(P12_PATH) : undefined,
    passphrase: P12_PASS,
  };

  const r = https.request(opts, (appleRes) => {
    let data = '';
    appleRes.on('data', (chunk) => (data += chunk));
    appleRes.on('end', () => {
      try {
        const session = JSON.parse(data);
        res.json(session);
      } catch (e) {
        res.status(502).send('invalid response from Apple: ' + e);
      }
    });
  });

  r.on('error', (err) => {
    res.status(502).send('apple request error: ' + err.message);
  });

  r.write(postBody);
  r.end();
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Apple merchant validation proxy listening on :${PORT}`));
