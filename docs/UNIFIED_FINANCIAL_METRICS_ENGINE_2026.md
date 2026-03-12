# Unified Financial Metrics Engine (2026)

## Overview
This engine implements the 2026 mandates for high-precision financial metrics, event-driven infrastructure, and regulatory compliance.

## Modules

### 1. Event-Driven Infrastructure
- **Architecture**: Event Sourcing & CQRS.
- **State**: Derived from immutable financial events via `StateReconstructor`.
- **Entities**: `Ledger` and `Account` refactored for asynchronous, append-only mutation.

### 2. SARB & ZARONIA Compliance
- **Methodology**: Backward-looking "compounding in arrears".
- **Lookback**: 5-business-day observation window.
- **Calendar**: Integrated with South African ZAJO holiday calendar.
- **Precision**: Annualized rates summed with CAS and margin, rounded to 2 decimal places.

### 3. Institutional Analytics
- **TVU (Total Value Utilized)**: Filters idle assets and double-counted wrappers.
- **Liquidity Churn**: Measures capital velocity (Fees / TVU).
- **TVPI (Total Value to Paid-In)**: Standard PE metric for fund performance.

### 4. Insurance Actuarial (IFRS 17)
- **GMM (General Measurement Model)**: Fulfillment cash flow valuation.
- **Contract Boundary**: FSI 2.2 compliant repricing logic.
- **Amortization**: Systematic CSM recognition based on coverage units.

## Implementation Details
- **Location**: `conxius-wallet/services/financial-metrics-engine/`
- **Math**: Uses `bignumber.js` for 100% precision.
- **Testing**: 100% pass rate across all engine modules.
