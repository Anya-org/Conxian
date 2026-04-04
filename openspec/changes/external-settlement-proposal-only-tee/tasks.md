# Tasks: Implementation references (tracked in code repos)

This OpenSpec package defines the required security boundaries and acceptance criteria for proposal-only external settlement triggers.

Execution should be tracked in the relevant implementation repos (Gateway, Nexus, Wallet, and on-chain contracts).

## Primary issue

- https://linear.app/conxian-labs/issue/CON-162/enforce-proposal-only-external-settlement-triggers-in-tee

## Suggested implementation work-items

1. **Gateway ingress hardening**
   - Ensure ISO 20022 / PAPSS / BRICS ingress produces an attested trigger artifact.
   - Ensure no endpoint or background job can turn a TradFi payload into a direct execution.

2. **TEE verification surface**
   - Define and verify `AttestedExternalSettlementTrigger` inside the TEE.
   - Add explicit “floor” checks (StrongBox/TEE/CloudTEE), with negative tests.

3. **Proposal emission + timelock scheduling**
   - Accept only attested triggers as inputs.
   - Start the standard 144-block timelock using the native chain height source.

4. **Multi-sig continuity**
   - Ensure external-triggered proposals follow the same approval policy as native proposals.

5. **Yield routing invariant tests**
   - Add regression tests proving the 5/5/90 streaming outputs are unchanged.
