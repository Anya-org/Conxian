# Spec: Autonomous Launch & Revenue Mechanics

## ADDED Requirements

### Requirement: Founder's Cut Fee Logic
The protocol MUST implement a hardcoded 0.1% Founder’s Cut **as a carve-out from captured protocol fees** (not an additive user fee).

For the purposes of this requirement, **captured protocol fees** MUST mean the protocol-retained portion of each transaction’s fee after applying any third-party distributions (e.g. referral splits).

All Founder’s Cut computations MUST be performed using integer math in the smallest unit of the transaction’s fee asset. For the purposes of this requirement, `/` MUST denote integer division and `%` MUST denote modulo.

The protocol MUST compute Founder’s Cut in the following order:

- `captured = captured_protocol_fees`
- `founders_cut = captured / 1000`
- `remainder = captured % 1000`
- `post_cut_captured = captured - founders_cut`

Internal protocol allocations (reserve/ops/incentives) MUST be computed from `post_cut_captured`.

The rounding remainder for the Founder’s Cut computation MUST equal `remainder` and MUST remain in the protocol treasury/vault balance of the transaction’s fee asset (as part of `post_cut_captured`) and MUST NOT be included in the transfer to the designated founder vault.
#### Scenario: Fee Redirection
- **Given** a successful swap or lending event
- **When** processing the transaction
- **Then** the protocol MUST allocate a 0.1% Founder’s Cut from the protocol’s captured fee amount and route it to the designated founder vault.

### Requirement: ALEX AMM Integration
The backend MUST utilize the ALEX Lab SDK for liquidity provisioning.
#### Scenario: Automated Liquidity
- **Given** an IDO event on ALEX
- **When** the LBP concludes
- **Then** the system MUST pair 10% of proceeds in an ALEX AMM pool for 6 months.

### Requirement: sBTC & USDCx Support
The system MUST support sBTC (uncapped) and USDCx as primary collateral.
#### Scenario: Asset Validation
- **Given** a deposit request
- **When** the asset is sBTC or USDCx
- **Then** the system MUST accept the deposit without supply cap restrictions.

### Requirement: 5-5-5 Referral Engine
The system MUST implement a tiered referral system for autonomous growth.
#### Scenario: Referral Distribution
- **Given** a transaction via a referral link
- **When** the transaction is finalized
- **Then** distribute 5% of fees to the referrer, 5% to the referee, and lock 5% for protocol health.

### Requirement: Key Relinquishment Plan
The protocol MUST have a verifiable path to "Burning the Keys."
#### Scenario: DAO Handover
- **Given** 24 months post-launch
- **When** the ExecutorDAO is stable
- **Then** the admin principal MUST be set to 0x0 (burn-address).
