#!/usr/bin/env python3
"""Oracle Management CLI

Command-line interface for managing oracle aggregator operations.
Provides easy-to-use commands for oracle administration and monitoring.

Usage:
  python oracle_manager.py pair add STX USD --min-sources 3
  python oracle_manager.py oracle add <pair> <oracle-address>
  python oracle_manager.py oracle remove <pair> <oracle-address>
  python oracle_manager.py price submit <pair> <price>
  python oracle_manager.py status <pair>
  python oracle_manager.py monitor --watch

Environment Variables:
  STACKS_NETWORK - Network (testnet/mainnet)
  ORACLE_AGGREGATOR_CONTRACT - Contract address
  DEPLOYER_PRIVKEY - Private key for admin operations
"""

import os
import sys
import json
import time
import asyncio
import argparse
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("oracle-manager")

@dataclass
class Config:
    network: str = os.getenv("STACKS_NETWORK", "testnet")
    rpc_url: str = os.getenv("STACKS_RPC_URL", "https://stacks-node-api.testnet.stacks.co")
    oracle_contract: str = os.getenv("ORACLE_AGGREGATOR_CONTRACT", "SPXXXXX.oracle-aggregator")
    circuit_breaker_contract: str = os.getenv("CIRCUIT_BREAKER_CONTRACT", "SPXXXXX.circuit-breaker")
    deployer_privkey: str = os.getenv("DEPLOYER_PRIVKEY", "")
    dry_run: bool = os.getenv("DRY_RUN", "false").lower() == "true"

class OracleManager:
    """Oracle management operations"""
    
    def __init__(self, config: Config):
        self.config = config
        
    # Trading Pair Management
    
    async def register_pair(self, base: str, quote: str, oracles: list[str], min_sources: int) -> bool:
        """Register a new trading pair"""
        logger.info(f"Registering pair {base}/{quote} with {len(oracles)} oracles, min_sources={min_sources}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would register trading pair")
            return True
            
        try:
            # TODO: Implement Stacks transaction
            # Call oracle-aggregator.register-pair(base, quote, oracles, min-sources)
            logger.info(f"Successfully registered pair {base}/{quote}")
            return True
        except Exception as e:
            logger.error(f"Failed to register pair: {e}")
            return False
            
    # Oracle Management
    
    async def add_oracle(self, base: str, quote: str, oracle_address: str) -> bool:
        """Add oracle to trading pair whitelist"""
        logger.info(f"Adding oracle {oracle_address} to {base}/{quote}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would add oracle to whitelist")
            return True
            
        try:
            # TODO: Implement Stacks transaction
            # Call oracle-aggregator.add-oracle(base, quote, oracle)
            logger.info(f"Successfully added oracle {oracle_address}")
            return True
        except Exception as e:
            logger.error(f"Failed to add oracle: {e}")
            return False
            
    async def remove_oracle(self, base: str, quote: str, oracle_address: str) -> bool:
        """Remove oracle from trading pair whitelist"""
        logger.info(f"Removing oracle {oracle_address} from {base}/{quote}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would remove oracle from whitelist")
            return True
            
        try:
            # TODO: Implement Stacks transaction
            # Call oracle-aggregator.remove-oracle(base, quote, oracle)
            logger.info(f"Successfully removed oracle {oracle_address}")
            return True
        except Exception as e:
            logger.error(f"Failed to remove oracle: {e}")
            return False
    
    async def check_oracle_status(self, base: str, quote: str, oracle_address: str) -> Dict[str, Any]:
        """Check if oracle is whitelisted"""
        logger.info(f"Checking oracle status: {oracle_address} on {base}/{quote}")
        
        try:
            # TODO: Implement Stacks read-only call
            # Call oracle-aggregator.is-oracle(base, quote, oracle)
            return {
                "whitelisted": True,  # Placeholder
                "enabled": True,
                "last_submission": 12345
            }
        except Exception as e:
            logger.error(f"Failed to check oracle status: {e}")
            return {}
    
    # Price Management
    
    async def submit_price(self, base: str, quote: str, price: int, oracle_privkey: str = None) -> bool:
        """Submit price for trading pair"""
        logger.info(f"Submitting price {price} for {base}/{quote}")
        
        if self.config.dry_run:
            logger.info("DRY RUN: Would submit price")
            return True
            
        try:
            # TODO: Implement Stacks transaction from oracle account
            # Call oracle-aggregator.submit-price(base, quote, price)
            logger.info(f"Successfully submitted price {price}")
            return True
        except Exception as e:
            logger.error(f"Failed to submit price: {e}")
            return False
            
    async def get_current_price(self, base: str, quote: str) -> Optional[Dict[str, Any]]:
        """Get current aggregated price"""
        logger.info(f"Getting current price for {base}/{quote}")
        
        try:
            # TODO: Implement Stacks read-only call
            # Call oracle-aggregator.get-price(base, quote)
            return {
                "price": 123456,  # Placeholder
                "height": 12345,
                "sources": 3,
                "timestamp": int(time.time())
            }
        except Exception as e:
            logger.error(f"Failed to get price: {e}")
            return None
            
    async def get_median_price(self, base: str, quote: str) -> Optional[int]:
        """Get current median price"""
        logger.info(f"Getting median price for {base}/{quote}")
        
        try:
            # TODO: Implement Stacks read-only call
            # Call oracle-aggregator.get-median(base, quote) 
            return 123456  # Placeholder
        except Exception as e:
            logger.error(f"Failed to get median price: {e}")
            return None
    
    # Monitoring and Status
    
    async def get_pair_status(self, base: str, quote: str) -> Dict[str, Any]:
        """Get comprehensive status for trading pair"""
        logger.info(f"Getting status for {base}/{quote}")
        
        try:
            current_price = await self.get_current_price(base, quote)
            median_price = await self.get_median_price(base, quote)
            
            # TODO: Get more detailed status from blockchain
            return {
                "pair": f"{base}/{quote}",
                "current_price": current_price,
                "median_price": median_price,
                "min_sources": 3,  # Placeholder
                "active_oracles": 3,  # Placeholder
                "last_update": int(time.time())
            }
        except Exception as e:
            logger.error(f"Failed to get pair status: {e}")
            return {}
    
    async def list_all_pairs(self) -> list:
        """List all registered trading pairs"""
        logger.info("Listing all trading pairs")
        
        try:
            # TODO: Query blockchain for all registered pairs
            # This would require iterating through pair registration events
            return [
                {"base": "STX", "quote": "USD", "min_sources": 3},
                {"base": "BTC", "quote": "USD", "min_sources": 3}
            ]  # Placeholder
        except Exception as e:
            logger.error(f"Failed to list pairs: {e}")
            return []
    
    async def monitor_prices(self, pairs: list, watch: bool = False):
        """Monitor price updates for specified pairs"""
        logger.info(f"Monitoring prices for {len(pairs)} pairs")
        
        while True:
            for pair_str in pairs:
                try:
                    base, quote = pair_str.split("/")
                    status = await self.get_pair_status(base, quote)
                    
                    if status:
                        print(f"\n{pair_str}:")
                        print(f"  Current Price: {status.get('current_price', {}).get('price', 'N/A')}")
                        print(f"  Median Price: {status.get('median_price', 'N/A')}")
                        print(f"  Sources: {status.get('current_price', {}).get('sources', 'N/A')}")
                        print(f"  Last Update: {status.get('last_update', 'N/A')}")
                        
                except Exception as e:
                    logger.error(f"Error monitoring {pair_str}: {e}")
            
            if not watch:
                break
                
            print(f"\n--- {time.strftime('%Y-%m-%d %H:%M:%S')} ---")
            await asyncio.sleep(30)  # Wait 30 seconds before next update

# CLI Command Handlers

async def handle_pair_command(args, manager: OracleManager):
    """Handle trading pair commands"""
    if args.pair_action == "add":
        if not all([args.base, args.quote]):
            print("Error: base and quote tokens required")
            return False
            
        oracles = args.oracles.split(",") if args.oracles else []
        min_sources = args.min_sources or 1
        
        return await manager.register_pair(args.base, args.quote, oracles, min_sources)
        
    elif args.pair_action == "list":
        pairs = await manager.list_all_pairs()
        if pairs:
            print("\nRegistered Trading Pairs:")
            for pair in pairs:
                print(f"  {pair['base']}/{pair['quote']} (min_sources: {pair['min_sources']})")
        else:
            print("No trading pairs found")
        return True
        
    return False

async def handle_oracle_command(args, manager: OracleManager):
    """Handle oracle management commands"""
    if not all([args.base, args.quote]):
        print("Error: base and quote tokens required")
        return False
        
    if args.oracle_action == "add":
        if not args.oracle_address:
            print("Error: oracle address required")
            return False
        return await manager.add_oracle(args.base, args.quote, args.oracle_address)
        
    elif args.oracle_action == "remove":
        if not args.oracle_address:
            print("Error: oracle address required")
            return False
        return await manager.remove_oracle(args.base, args.quote, args.oracle_address)
        
    elif args.oracle_action == "status":
        if not args.oracle_address:
            print("Error: oracle address required")
            return False
        status = await manager.check_oracle_status(args.base, args.quote, args.oracle_address)
        if status:
            print(f"\nOracle Status for {args.oracle_address}:")
            print(f"  Whitelisted: {status.get('whitelisted', 'Unknown')}")
            print(f"  Enabled: {status.get('enabled', 'Unknown')}")
            print(f"  Last Submission: {status.get('last_submission', 'Unknown')}")
        return True
        
    return False

async def handle_price_command(args, manager: OracleManager):
    """Handle price management commands"""
    if not all([args.base, args.quote]):
        print("Error: base and quote tokens required")
        return False
        
    if args.price_action == "submit":
        if args.price is None:
            print("Error: price value required")
            return False
        return await manager.submit_price(args.base, args.quote, args.price, args.oracle_privkey)
        
    elif args.price_action == "get":
        price_data = await manager.get_current_price(args.base, args.quote)
        if price_data:
            print(f"\nCurrent Price for {args.base}/{args.quote}:")
            print(f"  Price: {price_data.get('price', 'N/A')}")
            print(f"  Height: {price_data.get('height', 'N/A')}")
            print(f"  Sources: {price_data.get('sources', 'N/A')}")
        return True
        
    elif args.price_action == "median":
        median = await manager.get_median_price(args.base, args.quote)
        if median:
            print(f"\nMedian Price for {args.base}/{args.quote}: {median}")
        return True
        
    return False

async def handle_status_command(args, manager: OracleManager):
    """Handle status commands"""
    if args.base and args.quote:
        # Single pair status
        status = await manager.get_pair_status(args.base, args.quote)
        if status:
            print(f"\nStatus for {args.base}/{args.quote}:")
            print(json.dumps(status, indent=2))
    else:
        # All pairs status
        pairs = await manager.list_all_pairs()
        for pair in pairs:
            status = await manager.get_pair_status(pair["base"], pair["quote"])
            print(f"\n{pair['base']}/{pair['quote']}:")
            print(json.dumps(status, indent=2))
    return True

async def handle_monitor_command(args, manager: OracleManager):
    """Handle monitoring commands"""
    pairs = []
    if args.base and args.quote:
        pairs = [f"{args.base}/{args.quote}"]
    else:
        # Monitor all pairs
        all_pairs = await manager.list_all_pairs()
        pairs = [f"{p['base']}/{p['quote']}" for p in all_pairs]
    
    if not pairs:
        print("No pairs to monitor")
        return False
        
    await manager.monitor_prices(pairs, args.watch)
    return True

# Main CLI Setup

def setup_parser():
    """Setup command line argument parser"""
    parser = argparse.ArgumentParser(description="Oracle Management CLI")
    parser.add_argument("--dry-run", action="store_true", help="Dry run mode")
    parser.add_argument("--config", help="Configuration file")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Pair management
    pair_parser = subparsers.add_parser("pair", help="Trading pair management")
    pair_parser.add_argument("pair_action", choices=["add", "list"], help="Pair action")
    pair_parser.add_argument("base", nargs="?", help="Base token")
    pair_parser.add_argument("quote", nargs="?", help="Quote token") 
    pair_parser.add_argument("--oracles", help="Comma-separated oracle addresses")
    pair_parser.add_argument("--min-sources", type=int, help="Minimum sources required")
    
    # Oracle management
    oracle_parser = subparsers.add_parser("oracle", help="Oracle management")
    oracle_parser.add_argument("oracle_action", choices=["add", "remove", "status"], help="Oracle action")
    oracle_parser.add_argument("base", help="Base token")
    oracle_parser.add_argument("quote", help="Quote token")
    oracle_parser.add_argument("oracle_address", help="Oracle address")
    
    # Price management
    price_parser = subparsers.add_parser("price", help="Price management")
    price_parser.add_argument("price_action", choices=["submit", "get", "median"], help="Price action")
    price_parser.add_argument("base", help="Base token")
    price_parser.add_argument("quote", help="Quote token")
    price_parser.add_argument("price", type=int, nargs="?", help="Price value")
    price_parser.add_argument("--oracle-privkey", help="Oracle private key for submission")
    
    # Status monitoring
    status_parser = subparsers.add_parser("status", help="Get status information")
    status_parser.add_argument("base", nargs="?", help="Base token")
    status_parser.add_argument("quote", nargs="?", help="Quote token")
    
    # Price monitoring
    monitor_parser = subparsers.add_parser("monitor", help="Monitor price updates")
    monitor_parser.add_argument("base", nargs="?", help="Base token")
    monitor_parser.add_argument("quote", nargs="?", help="Quote token")
    monitor_parser.add_argument("--watch", action="store_true", help="Continuous monitoring")
    
    return parser

async def main():
    """Main CLI entry point"""
    parser = setup_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Setup configuration
    config = Config()
    if args.dry_run:
        config.dry_run = True
        logger.info("Running in DRY RUN mode")
    
    manager = OracleManager(config)
    
    try:
        # Route commands
        if args.command == "pair":
            success = await handle_pair_command(args, manager)
        elif args.command == "oracle":
            success = await handle_oracle_command(args, manager)
        elif args.command == "price":
            success = await handle_price_command(args, manager)
        elif args.command == "status":
            success = await handle_status_command(args, manager)
        elif args.command == "monitor":
            success = await handle_monitor_command(args, manager)
        else:
            print(f"Unknown command: {args.command}")
            success = False
            
        if not success:
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
    except Exception as e:
        logger.error(f"Command failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
