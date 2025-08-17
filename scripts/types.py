"""
Type definitions for Oracle orchestration system.
"""

from typing import List, Optional, TypedDict

# Price data types
class PriceData(TypedDict):
    price: float
    confidence: float
    volume: float
    timestamp: Optional[float]
    source: Optional[str]

class PriceFeedResult(TypedDict):
    median_price: float
    mean_price: float
    confidence_score: float
    std_deviation: float
    num_sources: int
    sources: List[str]

# Oracle types
class OracleInfo(TypedDict):
    address: str
    enabled: bool
    last_update: Optional[float]
    response_time_ms: List[float]
    accuracy_score: float

class OracleMetrics(TypedDict):
    uptime_percentage: float
    average_response_time: float
    price_accuracy: float
    last_submission: Optional[float]
    error_count: int

# Configuration types
class CoordinationConfig(TypedDict):
    min_sources: int
    max_deviation_bps: int
    submission_interval: int
    retry_attempts: int
    timeout_seconds: int

class HealthConfig(TypedDict):
    check_interval: int
    alert_threshold: float
    max_response_time: float
    min_uptime_percentage: float

# Alert types
class Alert(TypedDict):
    type: str
    severity: str
    message: str
    timestamp: float
    oracle_address: Optional[str]

# Status types
class SystemStatus(TypedDict):
    active_oracles: int
    total_pairs: int
    last_update: float
    health_score: float
    alerts: List[Alert]
