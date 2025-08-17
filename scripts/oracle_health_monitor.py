#!/usr/bin/env python3
"""Oracle Health Monitor

Comprehensive monitoring system for oracle health, performance, and reliability.
Tracks oracle responsiveness, accuracy, and provides alerting for issues.

Features:
- Real-time oracle health monitoring
- Performance metrics tracking
- Accuracy scoring and validation
- Automated alerting and notifications
- Health dashboard data generation
- Circuit breaker integration

Usage:
  python oracle_health_monitor.py --monitor-all
  python oracle_health_monitor.py --oracle SP123...ORACLE --pair STX/USD
  python oracle_health_monitor.py --dashboard --port 8080
"""

import os
import time
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
import statistics

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("oracle-health-monitor")

class HealthStatus(Enum):
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    OFFLINE = "offline"

class AlertLevel(Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"

@dataclass
class OracleMetrics:
    """Oracle performance metrics"""
    oracle_address: str
    pair: str
    
    # Response metrics
    response_time_ms: List[float] = field(default_factory=list)
    uptime_percentage: float = 0.0
    consecutive_failures: int = 0
    last_successful_submission: int = 0
    
    # Accuracy metrics
    price_submissions: List[Tuple[int, float]] = field(default_factory=list)  # (timestamp, price)
    accuracy_score: float = 0.0
    deviation_from_median: List[float] = field(default_factory=list)
    
    # Reliability metrics
    submission_frequency: float = 0.0  # submissions per hour
    missed_submissions: int = 0
    error_rate: float = 0.0
    
    # Health status
    health_status: HealthStatus = HealthStatus.OFFLINE
    last_health_check: int = 0
    health_score: float = 0.0

@dataclass
class AlertEvent:
    """Alert event data"""
    timestamp: int
    level: AlertLevel
    oracle_address: str
    pair: str
    message: str
    metrics: Dict[str, Any] = field(default_factory=dict)

@dataclass
class HealthCheckConfig:
    """Health monitoring configuration"""
    check_interval: int = 120  # seconds
    response_timeout: int = 30  # seconds
    max_consecutive_failures: int = 3
    min_uptime_threshold: float = 0.95  # 95%
    max_deviation_threshold: float = 0.02  # 2%
    min_submission_frequency: float = 0.5  # per hour
    alert_webhook_url: str = ""
    dashboard_enabled: bool = False

class OracleHealthMonitor:
    """Main oracle health monitoring system"""
    
    def __init__(self, config: HealthCheckConfig):
        self.config = config
        self.oracle_metrics: Dict[str, OracleMetrics] = {}
        self.alert_history: List[AlertEvent] = []
        self.monitoring_active = False
        
        # External data for comparison (mock sources)
        self.external_price_sources = ["coinbase", "binance", "kraken"]
        
    async def start_monitoring(self, oracle_addresses: List[str], trading_pairs: List[str]):
        """Start monitoring specified oracles and trading pairs"""
        logger.info(f"Starting health monitoring for {len(oracle_addresses)} oracles and {len(trading_pairs)} pairs")
        
        # Initialize metrics for all oracle-pair combinations
        for oracle in oracle_addresses:
            for pair in trading_pairs:
                key = f"{oracle}:{pair}"
                self.oracle_metrics[key] = OracleMetrics(
                    oracle_address=oracle,
                    pair=pair,
                    last_health_check=int(time.time())
                )
                
        self.monitoring_active = True
        
        # Start monitoring loops
        await asyncio.gather(
            self._health_check_loop(),
            self._metrics_collection_loop(),
            self._alert_processing_loop()
        )
        
    async def _health_check_loop(self):
        """Main health check loop"""
        while self.monitoring_active:
            try:
                await self._perform_health_checks()
                await asyncio.sleep(self.config.check_interval)
            except Exception as e:
                logger.error(f"Health check loop error: {e}")
                await asyncio.sleep(10)
                
    async def _metrics_collection_loop(self):
        """Metrics collection loop"""
        while self.monitoring_active:
            try:
                await self._collect_metrics()
                await asyncio.sleep(60)  # Collect metrics every minute
            except Exception as e:
                logger.error(f"Metrics collection error: {e}")
                await asyncio.sleep(10)
                
    async def _alert_processing_loop(self):
        """Alert processing loop"""
        while self.monitoring_active:
            try:
                await self._process_alerts()
                await asyncio.sleep(30)  # Process alerts every 30 seconds
            except Exception as e:
                logger.error(f"Alert processing error: {e}")
                await asyncio.sleep(10)
                
    async def _perform_health_checks(self):
        """Perform health checks on all monitored oracles"""
        logger.info("Performing health checks...")
        
        check_tasks = []
        for key, metrics in self.oracle_metrics.items():
            task = self._check_oracle_health(metrics)
            check_tasks.append(task)
            
        await asyncio.gather(*check_tasks, return_exceptions=True)
        
    async def _check_oracle_health(self, metrics: OracleMetrics):
        """Check health of a specific oracle"""
        logger.debug(f"Checking health of {metrics.oracle_address} for {metrics.pair}")
        
        start_time = time.time()
        
        try:
            # Check if oracle is responsive
            is_responsive = await self._check_oracle_responsiveness(metrics.oracle_address, metrics.pair)
            
            response_time = (time.time() - start_time) * 1000  # Convert to milliseconds
            metrics.response_time_ms.append(response_time)
            
            # Keep only last 100 response times
            if len(metrics.response_time_ms) > 100:
                metrics.response_time_ms = metrics.response_time_ms[-100:]
                
            if is_responsive:
                metrics.consecutive_failures = 0
                metrics.last_successful_submission = int(time.time())
            else:
                metrics.consecutive_failures += 1
                
            # Update health status
            await self._update_health_status(metrics)
            
        except Exception as e:
            logger.error(f"Health check failed for {metrics.oracle_address}: {e}")
            metrics.consecutive_failures += 1
            metrics.health_status = HealthStatus.CRITICAL
            
        metrics.last_health_check = int(time.time())
        
    async def _check_oracle_responsiveness(self, oracle_address: str, pair: str) -> bool:
        """Check if oracle is responsive"""
        try:
            # TODO: Implement actual blockchain query
            # Check if oracle is whitelisted and has recent submissions
            # For now, simulate responsiveness check
            await asyncio.sleep(0.1)  # Simulate network delay
            
            # Mock logic: oracle is responsive if it's been checked recently
            return True  # Placeholder
            
        except Exception:
            return False
            
    async def _update_health_status(self, metrics: OracleMetrics):
        """Update oracle health status based on metrics"""
        score = 0.0
        
        # Response time score (30% weight)
        if metrics.response_time_ms:
            avg_response = statistics.mean(metrics.response_time_ms[-10:])  # Last 10 checks
            response_score = max(0, 1 - (avg_response / (self.config.response_timeout * 1000)))
            score += response_score * 0.3
            
        # Failure rate score (40% weight)
        failure_score = max(0, 1 - (metrics.consecutive_failures / self.config.max_consecutive_failures))
        score += failure_score * 0.4
        
        # Submission frequency score (30% weight)
        frequency_score = min(1, metrics.submission_frequency / self.config.min_submission_frequency)
        score += frequency_score * 0.3
        
        metrics.health_score = score
        
        # Determine health status
        if score >= 0.8:
            metrics.health_status = HealthStatus.HEALTHY
        elif score >= 0.6:
            metrics.health_status = HealthStatus.WARNING
        elif score >= 0.3:
            metrics.health_status = HealthStatus.CRITICAL
        else:
            metrics.health_status = HealthStatus.OFFLINE
            
    async def _collect_metrics(self):
        """Collect performance and accuracy metrics"""
        logger.debug("Collecting metrics...")
        
        for key, metrics in self.oracle_metrics.items():
            try:
                await self._collect_oracle_metrics(metrics)
            except Exception as e:
                logger.error(f"Metrics collection failed for {key}: {e}")
                
    async def _collect_oracle_metrics(self, metrics: OracleMetrics):
        """Collect metrics for a specific oracle"""
        
        # Get recent submissions
        recent_submissions = await self._get_recent_submissions(metrics.oracle_address, metrics.pair)
        
        # Update submission frequency
        if recent_submissions:
            metrics.price_submissions.extend(recent_submissions)
            # Calculate submissions per hour
            one_hour_ago = int(time.time()) - 3600
            recent_count = len([s for s in metrics.price_submissions if s[0] > one_hour_ago])
            metrics.submission_frequency = recent_count
            
        # Calculate accuracy metrics
        await self._calculate_accuracy_metrics(metrics)
        
        # Calculate uptime
        await self._calculate_uptime(metrics)
        
    async def _get_recent_submissions(self, oracle_address: str, pair: str) -> List[Tuple[int, float]]:
        """Get recent price submissions from oracle"""
        try:
            # TODO: Query blockchain for recent submissions
            # For now, return mock data
            current_time = int(time.time())
            return [
                (current_time - 300, 123.45),  # 5 minutes ago
                (current_time - 600, 123.50),  # 10 minutes ago
            ]
        except Exception:
            return []
            
    async def _calculate_accuracy_metrics(self, metrics: OracleMetrics):
        """Calculate oracle accuracy metrics"""
        if len(metrics.price_submissions) < 2:
            return
            
        # Get external reference prices for comparison
        external_prices = await self._get_external_reference_prices(metrics.pair)
        
        if not external_prices:
            return
            
        # Calculate deviations from external prices
        deviations = []
        for timestamp, oracle_price in metrics.price_submissions[-10:]:  # Last 10 submissions
            # Find closest external price by timestamp
            closest_external = min(external_prices, key=lambda x: abs(x[0] - timestamp))
            deviation = abs(oracle_price - closest_external[1]) / closest_external[1]
            deviations.append(deviation)
            
        if deviations:
            metrics.deviation_from_median = deviations
            metrics.accuracy_score = max(0, 1 - statistics.mean(deviations))
            
    async def _get_external_reference_prices(self, pair: str) -> List[Tuple[int, float]]:
        """Get external reference prices for accuracy comparison"""
        try:
            # TODO: Fetch real external prices
            # For now, return mock data
            current_time = int(time.time())
            return [
                (current_time - 300, 123.48),
                (current_time - 600, 123.52),
            ]
        except Exception:
            return []
            
    async def _calculate_uptime(self, metrics: OracleMetrics):
        """Calculate oracle uptime percentage"""
        if not metrics.response_time_ms:
            metrics.uptime_percentage = 0.0
            return
            
        # Calculate uptime based on successful health checks
        total_checks = len(metrics.response_time_ms)
        failed_checks = metrics.consecutive_failures
        successful_checks = total_checks - failed_checks
        
        metrics.uptime_percentage = successful_checks / total_checks if total_checks > 0 else 0.0
        
    async def _process_alerts(self):
        """Process and generate alerts based on metrics"""
        for key, metrics in self.oracle_metrics.items():
            await self._check_alert_conditions(metrics)
            
    async def _check_alert_conditions(self, metrics: OracleMetrics):
        """Check if any alert conditions are met"""
        alerts = []
        
        # Check consecutive failures
        if metrics.consecutive_failures >= self.config.max_consecutive_failures:
            alerts.append(AlertEvent(
                timestamp=int(time.time()),
                level=AlertLevel.CRITICAL,
                oracle_address=metrics.oracle_address,
                pair=metrics.pair,
                message=f"Oracle has {metrics.consecutive_failures} consecutive failures",
                metrics={"consecutive_failures": metrics.consecutive_failures}
            ))
            
        # Check uptime
        if metrics.uptime_percentage < self.config.min_uptime_threshold:
            alerts.append(AlertEvent(
                timestamp=int(time.time()),
                level=AlertLevel.WARNING,
                oracle_address=metrics.oracle_address,
                pair=metrics.pair,
                message=f"Oracle uptime is {metrics.uptime_percentage:.1%}",
                metrics={"uptime_percentage": metrics.uptime_percentage}
            ))
            
        # Check accuracy
        if metrics.deviation_from_median and statistics.mean(metrics.deviation_from_median) > self.config.max_deviation_threshold:
            avg_deviation = statistics.mean(metrics.deviation_from_median)
            alerts.append(AlertEvent(
                timestamp=int(time.time()),
                level=AlertLevel.WARNING,
                oracle_address=metrics.oracle_address,
                pair=metrics.pair,
                message=f"Oracle accuracy deviation is {avg_deviation:.1%}",
                metrics={"avg_deviation": avg_deviation}
            ))
            
        # Check submission frequency
        if metrics.submission_frequency < self.config.min_submission_frequency:
            alerts.append(AlertEvent(
                timestamp=int(time.time()),
                level=AlertLevel.WARNING,
                oracle_address=metrics.oracle_address,
                pair=metrics.pair,
                message=f"Oracle submission frequency is {metrics.submission_frequency:.1f}/hour",
                metrics={"submission_frequency": metrics.submission_frequency}
            ))
            
        # Process new alerts
        for alert in alerts:
            await self._handle_alert(alert)
            
    async def _handle_alert(self, alert: AlertEvent):
        """Handle a new alert"""
        # Avoid duplicate alerts (same oracle/pair/level within 5 minutes)
        recent_alerts = [a for a in self.alert_history if 
                        a.oracle_address == alert.oracle_address and
                        a.pair == alert.pair and
                        a.level == alert.level and
                        (alert.timestamp - a.timestamp) < 300]
                        
        if recent_alerts:
            return  # Skip duplicate alert
            
        self.alert_history.append(alert)
        
        # Keep only last 1000 alerts
        if len(self.alert_history) > 1000:
            self.alert_history = self.alert_history[-1000:]
            
        # Log alert
        logger.warning(f"ALERT [{alert.level.value.upper()}] {alert.oracle_address} ({alert.pair}): {alert.message}")
        
        # Send webhook alert if configured
        if self.config.alert_webhook_url:
            await self._send_webhook_alert(alert)
            
    async def _send_webhook_alert(self, alert: AlertEvent):
        """Send alert via webhook"""
        try:
            # TODO: Implement actual webhook sending
            logger.info(f"Would send webhook alert: {alert.message}")
        except Exception as e:
            logger.error(f"Failed to send webhook alert: {e}")
            
    # Public API Methods
    
    def get_oracle_status(self, oracle_address: str, pair: str = None) -> Dict[str, Any]:
        """Get status for specific oracle"""
        if pair:
            key = f"{oracle_address}:{pair}"
            if key in self.oracle_metrics:
                metrics = self.oracle_metrics[key]
                return self._format_oracle_status(metrics)
        else:
            # Return status for all pairs
            status = {}
            for key, metrics in self.oracle_metrics.items():
                if metrics.oracle_address == oracle_address:
                    status[metrics.pair] = self._format_oracle_status(metrics)
            return status
            
        return {}
        
    def _format_oracle_status(self, metrics: OracleMetrics) -> Dict[str, Any]:
        """Format oracle metrics for status response"""
        return {
            "oracle_address": metrics.oracle_address,
            "pair": metrics.pair,
            "health_status": metrics.health_status.value,
            "health_score": round(metrics.health_score, 3),
            "uptime_percentage": round(metrics.uptime_percentage, 3),
            "accuracy_score": round(metrics.accuracy_score, 3),
            "submission_frequency": round(metrics.submission_frequency, 2),
            "consecutive_failures": metrics.consecutive_failures,
            "last_health_check": metrics.last_health_check,
            "avg_response_time": round(statistics.mean(metrics.response_time_ms[-10:]), 1) if metrics.response_time_ms else 0
        }
        
    def get_system_health_summary(self) -> Dict[str, Any]:
        """Get overall system health summary"""
        if not self.oracle_metrics:
            return {"status": "no_data"}
            
        total_oracles = len(set(m.oracle_address for m in self.oracle_metrics.values()))
        healthy_count = len([m for m in self.oracle_metrics.values() if m.health_status == HealthStatus.HEALTHY])
        warning_count = len([m for m in self.oracle_metrics.values() if m.health_status == HealthStatus.WARNING])
        critical_count = len([m for m in self.oracle_metrics.values() if m.health_status == HealthStatus.CRITICAL])
        offline_count = len([m for m in self.oracle_metrics.values() if m.health_status == HealthStatus.OFFLINE])
        
        avg_health_score = statistics.mean([m.health_score for m in self.oracle_metrics.values()])
        avg_uptime = statistics.mean([m.uptime_percentage for m in self.oracle_metrics.values()])
        
        recent_alerts = [a for a in self.alert_history if (int(time.time()) - a.timestamp) < 3600]  # Last hour
        
        return {
            "total_oracles": total_oracles,
            "healthy": healthy_count,
            "warning": warning_count,
            "critical": critical_count,
            "offline": offline_count,
            "avg_health_score": round(avg_health_score, 3),
            "avg_uptime": round(avg_uptime, 3),
            "recent_alerts": len(recent_alerts),
            "monitoring_active": self.monitoring_active,
            "last_update": int(time.time())
        }
        
    def get_recent_alerts(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent alerts"""
        recent = sorted(self.alert_history, key=lambda x: x.timestamp, reverse=True)[:limit]
        return [
            {
                "timestamp": alert.timestamp,
                "level": alert.level.value,
                "oracle": alert.oracle_address,
                "pair": alert.pair,
                "message": alert.message,
                "metrics": alert.metrics
            }
            for alert in recent
        ]

# Main execution and CLI

async def monitor_single_oracle(oracle_address: str, pair: str, config: HealthCheckConfig):
    """Monitor a single oracle-pair combination"""
    monitor = OracleHealthMonitor(config)
    
    try:
        await monitor.start_monitoring([oracle_address], [pair])
    except KeyboardInterrupt:
        logger.info("Monitoring stopped by user")
        monitor.monitoring_active = False

async def monitor_all_oracles(oracle_addresses: List[str], pairs: List[str], config: HealthCheckConfig):
    """Monitor all specified oracles and pairs"""
    monitor = OracleHealthMonitor(config)
    
    try:
        await monitor.start_monitoring(oracle_addresses, pairs)
    except KeyboardInterrupt:
        logger.info("Monitoring stopped by user")
        monitor.monitoring_active = False

def main():
    """Main CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Oracle Health Monitor")
    parser.add_argument("--oracle", help="Oracle address to monitor")
    parser.add_argument("--pair", help="Trading pair to monitor")
    parser.add_argument("--monitor-all", action="store_true", help="Monitor all oracles")
    parser.add_argument("--oracles", help="Comma-separated oracle addresses")
    parser.add_argument("--pairs", help="Comma-separated trading pairs")
    parser.add_argument("--interval", type=int, default=120, help="Check interval (seconds)")
    parser.add_argument("--config", help="Configuration file")
    
    args = parser.parse_args()
    
    # Setup configuration
    config = HealthCheckConfig(
        check_interval=args.interval,
        alert_webhook_url=os.getenv("ALERT_WEBHOOK_URL", "")
    )
    
    if args.config and os.path.exists(args.config):
        # TODO: Load configuration from file
        pass
    
    try:
        if args.oracle and args.pair:
            # Monitor single oracle
            asyncio.run(monitor_single_oracle(args.oracle, args.pair, config))
        elif args.monitor_all or (args.oracles and args.pairs):
            # Monitor multiple oracles
            oracles = args.oracles.split(",") if args.oracles else os.getenv("ORACLE_ADDRESSES", "").split(",")
            pairs = args.pairs.split(",") if args.pairs else os.getenv("TRADING_PAIRS", "STX/USD").split(",")
            
            if not oracles or not pairs:
                logger.error("Oracle addresses and trading pairs must be specified")
                return
                
            asyncio.run(monitor_all_oracles(oracles, pairs, config))
        else:
            parser.print_help()
            
    except KeyboardInterrupt:
        logger.info("Oracle Health Monitor stopped")
    except Exception as e:
        logger.error(f"Oracle Health Monitor error: {e}")
        raise

if __name__ == "__main__":
    main()
