# Session broker normative specification (CON-441)

This document defines the normative protocol boundary for the Conxian **session broker**.

The session broker is the trust boundary that issues and validates short-lived session credentials for protected Conxian APIs while enforcing proof-of-possession (PoP), mTLS binding, replay prevention, revocation checks, and fail-closed behavior.

ZSE note: this spec is public-safe and intentionally excludes private endpoints, concrete certificate identifiers, and key-management procedures.

## 1) Goals and non-goals

### Goals

- Define actors and trust boundaries for broker-mediated sessions.
- Define the handshake and session lifecycle semantics.
- Define mandatory TTL rules, PoP/mTLS binding, replay protection, and idempotency.
- Define revocation and attestation checks required for issuance and refresh.
- Define fail-closed rules, error taxonomy, and audit requirements.

### Non-goals

- Defining specific identity-provider vendor APIs.
- Defining custody/key-ceremony processes.
- Replacing per-service authorization policy; this spec governs session-broker boundary controls.

## 2) Actors and trust boundaries

| Actor | Role | Trust assumptions | Required controls |
| --- | --- | --- | --- |
| **Client workload** (wallet/app/service) | Requests and uses sessions | Possesses private PoP key and mTLS cert key material | PoP signing, nonce handling, key protection |
| **Session broker** | Validates handshake and issues session credentials | Trusted to enforce policy and fail closed | mTLS validation, PoP checks, revocation/attestation checks |
| **Resource server** (Gateway/Nexus API) | Enforces token/session validity at request time | Trusts broker-issued tokens only when proof checks pass | Token validation, PoP replay checks, idempotency enforcement |
| **Attestation verifier** | Validates device/workload attestation status | Supplies authoritative attestation verdicts | freshness and revocation-aware status API |
| **Revocation authorities** | Cert/key/session revocation signal sources | Must be queryable and current | CRL/OCSP/session-revocation cache |
| **Audit sink** | Immutable event capture for compliance/forensics | Write integrity and retention guarantees | append-only event writes and trace correlation |

## 3) Protocol objects (normative)

### 3.1 Session-init request

`SessionInitRequest` MUST contain:

- `client_id` (string)
- `aud` (string; intended resource audience)
- `scope` (array/string)
- `client_nonce` (high-entropy, single-use)
- `idempotency_key` (single logical handshake attempt key)
- `attestation_ref` (reference or bundle hash)
- `pop_jwk_thumbprint` (PoP key thumbprint)

Transport requirements:

- MUST be sent over mTLS.
- MUST include a PoP-signed header/proof over `(method, uri, body_hash, nonce, iat, jti)`.

### 3.2 Session grant

`SessionGrant` MUST include:

- `session_id` (opaque stable identifier)
- `access_token` (short-lived)
- `expires_at` and `issued_at`
- `cnf` claim binding token to PoP key thumbprint
- `mtls_cert_thumbprint` claim binding token to mTLS cert
- optional `refresh_token` (if enabled by policy)

### 3.3 Session state transitions

`PENDING -> ACTIVE -> EXPIRED`

Additional terminal states:

- `REVOKED`
- `ATTESTATION_INVALID`
- `MTLS_INVALID`

Once a session enters a terminal invalid state (`REVOKED`, `ATTESTATION_INVALID`, `MTLS_INVALID`), it MUST NOT be reactivated.

## 4) Handshake sequence (normative)

```text
Client                          Session Broker                   Attestation/Revocation
  |                                   |                                   |
  |-- mTLS connect ------------------>|                                   |
  |-- SessionInitRequest + PoP ------>|                                   |
  |                                   |-- verify attestation -----------> |
  |                                   |-- check cert/key/session revoke-> |
  |                                   |<-- status responses ------------- |
  |                                   |-- policy + replay checks          |
  |<-- SessionGrant / error ----------|                                   |
```

### 4.1 Step requirements

1. **mTLS establishment**
   - Broker MUST validate client certificate chain and validity window.
2. **PoP verification**
   - Broker MUST verify PoP signature and ensure `jti` is unused within replay window.
3. **Attestation check**
   - Broker MUST validate `attestation_ref` freshness and verdict.
4. **Revocation checks**
   - Broker MUST check certificate, key, and existing session revocation sources.
5. **Policy evaluation**
   - Broker MUST evaluate audience/scope/subject policy before issuing session.
6. **Grant issuance**
   - Broker MAY issue session only if all checks pass.

If any mandatory check cannot be completed, the broker MUST fail closed.

## 5) Token and session TTL semantics

| Artifact | Required TTL semantics |
| --- | --- |
| `client_nonce` | Single-use; valid for at most 120 seconds from issuance |
| PoP proof (`jti`) | Single-use within replay cache window; minimum replay cache retention 15 minutes |
| `access_token` | MUST be short-lived; maximum 300 seconds |
| `refresh_token` (if used) | MUST be bound to same PoP+mTLS identity and expire in <= 30 minutes |
| Session (`session_id`) | Absolute max lifetime <= 8 hours; policy MAY enforce shorter limits |

Normative TTL rules:

1. Expired artifacts MUST be rejected.
2. Broker/resource servers MUST use bounded clock-skew tolerance (recommended <= 60 seconds).
3. Refresh MUST re-run revocation and attestation checks before issuing replacement access token.

## 6) PoP and mTLS binding requirements

### 6.1 Binding model

Every issued access token MUST be jointly bound to:

- PoP key (`cnf` thumbprint), and
- mTLS client certificate thumbprint.

### 6.2 Request-time checks

Resource server MUST verify all of the following on every protected request:

1. Access token signature and expiry.
2. Presented mTLS cert thumbprint equals token `mtls_cert_thumbprint`.
3. PoP proof verifies against token `cnf` key binding.
4. PoP proof `htm/htu/body-hash/nonce` matches the received request.
5. PoP `jti` is not replayed.

Failure of any check MUST return an authentication error and MUST NOT degrade to bearer-only acceptance.

## 7) Replay protection and idempotency

### 7.1 Replay prevention (mandatory)

- Broker and resource servers MUST maintain replay caches for PoP `jti` values.
- Replay caches MUST be partitioned at minimum by `(client_id, cnf_thumbprint)`.
- A repeated `jti` inside replay window MUST be rejected as replay.

### 7.2 Idempotency for side-effecting calls

- All side-effecting API calls behind brokered sessions MUST require `Idempotency-Key`.
- Resource servers MUST dedupe by `(subject, route, idempotency_key, request_hash)` for at least 24 hours.
- Same key with different request hash MUST return an idempotency conflict error.

## 8) Revocation and attestation checks

### 8.1 Revocation sources

At minimum, implementations MUST check:

1. mTLS certificate revocation status.
2. PoP key/session revocation lists.
3. Broker-issued session revocation records.

### 8.2 Attestation checks

- Session issuance MUST require attestation status = valid and within freshness policy.
- Session refresh MUST re-check attestation validity.
- Privileged scopes MAY require stricter attestation tier checks than baseline scopes.

### 8.3 Unavailable dependencies

If revocation or attestation status cannot be retrieved with required freshness, broker MUST fail closed (no issuance/refresh).

## 9) Fail-closed rules (normative)

The broker and resource server MUST reject requests when any of the following occurs:

1. Missing/invalid mTLS context.
2. Missing/invalid PoP proof.
3. Replay signal detected.
4. Expired token/session/nonce.
5. Revocation source indicates revoked status.
6. Attestation missing, stale, unverifiable, or invalid.
7. Required policy decision unavailable.
8. Audit-write requirement configured as synchronous and audit sink unavailable.

No fallback to weaker auth mode is allowed for endpoints requiring brokered sessions.

## 10) Error taxonomy (normative)

| Code | HTTP | Category | Meaning | Retry guidance |
| --- | --- | --- | --- | --- |
| `SB_AUTH_INVALID_MTLS` | 401 | Authentication | mTLS missing/invalid/revoked | Retry only after cert remediation |
| `SB_AUTH_INVALID_POP` | 401 | Authentication | PoP signature/claims invalid | Retry with fresh PoP proof |
| `SB_AUTH_REPLAY_DETECTED` | 409 | Replay | Reused nonce/jti/idempotency key | Retry with new nonce/jti/key |
| `SB_AUTH_TOKEN_EXPIRED` | 401 | Authentication | Access/session expired | Re-authenticate or refresh |
| `SB_AUTH_REVOKED` | 403 | Authorization | Cert/key/session revoked | Do not retry until revoked state cleared |
| `SB_ATTESTATION_INVALID` | 403 | Attestation | Attestation failed policy | Re-attest and re-init session |
| `SB_DEPENDENCY_UNAVAILABLE` | 503 | Availability | Required revocation/attestation/policy dependency unavailable | Retry with backoff |
| `SB_IDEMPOTENCY_CONFLICT` | 409 | Idempotency | Same idempotency key, different payload | Generate new key and reconcile |
| `SB_AUDIT_WRITE_FAILED` | 503 | Audit integrity | Required audit write failed | Retry after audit sink recovery |

Error responses SHOULD include machine-readable fields: `code`, `message`, `trace_id`, `retryable`.

## 11) Audit and evidence requirements

### 11.1 Mandatory audit events

The following events MUST be recorded with immutable traceability:

- `session.init.received`
- `session.init.denied`
- `session.issued`
- `session.refreshed`
- `session.revoked`
- `request.auth.rejected`
- `request.idempotency.conflict`

### 11.2 Minimum audit fields

Each event record MUST include at least:

- `event_id`
- `timestamp`
- `trace_id`
- `session_id` (if available)
- `client_id`
- `subject`
- `aud`
- `scope`
- `mtls_cert_thumbprint`
- `cnf_thumbprint`
- `attestation_status`
- `decision` (`ALLOW`/`DENY`)
- `decision_reason_code`

### 11.3 Retention and integrity baseline

- Audit records MUST be retained for at least 365 days (or stricter policy if required).
- Audit events MUST be tamper-evident (append-only or equivalent integrity guarantees).
- Access to audit logs MUST be restricted and itself auditable.

## 12) Conformance checklist

An implementation is conformant only if:

1. Section 4 handshake checks are fully enforced.
2. Section 5 TTL ceilings are not exceeded.
3. Section 6 PoP+mTLS dual binding is enforced at request time.
4. Section 7 replay/idempotency controls are active and tested.
5. Section 8 revocation and attestation checks run for init and refresh.
6. Section 9 fail-closed rules are demonstrably active.
7. Section 10 error codes are returned consistently.
8. Section 11 audit events and fields are present in production telemetry.
