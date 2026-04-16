# BOS self-executing contract trigger v1 (CON-440)

This document defines a public-safe, protocol-level contract for how BOS (Business Operations System) turns verified CLM webhooks into a height-gated, multisignature finalization flow for on-chain actions.

The intent is to make “approved off-chain intent” auditable and deterministic, while ensuring on-chain execution remains governed by a 144-block timelock and explicit quorum-based approvals.

ZSE note: this spec MUST remain public-safe. It defines formats, invariants, and verification rules, but it MUST NOT contain operational secrets (shared keys, allowlists, wallet addresses, internal endpoints, etc.).

## 1) Goals and non-goals

Goals:

- Define which CLM webhook events are admissible to create or cancel a pending on-chain action.
- Define transport-level webhook verification (HMAC + timestamp freshness).
- Define message-level verification using `SignedEnvelopeV1`.
- Define deterministic payload hashing (`payload_hash`, `action_hash`) and idempotency keys (`event_id`, `action_id`).
- Define the action lifecycle: queue → 144-block timelock → multisig approvals → execute / cancel / expire.
- Define replay protection, cancellation semantics, monitoring, and audit traceability requirements.

Non-goals:

- Operational allowlist management (which publishers are trusted, where policy lives, how secrets rotate).
- Exact contract code, storage layout, or concrete Clarity entrypoints (implementations may vary).
- Key ceremonies, signer onboarding, or custody procedures (see `docs/protocols/ENTERPRISE_CUSTODY_BASELINE.md`).

## 2) Terminology

- **CLM**: a control-plane service that emits webhook events when an action is approved or canceled.
- **BOS ingress**: the component that receives CLM webhooks, verifies them, and enqueues on-chain actions.
- **Action**: a public-safe, structured request to mutate on-chain state (e.g., “call contract X with args Y”).
- **Pending action**: the on-chain record created when an action is queued but not yet executed.

## 3) Event types (webhook kinds)

This spec defines two webhook kinds, encoded as `SignedEnvelopeV1.kind`:

- `clm.onchain_action.approved.v1`
- `clm.onchain_action.canceled.v1`

Implementations MUST reject any other `kind`.

### 3.1 State model

Pending actions are modeled as a state machine.

Non-terminal states:

- `QUEUED`: action record exists; timelock not yet satisfied.
- `READY`: timelock satisfied; action is eligible to be approved by signers.
- `APPROVING`: at least one approval recorded; quorum not yet reached.

Terminal states:

- `EXECUTED`: successfully executed on-chain.
- `CANCELED`: canceled by governance-authorized logic.
- `EXPIRED`: execution window passed; MUST be treated as non-executable.

State invariants:

- `unlock_height` MUST be immutable after queueing.
- `action_hash` MUST be immutable after queueing.
- If `current_height > execution_expiry_height`, the action MUST be treated as `EXPIRED` regardless of any persisted `status` field.
- Attempts to cancel or execute a terminal action MUST fail closed (rejected or explicit no-op) and MUST be audit logged.

## 4) Transport verification (webhook HMAC)

Transport verification is an HMAC over the raw HTTP request body bytes plus a canonical prefix that binds request metadata.

### 4.1 Required headers

Implementations MUST require:

- `X-CLM-Timestamp`: base-10 integer Unix epoch seconds.
- `X-CLM-Signature`: lowercase hex encoding of `HMAC-SHA256` output.

### 4.2 Canonical string-to-sign

Let:

- `timestamp = X-CLM-Timestamp` (exact header bytes; parsed as integer for freshness checks)
- `method = UPPERCASE(HTTP method)` (for example `POST`)
- `path = raw request path` (the exact UTF-8 bytes of the path-and-query portion of the request target as observed by BOS ingress after all intermediary rewrites; no additional normalization)
- `raw_body_bytes = the raw HTTP request body bytes (unmodified)`

Deployments MUST ensure the `path` value signed by CLM is byte-for-byte identical to the `path` observed by BOS ingress after any intermediate hops (reverse proxies, API gateways, load balancers). If an intermediary rewrites the request path, CLM and BOS MUST agree on the exact rewritten path that is signed and verified.

Construct:

- `prefix = timestamp || '.' || method || '.' || path || '.'`
- `message_bytes = UTF-8(prefix) || raw_body_bytes`
- `sig = HMAC-SHA256(shared_secret, message_bytes)`

`X-CLM-Signature` MUST equal `hex(sig)`.

Comparison MUST be constant-time.

### 4.3 Freshness window

BOS ingress MUST enforce a bounded freshness window for `X-CLM-Timestamp` to reduce replay risk.

Requirements:

- Requests with timestamps more than `skew_tolerance` seconds in the future MUST be rejected.
- Requests older than a deployment-defined window `W` seconds MUST be rejected.
- The value of `W` is policy-defined and intentionally not specified here.

`skew_tolerance` is policy-defined and expected to be small relative to `W`.

## 5) Message verification (`SignedEnvelopeV1`)

The HTTP body MUST be a `SignedEnvelopeV1` as defined in `docs/protocols/SIGNED_EVENT_ENVELOPE_V1.md`.

Envelope acceptance requirements (in addition to the `SignedEnvelopeV1` spec):

- `v` MUST equal `1`.
- `kind` MUST be one of the kinds defined in section 3.
- `payload_hash` MUST equal `SHA-256(JCS(payload))`.
- `event_id` MUST equal `SHA-256(JCS(signing_root))` (per the envelope spec).
- At most one of `expires_at` or `expires_height` MAY be set; if both are present, the envelope MUST be rejected. If neither is set, the envelope is valid and has no envelope-level expiry.
- If either `expires_at` or `expires_height` is set, BOS ingress MUST enforce the expiry semantics defined in `SIGNED_EVENT_ENVELOPE_V1` and reject envelopes that are expired at verification time, even if transport HMAC and freshness checks succeed.

Replay protection requirement:

- BOS ingress MUST persist a durable idempotency record keyed by `event_id`.
- A given `event_id` MUST NOT be accepted more than once, even if the transport HMAC is valid.
- The idempotency record MUST include a final processing result for the `event_id` (for example: `ACCEPTED`, `REJECTED`, `BLOCKED`, `NO_OP`). Duplicate deliveries with the same `event_id` MUST be short-circuited to a no-op that reuses the recorded result; they MUST NOT re-run policy checks or create new on-chain attempts.
- The idempotency store MUST enforce uniqueness on `event_id`, and the check-and-record step MUST be implemented as an atomic operation so that concurrent deliveries of the same `event_id` cannot both proceed past idempotency enforcement.

## 6) Payload schemas

### 6.1 `clm.onchain_action.approved.v1` payload

The approved payload creates a new pending action.

Required fields:

- `action_id` (string): MUST equal the envelope `event_id` (hex).
- `action` (object): public-safe structured action intent.
- `action_hash` (string): lowercase hex `SHA-256(JCS(action))`.

Optional fields:

- `reason_code` (string): public-safe code describing why the action was approved.

Normative requirements:

- BOS ingress MUST compute `SHA-256(JCS(action))` and verify it equals `action_hash`.
- BOS ingress MUST verify `action_id == event_id`.
- BOS ingress MUST pass the validated `action_hash` unchanged into the queue transaction and MUST persist that same `action_hash` for `action_id`.
- If any accepted cancellation intent already exists for `action_id` with a different `action_hash`, BOS ingress MUST fail closed (reject) and MUST audit log the protocol violation.
- If a prior accepted cancellation intent exists for the same (`action_id`, `action_hash`), BOS ingress MUST NOT queue the action and MUST emit an audit event indicating a pre-queue cancellation.
- Queueing and recording cancellation intent for a given (`action_id`, `action_hash`) MUST be serialized at the BOS ingress persistence layer so that, in BOS’s durable records, at most one of {`QUEUE_ACCEPTED`, `PRE_QUEUE_CANCELLATION_ACCEPTED`} is ever recorded for that pair.

Informal TypeScript shape:

```ts
export type ClmOnchainActionApprovedV1 = {
  action_id: string; // == event_id
  action: Record<string, unknown>;
  action_hash: string; // sha256(JCS(action))
  reason_code?: string;
};
```

### 6.2 `clm.onchain_action.canceled.v1` payload

The canceled payload records CLM’s intent that an action should not execute.

Required fields:

- `action_id` (string): the action identifier to cancel.
- `action_hash` (string): lowercase hex `SHA-256(JCS(action))` for the action being canceled.
- `reason_code` (string): public-safe cancellation code.

Normative requirements:

- If an accepted cancellation intent already exists for the same (`action_id`, `action_hash`), BOS ingress MUST treat the new event as an idempotent `NO_OP` and MUST NOT modify previously persisted state for that (`action_id`, `action_hash`).
- If any accepted cancellation intent already exists for `action_id` with a different `action_hash`, the cancellation MUST be rejected and audit logged.
- If a pending action record exists for `action_id` and the payload `action_hash` equals the queued `action_hash`, BOS ingress MUST persist the cancellation intent keyed by (`action_id`, `action_hash`) and MUST emit an audit event.
- If a pending action record exists for `action_id` and the payload `action_hash` does not equal the queued `action_hash`, the cancellation MUST be rejected and audit logged.
- If no pending action record exists for `action_id`, BOS ingress MUST persist the cancellation intent keyed by (`action_id`, `action_hash`) so later queueing attempts can be deterministically blocked. If on-chain or archival state indicates `action_id` is already terminal (`EXECUTED`, `CANCELED`, or `EXPIRED`), BOS MUST also emit the “CLM–chain disagreement” audit event described in section 10.
- The cancellation-intent store MUST enforce concurrency-safe uniqueness on cancellations per `action_id`, so that at most one distinct `action_hash` can ever be accepted for a given `action_id`. The check-and-persist operation MUST be atomic with respect to other in-flight cancellations for the same `action_id`.

Informal TypeScript shape:

```ts
export type ClmOnchainActionCanceledV1 = {
  action_id: string;
  action_hash: string;
  reason_code: string;
};
```

## 7) Queueing semantics (pending action record)

When an approved event is accepted, BOS ingress MUST create an on-chain pending action record keyed by `action_id`.

Queue idempotency requirements:

- If a pending action already exists for `action_id` with the same `action_hash`, BOS ingress MUST treat the queue step as an idempotent no-op and MUST audit log the duplicate queue attempt.
- If a pending action already exists for `action_id` with a different `action_hash`, BOS ingress MUST fail closed (reject) and MUST audit log the collision.

The pending action record MUST include (directly or derivable):

- `action_id` (hex)
- `action_hash` (hex)
- `created_height` (number; derived from Stacks `block-height` at queue time)
- `unlock_height` (number; immutable)
- `execution_expiry_height` (number; immutable)

### 7.1 Timelock (144 blocks)

The 144-block timelock is defined in chain height terms.

Requirements:

- `unlock_height` MUST be set such that `unlock_height >= created_height + 144`.
- Implementations MAY choose a larger value; they MUST NOT choose a smaller value.

### 7.2 Execution expiry

To avoid actions remaining executable indefinitely, queueing MUST set an execution expiry height.

Requirements:

- `execution_expiry_height` MUST be greater than or equal to `unlock_height`.
- The maximum allowed span between `unlock_height` and `execution_expiry_height` is policy-defined and intentionally not specified here.
- If `current_height > execution_expiry_height`, the action MUST be treated as `EXPIRED` and MUST NOT be executed.

## 8) Approval semantics (multisig gating)

After an action is queued, governance-authorized signers MAY record approvals at any time. Execution remains height-gated by section 9.

Requirements:

- Each approval MUST be signer-attributable (the signer identity MUST be recorded in an auditable form).
- Approvals MUST be bound to both `action_id` and `action_hash`.
- A signer MUST NOT be able to contribute more than one approval to the same action.

Implementations MUST expose a deterministic way to derive:

- `required_quorum` (number)
- `approvals_count` (number)

## 9) Finalization semantics (execute)

An action may be executed only if all of the following are true:

- the on-chain state for `action_id` is non-terminal (i.e., not `EXECUTED`, `CANCELED`, or `EXPIRED`)
- `current_height >= unlock_height`
- `current_height <= execution_expiry_height`
- `approvals_count >= required_quorum`
- `action_hash` provided to finalization matches the queued `action_hash`
- no accepted cancellation intent exists for (`action_id`, `action_hash`)

Execution MUST fail closed if any condition is not met.

## 10) Cancellation semantics

Cancellation has two layers:

1. **CLM cancellation intent** (off-chain): a `clm.onchain_action.canceled.v1` event.
2. **On-chain cancellation** (authoritative): governance-authorized cancellation of a pending action.

CLM cancellation events:

- MUST be stored as durable audit records.
- MUST NOT directly trigger on-chain cancellation; on-chain cancellation MUST be governance-authorized.
- MUST be used by BOS ingress to block queueing an action if the cancellation arrives before queueing and references the same (`action_id`, `action_hash`).

If a cancellation intent exists for a queued action, BOS approval/finalization automation MUST treat the action as blocked and MUST NOT execute it. CLM can “reverse” a cancellation only by issuing a new approved event (which will have a new `action_id`).

CLM MUST NOT reuse an `action_id` once a cancellation intent exists. To “reverse” a cancellation it MUST issue a new approved event with a new `action_id`.

On-chain cancellation requirements:

- Cancellation MUST be bound to `action_id` and MUST verify the queued `action_hash`.
- Cancellation MUST be permitted for non-terminal states (`QUEUED`, `READY`, `APPROVING`) and MUST NOT require waiting for `unlock_height`.
- Cancellation MUST require `approvals_count >= required_quorum` (same quorum as execution).

This spec intentionally uses the same quorum for cancellation and execution. Any emergency-stop primitive with a different threshold must be modeled as a separate action type and governance rule.
- Cancellation MUST be rejected (or explicit no-op) for terminal states (`EXECUTED`, `CANCELED`, `EXPIRED`).
- If a CLM cancellation is received after an action is terminal, BOS MUST record a “CLM–chain disagreement” audit event.

## 11) Monitoring and audit traceability

Implementations MUST produce an audit trail sufficient to reconstruct:

- a cryptographic commitment to the exact bytes authenticated at the transport layer
- exactly what envelope/payload was accepted at the message layer
- how the action was mapped into an on-chain pending record
- why execution/cancellation attempts were accepted, rejected, or blocked

Minimum required identifiers to persist for each accepted webhook:

- `event_id`
- `kind`
- `created_at` (envelope)
- `payload_hash`
- `action_id`
- `action_hash` (if applicable)
- transport timestamp (`X-CLM-Timestamp`) and verification result
- `http_method` and `request_path` as used in the HMAC verification
- `raw_body_hash` (recommended: `SHA-256(raw_body_bytes)`)

Minimum required identifiers to persist for each on-chain attempt (queue/approve/execute/cancel):

- `action_id`
- `action_hash`
- `txid` (if broadcast)
- `observed_height`
- attempt result (`ACCEPTED`, `REJECTED`, `BLOCKED`, `NO_OP`) with a public-safe reason code

## 12) Verification checklist (implementation-facing)

Ingress MUST, in order:

1. Read and retain `raw_body_bytes` exactly as received.
2. Verify transport freshness and `X-CLM-Signature` per section 4.
3. Parse body as `SignedEnvelopeV1` and verify envelope per section 5.
4. Enforce durable idempotency on `event_id`.
   - If an idempotency record already exists, short-circuit processing to a no-op and reuse the recorded result.
   - Otherwise create an idempotency record before proceeding. This MUST be concurrency-safe and atomic with respect to other in-flight processing of the same `event_id`.
5. Validate the payload schema and hashes per section 6.
6. Perform allowlist/policy checks for the action (policy-defined, out of scope here).
   - This applies to both approval and cancellation events.
7. Queue or record cancellation intent, emitting audit events per section 11.
