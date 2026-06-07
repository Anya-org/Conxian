# GitHub Technical Research and Remediation Plan

## Purpose

Maintain a current, GitHub-backed source of truth for the Conxian organization review, technical research findings, remediation backlog, and verification plan.

## Current state

The GitHub organization is active and materially stronger than the earlier hygiene review suggested, but there is still a readiness gap between some public claims and the implementation evidence currently visible in GitHub.

### Confirmed improvements since the earlier review

- `conxian-business` is private.
- Public repositories reviewed now show much stronger governance posture.
- The earlier concern about tracked public `.env` files and generated artifacts is not currently supported by org-wide GitHub code search.
- `conxius-wallet` now has a published release (`v1.9.2`).

## Repositories reviewed

- `Conxian/Conxian`
- `Conxian/conxius-platform`
- `Conxian/conxian-business`
- `Conxian/conxius-wallet`
- `Conxian/conxius-enclave-sdk`
- `Conxian/conxian-gateway`
- `Conxian/.github`

## Key findings

### Strengths

- Architecture is coherent across protocol, wallet, gateway, enclave, platform, and BOS layers.
- Governance posture is much stronger than before.
- `conxius-wallet` contains real Android StrongBox/TEE-oriented code paths.
- `conxius-enclave-sdk` contains real crypto and attestation-related code, not only concept docs.
- `Conxian` protocol repo contains substantial Clarity and sBTC-related implementation surface.
- `conxian-gateway` has release discipline and meaningful changelog history.

### Main risks

- Some production-style claims appear stronger than the currently inspected implementation evidence.
- `conxius-wallet` still contains stubbed or simulated paths in security-sensitive areas.
- `conxius-enclave-sdk` still contains simulated attestation behavior in inspected code paths.
- `conxian-gateway` changelog still references simulated paths in important system areas.
- Complexity and cross-repo coupling remain high, which raises verification cost and drift risk.

## Evidence by area

### Wallet

Confirmed in GitHub:
- StrongBox/TEE-backed keystore management exists.
- biometric-related Android components exist.
- published release exists.

Needs remediation / verification:
- Play Integrity plugin currently appears stubbed in the inspected file.
- DLC manager inspected path appears simulated.
- fallback behavior in signing path needs stricter production gating.

### Enclave SDK

Confirmed in GitHub:
- real secp256k1 / Schnorr signing code.
- zeroization and key-derivation controls.
- attestation freshness and nonce checking structures.

Needs remediation / verification:
- simulated attestation generation is still present in the inspected path.
- production driver separation should be made explicit.
- production vs simulated trust levels must be unambiguous in code and docs.

### Gateway

Confirmed in GitHub:
- real release entries and versioning.
- documented readiness framing is better than before.

Needs remediation / verification:
- simulated behavior still appears in release history.
- public language should remain precise about active development vs production enforcement.

### Protocol

Confirmed in GitHub:
- real Clarity, sBTC, vault, and roadmap surface exists.
- governance/security docs are present.

Needs remediation / verification:
- success claims should be tied to external audit-grade proof where possible.
- internal sign-off and simulation should be distinguished from independently verified production evidence.

### Business / BOS

Confirmed in GitHub:
- repo is private.
- security policy, CODEOWNERS, contributing policy, secret scanning workflow, and Dependabot are present.
- boundary language is much improved.

Needs remediation / verification:
- continue keeping private/internal-only strategy and operational detail out of public surfaces.
- ensure cross-repo portfolio language stays aligned.

## Ordered work plan

## P0 — security and reality alignment

### P0.1 Wallet production-truth alignment
- mark or gate stubbed integrity-token logic out of production paths.
- mark or gate simulated DLC flows out of production paths.
- ensure release/status language distinguishes:
  - implemented
  - simulated
  - production-enforced

### P0.2 Enclave production-truth alignment
- separate simulated attestation from production drivers.
- prevent simulated attestation paths from appearing production-grade.
- make trust-level semantics explicit in code and docs.

### P0.3 Cross-repo claim correction
- remove or tighten any wording that implies completed production enforcement where only simulation or partial implementation exists.
- standardize readiness language across wallet, enclave SDK, gateway, protocol, and BOS docs.

## P1 — governance, hygiene, and release hardening

### P1.1 Governance consistency
- verify SECURITY.md, CONTRIBUTING.md, CODEOWNERS, LICENSE, changelog guidance, and release guidance across priority repos.
- align repo purpose/status sections with current reality.

### P1.2 Security workflow consistency
- verify secret scanning, dependency update automation, and CI hygiene across priority repos.
- ensure `.env.example` usage is consistent and public-safe.

### P1.3 Portfolio clarity
- align repo portfolio maps and repo descriptions.
- keep public/private boundary language explicit and consistent.

## P2 — verification and proof posture

### P2.1 Claim-vs-evidence matrix
- maintain a matrix of each major system claim vs supporting evidence.
- identify where evidence is code-only, doc-only, test-only, or externally validated.

### P2.2 Readiness gates
- define what is required before a component can be described as production-ready.
- distinguish simulation, internal validation, hardware validation, testnet validation, and mainnet validation.

### P2.3 Audit and proof pack
- define a public-safe proof pack for external claims.
- identify which surfaces need independent verification.

## Current backlog

### Immediate execution candidates
- inspect and patch wallet stub/simulated security-sensitive flows.
- inspect and patch enclave simulated attestation path labeling and gating.
- update README/status/release wording in wallet, gateway, enclave SDK, and protocol repos.
- standardize readiness language in BOS knowledge surfaces.

## Open questions

- Is Play Integrity fully backend-verified anywhere outside the repo-visible code?
- Are simulated wallet and gateway paths excluded from production promotion in CI or branch policy?
- Which components have been tested on real Android hardware?
- Which components have external security review already completed?

## Verification lanes

### Lane A — GitHub-verifiable
- code paths
- docs
- release notes
- CI/workflow configuration
- governance files

### Lane B — environment-backed
- Android runtime behavior
- Play Integrity backend verification
- real hardware-backed attestation chain validation
- production deploy/runtime integrations
- live cross-system settlement and bridge verification

## Working rule

Always check GitHub first. Treat GitHub-visible evidence as the default current-state source, and treat any stronger claim as requiring either:
- direct code evidence,
- test evidence,
- release evidence,
- or explicit external verification evidence.

## Next execution sequence

1. patch P0 wallet issues
2. patch P0 enclave issues
3. align cross-repo status/claim language
4. verify governance/release/security workflow consistency
5. produce claim-vs-evidence matrix
6. define environment-backed verification checklist
