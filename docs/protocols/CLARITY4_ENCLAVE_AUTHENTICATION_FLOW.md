# Clarity 4 enclave authentication flow (CON-465)

This document defines a public-safe, chain-verifiable flow for **hardware-backed identity** and **signature verification** from enclave-backed clients (Conxius Wallet / StrongBox / CloudTEE) into **Clarity 4** contract verification paths.

ZSE note: this spec intentionally avoids key-ceremony procedures, signer identities, concrete wallet principals, private endpoints, and any environment-specific identifiers. It focuses only on verifiable data shapes, trust boundaries, and fail-closed behavior.

## 1) Goals and non-goals

Goals:

- Make “enclave-backed approval” consumable by Clarity contracts using primitives available on-chain (notably `secp256k1-verify`).
- Define a clean trust boundary between:
  - platform/hardware attestation (off-chain), and
  - signature verification and replay protection (on-chain).
- Ensure all verification paths fail closed (no “best effort” authorization).
- Define explicit fallback / recovery behavior that does not silently weaken guarantees.

Non-goals:

- Defining the full attestation root-of-trust and certificate chain validation logic for every hardware platform.
- Defining operational allowlists, production key lifecycle processes, or incident response runbooks.
- Defining wallet UX.

## 2) Terms

- **Enclave key**: a `secp256k1` keypair whose private key never leaves the enclave boundary.
- **Subject**: the on-chain principal (account or contract) whose authority is being exercised by the enclave key.
- **Attestation evidence**: platform-specific evidence that a key is generated/held in a hardware-backed environment (StrongBox / TEE / CloudTEE). This is verified off-chain.
- **Clarity-verifiable proof**: a proof Clarity can check directly (for this flow: `secp256k1-verify` over a 32-byte message hash).
- **Relayer**: a principal that submits the on-chain transaction but is not necessarily the authorizing identity (for example, Gateway submitting a mandate signed by a user enclave).

## 3) Trust boundaries (who verifies what)

Clarity can verify cryptographic signatures, but it cannot realistically verify vendor attestation chains, parse large JSON blobs, or call external services. As a result, the system must split verification into two layers:

1. **Off-chain (hardware integrity / device identity)**
   - Verify device integrity evidence (Play Integrity / App Attest / Nitro / SGX-equivalent).
   - Bind an enclave public key to an identity subject.
   - Apply policy constraints that are impractical on-chain (certificate chain validation, allowlists, platform version checks).

2. **On-chain (authorization + replay protection)**
   - Verify that a signed request is authentic with `secp256k1-verify`.
   - Verify that the signing public key is currently authorized for the requested action.
   - Enforce freshness (expiry window) and anti-replay (idempotency).
   - Fail closed if any required verification input is missing.

This boundary is intentional: hardware attestation remains off-chain, while authorization is expressed on-chain in a way contracts can deterministically enforce.

## 4) Canonical proof format for Clarity 4

### 4.1 Message hash

All on-chain verification MUST be performed against a 32-byte message hash:

- `message: (buff 32)`

The message hash MUST be derived from a canonical, domain-separated encoding.

Two supported patterns:

1. **Direct payload-hash preimage (recommended for contract-executed payload buffers)**
   - `payload-hash = sha256(payload-bytes)` where `payload-bytes` is the exact bytes the contract will execute.
   - `message = sha256(preimage)` where `preimage` includes the domain separator plus all authorization-critical fields (see below).

2. **Signed Event Envelope v1 event id (recommended for envelope-style payloads)**
   - Use `docs/protocols/SIGNED_EVENT_ENVELOPE_V1.md` to compute `event_id` off-chain.
   - For this enclave-authentication flow, `event_id` MUST be defined as `sha256(...)` over a canonical encoding that includes, at a minimum, the envelope’s `payload_hash` and a unique anti-replay identifier (for example: nonce/sequence and an expiry window).
   - On-chain, do not treat `event_id` alone as sufficient domain separation.
   - Derive the Clarity-verifiable message as:

     `message = sha256(domain-separator || event_id)`

     where `domain-separator` binds the network, consuming contract, and action. `subject` MUST be bound either directly in the preimage or indirectly via the registry-derived subject pattern (where a `pubkey` is uniquely bound to a single subject). In this pattern, `payload-hash` and anti-replay fields are transitively bound via `event_id`, and the contract MUST additionally check `payload-hash == sha256(payload-bytes)` before acting on the payload.

Normative binding requirement: for any on-chain function that executes (or records) a `payload`, the contract MUST be able to deterministically bind the signed `message` to the exact payload bytes/fields it will act on. Implementations MUST NOT accept an arbitrary `(buff 32)` `message` that is not recomputed (or at minimum checked) against the call parameters.

Practical guidance:

- If the on-chain function accepts a raw `payload` buffer, the simplest binding is `payload-hash = sha256(payload)` and then `message = sha256(domain || payload-hash || ...)`, where `domain` is a constant buffer and `...` includes the minimal anti-replay and subject binding fields.
- If `Signed Event Envelope v1` is used, prefer passing the envelope’s `payload_hash` and `event_id` as explicit parameters, and have the contract check (at minimum) `payload_hash == sha256(payload-bytes)` before using `event_id` as the signed `message`.

Normative domain separation requirement: the `message` preimage MUST include a domain separator that uniquely identifies (at minimum) the network and the on-chain consumer of the signature (contract principal), so a valid signature cannot be replayed across contracts or networks.

Canonical encoding requirement: the preimage MUST be serialized unambiguously. Fixed-width fields (like `payload-hash`) SHOULD be used where possible. Any variable-length fields MUST be length-prefixed (or otherwise encoded in a non-ambiguous structured format). Implementations MUST NOT rely on naive string concatenation.

Reconstructability requirement: every field included in the signed preimage MUST be either (a) a contract constant, (b) provided as an explicit on-chain argument, or (c) deterministically derivable from those values. Implementations MUST NOT include off-chain-only identifiers that the contract cannot recompute.

At a minimum, the preimage MUST bind all authorization-critical fields:

- network identifier
- consuming contract identifier (contract principal)
- action identifier (function name or an equivalent action kind)
- `subject` (or a key that is uniquely bound to a subject in the on-chain registry, such as the enclave pubkey)
- `payload-hash`
- anti-replay identifier (nonce / `event_id` / sequence)

One acceptable high-level pattern is:

`message = sha256(network-id || contract-id || action-id || subject || payload-hash || nonce-or-event-id)`

### 4.2 Signature and public key

To be directly verifiable in Clarity, the signature suite MUST match the built-in `secp256k1-verify` input types:

- `signature: (buff 65)` as a recoverable ECDSA signature in the exact byte layout required by Clarity’s `secp256k1-verify`
- `public-key: (buff 33)` as compressed `secp256k1` public key

This aligns with the on-chain verifier reference contract:

- `Conxian/contracts/governance/governance-signature-verifier.clar`

## 5) Enrollment / key registration flow

Clarity contracts MUST NOT accept “any pubkey provided by the caller” as sufficient authorization. A key must be registered (and revocable) before it can authorize protected actions.

### 5.1 Required on-chain registry model

Define (or reuse) an on-chain registry that binds:

- an **identity subject** (a principal), to
- one or more **authorized enclave public keys** (33 bytes), with
- an **expiry window**, and
- an **attestation tier** label (for policy decisions).

The exact contract name is not mandated by this document; what matters is the behavior:

- Key registration is guarded by an explicit authority boundary.
- Keys are time-bounded (`expires-at`) and can be rotated.
- Contracts that require enclave authorization can query this registry deterministically.

Recommended minimum registry entry shape (canonical binding):

```
{ pubkey: (buff 33) } -> { subject: principal, tier: uint, expires-at: uint, created-at: uint, revoked-at: (optional uint) }
```

Optional index (if contracts need to enumerate keys by subject):

```
{ subject: principal, pubkey: (buff 33) } -> bool
```

Time unit requirement: all `*-at` fields in this document (`created-at`, `expires-at`, `revoked-at`, and any per-message `message-expires-at`) MUST be expressed in Stacks `burn-block-height`.

Subject binding requirement: runtime authorization MUST have an unambiguous rule for which `subject` is being authorized.

Implementations MUST choose one of these patterns:

- **Registry-derived subject (preferred when possible)**: the registry can be queried by `pubkey` to return a single `subject` principal (single-subject-per-key), and contracts use that `subject` for authorization.
- **Signed subject**: `subject` is included inside the signed message preimage, and the contract compares that signed subject against the function’s `subject` argument before authorization.

In both patterns, contracts MUST assert that the enclave pubkey is registered/authorized for the subject being exercised (for example, via `is-authorized-pubkey subject pubkey ...`) and MUST reject if the registry does not affirm that `(subject, pubkey)` binding.

Arbitrary caller-supplied `subject` values without one of these bindings are forbidden.

Uniqueness requirement: when using the registry-derived subject pattern, the registry MUST enforce at-most-one `subject` per `pubkey`. Attempting to register the same `pubkey` to a different `subject` MUST either fail or require explicitly revoking the previous mapping first.

Note: when the registry-derived subject pattern is used and the contract derives `subject` by looking up the `pubkey` in the registry, it is not required to redundantly include `subject` again in the signed preimage.

Revocation requirement: runtime authorization MUST fail if the registry marks the key as revoked (for example, `revoked-at` is `some`), even when `expires-at` is in the future.

Key validity requirement: the registry `expires-at` field is the key lifetime bound. Contracts MUST enforce it independently of any per-message TTL.

Key expiry bound requirement: when registering a key, `expires-at` MUST NOT exceed the validated attestation/identity validity window for that key, and extending a key’s lifetime MUST require a fresh attestation and re-registration.

`tier` is an on-chain policy input derived from off-chain attestation (for example: `L3 StrongBox` vs `L2 CloudTEE`). It is not the attestation evidence itself.

### 5.2 Who is allowed to register keys

Registration MUST be restricted to a protocol authority that is anchored on-chain (for example, a principal stored in `operational-treasury.clar` under a protocol principal name).

Reason: since full attestation verification is off-chain, key registration is the “bridge” point, and must be auditable and revocable.

### 5.3 Enrollment steps

1. Client generates or selects an enclave key.
2. Client obtains attestation evidence for that key (platform-specific).
3. A verifier (Gateway / identity service) validates the evidence off-chain and assigns a tier + expiry.
4. The verifier submits an on-chain registration call to the registry contract.

## 6) Runtime authorization flow (relayed intent execution)

This is the core “enclave-backed client into Clarity” flow.

### 6.1 High-level sequence

```
Client (enclave)          Gateway (relayer)                   Clarity contract

  1) Build canonical request
  2) message = sha256(...)
  3) signature = sign(message)
  4) send {message, sig, pubkey, payload}
                             5) submit tx with payload + proof  --->
                                                               6) secp256k1-verify
                                                               7) check pubkey authorized + unexpired
                                                               8) anti-replay (consume message_hash/event_id)
                                                               9) execute or (err ...)
```

### 6.2 On-chain verification checklist (normative)

For any Clarity public function that accepts an enclave-backed proof, the contract MUST:

0. **Bind the signed `message` to the payload actually used**
   - Recompute `payload-hash` from the payload bytes/fields the contract will execute.
   - Derive (or validate) `message'` from that `payload-hash` (and any required domain separation / subject / action / anti-replay fields).
   - `(asserts! (is-eq message message') (err ERR_MISMATCHED_PAYLOAD))`
   - All subsequent verification steps MUST use `message'` rather than the raw caller-supplied `message`.
1. **Verify signature**
   - `(asserts! (secp256k1-verify message' signature pubkey) (err ERR_INVALID_SIGNATURE))`
2. **Verify key authorization**
   - `(asserts! (is-authorized-pubkey subject pubkey ...) (err ERR_UNAUTHORIZED))`
3. **Verify freshness**
   - Enforce key lifetime (`expires-at`) from the registry, and reject if expired.
   - For protected actions, implementations SHOULD also include a per-message expiry (`message-expires-at`) in the signed preimage and reject if expired.
     - If used, `message-expires-at` MUST be an explicit on-chain input (argument or derivable field) that is bound into `message'`.
4. **Verify anti-replay**
   - Store and consume a scoped replay key that includes an identity dimension (at minimum `subject` or `pubkey`), for example: `{ subject, action, message' }` or `{ subject, event_id }`.
   - Contracts MUST NOT key replay protection on `event_id`/`message'` alone as a global replay map.
   - Reject if already consumed.

Pruning guidance: replay entries SHOULD store minimal timing metadata (for example, `consumed-at` and/or `expires-at`) so pruning cannot reopen replay windows. Pruning is only safe once `burn-block-height` is beyond the relevant expiry window.

If any required input is missing (no registry entry, missing expiry, etc.), the contract MUST fail closed.

### 6.3 Relayer identity

Contracts MUST treat `tx-sender` as a relayer in this flow.

- Authorization is derived from the signature + registry, not from `tx-sender`.
- If relayer restrictions are needed (for example, only Gateway may relay certain calls), that is a separate policy check and MUST NOT replace signature verification.

## 7) Fallback and recovery behavior

Enclave-backed authorization is the default for protected actions. Fallbacks exist only to preserve liveness under strict governance, and MUST be explicit.

Normative requirements:

- **No silent downgrade**: if enclave verification fails, execution MUST NOT proceed under a weaker check.
- **Fail closed by default**: missing attestation tier, missing registry entry, expired keys, or unverifiable signatures MUST reject.
- **Recovery is a separate path**:
  - Key rotation / re-enrollment MUST be handled by an explicit recovery workflow (for example: time-locked governance or emergency multi-sig), not by bypassing verification in the primary code path.

## 8) What remains off-chain (by design)

The following MUST remain off-chain:

- Vendor certificate chain validation and root-of-trust enforcement for device integrity.
- WebAuthn / passkey attestation verification.
- Platform-specific policy evaluation (OS version checks, device posture scoring, device allowlists/denylists).
- Any PII-bearing identity checks.

The on-chain system only consumes the derived, minimal, deterministic artifacts it can verify: `(buff 32)` message hashes, `(buff 65)` signatures, `(buff 33)` pubkeys, and registry state.

## 9) Notes for implementation planning

- Align all Clarity interfaces that claim to verify “passkey” or “enclave” signatures to the `secp256k1-verify` shape: `message (buff 32)`, `signature (buff 65)`, `pubkey (buff 33)`.
- Avoid patterns that accept `pubkey`/`signature` without also enforcing allowlisting/registry constraints; signature verification alone does not express *who* is allowed.
