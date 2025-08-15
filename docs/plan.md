# AutoVault Roadmap (PRD-aligned)

This roadmap derives from docs/prd.md and sequences work to deliver an MVP with timelock governance, complete tests, and ops, then extends to strategy integration and full DAO governance.

## Milestones

1) Compile + Tests Green (MVP Base)

- Clarinet CLI (with test) and Deno installed
- All contracts compile: vault, timelock, registry, dao, gov-token, traits
- Clarinet tests cover: deposits/withdrawals, fees, caps, rate-limit, reserve, and timelock execution of all admin setters
- Ops scripts validated (Hiro API, ping, monitor-health)

2) Timelock Governance Verified End-to-End

- Timelock is admin of vault in tests
- Queue/execute for each setter and reserve withdrawal
- Min-delay enforced; events emitted; queue inspection views added
- Cancel path implemented and tested (if present in scope)

3) Controllers (Autonomic Mechanics) – Flags + No-op Defaults

- Controller flags and parameters added to vault (disabled by default)
- Read-only getters and events for controller config
- Basic tests for enabling/disabling without changing core economics

4) Analytics & Docs

- Standardized events across contracts
- Read-only metrics: TVL, fees, withdrawals, reserve, governance
- Docs: security.md (invariants, threat model), benchmark.md (peer comparison)

5) Strategy Integration (Optional Path)

- Strategy trait wired into vault (optional strategy principal)
- strategy-mock.clar for yield simulation
- Vault routes deposit/withdraw to strategy when set; harvest path and performance fee logic
- Tests for strategy flows

6) DAO Governor (Post-MVP)

- Proposal lifecycle: create, vote, quorum, state, queue/execute via timelock
- Views for proposals, receipts, and states; events
- Tests for full governance flow

7) Testnet Deploy + Runbook

- Devnet/simnet profiles; deploy scripts
- Testnet deployment of MVP contracts
- Operator runbook for timelock ops and monitoring

## Acceptance Criteria (by milestone)

- M1: `clarinet check` passes; `clarinet test` suite green in CI.
- M2: All admin paths provably executed only via timelock with delay; cancel/inspect views tested where applicable.
- M3: Controller flags toggleable; no state changes when disabled; bounded config.
- M4: Metrics reflect on-chain state; docs published and versioned.
- M5: Strategy optional, safe defaults when unset; accounting invariants hold; harvest only affects yield.
- M6: Proposals reach Succeeded only with quorum; only timelock execution mutates admin state.
- M7: Testnet deployment addresses and procedures documented.

## Security Invariants (summary)

- Total-balance = sum(user balances) + reserves ± strategy I/O
- Fees within configured bounds; no negative balances
- Admin functions callable only by admin (timelock in prod)
- Timelock delay enforced for all queued actions
- Strategy cannot withdraw more than its TVL; no re-entrancy via callbacks

## Test Coverage Map

- Vault: deposits, withdrawals, fee accrual, caps, rate-limit, pause, reserve
- Timelock: queue/execute per setter, min-delay, cancel, views
- Controllers: flag toggling, parameter bounds (basic)
- Strategy (if enabled): deposit/withdraw/harvest accounting and performance fee
- DAO (post-MVP): proposal lifecycle, quorum, queue/execute

## Risks & Mitigations

- Clarinet test runtime requires Deno – ensure CI and local tooling include it
- Governance complexity – stage DAO after MVP; keep timelock minimal and well-tested
- Strategy integration risk – ship with strategy disabled by default; mock-only initially

## Success Metrics

- Test coverage for critical paths (≥90% of functions) and invariants
- Protocol KPIs per economics.md (revenue bps/TVL, cost-to-use)
- On-chain events consumed by monitoring script and dashboard
