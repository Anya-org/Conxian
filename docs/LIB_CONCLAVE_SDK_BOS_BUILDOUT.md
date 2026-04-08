# lib-conclave-sdk — BOS business buildout (CON-370)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `lib-conclave-sdk`.

Canonical SDK docs live in the SDK repo itself (Conxian/lib-conclave-sdk). If anything in this BOS document conflicts with the SDK repo docs (`README.md`, `GOVERNANCE.md`, `RELEASING.md`, `SECURITY.md`, `CHANGELOG.md`), treat the SDK repo as the source of truth and update this file to match.

Upstream repo: https://github.com/Conxian/lib-conclave-sdk

This BOS repo vendors the SDK as a gitlink submodule at `lib-conclave-sdk/`. The active pin is the committed gitlink; inspect it with `git submodule status lib-conclave-sdk`.

When this BOS repo bumps the `lib-conclave-sdk` submodule pin, revalidate any version-specific / stability-policy statements in this doc against the canonical SDK docs in the same PR.

Submodule bump doc-checklist:

- Re-verify section 2 (integration surfaces) against the current SDK README and API docs.
- Re-verify section 3 (ownership + release-process model) against `GOVERNANCE.md`, `CODEOWNERS`, and `RELEASING.md`.
- Re-verify sections 5–6 (gaps + prioritized list) against `docs/MAINNET_READINESS_LIB_CONCLAVE_SDK.md` and the SDK repo’s current open issues.

- SDK README: `lib-conclave-sdk/README.md`
- SDK governance: `lib-conclave-sdk/GOVERNANCE.md`
- SDK releasing: `lib-conclave-sdk/RELEASING.md`
- SDK security policy: `lib-conclave-sdk/SECURITY.md`
- SDK changelog: `lib-conclave-sdk/CHANGELOG.md`

Note: in this repo, those artifacts live under the `lib-conclave-sdk/` submodule when it is checked out (for example, via `git submodule update --init lib-conclave-sdk`).

## 1) Business-unit role (supporting shared SDK)

Per the repo portfolio, `lib-conclave-sdk` is a **supporting** repo:

- Portfolio classification: `Supporting — Headless enclave + cryptographic state machine SDK.`
  - Source: https://github.com/Conxian/conxian-business/blob/main/docs/REPO_PORTFOLIO.md#ecosystem-repos

In BOS terms, the SDK is the shared “security edge” library that downstream business units consume:

- **Conxius (wallet)**: hardware-backed key custody and signing, WASM bindings for client apps.
- **Conxian Gateway (Fusion)** and **Nexus (state node)**: shared primitives for attested workflows, rails orchestration helpers, and message formats.
- **Industrial engine surfaces**: CJCS/ISO20022 encoding helpers when job cards must be signed/attested inside the enclave boundary.

The business obligation of the SDK is to provide a single integration contract so downstream teams don’t re-implement enclave abstractions, attestation, signing formats, or swap/settlement message structures in each product repo.

## 2) SDK surface + integration contract (what downstream teams can rely on)

The SDK currently exposes two public integration surfaces:

1. **Rust crate API** (system/service integrations)
   - Cargo package name: `lib-conclave-sdk` (see `Cargo.toml` for the version at this pin).
   - Examples of “integration contract” types include (non-exhaustive; treat the SDK docs as authoritative):
     - `enclave::EnclaveManager` (hardware abstraction)
     - `enclave::SignRequest` / `enclave::SignResponse`
     - `ConclaveError` / `ConclaveResult<T>`
     - `protocol::*` modules (rails, business registry, asset registry, job card / ISO20022 wrappers)

2. **WASM bindings** (browser/mobile JS runtimes)
   - Canonical entrypoint is `ConclaveWasmClient` exposed via `src/wasm_bindings.rs`.
   - Expected build target: `wasm32-unknown-unknown` (built via `wasm-pack`).
   - Build output packaging details (npm package name, publish channel) should be treated as part of release governance and called out explicitly in release notes once the WASM artifact is shipped publicly.

Follow the stability policy defined in the SDK repo’s canonical docs (`lib-conclave-sdk/GOVERNANCE.md`, `lib-conclave-sdk/RELEASING.md`); do not infer integration-contract guarantees solely from the semver version at this pin.

From a BOS perspective, the key compatibility invariant is: if a change affects the documented integration surface (Rust crate API as documented by the SDK repo, and the documented WASM exports), it must be communicated clearly in `CHANGELOG.md` and release notes.

## 3) Ownership + release-process model (minimum required roles)

For stable public SDK operations, ownership needs to be role-based (not person-based):

- **SDK maintainer**: owns API design, dependency hygiene, and CI gates.
- **Security/cryptography approver**: owns enclave boundaries, attestation flows, and “no secret egress” guarantees.
- **Downstream integrator representative**: ensures wallet/gateway/nexus consumption patterns are supported and documented.
- **Release manager**: owns versioning discipline, release notes, tags, and publishing (crates.io + npm/WASM if shipped).

Minimum approval expectations:

- `CODEOWNERS` must cover enclave + signing surfaces and must be required for PRs.
- Releases should require explicit sign-off from the security/crypto approver.

### Role-to-scope map (BOS view)

| Role | Scope | Where defined |
| --- | --- | --- |
| SDK maintainer | All SDK modules + WASM bindings | `lib-conclave-sdk/CODEOWNERS` |
| Security/cryptography approver | Enclave boundary, signing, attestation | `lib-conclave-sdk/CODEOWNERS` + `lib-conclave-sdk/SECURITY.md` |
| Downstream integrator representative | Wallet/gateway/nexus integration expectations | `docs/MAINNET_READINESS_LIB_CONCLAVE_SDK.md` + this doc |
| Release manager | Tags, changelog discipline, publishing | `lib-conclave-sdk/RELEASING.md` |

## 4) Governance + documentation requirements (downstream-operable)

### Minimum public-safe docs (GitHub)

The SDK repo should keep these docs current (public-safe):

- `README.md`: role line, purpose, status policy, and the supported integration surfaces.
- `GOVERNANCE.md`: business role, ownership model, support expectations, and compatibility communication.
- `RELEASING.md`: release flow and required preflight gates.
- `SECURITY.md`: supported versions + vulnerability intake path.
- `CHANGELOG.md`: Keep a Changelog format, with clear “Breaking” communication.

In this BOS repo, the canonical cross-repo checklist is:

- Mainnet readiness checklist — lib-conclave-sdk: `docs/MAINNET_READINESS_LIB_CONCLAVE_SDK.md`

### Internal-only operating docs (Linear Virtual Office)

Keep privileged operational material out of Git, even for an SDK:

- Production environment mapping (endpoints, partner rails credentials, any non-public infra details).
- Key custody procedures (device provisioning, attestation key lifecycle, incident response runbooks).
- Commercial terms and partner integration runbooks.

If downstream teams need the concept in Git, store a public-safe stub plus a Linear pointer, using the ZSE stub template: `docs/templates/ZSE_STUB_TEMPLATE.md`.

## 5) Governance gaps (what blocks “stable public SDK operations”)

Gaps to close before treating the SDK as a stable, widely-consumed dependency:

1. **Explicit stability policy for the integration contract**: document what is considered “public API” (Rust modules + WASM surface), and what can change without notice during `0.x`.
   - Canonical home: `lib-conclave-sdk/GOVERNANCE.md` and/or `lib-conclave-sdk/RELEASING.md` (this doc should remain a BOS summary).
2. **Support intake and severity conventions**: add a clear support channel (GitHub Issues + escalation path) so downstream teams don’t rely on ad-hoc DMs.
3. **Release automation and provenance**: CI should enforce the full preflight set (fmt, clippy, tests, WASM build, vuln scan) and produce traceable evidence for release artifacts.
4. **Downstream integration guide**: a short “how to consume” guide for wallet/gateway/nexus (feature flags, target triples, WASM packaging expectations).
5. **Security audit readiness**: define the minimum audit bar for `1.0.0` (threat model scope + what components must be audited).

Suggested canonical home (public-safe): add an “Audit readiness” section to `lib-conclave-sdk/SECURITY.md`, and keep any privileged runbooks and vendor engagement detail in Linear.

## 6) Prioritized build/repair list

**P0 (release integrity + safety gates)**

- Close the mainnet-readiness checklist items and keep them discoverable: `docs/MAINNET_READINESS_LIB_CONCLAVE_SDK.md`.
- Enforce release hygiene + supply-chain gates as CI requirements (SemVer tags, changelog discipline, vulnerability scanning).
- Canonically define “public API” vs “internal module” boundaries in the SDK repo docs and keep the Rust/WASM surfaces aligned.

**P1 (downstream operability + anti-drift)**

- Add an integration guide focused on downstream teams (wallet/gateway/nexus) and keep it public-safe.
- Add support intake + severity conventions (issue template(s) and a short triage policy).
- Add compatibility communication conventions (deprecation window policy once `1.0.0` is planned).

**P2 (governance completeness)**

- Add explicit audit readiness criteria for `1.0.0` (what needs independent review).
- Add a role-based owner map (“who approves what”) inside the SDK repo (for example, in `lib-conclave-sdk/GOVERNANCE.md`) and link it from the SDK README.
