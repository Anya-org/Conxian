# Design: ERP sync + ISO 20022 mapping + MVCR artifact foundation (Milestone 1)

## 1. Problem
Conxian needs a reviewable first milestone for ERP integration and compliance reporting that is deterministic, testable, and ready for incremental wiring into broader gateway/settlement paths.

## 2. Contract foundation
Milestone 1 introduces a canonical event shape consumed by local generation flows:

- `rail` (`ISO20022 | PAPSS | BRICS`)
- `erp_system` (source or destination ERP identifier)
- `direction` (`ingress | egress`)
- `settlement_payload` (canonicalized JSON object)
- `compliance_checks` (list of `{ code, passed, details? }`)
- optional lineage hints (`source_event_id`, `iso20022_message_type`)

## 3. Deterministic identity model

### 3.1 Settlement trigger identity
- Canonicalize settlement payload as stable JSON (sorted keys, normalized text).
- Compute `normalized_settlement_hash = sha256(canonical_settlement_payload)`.
- Compute `trigger_id = sha256("external-settlement-trigger:v1|" + canonical({rail, normalized_settlement_hash}))`.
- Derive `idempotency_key = "{rail}:{normalized_settlement_hash}"`.

### 3.2 ERP sync identity
- Compute deterministic ERP idempotency key from canonical `{erp_system, direction, trigger_id}`.
- Use dedicated namespace prefix to avoid collision with settlement trigger namespace.

## 4. ISO 20022 mapping foundation
Milestone 1 ships mapping metadata for common canonical entities and a deterministic settlement reference selection order:

1. `payment_identification.uetr`
2. `payment_identification.end_to_end_id`
3. `payment_identification.instruction_id`

This allows consistent trigger extraction and compliance artifact lineage for initial integration.

## 5. MVCR artifact model and rendering
Each MVCR artifact includes:

- identity: `artifact_id`, `profile`, `generated_at`
- business context: `rail`, `erp_system`, `direction`, `settlement_reference`, `iso20022_message_type`
- checks: normalized compliance check list
- status: `passed` or `failed`
- lineage: `trigger_id`, `normalized_settlement_hash`, `erp_sync_idempotency_key`, and optional anchor/event references

Renderers:
- machine-readable JSON serializer
- human-readable Markdown renderer scaffold

## 6. Integration point
`conxian-business/transparency_custodian.py` remains the existing executable flow and is extended to optionally:

1. load a settlement event payload,
2. generate MVCR artifacts,
3. persist MVCR JSON + Markdown into `conxian-business/.generated/`.

This keeps milestone 1 low-risk and additive while establishing reusable primitives.

## 7. Testing strategy
- Determinism test: equivalent payloads (key order / Unicode form differences) produce the same trigger identity.
- MVCR success test: valid ISO 20022-style settlement input yields `passed` artifact.
- MVCR failure/edge tests:
  - failed compliance check yields failed artifact,
  - missing required settlement reference raises validation error.
