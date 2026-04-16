# Signed Event Envelope v1 (CON-472)

This document defines transport-independent, public-safe message formats for:

- `OracleReportV1`
- `TelemetryEventV1`

It also defines canonical serialization, hashing, signature-suite requirements, and a verification checklist that Nexus/collectors can implement.

ZSE note: payloads MUST be public-safe. Secrets MUST NOT appear in plaintext; they are represented only as commitments/hashes.

## 1) Goals and non-goals

Goals:

- Define deterministic (canonical) bytes to hash/sign, independent of transport (Nostr, HTTP, file, etc.).
- Support a primary Schnorr signature suite compatible with Nostr-style keys (BIP-340 over `secp256k1`).
- Optionally support an on-chain-verifiable signature suite for Stacks (`secp256k1-verify` / ECDSA), when user-submitted oracle updates are required.
- Provide explicit freshness and anti-replay semantics that can be enforced by collectors.

Non-goals:

- Key ceremony, signer identity procedures, and any operational allowlist management system of record.
- Transport-level auth (TLS/mTLS), which may still be required by deployments.

## 2) Canonical serialization and hashing

All hashing and signing in this spec is defined over a canonical byte representation.

### 2.1 JSON canonicalization

When hashing or signing any JSON object in this spec, implementations MUST use the JSON Canonicalization Scheme (RFC 8785 / JCS):

- UTF-8 encoding
- Object keys lexicographically sorted
- Deterministic number and string formatting per JCS

We refer to the JCS output bytes as `JCS(obj)`.

### 2.2 Hash function

Unless otherwise specified, the hash function is:

- `SHA-256(bytes)`

### 2.3 Encoding

All binary fields in JSON MUST be lowercase hex strings with no `0x` prefix.

## 3) Common envelope model

Both `OracleReportV1` and `TelemetryEventV1` share the same signed envelope model.

### 3.1 Publisher identity

`publisher` is the logical signer identity used for allowlists and replay protection. In v1 it is defined as an x-only `secp256k1` public key (32 bytes, hex) compatible with BIP-340.

### 3.2 Payload hash

`payload_hash` binds the payload contents without forcing all suites/transports to sign raw (potentially large) payload bytes.

Computation:

1. `payload_bytes = JCS(payload)`
2. `payload_hash = SHA-256(payload_bytes)`

### 3.3 Signing root and event id

Signatures in this spec cover a `signing_root` object (not the full message). The `signing_root` excludes `payload` and all signature fields; it includes `payload_hash`.

`signing_root` fields:

- `v` (number)
- `kind` (string)
- `publisher` (string, x-only pubkey hex)
- `created_at` (number, Unix epoch seconds)
- `expires_at` (number, Unix epoch seconds; optional)
- `created_height` (number, Stacks block height; optional)
- `expires_height` (number, Stacks block height; optional)
- `sequence` (string; optional)
- `payload_hash` (string, 32-byte hex)

Computation:

1. `signing_bytes = JCS(signing_root)`
2. `event_id = SHA-256(signing_bytes)`

`event_id` MUST be included in the message for dedupe/indexing and to make it unambiguous what was signed.

### 3.4 Freshness and anti-replay fields

- `created_at` is required.
- `expires_at` is optional but RECOMMENDED for oracle reports and any telemetry used for billing, accounting, or policy enforcement.
- `created_height` / `expires_height` are optional and MAY be used as a Stacks-anchored freshness window when collectors have authoritative chain height.
- `sequence` is optional but RECOMMENDED for billing-critical telemetry.

`sequence` format:

- A base-10, non-negative integer string.
- Intended to be parsed as `uint64` / BigInt.
- Monotonically increasing per `(publisher, kind, subject)` under a deployment-defined subject key (see section 6.2).

### 3.5 Allowlist model

Collectors MUST enforce an allowlist that binds:

- who (`publisher`)
- to what (`kind`, and optionally subject constraints)

The allowlist is out of band (policy registry, config, or on-chain registry). This spec defines only the message fields needed to enforce it.

## 4) Signature suites

Messages carry signatures in `sigs`. Multiple signatures MAY be provided.

All signatures MUST sign the raw 32-byte `event_id` bytes (not the hex string representation and not raw JSON).

### 4.1 BIP-340 Schnorr (`bip340-schnorr-secp256k1-sha256`)

Required for all v1 messages.

- `pubkey`: x-only `secp256k1` public key (32 bytes, hex). MUST equal the top-level `publisher`.
- `sig`: 64-byte Schnorr signature (hex) computed per BIP-340 with message = raw 32-byte `event_id`.

### 4.2 Stacks on-chain ECDSA (`stacks-secp256k1-ecdsa-sha256`)

Optional. Intended for deployments that want to accept user-submitted updates and verify them on-chain in Clarity.

- `pubkey`: compressed `secp256k1` public key (33 bytes, hex).
- `sig`: 65-byte recoverable ECDSA signature (hex) formatted as `r || s || v` (where `v` is the recovery parameter).
- message = raw 32-byte `event_id`.

Note: The Stacks pubkey MAY be derived from the BIP-340 x-only key, but v1 does not require a specific derivation.

## 5) Schemas

The schemas below are defined as normative field requirements, plus an informal TypeScript shape for implementers.

### 5.1 Shared types

```ts
export type Hex = string;

export type SignatureV1 =
  | {
      suite: 'bip340-schnorr-secp256k1-sha256';
      pubkey: Hex; // 32-byte x-only secp256k1 pubkey
      sig: Hex; // 64-byte schnorr signature
    }
  | {
      suite: 'stacks-secp256k1-ecdsa-sha256';
      pubkey: Hex; // 33-byte compressed secp256k1 pubkey
      sig: Hex; // 65-byte (r||s||v)
    };

export type SignedEnvelopeV1<Kind extends string, Payload extends Record<string, unknown>> = {
  v: 1;
  kind: Kind;

  publisher: Hex; // 32-byte x-only secp256k1 pubkey
  created_at: number; // Unix epoch seconds
  expires_at?: number; // Unix epoch seconds
  created_height?: number; // Stacks block height
  expires_height?: number; // Stacks block height
  sequence?: string; // uint64 decimal string

  payload: Payload;
  payload_hash: Hex; // 32-byte sha256
  event_id: Hex; // 32-byte sha256

  sigs: SignatureV1[];
};
```

### 5.2 `OracleReportV1`

`OracleReportV1.kind` MUST be `oracle.report.v1`.

`payload` MUST include:

- `feed_id` (string): stable identifier for the feed (examples: `fx.usd.zar`, `stx.usd`, `energy.kwh.spot`).
- `as_of` (number): Unix epoch seconds for the measurement time.
- `value` (string): decimal string (no floats) representing the reported value.
- `decimals` (number): number of decimal places implied by `value`.

`payload` MAY include:

- `unit` (string)
- `meta` (object): public-safe metadata (no secrets)
- `commitments` (object): commitment hashes (for ZSE), keyed by label

```ts
export type OracleReportPayloadV1 = {
  feed_id: string;
  as_of: number;
  value: string;
  decimals: number;

  unit?: string;
  meta?: Record<string, unknown>;
  commitments?: Record<string, Hex>; // label -> hash
};

export type OracleReportV1 = SignedEnvelopeV1<'oracle.report.v1', OracleReportPayloadV1>;
```

### 5.3 `TelemetryEventV1`

`TelemetryEventV1.kind` MUST be `telemetry.event.v1`.

`payload` MUST include:

- `subject` (string): stable subject key under the publisher (device id, workload id, node id).
- `event_type` (string): stable event type (examples: `heartbeat`, `throughput`, `latency`, `billing.usage`).

`payload` MAY include:

- `metrics` (object): values SHOULD be integers or decimal strings (avoid floats).
- `tags` (object): low-cardinality string tags.
- `commitments` (object): commitment hashes (for ZSE), keyed by label.

```ts
export type TelemetryEventPayloadV1 = {
  subject: string;
  event_type: string;

  metrics?: Record<string, number | string>;
  tags?: Record<string, string>;
  commitments?: Record<string, Hex>; // label -> hash
};

export type TelemetryEventV1 = SignedEnvelopeV1<'telemetry.event.v1', TelemetryEventPayloadV1>;
```

## 6) Verification checklist (reject if ...)

This checklist is the normative v1 behavior for collectors.

### 6.1 Basic structure

Reject if:

- `v` is not `1`.
- `kind` is unknown.
- `publisher` is not a 32-byte lowercase-hex string.
- `payload` is missing or is not a JSON object.
- `payload_hash` or `event_id` is missing or not a 32-byte lowercase-hex string.
- `sigs` is missing or empty.

### 6.2 Allowlist

Reject if:

- `(publisher, kind)` is not allowlisted.
- The allowlist defines a subject constraint and the message’s subject (deployment-defined key) does not match.

Deployment-defined subject key:

- For `oracle.report.v1`, subject SHOULD be `payload.feed_id`.
- For `telemetry.event.v1`, subject SHOULD be `payload.subject`.

### 6.3 Canonical hash and id

Reject if:

- Recomputed `payload_hash` != message `payload_hash`.
- Recomputed `event_id` != message `event_id`.

### 6.4 Signature verification

Reject if:

- There is no valid signature with `suite = 'bip340-schnorr-secp256k1-sha256'`.
- Any provided signature claims `pubkey` that does not match its suite’s required pubkey format.
- For the BIP-340 suite: the signature pubkey != top-level `publisher`.
- Any signature fails verification over message = `event_id`.

Collectors MAY ignore unknown signature suites (forward compatibility), but they MUST still require at least one valid BIP-340 signature.

### 6.5 Freshness and replay protection

Reject if:

- `created_at` is in the future beyond a deployment-configured clock-skew tolerance.
- `expires_at` is present and `expires_at <= created_at`.
- `expires_at` is present and `expires_at - created_at` exceeds a deployment-configured maximum TTL.
- `expires_at` is present and `now > expires_at`.
- `created_height` is present and is not a non-negative integer.
- `expires_height` is present and `expires_height <= created_height`.
- `expires_height` is present and the collector cannot verify Stacks chain height.
- `expires_height` is present and `stacks_tip_height > expires_height`.
- `sequence` is present and is not a base-10, non-negative integer string (no leading sign).

Replay protection rules:

- Dedupe: collectors MUST treat `event_id` as an idempotency key and ignore duplicates.
- Collectors MAY also maintain a recent-window dedupe cache keyed by `(publisher, kind, payload_hash)` as an additional replay defense.
- If `sequence` is present: collectors SHOULD store the maximum accepted `sequence` per `(publisher, kind, subject)` and reject any message with `sequence` less than or equal to the stored value.
- If `sequence` is not present: collectors SHOULD still enforce a bounded acceptance window using `created_at` and (if present) `expires_at`.

## 7) Transport notes (non-normative)

- Nostr: the envelope can be placed in the Nostr event `content` (or equivalent), but collectors MUST verify the envelope signature(s) defined in this spec and MUST NOT rely solely on transport-level signatures.
- HTTP/file queues: transport authentication and authorization MAY still be used, but must not replace envelope-level verification.
