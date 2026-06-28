# CON-762 partner scorecard artifacts — boundary decision

## Status: Migrated to Linear (ZSE)

All canonical partner scorecard data — baseline dimension scores, weighted partner scores, first-wave recommendations, scenario weight profiles, and build-vs-partner decisions — has been migrated to the Conxian Linear workspace under CON-762.

The CSV files in this directory tree are ZSE stubs retained for link continuity.

## Boundary decision record

- **Review**: Conxian/conxius-platform#1078 (2026-06-28)
- **Classification**: Not public-safe
- **Rationale**: The scorecard names specific commercial partners, reveals weighted procurement evaluation scores across multiple scenarios, and documents build-vs-partner architecture decisions. This is commercially sensitive procurement strategy.
- **Canonical location**: https://linear.app/conxian-labs/issue/CON-762
- **Git disposition**: CSV files retained as stubs; master spec retained as stub (`CON-762_PARTNER_SCORECARD_AND_SHORTLIST.md`)

## Do not re-populate

Future repo reviews should NOT re-create or re-populate the scorecard data in Git. The boundary decision recorded here is final under ZSE policy. If the partner shortlist changes, update Linear, not this directory.
