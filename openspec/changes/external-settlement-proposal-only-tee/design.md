# Design: Proposal-only external settlement triggers (TEE enforced)

## 0. Problem statement

We need to ingest external settlement signals (ISO 20022, PAPSS, BRICS) and wire them into the sovereign execution flow **strictly as proposal-only triggers**.

The system must preserve:

- the existing multi-sig approval gate,
- the existing **144-block** time-lock for the mapped digital asset path,
- the existing TEE / StrongBox security floor,
- and the existing “5/5/90 productive streaming” behavior for capital locked as transit bond or escrow.

At no point should a TradFi payload become direct execution authority.

## 1. Core principle

External settlement inputs are treated as **trigger material** only:

- They may cause a proposal to be created.
- They may cause a time-lock to be scheduled.
- They must **not** cause a contract call / funds movement / lock to be executed.

## 2. Canonical pipeline (explicit boundaries)

This design makes the boundaries between parsing, attestation, and execution explicit so they can be tested.

### Boundary A — Parsing (untrusted) → Attestation (trusted)

**Untrusted responsibilities** (parsing / normalization):

- Parse and validate schema (XML/JSON) to a canonical internal structure.
- Compute a stable digest of the payload (e.g. `sha256(raw_payload_bytes)`).
- Extract only the fields required for mapping + audit.

Clarification (to avoid “trust the parser”):

- The TEE MUST receive `raw_payload_bytes` (or a rail-defined canonical byte representation).
- The TEE MUST recompute `raw_payload_hash = sha256(raw_payload_bytes)` internally and compare it to any untrusted-side claimed hash.
- If the TEE produces or hashes `normalized_settlement`, it MUST use a deterministic canonical serialization (e.g., RFC 8785 JCS for JSON; a rail-defined XML canonicalization for ISO 20022).
- The attested artifact MUST NOT include raw payload bytes (only hashes + extracted fields required for mapping and audit).

**Trusted responsibilities** (TEE / Conclave):

- Recompute + re-validate the digest and any normalized payload hashing inside the TEE.
- Verify the oracle authenticity for the external rail (signature/HMAC/cert-chain; rail-specific).
- Produce an attested artifact that binds:
  - `rail`,
  - `raw_payload_hash`,
  - `normalized_settlement` (or a hash thereof),
  - `asset_path`,
  - `proposal_kind = EXTERNAL_SETTLEMENT_TRIGGER`,
  - `timelock_delay_blocks = 144`.

**Output artifact**: `AttestedExternalSettlementTrigger` (signed + TEE-attested).

### Boundary B — Attestation (trusted) → Proposal emission (write path)

The write path (proposal emission) **must only accept the attested trigger**, never the raw TradFi payload.

Proposal emission:

- Validates the TEE attestation.
- Validates that the proposal payload is “trigger-only” (no executable call data).
- Creates a **standard** proposal object (same type system / lifecycle as native proposals).
- Initiates the **standard** 144-block time-lock for the mapped `asset_path`.

### Boundary C — Proposal (queued) → Execution (permissioned)

Execution is a separate stage that:

- requires the existing multi-sig approvals,
- requires the time-lock to have elapsed,
- and uses the existing execution code-path (same lock/escrow primitives and yield routing).

Execution must never accept or interpret raw TradFi payloads.

## 3. Data model (minimum viable)

### 3.1 `ExternalSettlementMessage` (input)

- `rail`: `ISO20022 | PAPSS | BRICS`
- `raw_payload_bytes`
- `raw_payload_hash`
- `ingress_received_at`

### 3.2 `AttestedExternalSettlementTrigger` (TEE output)

- `rail`
- `raw_payload_hash`
- `trigger_id` (stable hash over `rail + raw_payload_hash + settlement_identifiers`)
- `asset_path` (see mapping)
- `timelock_delay_blocks = 144`
- `tee_attestation` (StrongBox/TEE/CloudTEE report)
- `oracle_verification` (rail-specific proof material; minimal)

### 3.3 `SovereignProposal` (proposal lane)

- `proposal_id`
- `proposal_kind = EXTERNAL_SETTLEMENT_TRIGGER`
- `trigger_id`
- `asset_path`
- `timelock` (start height + release height)
- `approval_policy` (existing multi-sig)
- `execution_payload_ref` (pointer to the *native* lock/escrow action template, **not** derived from TradFi bytes)

## 4. Mapping: settlement → digital asset path

The mapping from external settlement to a digital asset path must be deterministic and auditable.

Minimum requirement:

- Mapping is a pure function of the normalized settlement fields.
- Mapping output is an `asset_path` string or enum that selects an existing native execution template.

Example (illustrative only):

- `ISO20022(pacs.008, ccy=sBTC)` → `asset_path = BTC->sBTC`
- `PAPSS(ccy=USD)` → `asset_path = USD->sBTC`
- `BRICS(ccy=GOLD)` → `asset_path = GOLD->sBTC`

## 5. Time-lock initiation

On successful oracle verification (inside TEE), the system initiates the standard time-lock:

- `delay_blocks = 144`
- `release_height = start_height + 144`

The *start height* must be sourced from the same canonical chain height source used by the native path (e.g., Stacks burn-block height if that is the existing standard).

## 6. Yield routing invariants (5/5/90)

External-triggered lock events must call the **same** lock/escrow primitive as native flows so that downstream routing remains unchanged.

Invariant:

- “trigger source” must not influence yield split logic.
- the 5/5/90 productive streaming logic must only depend on the lock type and asset path.

## 7. Test plan (explicit and automatable)

### 7.1 Boundary tests

1. **Parsing can’t execute**
   - Given a valid ISO 20022 payload, parsing produces a normalized object + hash.
   - Parsing has no side-effect surface that can emit an execution.

2. **Only attested triggers can become proposals**
   - Without a valid TEE attestation: proposal emission fails.
   - With a valid TEE attestation: proposal emission succeeds.

3. **No raw payload enters execution**
   - Execution inputs reference `trigger_id` and `asset_path` only.
   - A raw payload (XML/JSON) cannot be supplied to the executor.

### 7.2 Lifecycle tests

1. Verified external message produces a proposal (status: queued/timelocked), not an execution.
2. The timelock release height matches native behavior (`+144` blocks from native start height).
3. Multi-sig approvals are still required.
4. Yield routing outputs are identical (bit-for-bit) for native vs external-triggered lock events.
