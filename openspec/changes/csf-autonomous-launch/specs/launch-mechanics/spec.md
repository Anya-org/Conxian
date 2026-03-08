# Spec: Autonomous Launch & Revenue Mechanics

## ADDED Requirements

### Requirement: Founder's Cut Fee Logic
The protocol MUST implement a hardcoded 0.1% fee on all transactional events.
#### Scenario: Fee Redirection
- **Given** a successful swap or lending event
- **When** processing the transaction
- **Then** the protocol MUST deduct 0.1% and route it to the designated founder address.

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
