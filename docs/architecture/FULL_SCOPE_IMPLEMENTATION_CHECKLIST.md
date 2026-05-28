# Full Scope Implementation Checklist

## Purpose

This checklist tracks the end-to-end alignment work across strategy, architecture, repo roles, documentation, and future cleanup.

## Completed or in progress

- strategy docs for Bitcoin-layer support
- repo alignment plan
- repo boundary overlap audit
- repo boundary decision record
- portfolio alignment baseline preserving strongest existing work
- role decision record for `conxian-nexus` and `conxian_ui`
- repo ownership docs for strategic repos
- role alignment docs for `conxian-nexus` and `conxian_ui`

## Remaining implementation path

### Architecture and strategy

- [ ] merge all active architecture PRs in `conxian-business`
- [ ] cross-link older portfolio docs to newer authority docs

### Repo-local docs

- [ ] merge strategic repo ownership PRs
- [ ] merge supporting repo role-alignment PRs
- [ ] update any remaining supporting repos with ownership docs where helpful

### Code placement cleanup

- [ ] audit `lib-conxian-core` for adapter leakage
- [ ] audit `conxian-gateway` for non-gateway concerns
- [ ] audit `conxius-wallet` for infrastructure overlap
- [ ] audit `Conxian` for mixed gateway or app concerns
- [ ] audit `conxius-platform` for catch-all drift
- [ ] audit `conxian-nexus` for gateway overlap
- [ ] execute CON-702 `Conxian_UI` parent-control alignment checkpoint
- [ ] set `Conxian_UI` public role line to supporting/reference UI surface (not parent control plane)
- [ ] document boundary that `Conxian_UI` owns no secrets, signing keys, or privileged transaction/broadcast authority
- [ ] verify `Conxian_UI` consumes approved/public outputs from authoritative systems and capture evidence in `docs/architecture/CONXIAN_UI_PARENT_CONTROL_ALIGNMENT_PLAN.md`

### Release and narrative alignment

- [ ] apply release standard to strategic repos
- [ ] align public repo descriptions with the builder-platform thesis
- [ ] update site and public portfolio narrative incrementally

### Layer implementation roadmap

- [ ] define concrete milestones for Bitcoin mainnet support
- [ ] define concrete milestones for Lightning support
- [ ] define concrete milestones for Stacks support
- [ ] define secondary milestones for Rootstock and Liquid adapters

### Emerging rails (Research-lane baseline)

- [ ] register each emerging-rail intake with a maturity lane (`Build-now`, `Pilot`, `Partner`, `Research`)
- [ ] apply and record the required default (`Research`) when lane is unspecified
- [ ] capture required intake fields: rail scope, target adapter interface, owner, review cadence, risk register, and promotion blockers
- [ ] define lane-promotion evidence for each candidate rail (`Research -> Pilot` at minimum)
- [ ] align `conxian-gateway` implementation handoff with `conxius-platform` harness/runtime and observability evidence

## Working rule

For all remaining work:

- read existing material first
- preserve the strongest current work
- converge on one portfolio direction
- do not create duplicate narratives or hidden ownership

## Summary

This checklist is the implementation spine for the approved full scope.
