#!/usr/bin/env python3
"""Simulate a chainhook payload for update-autonomics event locally.

Optionally POST the payload to a receiver URL with HMAC signature.
Env:
    RECEIVER_URL       - http(s)://host:port/path
    CHAINHOOK_SECRET   - shared secret for HMAC-SHA256 signature header
"""
import json, time, sys, os, hmac, hashlib, urllib.request
from typing import Dict, Any

def sample_payload() -> Dict[str, Any]:
    return {
        "hook": "vault-autonomics-analytics",
        "network": "testnet",
        "block_height": 123456,
        "txid": "0xFAKE",
        "timestamp": int(time.time()),
        "contract": os.getenv('VAULT_CONTRACT','SPXXXX.vault'),
        "function": "update-autonomics",
        "print_event": {
            "event": "update-autonomics",
            "reserve-ratio": 750,
            "new-deposit-fee": 30,
            "withdraw-fee": 10
        }
    }

if __name__ == '__main__':
    payload = sample_payload()
    url = os.getenv('RECEIVER_URL')
    if not url:
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write('\n')
        sys.exit(0)
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={'content-type':'application/json'})
    secret = os.getenv('CHAINHOOK_SECRET')
    if secret:
        sig = hmac.new(secret.encode(), data, hashlib.sha256).hexdigest()
        req.add_header('x-chainhook-signature', sig)
    with urllib.request.urlopen(req) as resp:
        sys.stdout.write(resp.read().decode() + '\n')
