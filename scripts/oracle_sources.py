#!/usr/bin/env python3
"""Oracle price source adapters (async).

Provides normalized price fetchers for common sources and a coordinator helper.
All functions return a list of dicts: { source, price:int, timestamp:int } in integer price units (scaled by 1e2 or 1e0 depending on config).

ENV:
  OFFLINE=1  - return mock data without network calls
"""
from __future__ import annotations
import os, time, asyncio, typing as t
import json
import urllib.parse

try:
    import aiohttp
except Exception:  # optional dependency
    aiohttp = None  # type: ignore

# Simple rate limiting and retry configuration
RATE_LIMIT_MS: int = int(os.getenv('ORACLE_RATE_LIMIT_MS', '250'))
MAX_RETRIES: int = int(os.getenv('ORACLE_MAX_RETRIES', '2'))
BACKOFF_BASE_MS: int = int(os.getenv('ORACLE_BACKOFF_BASE_MS', '200'))

# Per-host last call timestamps for coarse rate limiting
_LAST_CALL_AT: t.Dict[str, float] = {}

# Per-source health metrics
_SOURCE_METRICS: t.Dict[str, t.Dict[str, t.Any]] = {}

def _record_metric(source: str, ok: bool, latency_ms: t.Optional[int] = None, err: t.Optional[str] = None) -> None:
    # Don't record metrics in offline mode
    if os.getenv('OFFLINE') == '1':
        return
        
    m = _SOURCE_METRICS.setdefault(source, {
        'ok': 0,
        'err': 0,
        'last_error': '',
        'last_latency_ms': None,
        'total_latency_ms': 0,
        'last_ts': 0,
    })
    m['last_ts'] = int(time.time())
    if latency_ms is not None:
        m['last_latency_ms'] = latency_ms
        m['total_latency_ms'] += latency_ms
    if ok:
        m['ok'] += 1
        m['last_error'] = ''
    else:
        m['err'] += 1
        if err:
            # truncate long errors
            m['last_error'] = (err[:180] + '…') if len(err) > 180 else err

def get_source_metrics() -> t.Dict[str, t.Dict[str, t.Any]]:
    """Return a snapshot of source health metrics."""
    # Shallow copy is fine for reporting
    return {k: dict(v) for k, v in _SOURCE_METRICS.items()}

# Comprehensive Stacks ecosystem token mappings
SymbolMap = {
    # Major cryptocurrencies
    'BTC': {'coingecko': 'bitcoin', 'binance': 'BTCUSDT', 'kraken': 'XXBTZUSD', 'alex': 'wbtc'},
    'ETH': {'coingecko': 'ethereum', 'binance': 'ETHUSDT', 'kraken': 'XETHZUSD'},
    'USD': {'coingecko': 'usd'},
    'USDT': {'coingecko': 'tether', 'binance': 'USDTUSDT'},
    'USDC': {'coingecko': 'usd-coin', 'binance': 'USDCUSDT'},
    
    # Stacks ecosystem tokens
    'STX': {'coingecko': 'stacks', 'binance': 'STXUSDT', 'kraken': 'STXUSD', 'alex': 'stx'},
    'ALEX': {'coingecko': 'alex-lab', 'alex': 'alex'},
    'DIKO': {'coingecko': 'arkadiko', 'alex': 'diko'},
    'USDA': {'alex': 'usda'},  # Arkadiko USD
    'XUSD': {'alex': 'xusd'},  # Stacks USD
    'XBTC': {'alex': 'xbtc'},  # Wrapped Bitcoin on Stacks
    'WMNO': {'alex': 'wmno'},  # Wrapped Mino
    'BANANA': {'alex': 'banana'},
    'WELSH': {'alex': 'welsh'},
    'RYDER': {'alex': 'ryder'},
    'CHA': {'alex': 'cha'},
    'LEO': {'alex': 'leo'},
    'ROO': {'alex': 'roo'},
    'NYCC': {'alex': 'nycc'},
    'SLIME': {'alex': 'slime'},
    'CORGI': {'alex': 'corgi'},
    'PEPE': {'alex': 'pepe'},
    'SHIB': {'alex': 'shib'},
    'ORDI': {'alex': 'ordi'},
    'AUTO': {'alex': 'auto'},  # AutoVault token
    
    # Bitflow tokens
    'FLOW': {'alex': 'flow'},
    
    # Other Stacks DeFi tokens
    'CITY': {'alex': 'city'},  # CityCoins
    'MIA': {'alex': 'mia'},    # MiamiCoin
    'NYC': {'alex': 'nyc'},    # NewYorkCityCoin
    
    # Stacks Name Service
    'BNS': {'alex': 'bns'},
    
    # Popular meme tokens on Stacks
    'CRASHPUNKS': {'alex': 'crashpunks'},
    'MEGAPONT': {'alex': 'megapont'},
    'NOTHING': {'alex': 'nothing'},
}

def _now() -> int:
    return int(time.time())

def _host(url: str) -> str:
    try:
        return urllib.parse.urlparse(url).netloc or 'unknown'
    except Exception:
        return 'unknown'

async def _http_json(url: str, timeout: int = 5) -> t.Any:
    if os.getenv('OFFLINE') == '1' or aiohttp is None:
        raise RuntimeError('offline or aiohttp missing')
    host = _host(url)
    # simple per-host rate limit
    last = _LAST_CALL_AT.get(host, 0.0)
    now_mono = time.monotonic()
    delta_ms = int((now_mono - last) * 1000)
    if delta_ms < RATE_LIMIT_MS:
        await asyncio.sleep((RATE_LIMIT_MS - delta_ms) / 1000.0)
    attempt = 0
    backoff_ms = BACKOFF_BASE_MS
    while True:
        attempt += 1
        t0 = time.monotonic()
        try:
            async with aiohttp.ClientSession() as sess:
                async with sess.get(url, timeout=timeout) as resp:
                    if resp.status == 429 and attempt <= (MAX_RETRIES + 1):
                        # rate limited; backoff and retry
                        await asyncio.sleep(backoff_ms / 1000.0)
                        backoff_ms *= 2
                        continue
                    resp.raise_for_status()
                    data = await resp.json()
                    _LAST_CALL_AT[host] = time.monotonic()
                    return data
        except Exception as e:
            if attempt <= (MAX_RETRIES + 1):
                await asyncio.sleep(backoff_ms / 1000.0)
                backoff_ms *= 2
                continue
            raise

async def coingecko(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    t0 = time.monotonic()
    try:
        b = SymbolMap.get(base, {}).get('coingecko', base.lower())
        q = SymbolMap.get(quote, {}).get('coingecko', quote.lower())
        url = f"https://api.coingecko.com/api/v3/simple/price?ids={b}&vs_currencies={q}"
        data = await _http_json(url)
        px = data.get(b, {}).get(q)
        if px is None:
            raise RuntimeError('missing price')
        out = [{ 'source': 'coingecko', 'price': int(px * 100), 'timestamp': _now() }]
        _record_metric('coingecko', True, int((time.monotonic() - t0) * 1000))
        return out
    except Exception as e:
        _record_metric('coingecko', False, err=str(e))
        return []

async def binance(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    t0 = time.monotonic()
    try:
        sym = SymbolMap.get(base, {}).get('binance', f"{base}{quote}")
        url = f"https://api.binance.com/api/v3/ticker/price?symbol={sym}"
        data = await _http_json(url)
        px = float(data.get('price'))
        out = [{ 'source': 'binance', 'price': int(px * 100), 'timestamp': _now() }]
        _record_metric('binance', True, int((time.monotonic() - t0) * 1000))
        return out
    except Exception as e:
        _record_metric('binance', False, err=str(e))
        return []

async def kraken(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    t0 = time.monotonic()
    try:
        pair = SymbolMap.get(base, {}).get('kraken', f"{base}{quote}")
        url = f"https://api.kraken.com/0/public/Ticker?pair={pair}"
        data = await _http_json(url)
        res = next(iter(data.get('result', {}).values()))
        px = float(res['c'][0])
        out = [{ 'source': 'kraken', 'price': int(px * 100), 'timestamp': _now() }]
        _record_metric('kraken', True, int((time.monotonic() - t0) * 1000))
        return out
    except Exception as e:
        _record_metric('kraken', False, err=str(e))
        return []

async def alex_dex(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    """Fetch prices from ALEX DEX (Stacks native DEX)."""
    t0 = time.monotonic()
    try:
        base_sym = SymbolMap.get(base, {}).get('alex', base.lower())
        quote_sym = SymbolMap.get(quote, {}).get('alex', quote.lower())
        
        # ALEX API endpoint for token prices
        url = f"https://api.alexlab.co/v1/amm/tokens/{base_sym}/price"
        data = await _http_json(url)
        
        # ALEX returns prices in different formats, normalize to USD
        price_field = 'price_usd' if 'price_usd' in data else 'price'
        px = float(data.get(price_field, 0))
        
        if px <= 0:
            raise RuntimeError(f'invalid price from ALEX: {px}')
            
        out = [{ 'source': 'alex', 'price': int(px * 100), 'timestamp': _now() }]
        _record_metric('alex', True, int((time.monotonic() - t0) * 1000))
        return out
    except Exception as e:
        _record_metric('alex', False, err=str(e))
        return []

async def stackswap(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    """Fetch prices from StacksSwap (another Stacks DEX)."""
    t0 = time.monotonic()
    try:
        # StacksSwap API (if available)
        # Note: This is a placeholder as StacksSwap API may not be public
        base_sym = SymbolMap.get(base, {}).get('stackswap', base.lower())
        quote_sym = SymbolMap.get(quote, {}).get('stackswap', quote.lower())
        
        # Mock endpoint - replace with actual StacksSwap API when available
        url = f"https://api.stackswap.org/v1/price/{base_sym}-{quote_sym}"
        data = await _http_json(url)
        
        px = float(data.get('price', 0))
        if px <= 0:
            raise RuntimeError(f'invalid price from StacksSwap: {px}')
            
        out = [{ 'source': 'stackswap', 'price': int(px * 100), 'timestamp': _now() }]
        _record_metric('stackswap', True, int((time.monotonic() - t0) * 1000))
        return out
    except Exception as e:
        _record_metric('stackswap', False, err=str(e))
        return []

async def stacks_api(base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
    """Fetch prices from Stacks blockchain API with contract calls."""
    t0 = time.monotonic()
    try:
        # Use Stacks API to call price oracle contracts directly
        stacks_rpc = os.getenv('STACKS_RPC_URL', 'https://stacks-node-api.testnet.stacks.co')
        
        # Example: call a price oracle contract
        base_sym = SymbolMap.get(base, {}).get('alex', base.lower())
        quote_sym = SymbolMap.get(quote, {}).get('alex', quote.lower())
        
        # Mock contract call - replace with actual oracle contract when deployed
        url = f"{stacks_rpc}/v2/contracts/call-read/SPXXXXX/oracle-aggregator/get-price"
        
        # Prepare contract call data
        payload = {
            "sender": "SP000000000000000000002Q6VF78",
            "arguments": [f'"{base_sym}"', f'"{quote_sym}"']
        }
        
        # This would be a POST request with the payload
        # For now, return empty to avoid actual calls
        raise RuntimeError('Stacks API adapter not yet implemented')
        
    except Exception as e:
        _record_metric('stacks_api', False, err=str(e))
        return []

async def fetch_prices(base: str, quote: str, sources: t.List[str]) -> t.List[t.Dict[str, t.Any]]:
    tasks: t.List[asyncio.Task] = []
    for s in sources:
        fn = {
            'coingecko': coingecko, 
            'binance': binance, 
            'kraken': kraken,
            'alex': alex_dex,
            'stackswap': stackswap,
            'stacks_api': stacks_api
        }.get(s)
        if fn:
            tasks.append(asyncio.create_task(fn(base, quote)))
    results: t.List[t.Dict[str, t.Any]] = []
    if not tasks:
        return results
    done = await asyncio.gather(*tasks, return_exceptions=True)
    for d in done:
        if isinstance(d, list):
            results.extend(d)
    # dedupe by source
    seen = set()
    uniq: t.List[t.Dict[str, t.Any]] = []
    for e in results:
        if e.get('source') in seen:
            continue
        seen.add(e.get('source'))
        uniq.append(e)
    return uniq
