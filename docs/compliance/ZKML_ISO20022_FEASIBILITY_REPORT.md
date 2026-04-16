# ZKML & ISO 20022 Compliance Feasibility (CON-467)

This report assesses whether privacy-preserving proof workflows (including zkML) can satisfy institutional requirements that are commonly expressed as “ISO 20022 compliance” in the Conxian model.

## Executive summary

- **ISO 20022 is a message standard, not a compliance standard.** Feasibility depends on (a) whether we can render ISO 20022-conformant messages from Conxian’s canonical datasets and (b) whether we can provide institution-grade evidence for AML/KYC/sanctions controls without public disclosure.
- **ISO 20022 rendering over verifiable datasets is feasible now** using Conxian’s existing “Glass Node / checkpoint-verified datasets” direction.
- **Privacy-preserving compliance evidence is feasible in a hybrid model**:
  - keep full ISO 20022 payloads (and other PII-bearing artifacts) **off-chain** as encrypted objects,
  - anchor binding-and-hiding commitments for identity-bearing inputs (not plain hashes) plus payload digests for ISO payload bytes,
  - provide **attestation and/or ZK proofs** about policy checks.
- **zkML is not required for an ISO 20022 pilot** and is unlikely to be the critical path. zkML becomes relevant only if a pilot explicitly requires verifiable ML inference (for example, “prove this model scored this transaction below a threshold”) rather than rule-based checks.

## Scope and definitions

### What “ISO 20022 compliance” usually means in institutional conversations

Institutions often use “ISO 20022 compliance” as shorthand for a bundle:

1. **Schema conformance**: messages validate against the right ISO 20022 XSD and follow implementation guidelines for a given rail (e.g., message family selection, required fields, code sets).
2. **Semantic correctness / reconciliation**: message data reconciles to settlement logs, postings, and audit trails.
3. **Regulatory controls**: AML/KYC/sanctions checks and traceable evidence.
4. **Privacy / confidentiality**: counterparty identity and account data are protected, with authorized disclosure paths.

### What “zkML” means in this context

For this report:

- **zkML** means “verifiable ML inference,” where a prover produces a ZK proof that a model inference was run correctly on particular inputs (usually committed inputs), yielding an output (risk score / classification) without revealing the raw inputs.
- It does **not** mean “AI used somewhere in the workflow.”

## Conxian constraints and existing direction

The repo already encodes key constraints that strongly shape feasibility:

1. **Institutional egress is read-only and proof-carrying** (datasets are derived, checkpointed, and verifiable).
   - See: [`sovereign-data-migration-institutional-egress` spec](../../openspec/changes/sovereign-data-migration-institutional-egress/specs/sovereign-data-migration-institutional-egress/spec.md).
2. **TradFi payloads are not execution authority; ingestion is proposal-only and verified inside a TEE**.
   - See: [`external-settlement-proposal-only-tee` spec](../../openspec/changes/external-settlement-proposal-only-tee/specs/external-settlement-proposal-only-tee/spec.md).
3. **Fail closed**: functional stubs (including ZKML) must return explicit errors in production paths.
   - See: [`docs/BRANCHING_AND_PROMOTION_POLICY.md`](../BRANCHING_AND_PROMOTION_POLICY.md).
4. **No secret egress / no private identity disclosures in egress datasets**.
   - This is compatible with ISO 20022 only if identity-bearing fields are handled via an authorized disclosure channel (encrypted payloads + selective disclosure), rather than being emitted into public/general-purpose “egress datasets.”

## Feasibility: privacy-preserving proofs + ISO 20022

### A workable decomposition

To make feasibility concrete, split the problem into four layers:

1. **Canonical truth**: Stacks L1 events/state.
2. **Verifiable derived datasets**: Nexus produces deterministic snapshots with on-chain checkpoints.
3. **Message rendering**: Gateway renders ISO 20022 messages from derived datasets (or from a deterministic renderer over a snapshot).
4. **Compliance evidence**: separate artifacts prove/attest policy checks.

This decomposition keeps ISO 20022 as a rendering concern and keeps “compliance checks” as evidence artifacts. That separation matters because ISO 20022 schemas do not solve AML/KYC evidence.

### ISO 20022 rendering: feasible with deterministic mapping + versioning

ISO 20022 rendering is feasible if we treat it as:

- a deterministic function:
  - input: a versioned canonical dataset record (or set of records) + a versioned mapping profile
  - output: ISO 20022 payload bytes (XML) + deterministic digest(s)
- with stable versioning:
  - dataset schema version
  - mapping profile version
  - message family/version selection (e.g., which `pacs.*` variant)

Key feasibility enablers already exist in OpenSpec:

- deterministic field naming + deterministic mappings for message formats,
- checkpoint verification that lets third parties validate snapshot integrity.

### Privacy-preserving compliance evidence: feasible, but requires an explicit private artifact lane

Institutional compliance is typically identity-heavy (names, addresses, account identifiers, screening results). Given the “no private identity disclosures in egress datasets” constraint, the likely pattern is:

1. **Store ISO 20022 payloads as encrypted objects** in an authorized storage plane.
2. **Expose only commitments and minimal identifiers** in verifiable datasets.
3. Provide **selective disclosure** paths for authorized verifiers (institutions, auditors, regulators), where they can obtain:
   - the decrypted ISO 20022 payload, and
   - a proof bundle that binds the payload to checkpointed datasets / on-chain anchors.

ISO 20022 rendering for the pilot should be treated as a **private service** that has access to full, non-public identity-bearing inputs. Public/verifiable egress datasets may only contain commitments to these payloads (and other non-PII linkage identifiers) and **must not** store raw identity-bearing ISO 20022 fields.

Note: plain hashes of PII (names, account identifiers, etc.) are generally linkable and are not sufficient as a privacy mechanism. For identity-bearing fields, the pilot should use a binding-and-hiding commitment construction (or an equivalent keyed commitment scheme) rather than emitting raw hashes.

Proof bundle options:

- **TEE attestation (near-term)**
  - Best aligned with the current external settlement trigger direction.
  - Attestation can bind:
    - payload hash
    - canonicalized “normalized settlement tx” hash
    - policy version identifiers
    - screening outcomes (as structured claims, not bare booleans)
- **ZK proofs for rule checks (medium-term)**
  - Good fit when policy checks are arithmetic/boolean constraints over committed inputs.
  - Lets external parties verify compliance without learning underlying PII.
- **zkML for screening/risk scoring (high-risk/longer-term)**
  - Potential fit if institutions require “prove the ML scoring happened exactly as specified.”
  - Often expensive in prover time and circuit size; model updates introduce governance complexity.

### zkML feasibility notes (what is and is not realistic for a pilot)

zkML tends to become feasible only under constraints that are often acceptable for a pilot, but not for general-purpose compliance:

- **Small models only** (logistic regression, small MLPs, small trees), usually quantized.
- **Stable, versioned model weights** (model updates are governance events).
- **Clear public output** (risk score threshold, category) and clear privacy boundaries for inputs.
- **Acceptable latency/cost**: proof generation must fit within operational SLAs.

If a pilot requires sanctions screening against large lists or large transformer-based models, zkML is unlikely to be the correct first move.

## Pilot recommendation (business + technical + verification constraints)

### Pilot goal

Demonstrate “institution-grade ISO 20022 outputs + verifiable linkage to Conxian truth” without putting identity data on-chain.

### Proposed pilot phases

#### Phase 1: ISO 20022 egress rendering over checkpointed datasets

Deliverables:

- Select 1–2 message families to support (example scope: a single credit transfer family + a statement/reporting family).
- Define a minimal canonical dataset schema for the pilot and a deterministic mapping profile.
- Implement deterministic rendering and publish:
  - payload bytes
  - payload hash
  - mapping profile version
  - mapping profile fingerprint (hash of the canonical mapping artifact)
  - dataset identifiers required to recompute rendering from a snapshot

Constraints:

- Rendering must be reproducible from a checkpoint-verified snapshot.
- Mapping must be version-controlled and treated as part of the proof surface.
- Message rendering must not introduce “hidden business logic” (it should be a pure projection).

#### Phase 2: Compliance evidence bundle (TEE-first)

Deliverables:

- Define a versioned “compliance evidence” artifact that binds:
  - commitment to the ISO 20022 payload (hash over canonicalized payload bytes),
  - commitment(s) to identity inputs (binding-and-hiding commitments; never raw hashes for PII fields),
  - dataset snapshot/checkpoint identifier(s) and canonical record reference(s) used for rendering,
  - policy version identifier(s),
  - mapping profile fingerprint,
  - a structured outcome (pass/fail + reason codes).
- Implement production behavior as:
  - TEE attests canonicalization and the outcome,
  - Conxian stores only non-PII commitments in the verifiable dataset layer.

Constraints:

- Must fail closed: if evidence cannot be produced, the workflow must produce explicit service errors.
- Must keep private identity data out of public egress datasets.
- Must not treat the compliance evidence as execution authority (it is an audit/control artifact).
- For any institution-facing ISO 20022 payload delivery, emission/serving MUST NOT succeed unless a corresponding compliance evidence artifact has been generated, linked, and persisted.
- Compliance evidence generation may be asynchronous relative to rendering, but ISO 20022 payload serving MUST block until the corresponding evidence artifact exists and is durably persisted.

#### Phase 3 (optional): ZK proofs for a narrow compliance claim

Candidate claims that are ZK-friendly:

- prove an amount is within a limit without revealing the exact amount (range proof),
- prove a risk score is below a threshold (with a small model),
- prove a counterparty identifier is a member of an allowlist/denylist commitment set (depending on the privacy model).

Constraints:

- The claim must be clearly stated with pinned verification keys and deterministic public inputs.
- Avoid mixing “full ISO 20022 rendering” and “compliance ZK proofs” in the same circuit; keep circuits narrow.

## Business constraints (must be true for a credible pilot)

1. **Disclosure model is explicit**
   - Who can see full ISO 20022 payloads?
   - Who can see identity-bearing fields?
   - Who can see only commitments and proofs?

2. **Audit and retention requirements are met**
   - retention window for payloads and evidence
   - reproducibility of evidence bundles (“same inputs produce same commitments/proofs”)

3. **Governance for policy/model versions is explicit**
   - “which policy version was applied” must be a first-class field in evidence bundles.

4. **Operational boundaries stay intact**
   - no signing keys in analytics or rendering services
   - no “execution authority” derived from inbound ISO 20022 messages

## Technical constraints (must be solved in any implementation)

1. **Canonicalization and hashing rules are pinned**
   - ISO 20022 XML canonicalization, dataset canonicalization, and evidence canonicalization must be deterministic.

2. **Versioned mapping artifacts**
   - a stable mapping file must exist for each supported message family/version.

3. **Private artifact lane**
   - encrypted payload storage + access control + key custody boundaries.
   - explicit policy for what gets committed in public datasets.
   - commitment randomness/keys used for identity-bearing inputs must remain private and must not appear in verifiable datasets or other egress surfaces.

4. **Proof system and verification surface**
   - if ZK proofs are used, decide where verification happens (off-chain service vs. on-chain anchoring of receipts).
   - verification keys (and model weights, if zkML) must be versioned and governed.

## Verification constraints (what “done” looks like)

Minimum verification expectations for a pilot:

1. **Snapshot integrity**
   - a third party can validate dataset snapshots against on-chain checkpoints.

2. **Renderer determinism**
   - given a snapshot + mapping profile version, a third party can re-render the ISO 20022 payload and obtain the same payload hash.

3. **Evidence binding**
   - evidence bundles must bind (by hash/commitment) to:
     - the ISO payload,
     - the dataset records used for rendering,
     - the policy/model version identifiers.

4. **Fail-closed behavior**
   - missing evidence generation must yield explicit, non-success responses (no simulated “valid=true”).

## Open questions to resolve before committing to zkML

1. Which compliance checks are required for the pilot (rule-based vs. ML)?
2. Is verifiable inference required, or is TEE attestation sufficient?
3. What is the exact privacy model (who learns what, when)?
4. Which ISO 20022 message family/version(s) are required by the institutional partner?

## Suggested next steps

1. Confirm pilot message family scope and the minimum dataset needed to render it.
2. Define a first “mapping profile” format and versioning rule.
3. Define a “compliance evidence bundle” schema (TEE-first) that binds payload + dataset + policy.
4. If zkML is still desired after Phase 2, pick a single narrow claim and a small model target and benchmark proof generation.
