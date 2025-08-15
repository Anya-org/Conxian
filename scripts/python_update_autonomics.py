#!/usr/bin/env python3
"""Python wrapper to inspect vault state then (optionally) broadcast update-autonomics.

Requires:
  STACKS_API_BASE (e.g. https://api.testnet.hiro.so)
  VAULT_CONTRACT (SP...vault)
Optional for broadcast:
  STACKS_PRIVKEY (hex) -> if present and --broadcast used, we defer to Node SDK script.

This script focuses on read-only inspection using the Hiro API.
"""
from __future__ import annotations
import os, sys, json, time, subprocess, typing as t, hashlib
import urllib.request

API_BASE = os.getenv("STACKS_API_BASE", "https://api.testnet.hiro.so")
VAULT = os.getenv("VAULT_CONTRACT")

class APIError(RuntimeError):
    pass

def api_get(path: str):
    url = API_BASE.rstrip('/') + path
    with urllib.request.urlopen(url) as r:  # nosec B310 (read-only)
        if r.status != 200:
            raise APIError(f"GET {url} -> {r.status}")
        return json.loads(r.read().decode())

def fetch_contract_data():
    if not VAULT:
        raise SystemExit("VAULT_CONTRACT env required")
    addr, name = VAULT.split('.')
    # Example: read fee state by calling get-fees read-only endpoint
    # Hiro endpoint: /v2/contracts/call-read/{address}/{contract}/{fn}
    # We'll query a few read-only functions
    endpoints = [
        ("get-fees", []),
        ("get-reserve-bands", []),
        ("get-fee-ramps", []),
        ("get-utilization", []),
        ("get-reserve-ratio", []),
    ]
    results = {}
    for fn, args in endpoints:
        body = json.dumps({
            "sender": addr,
            "arguments": [json.dumps(a) for a in args]
        }).encode()
        url = f"{API_BASE.rstrip('/')}/v2/contracts/call-read/{addr}/{name}/{fn}";
        req = urllib.request.Request(url, data=body, headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req) as resp:  # nosec B310
            if resp.status != 200:
                raise APIError(f"call-read {fn} -> {resp.status}")
            payload = json.loads(resp.read().decode())
            results[fn] = payload
    return results

def maybe_broadcast():
    if '--broadcast' not in sys.argv:
        return None
    priv = os.getenv('STACKS_PRIVKEY')
    if not priv:
        print("STACKS_PRIVKEY not set; skipping broadcast", file=sys.stderr)
        return None
    # Use Node script for signing/broadcasting to avoid reimplementing stacks tx logic in python.
    cmd = ["node", "-r", "dotenv/config", "scripts/sdk_update_autonomics.ts"]
    print("Running:", ' '.join(cmd), file=sys.stderr)
    return subprocess.call(cmd)

def main():
    data = fetch_contract_data()
    print(json.dumps({"vault": VAULT, "snapshot": data}, indent=2))
    maybe_broadcast()

if __name__ == '__main__':
    main()
