#!/usr/bin/env python3
"""Local Chainhook Receiver

Run a simple HTTP server to receive Chainhook POSTs for validation.
Supports optional HMAC verification using CHAINHOOK_SECRET.

Usage:
  python scripts/local_chainhook_receiver.py --port 8080

Env:
  CHAINHOOK_SECRET  - shared secret for HMAC-SHA256 (optional)
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import hmac, hashlib, json, os

SECRET = os.getenv("CHAINHOOK_SECRET", "")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('content-length', '0'))
        body = self.rfile.read(length)
        sig = self.headers.get('x-chainhook-signature', '')
        ok = True
        if SECRET:
            mac = hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()
            ok = hmac.compare_digest(mac, sig)
        try:
            payload = json.loads(body.decode())
        except Exception:
            payload = {"raw": body.decode(errors='ignore')}
        self.send_response(200 if ok else 401)
        self.send_header('content-type', 'application/json')
        self.end_headers()
        res = {"ok": ok, "received": payload, "path": self.path}
        self.wfile.write(json.dumps(res).encode())

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    HTTPServer(('', args.port), Handler).serve_forever()
