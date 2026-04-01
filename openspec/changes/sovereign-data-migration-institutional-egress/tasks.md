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

These tracks **MUST** enforce the canonical `snake_case` egress schema (including deprecated aliases and/or replacement datasets for field renames) and publish deterministic renderer mappings (for example ISO 20022) in version control alongside each dataset schema (see [spec: Export field naming conventions](./specs/sovereign-data-migration-institutional-egress/spec.md#export-field-naming-conventions)).

## Gateway readiness (non-egress)
- [ ] [CON-160](https://linear.app/conxian-labs/issue/CON-160/add-global-settlement-ingress-to-gateway) — add global settlement ingress to gateway (not an external-subledger write-path)
