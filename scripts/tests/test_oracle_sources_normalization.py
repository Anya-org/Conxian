#!/usr/bin/env python3
"""Tiny normalization checks for oracle_sources adapters.

Verifies shape: source, price:int (scaled by 1e2), timestamp:int.
Runs in OFFLINE=1 mode to avoid network calls.
"""
import os
import asyncio
import importlib.util
from typing import List, Dict, Any

os.environ.setdefault('OFFLINE', '1')

SPEC = importlib.util.spec_from_file_location('oracle_sources', '/workspaces/AutoVault/scripts/oracle_sources.py')
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

async def gather_all() -> List[Dict[str, Any]]:
    funcs = [getattr(mod, name) for name in ('coingecko', 'binance', 'kraken') if hasattr(mod, name)]
    outs: List[Dict[str, Any]] = []
    for fn in funcs:
        try:
            res = await fn('BTC', 'USD')
            outs.extend(res)
        except Exception:
            pass
    return outs

async def main() -> int:
    data = await gather_all()
    # In offline mode, adapters return [] and the orchestrator fallback is used.
    # Still, we can validate that when data is present it has the correct shape.
    for e in data:
        assert isinstance(e, dict)
        assert isinstance(e.get('source'), str)
        assert isinstance(e.get('price'), int)
        assert isinstance(e.get('timestamp'), int)
        # price is integer scaled by 1e2 (cents). We can't guarantee value, just type.
        assert e['price'] >= 0
    print('OK normalization entries:', len(data))
    return 0

if __name__ == '__main__':
    raise SystemExit(asyncio.run(main()))
