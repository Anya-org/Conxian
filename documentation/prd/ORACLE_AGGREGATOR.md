# Conxian PRD: Oracle Aggregator

| | |
|---|---|
| **Status** | 🔶 Draft |
| **Version** | 0.4 |
| **Owner** | R&D WG |
| **Last Updated** | 2025-08-28 |
| **References** | `oracle-aggregator.clar` |
| **Compatibility** | SDK 3.5.0, Nakamoto |

---

## 1. Summary & Vision

The Oracle Aggregator is a critical security component of the Conxian ecosystem. It is designed to provide reliable, manipulation-resistant price data by aggregating feeds from multiple independent sources, such as internal DEX TWAPs and external, signed price feeds. The vision is to create a robust and configurable oracle system that can safely power the protocol's most sensitive operations, from vault liquidations to strategy rebalancing, by ensuring data freshness, accuracy, and integrity.

## 2. Goals / Non-Goals

### Goals
- **Aggregation**: Combine prices from multiple whitelisted sources to produce a single, trusted price point.
- **Manipulation Resistance**: Use techniques like medianization, source diversification, and staleness checks to resist price manipulation from a single compromised source.
- **Configurability**: Allow governance to register new oracle sources, set weights, and define security parameters like maximum data age.
- **Reliability**: Provide a highly available and dependable price feed for all on-chain consumers.

### Non-Goals
- **Primary Oracle Source**: The aggregator is not an oracle itself; it is a consumer and processor of data from other oracles.
- **Complex Arbitrage**: The system is not designed to perform complex arbitrage between sources, only to find a reliable median price.

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| ORA-US-01 | Vault Contract | To request a reliable price for an asset | I can accurately value collateral and calculate share prices. | P0 |
| ORA-US-02 | Oracle Provider | To submit my signed price data on-chain | I can contribute to the security and accuracy of the protocol's price feeds. | P0 |
| ORA-US-03 | Governance | To add a new, trusted oracle source | I can increase the decentralization and resilience of the price feed. | P0 |
| ORA-US-04 | Security Auditor | To review the list of sources and their parameters | I can assess the risk profile of the oracle system. | P0 |

## 4. Functional Requirements

| ID | Requirement | Status |
|---|---|---|
| ORA-FR-01 | Allow an admin to register new oracle sources and define their type (e.g., internal, external). | ✅ Implemented |
| ORA-FR-02 | For each submitted price, validate that the source is on the whitelist. | ✅ Implemented |
| ORA-FR-03 | For each submitted price, validate its freshness against a configurable maximum age (`max-age`). | 🔄 Planned (v1.1) |
| ORA-FR-04 | Compute a median price from the set of valid, recent prices. | ✅ Implemented (Simple Median) |
| ORA-FR-05 | Expose a public, read-only `get-price(asset)` function that returns the latest aggregated price and its update timestamp. | ✅ Implemented |
| ORA-FR-06 | Emit events for `SourceAdded`, `SourceRemoved`, and `PriceUpdated`. | ✅ Implemented |
| ORA-FR-07 | Integrate with the circuit breaker to halt consumers if price deviation between sources exceeds a critical threshold. | 🔄 Planned (v1.1) |
| ORA-FR-08 | Support weighted medians to give more trusted oracles greater influence. | 🔄 Planned (v1.1) |
| ORA-FR-09 | Accept signed price submissions and validate signatures using SDK 3.5.0 cryptographic primitives (e.g., Schnorr), including timestamp and domain separation. | 🔄 Planned (v1.1) |
| ORA-FR-10 | Enforce replay protection (per-source nonce or monotonic timestamp) and reject out-of-order or duplicate submissions. | 🔄 Planned (v1.1) |
| ORA-FR-11 | Gate strict verification (signatures, nonces, freshness) behind a feature flag to enable safe, backward-compatible rollout. | 🔄 Planned (v1.1) |
| ORA-FR-12 | Place oracle admin functions behind governance timelock controls. | 🔄 Planned (v1.1) |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| ORA-NFR-01 | **Gas Efficiency** | A `get-price` call should be highly efficient. `submit-price` should have a predictable gas cost. |
| ORA-NFR-02 | **Security** | Unauthorized submissions must be rejected. Stale data must be ignored. |
| ORA-NFR-03 | **Precision** | All internal calculations must handle 18-decimal precision consistently. Normalization for sources with different decimals is a future requirement. |
| ORA-NFR-04 | **Signature Verification Budget** | Signature checks must stay within block gas constraints for expected submission frequency. |
| ORA-NFR-05 | **Backward Compatibility** | When the feature flag is off, legacy whitelist-only submissions continue to work. |
| ORA-NFR-06 | **Deterministic Time Window** | A clearly defined max clock skew and freshness window is enforced on-chain. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| ORA-INV-01 | **Whitelist Enforcement** | Only prices from whitelisted oracles can be included in the median calculation. |
| ORA-INV-02 | **Staleness Rejection** | A price older than `max-age` must never be included in the aggregated price. |
| ORA-INV-03 | **Minimum Sources** | An aggregated price should only be considered valid if it is derived from a minimum number of independent sources (e.g., >= 2). |
| ORA-INV-04 | **Replay Protection** | Each source must not be able to reuse the same nonce/timestamp; out-of-order updates are rejected. |
| ORA-INV-05 | **Authenticated Submissions** | If strict mode is enabled, only correctly signed payloads are accepted. |

## 7. Data Model / State & Maps

```clarity
;; Conceptual State
(define-map oracle-sources principal (tuple (type symbol) (decimals uint)))
(define-map last-prices (tuple (source principal) (asset principal)) (tuple (price uint) (timestamp uint)))
(define-data-var admin principal)
;; v1.1 additions for SDK 3.5.0 / Nakamoto compatibility
(define-map source-nonces principal uint)              ;; per-source nonce/sequence
(define-data-var strict-mode bool)                     ;; feature flag gating strict verification
```

## 8. Public Interface (Contract Functions / Events)

### Functions
- `get-price(asset: principal)`: Returns the latest aggregated price for an asset.
- `submit-price(asset: principal, price: uint)`: (Whitelisted Oracles) Submits a price from a source.
- `submit-price-signed(asset: principal, price: uint, timestamp: uint, nonce: uint, signature: (buff ...))`: (Whitelisted Oracles) Submits a signed payload validated using SDK 3.5.0 crypto primitives when `strict-mode` is on.
- `add-oracle(source: principal, metadata: tuple)`: (Admin) Adds a new oracle source to the whitelist.
- `remove-oracle(source: principal)`: (Admin) Removes an oracle source from the whitelist.

### Events
- `(print (tuple 'event "price-updated" ...))`
- `(print (tuple 'event "source-added" ...))`

## 9. Core Flows (Sequence Narratives)

### Price Update Flow
1. **Submission**: An external, whitelisted oracle (e.g., a keeper bot) calls `submit-price` with a new price for an asset.
2. **Validation**: The contract checks that the caller (`tx-sender`) is in the `oracle-sources` whitelist. If `strict-mode` is enabled, it verifies the signed payload (asset, price, timestamp, nonce, domain) using SDK 3.5.0 cryptographic primitives and enforces replay protection (monotonic nonce/timestamp). It also checks the timestamp freshness (v1.1).
3. **Storage**: The submitted price is stored in the `last-prices` map.
4. **Aggregation**: The contract re-calculates the median price for the asset using all fresh prices available.
5. **Event**: A `PriceUpdated` event is emitted.

## 10. Edge Cases & Failure Modes

- **Stale Data**: If oracles stop submitting prices, the data could become stale, posing a risk to consumers.
- **Correlated Failures**: If multiple oracle sources get their data from the same upstream provider (e.g., the same centralized exchange), they may all fail or report bad data simultaneously.
- **Governance Capture**: A malicious actor controlling governance could whitelist a compromised oracle.
- **Replay Attacks**: An attacker attempts to resubmit an old signed payload; prevented by per-source nonces/monotonic timestamps.
- **Clock Skew**: Large clock drift causes valid signatures to fail freshness checks; mitigated by explicit max skew and observability alerts.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Stale Data** | A strict, on-chain `max-age` check for all prices is the primary mitigation. Off-chain monitoring should provide a secondary alert. |
| **Single Source Manipulation** | Requiring a minimum number of sources (e.g., >= 2) for a price to be considered valid. The median calculation further blunts the impact of a single outlier. |
| **Precision Mismatch** | For v1.0, all sources are assumed to use the same precision. For v1.1, a normalization mechanism will be introduced to handle sources with different decimal counts. |
| **Governance Attack** | Oracle administration functions should be placed behind a timelock, giving the community time to react to a malicious change in the oracle configuration. |
| **Replay/Forged Signature** | Signed payloads with domain separation plus per-source nonces/monotonic timestamps; strict-mode gating; governance timelock for changing sources/keys. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| ORA-M-01 | **Price Staleness** | The time elapsed since the last successful price update for each asset. |
| ORA-M-02 | **Inter-source Deviation** | The percentage difference between the prices reported by different oracles for the same asset. |
| ORA-M-03 | **Update Frequency** | The number of price updates per hour for each asset. |
| ORA-M-04 | **Rejected Submissions** | Count of rejected updates due to signature invalidity, replay, or staleness. |

## 13. Rollout / Migration Plan

- **v1.0 (Production Ready Core)**: The core aggregation logic, whitelist, and simple median calculation are ready for deployment.
- **v1.1 (Planned Enhancements)**: Enable strict-mode feature flag to enforce signed submissions (SDK 3.5.0 crypto), replay protection (nonces/monotonic timestamps), on-chain staleness detection, advanced manipulation detection, and full governance timelock integration.

## 14. Monitoring & Observability

- Off-chain agents must monitor the `Price Staleness` metric and alert if any feed has not been updated within its expected frequency.
- Dashboards will track the `Inter-source Deviation` to identify oracles that are consistently out of line with their peers.
- Alert on spikes in `Rejected Submissions` to detect key drift, clock issues, or attack attempts.

## 15. Open Questions

- What is the optimal set of initial oracle sources to ensure decentralization?
- How should the weights be determined for the weighted median calculation in v1.1?
- What domain separation scheme and max clock skew should be standardized for signed payloads?

## 16. Changelog & Version Sign-off

- **v0.4 (2025-08-28)**:
    - Aligned with SDK 3.5.0 and Nakamoto compatibility.
    - Added requirements for signed submissions, replay protection, and feature-flagged strict mode.
    - Extended data model, interface, flows, risks, metrics, and rollout plan accordingly.
- **v0.3 (2025-08-26)**:
    - Refactored PRD into the 16-point standard format.
    - Corrected status to "Draft" and clarified the phased rollout plan.
    - Reorganized status tables and security notes into the new structure.
- **v1.0 (2025-08-18)**:
    - *Note: This version was incorrectly marked as stable.* Assessed production readiness of the v1.0 feature set.
- **v0.2 (2025-08-17)**:
    - Initial draft skeleton implementation.

**Approved By**: R&D WG, Security WG
**Mainnet Status**: **Core Features (v1.0) APPROVED FOR DEPLOYMENT**, pending v1.1 enhancements for full functionality.
