# AutoVault PRD — Autonomic Economics

This PRD enumerates requirements for a self-regulating (“autonomic”) vault aligned with security, sustainability, and profitability on Stacks.

## Goals

- Safety-first vault with delayed governance (timelock) for all admin actions
- Sustainable fee capture and reserve management
- Self-tuning parameters to maintain healthy utilization and liquidity
- Transparent on-chain events and predictable user experience

## Core Scope

- Timelock governance (done): queue/execute for all admin setters and reserve withdrawals
- Vault parameterization (done): fees, pause, global cap, user cap, rate-limit, token binding
- API + Ops (in progress): Hiro API scripts, docs, testnet workflows
- Tests (todo): Clarinet tests covering all critical flows and governance

## Autonomic Mechanics (MVP+)

- Utilization-aware fees (optional, gated by admin flag):
  - Define utilization = total-balance / global-cap
  - Withdraw fee bps: increase when utilization > U_high, decrease when < U_low
  - Bounds: fee-min-bps ≤ fee-withdraw-bps ≤ fee-max-bps; ramp per epoch Δbps
- Reserve target bands:
  - Reserve_target_low, Reserve_target_high (share of total-balance)
  - If reserve < low -> nudge deposit-fee up; if reserve > high -> nudge down
- Rate-limit breakers:
  - If block-volume spikes above threshold-X, auto-pause or tighten caps until cooldown
  - Emit breaker events; unpause requires timelock or cooldown expiry

All self-tuning changes remain gated by admin/timelock controls; knobs include enabling the controller, setting bands, and setting ramp rates.

## Events & Observability

- Emit events for all parameter updates and autonomic adjustments
- Compact payloads to minimize gas
- Read-only getters for current regime and controller configuration

## Testing Plan (Clarinet)

- Deposits/withdrawals: fees, balances, reserve accrual, total-balance invariants
- Risk controls: pause, user/global caps, rate-limit per block
- Governance: queue/execute each setter via timelock; delay enforcement
- Controllers: simulate utilization changes; verify fee ramps and bounds

## Non-Goals (for now)

- Price oracles and multi-asset strategies (can be integrated later)
- Full DAO tokenomics; timelock is sufficient for MVP governance

## Milestones

1) Compile + tests green (Clarinet)
2) Timelock as-admin execution verified end-to-end
3) Controller flags and parameters added (no-op by default)
4) Controller paths tested and documented
5) Testnet deploy + runbook
