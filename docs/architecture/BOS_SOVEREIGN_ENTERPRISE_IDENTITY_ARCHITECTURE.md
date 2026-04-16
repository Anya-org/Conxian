# BOS sovereign enterprise identity architecture (CON-441)

This document specifies the BOS approach for **enterprise authentication** (humans and workloads) and **ERP session brokering** without relying on reusable centralized credentials.

ZSE note: this is a public-safe architecture. It defines trust primitives, interfaces, and security invariants, but avoids operational runbooks, concrete endpoints, and any secret material.

## 1) Goals and non-goals

Goals:

- **Hardware-backed enterprise identity**: all privileged enterprise actions are authenticated via device/workload keys held in secure hardware (TPM/TEE/HSM class).
- **Attestation-gated access**: access to BOS privileged surfaces requires a verifiable attestation chain that proves key origin + device/workload posture.
- **Short-lived sessions**: all online session credentials are short-lived, capability-scoped, and bound to proof-of-possession.
- **Enterprise policy integration**: preserve existing enterprise governance (SSO, group membership, conditional access) without turning the IdP into a long-lived credential issuer for BOS.
- **Strong operational recovery**: explicit revocation + rotation flows that map onto the protected-action state machine baseline.

Non-goals:

- Defining enterprise HR processes, employee lifecycle, or key-ceremony procedures.
- Specifying a single vendor/product for attestation verification.
- Replacing custody controls for value-bearing actions (see `docs/protocols/ENTERPRISE_CUSTODY_BASELINE.md`).

## 2) Design principles (invariants)

1. **No bearer tokens for privileged surfaces**
   - Any session credential that can reach privileged tools MUST be bound to proof-of-possession via mTLS or a DPoP-style request signature.

2. **Attestation is evaluated before issuing sessions**
   - If attestation cannot be verified or is inconsistent, issuance MUST fail closed.

3. **Enterprise IdP is an input, not the root of trust**
   - SAML/OIDC assertions can contribute claims (who/role), but BOS sessions must still be bound to an attested hardware key (what/where).

4. **Capability-scoped sessions only**
   - There is no “enterprise admin token.” Sessions must carry explicit capability scopes aligned with BOS capability domains.

5. **Recovery is a protected action**
   - Any rotation/revocation that changes effective authorization MUST follow quorum + time-lock requirements.

## 3) Actors and components

### Actors

- **Operator (human)**: uses Conxius Wallet or an enterprise-managed device to approve/authorize BOS actions.
- **ERP workload**: SAP / Oracle ERP and its enterprise AI agent surfaces (tool calling / job execution).
- **BOS privileged services**: MCP server, intent adapters, orchestration services, signing request routers.

### Components (identity plane)

- **Attestation Verifier**: verifies device/workload attestation evidence and extracts claims about key origin + posture.
- **Enterprise Policy Adapter**: integrates enterprise policy signals (SSO, group membership, device compliance) as _inputs_ to authorization.
- **Session Broker (capability issuer)**: issues short-lived, capability-scoped BOS session credentials that are proof-of-possession bound.
- **Revocation Registry**: supports rapid invalidation of device/workload identities and outstanding sessions.

### Components (execution plane)

- **BOS Orchestrator**: evaluates policy, builds requests, and routes to signer boundaries.
- **Signer boundaries**: SAB custody and authority signers (out of scope here; see `docs/BOS_WALLET_CONTROL_MODEL.md`).

## 4) Identity primitives

### 4.1 Hardware-backed key pair

Each enterprise device/workload that needs BOS access MUST provision one or more key pairs such that:

- device identity and approval/signature keys have private key material that is non-exportable and held in TPM/TEE/HSM-class hardware
- session binding keys are hardware-backed and non-exportable for any session that can reach privileged/write BOS surfaces; for explicitly non-privileged, read-only surfaces, session binding keys MAY be software-backed if they are minted inside a hardened boundary and are never reused for higher-privilege BOS surfaces
- the public key becomes a stable, non-reassignable identifier for this device/workload, used for replay protection and per-device risk controls; authorization policy and revocation are keyed on the canonical BOS principal that binds to one or more such device/workload keys

Key purposes are separated:

- **device identity key**: proves “this device/workload”
- **session binding key**: binds online sessions to proof-of-possession
- **approval/signature key**: used only for explicit approvals (for example, signing an intent mandate)

Key acceptance surfaces MUST be disjoint:

- approval/signature keys MUST NOT be accepted for session establishment or generic BOS API authentication
- session binding keys MUST NOT be accepted for value-bearing approvals or other protected actions
- device identity keys MUST NOT be accepted for interactive approvals

At minimum, device identity, session binding, and approval/signature keys MUST be distinct key pairs (even if stored in the same secure element). They MUST have disjoint acceptance surfaces and policy lanes, even though they all resolve to the same canonical BOS principal anchored in the device/workload identity key.

### 4.2 Attestation evidence

For any device/workload requesting BOS session credentials, the attestation verifier MUST validate:

- key origin in secure hardware
- a freshness signal (challenge/nonce)
- posture claims required by policy (for example, “device is enterprise-managed”, “workload runs in a TEE-class boundary”)

The verifier emits a **Device/Workload Identity Record**:

- subject public key (device/workload identity key)
- attestation type + verifier policy version/hash
- issued-at and expiry
- posture claims (public-safe subset)
- a verifier signature over the record

Implementations MUST enforce a maximum accepted age for a Device/Workload Identity Record. For privileged/write surfaces this age MUST NOT exceed 24 hours and SHOULD be 12 hours or less. The session broker MUST reject records older than this limit and require fresh attestation, even if the record’s own expiry has not been reached. Policy changes (for example, a new verifier policy version/hash) MAY also force re-attestation according to enterprise policy.

### 4.3 Enterprise policy signals

Enterprise SSO (OIDC/SAML) and provisioning (SCIM) are used to supply:

- user identity (for interactive sessions)
- group membership / role assignment
- conditional access decisions (where available)

These signals MUST be treated as time-bound inputs and must not become reusable BOS credentials.

The session broker MUST only issue sessions when enterprise policy signals are explicitly bound to the attested subject key in an auditable way. Implementations MUST NOT combine enterprise claims from one context with attestation evidence from an unrelated key.

The session broker SHOULD reject enterprise policy inputs (for example, IdP assertions or cached SCIM group membership) that are older than a deployment-defined maximum age. As a guideline, IdP assertions should be bounded to minutes (for example, 5–15 minutes).

## 5) Session brokering model

The session broker issues one of the following proof-of-possession-bound session forms:

1. **mTLS client identity** (recommended for service-to-service and ERP connectors)
   - broker mints a short-lived client certificate for a dedicated session binding key that is itself attested, or whose certificate carries an explicit binding to the device/workload identity key (for example, a custom extension that contains the device/workload identity key hash). The TLS key pair MUST NOT be the same as the device identity key or any approval/signature key, and device identity/approval keys MUST NEVER be used directly for TLS. Where the platform supports it, the TLS private key MUST be non-exportable and hardware-backed (TPM/TEE/HSM class). If a deployment uses a software TLS key, it MUST conform to the session binding key exception described in section 4.1 and MUST NOT be used for the highest-privilege BOS surfaces.

2. **PoP token** (recommended for browser/mobile clients)
   - broker issues a short-lived token whose requests must include a per-request signature with the bound key
   - the bound key MUST be hardware-backed and non-exportable per section 4.1 (for example, WebAuthn/FIDO or OS keystore-backed keys), not JS-managed or exportable keys; it MUST be the dedicated session binding key and MUST NOT be used as an approval/signature key for protected actions

The session broker MUST cryptographically bind the PoP-bound session key to the principal’s Device/Workload Identity Record (for example, by including the identity-record identifier or device/workload identity key hash in token claims and validation logic).

Session properties (normative defaults):

- TTL: MUST NOT exceed 15 minutes for sessions that can reach privileged BOS surfaces (implementations SHOULD target 5–15 minutes); longer TTLs MAY be used only for explicitly non-privileged, read-only surfaces under documented enterprise policy
- Read-only TTL: MUST still be finite (as a guideline, 1 hour or less); any revocation-cache TTL used for read-only degraded modes MUST be shorter than the read-only session TTL
- Audience-bound: tokens/certs are issued for a specific BOS service surface
- Scope-bound: explicit capability scopes (no implicit admin)
- Replay-resistant: per-request nonce or signed request binding

Issuance MUST fail closed if any of the following cannot be verified:

- attestation validity and freshness
- enterprise policy inputs (when required)
- allowlist membership for the subject principal (and, where policy requires, the specific device/workload identity key)
- requested capability scopes vs policy

The session broker MUST derive a canonical BOS principal from:

- the attested subject public key and its Device/Workload Identity Record
- current enterprise policy signals (when required for the session type)

Session issuance MUST be conditioned on a configured binding between these elements (for example, `user_id ↔ device_key` or `workload_id ↔ device_key`), and that binding MUST be recorded in an immutable audit trail.

Creation, modification, or removal of the binding between a BOS principal and a device/workload identity key MUST be treated as a protected action under `docs/protocols/ENTERPRISE_CUSTODY_BASELINE.md`.

The canonical BOS principal is a subject-level identifier (human operator or workload) that is bound to one or more Device/Workload Identity Records. Each Device/Workload Identity Record contributes one attested device/workload identity key for that principal. Session binding keys (mTLS client keys and PoP keys) are proof-of-possession carriers that MUST be cryptographically bound to a specific principal via their associated Device/Workload Identity Record. Allowlists, capability scopes, and audit trails MUST be keyed on the subject principal identifier, not on ephemeral session keys.

Revocation entries MAY target a specific device/workload identity key or Device/Workload Identity Record, but every revocation entry MUST record the associated principal and MUST NOT treat the device key as an independent principal.

Device identity, session binding, and approval/signature keys are credentials for a canonical BOS principal. They MUST be mapped back to that principal and MUST NOT be treated as independent principals.

Canonical BOS principals SHOULD be modeled explicitly as one of:

- **Human operator principal**: bound to an enterprise user identifier plus one or more attested device/workload identity keys.
- **ERP connector workload principal**: bound to an ERP system identifier plus an attested connector device/workload identity key.
- **Headless automation principal**: bound to a non-human workload identifier plus an attested device/workload identity key.

Principal identifiers MUST be globally unique within a BOS deployment and MUST NOT be reused for different subjects.

Subject device/workload identity keys MUST NOT be reassigned to a different BOS principal over their lifetime. If a device or workload is reprovisioned or reassigned, it MUST generate new keys and establish a new binding.

Multi-day or indefinite refresh credentials are not permitted for privileged BOS surfaces. Session renewal MUST require fresh attestation at least once per deployment policy interval (and never less frequently than the maximum accepted identity-record age window), and interactive sessions MAY additionally require enterprise IdP re-authentication per policy. If a deployment supports any renewal artifact, it MUST be a hardware-backed proof-of-possession credential that is audience-limited to the session broker only and is never accepted directly by BOS privileged services. Any renewal artifact MUST have a short TTL (for example, 1 hour or less) and MUST have a maximum lifetime less than or equal to the maximum accepted Device/Workload Identity Record age.

## 6) ERP and enterprise flows

### 6.1 Operator interactive session (human-in-the-loop)

Use case: an operator needs to approve an intent mandate originating from ERP.

1. Operator authenticates to enterprise IdP (SSO).
2. Operator device proves possession of the attested session binding key associated with its Device/Workload Identity Record (per sections 4.1–4.2), not the approval/signature key.
3. Session broker issues a short-lived operator session scoped to an approval surface.
4. Operator reviews an intent mandate and produces an explicit approval signature (for example, via Conxius Wallet secure hardware).
5. BOS services accept the approval only when:
   - the mandate signature is valid
   - the operator session was valid _and_ PoP-bound at the time the approval was issued
   - policy checks pass

Approval signatures MUST be over a structured payload that includes, at minimum:

- the mandate hash (or mandate payload hash)
- the canonical BOS principal identifier derived by the session broker
- a freshness field (timestamp + expiry and/or a broker-issued nonce)

BOS services MUST reject approvals where any of these bindings do not match the approval challenge and session context recorded by the broker at the time the approval was issued (even if the interactive session has since expired).

Approval signatures for value-bearing actions MUST NOT be accepted more than 15 minutes after their embedded timestamp/expiry and MUST be rejected immediately if the associated principal, device/workload identity key, or identity record has been revoked.

Approval/signature keys used for mandate approvals MUST be hardware-backed, enrolled for the canonical BOS principal, and explicitly authorized for that principal’s approval capability scope. BOS services MUST verify that the signing key is authorized for the claimed principal (not just that the signature is structurally valid).

### 6.2 ERP-to-BOS (MCP tool call) session

Use case: SAP/Oracle tool calling (`authorize_intent`) requires a session without storing reusable secrets.

1. ERP connector workload runs in an enterprise-managed boundary (TPM/TEE/HSM-class).
2. Connector presents attestation evidence to the session broker.
3. Broker issues a short-lived, PoP-bound session credential scoped to the MCP surface.
4. ERP tool call is executed under that session.
5. The resulting intent mandate is treated as a protected action input:
   - it is signed/approved by the required parties
   - it is executed only through BOS orchestrated workflows

This integrates with the existing ERP handshake model described in `docs/ERP_MCP_HANDSHAKE_SPEC.md`, but replaces any implicit “shared secret to call MCP” assumption with attested session brokering.

ERP connectors that call BOS MCP (or any privileged BOS surface) MUST NOT hold long-lived BOS credentials (static API keys, shared secrets, or non-expiring tokens). All BOS calls from ERP MUST be mediated via short-lived, attested, proof-of-possession-bound sessions issued by the session broker.

Horizontally-scaled ERP connector clusters MUST either:

- share a BOS-facing key that remains non-exportable inside a centralized HSM/TEE boundary (application instances may invoke cryptographic operations via that boundary, but must not load, cache, or distribute private key material), or
- provision a distinct device/workload identity key per instance so compromise and revocation can be localized

Distributing a single private key into multiple application instances or configuration stores is not permitted.

Deployments that choose the centralized HSM/TEE option MUST treat the shared BOS-facing key as a single connector principal (shared blast radius across instances) and SHOULD prefer per-instance device/workload identity keys for high-privilege BOS surfaces where localized compromise and revocation are required.

### 6.3 Headless enterprise workload session (non-human)

Use case: an enterprise-controlled automation (not a human) needs to call BOS.

1. Workload identity key is provisioned in secure hardware.
2. Workload attestation is verified.
3. Broker issues a short-lived workload session scoped to a single capability domain.
4. Every request is PoP-bound (mTLS or request-signature).

## 7) Revocation and recovery

Revocation and recovery MUST map to the protected-action and recovery baselines in `docs/protocols/ENTERPRISE_CUSTODY_BASELINE.md`.

### 7.1 Revocation

Revocation targets:

- subject public keys (device/workload identity keys for a given BOS principal)
- Device/Workload Identity Records (to revoke unsafe posture independently of the underlying key, while still binding to the principal)
- verifier policy versions (if an attestation root is compromised)
- sessions issued under a compromised subject principal

Revocation MUST be enforceable at the session broker and at BOS service boundaries (defense in depth).

When a Device/Workload Identity Record is revoked due to unsafe posture, the session broker MUST treat that record as permanently invalid. Fresh attestations from the same subject key MAY result in a new Device/Workload Identity Record only if the subject key itself has not been revoked and the attested posture satisfies the current verifier policy version/hash. Issuing a new record for a high-privilege principal SHOULD require explicit policy approval.

At minimum:

- the session broker MUST check revocation status on every session issuance and on every session validation request it handles
- the session broker MUST reject any identity record marked as revoked, even if the corresponding subject key is not revoked
- BOS privileged services MUST enforce revocation either by consulting the revocation registry on each request, or by honoring a strict maximum revocation-cache TTL that is shorter than the maximum session TTL

If the revocation registry or attestation verifier is unavailable or returns an indeterminate result, the session broker and BOS privileged services MUST fail closed for privileged/write surfaces (rejecting session issuance and validation). Read-only surfaces MAY operate under a bounded cached view of revocation state when the registry is temporarily unavailable, subject to enterprise policy and with clear audit logging.

When revocation or attestation checks are indeterminate, the session broker MUST NOT issue new sessions that can reach privileged/write BOS surfaces. Deployments MAY, under explicit enterprise policy and with immutable audit logging, allow the session broker to issue sessions constrained to explicitly read-only scopes using a bounded cached view of revocation state; otherwise, all session issuance MUST fail closed until revocation and attestation checks are healthy again.

Implementations MUST treat network connection failures, DNS errors, timeouts, non-2xx HTTP responses, and parse/validation errors from the revocation registry or attestation verifier as indeterminate results. For privileged/write surfaces, only an explicit, positively authenticated “not revoked” response may be treated as sufficient to proceed.

For sessions validated via online introspection (for example, opaque tokens), the session broker acts as the validation authority. For self-contained sessions validated directly by BOS services (for example, PoP tokens or mTLS client certs), those services MUST perform equivalent revocation checks against the revocation registry (or via a cache with TTL strictly shorter than the maximum session TTL) and MUST NOT treat locally-validated sessions as exempt from the global revocation model.

### 7.2 Recovery and rotation

Any operation that changes effective enterprise authorization (for example, onboarding a new attestation root, rotating an enterprise capability issuer key, or unblocking a locked identity plane) MUST be treated as a protected action with:

- quorum approval
- time-lock where required by policy
- immutable audit records bound to payload hash + policy hash

Minimum recovery scenarios and invariants:

- **Lost or compromised operator device**: revoke the affected Device/Workload Identity Record and any active sessions; binding a new device/workload identity key to the operator principal MUST be executed as a protected action and MUST NOT silently override prior revocations.
- **Suspected ERP connector / automation compromise**: revoke the connector principal’s device/workload identity key and sessions immediately; if continued operation is required, provision a new connector principal or new device/workload identity key under protected-action controls before re-enabling BOS access.
- **Attestation root / verifier policy rotation**: treat verifier policy version/hash updates as protected actions; after rotation, session issuance MUST require fresh attestation under the new policy, and previously-issued identity records SHOULD be re-evaluated or revoked according to policy.

## 8) Integration points with BOS message-level security

Session authentication should not be the only line of defense.

For BOS-to-BOS messaging and evidence capture:

- payloads SHOULD be signed using `docs/protocols/SIGNED_EVENT_ENVELOPE_V1.md`
- services SHOULD enforce freshness/anti-replay fields (timestamps, expiry, sequence) and publisher allowlists

This allows transport authentication (mTLS/PoP tokens) to be treated as a narrow “session establishment” layer rather than a permanent authorization mechanism.

## 9) Open questions (need decisions)

1. Do we standardize on mTLS (client certs) for ERP connectors, or do we allow PoP tokens for SAP/Oracle integrations where mutual TLS termination is hard?
2. What is the minimum attestation posture required for “ERP connector” classification (TPM-only vs TEE-class)?
3. Where should allowlist and capability mapping live long term (policy registry vs on-chain registry), and what is the canonical policy hash/version format?
