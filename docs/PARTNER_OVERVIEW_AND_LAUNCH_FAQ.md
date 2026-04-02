# Partner Overview and Launch FAQ

This page is a concise, external-facing overview of Conxian for partners, evaluators, and early inbound interest.

## Overview (one page)

**What Conxian is:** Conxian is a Bitcoin-native operating stack that combines:

- **Non-custodial end-user interfaces** (e.g., Conxian’s Conxius Wallet)
- **Institutional / B2B middleware** (Conxian Gateway)
- **Open specifications** ([OpenSpec](../openspec/README.md)) and auditable system components

**What Conxian is not:** Conxian is not a custodian, bank, exchange, or a KYC provider. Any regulated flows (fiat on-ramps, KYC/AML, chargebacks, etc.) are intentionally delegated to regulated partners.

### Why partners care

Conxian is built to make partner integrations easier to evaluate, safer to operate, and easier to explain:

- **Non-custodial by design**: user keys stay under user control; Conxian does not take custody of customer funds.
- **Hardware-backed signing**: security-critical signing is intended to be anchored to device secure hardware (e.g., Android StrongBox / Secure Enclave-style patterns).
- **Explicit integration boundaries**: partner flows are treated as first-class “handoffs” with clear UI labeling and clear responsibility split.
- **Spec-first architecture**: OpenSpec documents the “what” and “why” so partners can review assumptions before touching code.

### Partner integration surfaces

Typical partner integration paths include:

1. **On-ramps / off-ramps**
   - Partner provides the regulated flow (KYC/AML, payment rails, chargebacks).
   - Conxian provides the non-custodial wallet UX and the handoff boundary.

2. **Swaps / bridges / liquidity routing**
   - Partner provides quotes, routing, and execution primitives.
   - Conxian constructs unsigned payloads and executes user-signed transactions.

3. **Institutional / treasury interfaces (B2B)**
   - Partner provides enterprise APIs, custody, compliance tooling, or reporting.
   - Conxian Gateway can act as the middleware layer for integrations and state monitoring.

### What we typically need from partners (for evaluation)

- A short description of the product and where it fits (on-/off-ramp, swap, bridge, L2, infra, compliance).
- API docs (or SDK docs) plus sandbox / test keys.
- Supported geos and an explicit statement of who performs KYC/AML (if applicable).
- Operational expectations (SLA targets, incident contacts, rate limits).
- Security posture (SOC2/ISO posture if applicable, key management model, threat model summary).

## Launch FAQ

> Nothing in this document constitutes legal, regulatory, tax, or investment advice. Partners remain responsible for obtaining their own professional advice and ensuring compliance with all applicable laws and regulations.

### What is launching?

We’re packaging the Conxian stack so partners and evaluators can:

- Review the architecture and OpenSpec documents.
- Run core components locally and validate integration boundaries.
- Engage in early partner pilots with clearly scoped integration work.

### What is the quickest way to evaluate Conxian?

Start with:

1. [README.md](../README.md) (high-level repo overview)
2. [OpenSpec](../openspec/README.md) (ground-truth specs)
3. [docs/](./README.md) (security, architecture, and system documentation)

### Is Conxian open source?

This repository is public; see [LICENSE](../LICENSE) for current licensing terms. If you need a different licensing structure for a commercial integration, raise it early in the conversation so we can confirm constraints.

### Does Conxian custody user funds or keys?

No. Conxian is designed to keep keys under the user’s control and avoid custodial flows.

### Who handles KYC/AML and other regulated steps?

Regulated flows are handled by regulated partners (where required). Partners remain responsible for their own regulatory compliance and licensing obligations in the jurisdictions where they operate. Conxian focuses on the non-custodial user experience and cryptographic execution.

### How do you label partner flows in the UI?

Partner flows are expected to be clearly labeled as partner-provided experiences (for example: “Powered by {Partner}” when a user transitions to a partner on-ramp flow).

### What data does Conxian share with partners?

Conxian aims to minimize partner data sharing and only transmit what is required for a given integration. Privacy and data minimization are treated as first-order design constraints.

### How should security issues be reported?

Report security vulnerabilities privately to `security@conxian-labs.com`.

### Where do partnership conversations start?

For partnership inquiries, email `admin@conxian-labs.com` with:

- the integration category,
- target geography,
- links to API/SDK docs,
- and a short threat-model / custody model summary.
