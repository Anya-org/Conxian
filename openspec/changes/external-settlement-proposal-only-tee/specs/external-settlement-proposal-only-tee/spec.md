# Spec: Proposal-only external settlement triggers (TEE enforced)

Proposal-only external settlement triggers define how ISO 20022 / PAPSS / BRICS messages may enter the sovereign system.

## 1. Normative rules

1. **TradFi payloads are never execution authority**
   - A raw ISO 20022 / PAPSS / BRICS payload MUST NOT be consumed by any execution function.
   - Raw payloads MAY be parsed/normalized for audit and mapping.

2. **TEE verification is required before proposal emission**
   - A proposal MUST NOT be emitted unless a TEE/StrongBox/CloudTEE attestation verifies:
     - `raw_payload_hash` MUST equal the lowercase hex encoding (no `0x` prefix) of the 32-byte SHA-256 digest of `raw_payload_bytes` (computed from `raw_payload_bytes` inside the TEE),
     - `normalized_settlement_hash` MUST equal the lowercase hex encoding (no `0x` prefix) of the 32-byte SHA-256 digest of `canonical_settlement_tx_bytes`, where `canonical_settlement_tx_bytes` is the rail-specific canonical serialization of the normalized settlement transaction (computed inside the TEE as follows):
       - JSON: RFC 8785 JSON Canonicalization Scheme (JCS)
         - `canonical_settlement_tx_bytes` MUST be the UTF-8 encoding (no BOM) of the JCS output string.
       - XML: W3C XML Canonicalization 1.1
         - `canonical_settlement_tx_bytes` MUST be the XML C14N 1.1 octet stream output (not re-encoded as text).
       - Additional requirement: rail-specific normalization MUST be envelope-agnostic: the same settlement transaction replayed in different envelopes/messages MUST yield the same `normalized_settlement_hash`, and envelope-level metadata (e.g., message identifiers, timestamps, routing fields) MUST NOT affect `normalized_settlement_hash`.
       - The canonical settlement transaction bytes (`canonical_settlement_tx_bytes`) hashed to produce `normalized_settlement_hash` MUST include at least the canonical `transaction_identifiers` defined in §2.1.1, and MUST NOT include any `envelope_identifiers`.
     - any digest/hash computed outside the TEE MUST be treated as untrusted; the TEE MUST recompute authoritative values from `raw_payload_bytes` and reject any mismatch with host-supplied claims
     - `settlement_identifiers` MUST be derived/normalized inside the TEE from `raw_payload_bytes`. If the host supplies a `settlement_identifiers` optimization hint, it MUST be provided to the TEE as `raw_settlement_identifiers_hint_bytes` and validated exactly as specified in §2.1.1 (including attestation refusal on mismatch and oversized hints)
     - the oracle authenticity proof,
     - and the deterministic mapping to `asset_path`.

Hex encoding conventions: the lowercase hex encoding of any 32-byte SHA-256 digest in this spec (including `raw_payload_hash`, `normalized_settlement_hash`, `trigger_id`, and `oracle_proof_digest`) MUST be exactly 64 characters long (`0-9`, `a-f`) and MUST include leading zeros for leading zero bytes. Implementations MUST reject any value that is not exactly 64 characters of lowercase hex in this range (for example, inputs with `0x` prefixes, uppercase hex, incorrect length, or non-hex characters). For illustration, a regular-expression such as `^[0-9a-f]{64}$` MAY be used to validate this constraint.

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

7. **Idempotency / replay protection** <a id="idempotency-replay-protection"></a>
   - `trigger_id` MUST be computed deterministically as follows:
     - Canonicalization MUST use RFC 8785 JSON Canonicalization Scheme (JCS).
     - `rail` MUST be encoded as an uppercase ASCII string with one of: `"ISO20022"`, `"PAPSS"`, `"BRICS"`.
     - Implementations MUST reject any external settlement trigger whose `rail` field is not exactly one of the allowed strings above.
     - Expanding the rail identifier set requires a spec update, and may require versioning the `trigger_id` domain separator.
     - `normalized_settlement_hash` MUST be exactly the 64-character lowercase hex SHA-256 string over `canonical_settlement_tx_bytes` computed as specified in §1.2.
     - The canonicalized value MUST be the JCS output for the JSON object `{"rail": rail, "normalized_settlement_hash": normalized_settlement_hash}` (exact key names as shown).
     - The hash input MUST be the byte concatenation `utf8("external-settlement-trigger:v1") || utf8(JCS({"rail": rail, "normalized_settlement_hash": normalized_settlement_hash}))`.
     - The hash MUST be SHA-256 over the hash input bytes.
     - `trigger_id` MUST be the lowercase hex encoding (no `0x` prefix) of the SHA-256 digest.
     - If `trigger_id` test vectors are provided, they MUST specify `{ rail, normalized_settlement_hash, trigger_id }` using the encodings above, and SHOULD also include the canonical JCS string `JCS({"rail": rail, "normalized_settlement_hash": normalized_settlement_hash})` and the intermediate 32-byte SHA-256 digest as a 64-character lowercase hex string.
   - Idempotency is enforced at the trigger granularity (one trigger per settlement transaction).
   - Proposal emission MUST be idempotent on `trigger_id`: duplicate triggers MUST NOT create additional proposals or timelocks.

## 2. Required artifacts

### 2.1 `AttestedExternalSettlementTrigger`

Minimum fields:

- `rail` (see §1.7 for canonical encoding and allowed values)
- `raw_payload_hash` (lowercase hex encoding, no `0x` prefix, of the 32-byte SHA-256 digest of `raw_payload_bytes`)
- `settlement_identifiers` (per-rail canonical set; see below)
- `normalized_settlement_hash` (see §1.2 for canonical settlement bytes and encoding)
- `trigger_id` (lowercase hex encoding, no `0x` prefix, of the 32-byte SHA-256 digest computed as specified in §1.7)
- `asset_path`
- `timelock_delay_blocks` (must equal `144`)
- `tee_attestation`
- `oracle_verification`

The TEE attestation MUST bind (directly or by digest) the canonical values of at least `{ rail, raw_payload_hash, normalized_settlement_hash, trigger_id, settlement_identifiers, asset_path, timelock_delay_blocks, oracle_verification }` so they cannot be altered after verification. The canonical `oracle_verification` value that the TEE attests MUST embed `oracle_proof_digest` (and MAY additionally embed the exact oracle proof bytes), and proposal emission MUST verify only that same proof input, so a different proof cannot be substituted before or after attestation.

`oracle_verification` MUST NOT be a bare boolean. It MUST be a JSON object and MUST include (directly or by digest) the exact oracle proof bytes verified inside the TEE. At minimum, it MUST include `oracle_proof_digest`, defined as the 64-character lowercase hex encoding (characters `0-9a-f`, no `0x` prefix) of SHA-256 over `utf8("oracle-proof:v1") || raw_oracle_proof_bytes`.

The TEE MUST compute `oracle_proof_digest` from the exact `raw_oracle_proof_bytes` it verifies and MUST NOT accept any host-provided digest value as authoritative; any host-provided digest MUST be recomputed and any mismatch MUST cause attestation to fail.

If `oracle_verification` embeds the raw oracle proof bytes, they MUST be encoded as base64url as defined in RFC 4648 §5 (URL- and filename-safe alphabet, no padding `=`) in `oracle_proof_bytes_b64`.

If `oracle_verification` includes `oracle_proof_bytes_b64`, its character length MUST be ≤ 21846 (the maximum base64url length corresponding to 16384 raw bytes with padding removed). Any violation of this character-length bound MUST cause the trigger to be rejected at proposal emission time, and every component that base64url-decodes `oracle_proof_bytes_b64` MUST enforce this bound before decoding. Decoding it MUST yield exactly the `raw_oracle_proof_bytes` used both to verify the oracle authenticity proof and to compute `oracle_proof_digest`.

Proposal emission MUST validate that `oracle_verification` is a JSON object containing `oracle_proof_digest` in the format defined above and, if present, `oracle_proof_bytes_b64` as valid RFC 4648 §5 base64url (no padding); any violation MUST cause the proposal to be rejected.

`raw_oracle_proof_bytes` MUST be the exact byte sequence of the oracle authenticity proof input, before any internal parsing, canonicalization, or transformation.

`raw_oracle_proof_bytes` MUST be at most 16384 bytes in length. The TEE MUST enforce this bound before attempting to parse or verify the proof and MUST refuse to produce a successful attestation if it is exceeded. Proposal emission MUST reject any trigger whose persisted `raw_oracle_proof_bytes` exceed this bound. If `oracle_verification.oracle_proof_bytes_b64` is present, its decoded length MUST also satisfy this bound.

The component that invokes the TEE MUST persist the exact `raw_oracle_proof_bytes` alongside the resulting `AttestedExternalSettlementTrigger` so proposal emission can recompute `oracle_proof_digest` deterministically.

At proposal emission time, implementations MUST treat the persisted `raw_oracle_proof_bytes` as the primary authoritative oracle proof bytes and MUST use them whenever they are present and readable. If the persisted `raw_oracle_proof_bytes` for an `AttestedExternalSettlementTrigger` are missing or are I/O-level unavailable (for example, a storage read fails), proposal emission MAY instead use `oracle_verification.oracle_proof_bytes_b64`, but only if it is present in the TEE-bound `oracle_verification`. Persisted bytes that are present but truncated, exceed the length bound, or disagree with `oracle_proof_bytes_b64` MUST NOT be treated as unavailable under this rule and MUST instead cause a permanent validation failure. If neither persisted `raw_oracle_proof_bytes` nor `oracle_verification.oracle_proof_bytes_b64` are available, the trigger MUST be treated as a permanent validation failure. Implementations MUST NOT attempt to reconstruct the oracle proof bytes from any other non-attested source. This fallback to `oracle_verification.oracle_proof_bytes_b64` SHOULD be treated as an exceptional, strongly audited recovery path rather than normal steady-state behavior.

If `oracle_verification` includes `oracle_proof_bytes_b64`, proposal emission MUST decode it and verify that:

- If persisted `raw_oracle_proof_bytes` are present, the decoded bytes are byte-identical to the persisted `raw_oracle_proof_bytes`.
- SHA-256 over `utf8("oracle-proof:v1") || decoded_bytes` equals the attested `oracle_proof_digest`.

Proposal emission MUST reject on any mismatch.

Proposal emission MUST recompute `oracle_proof_digest` from the authoritative oracle proof bytes (the persisted `raw_oracle_proof_bytes` if available, otherwise the decoded `oracle_verification.oracle_proof_bytes_b64`) and MUST reject if the result differs from the `oracle_proof_digest` value bound by the TEE attestation.

Prohibited fields:

- `raw_payload_bytes`
- Any full parsed external-settlement payload structure (XML/JSON) beyond the canonical `settlement_identifiers`.

#### 2.1.1 `settlement_identifiers` (per-rail canonical set)<a id="settlement-identifiers-canonical"></a>

`settlement_identifiers` MUST be a JSON object with two namespaces:

- `transaction_identifiers`: envelope-agnostic identifiers for the settlement transaction.
- `envelope_identifiers`: envelope/message-local identifiers for audit/debug only.

Within `settlement_identifiers`, implementations MUST use only JSON objects with leaf values restricted to JSON strings and JSON numbers that MUST be integers in the range `[0, 9007199254740991]` (inclusive, i.e. `2^53-1`); arrays MUST NOT be used.

For the purposes of this section, nesting depth is the number of JSON object keys in a JSON key path (root object properties have depth 1), and a leaf field is any JSON key path whose value is not a JSON object.

Example: in `transaction_identifiers.transaction_reference`, the key `transaction_identifiers` has depth 1 and `transaction_reference` has depth 2. `transaction_identifiers` is not a leaf (its value is an object), while `transaction_identifiers.transaction_reference` is a leaf.

If the canonical `settlement_identifiers` derived from `raw_payload_bytes` fails to meet the structural and leaf-type constraints in this section, the TEE MUST refuse to produce a successful attestation.

The canonical `settlement_identifiers` derived from `raw_payload_bytes` MUST have max nesting depth ≤ 8, contain ≤ 128 leaf fields, and when serialized using RFC 8785 JCS (UTF-8) MUST be ≤ 16384 bytes. If any bound is exceeded, the TEE MUST refuse to produce a successful attestation.

Because the size bound above uses RFC 8785 JCS, JSON objects with duplicate member names are invalid; the canonical `settlement_identifiers` MUST NOT contain duplicate member names at any object level, and if duplicates are present the TEE MUST refuse to produce a successful attestation.

`transaction_identifiers` MUST be included in the normalized settlement transaction hashed to produce `normalized_settlement_hash`.

`envelope_identifiers` MUST NOT affect `normalized_settlement_hash`.

`settlement_identifiers` MUST be derived/normalized inside the TEE from `raw_payload_bytes`.

Implementations MUST NOT treat any host-supplied `settlement_identifiers` as authoritative. If a host supplies any identifiers as an optimization hint:

- The host MUST provide the hint to the TEE as `raw_settlement_identifiers_hint_bytes`, defined as the exact UTF-8 JSON byte sequence encoding a JSON object.
- The TEE MUST treat `raw_settlement_identifiers_hint_bytes` as untrusted input.
- The byte length of the exact `raw_settlement_identifiers_hint_bytes` provided to the TEE MUST be ≤ 16384 bytes, and this bound MUST be enforced before JSON parsing. If the bound is exceeded, the TEE MUST refuse to produce a successful attestation.
- The TEE MUST parse `raw_settlement_identifiers_hint_bytes` as UTF-8 JSON. If parsing fails or the parsed value is not a JSON object, the TEE MUST refuse to produce a successful attestation.
- When parsing `raw_settlement_identifiers_hint_bytes`, the TEE MUST treat any JSON object containing duplicate member names at any object level as invalid input (i.e., MUST NOT apply keep-first/keep-last semantics) and MUST refuse to produce a successful attestation.
- After parsing, the hint object MUST satisfy the structural and leaf-type constraints in this section, have max nesting depth ≤ 8, contain ≤ 128 leaf fields, and, when serialized using RFC 8785 JCS (UTF-8), MUST be ≤ 16384 bytes. The TEE MUST enforce the depth, leaf-count, and structural/leaf-type constraints while traversing the hint object for validation and MUST abort that traversal as soon as it can determine that any of those bounds would be exceeded. Before using the hint object for any canonical-vs-hint comparison or any further processing beyond this validation pass, the TEE MUST compute the RFC 8785 JCS (UTF-8) serialization of the hint object and enforce the 16384-byte size bound on that serialized form.
- Separately, before any canonical-vs-hint comparison or any trigger-critical computation, the TEE MUST treat any optional `settlement_identifiers.envelope_identifiers` fields (i.e., any keys other than `tx_index`) whose values individually violate any additional field-specific canonicalization or validation requirement for that key (i.e., beyond the structural/leaf-type constraints and global bounds enforced above), if defined, as absent. Any canonical-vs-hint comparison in the following bullets MUST be performed against this post-processing view of the hint object. Optional `settlement_identifiers.envelope_identifiers` fields MUST NOT be discarded in order to bypass the maximum nesting depth, maximum leaf-field count, or RFC 8785 JCS size bounds; any violation of those global bounds MUST cause the TEE to refuse to produce a successful attestation.
- The TEE MUST recompute the canonical `settlement_identifiers` from `raw_payload_bytes` and compare any overlapping leaf fields. An overlapping leaf field is any canonical leaf-field JSON key path present in both objects. For each overlapping leaf field, the host-supplied JSON value MUST exactly equal the TEE-derived canonical JSON value (same JSON type and value). If any overlapping leaf field differs, the TEE MUST refuse to produce a successful attestation.
- If any JSON key path present in the hint object has a JSON object value in the canonical `settlement_identifiers` but a non-object value in the hint, the TEE MUST refuse to produce a successful attestation.
- Any host-supplied extra fields MUST be ignored for canonicalization purposes, but the hint object (including any extra fields) remains subject to all constraints above (allowed leaf value types, maximum nesting depth, maximum leaf count, and JCS-serialized size bounds).
- The `AttestedExternalSettlementTrigger.settlement_identifiers` included in the attested payload MUST be exactly the TEE-derived canonical object; host-supplied hints (including any extra fields) MUST NOT be forwarded or merged into the attested/returned identifiers.

Any TEE attestation failure caused by invalid, out-of-bounds, or mismatched host-supplied `settlement_identifiers` hints for a given `{ rail, raw_payload_hash }` instance MUST be treated as a permanent validation failure in the normal automated processing pipeline. Implementations MUST NOT automatically retry the same `{ rail, raw_payload_hash }` with modified or omitted hints in order to probe for a passing combination. Any operator-initiated override that reprocesses such a payload (for example, after a production bug fix) MUST be explicitly configured, strongly audited, and MUST NOT weaken the TEE’s comparison rules.

Implementations MUST distinguish hint-validation failures from transient TEE/infrastructure errors (for example, via stable error codes). Hint-validation failures MUST be treated as permanent validation failures, while transient errors MAY be retried.

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

- `settlement_identifiers.transaction_identifiers` MUST be present and MUST be a JSON object whose values are strings. If the `settlement_identifiers.transaction_identifiers` member is absent, is not an object, or contains any non-string value, this MUST be treated as a canonicalization failure for the corresponding settlement transaction.
- Implementations MUST canonicalize and validate each string value in `settlement_identifiers.transaction_identifiers` as follows:
  1. When constructing `settlement_identifiers` from upstream bytes, implementations MUST decode those bytes as UTF-8 and MUST treat any decoding error as a canonicalization failure for the corresponding settlement transaction (i.e., MUST NOT substitute `U+FFFD`).
  2. Implementations MUST reject any value that is not a sequence of Unicode scalar values (reject surrogate code points `U+D800..U+DFFF`).
  3. The value MUST be normalized to Unicode NFC; all subsequent validation, equality, and hashing operates on the NFC-normalized value.
  4. Implementations MUST reject the value if any of the following holds:
     - The NFC-normalized value is empty.
     - The UTF-8 encoding of the NFC-normalized value exceeds 4096 bytes.
     - The NFC-normalized value contains any Unicode control or format character (characters with `General_Category` Cc or Cf in the Unicode Character Database).
     - The NFC-normalized value contains the Unicode replacement character `U+FFFD`.
     - The NFC-normalized value begins or ends with any Unicode whitespace character (characters with `White_Space=Y` in the Unicode Character Database).

- The normalization and validation rules in items 1–4 above apply to all values in `settlement_identifiers.transaction_identifiers` (including any optional reconciliation keys) and do not apply to fields outside `settlement_identifiers.transaction_identifiers`.
- `transaction_identifiers.transaction_reference` MUST satisfy the canonical string rules above and MUST preserve case.
- `settlement_identifiers.envelope_identifiers` MUST be present and MUST be a JSON object containing the required `envelope_identifiers.tx_index`.
- `envelope_identifiers.tx_index` MUST be a JSON number that is an integer in the range `[0, 9007199254740991]` (inclusive, i.e. `2^53-1`).
  - If `settlement_identifiers.envelope_identifiers` is absent or is not an object, or `envelope_identifiers.tx_index` is absent or invalid, the settlement transaction MUST be treated as invalid for external-settlement trigger purposes.

Note: This section intentionally tightens earlier guidance. These canonicalization and structural requirements are normative for the current `external-settlement-trigger:v1` definition.

Any settlement transaction that fails any of the requirements above (including the type/structure requirements for `settlement_identifiers.transaction_identifiers` or canonicalization/validation of any of its values, including any optional reconciliation keys) MUST be treated as invalid for external-settlement trigger purposes and MUST NOT produce a `normalized_settlement_hash` or `SovereignProposal`.

`envelope_identifiers.tx_index` MUST satisfy the field requirements above. If `envelope_identifiers.tx_index` is missing or fails these requirements, the corresponding settlement transaction MUST be treated as invalid for external-settlement trigger purposes and MUST NOT produce a `normalized_settlement_hash` or `SovereignProposal`.

Any other `settlement_identifiers.envelope_identifiers` keys are optional metadata. Optional envelope identifier values MUST satisfy the structural and leaf-type constraints in this section and MUST NOT cause the overall `settlement_identifiers` object to violate the maximum nesting depth, maximum leaf-field count, or RFC 8785 JCS (UTF-8) size bounds in this section. If an optional envelope identifier satisfies those constraints and bounds but fails any additional field-specific canonicalization or validation requirement defined by this spec, implementations MUST treat that value as if the corresponding field were absent and MUST NOT treat the settlement transaction as invalid solely because of that field. If an optional envelope identifier violates any structural or leaf-type constraint in this section or causes any of the maximum nesting depth, maximum leaf-field count, or RFC 8785 JCS (UTF-8) size bounds in this section to be violated, the settlement transaction MUST be treated as invalid as specified above.

Unrecognized keys under `settlement_identifiers.envelope_identifiers` MUST be treated as metadata only: their presence MUST NOT affect any consensus-critical behavior of `external-settlement-trigger:v1` (including validity decisions and any trigger-critical computation such as `normalized_settlement_hash`), except that their values remain subject to the structural and leaf-type constraints in this section and MUST NOT cause the overall `settlement_identifiers` object to violate the maximum nesting depth, maximum leaf-field count, or RFC 8785 JCS (UTF-8) size bounds in this section. If a value under any unrecognized `settlement_identifiers.envelope_identifiers` key violates any such constraint or bound, the settlement transaction MUST be treated as invalid as specified above.

For both the TEE-derived canonical `settlement_identifiers` object and any host-supplied `settlement_identifiers` hints, implementations MUST enforce the maximum nesting depth, maximum leaf-field count, and RFC 8785 JCS size bounds in this section on the resulting object (whether host-supplied and parsed, or TEE-derived) before treating any optional `settlement_identifiers.envelope_identifiers` fields as absent. Before computing `normalized_settlement_hash` (and before any canonical-vs-hint comparison), implementations MUST treat any optional `settlement_identifiers.envelope_identifiers` fields (i.e., any keys other than `tx_index`) whose values individually violate any additional field-specific canonicalization or validation requirement for that key (beyond the structural/leaf-type constraints and global bounds in this section), if defined, as absent. Optional `settlement_identifiers.envelope_identifiers` fields MUST NOT be discarded in order to bypass the maximum nesting depth, maximum leaf-field count, or RFC 8785 JCS size bounds; any violation of those global bounds MUST be treated as a permanent validation failure.

For `external-settlement-trigger:v1`, the TEE and all other components that canonicalize or validate `settlement_identifiers` (including host-side validators and offline tooling) MUST use Unicode 15.1.0 (Unicode Character Database + normalization data) for evaluating `General_Category`, `White_Space`, and NFC normalization.

Once an `external-settlement-trigger:vN` protocol version is activated, its pinned Unicode version and canonicalization rules MUST remain fixed. Any change to either requires a spec revision and a protocol version bump (e.g., from `external-settlement-trigger:vN` to `external-settlement-trigger:vN+1`).

Implementations MUST apply canonicalization/validation before any hashing, attestation, or equality checks. String equality MUST be defined as byte-equality over the UTF-8 encoding of the Unicode NFC-normalized value (no locale-dependent collation). Implementations MUST NOT apply case folding unless explicitly required by a field-specific canonicalization or validation requirement.

Implementations MAY accept non-NFC-normalized input from upstream rails, but MUST convert it to Unicode NFC as part of canonicalization; all validation and equality checks operate on the NFC-normalized value.

Rails MAY include additional canonical identifiers (e.g., for reconciliation) in `settlement_identifiers.transaction_identifiers`. These optional identifier values are subject to the canonical string rules above. If a rail includes any of the following identifier keys, their values MUST be emitted in the canonical form specified:

- `settlement_currency`: ISO 4217 code; the value MUST match `^[A-Za-z]{3}$`. The emitted canonical form MUST be the ASCII uppercase (`A`–`Z`) of those three letters and MUST match `^[A-Z]{3}$`.
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
2. Valid payload but invalid oracle proof → TEE refuses to produce a successful attestation.
3. Any attempt to include `raw_payload_bytes` or a full external-settlement payload structure in `AttestedExternalSettlementTrigger` → rejected.
4. Any attempt to supply raw TradFi payload (bytes or parsed structure) to execution code → rejected.
5. Replay the same settlement transaction (same `trigger_id`) → no new proposal/timelock created.
6. Any attempt to skip multi-sig approvals → rejected.
7. Any attempt to change timelock away from 144 blocks (increase or decrease) → rejected.
8. Host-supplied `settlement_identifiers` mismatch the TEE-derived identifiers (for any overlapping field) for the same `raw_payload_bytes` → TEE refuses to produce a successful attestation.
9. Host-supplied `settlement_identifiers` hints exceed the TEE bounds in §2.1.1 → TEE refuses to produce a successful attestation.
10. Oracle proof bytes do not hash to the `oracle_proof_digest` bound by the TEE attestation → proposal emission fails.
11. `settlement_identifiers` (canonical or host hint) violates the structural/leaf-type constraints in §2.1.1 (pre-drop; before treating any optional `settlement_identifiers.envelope_identifiers` fields as absent) → TEE refuses to produce a successful attestation.
12. `oracle_verification` is not a JSON object or is missing `oracle_proof_digest` → proposal emission fails.
13. `oracle_verification.oracle_proof_digest` is not a lowercase hex-encoded SHA-256 digest → proposal emission fails.
14. Canonical `settlement_identifiers` exceed the bounds in §2.1.1 → TEE refuses to produce a successful attestation.
15. `oracle_verification.oracle_proof_bytes_b64` (if present) does not match the persisted `raw_oracle_proof_bytes` or does not hash to `oracle_proof_digest` → proposal emission fails.
16. `oracle_verification.oracle_proof_bytes_b64` is not valid base64url (e.g., contains padding `=` or characters outside `[A-Za-z0-9_-]`) → proposal emission fails.
17. Truncated or oversized persisted `raw_oracle_proof_bytes` for an attested trigger (even if `oracle_verification.oracle_proof_bytes_b64` is present), or missing persisted `raw_oracle_proof_bytes` when `oracle_verification.oracle_proof_bytes_b64` is also unavailable → proposal emission fails.
18. `oracle_verification.oracle_proof_bytes_b64` is valid RFC 4648 §5 base64url but exceeds the maximum allowed character length (21846) → proposal emission fails.
