# Security Checklist (Initial Draft)

## Contract Invariants
- [ ] Vault total-shares == sum(user shares)
- [ ] Withdraw cannot exceed user asset-equivalent shares
- [ ] Fees remain within 0..10000 bps
- [ ] Autonomics only active when enabled flag true
- [ ] Timelock delay respected before execution

## Access Control
- [ ] Only admin (timelock / DAO) can mutate critical params
- [ ] Treasury withdrawals gated
- [ ] Governance proposal threshold enforced

## Economic Safety
- [ ] Reserve ratio remains within governance bounds (bounded adjustments)
- [ ] Rate limiting cannot be bypassed by multi-call
- [ ] Fee ramp steps small enough to avoid shock changes

## Event / Analytics Integrity
- [ ] Analytics emission does not revert core logic
- [ ] Chainhook cannot cause re-entrancy (read-only)

## Deployment Hygiene
- [ ] Verify all deployed contract IDs captured in registry
- [ ] Post-deploy verification script passes
- [ ] Chainhook registered with correct address

## Recommended Next Steps
- Property tests for invariants (formal or fuzz)
- Static analysis tools (clarinet check + linter / future analyzers)
- Independent audit
