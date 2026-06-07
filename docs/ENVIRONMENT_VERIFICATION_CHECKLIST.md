# Environment-backed Verification Checklist

## Purpose

Track what must be verified outside GitHub before higher-confidence production claims are made.

## Wallet

- verify Play Integrity request on a real Android device
- verify backend-side integrity token validation
- verify biometric + signing path in release build
- verify StrongBox behavior on supported hardware and fallback behavior on unsupported hardware
- verify simulated DLC path is unavailable in release build

## Enclave SDK

- verify hardware-bound driver integration, not only software-backed drivers
- verify attestation chain validation with real device or enclave evidence
- verify fail-closed behavior when attestation is software-only
- verify high-value enforcement with hardened attestation level

## Gateway

- verify readiness-gated deployment path in environment
- verify any simulated validation paths are excluded from production routes
- verify secrets/config handling in deployment environment
- verify dependency and release workflows on tag and promotion path

## Protocol

- verify testnet/mainnet deployment plan against actual chain behavior
- verify contract interactions for the highest-risk modules
- collect or link explicit audit artifacts when available

## Portfolio and governance

- verify branch promotion rules are actually enforced in practice
- verify CODEOWNERS review requirements on sensitive changes
- verify secret scanning and dependency automation run on target branches

## Output format

For each verification item, record:
- date
- environment
- actor
- result
- evidence link
- follow-up action
