# ALEX Launch Readiness

**Current status: ALEX production release wiring is disabled and is not launch-ready.**
Conxian does not claim a live ALEX adapter or verified production connectivity. The
release generator and checked-in release artifacts intentionally omit the ALEX
adapter, reserve pool, swap helper, and related registration calls until the launch
configuration and acceptance evidence below exist.

## Local simulation is not ALEX connectivity

Clarinet simnet keeps these local-only fixtures so contract signatures and existing
integration tests remain useful:

- `contracts/integrations/simnet/alex-adapter.clar`
- `contracts/integrations/stubs/alex-reserve-pool.clar`
- `contracts/integrations/stubs/alex-swap-helper-v1-03.clar`

They return deterministic mock results for local execution. They do not make RPC
calls, reach ALEX liquidity, prove a wrapper or pool exists, or demonstrate that a
real swap can settle. A passing `tests/alex-integration.test.ts` run is therefore a
simnet signal only.

## Initial product path versus a future adapter

The recommended initial product path is **direct user swaps through ALEX** after a
Conxian token is actually listed and its pool is funded. This keeps user-facing
routing at ALEX while Conxian validates the token, listing, liquidity, and support
process.

A future **protocol-owned Conxian adapter** is a separate launch decision. It must
use verified network-specific contracts and a reviewed integration implementation;
the local adapter name must not be promoted or treated as a production principal.

## Canonical ALEX network references

Use the official ALEX network pages as the source of truth and re-verify them before
any launch transaction. These references are documentation inputs, not release
configuration embedded in Conxian:

| Network | Reserve pool | Swap helper |
| --- | --- | --- |
| Mainnet | `SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.alex-reserve-pool` | `SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.swap-helper-v1-03` |
| ALEX testnet | `ST29E61D211DD0HB0S0JSKZ05X0DSAJS5G5QSTXDX.alex-reserve-pool` | `ST29E61D211DD0HB0S0JSKZ05X0DSAJS5G5QSTXDX.swap-helper-v1-03` |

- [ALEX mainnet deployed contracts](https://docs.alexlab.co/developers/integrations/networks/mainnet)
- [ALEX testnet deployed contracts](https://docs.alexlab.co/developers/integrations/networks/testnet)
- [ALEX trading pool and swap-helper documentation](https://docs.alexlab.co/developers/products/alexs-automated-market-maker-amm/trading-pool)

The ALEX testnet can be reset. Confirm the network, contract code/version, and
principal at the time of testing rather than relying on a stale address.

## Required launch inputs

Before production wiring is considered, record all of the following with no
placeholders:

- Exact Conxian launch token contract and asset name.
- Target network.
- Pair and anchor asset.
- ALEX wrapper/listing decision, including whether the token is permissioned or uses the documented wrapper flow.
- Pool principal, ALEX pool version, factor, and weights.
- Initial liquidity amounts and funding owner.
- Fee, oracle, and start-block configuration.
- Listing transaction ID and pool-creation/funding transaction IDs.
- Verified Conxian deployer principal and sufficient funding for deployment and controlled tests.

## Evidence required to enable release wiring

Release wiring can be enabled only after a reviewable evidence bundle contains:

1. Verified wrapper, pool, reserve/helper, and token principals on the selected network.
2. A controlled swap using a **nonzero `min-dy`** that succeeds against the intended pool.
3. Recorded post-conditions: expected output amount, fee behavior, pool reserve changes, and no unexpected asset movement.
4. Recipient and balance verification for both input and output assets, using transaction receipts and on-chain reads.
5. Rollback behavior for insufficient `min-dy`, unavailable/paused pool, failed helper call, and rejected listing/configuration. The disable path and operator response must be documented.

Until those inputs and proofs are attached to the launch decision, keep ALEX
production publishing and registration disabled. Do not replace this gate with a
guessed production adapter, a hardcoded Conxian deployer, a fake wrapper, or a
simnet principal.
