"""Simple Flask merchant validation proxy that uses curl under the hood.
Requires `curl` available on the host. This avoids needing special Python
packages to send a client certificate in PKCS#12 (.p12) format.

Usage:
  export APPLE_P12_PATH=./merchant_id.p12
  export APPLE_P12_PASSWORD=yourpassword
  export MERCHANT_IDENTIFIER=merchant.com.example
  export DOMAIN_NAME=your-domain.com
  export DISPLAY_NAME="The Learmond Corporation"
  python3 python_server.py

POST /apple/validate
  body: { "validationURL": "https://apple-pay-gateway.apple.com/..." }
Returns the merchantSession JSON from Apple or a 502 error on failure.
"""
from flask import Flask, request, jsonify, abort
import os
import subprocess
import json

app = Flask(__name__)

P12_PATH = os.environ.get('APPLE_P12_PATH', './merchant_id.p12')
P12_PASS = os.environ.get('APPLE_P12_PASSWORD', '')
MERCHANT_ID = os.environ.get('MERCHANT_IDENTIFIER', 'merchant.com.example')
DOMAIN_NAME = os.environ.get('DOMAIN_NAME', 'localhost')
DISPLAY_NAME = os.environ.get('DISPLAY_NAME', 'The Learmond Corporation')


@app.route('/apple/validate', methods=['POST'])
def validate():
    data = request.get_json(force=True)
    validation_url = data.get('validationURL')
    if not validation_url:
        return ('missing validationURL', 400)

    payload = json.dumps({
        'merchantIdentifier': MERCHANT_ID,
        'domainName': DOMAIN_NAME,
        'displayName': DISPLAY_NAME
    })

    # Use curl to POST with the PKCS#12 (.p12) client cert
    cmd = [
        'curl', '-sS', '--request', 'POST',
        '--header', 'Content-Type: application/json',
        '--data', payload,
    ]

    # If a p12 exists, pass it to curl with --cert and --cert-type P12
    if os.path.exists(P12_PATH):
        cmd += ['--cert', f'{P12_PATH}:{P12_PASS}', '--cert-type', 'P12']

    cmd.append(validation_url)

    try:
        proc = subprocess.run(cmd, capture_output=True, check=True)
        out = proc.stdout.decode('utf-8')
        # Attempt to parse JSON and return it
        try:
            obj = json.loads(out)
            return jsonify(obj)
        except Exception:
            return (out, 502)
    except subprocess.CalledProcessError as e:
        return (e.stderr.decode('utf-8') or str(e), 502)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', '3000'))
    app.run(host='0.0.0.0', port=port)
