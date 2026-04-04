# Spec: Proposal-only external settlement triggers (TEE enforced)

Proposal-only external settlement triggers define how ISO 20022 / PAPSS / BRICS messages may enter the sovereign system.

## 1. Normative rules

1. **TradFi payloads are never execution authority**
   - A raw ISO 20022 / PAPSS / BRICS payload MUST NOT be consumed by any execution function.
   - Raw payloads MAY be parsed/normalized for audit and mapping.

2. **TEE verification is required before proposal emission**
   - A proposal MUST NOT be emitted unless a TEE/StrongBox/CloudTEE attestation verifies:
     - the payload digest (computed from `raw_payload_bytes` inside the TEE),
     - `normalized_settlement_hash` (computed inside the TEE) for each settlement transaction using a rail-specific canonical serialization:
       - JSON: RFC 8785 JSON Canonicalization Scheme (JCS)
       - XML: W3C XML Canonicalization 1.1
       - Additional requirement: rail-specific normalization MUST be envelope-agnostic: the same settlement transaction replayed in different envelopes/messages MUST yield the same `normalized_settlement_hash`, and envelope-level metadata (e.g., message identifiers, timestamps, routing fields) MUST NOT affect `normalized_settlement_hash`.
       - The normalized settlement transaction hashed to produce `normalized_settlement_hash` MUST include at least the canonical `transaction_identifiers` defined in §2.1.1, and MUST NOT include any `envelope_identifiers`.
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
   - `trigger_id` MUST be computed deterministically as follows:
     - Canonicalization MUST use RFC 8785 JSON Canonicalization Scheme (JCS).
     - The canonicalized value MUST be the JCS output for the JSON object `{"rail": rail, "normalized_settlement_hash": normalized_settlement_hash}` (exact key names as shown).
     - The hash MUST be SHA-256 over `utf8("external-settlement-trigger:v1") || utf8(JCS({"rail": rail, "normalized_settlement_hash": normalized_settlement_hash}))`.
     - `trigger_id` MUST be the lowercase hex encoding of the SHA-256 digest.
   - Idempotency is enforced at the trigger granularity (one trigger per settlement transaction).
   - Proposal emission MUST be idempotent on `trigger_id`: duplicate triggers MUST NOT create additional proposals or timelocks.

## 2. Required artifacts

### 2.1 `AttestedExternalSettlementTrigger`

Minimum fields:

- `rail`
- `raw_payload_hash`
- `settlement_identifiers` (per-rail canonical set; see below)
- `normalized_settlement_hash`
- `trigger_id`
- `asset_path`
- `timelock_delay_blocks` (must equal `144`)
- `tee_attestation`
- `oracle_verification`

Prohibited fields:

- `raw_payload_bytes`
- Any full parsed external-settlement payload structure (XML/JSON) beyond the canonical `settlement_identifiers`.

#### 2.1.1 `settlement_identifiers` (per-rail canonical set) <a id="settlement-identifiers-canonical"></a>

`settlement_identifiers` MUST be a JSON object with two namespaces:

- `transaction_identifiers`: envelope-agnostic identifiers for the settlement transaction.
- `envelope_identifiers`: envelope/message-local identifiers for audit/debug only.

`transaction_identifiers` MUST be included in the normalized settlement transaction hashed to produce `normalized_settlement_hash`.

`envelope_identifiers` MUST NOT affect `normalized_settlement_hash`.

Minimum required identifier set (by rail):

`tx_index` requirements (all rails):

- `tx_index` MUST be computed over the rail-defined settlement-transaction entries (e.g., ISO20022 `pacs.008` `CdtTrfTxInf` elements) in the exact sequence they appear in the received message payload, before any internal normalization or reordering. Implementations MUST NOT reorder transactions for indexing.
- The index MUST be computed over all transaction entries present in the received message payload, including any that are later rejected or skipped.

Example: if a message contains three settlement-transaction entries `[A, B, C]` and `B` is later rejected or skipped, any triggers emitted for `A` and `C` still use `tx_index = 0` and `tx_index = 2`.

- **ISO20022 (pacs.008)**
  - `transaction_identifiers.transaction_reference` (prefer `uetr`, else `end_to_end_id`, else `instruction_id`)
  - `envelope_identifiers.tx_index`
- **PAPSS**
  - `transaction_identifiers.transaction_reference`
  - `envelope_identifiers.tx_index`
- **BRICS**
  - `transaction_identifiers.transaction_reference`
  - `envelope_identifiers.tx_index`

Canonical formatting requirements:

- All string values in `settlement_identifiers` MUST be canonicalized and validated as follows:
  1. If an upstream source provides bytes, implementations MUST decode them as UTF-8 and MUST treat any decoding error as a canonicalization failure for the corresponding settlement transaction (i.e., MUST NOT substitute `U+FFFD`).
  2. Implementations MUST reject any value that is not a sequence of Unicode scalar values (reject surrogate code points `U+D800..U+DFFF`).
  3. The value MUST be normalized to Unicode NFC; all subsequent validation, equality, and hashing operates on the NFC-normalized value.
  4. Implementations MUST reject the value if the NFC-normalized value is empty, contains any Unicode control or format character (characters with `General_Category` Cc or Cf in the Unicode Character Database), contains the Unicode replacement character `U+FFFD`, or begins or ends with any Unicode whitespace character (characters with `White_Space=Y` in the Unicode Character Database).
- `transaction_identifiers.transaction_reference` MUST satisfy the canonical string rules above and MUST preserve case.
- `envelope_identifiers.tx_index` MUST be a non-negative integer.

Note: This section intentionally tightens earlier guidance. These canonicalization rules are normative for the current `external-settlement-trigger:v1` definition. Values that violate these canonical string rules MUST be treated as invalid.

If any value in `settlement_identifiers` (including any field-specific rules for optional reconciliation keys) fails canonicalization or validation, the corresponding settlement transaction MUST be treated as invalid for external-settlement trigger purposes and MUST NOT produce a `normalized_settlement_hash` or `SovereignProposal`.

For `external-settlement-trigger:v1`, implementations MUST use Unicode 15.1.0 (Unicode Character Database + normalization data) for evaluating `General_Category`, `White_Space`, and NFC normalization.

Once an `external-settlement-trigger:vN` protocol version is activated, its pinned Unicode version and canonicalization rules MUST remain fixed. Any change to either requires a spec revision and a protocol version bump (e.g., from `external-settlement-trigger:vN` to `external-settlement-trigger:vN+1`).

Implementations MUST apply canonicalization/validation before any hashing, attestation, or equality checks. String equality MUST be defined as byte-equality over the UTF-8 encoding of the Unicode NFC-normalized value (no locale-dependent collation). Implementations MUST NOT apply case folding unless explicitly required by a field-specific canonicalization rule.

Implementations MAY accept non-NFC-normalized input from upstream rails, but MUST convert it to Unicode NFC as part of canonicalization; all validation and equality checks operate on the NFC-normalized value.

Rails MAY include additional canonical identifiers (e.g., for reconciliation) in `settlement_identifiers.transaction_identifiers`. These optional identifier values are subject to the canonical string rules above. If a rail includes any of the following identifier keys, their values MUST be emitted in the canonical form specified:

- `settlement_currency`: ISO 4217 code; the value MUST match `^[A-Za-z]{3}$`. The emitted canonical form MUST be the ASCII uppercase (`A`–`Z`) of those three letters.
- `settlement_amount`: normalized non-negative decimal string (no sign, no exponent; canonical regex: `^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$`). The emitted value MUST match this regex. Fractional parts MUST NOT end in `0`, and integer values MUST NOT include a decimal point (e.g., `0`, `1`, `0.5`, `123.45` are valid; `01`, `1.0`, `0.50` are invalid).
- `settlement_date`: ISO 8601 full-date `YYYY-MM-DD`. The emitted value MUST match `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, MUST represent a valid proleptic Gregorian calendar date with a year in the range `0001`–`9999`, and MUST NOT include any time-of-day or timezone offset component.

Implementations MUST NOT attempt to “fix up” non-canonical decimal strings for `settlement_amount`; any value that does not match the canonical form (after NFC normalization) MUST cause the corresponding settlement transaction to be treated as invalid for external-settlement trigger purposes and MUST NOT produce a `normalized_settlement_hash` or `SovereignProposal`.

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
5. Replay the same settlement transaction (same `trigger_id`) → no new proposal/timelock created.
6. Any attempt to skip multi-sig approvals → rejected.
7. Any attempt to change timelock away from 144 blocks (increase or decrease) → rejected.
