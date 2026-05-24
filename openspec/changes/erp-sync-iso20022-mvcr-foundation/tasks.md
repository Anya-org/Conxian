# Tasks: ERP sync + ISO 20022 mapping + MVCR artifact foundation (Milestone 1)

## Milestone 1 (this implementation)

- [x] Add deterministic settlement trigger identity helper.
- [x] Add deterministic ERP sync idempotency identity helper.
- [x] Add ISO 20022 mapping metadata + settlement reference extraction priority.
- [x] Add MVCR artifact datamodel and generator with JSON + Markdown rendering.
- [x] Integrate optional MVCR generation into `conxian-business/transparency_custodian.py`.
- [x] Add tests covering deterministic identity and MVCR success/failure behavior.

## Follow-on milestones

- [ ] Wire identity + MVCR generation into production gateway/nexus event ingestion surfaces.
- [ ] Expand ISO 20022 mapping coverage to additional message families and status flows.
- [ ] Add end-to-end integration tests across ERP sync + ISO mapping + MVCR output lineage.
