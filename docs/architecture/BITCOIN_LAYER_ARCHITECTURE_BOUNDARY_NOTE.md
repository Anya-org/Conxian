# Bitcoin Layer Architecture Boundary Note

## Status

Canonical boundary note

## Purpose

This note defines the canonical capability vocabulary, phased layer support scope, and repository ownership boundaries for Bitcoin layer support across the Conxian portfolio.

## Canonical capability verbs

Canonical verb set (in order): `observe`, `derive`, `build`, `sign`, `broadcast`, `verify`, `settle`, `bridge`, `recover`, `simulate`.

| Verb | Canonical definition |
| --- | --- |
| `observe` | Read and track chain, account, transaction, invoice, and event state for a target layer. |
| `derive` | Produce addresses/accounts/keys from approved derivation policies for the target layer. |
| `build` | Construct transactions or intent payloads with policy-aware inputs, outputs, and fees. |
| `sign` | Authorize intents/transactions through approved software, hardware, or enclave signer paths. |
| `broadcast` | Submit signed payloads through the correct network/provider boundary. |
| `verify` | Validate destination, amount, fee, policy, and network assumptions before/after submission. |
| `settle` | Determine finality using layer-appropriate confirmation and settlement rules. |
| `bridge` | Move value or state across Bitcoin-connected layers with explicit trust assumptions. |
| `recover` | Restore signer/account/watch-only posture and resynchronize pending state safely. |
| `simulate` | Preview execution, fees, policies, and likely settlement outcomes before commit. |

## Layer support phases

| Phase | Support classification | Layers |
| --- | --- | --- |
| Phase 1 | First-class supported layers | Bitcoin mainnet, Lightning, Stacks |
| Phase 2 | Adapter layers | Rootstock, Liquid |

Boundary interpretation:

- Phase 1 layers are treated as first-class portfolio support targets.
- Phase 2 layers are handled via the adapter model and should reuse the same canonical verb vocabulary where applicable.

## Protocol-adapter maturity lane baseline

Protocol-adapter intake and promotion for emerging rails must follow
`docs/architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md`.

- Intake records must include lane, rail scope, target adapter interface, owner, review cadence, risk register, and promotion blockers.
- If lane is unspecified, the required default is `Research`.
- Lane decisions must preserve gateway-first adapter implementation ownership and platform-owned harness/observability evidence.

## M0 canonical Lightning boundary decision

Lightning is **gateway-first / gateway-owned adapter surface**.

Boundary implications:

- `conxian-gateway` owns Lightning adapter implementation and provider/node integration surfaces.
- `lib-conxian-core` owns shared capability interfaces and verification primitives, not Lightning provider adapters.
- `conxius-enclave-sdk` owns signer controls consumed by gateway-owned Lightning adapter paths.

Linked M0 artifacts:

- `docs/BITCOIN_LAYER_CAPABILITY_OWNERSHIP_MATRIX_M0.md`
- `docs/BITCOIN_LAYER_MAINNET_READINESS_GATE_CHECKLIST_M0.md`

## Repository ownership boundaries

| Repository | Owns | Does not own |
| --- | --- | --- |
| `lib-conxian-core` | Canonical capability interfaces, shared transaction intent models, shared verification/safety primitives | Network adapters, provider-specific integration logic, wallet UX, runtime orchestration |
| `conxian-gateway` | Bitcoin layer adapters, provider connectivity, observation/broadcast boundaries, bridge interoperability surfaces | Canonical shared-core ownership, wallet UX, portfolio taxonomy/planning ownership |
| `conxius-enclave-sdk` | Secure signer abstraction, enclave/hardware trust integration, attestation/policy-constrained signer controls | Adapter implementations, app orchestration, consumer workflow logic |
| `conxius-platform` | Composition runtime, integration harnesses, test/observability wiring across strategic repos | Canonical business logic, duplicated shared-core logic, adapter ownership that belongs in gateway |
| `conxius-wallet` | Reference client flows, signer UX validation, capability demonstrations for supported layers | Strategic portfolio center, canonical adapter ownership, hidden shared-core logic |
| `Conxian` | Protocol identity and protocol-first specs/artifacts (unless explicitly reclassified) | Overlapping gateway runtime logic, mixed adapter/product concerns that weaken protocol clarity |

## Naming and branding guardrails

- Use repository names exactly as canonical: `Conxian`, `lib-conxian-core`, `conxian-gateway`, `conxius-enclave-sdk`, `conxius-platform`, `conxius-wallet`.
- Use **Conxian** wording for protocol/platform identity context and **Conxius** wording only for repositories that are explicitly named `conxius-*`.
- Avoid deprecated or mixed naming variants in new boundary documentation.

## Source alignment

This note consolidates and operationalizes:

- `docs/research/BITCOIN_LAYER_CAPABILITY_MATRIX.md`
- `docs/research/BITCOIN_LAYER_REPO_ALIGNMENT_PLAN.md`
- `docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`
- `docs/architecture/PORTFOLIO_ALIGNMENT_BASELINE.md`
