# Conxian Risk Management

This document is the source of truth for the current risk-management control
path. It describes the implementation on Clarity 4 / Epoch 3.0 and deliberately
does not claim production solvency calculations where the dimensional position
source is still a placeholder.

## Architecture and API ownership

The protocol has one canonical risk implementation:

- `contracts/core/risk-unit.clar` owns health-factor calculation, the position
  health cache, system-risk score, liquidation authorization, and risk wiring.
- `contracts/core/risk-manager.clar` is a compatibility facade introduced for
  callers that still use the old name. Its query/math methods forward to
  `risk-unit`; its privileged write and liquidation methods return
  `ERR_FACADE_DEPRECATED` (`u1003`) instead of attempting an unsafe nested
  authorization path.
- `contracts/core/dimensional-engine.clar` resolves `risk-unit` from
  `conxian-protocol` first and falls back to the legacy `risk-manager` module
  key only for compatibility.
- `contracts/agents/agent-risk.clar` computes telemetry scores and has an
  explicit, admin-gated publication path into the configured canonical risk
  unit. It does not own liquidation logic or circuit-breaker administration.

Do not add a second risk implementation to `risk-manager`. New integrations
should call `risk-unit` directly and should register it under the `risk-unit`
module key.

## Units and math

### Health factor

Health factors use basis-point-style fixed-point units:

```text
health-factor = collateral-value * 10_000 / total-debt
```

- `u10000` is `1.0x`.
- Zero debt returns the bounded sentinel `u100000`.
- Exact threshold values are healthy; liquidation uses strict `<`.
- `u10000` is the normal liquidation threshold.
- `u11000` is the emergency threshold selected when system risk is at least
  `u5000`.

`calculate-health-factor` is pure read-only math and returns a `uint` directly,
preserving the existing ABI.

The multiplication is intentionally not pre-bounded. Clarity arithmetic rejects
values that overflow the `uint` range, so an out-of-range input fails closed
rather than producing a wrapped health factor. Introducing an application-level
ceiling would risk rejecting useful protocol amounts or changing precision, so
the explicit bound remains follow-up work.

### System risk score

`risk-unit` stores system risk on an explicit `0..10000` scale. Values above
`u10000` are rejected. `u5000` is the emergency-threshold transition point.

`agent-risk` retains its historical `0..1000` compatibility score so existing
telemetry consumers do not silently change units. `publish-system-risk`
normalizes the score by ten before calling `risk-unit`:

| GCR band | Agent score | Published system score |
|---|---:|---:|
| `GCR <= 100` | `u900` | `u9000` |
| `100 < GCR < 150` | `u500` | `u5000` |
| `GCR >= 150` | `u100` | `u1000` |

The publication path requires the configured `risk-unit` principal and the
canonical unit separately authenticates `contract-caller == risk-agent` (or a
trusted admin). A malicious metrics trait cannot select an arbitrary receiver.

## Authorization matrix

| Operation | Authorized caller | Notes |
|---|---|---|
| `risk-unit.initialize` | Deploying principal or `conxian-access` `ROLE_ADMIN` | One shot; the supplied owner is configuration, not bootstrap authorization. |
| `risk-unit.update-system-risk` | Configured agent contract or admin | Score is bounded before mutation. |
| `risk-unit.get-health-factor` | Any caller after initialization | Refreshes the cache using current position data. |
| `risk-unit.liquidate` | `dimensional-engine`, configured agent, configured ops engine, or admin | Authorization executes before any cache mutation. `.risk-manager` is not whitelisted. |
| `risk-unit.set-*` | Local owner or `conxian-access` `ROLE_ADMIN` | Configuration is only available after initialization. |
| `agent-risk.initialize` | Its deployment-time admin | One shot; reinitialization is rejected. |
| `agent-risk.publish-system-risk` | Agent admin and configured `risk-unit` trait target | This path does not grant circuit-breaker rights. |
| `risk-manager` privileged methods | None | ABI is retained, but methods return `u1003`; use `risk-unit`. |

## Initialization and wiring

Fresh environments should wire the risk path in this order:

1. Initialize `conxian-access` and establish its admin role.
2. Initialize `agent-risk` with the deployment-time administrator.
3. Initialize `risk-unit`:

   ```clarity
   (contract-call? .risk-unit initialize
     tx-sender
     .agent-risk
     .dimensional-engine)
   ```

4. Configure `risk-unit.set-ops-engine` if the ops engine is a liquidation
   caller.
5. Register `risk-unit` in `conxian-protocol` under `"risk-unit"`. Register
   `risk-manager` under its legacy key only when an external compatibility
   caller needs it.
6. Set `agent-risk.set-risk-unit` to the canonical risk-unit principal.

The agent publication entrypoint uses the principal-injected
`risk-signal-publisher-trait` rather than a hardcoded static call. This keeps
the test/deployment graph free of an unnecessary agent-to-risk-unit circular
dependency. The configured principal check is still mandatory.

Deployment manifests that initialize `risk-unit` must also include the module
registry and agent publication wiring when those integrations are expected to
be live. Do not treat contract publication alone as completed risk wiring.

### Release artifact scope

`scripts/gen-deployment-plans.py` is authoritative for the checked-in
`deployments/full-system.testnet-plan.yaml` and
`deployments/full-system.mainnet-plan.yaml` artifacts selected by the deployment
workflows. Those two plans are regenerated from
`deployments/default.simnet-plan.yaml` and now include the complete risk wiring
sequence. `deployments/mainnet-manifest-v1.yaml` is a separately maintained
manual manifest and is not an output of that generator, so it is intentionally
unchanged here. `deployments/mainnet-release-plan.yaml` is an explicitly disabled
legacy no-op and remains empty.

## Cache and freshness semantics

`risk-unit.position-health` stores:

```text
{ health-factor: uint, last-update: burn-block-height }
```

The cache is decision-grade for `CACHE_MAX_AGE = u6` burn blocks. Freshness is
computed against `burn-block-height`, not wall-clock time.

- `get-health-factor` refreshes and writes the cache.
- `get-position-health` exposes the cached factor, update height, and a
  `fresh` boolean. It remains useful for operations even when stale.
- `get-health-factor-read-only` returns only fresh cache data.
- `is-liquidatable` fails closed with `u1003` when the cache is absent and
  `u1004` when it is stale. It does not use the former safe-looking `u20000`
  default.
- `liquidate` refreshes only after authorization. A failed transaction does
  not leave a cache mutation, and a successful downstream liquidation deletes
  the cache entry.

## Score publication and observability

The following read-only methods are intended for dashboards and operational
checks:

- `get-system-risk-score`
- `get-risk-config` — ownership, configured callers, score, thresholds, and
  active threshold, and cache age
- `get-position-health` — cached health, burn-block update height, freshness

Risk score updates emit a structured `risk-score-updated` event. Successful
liquidation decisions emit `risk-triggered-liquidation` with the position,
health factor, system score, threshold, and burn-block height. Agent
publication emits `system-risk-published` with both compatibility and
canonical scores.

## Circuit breaker and oracle behavior

The canonical pause guard remains downstream in
`contracts/dimensional/dimensional-core.clar`: its `is-paused` path queries
`enhanced-circuit-breaker`, and `liquidate-position` checks that guard before
executing. `risk-unit` intentionally does not duplicate circuit-breaker admin
rights. This is a transitive execution guard, not a claim that the risk agent
can pause the protocol.

The oracle principal is passed to `dimensional-core.liquidate-position`, but
the current dimensional position source is not production solvency data:

- `dimensional-core.get-position` currently returns placeholder collateral and
  maintenance-margin values.
- `dimensional-core.liquidate-position` currently validates pause/caller state
  and returns success without closing the position.

Replacing those placeholder-backed reads and implementing position settlement
are separate work and are intentionally out of scope for this risk-hardening
change. Until then, tests prove control-path authorization, cache behavior, and
math—not oracle-valued production solvency.

## Root-to-leaf execution flow

The intended flow is:

```text
finance-metrics
    ↓
agent-risk.assess-system-risk (local compatibility score)
    ↓ explicit admin publication + x10 normalization
risk-unit.update-system-risk
    ↓ score selects normal/emergency threshold
dimensional-engine resolves registered risk-unit
    ↓
risk-unit.get-health-factor / liquidate
    ↓
dimensional-core pause guard → oracle-aware liquidation path
```

The leaf math and cache tests should pass before facade and dimensional-engine
integration tests are used as root-to-leaf checks.

The downstream `dimensional-core` authorization list still contains the legacy
`.risk-manager` principal for compatibility. The current `risk-manager` facade
itself disables privileged forwarding and returns `u1003`; new callers must use
the registered canonical `.risk-unit` contract. Because
`dimensional-core.get-position` and settlement remain placeholder-backed, the
successful low-health downstream liquidation branch is intentionally not claimed
by this test suite.

## Tests and validation

Focused risk/AYE tests:

```bash
bash scripts/run-tests.sh \
  tests/core/risk-manager.test.ts \
  tests/agents/aye-pid.test.ts \
  tests/aye-engine.test.ts \
  tests/chaos_engine.test.ts \
  tests/core/dimensional-engine.test.ts
```

Repository-wide documentation validation:

```bash
npm run validate:docs
```

Clarity compilation in CI:

```bash
clarinet check --manifest-path Clarinet.toml
```

The native `clarinet` binary is not part of the current development devbox;
when it is unavailable, report the check as blocked rather than substituting a
deployment operation.
