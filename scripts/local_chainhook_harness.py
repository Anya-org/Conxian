#!/usr/bin/env python3
"""Simulate a chainhook payload for update-autonomics event locally."""
import json, time, sys, os

def sample_payload():
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
    json.dump(sample_payload(), sys.stdout, indent=2)
    sys.stdout.write('\n')
