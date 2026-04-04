# Tasks: Execution References (tracked elsewhere)

This OpenSpec package is an architecture synthesis only. Execution remains tracked in the existing SAB migration, treasury/oracle, and gateway readiness issues.

## SAB migration program
- [ ] [CON-329](https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory) — control plane and dependency inventory

## Supabase phase-out (analytics)
- [ ] [CON-337](https://linear.app/conxian-labs/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service) — inventory current Supabase and Neon dependencies by service
- [ ] [CON-331](https://linear.app/conxian-labs/issue/CON-331/pilot-proof-carrying-analytics-for-treasury-and-oracle-workflows) — pilot proof-carrying analytics for treasury and oracle workflows

## Neon phase-out (transactional SQL)
- [ ] [CON-330](https://linear.app/conxian-labs/issue/CON-330/pilot-sovereign-transactional-sql-for-conxian-nexus) — pilot sovereign transactional SQL for `conxian-nexus`

## Institutional egress policy (read-only subledger export)
- [ ] [CON-161](https://linear.app/conxian-labs/issue/CON-161/extend-treasury-oracle-schema-for-external-settlement-logs) — extend treasury oracle schema for external settlement logs
- [ ] [CON-164](https://linear.app/conxian-labs/issue/CON-164/add-external-settlement-log-schema-in-treasury-oracle-repo) — add external settlement log schema in treasury oracle repo
- [ ] Treat [spec: Export field naming conventions](./specs/sovereign-data-migration-institutional-egress/spec.md#export-field-naming-conventions) as shared acceptance criteria for CON-161 and CON-164.

## Gateway readiness (non-egress)
- [ ] [CON-160](https://linear.app/conxian-labs/issue/CON-160/add-global-settlement-ingress-to-gateway) — add global settlement ingress to gateway (not an external-subledger write-path)
- [ ] [CON-162](https://linear.app/conxian-labs/issue/CON-162/enforce-proposal-only-external-settlement-triggers-in-tee) — enforce proposal-only external settlement triggers in TEE (no direct execution lane)
  - Shared acceptance criteria: `openspec/changes/external-settlement-proposal-only-tee/`.
