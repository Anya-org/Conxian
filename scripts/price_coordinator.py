#!/usr/bin/env python3
"""Price Feed Coordinator

Coordinates price submissions across multiple oracles and external data sources.
Implements sophisticated price validation, anomaly detection, and submission strategies.

Features:
- Multi-source price aggregation
- Price anomaly detection and filtering
- Oracle reliability scoring
- Coordinated submission timing
- Circuit breaker integration
- Real-time price monitoring

Usage:
  python price_coordinator.py --pairs STX/USD,BTC/USD --interval 60
  python price_coordinator.py --config feeds.conf --mode continuous
"""

import os
import time
import json
import asyncio
import logging
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("price-coordinator")

class PriceSource(Enum):
    COINBASE = "coinbase"
    BINANCE = "binance"
    KRAKEN = "kraken"
    COINGECKO = "coingecko"
    COINMARKETCAP = "coinmarketcap"

@dataclass
class PriceData:
    """Individual price data point"""
    source: str
    price: float
    timestamp: int
    confidence: float = 1.0
    volume: float = 0.0
    
@dataclass 
class AggregatedPrice:
    """Aggregated price from multiple sources"""
    median_price: float
    mean_price: float
    weighted_price: float
    std_deviation: float
    confidence_score: float
    source_count: int
    sources: List[PriceData] = field(default_factory=list)
    timestamp: int = field(default_factory=lambda: int(time.time()))

@dataclass
class OracleSubmission:
    """Oracle price submission record"""
    oracle_address: str
    price: int
    timestamp: int
    transaction_hash: str = ""
    success: bool = False
    error: str = ""

@dataclass
class CoordinationStrategy:
    """Price coordination strategy configuration"""
    submission_delay_min: int = 5  # Minimum seconds between submissions
    submission_delay_max: int = 30  # Maximum seconds between submissions
    price_staleness_threshold: int = 300  # 5 minutes
    anomaly_detection_threshold: float = 0.05  # 5% deviation
    min_confidence_score: float = 0.7
    max_price_age_seconds: int = 60
    oracle_selection_strategy: str = "round_robin"  # round_robin, best_reliability, random

class PriceFeedCoordinator:
    """Main price feed coordination system"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.trading_pairs = config.get("trading_pairs", [])
        self.oracle_addresses = config.get("oracle_addresses", [])
        self.strategy = CoordinationStrategy(**config.get("strategy", {}))
        
        # State tracking
        self.price_history: Dict[str, List[AggregatedPrice]] = {}
        self.oracle_reliability: Dict[str, float] = {}
        self.last_submissions: Dict[str, int] = {}
        self.active_submissions: Dict[str, List[OracleSubmission]] = {}
        
        # External price sources
        self.price_sources = {
            PriceSource.COINBASE: self._fetch_coinbase_price,
            PriceSource.BINANCE: self._fetch_binance_price,
            PriceSource.KRAKEN: self._fetch_kraken_price,
            PriceSource.COINGECKO: self._fetch_coingecko_price,
        }
        
    async def start_coordination(self, interval: int = 60):
        """Start continuous price coordination"""
        logger.info(f"Starting price coordination with {interval}s interval")
        
        while True:
            try:
                await self._coordination_cycle()
                await asyncio.sleep(interval)
            except KeyboardInterrupt:
                logger.info("Price coordination stopped by user")
                break
            except Exception as e:
                logger.error(f"Coordination cycle error: {e}")
                await asyncio.sleep(10)  # Brief pause before retry
                
    async def _coordination_cycle(self):
        """Single coordination cycle for all trading pairs"""
        logger.info("Starting coordination cycle")
        
        for pair in self.trading_pairs:
            try:
                await self._coordinate_pair(pair)
            except Exception as e:
                logger.error(f"Error coordinating {pair}: {e}")
                
    async def _coordinate_pair(self, pair: str):
        """Coordinate price submissions for a single trading pair"""
        base, quote = pair.split("/")
        logger.info(f"Coordinating {pair}")
        
        # Fetch prices from all sources
        aggregated_price = await self._aggregate_prices(base, quote)
        
        if not aggregated_price:
            logger.warning(f"No valid prices available for {pair}")
            return
            
        # Store price history
        if pair not in self.price_history:
            self.price_history[pair] = []
        self.price_history[pair].append(aggregated_price)
        
        # Keep only recent history (last 100 entries)
        if len(self.price_history[pair]) > 100:
            self.price_history[pair] = self.price_history[pair][-100:]
            
        # Detect anomalies
        if self._detect_price_anomaly(pair, aggregated_price):
            logger.warning(f"Price anomaly detected for {pair}, skipping submissions")
            return
            
        # Check if submission is needed
        if not self._should_submit_price(pair, aggregated_price):
            logger.info(f"No price submission needed for {pair}")
            return
            
        # Select oracles for submission
        selected_oracles = self._select_oracles_for_submission(pair)
        
        # Coordinate submissions
        await self._execute_coordinated_submissions(pair, aggregated_price, selected_oracles)
        
    async def _aggregate_prices(self, base: str, quote: str) -> Optional[AggregatedPrice]:
        """Aggregate prices from multiple external sources"""
        logger.debug(f"Aggregating prices for {base}/{quote}")
        
        # Fetch prices from all sources concurrently
        fetch_tasks = []
        for source_type, fetch_func in self.price_sources.items():
            task = fetch_func(base, quote)
            fetch_tasks.append(task)
            
        price_results = await asyncio.gather(*fetch_tasks, return_exceptions=True)
        
        # Filter valid prices
        valid_prices = []
        for i, result in enumerate(price_results):
            if isinstance(result, PriceData) and result.price > 0:
                valid_prices.append(result)
            elif isinstance(result, Exception):
                source_name = list(self.price_sources.keys())[i].value
                logger.warning(f"Failed to fetch from {source_name}: {result}")
                
        if len(valid_prices) < 2:
            logger.warning(f"Insufficient price sources: {len(valid_prices)}")
            return None
            
        # Calculate aggregated metrics
        prices = [p.price for p in valid_prices]
        weights = [p.confidence * (p.volume if p.volume > 0 else 1.0) for p in valid_prices]
        
        median_price = statistics.median(prices)
        mean_price = statistics.mean(prices)
        std_dev = statistics.stdev(prices) if len(prices) > 1 else 0.0
        
        # Calculate weighted average
        total_weight = sum(weights)
        weighted_price = sum(p * w for p, w in zip(prices, weights)) / total_weight
        
        # Calculate confidence score based on price consistency
        confidence_score = max(0.0, 1.0 - (std_dev / mean_price)) if mean_price > 0 else 0.0
        
        return AggregatedPrice(
            median_price=median_price,
            mean_price=mean_price,
            weighted_price=weighted_price,
            std_deviation=std_dev,
            confidence_score=confidence_score,
            source_count=len(valid_prices),
            sources=valid_prices
        )
        
    def _detect_price_anomaly(self, pair: str, current_price: AggregatedPrice) -> bool:
        """Detect if current price represents an anomaly"""
        if pair not in self.price_history or len(self.price_history[pair]) < 3:
            return False
            
        recent_prices = [p.weighted_price for p in self.price_history[pair][-10:]]
        recent_median = statistics.median(recent_prices)
        
        # Check for excessive deviation from recent median
        deviation = abs(current_price.weighted_price - recent_median) / recent_median
        
        if deviation > self.strategy.anomaly_detection_threshold:
            logger.warning(f"Anomaly detected: {deviation:.3%} deviation from recent median")
            return True
            
        # Check confidence score
        if current_price.confidence_score < self.strategy.min_confidence_score:
            logger.warning(f"Low confidence score: {current_price.confidence_score:.3f}")
            return True
            
        return False
        
    def _should_submit_price(self, pair: str, price: AggregatedPrice) -> bool:
        """Determine if price submission is needed"""
        # Check if enough time has passed since last submission
        last_submission = self.last_submissions.get(pair, 0)
        time_since_last = int(time.time()) - last_submission
        
        if time_since_last < self.strategy.submission_delay_min:
            return False
            
        # Check if price is fresh enough
        price_age = int(time.time()) - price.timestamp
        if price_age > self.strategy.max_price_age_seconds:
            logger.warning(f"Price too old: {price_age}s")
            return False
            
        # Check for significant price change
        if pair in self.price_history and len(self.price_history[pair]) > 0:
            last_price = self.price_history[pair][-2] if len(self.price_history[pair]) > 1 else self.price_history[pair][-1]
            price_change = abs(price.weighted_price - last_price.weighted_price) / last_price.weighted_price
            
            # Submit if significant change or enough time has passed
            if price_change > 0.001 or time_since_last > self.strategy.submission_delay_max:
                return True
        else:
            # Always submit first price
            return True
            
        return False
        
    def _select_oracles_for_submission(self, pair: str) -> List[str]:
        """Select which oracles should submit prices"""
        available_oracles = self.oracle_addresses.copy()
        
        if self.strategy.oracle_selection_strategy == "round_robin":
            # Simple round-robin selection
            pair_hash = hash(pair) % len(available_oracles)
            selected_count = min(3, len(available_oracles))  # Submit through 3 oracles
            selected = []
            for i in range(selected_count):
                idx = (pair_hash + i) % len(available_oracles)
                selected.append(available_oracles[idx])
            return selected
            
        elif self.strategy.oracle_selection_strategy == "best_reliability":
            # Select oracles with best reliability scores
            oracle_scores = [(addr, self.oracle_reliability.get(addr, 0.5)) for addr in available_oracles]
            oracle_scores.sort(key=lambda x: x[1], reverse=True)
            return [addr for addr, score in oracle_scores[:3]]
            
        else:
            # Random selection
            import random
            return random.sample(available_oracles, min(3, len(available_oracles)))
            
    async def _execute_coordinated_submissions(self, pair: str, price: AggregatedPrice, oracles: List[str]):
        """Execute coordinated price submissions through selected oracles"""
        logger.info(f"Executing coordinated submissions for {pair} through {len(oracles)} oracles")
        
        # Convert price to integer (assuming 6 decimal places)
        price_int = int(price.weighted_price * 1_000_000)
        
        # Create submission tasks with staggered timing
        submission_tasks = []
        for i, oracle in enumerate(oracles):
            delay = i * 5  # 5 second stagger between submissions
            task = self._submit_price_with_delay(pair, oracle, price_int, delay)
            submission_tasks.append(task)
            
        # Execute all submissions concurrently
        submissions = await asyncio.gather(*submission_tasks, return_exceptions=True)
        
        # Track submissions
        if pair not in self.active_submissions:
            self.active_submissions[pair] = []
            
        successful_submissions = 0
        for i, result in enumerate(submissions):
            if isinstance(result, OracleSubmission) and result.success:
                successful_submissions += 1
                self.active_submissions[pair].append(result)
                # Update oracle reliability
                self.oracle_reliability[result.oracle_address] = min(1.0, 
                    self.oracle_reliability.get(result.oracle_address, 0.5) + 0.1)
            elif isinstance(result, Exception):
                logger.error(f"Submission failed for oracle {oracles[i]}: {result}")
                # Decrease oracle reliability
                self.oracle_reliability[oracles[i]] = max(0.0,
                    self.oracle_reliability.get(oracles[i], 0.5) - 0.1)
                    
        logger.info(f"Completed {successful_submissions}/{len(oracles)} submissions for {pair}")
        self.last_submissions[pair] = int(time.time())
        
    async def _submit_price_with_delay(self, pair: str, oracle: str, price: int, delay: int) -> OracleSubmission:
        """Submit price through oracle with specified delay"""
        if delay > 0:
            await asyncio.sleep(delay)
            
        logger.info(f"Submitting price {price} for {pair} via oracle {oracle}")
        
        submission = OracleSubmission(
            oracle_address=oracle,
            price=price,
            timestamp=int(time.time())
        )
        
        try:
            # TODO: Implement actual blockchain transaction
            # For now, simulate submission
            if self.config.get("dry_run", True):
                logger.info("DRY RUN: Price submission simulated")
                submission.success = True
                submission.transaction_hash = f"mock_tx_{int(time.time())}"
            else:
                # Call oracle-aggregator.submit-price(base, quote, price) from oracle account
                pass
                
        except Exception as e:
            submission.error = str(e)
            logger.error(f"Price submission failed: {e}")
            
        return submission
        
    # External Price Source Implementations
    
    async def _fetch_coinbase_price(self, base: str, quote: str) -> PriceData:
        """Fetch price from Coinbase API"""
        try:
            # TODO: Implement actual Coinbase API call
            # For now, return mock data
            await asyncio.sleep(0.1)  # Simulate API delay
            return PriceData(
                source="coinbase",
                price=123.45,  # Mock price
                timestamp=int(time.time()),
                confidence=0.9,
                volume=1000.0
            )
        except Exception as e:
            raise Exception(f"Coinbase API error: {e}")
            
    async def _fetch_binance_price(self, base: str, quote: str) -> PriceData:
        """Fetch price from Binance API"""
        try:
            # TODO: Implement actual Binance API call
            await asyncio.sleep(0.1)
            return PriceData(
                source="binance",
                price=123.50,  # Mock price
                timestamp=int(time.time()),
                confidence=0.9,
                volume=2000.0
            )
        except Exception as e:
            raise Exception(f"Binance API error: {e}")
            
    async def _fetch_kraken_price(self, base: str, quote: str) -> PriceData:
        """Fetch price from Kraken API"""
        try:
            # TODO: Implement actual Kraken API call
            await asyncio.sleep(0.1)
            return PriceData(
                source="kraken",
                price=123.40,  # Mock price
                timestamp=int(time.time()),
                confidence=0.8,
                volume=500.0
            )
        except Exception as e:
            raise Exception(f"Kraken API error: {e}")
            
    async def _fetch_coingecko_price(self, base: str, quote: str) -> PriceData:
        """Fetch price from CoinGecko API"""
        try:
            # TODO: Implement actual CoinGecko API call
            await asyncio.sleep(0.1)
            return PriceData(
                source="coingecko",
                price=123.48,  # Mock price
                timestamp=int(time.time()),
                confidence=0.7
            )
        except Exception as e:
            raise Exception(f"CoinGecko API error: {e}")
            
    # Monitoring and Reporting
    
    def get_status_report(self) -> Dict[str, Any]:
        """Generate comprehensive status report"""
        return {
            "trading_pairs": len(self.trading_pairs),
            "oracle_addresses": len(self.oracle_addresses),
            "price_history_size": {pair: len(history) for pair, history in self.price_history.items()},
            "oracle_reliability": self.oracle_reliability.copy(),
            "last_submissions": self.last_submissions.copy(),
            "active_submissions": {pair: len(subs) for pair, subs in self.active_submissions.items()},
            "strategy": {
                "submission_delay_min": self.strategy.submission_delay_min,
                "submission_delay_max": self.strategy.submission_delay_max,
                "anomaly_threshold": self.strategy.anomaly_detection_threshold,
                "confidence_threshold": self.strategy.min_confidence_score
            }
        }

# Configuration and Main Execution

def load_config(config_file: Optional[str] = None) -> Dict[str, Any]:
    """Load configuration from file or environment"""
    config = {
        "trading_pairs": os.getenv("TRADING_PAIRS", "STX/USD,BTC/USD").split(","),
        "oracle_addresses": os.getenv("ORACLE_ADDRESSES", "").split(",") if os.getenv("ORACLE_ADDRESSES") else [],
        "dry_run": os.getenv("DRY_RUN", "true").lower() == "true",
        "strategy": {
            "submission_delay_min": int(os.getenv("SUBMISSION_DELAY_MIN", "5")),
            "submission_delay_max": int(os.getenv("SUBMISSION_DELAY_MAX", "30")),
            "anomaly_detection_threshold": float(os.getenv("ANOMALY_THRESHOLD", "0.05")),
            "min_confidence_score": float(os.getenv("MIN_CONFIDENCE", "0.7"))
        }
    }
    
    if config_file and os.path.exists(config_file):
        # TODO: Load from JSON/YAML config file
        pass
        
    return config

async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Price Feed Coordinator")
    parser.add_argument("--pairs", help="Trading pairs (comma-separated)")
    parser.add_argument("--interval", type=int, default=60, help="Coordination interval (seconds)")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--dry-run", action="store_true", help="Dry run mode")
    parser.add_argument("--mode", choices=["continuous", "single"], default="continuous", help="Execution mode")
    
    args = parser.parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    if args.pairs:
        config["trading_pairs"] = args.pairs.split(",")
    if args.dry_run:
        config["dry_run"] = True
        
    logger.info(f"Starting Price Feed Coordinator")
    logger.info(f"Trading pairs: {config['trading_pairs']}")
    logger.info(f"Dry run mode: {config['dry_run']}")
    
    coordinator = PriceFeedCoordinator(config)
    
    try:
        if args.mode == "continuous":
            await coordinator.start_coordination(args.interval)
        else:
            # Single coordination cycle
            await coordinator._coordination_cycle()
            
        # Print final status
        status = coordinator.get_status_report()
        print("\nFinal Status Report:")
        print(json.dumps(status, indent=2))
        
    except KeyboardInterrupt:
        logger.info("Price Feed Coordinator stopped by user")
    except Exception as e:
        logger.error(f"Price Feed Coordinator error: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())
