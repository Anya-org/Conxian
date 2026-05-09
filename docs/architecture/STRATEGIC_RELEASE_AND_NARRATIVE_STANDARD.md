# Strategic Release and Narrative Standard

## Purpose

This document standardizes release discipline and public-facing narrative across the Conxian portfolio after adoption of the builder-platform strategy.

## Strategic narrative standard

Conxian should be described as:

- infrastructure for builders
- native support tooling for Bitcoin mainnet and Bitcoin-connected layers
- a platform for capability interfaces, secure signing, integration quality, and reference implementations

Conxian should not be described primarily as:

- a direct full-service financial operator
- a generic consumer wallet company
- a clone of every upstream SDK or application layer

## Public repo narrative guidance

### Primary strategic repos

Each should clearly state:

- what layer of the platform it owns
- what it does not own
- how it relates to the rest of the portfolio

### Reference repos

Each should clearly state:

- that it is a reference or example surface
- that canonical integration logic lives below it

### Supporting repos

Each should clearly state:

- its narrow supporting role
- the strategic repo it sits above, beside, or in front of

## Release standard

### Applies strongly to

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-enclave-sdk`
- `conxius-platform`

### Recommended for

- `conxian-nexus`
- `conxius-orbit`
- `Conxian` where versioned protocol artifacts are relevant

## Minimum release expectations

- versioned tags
- release notes
- changelog maintenance
- compatibility or upgrade notes where needed

## Release note template guidance

Each release should answer:

- what changed
- what layer or capability was affected
- whether this is breaking or non-breaking
- whether builders need to change integrations
- whether security, signer, or verification behavior changed

## Narrative consistency rule

Whenever repo READMEs, site copy, or portfolio docs are updated:

- align the wording to the builder-platform thesis
- preserve the strongest older messaging where still true
- avoid creating a parallel narrative that re-centers the portfolio on consumer service identity

## Summary

Release discipline and public narrative should make the portfolio look coherent:

- strategic repos look like builder infrastructure
- reference repos look like reference surfaces
- supporting repos look narrow and intentional
- the org story reinforces Bitcoin-layer support rather than drifting back into a blended identity