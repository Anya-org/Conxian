# SDK 3.5.0 and Nakamoto Support Plan

## Current Status

### Clarity SDK
- We are using `@stacks/transactions` version 7.0.6 (outdated).
- The test suite has gaps: no transaction tests, inefficient `initSimnet` usage, weak assertions.

### Nakamoto
- No Nakamoto features (e.g., sBTC, `pox-4` capabilities) are currently used.
- Contracts are written in Clarity 2 and need to be upgraded to Clarity 3.

## Recommendations

### Immediate Actions
1. Update `@stacks/transactions` to version 7.2.0.
2. Enhance the test suite:
   - Add transaction tests.
   - Use `beforeAll` or `beforeEach` hooks for `initSimnet`.
   - Strengthen assertions.
3. Enable advanced SDK 3.5.0 features in the test setup (coverage and cost tracking).

### Medium-Term Actions
1. Upgrade contracts to Clarity 3.
2. Integrate sBTC into the vault contract.
3. Complete the implementation of `nakamoto-vault-ultra.clar`.

### Long-Term Actions
1. Implement on-chain automation for periodic functions (like founder token reallocation).
2. Improve tooling for a better developer experience.

## Detailed Plan

### Phase 1: SDK Update and Test Enhancement (Week 1)
- Update `@stacks/transactions` to 7.2.0.
- Refactor tests to use `beforeAll`/`beforeEach` for `initSimnet`.
- Add transaction tests for all state-changing functions.
- Enable coverage and cost tracking in the test setup.

### Phase 2: Clarity 3 Upgrade (Week 2-3)
- Upgrade all contracts to Clarity 3 syntax.
- Integrate sBTC into the vault contract.
- Complete and audit `nakamoto-vault-ultra.clar`.

### Phase 3: On-Chain Automation (Week 4)
- Research and implement a solution for on-chain automation (e.g., keeper network).

## References
- [VAULT.md](prd/VAULT.md)
- [SDK_TESTING.md](prd/SDK_TESTING.md)
- [DAO_GOVERNANCE.md](prd/DAO_GOVERNANCE.md)
- [CLARITY_SDK_NOTES.md](CLARITY_SDK_NOTES.md)
