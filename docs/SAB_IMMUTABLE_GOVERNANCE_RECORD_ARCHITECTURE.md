# SAB immutable governance and record architecture (CON-333)

This document defines where immutable, append-only, and policy-sensitive records live in the SAB target architecture.
It classifies governance record domains, establishes datastore boundaries with operational systems, and defines fail-closed behavior for policy-sensitive execution surfaces.

## Principles (non-negotiable)

1. **Stacks L1 is the canonical authority for enforceable governance state.** Any off-chain copy is a derived/indexed view.
2. **Derived datastores exist for query ergonomics, not correctness.** If a derived store is unavailable or fails validation, execution MUST halt (for policy-sensitive paths) or fall back to on-chain reads (for read-only UI/query paths).
3. **Append-only governance records MUST be content-addressed and provenance-carrying.** Every record MUST include an immutable `record_id` (content hash) and actor provenance (who/what authorized it).
4. **Zero Secret Egress (ZSE):** Governance datastores MUST NOT contain enclave-only secrets, signing keys, seed phrases, or private key material in any form.
5. **Legal and institutional content is indexed, not replicated.** The full text of privileged legal/institutional documents lives in Linear Virtual Office (or another approved protected store). The governance ledger stores only public-safe metadata, content hashes, and access pointers.
6. **Policy validation failures MUST fail closed.** No “best effort”, no inferred defaults, no degraded execution for writes.

### Record canonicalization and hashing

The `record_id` for any JSON-LD governance record MUST be computed deterministically to prevent “same semantics, different hash” failures across implementations.

- **Canonicalization:** JSON-LD RDF Dataset Canonicalization using **URDNA2015**.
- **Hash:** `sha256` over the canonicalized N-Quads bytes (UTF-8).
- **Digest encoding:** `record_id` is the raw 32-byte digest; when represented as text it MUST be encoded as lowercase hex (64 chars). The on-chain anchor MUST store the same 32-byte digest (or, if stored as text, the same lowercase-hex encoding).
- **Context resolution:** canonicalization MUST run with network fetch disabled; any JSON-LD contexts MUST be resolved from pinned, content-addressed artifacts.

## Target record planes

SAB target architecture separates (a) enforceable governance state, (b) append-only governance records, and (c) operational application state.

### Plane A: Canonical governance authority (Stacks L1)

These records are authoritative and MUST be discoverable by clients and agents directly from Stacks L1.

- Contract ownership and admin roles
- Governance parameter changes (fee rates, splits, timelock parameters)
- Key registry / authority registry (public keys, key IDs, attestation commitments)
- Audit/checkpoint registry (dataset checkpoints and content-hash anchors)

### Plane B: Append-only governance record ledger (Fluree)

**Decision:** Use Fluree as the queryable, append-only governance/audit ledger.

Fluree is used for:

- governance resolutions, voting records, and policy bundles as versioned JSON-LD
- audit trails for operator/agent actions (derived from on-chain + signed off-chain events)
- provenance graphs across policies, identities, controls, and evidence

Fluree is NOT used as a canonical authority. Every correctness-relevant record MUST be anchored on-chain by content hash (Plane A) and validated before use.

### Plane C: Operational application state (derived read models)

Operational application state (orders, sessions, dashboards, caches) remains separate from governance/compliance state.

- PostgreSQL (derived read model) for Nexus/Gateway query acceleration
- Supabase/hosted SQL surfaces are transitional and MUST NOT be correctness-critical
- Redis/SQLite are convenience caches only

## Governance record domains (classification)

The table below classifies governance record domains by immutability, retention, provenance, and datastore placement.
“Canonical anchor” refers to the on-chain record required to treat the record as valid at runtime.

| Domain | Examples | Immutability requirement | Canonical anchor (Stacks L1) | Off-chain record store | Retention | Query expectations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Governance decisions | Motions, votes, resolutions, ratifications | Append-only. Superseded via new records only. | Governance/audit registry entry containing `record_id` and effective block range | Fluree | Indefinite | Time-travel queries (policy at block-height X); trace decisions to affected policy bundles |
| Policy bundles (policy-as-code) | Allow/deny lists, thresholds, approval policies, spend tiers, emergency procedures | Append-only and versioned. Runtime MUST select policy by immutable digest. | Policy registry entry (hash + activation height) | Fluree | Indefinite | Fetch by digest; compute “effective policy” snapshot for a given height |
| Identity and authority bindings | DID registry links, key attestations (public), role bindings, signer set membership | Append-only. Revocations are additive records. | Key/authority registry contract entries | Fluree (derived view) | Indefinite | Graph queries: “who could sign what at height X?” |
| Control-plane manifests | Release-policy snapshots, deployment allowlists, contract manifests, artifact digests, submodule pins | Append-only. Must be content-addressed. | Audit registry anchor for manifest hash; on-chain contract ownership for enforcement | Fluree + Git (for public-safe manifests) | Indefinite | Diff manifests across versions; prove which artifact produced an on-chain change |
| Audit trails (agent/operator) | Signing requests, approvals, executions, policy denials, break-glass actions | Append-only. Redaction via additive “sealed” records only. | Audit/checkpoint registry entry for dataset roots and/or record hash anchors | Fluree (queryable) + derived exports | 7+ years minimum (or longer if mandated) | Multi-dimensional queries (actor, action type, contract, txid); point-in-time reconstruction |
| Compliance evidence indexes | Sanctions screening attestations, KYC status commitments, regulatory reports (metadata only) | Append-only. Must not store private inputs. | Audit registry anchor of evidence package hash | Fluree (metadata only) | 7+ years minimum | Evidence package discovery by hash, timeframe, and policy version |
| Legal/institutional indexes | Charter, bylaws, contracts, custodian agreements (metadata only) | Append-only metadata and content hash only; privileged content remains protected. | Audit registry anchor of content hash + pointer to canonical protected store | Fluree (metadata only) | Per legal retention; default 7+ years | Search by parties, effective dates, and referenced policy/decision |

## Data boundaries with operational systems

Operational systems may depend on governance records only through validated, read-only interfaces.

### Allowed interactions

1. **Read policy snapshots:** operational components may read policy bundles by digest and compute “effective policy” at a given Stacks block-height.
2. **Validate before execute:** any policy-sensitive write MUST validate policy digest and its on-chain anchor before signing or broadcasting a transaction.
3. **Emit audit events:** operational components MAY emit signed audit events into the governance ledger, but those events MUST NOT be treated as authoritative without anchors/checkpoints.

### Prohibited interactions

- Governance/policy decisions MUST NOT be stored in operational databases as canonical.
- Operational services MUST NOT “patch” missing governance state by using defaults, heuristics, or cached stale policy for writes.

## Immutable control surfaces (runtime-visible)

The following control-plane artifacts MUST be immutable to agents and operators at runtime (read-only, content-addressed, and validated):

- `policy_bundle_digest`: digest identifying the full policy bundle a component is running under
- `principal_map_digest`: role/principal bindings used to resolve dynamic principals at runtime
- `authority_set_digest`: signer sets and quorum definitions for SAB/DAO/Guardian actions
- `deployment_allowlist_digest`: which contracts/methods are allowed to be invoked by which agents
- `artifact_manifest_digest`: build artifacts (OCI image digests, binaries, WASM) pinned by digest
- `contract_manifest_digest`: contract IDs, versions, and any upgrade constraints
- `audit_checkpoint_scheme_id`: the canonical checkpoint scheme identifier (for dataset root validation)
- `break_glass_policy_digest`: explicit emergency halt/pause policy (including who can invoke it)

## Fail-closed governance behavior

Policy-sensitive execution surfaces MUST treat governance validation as a hard precondition.
If the precondition fails, the system halts rather than executing with degraded correctness.

### Required failure semantics (minimum)

| Component | Governance dependency | If policy cannot be fetched | If policy cannot be validated against L1 | If policy is stale (anchor height behind current) |
| :--- | :--- | :--- | :--- | :--- |
| Gateway (tx relay) | Deployment/tx policy bundle | Reject request (503) | Reject request (403/503) | Reject writes; allow read-only queries |
| Nexus (indexer) | Checkpoint scheme + dataset roots | Stop serving derived correctness-dependent reads; continue indexing if safe | Halt indexing and mark replica invalid until rebuilt | Continue indexing but flag replica “untrusted” until next validated checkpoint |
| Ops Orchestrator (automation loop) | Action allowlists + spend tiers | Do not execute jobs; surface “blocked by governance” | Do not execute; require operator intervention | Do not execute policy-sensitive jobs |
| Signing surface (TEE / secure element) | Signing policy + authority sets | Refuse to sign | Refuse to sign | Refuse to sign |

Notes:

- “Reject request (503)” is a service error, not a retry suggestion for policy-sensitive writes.
- The only safe degradation mode is **read-only** when no policy-sensitive execution can occur.

## Sandbox and isolation requirements

Governance and policy-sensitive execution surfaces require explicit isolation to prevent “policy drift” and unsafe fallback behavior.

### Fluree governance ledger isolation

- MUST run in a sovereign/self-hosted baseline (no hosted-only dependency for correctness).
- MUST be on a dedicated network segment.
- MUST expose separate **read** and **append** credentials.
  - Agents and operational services MUST be issued read-only credentials.
  - Append credentials MUST be restricted to a governance-ingress service under SAB/DAO control.
- MUST support append-only semantics at the application layer (no update/delete endpoints exposed to normal clients).

### Policy-sensitive execution sandbox

For any component that can sign, deploy, or move value:

- MUST run in an isolated execution boundary (TEE where required, otherwise container/VM).
- MUST pin control artifacts by digest (no mutable tags).
- MUST enforce outbound network allowlists.
- MUST treat the governance ledger as read-only.
- MUST separate “policy evaluation” from “execution” (no blended codepaths where fallback can occur).

### Protected record surfaces (legal/compliance)

- Privileged legal and institutional documents MUST remain outside runtime-accessible stores.
- Runtime agents MUST only see:
  - public-safe metadata
  - content hashes
  - “where to request access” pointers

## Readiness for implementation

This architecture is ready for a focused implementation phase when the following interfaces are treated as stable targets:

1. A minimal on-chain registry contract (or extension of the existing audit/checkpoint registry) that anchors governance record hashes and policy bundle digests.
2. A Fluree ledger schema that stores JSON-LD governance records and their links to on-chain anchors.
3. A shared `policy-gate` library that implements the fail-closed rules above and is used by Gateway, Nexus, Orchestrator, and signing surfaces.
