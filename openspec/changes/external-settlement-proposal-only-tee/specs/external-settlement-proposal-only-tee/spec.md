# Spec: Proposal-only external settlement triggers (TEE enforced)

Proposal-only external settlement triggers define how ISO 20022 / PAPSS / BRICS messages may enter the sovereign system.

## 1. Normative rules

1. **TradFi payloads are never execution authority**
   - A raw ISO 20022 / PAPSS / BRICS payload MUST NOT be consumed by any execution function.
   - Raw payloads MAY be parsed/normalized for audit and mapping.

2. **TEE verification is required before proposal emission**
   - A proposal MUST NOT be emitted unless a TEE/StrongBox/CloudTEE attestation verifies:
     - the payload digest (computed from `raw_payload_bytes` inside the TEE),
     - `normalized_settlement_hash` (computed inside the TEE) using a rail-specific canonical serialization:
       - JSON: RFC 8785 JSON Canonicalization Scheme (JCS)
       - XML: W3C XML Canonicalization 1.1
     - any digest/hash computed outside the TEE MUST be treated as untrusted; the TEE MUST recompute authoritative values from `raw_payload_bytes` and reject any mismatch with host-supplied claims
     - the oracle authenticity proof,
     - and the deterministic mapping to `asset_path`.

3. **Timelock is mandatory**
   - Verified external triggers MUST initiate the standard 144-block timelock.
   - The start height MUST use the same canonical chain-height source used by the native path.

4. **Timelock scheduling is owned by proposal emission**
   - The TEE MUST attest `timelock_delay_blocks = 144`.
   - Proposal emission MUST schedule the timelock after verifying TEE attestation.
   - Execution MUST NOT accept a `start_height` or `release_height` sourced from the raw TradFi payload.

5. **Multi-sig approvals are mandatory**
   - Verified external triggers MUST enter the same multi-sig approval policy as native proposals.

6. **Yield routing invariance**
   - Downstream yield routing MUST be identical for native vs external-triggered lock events.
   - Trigger source MUST NOT change the 5/5/90 productive streaming behavior.

7. **Idempotency / replay protection**
   - `trigger_id` MUST be computed deterministically using a canonical encoding (e.g., `sha256("external-settlement-trigger:v1" || JCS({ rail, raw_payload_hash, settlement_identifiers }))`). Idempotency is enforced per `{ rail, raw_payload_hash, settlement_identifiers }` (one trigger per settlement transaction within a given `raw_payload_hash`).
   - Proposal emission MUST be idempotent on `trigger_id`: duplicate triggers MUST NOT create additional proposals or timelocks.

## 2. Required artifacts

### 2.1 `AttestedExternalSettlementTrigger`

Minimum fields:

- `rail`
- `raw_payload_hash`
- `settlement_identifiers`
- `normalized_settlement_hash`
- `trigger_id`
- `asset_path`
- `timelock_delay_blocks` (must equal `144`)
- `tee_attestation`
- `oracle_verification`

Prohibited fields:

- `raw_payload_bytes`
- Any full parsed external-settlement payload structure (XML/JSON) beyond the canonical `settlement_identifiers`.

#### 2.1.1 `settlement_identifiers` (per-rail canonical set)

Minimum required identifier set (by rail):

`tx_index` requirements (all rails):

- `tx_index` MUST be computed over the rail-defined settlement-transaction entries (e.g., ISO20022 `pacs.008` `CdtTrfTxInf` elements) in the exact sequence they appear in the received message payload, before any internal normalization or reordering. Implementations MUST NOT reorder transactions for indexing.
- The index MUST be computed over all transaction entries present in the received message payload, including any that are later rejected or skipped.

Example: if a message contains three settlement-transaction entries `[A, B, C]` and `B` is later rejected or skipped, any triggers emitted for `A` and `C` still use `tx_index = 0` and `tx_index = 2`.

- **ISO20022 (pacs.008)**
  - `message_id`
  - `tx_index` (0-based index of the `CdtTrfTxInf` element in the order it appears in the received XML document)
  - `transaction_reference` (prefer `uetr`, else `end_to_end_id`, else `tx_index` as a base-10 string)
- **PAPSS**
  - `message_id`
  - `tx_index` (0-based index of the transaction entry in the order it appears in the received message payload)
  - `transaction_reference` (if not present, use `tx_index` as a base-10 string)
- **BRICS**
  - `message_id`
  - `tx_index` (0-based index of the transaction entry in the order it appears in the received message payload)
  - `transaction_reference` (if not present, use `tx_index` as a base-10 string)

Canonical formatting requirements:

- `message_id` and `transaction_reference` MUST be UTF-8 strings (Unicode NFC), MUST NOT contain `\n`, and MUST preserve case.
- `tx_index` MUST be a non-negative integer.

### 2.2 `SovereignProposal` (trigger-kind)

Minimum fields:

- `proposal_kind = EXTERNAL_SETTLEMENT_TRIGGER`
- `trigger_id`
- `asset_path`
- `timelock` (start + release heights)
- `approval_policy`

Prohibited fields:

- Any “call data” / executable contract payload that is derived from the raw TradFi bytes.

## 3. Negative test cases (must exist)

1. Missing or invalid TEE attestation → proposal emission fails.
2. Valid payload but invalid oracle proof → proposal emission fails.
3. Any attempt to include `raw_payload_bytes` or a full external-settlement payload structure in `AttestedExternalSettlementTrigger` → rejected.
4. Any attempt to supply raw TradFi payload (bytes or parsed structure) to execution code → rejected.
5. Replay the same external trigger (same `trigger_id`) → no new proposal/timelock created.
6. Any attempt to skip multi-sig approvals → rejected.
7. Any attempt to change timelock away from 144 blocks (increase or decrease) → rejected.
