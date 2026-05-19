# Repo Boundary Overlap Audit

## Purpose

This audit identifies boundary overlap across the current Conxian repository portfolio and recommends what should be kept, moved, split, demoted, or clarified.

This is the first execution pass following approval of the Bitcoin-layer capability strategy and builder-platform positioning.

## Strategic assumption

Conxian is aligning toward:

- builder enablement
- Bitcoin mainnet and Bitcoin-connected layer support
- shared capability infrastructure
- secure signing and trust abstractions
- reference clients rather than consumer-service primacy

The audit therefore evaluates repositories against that direction, not against a full-stack financial-service strategy.

## Repos reviewed

Primary focus:

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-wallet`
- `Conxian`
- `conxius-platform`
- `conxian-nexus`

Supporting context:

- `conxius-enclave-sdk`
- `conxius-orbit`
- `.github`
- `conxian-business`

## Top findings

### 1. Shared core is not yet fully isolated

`lib-conxian-core` is correctly positioned as a shared core repository, but it appears to contain gateway-related areas.

Implication:
- shared primitives and integration logic are not yet cleanly separated
- future adapter work may drift into core rather than staying behind clear interfaces

Recommendation:
- keep `lib-conxian-core` as a primary strategic repo
- move any provider, network-adapter, or gateway runtime code out of core
- leave behind:
  - capability interfaces
  - safety and verification primitives
  - shared data models
  - signer policy abstractions

### 2. Gateway concerns appear in more than one repo

`conxian-gateway` is the most natural home for integration and adapter logic, but gateway-related code or directories also appear elsewhere, including `Conxian` and `conxius-wallet`, and gateway-related areas appear to exist in `lib-conxian-core`.

Implication:
- builder-facing adapter ownership is ambiguous
- future contributors will struggle to know where Bitcoin, Lightning, Stacks, or external provider integration actually belongs

Recommendation:
- make `conxian-gateway` the canonical home of:
  - network adapters
  - provider integrations
  - broadcast and observation service boundaries
  - bridge and interoperability logic
- remove duplicate or adjacent gateway logic from:
  - `Conxian`
  - `conxius-wallet`
  - `lib-conxian-core`

### 3. `conxius-wallet` is carrying too much strategic weight

`conxius-wallet` contains the strongest signs of boundary leakage.

Observed signals:
- adjacent module references
- gateway references
- broad documentation footprint
- signs of serving as more than a reference client

Implication:
- portfolio gravity could pull back toward a wallet-company identity
- infrastructure and builder-platform positioning becomes less credible

Recommendation:
- reframe `conxius-wallet` as a reference client and validation surface
- keep:
  - interaction patterns
  - signer UX examples
  - layer capability demos
- move out or deprecate:
  - embedded integration logic
  - infrastructure concerns
  - shared-core behavior that should live below it

### 4. `Conxian` lacks a single unambiguous role

The `Conxian` repository appears to carry protocol identity, documentation, and adjacent executable concerns.

Implication:
- unclear whether it is:
  - the canonical protocol repo,
  - an umbrella reference repo,
  - or a mixed system repo

Recommendation:
- choose one of two roles:

Option A: protocol-first repo
- keep protocol specs, contracts, and canonical reference artifacts
- remove gateway and app-adjacent concerns

Option B: umbrella reference repo
- keep broad documentation and examples
- avoid owning active adapter/runtime logic

Current recommendation:
- favor **protocol-first repo** if long-term protocol credibility matters more than umbrella convenience

### 5. `conxius-platform` risks becoming the catch-all

`conxius-platform` is explicitly framed as the full ecosystem spun up locally for development.

That is useful, but dangerous if not bounded.

Implication:
- platform can silently absorb responsibilities that belong in core or gateway
- documentation, scripts, maintenance tools, and integration logic can accumulate here until it becomes the real center of gravity

Recommendation:
- keep `conxius-platform` as:
  - composition environment
  - local integration harness
  - test/runtime orchestration surface
- do not let it become the canonical home of logic
- use it to consume strategic repos, not replace them

### 6. `conxian-nexus` needs sharper definition

The current repo shape suggests `conxian-nexus` may act as an API bridge or interoperability surface, but its distinction from `conxian-gateway` is not crisp enough.

Implication:
- two adjacent integration repos can create duplication and ambiguity

Recommendation:
- explicitly choose whether `conxian-nexus` is:
  - a public API facade,
  - an internal interoperability service,
  - or an unnecessary overlap with gateway
- if overlap is substantial, narrow or merge

### 7. Governance is stronger than boundary discipline

The portfolio now shows much better governance hygiene than the earlier public review indicated.

Positive signals:
- `.github` baseline exists
- major repos generally have:
  - README
  - CONTRIBUTING
  - SECURITY
  - LICENSE
  - CODEOWNERS in many cases
- `conxian-business` is private

Implication:
- the next maturity problem is not baseline governance
- the next maturity problem is architectural and ownership discipline

### 8. Documentation is distributed too close to execution surfaces

A number of repos appear to carry significant strategy, alignment, taxonomy, audit, and operations material alongside code.

Implication:
- product repos are serving as execution surfaces and planning archives at the same time
- this makes repo purpose less clear

Recommendation:
- keep essential developer docs in code repos
- move portfolio-wide strategy, taxonomy, and governance alignment docs to `conxian-business` or another intentional planning home

## Repo-by-repo assessment

## `lib-conxian-core`

**Keep**
- yes

**Classification**
- primary strategic repo

**Should own**
- shared capability interfaces
- transaction and policy models
- cross-layer safety abstractions
- verification primitives

**Should not own**
- gateway runtime logic
- provider-specific adapters
- consumer product behavior

**Recommendation**
- keep / narrow / harden boundary

## `conxian-gateway`

**Keep**
- yes

**Classification**
- primary strategic repo

**Should own**
- adapter boundaries
- network/provider integrations
- observation and broadcast service edges
- bridge and interoperability logic

**Should not own**
- wallet UX
- shared-core ownership
- portfolio-wide strategy docs

**Recommendation**
- keep / strengthen as canonical integration layer

## `conxius-wallet`

**Keep**
- yes, but reposition

**Classification**
- reference repo

**Should own**
- reference interaction flows
- demo UX
- integration examples
- validation surface for signer and layer support

**Should not own**
- infrastructure logic
- duplicated adapter code
- strategic portfolio center

**Recommendation**
- keep / demote / narrow boundary

## `Conxian`

**Keep**
- yes

**Classification**
- protocol-first or umbrella, must choose

**Should own**
- protocol identity if chosen as protocol repo
- canonical specs and reference artifacts if chosen as umbrella repo

**Should not own**
- overlapping gateway runtime logic if protocol-first
- mixed execution concerns if umbrella repo

**Recommendation**
- keep / clarify / narrow scope

## `conxius-platform`

**Keep**
- yes

**Classification**
- primary strategic repo, but only as composition/runtime

**Should own**
- local orchestration
- integration harnesses
- observability and test environment setup

**Should not own**
- canonical business logic
- duplicated core logic
- strategic drift into catch-all ownership

**Recommendation**
- keep / narrow / enforce consumption-over-ownership

## `conxian-nexus`

**Keep**
- undecided until clarified

**Classification**
- supporting repo, pending purpose clarification

**Should own**
- only the API or interoperability role if distinct from gateway

**Should not own**
- duplicated gateway concerns

**Recommendation**
- clarify / narrow / possibly merge or demote

## `conxius-enclave-sdk`

**Keep**
- yes

**Classification**
- primary strategic repo

**Recommendation**
- keep focused on secure signer and device trust concerns
- avoid strategic drift into unrelated orchestration or app concerns

## `conxius-orbit`

**Keep**
- yes

**Classification**
- supporting repo

**Recommendation**
- keep tool-focused and deployment-focused
- do not let it become a general platform repo

## Dependency direction recommendation

Target dependency direction should be:

- `conxius-wallet` -> `lib-conxian-core`, `conxian-gateway`, `conxius-enclave-sdk`
- `conxius-platform` -> composes strategic repos
- `conxian-gateway` -> depends on `lib-conxian-core`
- `conxian-nexus` -> only if clearly distinct, depends on gateway/core as appropriate
- `lib-conxian-core` -> minimal or no upward dependency on product surfaces
- `Conxian` -> depends on chosen role; should not silently become integration owner

## Recommended actions by urgency

### Priority 1

- clarify the role of `Conxian`
- establish `conxian-gateway` as the canonical integration layer
- prevent `lib-conxian-core` from carrying adapter logic
- reframe `conxius-wallet` as a reference client

### Priority 2

- narrow `conxius-platform` to runtime composition
- clarify whether `conxian-nexus` is distinct enough to keep separate
- move portfolio-wide strategy and taxonomy docs to intentional planning homes

### Priority 3

- update repo READMEs with one-sentence ownership boundaries
- standardize dependency direction in architecture docs
- update public narrative to reflect builder-platform positioning

## Proposed keep / move / split / demote summary

| Repo | Recommendation |
| --- | --- |
| `lib-conxian-core` | Keep, narrow, remove gateway-specific logic |
| `conxian-gateway` | Keep, strengthen as canonical adapter/integration layer |
| `conxius-wallet` | Keep, demote to reference client role |
| `Conxian` | Keep, choose protocol-first or umbrella role and narrow scope |
| `conxius-platform` | Keep, narrow to composition/runtime role |
| `conxian-nexus` | Clarify role, narrow or merge if overlapping |
| `conxius-enclave-sdk` | Keep, stay focused on signing/device trust |
| `conxius-orbit` | Keep, maintain tool-focused purpose |

## Suggested next tasks

1. convert this audit into a boundary decision record
2. update strategic repo READMEs with ownership statements
3. perform code-placement audit in the affected repos
4. decide the future role of `Conxian`
5. decide the future role of `conxian-nexus`

## Summary

The portfolio already has the right ingredients for a builder platform supporting Bitcoin mainnet and Bitcoin-connected layers.

The main problem is no longer missing repos or missing governance.

The main problem is **overlap**:

- core versus gateway
- gateway versus wallet
- protocol versus umbrella
- platform versus everything else

Cleaning up those boundaries is the highest-leverage next step because it will make the implementation roadmap, mainnet support work, and public positioning all much clearer.