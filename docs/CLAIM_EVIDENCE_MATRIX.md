# Claim vs Evidence Matrix

## Purpose

Provide a reusable decision surface for evaluating whether a technical or product claim is safe to make publicly.

## Evidence levels

- **Doc-only**: claim exists in README, PRD, roadmap, or strategy docs, but code/test/runtime proof is not yet verified.
- **Code-visible**: repository code or configuration exists that supports the claim.
- **Test-visible**: repository tests or CI evidence support the claim.
- **Release-visible**: tagged release, changelog, or release workflow supports the claim.
- **Environment-verified**: confirmed outside GitHub in runtime, device, testnet, or deployment validation.
- **Externally verified**: confirmed by independent audit, assessment, or third-party validation.

## Status labels

- **Simulated**: development or validation path only; not safe to frame as production-enforced.
- **Implemented**: code exists, but production enforcement may still depend on environment or control activation.
- **Production-enforced**: protected by runtime controls, release policy, and readiness gates.
- **Externally verified**: independently reviewed or audited.

## Current matrix

| Surface | Claim | Current evidence | Public-safe status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `conxius-wallet` | StrongBox/TEE-backed security exists | Code-visible | Implemented | Real Android keystore and StrongBox-oriented code paths are present. |
| `conxius-wallet` | Play Integrity is production-enforced | Code-visible, but stubbed path inspected | Not yet safe | Release builds now fail closed until end-to-end production path exists. |
| `conxius-wallet` | DLC execution is production-ready | Code-visible, but simulated path inspected | Not yet safe | Simulated flow is now debug-only and fails closed in release builds. |
| `conxius-enclave-sdk` | Hardware-backed signing architecture exists | Code-visible | Implemented | Real signing code exists. |
| `conxius-enclave-sdk` | Active production attestation is hardware-bound | Code-visible, mixed with software-driver simulation | Not yet safe | Depends on hardware-bound drivers, not just repo-visible software paths. |
| `conxian-gateway` | Institutional middleware runtime exists | Code-visible, Release-visible | Implemented | Real runtime code and release history exist. |
| `conxian-gateway` | All critical verification paths are production-enforced | Code-visible with simulated validation references | Not yet safe | Must stay tied to readiness gates and environment-backed verification. |
| `Conxian` protocol | Material protocol implementation exists | Code-visible | Implemented | Real Clarity and sBTC-related surface exists. |
| `Conxian` protocol | Security and correctness are externally proven | No external audit artifact established here | Not yet safe | Requires explicit external verification evidence. |
| `conxian-business` | Public/private boundary is controlled | Code-visible, policy-visible | Implemented | Repo is private and boundary docs are improved. |

## Rules for public claims

1. Do not present **Simulated** as production-ready.
2. Do not present **Implemented** as **Production-enforced** unless the runtime control path is confirmed.
3. Do not present **Production-enforced** as independently validated without external evidence.
4. Prefer precise wording:
   - "implemented"
   - "available in code"
   - "validated in test"
   - "gated in release builds"
   - "verified in environment"
   - "independently reviewed"

## Review cadence

- update after any readiness, release, audit, or security-control change
- check GitHub first
- attach environment-backed evidence separately when available
