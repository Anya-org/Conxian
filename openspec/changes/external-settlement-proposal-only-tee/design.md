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
- Compute a stable digest of the payload for transport/audit (e.g. `sha256(raw_payload_bytes)`).
- Extract only the fields required for mapping + audit.

**Boundary contract**:

- `raw_payload_bytes` MUST be the exact octet sequence of the rail application payload at the capture point on the rail ingress boundary, after **only** removing rail-specific transport framing that delimits and exposes the message-body bytes (e.g., envelope/header stripping, record/frame boundary removal, removal of HTTP `Transfer-Encoding: chunked` framing).
- Construction of `raw_payload_bytes` MUST occur **before** any operation that interprets or transforms those bytes, including content decoding (e.g., base64), decompression (e.g., gzip or HTTP `Content-Encoding`), character-set decoding, parsing, or normalization.
- All intermediaries and ingress components between the external rail and this ingress capture point for `raw_payload_bytes` MUST be configured such that they do not transform the application payload octets other than performing the allowed transport-framing removal described above.
- The TEE MUST receive `raw_payload_bytes` exactly as defined above.
- Other than the allowed transport-framing removal defined above, `raw_payload_bytes` MUST NOT undergo any transformation (including, but not limited to, re-encoding, whitespace normalization, parser round-tripping, BOM insertion/removal, or newline translation).
- The TEE MUST NOT treat any untrusted-side hash computation as authoritative.

**Trusted responsibilities** (TEE / Conclave):

- Recompute `raw_payload_hash = sha256(raw_payload_bytes)` inside the TEE and compare it to the claimed hash.
- Compute `normalized_settlement_hash` inside the TEE from a canonical `normalized_settlement` derived from `raw_payload_bytes`.
  - The canonical serialization MUST be rail-specific.
  - JSON canonicalization: RFC 8785 JSON Canonicalization Scheme (JCS).
  - XML canonicalization: W3C XML Canonicalization 1.1.
- Verify the oracle authenticity for the external rail (signature/HMAC/cert-chain; rail-specific).
- Produce an attested artifact that binds:
  - `rail`,
  - `raw_payload_hash`,
  - `normalized_settlement_hash`,
  - `asset_path`,
  - `proposal_kind = EXTERNAL_SETTLEMENT_TRIGGER`,
  - `timelock_delay_blocks = 144`.

The attested artifact MUST NOT contain raw payload bytes.

**Output artifact**: `AttestedExternalSettlementTrigger` (signed + TEE-attested).

### Boundary B — Attestation (trusted) → Proposal emission (write path)

The write path (proposal emission) **must only accept the attested trigger**, never the raw TradFi payload.

Proposal emission:

- Validates the TEE attestation.
- Validates that the proposal payload is “trigger-only” (no executable call data).
- Creates a **standard** proposal object (same type system / lifecycle as native proposals).
- Schedules the **standard** 144-block time-lock for the mapped `asset_path`.
- MUST be idempotent on `trigger_id` (a duplicate trigger must not create additional proposals/timelocks).

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
- `normalized_settlement_hash` (hash of the normalized settlement transaction under canonical serialization)
- `trigger_id` (stable hash over `rail + normalized_settlement_hash`)
- `settlement_identifiers` (rail-specific canonical identifiers; see below)
- `asset_path` (see mapping)
- `timelock_delay_blocks = 144`
- `tee_attestation` (StrongBox/TEE/CloudTEE report)
- `oracle_verification` (rail-specific proof material; minimal)

#### 3.2.1 `settlement_identifiers` (required; canonical)

Each rail MUST define a canonical identifier set used to populate `settlement_identifiers` for audit and reconciliation.

`settlement_identifiers` SHOULD be treated as two namespaces:

- `transaction_identifiers`: envelope-agnostic identifiers for the settlement transaction.
- `envelope_identifiers`: envelope/message-local identifiers for audit/debug only.

`transaction_identifiers` MUST be included in the normalized settlement transaction hashed to produce `normalized_settlement_hash`.

`envelope_identifiers` (including `tx_index`) MUST NOT affect `normalized_settlement_hash`.

Replay protection and deterministic idempotency are enforced via `trigger_id` derived from `{ rail, normalized_settlement_hash }`.

Trigger granularity:

- A trigger is emitted **per settlement transaction** (not per envelope/message).
- If a single inbound message contains multiple settlement transactions (e.g., ISO 20022 `pacs.008` with multiple `CdtTrfTxInf` entries), it produces **one trigger per transaction**.
- Replaying the same settlement transaction in a different envelope/message MUST produce the same `trigger_id`.

Minimum required identifier set (by rail):

For normative `tx_index` requirements (ordering source, no-reorder constraint, and inclusion rules), see [specs/external-settlement-proposal-only-tee/spec.md §2.1.1](specs/external-settlement-proposal-only-tee/spec.md#211-settlement_identifiers-per-rail-canonical-set).

The per-rail `tx_index` parentheticals below are summaries; the spec is authoritative.

- **ISO20022 (pacs.008)**
  - `transaction_identifiers.transaction_reference` (MUST use the first available in this order)
    - `uetr` (e.g., `CdtTrfTxInf.PmtId.UETR`), else
    - `end_to_end_id` (e.g., `CdtTrfTxInf.PmtId.EndToEndId`), else
    - `instruction_id` (e.g., `CdtTrfTxInf.PmtId.InstrId`)
  - `envelope_identifiers.tx_index` (0-based index of the `CdtTrfTxInf` entry in rail-defined document order)
- **PAPSS**
  - `transaction_identifiers.transaction_reference` (rail-provided unique reference)
  - `envelope_identifiers.tx_index` (0-based index in rail-defined order)
- **BRICS**
  - `transaction_identifiers.transaction_reference` (rail-provided unique reference)
  - `envelope_identifiers.tx_index` (0-based index in rail-defined order)

Canonical formatting requirements:

- `transaction_identifiers.transaction_reference` MUST be a UTF-8 string (Unicode NFC), MUST NOT contain `\n`, and MUST preserve case.
- `envelope_identifiers.tx_index` MUST be a non-negative integer.

Proposal emission MUST be idempotent on `trigger_id`: duplicate triggers MUST NOT create additional proposals or timelocks.

Note: `trigger_id` MUST be a pure function of `{ rail, normalized_settlement_hash }`; differences in `raw_payload_hash` alone (e.g., different envelopes/messages carrying the same normalized settlement transaction) MUST NOT affect `trigger_id`.

To ensure cross-implementation stability, `trigger_id` MUST be computed from a canonical encoding of `{ rail, normalized_settlement_hash }` (e.g., `sha256("external-settlement-trigger:v1" || JCS({ rail, normalized_settlement_hash }))`).

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

After oracle verification and attestation succeed inside the TEE, proposal emission initiates the standard time-lock using the attested delay and the native chain-height source:

- `delay_blocks = 144`
- `start_height` is obtained at proposal emission time from the same canonical chain height source used by the native path
- `release_height = start_height + delay_blocks`

The TEE MUST attest `timelock_delay_blocks` but does not need to attest `start_height` or `release_height`.

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

4. **Replay is idempotent**
   - Replaying the same settlement transaction (same `trigger_id`) does not create additional proposals or timelocks.

### 7.2 Lifecycle tests

1. Verified external message produces a proposal (status: queued/timelocked), not an execution.
2. The timelock release height matches native behavior (`+144` blocks from native start height).
3. Multi-sig approvals are still required.
4. Yield routing outputs are identical (bit-for-bit) for native vs external-triggered lock events.
