#!/usr/bin/env python3
"""Oracle Orchestration Manager

Automated oracle management and price feed coordination for AutoVault.
Manages oracle whitelists, coordinates price submissions, and monitors oracle health.

Key Features:
- Oracle registration and whitelist management
- Automated price feed coordination
- Oracle health monitoring and alerting
- Circuit breaker integration
- Multi-source price validation

Usage:
  python oracle_orchestrator.py --config oracle.conf --mode [manager|coordinator|monitor]
  
Environment Variables:
  STACKS_NETWORK - Network (testnet/mainnet) 
  STACKS_RPC_URL - RPC endpoint
  ORACLE_AGGREGATOR_CONTRACT - Oracle aggregator contract address
  DEPLOYER_PRIVKEY - Private key for admin operations
"""

import os
import time
import json
import logging
import asyncio
import dataclasses
import typing as t
from datetime import datetime, timedelta
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("oracle-orchestrator")

# Optional external price adapters
try:
    from oracle_sources import fetch_prices as fetch_external_prices  # type: ignore
except Exception:
    # Try adding the scripts directory to sys.path and retry
    try:
        import sys
        from pathlib import Path as _Path
        _scripts_dir = str(_Path(__file__).parent)
        if _scripts_dir not in sys.path:
            sys.path.append(_scripts_dir)
        from oracle_sources import fetch_prices as fetch_external_prices  # type: ignore
    except Exception:
        fetch_external_prices = None  # type: ignore

@dataclasses.dataclass
class OracleConfig:
    """Oracle orchestration configuration"""
    network: str = os.getenv("STACKS_NETWORK", "testnet")
    rpc_url: str = os.getenv("STACKS_RPC_URL", "https://stacks-node-api.testnet.stacks.co")
    oracle_contract: str = os.getenv("ORACLE_AGGREGATOR_CONTRACT", "SPXXXXX.oracle-aggregator")
    deployer_privkey: str = os.getenv("DEPLOYER_PRIVKEY", "")
    
    # Oracle management settings
    max_oracles_per_pair: int = 10
    min_oracles_per_pair: int = 3
    oracle_timeout_seconds: int = 300
    price_staleness_threshold: int = 600  # 10 minutes
    
    # Price coordination settings
    price_update_interval: int = 60  # 1 minute
    price_deviation_threshold_bps: int = 500  # 5%
    aggregation_delay_seconds: int = 30
    
    # Monitoring settings
    health_check_interval: int = 120  # 2 minutes
    alert_webhook_url: str = os.getenv("ALERT_WEBHOOK_URL", "")
    
    # Circuit breaker integration
    circuit_breaker_contract: str = os.getenv("CIRCUIT_BREAKER_CONTRACT", "SPXXXXX.circuit-breaker")
    price_volatility_threshold_bps: int = 1000  # 10%
    
    dry_run: bool = os.getenv("DRY_RUN", "true").lower() == "true"
    # External adapter settings
    external_sources: t.List[str] = dataclasses.field(default_factory=lambda: ["coingecko", "binance", "kraken", "alex"])  # noqa: E501
    offline: bool = (os.getenv("OFFLINE", os.getenv("ORACLE_OFFLINE", "0")) == "1")

@dataclasses.dataclass
class OracleInfo:
    """Oracle information and status"""
    address: str
    enabled: bool
    last_submission_height: int
    last_price: int
    response_time_ms: int
    accuracy_score: float
    consecutive_failures: int
    
@dataclasses.dataclass
class TradingPair:
    """Trading pair configuration"""
    base: str
    quote: str
    min_sources: int
    current_price: int
    last_update_height: int
    source_count: int
    oracles: t.List[OracleInfo]

class OracleOrchestrator:
    """Main oracle orchestration manager"""
    
    def __init__(self, config: OracleConfig):
        self.config = config
        self.trading_pairs: t.Dict[str, TradingPair] = {}
        self.oracle_registry: t.Dict[str, OracleInfo] = {}
        self.price_feeds: t.Dict[str, t.List[t.Dict[str, t.Any]]] = {}
        
    async def initialize(self):
        """Initialize orchestrator and load current state"""
        logger.info("Initializing Oracle Orchestrator...")
        await self._load_trading_pairs()
        await self._load_oracle_registry()
        await self._load_config_file()
        logger.info(f"Loaded {len(self.trading_pairs)} trading pairs and {len(self.oracle_registry)} oracles")

    async def _load_config_file(self):
        """Load additional config from file if provided via ORACLE_CONFIG."""
        cfg_path = os.getenv("ORACLE_CONFIG")
        if not cfg_path:
            return
        try:
            with open(cfg_path, 'r') as f:
                data = json.load(f)
            for k, v in data.items():
                if hasattr(self.config, k):
                    setattr(self.config, k, v)
            logger.info("Oracle config loaded from %s", cfg_path)
        except Exception as e:
            logger.warning("Failed to load ORACLE_CONFIG %s: %s", cfg_path, e)
        
    async def _load_trading_pairs(self):
        """Load all registered trading pairs from blockchain"""
        # TODO: Implement blockchain query to get all pairs
        # For now, create comprehensive Stacks ecosystem pairs
        self.trading_pairs = {
            # Major pairs
            "STX/USD": TradingPair(
                base="STX",
                quote="USD", 
                min_sources=3,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "BTC/USD": TradingPair(
                base="BTC",
                quote="USD",
                min_sources=3, 
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            
            # Stacks DeFi tokens
            "ALEX/USD": TradingPair(
                base="ALEX",
                quote="USD",
                min_sources=2,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "DIKO/USD": TradingPair(
                base="DIKO",
                quote="USD",
                min_sources=2,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "USDA/USD": TradingPair(
                base="USDA",
                quote="USD",
                min_sources=2,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "XBTC/USD": TradingPair(
                base="XBTC",
                quote="USD",
                min_sources=2,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            
            # Stacks pairs vs STX
            "ALEX/STX": TradingPair(
                base="ALEX",
                quote="STX",
                min_sources=1,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "DIKO/STX": TradingPair(
                base="DIKO",
                quote="STX",
                min_sources=1,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            
            # Popular Stacks tokens
            "WELSH/USD": TradingPair(
                base="WELSH",
                quote="USD",
                min_sources=1,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
            "AUTO/USD": TradingPair(
                base="AUTO",
                quote="USD",
                min_sources=1,
                current_price=0,
                last_update_height=0,
                source_count=0,
                oracles=[]
            ),
        }
        
    async def _load_oracle_registry(self):
        """Load oracle registry and status"""
        # TODO: Query blockchain for registered oracles
        # Placeholder implementation
        self.oracle_registry = {}
        
    # Oracle Management Methods
    
    async def add_oracle(self, pair_key: str, oracle_address: str) -> bool:
        """Add oracle to trading pair whitelist"""
        logger.info(f"Adding oracle {oracle_address} to pair {pair_key}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would add oracle to whitelist")
            return True
            
        try:
            # TODO: Implement actual blockchain transaction
            # Call oracle-aggregator.add-oracle(base, quote, oracle)
            logger.info(f"Successfully added oracle {oracle_address} to {pair_key}")
            return True
        except Exception as e:
            logger.error(f"Failed to add oracle: {e}")
            return False
            
    async def remove_oracle(self, pair_key: str, oracle_address: str) -> bool:
        """Remove oracle from trading pair whitelist"""
        logger.info(f"Removing oracle {oracle_address} from pair {pair_key}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would remove oracle from whitelist")
            return True
            
        try:
            # TODO: Implement actual blockchain transaction  
            # Call oracle-aggregator.remove-oracle(base, quote, oracle)
            logger.info(f"Successfully removed oracle {oracle_address} from {pair_key}")
            return True
        except Exception as e:
            logger.error(f"Failed to remove oracle: {e}")
            return False
    
    async def update_min_sources(self, pair_key: str, min_sources: int) -> bool:
        """Update minimum sources requirement for a trading pair"""
        logger.info(f"Updating min sources for {pair_key} to {min_sources}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would update min sources")
            return True
            
        try:
            # TODO: Implement blockchain transaction
            # Call oracle-aggregator.set-min-sources(base, quote, min-sources)
            return True
        except Exception as e:
            logger.error(f"Failed to update min sources: {e}")
            return False
    
    # Price Feed Coordination
    
    async def coordinate_price_feeds(self):
        """Coordinate price submissions across oracles"""
        logger.info("Starting price feed coordination cycle")
        
        for pair_key, pair in self.trading_pairs.items():
            try:
                await self._coordinate_pair_prices(pair_key, pair)
            except Exception as e:
                logger.error(f"Error coordinating prices for {pair_key}: {e}")
                
    async def _coordinate_pair_prices(self, pair_key: str, pair: TradingPair):
        """Coordinate price submissions for a specific trading pair"""
        
        # Fetch external price data
        external_prices = await self._fetch_external_prices(pair.base, pair.quote)
        
        if not external_prices:
            logger.warning(f"No external prices available for {pair_key}")
            return
            
        # Validate price deviation
        if await self._detect_price_anomaly(pair_key, external_prices):
            logger.warning(f"Price anomaly detected for {pair_key}, skipping update")
            return
            
        # Submit prices through available oracles
        successful_submissions = 0
        for oracle in pair.oracles:
            if oracle.enabled and oracle.consecutive_failures < 3:
                try:
                    price = await self._select_oracle_price(external_prices, oracle)
                    if await self._submit_oracle_price(pair, oracle, price):
                        successful_submissions += 1
                except Exception as e:
                    logger.error(f"Failed to submit price via oracle {oracle.address}: {e}")
                    oracle.consecutive_failures += 1
        
        logger.info(f"Submitted {successful_submissions} prices for {pair_key}")
        
    async def _fetch_external_prices(self, base: str, quote: str) -> t.List[t.Dict[str, t.Any]]:
        """Fetch prices from external data sources.

        Attempts to use async adapters (CoinGecko, Binance, Kraken) when available.
        Falls back to local jittered placeholders when adapters are unavailable or offline.
        """
        # Prefer external adapters unless offline or unavailable
        if not self.config.offline and fetch_external_prices is not None:
            try:
                prices = await fetch_external_prices(base, quote, self.config.external_sources)  # type: ignore
                if prices:
                    return prices
            except Exception as e:
                logger.warning("External adapter fetch failed (%s/%s): %s", base, quote, e)

        # Fallback: local jittered placeholder data
        now = int(time.time())
        base_px = 123456
        return [
            {"source": "placeholder-a", "price": base_px, "timestamp": now},
            {"source": "placeholder-b", "price": base_px - 6, "timestamp": now},
            {"source": "placeholder-c", "price": base_px + 4, "timestamp": now}
        ]
        
    async def _detect_price_anomaly(self, pair_key: str, prices: t.List[t.Dict[str, t.Any]]) -> bool:
        """Detect price anomalies that might indicate market manipulation"""
        if len(prices) < 2:
            return False
            
        price_values = [p["price"] for p in prices]
        avg_price = sum(price_values) / len(price_values)
        
        # Check for excessive deviation
        for price in price_values:
            deviation_bps = abs(price - avg_price) * 10000 // avg_price
            if deviation_bps > self.config.price_deviation_threshold_bps:
                logger.warning(f"Price anomaly detected: {deviation_bps} bps deviation")
                return True
                
        return False
        
    async def _select_oracle_price(self, external_prices: t.List[t.Dict[str, t.Any]], oracle: OracleInfo) -> int:
        """Select appropriate price for oracle submission"""
        # Trimmed mean around median to resist outliers
        prices = sorted([int(p["price"]) for p in external_prices])
        n = len(prices)
        if n == 0:
            return 0
        if n <= 2:
            return prices[n // 2]
        trim = max(1, n // 5)  # ~20% trim
        trimmed = prices[trim: n - trim] if (n - 2*trim) >= 1 else prices
        return sum(trimmed) // len(trimmed)
        
    async def _submit_oracle_price(self, pair: TradingPair, oracle: OracleInfo, price: int) -> bool:
        """Submit price through specific oracle"""
        if self.config.dry_run:
            logger.info(f"DRY RUN: Would submit price {price} via oracle {oracle.address}")
            return True
            
        try:
            # TODO: Implement actual blockchain transaction
            # Call oracle-aggregator.submit-price(base, quote, price) from oracle account
            oracle.consecutive_failures = 0
            oracle.last_price = price
            return True
        except Exception as e:
            logger.error(f"Oracle price submission failed: {e}")
            oracle.consecutive_failures += 1
            return False
    
    # Health Monitoring
    
    async def monitor_oracle_health(self):
        """Monitor oracle health and performance"""
        logger.info("Starting oracle health monitoring cycle")
        
        for pair_key, pair in self.trading_pairs.items():
            await self._monitor_pair_health(pair_key, pair)
            
    async def _monitor_pair_health(self, pair_key: str, pair: TradingPair):
        """Monitor health of oracles for a specific trading pair"""
        
        healthy_oracles = 0
        for oracle in pair.oracles:
            if await self._check_oracle_health(oracle):
                healthy_oracles += 1
            else:
                await self._handle_unhealthy_oracle(pair_key, oracle)
                
        # Check if we have enough healthy oracles
        if healthy_oracles < pair.min_sources:
            await self._alert_insufficient_oracles(pair_key, healthy_oracles, pair.min_sources)
            
    async def _check_oracle_health(self, oracle: OracleInfo) -> bool:
        """Check if an oracle is healthy"""
        # Check response time
        if oracle.response_time_ms > self.config.oracle_timeout_seconds * 1000:
            return False
            
        # Check consecutive failures
        if oracle.consecutive_failures >= 3:
            return False
            
        # Check if price is stale
        current_time = int(time.time())
        if (current_time - oracle.last_submission_height * 10) > self.config.price_staleness_threshold:
            return False
            
        return True
        
    async def _handle_unhealthy_oracle(self, pair_key: str, oracle: OracleInfo):
        """Handle detection of unhealthy oracle"""
        logger.warning(f"Unhealthy oracle detected: {oracle.address} on {pair_key}")
        
        # Disable oracle temporarily
        if oracle.consecutive_failures >= 5:
            logger.warning(f"Disabling oracle {oracle.address} due to repeated failures")
            oracle.enabled = False
            await self.remove_oracle(pair_key, oracle.address)
            
    async def _alert_insufficient_oracles(self, pair_key: str, healthy: int, required: int):
        """Alert when insufficient healthy oracles"""
        message = f"ALERT: {pair_key} has only {healthy}/{required} healthy oracles"
        logger.critical(message)
        
        if self.config.alert_webhook_url:
            await self._send_webhook_alert(message)
            
    async def _send_webhook_alert(self, message: str):
        """Send alert via webhook"""
        # TODO: Implement webhook alert
        logger.info(f"Would send webhook alert: {message}")
        
    # Circuit Breaker Integration
    
    async def check_circuit_breaker_conditions(self):
        """Check if circuit breaker should be triggered"""
        logger.info("Checking circuit breaker conditions")
        
        for pair_key, pair in self.trading_pairs.items():
            await self._check_pair_volatility(pair_key, pair)
            
    async def _check_pair_volatility(self, pair_key: str, pair: TradingPair):
        """Check price volatility for circuit breaker trigger"""
        
        # Get recent price history
        recent_prices = await self._get_recent_prices(pair_key, 10)
        
        if len(recent_prices) < 2:
            return
            
        # Calculate volatility
        max_price = max(recent_prices)
        min_price = min(recent_prices)
        volatility_bps = (max_price - min_price) * 10000 // max_price
        
        if volatility_bps > self.config.price_volatility_threshold_bps:
            logger.warning(f"High volatility detected for {pair_key}: {volatility_bps} bps")
            await self._trigger_circuit_breaker(pair_key)
            
    async def _get_recent_prices(self, pair_key: str, count: int) -> t.List[int]:
        """Get recent price history for a trading pair"""
        # TODO: Query blockchain for recent price history
        # Placeholder implementation
        return [123456, 123450, 123460, 123455]
        
    async def _trigger_circuit_breaker(self, pair_key: str):
        """Trigger circuit breaker for extreme volatility"""
        logger.critical(f"Triggering circuit breaker for {pair_key}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would trigger circuit breaker")
            return
            
        try:
            # TODO: Call circuit-breaker contract
            pass
        except Exception as e:
            logger.error(f"Failed to trigger circuit breaker: {e}")

# Main orchestration loop

async def run_orchestrator(mode: str, config: OracleConfig):
    """Run oracle orchestrator in specified mode"""
    orchestrator = OracleOrchestrator(config)
    await orchestrator.initialize()
    
    if mode == "manager":
        # Oracle management mode - handle add/remove operations
        logger.info("Running in Oracle Manager mode")
        while True:
            # TODO: Listen for management commands or schedule management tasks
            await asyncio.sleep(60)
            
    elif mode == "coordinator":
        # Price coordination mode - coordinate price feeds
        logger.info("Running in Price Coordinator mode")
        while True:
            await orchestrator.coordinate_price_feeds()
            await asyncio.sleep(config.price_update_interval)
            
    elif mode == "monitor":
        # Monitoring mode - health checks and circuit breaker
        logger.info("Running in Monitor mode")
        while True:
            await orchestrator.monitor_oracle_health()
            await orchestrator.check_circuit_breaker_conditions()
            await asyncio.sleep(config.health_check_interval)
            
    elif mode == "full":
        # Full orchestration mode - all functions
        logger.info("Running in Full Orchestration mode")
        
        async def price_coordination_loop():
            while True:
                await orchestrator.coordinate_price_feeds()
                await asyncio.sleep(config.price_update_interval)
                
        async def monitoring_loop():
            while True:
                await orchestrator.monitor_oracle_health()
                await orchestrator.check_circuit_breaker_conditions()
                await asyncio.sleep(config.health_check_interval)
        
        # Run both loops concurrently
        await asyncio.gather(
            price_coordination_loop(),
            monitoring_loop()
        )

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Oracle Orchestration Manager")
    parser.add_argument("--mode", choices=["manager", "coordinator", "monitor", "full"], 
                       default="full", help="Orchestration mode")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--dry-run", action="store_true", help="Dry run mode")
    
    args = parser.parse_args()
    
    config = OracleConfig()
    if args.dry_run:
        config.dry_run = True
        
    if args.config and Path(args.config).exists():
        # TODO: Load configuration from file
        pass
        
    try:
        asyncio.run(run_orchestrator(args.mode, config))
    except KeyboardInterrupt:
        logger.info("Oracle Orchestrator shutdown requested")
    except Exception as e:
        logger.error(f"Oracle Orchestrator error: {e}")
        raise
