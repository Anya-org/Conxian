# Conxian PRD: System Security Layer

| | |
|---|---|
| **Status** | 🟢 Living |
| **Version** | 1.3 |
| **Owner** | Security WG |
| **Last Updated** | 2025-08-26 |
| **References** | [AIP-1](...), [AIP-2](...), [AIP-3](...), [AIP-4](...), [AIP-5](...) |

---

## 1. Summary & Vision

The System Security Layer is not a single contract but a holistic set of controls, best practices, and monitoring systems that work in concert to protect the Conxian ecosystem from internal and external threats. It consolidates the implementations of AIPs 1 through 5 and defines the roadmap for future security enhancements. The vision is to create a defense-in-depth security posture that minimizes the attack surface, provides rapid response capabilities, and ensures the safety of user funds through multiple, overlapping safeguards.

## 2. Goals / Non-Goals

### Goals
- **Layered Defense**: Implement multiple, independent layers of security (e.g., operational, governance, market, accounting) so that the failure of one control does not compromise the entire system.
- **Rapid Response**: Provide mechanisms for the rapid detection and mitigation of exploits, such as the emergency pause and circuit breakers.
- **Proactive Hardening**: Continuously identify and address potential vulnerabilities before they can be exploited.
- **Transparent Security**: Make the security posture of the system clear and auditable for all users and stakeholders.

### Non-Goals
- **Eliminate All Risk**: It is impossible to eliminate all risks in a decentralized system. The goal is to mitigate risks to an acceptable level.
- **Centralized Control**: Security measures should not come at the cost of decentralization. Controls are designed to be governed by the community or distributed committees (multi-sigs).

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| SEC-US-01 | User | To know that my funds are protected by multiple safeguards | I can confidently deposit assets into the protocol. | P0 |
| SEC-US-02 | Guardian | To be able to pause the system in an emergency | I can act quickly to prevent losses during an active exploit. | P0 |
| SEC-US-03 | DAO Voter | To know that governance is resistant to manipulation | I can trust the outcomes of on-chain votes. | P0 |
| SEC-US-04 | Security Researcher | To have a clear understanding of the security model | I can effectively audit the system and report vulnerabilities. | P0 |

## 4. Functional Requirements

| ID | Control | Domain | AIP | Description |
|---|---|---|---|---|
| SEC-FR-01 | **Emergency Pause** | Operational | 1 | A guardian multi-sig must be able to halt all critical, state-mutating functions across the protocol. |
| SEC-FR-02 | **Time-Weighted Voting**| Governance | 2 | The DAO's voting power calculation must incorporate a time-weighting factor to resist flash loan attacks. |
| SEC-FR-03 | **Multi-Sig Treasury** | Treasury | 3 | All treasury disbursements must be approved by an `m-of-n` multi-signature committee. |
| SEC-FR-04 | **Bounty Hardening** | Incentives | 4 | The bounty system must have mechanisms to prevent Sybil attacks and reward abuse. |
| SEC-FR-05 | **Precision Math** | Accounting | 5 | All contracts must use a standardized, high-precision math library to prevent rounding and overflow exploits. |
| SEC-FR-06 | **Circuit Breaker** | Markets | TBD | Trading must be automatically halted in DEX pools if price volatility exceeds a predefined threshold. |
| SEC-FR-07 | **Oracle Aggregation** | Pricing | TBD | Prices must be aggregated from multiple sources to prevent dependency on a single, manipulable oracle. |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| SEC-NFR-01 | **Auditability** | All security-related actions (e.g., pausing, unpausing, multi-sig signing) must emit clear, on-chain events. |
| SEC-NFR-02 | **Gas Overhead** | Security mechanisms should not add prohibitive gas costs to common user transactions. |
| SEC-NFR-03 | **Formal Verification** | Critical security invariants should be formally specified and tested where possible. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| SEC-INV-01 | **Pause Halts Action** | When the system is paused, no protected function can be successfully executed. |
| SEC-INV-02 | **Timelock is Unbreakable**| A DAO proposal cannot be executed before its timelock delay has fully passed. |
| SEC-INV-03 | **Multi-sig is Enforced**| A treasury transaction cannot proceed without the required number of signatures. |

## 7. Data Model / State & Maps

The security layer is a cross-contract concern. The state is distributed across multiple contracts (e.g., `paused` vars, `timelock` schedules, `multisig` member lists).

## 8. Public Interface (Contract Functions / Events)

The interface consists of the various security functions within each contract, for example:
- `set-paused(bool)` in multiple contracts.
- `execute(...)` in the `timelock` contract.
- `approve-disbursement(...)` in the `treasury` contract.

## 9. Core Flows (Sequence Narratives)

### Emergency Pause Flow
1. **Detection**: An off-chain monitor or a community member detects a critical exploit.
2. **Alert**: The guardian multi-sig committee is alerted.
3. **Execution**: The required number of guardians sign and execute a `set-paused(true)` transaction on the relevant contract(s).
4. **Mitigation**: The system is halted, preventing further damage while a fix is developed and deployed via governance.

## 10. Edge Cases & Failure Modes

- **Guardian Collusion/Key Loss**: If the guardian multi-sig members collude or lose their keys, the emergency pause function could be abused or become unusable.
- **Slow Response**: A slow response to an incident could still result in significant losses, even if the system can eventually be paused.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Smart Contract Bug** | Defense-in-depth; multiple independent audits; comprehensive test suite; bug bounty program. |
| **Economic Exploit** | Circuit breakers, oracle aggregation, and precision math provide specific defenses against common economic attacks. |
| **Centralization Risk** | Security controls like multi-sigs and timelocks are designed to be administered by the DAO, ensuring community oversight. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| SEC-M-01 | **Mean Time to Respond (MTTR)** | The time from the first detection of a critical incident to the successful execution of a mitigating action (e.g., pausing the system). |
| SEC-M-02 | **Invariant Breach Count** | The number of times a critical system invariant is found to be violated (should always be zero). |
| SEC-M-03 | **Governance Participation %** | A measure of the decentralization and health of the governance process, a key component of security. |
| SEC-M-04 | **Treasury Anomaly Alerts** | The number of alerts triggered by unexpected treasury movements. |

## 13. Rollout / Migration Plan

- **Phase 1 (Completed)**: AIPs 1-5 have been implemented and are active in the production system.
- **Phase 2 (Q3 2025)**: Integrate the circuit breaker mechanism with the core DEX pools.
- **Phase 3 (Q4 2025)**: Develop a formal specification of security invariants and begin using symbolic checking tools.
- **Phase 4 (Q1 2026)**: Deploy the full oracle aggregator system and integrate its price data throughout the protocol.

## 14. Monitoring & Observability

- A dedicated, 24/7 monitoring system must be in place to track key security metrics and provide real-time alerts to the guardian committee and the public.
- Dashboards will provide transparency into all security-related actions and states.

## 15. Open Questions

- What is the optimal methodology for tuning circuit breaker thresholds (e.g., based on historical volatility vs. a static percentage)?
- How can we best incentivize rapid and responsible disclosure from whitehat security researchers?

## 16. Changelog & Version Sign-off

- **v1.3 (2025-08-26)**:
    - Refactored PRD into the 16-point standard format.
    - Changed status to "Living" to reflect its continuous nature.
    - Expanded on the control matrix and roadmap to provide a more narrative structure.
- **v1.2 (2025-08-18)**:
    - Validated SDK 3.5.0 testing compliance and confirmed production security posture.
- **v1.1 (2025-08-17)**:
    - Initial consolidation of security-related AIPs and documentation.

**Approved By**: Security WG, Protocol Team
**Mainnet Status**: **APPROVED - All AIP-1..5 implementations are operational.**
