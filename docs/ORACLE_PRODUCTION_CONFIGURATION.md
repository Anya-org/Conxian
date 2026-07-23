# Oracle Production Configuration and Release Gate

**Status: proposed and release-gated.** This document is a source-profile and
verification runbook, not deployment proof and not authorization to sign,
broadcast, or activate an oracle provider.

The issue #500 release-plan change is deliberately limited to deterministic,
source-independent wiring:

1. `oracle-aggregator.set-price-decimals(u8)`;
2. `twap-oracle.set-price-decimals(u8)`;
3. `liquidity-manager.set-oracle('<deployer>.oracle')`.

The generator emits those calls only in the final initialization batch. It does
not authorize an external source, submit a price, select a feed mapping, or
claim that a plan was broadcast. Both full-system plans remain preflight-only.

## 1. Release strategy

The proposed production strategy is:

- **Pyth: primary candidate.** Pyth feed metadata is recorded below only when
  it is directly verified from Pyth's official catalog. No Pyth contract
  principal is wired into the generated plans.
- **DIA: secondary candidate.** The verified Stacks DIA oracle metadata below
  is an approval input, not an initialization call in this release profile.
- **Conxian TWAP: sanity boundary.** The canonical `.oracle` facade reads the
  aggregate spot source and the Conxian TWAP source, checks their shared scale,
  and exposes the validated price path to consumers.
- **Fail closed.** If the approved provider, feed, relayer, freshness,
  confidence, source quorum, scale, or TWAP observation boundary is not valid,
  consuming paths must stop. They must not silently reuse an old price or
  switch to an unapproved feed.

Two relayers operated by the same provider are **not** an independent quorum.
Quorum approval must account for provider independence and provenance, not only
the number of relayer keys or transactions.

Provider-specific activation remains blocked pending the Pyth migration gate,
DIA/provider approval, source-security review, and signer/key-custody approval.

## 2. Shared source price scale

The release-plan metadata boundary uses a shared source price scale of **8
decimals (`u8`)**. This is a declaration that the canonical spot and TWAP
values use the same fixed-point source scale. It is not a conversion routine.

- `set-price-decimals` stores metadata on `oracle-aggregator` and
  `twap-oracle`.
- The `.oracle` facade rejects an unset scale and rejects a mismatch between
  the two source scales.
- The metadata does not convert provider values, token-native units, or
  provider exponents.
- A provider adapter/relayer must normalize an approved provider value to the
  agreed source scale before submission. That adapter is outside this issue's
  generated plan.

Token-specific decimal conversion is a separate concern. For example, a
token's native balance precision must be converted by the pricing or risk
adapter when a USD source price is applied to that token. Changing the source
price metadata from `u8` does not change STX, CXD, LP, or any other token's
native decimal convention.

## 3. Verified provider metadata (approval required)

The values in this section are **provider metadata**, not Conxian signer,
deployer, admin, or authorization values. They must be re-verified during the
release approval window and must not be copied into a generated plan without a
separate approved provider configuration.

Retrieval date for the values below: **July 22, 2026**.

### 3.1 Pyth feed IDs

The following 64-hex-character IDs (32 bytes) were retrieved from the official
Pyth Core Hermes crypto catalog and matched by the official display symbol:

| Feed | Official Pyth Core Hermes `id` | Release use |
|---|---|---|
| BTC/USD | `e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` | Candidate metadata only |
| STX/USD | `ec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17` | Candidate metadata only |
| ETH/USD | `ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` | Candidate metadata only |
| USDC/USD | `eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a` | Candidate metadata only |

Canonical sources:

- [Pyth Price Feed IDs](https://docs.pyth.network/price-feeds/core/price-feeds/price-feed-ids)
- [Official Hermes crypto catalog](https://hermes.pyth.network/v2/price_feeds?asset_type=crypto)

These are feed IDs, not Stacks contract principals. The current Pyth Core
documentation announces an **August 18, 2026** Core upgrade/migration gate and
states that the current supported-chain guidance is for major EVM chains,
Solana, and Sui. Stacks support and a release-approved Stacks contract
principal are unresolved for this profile. Treat August 18, 2026 as a Pyth
support/migration gate: do not wire a guessed Pyth principal before the
provider confirms the post-migration Stacks path, contract, endpoint, and
operational requirements.

Canonical migration sources:

- [Pyth Core upgrade](https://docs.pyth.network/price-feeds/core/upgrade)
- [Preparing for the Pyth Core upgrade](https://docs.pyth.network/price-feeds/core/upgrade/preparing)
- [Pyth Core price feeds](https://docs.pyth.network/price-feeds/core/price-feeds)

The August 18 gate also includes Hermes authentication and endpoint migration
requirements. A release must bind the selected endpoint, API-key custody,
contract verification path, and feed catalog snapshot together. A feed ID by
itself is not an integration approval.

### 3.2 DIA Stacks metadata

DIA's official Stacks guide verifies these deployed provider principals:

| Network | Verified DIA oracle principal | Status |
|---|---|---|
| Mainnet | `SP1G48FZ4Y7JY8G2Z0N51QTCYGBQ6F4J43J77BQC0.dia-oracle` | Provider metadata; approval required |
| Testnet | `ST1S5ZGRZV5K4S9205RWPRTX9RGS9JV40KQMR4G1J.dia-oracle` | Provider metadata; approval required |

The verified Stacks feed key used in the official guide is **`STX/USD`**.
DIA documents that the returned STX/USD price uses eight decimals and that
the response includes the last-update timestamp. No unsupported DIA BTC/USD,
ETH/USD, or USDC/USD key is synthesized here. The testnet principal is recorded
as `...ZGRZ...`, matching the official page; an earlier research note's
`...ZGRV...` variant is not used.

Canonical source:

- [DIA Stacks oracle guide](https://www.diadata.org/docs/nexus/how-to-guides/fetch-price-data/chain-specific-guide/stacks)

The DIA principals and `STX/USD` key remain provider metadata. They do not
authorize a source, establish a signer, or prove that a Conxian deployment has
been made.

## 4. Current on-chain behavior and release requirements

The following is the behavior of the current checked-in contracts. It is not a
claim that provider-specific release thresholds are already implemented.

### 4.1 Aggregate source boundary

`oracle-aggregator` stores a source submission with the current
`burn-block-height`. Its aggregate read path requires at least two authorized
sources and accepts the aggregate only when the oldest included source is no
more than **`u144` burn blocks** old. The contract does not receive or validate
provider wall-clock timestamps, confidence intervals, signed feed IDs, or
provider provenance.

The release adapter must therefore enforce provider-specific requirements
before a submission reaches the contract, including:

- approved provider and exact feed key/ID;
- source provenance and payload signature/authentication;
- provider timestamp freshness against the approved wall-clock budget;
- provider confidence/uncertainty limits where the provider exposes them;
- normalized `u8` output and valid range checks;
- independent source/quorum policy; and
- deterministic handling of missing, delayed, or contradictory updates.

The provider timestamp policy and confidence thresholds are **release gates**,
not current on-chain enforcement. Do not describe them as enforced until a
reviewed adapter and corresponding contract boundary exist.

### 4.2 Conxian TWAP boundary

`twap-oracle` defaults `twap-window` to **`u144` burn blocks**. Its current
implementation reads an observation at `current burn-block-height - u144` and
another at the current burn block, then returns their simple arithmetic mean.
It is not a continuously integrated rolling TWAP. The current release plan
does not call `set-twap-window` and does not submit observations.

The deterministic cadence for a future approved relayer is therefore explicit:

1. publish or accept an approved observation for an asset at the start block;
2. publish or accept the matching observation at the end block;
3. ensure both observations use the same approved `u8` scale; and
4. fail closed when either boundary observation is absent or outside the
   approved operational window.

`update-price-observation` is intentionally absent from the generated plans.
It is a provider/relayer operation and requires a separately approved source
profile.

### 4.3 Facade and deviation boundary

The canonical `.oracle` facade first verifies that both source decimal values
are configured and equal. Its current default maximum spot-vs-TWAP deviation is
`u500` basis points, and `get-validated-price` rejects a larger calculated
deviation. This check is distinct from provider freshness, confidence, and
quorum policy. Those provider policies must not be inferred from the facade's
scale or deviation checks.

## 5. Authorization, provenance, and custody gates

Before provider activation, release approval must include all of the following:

1. **Provider approval:** named provider, network, contract principal or
   endpoint, exact feed IDs/keys, terms, and migration compatibility.
2. **Source authorization:** an approved list of source principals/relayers and
   a documented independent-quorum rule. Two keys controlled by one provider do
   not satisfy independent-provider quorum.
3. **Key custody:** relayer/API credentials are held by the approved vault or
   signing service, are never committed to the repository, and have rotation,
   revocation, and incident-response procedures.
4. **Provenance:** retain provider documentation, feed catalog retrieval time,
   payload/signature format, source set, and the exact adapter release that
   normalized the value.
5. **Freshness:** enforce both provider timestamp age and the on-chain
   `burn-block-height` boundary. A provider timestamp cannot waive the
   contract's `u144` source-age rule.
6. **Confidence:** enforce an approved confidence/uncertainty budget where
   available. If a source has no confidence field, record that limitation and
   use the approved fallback/position-size policy rather than inventing one.
7. **Fallback:** only switch to the approved secondary source after its exact
   principal/feed/key and freshness checks pass. If no approved source meets
   the gate, pause or reject the consuming operation; never silently use a
   stale last-good value.

## 6. What the generated plans do and do not prove

The generated plans now contain **240 effective entries** after the explicit
quarantine of the unavailable `zkml-verifier` scaffold:

- 214 filtered contract publications; and
- 26 final-batch initialization/configuration calls, including the three
  source-independent oracle wiring calls.

The plans prove only that the checked-in generator can reproduce those
preflight artifacts and that the semantic validation rules pass. They do not
prove:

- that any contract was published on testnet or mainnet;
- that a transaction was signed, accepted, anchored, or confirmed;
- that the unresolved plan deployer is an approved signer-derived identity;
- that a Pyth or DIA provider was authorized or activated;
- that price data was submitted; or
- that a provider's timestamp, confidence, or availability policy is enforced.

An on-chain receipt/evidence pack must bind transaction IDs, network, approved
deployer, plan hash, contract/function/arguments, canonical status, block data,
and post-deployment read-only state. A workflow artifact, generated YAML file,
checksum, or dashboard summary is not an on-chain receipt.

## 7. Fresh-deployment verification

### 7.1 Plan-only preflight

Run from the repository root:

```bash
python3 scripts/gen-deployment-plans.py --check
sha256sum deployments/full-system.mainnet-plan.yaml
cat deployments/full-system.mainnet-plan.sha256
```

The first command must report that the checked-in plans match a fresh
generator run. The two checksum outputs must match exactly. This is preflight
evidence only.

### 7.2 Read-only state queries

After a separately approved fresh deployment, use the Stacks node read-only
RPC. The node endpoint and deployer address must be supplied by the approved
network release record; do not substitute a guessed address.

```bash
export NODE_RPC="https://<approved-stacks-node>"
export DEPLOYER_ADDRESS="<approved-signer-derived-address>"
export READ_SENDER="$DEPLOYER_ADDRESS"

call_read() {
  local contract_name="$1"
  local function_name="$2"
  curl --fail-with-body -sS -X POST \
    "$NODE_RPC/v2/contracts/call-read/$DEPLOYER_ADDRESS/$contract_name/$function_name" \
    -H 'content-type: application/json' \
    --data "{\"sender\":\"$READ_SENDER\",\"arguments\":[]}"
  printf '\n'
}

call_read oracle-aggregator get-price-decimals
call_read twap-oracle get-price-decimals
call_read oracle get-price-decimals
call_read liquidity-manager get-configured-oracle
```

The endpoint and request shape follow the [Stacks node RPC API
reference](https://docs.stacks.co/reference/api). Decode the returned Clarity
`result` with the approved Stacks SDK or node tooling. The expected successful
states are:

- `oracle-aggregator.get-price-decimals` -> `(some u8)`;
- `twap-oracle.get-price-decimals` -> `(some u8)`;
- `oracle.get-price-decimals` -> `(ok u8)`; and
- `liquidity-manager.get-configured-oracle` ->
  `(some '<approved-address>.oracle')`.

The two source results must use the same scale, and the facade and liquidity
manager results must point to the same deployment's canonical `.oracle`
contract. A successful read-only call is state verification, not a substitute
for complete transaction receipt evidence.

The SDK equivalent is `fetchCallReadOnlyFunction` with empty arguments for the
four functions above; see the [Stacks read-only call
guide](https://docs.stacks.co/stacks.js/read-only-calls). Never place a private
key, API key, or mnemonic in a query command or its output.

### 7.3 Negative and fail-closed expectations

The following results are release failures, not acceptable degraded success:

- either source returns `none` for `get-price-decimals`;
- the facade returns `ERR_PRICE_SCALE_NOT_CONFIGURED` (`u7007`) or
  `ERR_PRICE_SCALE_MISMATCH` (`u7008`);
- the liquidity manager returns `none`, points anywhere other than the
  canonical `.oracle`, or rejects the approved configuration unexpectedly;
- an attempted non-canonical oracle configuration returns anything other than
  the expected `ERR_ORACLE_MISMATCH` (`u2008`) boundary;
- the aggregate has fewer than two authorized sources (`u1007`) or its oldest
  source is older than `u144` burn blocks (`u1002`); or
- a TWAP boundary observation is missing, causing the current TWAP contract to
  return its no-price/window error rather than a fabricated value.

Provider-specific feed authorization and price submissions must be verified in
their own approved evidence path. Their absence from these plans is
intentional.

## 8. Recovery and fallback policy

If Pyth is unavailable, unsupported after the August 18, 2026 migration gate,
or fails the provider freshness/confidence test, the system may use DIA only if
the exact DIA principal, feed key, relayer custody, and independent approval
are already recorded for the target network. If neither candidate satisfies
the release gate, keep the consumer paused/fail-closed.

Do not:

- add `set-source-authorized` to a source-independent plan;
- add `submit-price`, `set-price`, `register-asset`, or
  `update-price-observation` to bypass provider approval;
- treat two relayers from one provider as independent sources;
- infer token-native decimal conversion from the `u8` source scale;
- replace a missing price with a guessed feed ID, principal, or last-good
  value; or
- describe preflight YAML/checksum/workflow output as a deployment receipt.

---

*Last updated: July 22, 2026. Provider metadata and migration status must be
re-verified before any future activation decision.*
