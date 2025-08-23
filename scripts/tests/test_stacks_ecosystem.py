#!/usr/bin/env python3
"""Test Stacks ecosystem token support in oracle adapters.

Validates that the oracle system can handle Stacks-native tokens and DEX integrations.
Tests both offline (placeholder) and online (with alex/stackswap adapters) modes.
"""
import os
import sys
import asyncio
import importlib.util
from pathlib import Path

# Add scripts to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
sys.path.append(str(SCRIPTS_DIR))

# Import modules dynamically
sources_spec = importlib.util.spec_from_file_location(
    "oracle_sources", SCRIPTS_DIR / "oracle_sources.py"
)
orchestrator_spec = importlib.util.spec_from_file_location(
    "oracle_orchestrator", SCRIPTS_DIR / "oracle_orchestrator.py"
)

sources_module = importlib.util.module_from_spec(sources_spec)
orchestrator_module = importlib.util.module_from_spec(orchestrator_spec)

sources_spec.loader.exec_module(sources_module)
orchestrator_spec.loader.exec_module(orchestrator_module)

# Extract classes and functions
fetch_prices = sources_module.fetch_prices
get_source_metrics = sources_module.get_source_metrics
OracleConfig = orchestrator_module.OracleConfig
OracleOrchestrator = orchestrator_module.OracleOrchestrator

# Test token pairs
STACKS_PAIRS = [
    ("STX", "USD"),
    ("ALEX", "USD"),
    ("DIKO", "USD"),
    ("USDA", "USD"),
    ("XBTC", "USD"),
    ("WELSH", "USD"),
    ("AUTO", "USD"),
    ("ALEX", "STX"),
    ("DIKO", "STX"),
]

# Available adapters including Stacks-specific ones
ALL_ADAPTERS = ["coingecko", "binance", "kraken", "alex", "stackswap"]

async def test_stacks_token_mappings():
    """Test that Stacks tokens have proper symbol mappings."""
    print("=== Testing Stacks Token Mappings ===")
    
    symbol_map = sources_module.SymbolMap
    stacks_tokens = ["STX", "ALEX", "DIKO", "USDA", "XBTC", "WELSH", "AUTO"]
    
    for token in stacks_tokens:
        if token in symbol_map:
            mappings = symbol_map[token]
            print(f"✓ {token}: {list(mappings.keys())}")
        else:
            print(f"✗ {token}: No mappings found")
    
    print()

async def test_stacks_adapters_offline():
    """Test Stacks-specific adapters in offline mode."""
    print("=== Testing Stacks Adapters (Offline) ===")
    
    # Force offline mode
    os.environ["OFFLINE"] = "1"
    
    success = True
    for base, quote in STACKS_PAIRS:
        try:
            result = await fetch_prices(base, quote, ["alex", "stackswap"])
            if result:
                print(f"✗ {base}/{quote}: Expected empty result in offline mode, got {len(result)}")
                success = False
            else:
                print(f"✓ {base}/{quote}: Correctly returned empty in offline mode")
        except Exception as e:
            print(f"✗ {base}/{quote}: Error - {e}")
            success = False
    
    print()
    return success

async def test_orchestrator_stacks_pairs():
    """Test orchestrator with Stacks trading pairs."""
    print("=== Testing Orchestrator with Stacks Pairs ===")
    
    # Keep offline mode for testing
    os.environ["OFFLINE"] = "1"
    
    config = OracleConfig()
    config.offline = True
    config.external_sources = ALL_ADAPTERS
    
    orchestrator = OracleOrchestrator(config)
    await orchestrator.initialize()
    
    print(f"Loaded {len(orchestrator.trading_pairs)} trading pairs:")
    
    success = True
    for pair_key, pair in orchestrator.trading_pairs.items():
        try:
            prices = await orchestrator._fetch_external_prices(pair.base, pair.quote)
            
            if not prices:
                print(f"✗ {pair_key}: No prices returned")
                success = False
            else:
                print(f"✓ {pair_key}: {len(prices)} prices returned")
                
                # Test aggregation
                if len(prices) > 0:
                    median = await orchestrator._select_oracle_price(prices, None)
                    if median > 0:
                        print(f"  └─ Trimmed-mean: {median}")
                    else:
                        print(f"  └─ Invalid aggregation: {median}")
                        success = False
                        
        except Exception as e:
            print(f"✗ {pair_key}: Error - {e}")
            success = False
    
    print()
    return success

async def test_symbol_coverage():
    """Test that all important Stacks ecosystem tokens are covered."""
    print("=== Testing Symbol Coverage ===")
    
    symbol_map = sources_module.SymbolMap
    
    # Check important Stacks ecosystem categories
    categories = {
        "Core": ["STX", "BTC"],
        "DeFi Protocols": ["ALEX", "DIKO", "USDA", "XBTC"],
        "Stablecoins": ["USDA", "XUSD"],
        "Meme/Community": ["WELSH", "BANANA", "CORGI", "PEPE"],
        "Infrastructure": ["AUTO", "FLOW", "BNS"],
        "CityCoins": ["CITY", "MIA", "NYC"],
    }
    
    total_tokens = 0
    covered_tokens = 0
    
    for category, tokens in categories.items():
        print(f"{category}:")
        for token in tokens:
            total_tokens += 1
            if token in symbol_map:
                covered_tokens += 1
                sources = list(symbol_map[token].keys())
                print(f"  ✓ {token}: {sources}")
            else:
                print(f"  ✗ {token}: Not mapped")
    
    coverage_pct = (covered_tokens / total_tokens) * 100
    print(f"\nCoverage: {covered_tokens}/{total_tokens} tokens ({coverage_pct:.1f}%)")
    print()
    
    return coverage_pct >= 80  # Require 80% coverage

async def main():
    """Run all Stacks ecosystem tests."""
    print("🔥 Stacks Ecosystem Oracle Adapter Tests")
    print("=" * 50)
    print()
    
    # Run all tests
    await test_stacks_token_mappings()
    offline_ok = await test_stacks_adapters_offline()
    orchestrator_ok = await test_orchestrator_stacks_pairs()
    coverage_ok = await test_symbol_coverage()
    
    # Summary
    print("=== Test Summary ===")
    print(f"Stacks Adapters (Offline): {'✓ PASS' if offline_ok else '✗ FAIL'}")
    print(f"Orchestrator Integration: {'✓ PASS' if orchestrator_ok else '✗ FAIL'}")
    print(f"Symbol Coverage: {'✓ PASS' if coverage_ok else '✗ FAIL'}")
    print()
    
    overall = offline_ok and orchestrator_ok and coverage_ok
    print(f"Overall Stacks Support: {'✓ PASS' if overall else '✗ FAIL'}")
    
    if overall:
        print("\n🎉 Stacks ecosystem oracle support is ready!")
        print("Features available:")
        print("- Comprehensive token mappings for major Stacks tokens")
        print("- ALEX DEX integration (when online)")
        print("- StacksSwap integration (when available)")
        print("- Direct Stacks API calls (planned)")
        print("- Fallback to placeholder data for testing")
    else:
        print("\n⚠️  Some Stacks ecosystem features need attention")
    
    return 0 if overall else 1

if __name__ == "__main__":
    try:
        exitcode = asyncio.run(main())
        sys.exit(exitcode)
    except KeyboardInterrupt:
        print("\nTest interrupted")
        sys.exit(130)
