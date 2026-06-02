# BOS treasury and yield integration architecture (CON-438)

This document defines a **public-safe** target architecture for integrating legacy FP&A / treasury systems with `cxn-treasury-oracle`, while ensuring there is **no direct dashboard-to-contract coupling**.

The main design principle is: **dashboards propose and observe; BOS executes and proves**.

## 1) Goals and non-goals

Goals:

- Provide a canonical path to express treasury/yield operations as **intents** that are verifiable, reviewable, and replay-resistant.
- Ensure all value-bearing actions are executed by **BOS-controlled signers** (SAB/DAO authorities), never by dashboards.
- Treat `cxn-treasury-oracle` as a **derived read model + evidence index**, not a canonical source of truth.
- Define reconciliation rules that tie off-chain intent logs to on-chain transactions and indexed state.
- Define liquidity guardrails and safe failure behavior (fail closed).

Non-goals:

- Defining secret management, allowlists, or vendor-specific endpoints (ZSE: these live in Linear).
- Replacing on-chain policy (contracts); this doc defines an integration boundary and verification expectations.

## 2) Core invariants (must always hold)

1. **No dashboard-to-contract coupling**
   - Dashboards MUST NOT hold production signing keys.
   - Dashboards MUST NOT broadcast value-bearing transactions.
   - Broadcast endpoints (BOS or Gateway) for value-bearing transactions MUST only accept transactions that are the result of validated BOS workflows (for example: approved `treasury.intent.v1` intents) and MUST NOT be exposed as generic transaction relays to dashboard-tier clients.

2. **Canonical truth is on-chain**
   - Off-chain databases (including `cxn-treasury-oracle`) MUST be treated as derived/non-authoritative.

3. **Dynamic principals (no hardcoded production addresses)**
   - Treasury/yield contracts MUST resolve operational principals via `contracts/core/operational-treasury.clar`.

4. **Fail closed**
   - Any automation path that cannot prove validity MUST stop execution and record an explicit error state.

## 3) Components and trust boundaries

### 3.1 Components

- **Legacy FP&A / treasury systems**: SAP/Oracle or similar systems that generate budget, allocation, and settlement requests.
- **Treasury intent adapter**: converts legacy actions into canonical intents and submits them to BOS.
  - This can be an ERP MCP tool, an internal service, or a job runner.
- **BOS orchestrator**: validates intents, enforces guardrails, and prepares unsigned transactions.
- **Signing authorities**: SAB/DAO-controlled keys or multi-sigs used for value-bearing execution.
- **Gateway/Nexus**: relays and indexes on-chain state/events and provides derived query surfaces.
- **`cxn-treasury-oracle`**: derived SQL read model + audit/evidence tables for yield, runway, and treasury action logs.

### 3.2 Trust boundary diagram

```text
          (propose)                         (execute)
FP&A/ERP ----------> intent adapter -----> BOS orchestrator -----> signer(s) -----> Stacks L1
   |                     |                     |                      |               |
   |                     |                     |                      |               |
   +--> dashboards <------+---- read models <--+--- Nexus/Gateway <----+--- events ----+
           (observe)          (cxn-treasury-oracle)     (derived)
```

### 3.3 What is allowed where

- Dashboards MAY:
  - display derived state (runway, yield, principal, pending intents)
  - request new intents (via adapter)
  - attach public-safe evidence hashes/commitments
- Dashboards MUST NOT:
  - sign or broadcast value-bearing transactions
  - be treated as evidence sources (they render evidence, they do not define it)

## 4) Canonical treasury intent model

Treasury operations are expressed as signed, replay-resistant intents.

### 4.1 Intent envelope

All treasury intents MUST be wrapped in the signed envelope described in `docs/protocols/SIGNED_EVENT_ENVELOPE_V1.md`.

- `kind`: `treasury.intent.v1`
- `publisher`: the authorized operational publisher key (allowlisted by BOS)
- Freshness: `expires_at` and/or `expires_height` SHOULD be set for all value-bearing intents.

### 4.2 Intent payload fields (public-safe)

The payload must remain public-safe (ZSE). It should contain:

- `intent_id` (string): stable id for idempotency and reconciliation.
- `action` (string enum): canonical treasury action type.
- `requested_at` (number): unix seconds.
- `meta` (object): optional public-safe origin metadata (source system, pseudonymous requestor refs).
- `target_contract` (string): contract to call (by name), or a role-based identifier resolved via `operational-treasury`.
- `params` (object): action parameters (amounts, assets, recipients) expressed as atomic units.
- `policy` (object): optional public-safe policy tags (e.g., “requires-timelock”).
- `reconciliation` (object): optional identifiers used to bind to external settlement logs.
- `commitments` (object): hash commitments to any internal-only supporting documents.

Recommended `action` values:

- `treasury.withdraw`
- `treasury.rebalance`
- `yield.allocate`
- `yield.harvest`
- `policy.pause`

### 4.3 Example intent (shape only)

```json
{
  "v": 1,
  "kind": "treasury.intent.v1",
  "publisher": "<x-only-pubkey-hex>",
  "created_at": 1776297600,
  "expires_at": 1776301200,
  "payload": {
    "intent_id": "treasury-intent-00000001",
    "action": "treasury.withdraw",
    "requested_at": 1776297600,
    "meta": {
      "source_system": "sap-fpa-prod",
      "requestor_ref": "role:finance-ops"
    },
    "target_contract": "operational-treasury",
    "params": {
      "asset": "STX",
      "amount_atomic": "1000000",
      "recipient_role": "SAB_TREASURY_MS"
    },
    "policy": {
      "requires_timelock": false
    },
    "commitments": {
      "supporting_doc_sha256": "<sha256-hex>"
    }
  },
  "payload_hash": "<sha256-hex>",
  "event_id": "<sha256-hex>",
  "sigs": [
    {
      "suite": "bip340-schnorr-secp256k1-sha256",
      "pubkey": "<x-only-pubkey-hex>",
      "sig": "<sig-hex>"
    }
  ]
}
```

## 5) Approval controls and execution paths

The approval model is enforced in two places:

1. **BOS preflight** (off-chain): validate signatures, freshness, allowlists, and guardrails before preparing a transaction.
2. **Contracts** (on-chain): enforce role-based authorization and any timelock/circuit-breaker rules.

### 5.1 Authority routing (conceptual)

- Low/medium-risk actions MAY be executed by SAB-controlled authorities.
- High-risk / high-value actions SHOULD route through DAO-controlled authorities and timelock.
- Emergency pause MUST route through the guardian/emergency authority model.

This architecture assumes principals are represented as **roles** and resolved dynamically on-chain (e.g., via `operational-treasury` principal registry), rather than hardcoding addresses.

### 5.2 Execution steps (happy path)

1. Adapter submits `treasury.intent.v1`.
2. BOS orchestrator validates:
   - signature allowlist
   - freshness window (`expires_*`)
   - idempotency (`intent_id`)
   - liquidity guardrails (section 6)
   - required authority route (SAB vs DAO + timelock)
3. BOS builds an unsigned transaction calling the appropriate contract(s).
4. BOS requests signature from the required authority wallet.
5. BOS (or Gateway) broadcasts the signed transaction.
6. Nexus indexes the on-chain result; derived stores update.
7. BOS writes reconciliation updates into `cxn-treasury-oracle`.

## 6) Liquidity guardrails (minimum baseline)

Guardrails are enforced by BOS preflight and SHOULD also be reflected on-chain where possible.

Guardrail evaluation MUST use canonical on-chain state (or projections that are cryptographically checkpointed on-chain) as its correctness source.
`cxn-treasury-oracle` MAY be used as a cached, observable view, but MUST NOT be the sole input to liquidity or risk guardrails.
Any divergence between the read model and on-chain checkpoints MUST be treated as a reconciliation fault.

Minimum guardrail classes:

- **Reserve floor**: maintain a minimum liquid reserve by asset class.
- **Rate limiting**: cap outbound treasury actions per time/height window.
- **Destination allowlists**: restrict recipients to role-resolved principals.
- **Strategy allowlists**: restrict yield allocation targets.
- **Circuit breakers**: when volatility or integrity signals breach thresholds, only allow pause/isolation actions.

If any guardrail evaluation cannot be performed due to missing inputs, the system MUST fail closed and mark the intent as non-executable.

## 7) Oracle publishing (what goes into `cxn-treasury-oracle`)

`cxn-treasury-oracle` is a read model used for:

- dashboards and reporting
- audit/evidence collation
- operational reconciliation and alerting

It MUST NOT be used as a correctness dependency.

### 7.1 Publishing rules

1. Prefer writing derived state from on-chain events (via Nexus projections).
2. If publishing originates off-chain (e.g., market data), it MUST be signed and treated as an oracle feed input.
3. Derived datasets SHOULD be checkpointed on-chain at a fixed cadence (e.g., every 144 Stacks blocks), per `openspec/specs/sab-datastore-mapping/spec.md`.

### 7.2 Feed types

- **Oracle reports**: publish measurements as `oracle.report.v1` events (see `Signed Event Envelope v1`).
  - Examples: `treasury.runway.days`, `treasury.principal.btc`, `yield.apy.net`.
- **Action logs**: store `treasury_actions` as the off-chain ledger of intents + execution receipts.

## 8) Reconciliation model

Reconciliation binds together:

- the off-chain intent (`intent_id`)
- the on-chain transaction hash(es)
- the observed on-chain events/state transitions
- optional external settlement references

### 8.1 Idempotency and dedupe

- `intent_id` MUST be globally unique for the publisher domain.
- BOS MUST reject any intent that attempts to reuse an `intent_id` with different payload contents.

### 8.2 Required reconciliation fields (conceptual)

The derived action log SHOULD track:

- `intent_id`
- `intent_event_id` (from the signed envelope)
- `status`: `PENDING` | `APPROVED` | `BROADCAST` | `CONFIRMED` | `REJECTED` | `FAILED` | `EXPIRED`
- `onchain_txid`
- `confirmed_height`
- `error_code` / `error_detail` (public-safe)

## 9) Operational failure handling

Failure modes and required behavior:

1. **Oracle unavailable / stale**
   - Execution MUST NOT proceed if it relies on freshness-constrained oracle inputs.
   - Dashboards MAY continue to render the last known derived state but MUST show staleness.

2. **Signature allowlist mismatch**
   - Reject intent; do not attempt partial execution.

3. **On-chain rejection (contract error)**
   - Mark the intent failed with the on-chain error; do not retry unless a new intent is issued.

4. **Broadcast failure / mempool stuck**
   - Keep intent in `BROADCAST` with retry-safe semantics; do not generate a second spend unless the first is proven dropped/expired.

5. **Reconciliation mismatch**
   - Freeze downstream automated actions that depend on the mismatched state.
   - Require explicit review (SAB/DAO policy) before continuing.

6. **Treasury read model unavailable / write failure**
   - Do not block value-bearing on-chain execution if correctness can be proven without the read model.
   - Enqueue reconciliation records and re-materialize `treasury_actions` and related projections from on-chain events once storage recovers.
   - Emit an operator alert and flag affected intents as reconciled on-chain but pending off-chain ledger repair until the backlog is cleared.

7. **Intent expired**
   - If an intent reaches its `expires_at` / `expires_height` before BOS can safely broadcast, mark it `EXPIRED`, do not attempt execution, and require issuance of a fresh intent if the action is still desired.

---

© 2026 Conxian-Labs.
