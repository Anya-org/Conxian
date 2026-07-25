# Agents Module

- [Overview (Explanation)](#overview-explanation)
- [Architecture (Explanation)](#architecture-explanation)
- [Core Contracts (Reference)](#core-contracts-reference)
  - [agent-risk.clar](#agent-riskclar)
  - [agent-treasury.clar (Compatibility Layer)](#agent-treasuryclar-compatibility-layer)
  - [fiscal-orchestrator.clar](#fiscal-orchestratorclar)
  - [fiscal-intelligence.clar](#fiscal-intelligenceclar)
  - [payment-forge.clar](#payment-forgeclar)
- [Integration Examples (How-to)](#integration-examples-how-to)
- [Jargon (Accessibility)](#jargon-accessibility)
- [Testing (How-to)](#testing-how-to)
- [Status (Reference)](#status-reference)

## Overview (Explanation)
The Agents module implements autonomous "Fiscal Agents" that manage protocol risk, treasury health, and automated payments. These agents operate based on Grounded Telemetry and Unified Theory variables (C_R, V_X, A_S), ensuring the protocol remains adaptive and sovereign in volatile market conditions.

## Architecture (Explanation)
- **Risk Agent**: `agent-risk.clar` calculates compatibility-scale cybernetic scores from GCR and explicitly publishes normalized scores to the canonical `risk-unit`; it does not own liquidation or circuit-breaker administration.
- **Treasury Agent**: `agent-treasury.clar` provides a compatibility layer for executing fiscal strategies across designated pools.
- **Orchestrator**: `fiscal-orchestrator.clar` serves as the canonical implementation for fee collection and BME epoch routing.
- **Intelligence Unit**: `fiscal-intelligence.clar` (SFIU) manages Sovereign Business Cells (SBC) and yield strategies.
- **Payment Forge**: `payment-forge.clar` bridges institutional ISO 20022 messages with sovereign x402 machine-to-machine settlements.

## Core Contracts (Reference)

### `agent-risk.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `get-risk-score` | `()` | Returns the current system-wide risk score. |
| `get-protocol-status` | `()` | Returns the compliance status and version. |
| `get-contract-owner` | `()` | Returns the current administrator principal. |
| `get-gcr` | `(m <finance-metrics-trait>)` | Calculates the Global Collateral Ratio. |
| `assess-system-risk` | `(m <finance-metrics-trait>)` | Evaluates protocol health and updates score. |
| `get-cybernetic-intel` | `(m <finance-metrics-trait>)` | Aggregates fees, GCR, and risk score. |
| `set-stability-fee` | `(f uint)` | Updates the PID stability fee (Admin only). |
| `set-risk-score` | `(s uint)` | Manually overrides the compatibility score, bounded to `0..1000` (Admin only). |
| `publish-system-risk` | `(m <finance-metrics-trait>, risk-module <risk-signal-publisher-trait>)` | Publishes the normalized `0..10000` score to the configured canonical risk unit (Admin only). |
| `get-published-risk-score` | `()` | Returns the current compatibility score normalized to canonical units. |
| `set-risk-unit` | `(risk-unit principal)` | Configures the canonical publication target (Admin only). |
| `get-risk-unit` | `()` | Returns the configured publication target. |
| `initialize` | `(a principal)` | One-shot initialization; only the deployment-time admin may call it. |
| `set-mock-gcr` | `(g uint)` | Compatibility stub for GCR updates. |
| `set-tvl` | `(c uint) (p uint) (b uint)` | Compatibility stub for TVL updates. |
| `update-pid-rates` | `()` | Compatibility stub for PID rate updates. |

### `agent-treasury.clar` (Compatibility Layer)
| Function | Signature | Description |
|----------|-----------|-------------|
| `run-fiscal-strategy` | `(pool-trait <csf-trait>, pools-to-reward (list 50 principal), cxd-token-trait <sip-010-ft-trait>, metrics-ref <finance-metrics-trait>)` | Executes the compatibility fiscal strategy. |
| `calculate-performance-adjustment` | `(metrics-ref <finance-metrics-trait>)` | Computes yield adjustments based on risk signals. |
| `calculate-cybernetic-policy` | `(metrics-ref <finance-metrics-trait>)` | Calculates the current fiscal allocation policy. |
| `get-protocol-status` | `()` | Returns the compliance status and version. |
| `initialize` | `(new-admin principal)` | Sets the initial administrator. |
| `set-admin` | `(new-admin principal)` | Updates the administrator principal. |

### `fiscal-orchestrator.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `run-fiscal-strategy` | `(pools-to-reward (list 50 principal), cxd-token-trait <sip-010-ft-trait>, metrics-ref <finance-metrics-trait>)` | Orchestrates fee collection and BME routing. |
| `calculate-performance-adjustment` | `(metrics-ref <finance-metrics-trait>)` | Computes yield adjustments based on risk signals. |
| `calculate-cybernetic-policy` | `(metrics-ref <finance-metrics-trait>)` | Calculates the dynamic allocation policy. |
| `get-protocol-status` | `()` | Returns the compliance status and version. |
| `is-authorized-admin` | `()` | Returns whether the sender is the current administrator. |
| `initialize` | `(new-admin principal)` | Sets the initial administrator. |
| `set-admin` | `(new-admin principal)` | Updates the administrator principal. |

### `fiscal-intelligence.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `codify-sbc` | `(name (string-ascii 32))` | Codifies a new Sovereign Business Cell (Admin only). |
| `infuse-sbc` | `(name (string-ascii 32), amount uint)` | Infuses a Business Cell with liquid reserves. |
| `deploy-symmetry` | `(sbc-name (string-ascii 32), strategy principal, amount uint)` | Deploys symmetry to a yield strategy. |
| `harvest-sovereign-yield` | `(sbc-name (string-ascii 32), strategy principal, yield-amount uint)` | Harvests yield from strategies (Admin only). |
| `autonomous-yield-sweep` | `(sbc-name (string-ascii 32), strategy principal)` | Executes autonomous 20% yield sweep. |
| `set-admin` | `(new-admin principal)` | Updates the administrator principal (Admin only). |
| `get-sbc-status` | `(name (string-ascii 32))` | Returns the status of a specific SBC. |
| `calculate-syi` | `(name (string-ascii 32))` | Calculates the Sovereign Yield Index (SYI). |
| `get-protocol-status` | `()` | Returns the compliance status and version. |

### `payment-forge.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-x402-settlement` | `(amount uint, token <sip-010-trait>, signature (buff 65))` | Triggers x402 M2M Settlement. |
| `authorize-iso-20022-egress` | `(tx-id (buff 32), iso-xml-hash (buff 32))` | Authorizes ISO 20022 Egress (Admin only). |
| `settle-sbc-obligation` | `(sbc (string-ascii 32), amount uint, token <sip-010-trait>)` | Settles SBC obligations via the Fiscal-Vault. |
| `set-settlement-authority` | `(new-authority principal)` | Rotates the primary settlement authority (Admin only). |
| `set-settlement-operator` | `(operator principal, active bool)` | Adds or removes an EOA or contract settlement operator (Admin only). |
| `set-admin` | `(new-admin principal)` | Updates the administrator principal (Admin only). |
| `get-iso-hash` | `(tx-id (buff 32))` | Returns the ISO hash for a transaction. |
| `get-settlement-authority` | `()` | Returns the configured settlement authority. |
| `is-settlement-operator` | `(operator principal)` | Reports whether a principal is an active settlement operator. |
| `get-protocol-status` | `()` | Returns the compliance status and version. |

### Payment Forge settlement authority and operators
`settle-sbc-obligation` is fail-closed unless the immediate `contract-caller`
is either the configured settlement authority or an active settlement
operator. A fresh deployment initializes both `admin` and
`settlement-authority` from the deploying `tx-sender`; this is only an initial
configuration, not a substitute for deployment-specific access control.

The admin configures the authority and operators with
`set-settlement-authority` and `set-settlement-operator`. Both EOAs and
contract principals are supported, but a contract integration must invoke
`settle-sbc-obligation` itself because an originating transaction sender cannot
impersonate its nested `contract-caller`. The configured payment-forge caller
must also be authorized by `fiscal-vault-oracle` for the downstream release.

## Integration Examples (How-to)

### Assessing System Risk
To assess system risk from an external contract or service:
```clarity
(contract-call? .agent-risk assess-system-risk .finance-metrics)
```

`assess-system-risk` and `get-cybernetic-intel` update only the agent's
compatibility score. Canonical system-risk state is changed only through the
explicit, admin-gated publication path after `set-risk-unit` wiring:

```clarity
(contract-call? .agent-risk publish-system-risk
  .finance-metrics
  .risk-unit)
```

The configured target must be the canonical `risk-unit`; the agent does not
grant itself circuit-breaker or liquidation authority.

### Running Fiscal Strategy
The orchestrator can be triggered periodically to process protocol rewards:
```clarity
(contract-call? .fiscal-orchestrator run-fiscal-strategy reward-pools cxd-token .finance-metrics)
```

### Codifying a Sovereign Business Cell
Creating a new fiscal unit for specialized operations:
```clarity
(contract-call? .fiscal-intelligence codify-sbc "DEFI-ARBITRAGE-CELL-01")
```

## Jargon (Accessibility)
- **Fiscal Agent**: An autonomous smart contract program designed to execute financial policies without human intervention.
- **Grounded Telemetry**: The practice of using live, on-chain protocol metrics (like TVL or GCR) to drive agentic decisions.
- **Cybernetic Risk Score**: A dynamic value representing the safety of a protocol state, calculated using feedback loops from market data.
- **Sovereign Business Cell (SBC)**: A logical fiscal unit within the protocol used to isolate liquidity and yield strategies.
- **Strategic Symmetry**: The balanced allocation of protocol reserves across various yield-generating strategies.
- **x402 Machine-to-Machine Settlement**: A machine-to-machine settlement protocol inspired by "402 Payment Required", used for autonomous agentic commerce.
- **Global Collateral Ratio (GCR)**: A measure of the protocol's total collateralization across all assets and liabilities.

## Testing (How-to)
Run the agent module test suite using Vitest:
```bash
npx vitest run tests/agents
```

## Status (Reference)
- Implementation: Audit-remediated settlement control path (v1.2.0)
- Production readiness: Not claimed; x402 signature verification remains a
  placeholder and deployment-specific authority/operator configuration is
  required before production use.
- Nakamoto Standards: Compliant (Epoch 3.0)
- Audit: Session 33 Remediation Complete
- Bitcoin Compliance: BIP-341/342/174 verification procedures integrated into the global deployment runbook.
