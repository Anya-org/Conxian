---
description: Conxian Workflow (formerly AutoVault) - Pointer and Quick Actions
auto_execution_mode: 3
---

# Conxian Workflow (formerly AutoVault)

This workflow replaces the previous AutoVault workflow. Detailed technical guidance has been centralized to avoid duplication. Use this file as a pointer and for quick commands.

## Prerequisites

- Node.js >= 18 and npm
- Clarinet SDK 3.5.0 via `@hirosystems/clarinet-sdk`
- Minimal Clarinet test manifest at project root: `Clarinet.test.toml`
- Global Vitest setup: `stacks/global-vitest.setup.ts` with `initBeforeEach: false`

## Dynamic SIP-010 Dispatch (Implementation Pattern)

- Canonical guidance has moved to:
  - `.windsurf/workflows/token-standards.md` → "Dynamic Dispatch Notes (SIP-010)"
  - `.windsurf/workflows/design.md` → "Tokenized-Bond Dynamic SIP-010 Dispatch"

Key references:
- Contract: `contracts/dimensional/tokenized-bond.clar`
- Trait: `contracts/traits/sip-010-trait.clar`

## Testing & Environment Setup

- Follow the canonical testing guidance in `token-standards.md` → "Testing & Dev Environment".
- Global setup is in `stacks/global-vitest.setup.ts` with `initBeforeEach: false`.
- Minimal manifest: `Clarinet.test.toml` including traits and target contracts.

## Steps

1. Ensure dependencies are installed
   - Command: `node ./scripts/ensure-deps.js`
   - Notes: Installs root and `stacks/clarinet-wrapper` dependencies if missing. Network access required.

// turbo
1. Run unit & integration tests (safe)
   - Command: `npx vitest run`
   - Expected: All tests pass, including dynamic SIP-010 dispatch scenarios in `tokenized-bond`.

1. Optional: Generate coverage report
   - Command: `npm run coverage`
   - Notes: Uses Vitest C8 coverage. Validate function coverage for SIP-010 interactions and diagnostics.

1. Validate dynamic dispatch behavior (manual checks)
   - Confirm `(get-payment-token-contract)` returns `some(contract-principal)` of the configured token.
   - For coupon claims and maturity redemption, ensure calls succeed with `<sip10>` parameter and correct `contract-call?` usage.

1. Troubleshooting
   - If principals are undefined: verify `initBeforeEach: false` in `stacks/global-vitest.setup.ts` and that accounts are retrieved in `beforeEach`.
   - If external calls fail: confirm un-dotted function names in `contract-call?` and correct trait parameter type `<sip10>`.
   - If manifest issues arise: re-check `Clarinet.test.toml` includes all referenced contracts.

## Artifacts

- Tests: `stacks/sdk-tests/dimensional-system.spec.ts`
- Manifest: `Clarinet.test.toml`
- Setup: `stacks/global-vitest.setup.ts`
- Contracts: `contracts/dimensional/tokenized-bond.clar`, `contracts/mocks/mock-token.clar`