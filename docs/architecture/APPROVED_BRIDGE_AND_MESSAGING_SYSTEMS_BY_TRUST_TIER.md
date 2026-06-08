# Approved Bridge and Messaging Systems by Trust Tier

> Canonical policy artifact for bridge/messaging approval in Conxian architecture.
> Approved direction source: CON-791 / GitHub #737.

## Purpose

This document defines the production policy for bridge/messaging routing by trust tier.
Gateway and Nexus implementations MUST treat this file as canonical for system allow/deny behavior.

## Trust tier taxonomy (T1..T4)

| Tier | Required trust class | Production allowance | Policy intent |
| --- | --- | --- | --- |
| **T1** | `light_client` (trust-minimized verification) | **Allowed** | Settlement-critical and treasury-critical paths. |
| **T2** | `external_quorum` / `app_defined_multiverifier` / `shared_pos` with explicit controls | **Allowed (conditional)** | Standard production business flows with explicit verifier assumptions. |
| **T3** | Same verification classes as T2, but bounded-risk operational posture | **Allowed (strictly bounded)** | Pilot/bootstrapping flows with caps, explicit risk acceptance, and kill-switch controls. |
| **T4** | `unknown`, unapproved, placeholder, or policy-noncompliant trust posture | **Not allowed** | Research/sandbox only; MUST be blocked from production routing. |

## Approved systems matrix

| System | Verification class | Allowed tiers | Approval status | Required conditions |
| --- | --- | --- | --- | --- |
| **IBC** | `light_client` | **T1, T2** | **Approved** | MUST use verifiable light-client path and required freshness/finality metadata. |
| **Hyperlane** | `app_defined_multiverifier` | **T2, T3** | **Conditionally approved** | MUST use explicit hardened ISM/verifier config (no defaults/placeholder), enforce freshness windows, and persist policy+evidence binding. |
| **LayerZero v2** | `external_quorum` (DVN-based) | **T2, T3** | **Conditionally approved** | MUST use explicit non-default DVN/security config, enforce freshness windows, and persist policy+evidence binding. |
| **Wormhole NTT** | `external_quorum` (Guardian + transceiver thresholds) | **T2, T3** | **Conditionally approved** | MUST use explicit quorum/threshold config (no single-attester path), enforce freshness windows, and persist policy+evidence binding. |
| **Axelar GMP** | `shared_pos` | **T2, T3** | **Approved for managed/expedient use (conditional gates apply)** | MUST enforce validator/quorum metadata checks, freshness windows, and per-tier controls (especially T3 caps/kill-switch). |

## Mandatory constraints

1. Gateway MUST enforce **deny-by-default** routing for any unlisted system/configuration.
2. Routes MUST NOT silently downgrade trust tier (for example, `T1 -> T2/T3`) without an explicit policy decision.
3. `T1` routes MUST use **IBC only**.
4. Every route decision MUST be bound to both **policy version** and **evidence hash**.
5. Freshness windows and finality metadata MUST be validated before route execution.
6. Unknown/missing trust tier or verification metadata MUST fail closed as `blocked`.
7. `T3` routes MUST enforce bounded exposure (caps + kill-switch controls).

## Forbidden usage patterns

- Any non-IBC system in `T1`.
- Single-attester/single-verifier production configuration for `T2`.
- Placeholder/default security configuration in production.
- Treating transport/authenticity signals as settlement truth.
- Routing when required trust metadata is missing.

## Gateway enforcement implications

Gateway policy implementation MUST:

- evaluate routing policy by `(assetRiskProfile, trustTier, system)`;
- enforce fail-closed behavior on missing/stale/invalid metadata;
- enforce per-tier controls (including `T3` exposure caps and kill-switches);
- persist audit records containing policy version, evidence hash, `verificationStatus`, and `verificationReason`.

## Nexus metadata requirements

Nexus MUST emit canonical bridge/messaging metadata with at least:

- `system`, `systemVersion`
- `trustTier`, `verificationClass`
- `sourceChainId`, `destinationChainId`
- `finalityClass`, `minConfirmations`
- `observedAt`, `expiresAt`
- `proofRef`, `evidenceHash`, `evidenceUri`
- `verifierSetRef`
- `verificationStatus`, `verificationReason`

Protocol-specific `securityParams` SHOULD be included and validated per system (for example, IBC client/channel identifiers, Wormhole guardian/transceiver params, Hyperlane ISM params, LayerZero DVN params, Axelar validator/quorum epoch params).

## Source references

- Linear issue: [CON-791 — Research and approve bridge and messaging systems by trust tier](https://linear.app/conxian-labs/issue/CON-791/research-and-approve-bridge-and-messaging-systems-by-trust-tier)
- GitHub issue: [#737 — Research and approve bridge and messaging systems by trust tier](https://github.com/Conxian/conxian-business/issues/737)
- Prior architecture context: [`docs/NEXUS_GATEWAY_UNIVERSAL_CHAIN_ARCHITECTURE.md`](../NEXUS_GATEWAY_UNIVERSAL_CHAIN_ARCHITECTURE.md)
- Research tracker context: [`docs/REMAINING_UNIVERSAL_SUPPORT_RESEARCH.md`](../REMAINING_UNIVERSAL_SUPPORT_RESEARCH.md)
