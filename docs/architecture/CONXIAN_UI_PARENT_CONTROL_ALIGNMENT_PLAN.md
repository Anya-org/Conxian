# CONXIAN_UI Parent Control Alignment Plan (CON-702)

## Checkpoint status

Implementation checkpoint created in `conxian-business` to lock role and boundary decisions for `Conxian_UI`.

Source issue: [CON-702 — Align Conxian_UI to parent control model](https://linear.app/conxian-labs/issue/CON-702/align-conxian-ui-to-parent-control-model)

## Decision summary

- `Conxian_UI` is a **supporting/reference UI surface**, not an authoritative parent control plane.
- Parent control authority remains in **private control/governance sources** and **core runtime systems**.
- `Conxian_UI` must consume approved/public outputs from authoritative systems.
- `Conxian_UI` must not own or operate secrets, signing keys, or privileged transaction/broadcast authority.

## Public/private boundary rules

### `Conxian_UI` may own/do

- Present user-facing views built from approved/public outputs.
- Provide interaction flows that submit user intent through approved service boundaries.
- Publish UI-level documentation, examples, and reference UX patterns.

### `Conxian_UI` must not own/do

- Hold, manage, or directly access secrets, custody keys, or signing keys.
- Act as source-of-truth for governance, policy, or privileged control state.
- Perform privileged signing, privileged transaction broadcast, or privileged automation execution.
- Introduce hidden control-plane mutations through undocumented admin paths.

### Enforcement rule

Any privileged action must be mediated by authoritative private control/governance and runtime systems; `Conxian_UI` remains a consumer/presentation boundary.

## Control ownership mapping

| Control domain | Authoritative repo/system | `Conxian_UI` role |
| --- | --- | --- |
| Governance policy, approvals, control definitions | Private governance/control sources in `conxian-business` + internal governance systems | Consume approved/public policy outputs only |
| Secret and key custody | Signer-boundary systems (enclave/HSM/custody controls) | No ownership, no direct access |
| Privileged signing authority | Core runtime signer flows and governed execution paths | No signing authority |
| Privileged transaction/broadcast authority | Core runtime systems and governed automation services | No privileged broadcast authority |
| Canonical operational truth | Core protocol/runtime systems of record | Display derived/read-only views |
| Public transparency artifacts | Public-safe docs, release notes, approved APIs/feeds | Consume and present |

## Intended file-level changes in this checkpoint (this repo)

- `docs/architecture/CONXIAN_UI_PARENT_CONTROL_ALIGNMENT_PLAN.md` (new anchor/checkpoint doc)
- `docs/architecture/NEXUS_AND_UI_ROLE_DECISION_RECORD.md` (add CON-702 resolution section)
- `docs/architecture/FULL_SCOPE_IMPLEMENTATION_CHECKLIST.md` (replace generic `conxian_ui` review with concrete CON-702 tasks)
- `docs/REPO_PORTFOLIO.md` (remove flagship contradiction; align `Conxian_UI` classification)
- `CHANGELOG.md` (record checkpoint)

## Execution checklist (near-term) with evidence placeholders

- [x] Publish this CON-702 checkpoint package in `conxian-business`.
  - Evidence: _commit link/SHA in this repo_
- [ ] Update `Conxian_UI` GitHub description + README role line to supporting/reference UI wording.
  - Evidence: _PR link and merged commit in `Conxian_UI`_
- [ ] Add explicit boundary section in `Conxian_UI` docs: no secrets/keys/privileged signing/broadcast ownership.
  - Evidence: _doc path + PR link in `Conxian_UI`_
- [ ] Verify `Conxian_UI` dependencies are approved/public outputs only.
  - Evidence: _dependency inventory path + review checklist artifact_
- [ ] Add release/governance checkpoint to reject privileged control-plane coupling in `Conxian_UI`.
  - Evidence: _updated checklist/policy link_

## Completion evidence log (template)

| Task | Artifact link | Status |
| --- | --- | --- |
| Checkpoint docs published in `conxian-business` | _TBD_ | In progress |
| `Conxian_UI` role line updated | _TBD_ | Pending |
| `Conxian_UI` boundary doc update merged | _TBD_ | Pending |
| Dependency/public-output verification complete | _TBD_ | Pending |
| Governance gate/checkpoint updated | _TBD_ | Pending |
