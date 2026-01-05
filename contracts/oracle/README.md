# Oracle Module

Decentralized price feed and data oracle system for the Conxian Protocol providing reliable price data for DeFi operations,
lending protocols, and liquidation management.

## Overview

The oracle module delivers comprehensive price feed infrastructure supporting:

- **Multi-Source Aggregation**: Multiple price feed sources for reliability
- **Time-Weighted Averages**: TWAP for price stability and manipulation resistance
- **Circuit Breakers**: Emergency protection against extreme market conditions
- **Real-Time Updates**: Live price feeds with freshness guarantees

## Key Contracts

### Core Oracle Infrastructure

#### Oracle Aggregator V2 (`oracle-aggregator-v2.clar`)

- **Primary aggregation engine** combining multiple price sources
- **Time-weighted average prices** (TWAP) for stability
- **Manipulation detection** and outlier resistance
- **Circuit breaker functionality** for emergency protection
- **Configurable parameters** for thresholds and weights

#### Base Oracle (`oracle.clar`)

- **Fundamental oracle interface** and delegation layer
- **Administrative functions** for oracle management
- **Integration point** for protocol contracts
- **Security controls** and access management

## Oracle Architecture

### Price Feed Sources

```
┌─────────────────┐    ┌─────────────────┐
│   External      │    │   Protocol      │
│   Price Sources │    │   Reporters     │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
          ┌─────────────────────┐
          │  Oracle Aggregator    │
          │   V2 (Primary)       │
          └─────────┬───────────┘
                    │
          ┌─────────────────────┐
          │  Base Oracle        │
          │  (Interface)        │
          └─────────┬───────────┘
                    │
          ┌─────────────────────┐
          │  Protocol Contracts │
          │  (DEX, Lending, etc)│
          └─────────────────────┘
```

### Data Flow

1. **Source Updates**: External sources push price updates to aggregator
2. **Validation**: Freshness, deviation, and statistical checks
3. **Aggregation**: Multiple sources combined with TWAP algorithms
4. **Distribution**: Clean price feeds through base oracle interface
5. **Fallback**: Circuit breakers and emergency protections

## Usage Examples

### Querying Prices

```clarity
;; Get aggregated price for an asset
(contract-call? .oracle-aggregator-v2 get-price asset-principal)

;; Get price through base oracle interface
(contract-call? .oracle get-price asset-principal)

;; Get time-weighted average price
(contract-call? .oracle-aggregator-v2 get-twap asset-principal)
```

### Oracle Management

```clarity
;; Update price feeds (authorized sources only)
(contract-call? .oracle-aggregator-v2 set-source asset price weight)

;; Configure circuit breaker
(contract-call? .oracle-aggregator-v2 set-circuit-breaker circuit-contract)

;; Set manipulation detection parameters
(contract-call? .oracle-aggregator-v2 set-params threshold-bps alpha-bps)
```

### Advanced Features

```clarity
;; Check for price manipulation
(contract-call? .oracle-aggregator-v2 is-manipulated asset-principal)

;; Get volatility data
(contract-call? .oracle-aggregator-v2 get-volatility-data asset-principal)

;; Check circuit breaker status
(contract-call? .oracle-aggregator-v2 check-circuit-breaker)
```

## Security Features

### Manipulation Resistance

- **Multi-source validation** prevents single-point failures
- **Time-weighted averaging** smooths price manipulation attempts
- **Statistical detection** using deviation thresholds
- **Volatility tracking** for anomaly detection

### Reliability Guarantees

- **Freshness checks** ensure recent price updates
- **Circuit breakers** for extreme market conditions
- **Fallback mechanisms** for source failures
- **Emergency controls** for protocol protection

### Access Control

- **Role-based permissions** for administrative functions
- **Authorized sources** for price updates
- **Configurable thresholds** and parameters
- **Audit trails** for all operations

## Integration Points

### DEX Integration

- **Price feeds** for swap calculations and slippage protection
- **Liquidation prices** for concentrated liquidity positions
- **MEV protection** through accurate price discovery

### Lending Protocols

- **Collateral valuation** for loan-to-value calculations
- **Liquidation triggers** based on accurate price feeds
- **Risk assessment** using volatility and manipulation detection

### Risk Management

- **Portfolio valuation** with reliable price data
- **Stress testing** using historical volatility
- **Circuit breaker integration** for emergency responses

## Performance Optimizations

### Gas Efficiency

- **Optimized storage** patterns for frequent access
- **Batch operations** for multiple price updates
- **Efficient algorithms** for TWAP calculations
- **Minimal state changes** for price queries

### Scalability

- **Multi-asset support** for diverse token pairs
- **Parallel processing** of price feed updates
- **Configurable update intervals** for different use cases
- **Layered validation** for different risk levels

## Oracle Economics

### Incentive Structure

- **Reporter rewards** for timely price updates
- **Stake requirements** for oracle participation
- **Quality scoring** for source reliability
- **Penalty mechanisms** for malicious behavior

### Fee Model

- **Protocol usage fees** for oracle access
- **Premium features** for advanced analytics
- **Volume discounts** for heavy users
- **Cross-subsidization** between different use cases

## Monitoring & Analytics

### Real-Time Monitoring

- **Price deviation alerts** for market anomalies
- **Source health checks** for oracle reliability
- **Manipulation detection alerts** for security
- **Circuit breaker notifications** for emergency events

### Historical Data

- **Price history** for TWAP calculations
- **Volatility tracking** for risk assessment
- **Source performance** metrics
- **Manipulation attempts** logging
