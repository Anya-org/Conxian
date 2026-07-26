# ALEX Production Evidence Template

> **Fail-closed record for Issue #526.** This template records evidence for a
> proposed network-specific ALEX integration. It is not a launch approval,
> deployment plan, or authorization to enable production wiring.

## Authorization rule

Every required field and checklist item below must be complete, independently
reviewed, and linked to canonical evidence before this record can support a launch
decision. Blank, `TBD`, unknown, assumed, example, or unverified values **cannot
authorize generation, publish, registration, or routing** of any ALEX production
contract or transaction.

Discovery evidence establishes what an official source or live contract interface
reported at a specific time. Launch evidence additionally proves the selected
Conxian asset, listing, pool, liquidity, configuration, controlled transactions,
failure behavior, ownership, and rollback path. Discovery evidence is necessary,
but it is not a substitute for launch evidence.

## 1. Record and target

| Field | Required value |
| --- | --- |
| Evidence record owner | |
| Target network | |
| Verification timestamp (UTC) | |
| Proposed launch/change window (UTC) | |
| Conxian change/PR under review | |
| Related decision record | |

## 2. Discovery evidence

Record the exact retrieved material. Do not rely on an unversioned page title or a
principal copied from an earlier review.

| Official source | URL | Retrieved at (UTC) | SHA-256 or content-addressed digest | Archived/canonical copy |
| --- | --- | --- | --- | --- |
| ALEX network documentation | | | | |
| Swap helper interface | | | | |
| Swap helper source | | | | |
| Reserve interface | | | | |
| Reserve source | | | | |
| Pool interface/source | | | | |
| Wrapper/listing documentation | | | | |

### Interface compatibility review

- [ ] Selected helper principal and exact contract version recorded.
- [ ] Selected pool principal and exact contract version recorded.
- [ ] Selected reserve principal and exact contract version recorded.
- [ ] Function names, argument types, response types, traits, and optional values
      are compared with the proposed production implementation.
- [ ] The review explicitly accounts for live helper token-trait arguments and its
      optional `min-dy` shape where applicable.
- [ ] The review explicitly accounts for the selected reserve's actual reward and
      balance APIs rather than local fixture function names.
- [ ] Compatibility differences have reviewed implementation changes and focused
      tests; no simnet fixture ABI is treated as the live ABI.

Compatibility review link and conclusion:

<!-- Required: link to a reviewed diff/spec and state compatible or incompatible. -->

## 3. Conxian asset and listing route

| Field | Required value |
| --- | --- |
| Conxian token contract principal | |
| SIP-010 asset name | |
| Token decimals | |
| Wrapper/listing route | |
| Wrapper contract principal and version, if applicable | |
| Listing authority/owner | |
| Anchor asset contract and asset name | |
| Pair direction and symbols | |

Listing or wrapper rationale and reviewed source:

## 4. Selected ALEX contracts and launch parameters

| Field | Required value |
| --- | --- |
| Swap helper principal and exact version | |
| Pool principal and exact version/interface | |
| Reserve principal and exact version/interface | |
| Factor | |
| Token X weight | |
| Token Y weight | |
| Fee configuration | |
| Oracle principal, version, and parameters | |
| Start block and clock basis | |
| Owner/admin principal | |
| Conxian deployer principal | |
| Liquidity funding owner | |
| Initial token X liquidity | |
| Initial token Y liquidity | |

Parameter derivation, units, decimal normalization, and approval links:

## 5. On-chain setup evidence

Use canonical transaction and explorer links for the selected network. Explorer
links alone are insufficient if the transaction ID, final status, post-conditions,
and relevant receipt values are not also recorded.

| Action | Transaction ID | Canonical explorer link | Final status/block | Verified receipt/configuration |
| --- | --- | --- | --- | --- |
| Wrapper creation/configuration | | | | |
| Token listing | | | | |
| Pool creation | | | | |
| Initial token X funding | | | | |
| Initial token Y funding | | | | |
| Oracle/configuration transaction | | | | |
| Ownership/admin configuration | | | | |

- [ ] Each transaction targets the principals and asset names recorded above.
- [ ] Each transaction has final successful status on the selected network.
- [ ] Created pool/listing state matches the reviewed parameters exactly.
- [ ] Funding sources and resulting balances reconcile with the recorded amounts.

## 6. Controlled swap evidence

| Field | Required value |
| --- | --- |
| Controlled swap transaction ID | |
| Canonical explorer link | |
| Caller and recipient | |
| Input asset and amount | |
| Output asset | |
| Nonzero `min-dy` | |
| Helper and pool used | |
| Explicit transaction post-conditions | |
| Final status and block | |

### Before/after reconciliation

| Measurement | Before | After | Expected delta | Actual delta | Reconciled? |
| --- | --- | --- | --- | --- | --- |
| Caller input balance | | | | | |
| Recipient output balance | | | | | |
| Pool input reserve | | | | | |
| Pool output reserve | | | | | |
| Protocol/helper fee balance | | | | | |
| Other relevant balance | | | | | |

Fee calculation, reserve invariant/check, rounding, receipt events, and reconciliation
notes:

- [ ] `min-dy` is nonzero and derived from an approved quote/slippage policy.
- [ ] Post-conditions cap input movement and require the intended output movement.
- [ ] No unexpected asset movement is present in the receipt.
- [ ] Input/output balances, fees, and pool reserve changes reconcile.

## 7. Negative-path and rollback evidence

Record an on-chain transaction or reproducible controlled test for every path. A
description of expected behavior without evidence is incomplete.

| Scenario | Transaction/test ID | Canonical link/log | Expected result | Observed result | State/balance reconciliation |
| --- | --- | --- | --- | --- | --- |
| Insufficient output / `min-dy` rejection | | | | | |
| Paused pool | | | | | |
| Unavailable pool | | | | | |
| Failed helper call | | | | | |
| Rejected listing/configuration | | | | | |

- [ ] Failures leave no partial registration, routing, or unexpected asset movement.
- [ ] Disable/rollback action was exercised or demonstrated in a production-like
      environment without relying on a simnet-only API.
- [ ] Monitoring and operator escalation behavior are recorded.

## 8. Ownership, review, and rollback

| Field | Required value |
| --- | --- |
| Independent reviewer identity | |
| Independent review date (UTC) | |
| Review artifact/approval link | |
| Rollback/disable owner | |
| Rollback/disable runbook link | |
| Monitoring owner and dashboard/alerts | |
| Incident escalation channel/runbook | |

Reviewer attestation:

- [ ] I independently verified the selected network, principals, interfaces,
      parameters, transactions, balances, fees, reserves, and failure evidence.
- [ ] I found no placeholder, guessed, or simnet-only value used as launch evidence.
- [ ] I verified that production generation, publish, registration, and routing
      remain disabled until the separate launch decision is approved.

Reviewer name/signature and timestamp:

## 9. Final gate

- [ ] All required fields are complete and have canonical evidence links.
- [ ] Discovery evidence and launch evidence are clearly distinguished.
- [ ] Production implementation was reviewed against the exact selected live ABIs.
- [ ] Focused tests, release-plan drift checks, and security review pass.
- [ ] The launch decision explicitly authorizes the exact principals, versions,
      parameters, and transactions recorded here.

**Gate result:** `BLOCKED` unless every item above is complete and the separate
launch decision is approved. Completing this template alone does not publish,
register, route, deploy, or prove a production launch.
