# ADR-007: Proposed Partnership Edge-Policy Baseline

- **Status:** Proposed
- **Date:** 2026-07-26
- **Decision issue:** [GitHub issue #527](https://github.com/Conxian/Conxian/issues/527)
- **Parent:** [GitHub issue #496](https://github.com/Conxian/Conxian/issues/496)
- **Maintainer direction:** [Issue comment 5084157157](https://github.com/Conxian/Conxian/issues/527#issuecomment-5084157157)
- **Supersedes:** Nothing

## 1. Decision status and intent

This record proposes a safe baseline for interpreting “basic network vars” in
the maintainer direction. In this record, those variables are a **versioned
partnership edge-policy object**: deterministic policy identifiers, scope,
asset, accounting, authorization, lifecycle, and approval fields used at the
integration or Gateway boundary.

They are **not** operating-system environment variables, deployment secrets,
private keys, contract addresses, a request to modify a live network, or proof
that any partnership route is approved or active.

`Proposed` is deliberate. The repository can safely record deny-by-default
technical behavior without inferring commercial, legal, compliance, tax,
treasury, security, or launch approval. Community members, governance, and
agents may refine future versions only within the authority boundaries below.

## 2. Current architecture boundary

The intended boundary is edge-regulated and protocol-neutral:

1. The integration, Gateway, or regulated-partner edge selects and enforces an
   approved, versioned commercial and jurisdiction policy.
2. Authorized reporters submit authenticated facts, not policy choices.
3. Partnership accounting consumes a typed policy identifier/version/hash and
   immutable snapshots rather than raw KYC, sanctions, legal, tax, or customer
   due-diligence data.
4. Generic protocol revenue primitives remain jurisdiction-neutral.

This is a target architecture, not a claim that the full path exists today.
The current code has mixed compliance enforcement, and the integration fee
path is not yet bound to a complete multi-jurisdiction edge-policy attestation.

### 2.1 Legacy compatibility boundary

[Merged PR #514](https://github.com/Conxian/Conxian/pull/514) remains the
legacy-compatible route:

- STX only;
- reporter-authorized, replay-protected usage accounting;
- `4320` burn-block periods for its monthly billing mode;
- exact payer settlement; and
- 100% routing to protocol revenue through the existing distributor path.

This proposal does not reinterpret, migrate, or activate a partner split in
that route. Partnership settlement is a **separate future versioned route**
that must preserve explicit compatibility and migration boundaries.

## 3. Proposed baseline parameters

The classification column prevents safe technical defaults from being
mistaken for commercial or legal approval.

| Parameter | Proposed baseline | Classification | Approval state |
| --- | --- | --- | --- |
| Policy status | `draft` / inactive | Safe technical default | Baseline-decided for a proposal |
| Network scope | No active network; network allowlist is empty | Safe technical default | Baseline-decided |
| Activation identity | A non-empty immutable `policy-id`, monotonic `policy-version`, and canonical `policy-hash` are required before activation | Safe technical default | Baseline-decided; hash schema requires implementation review |
| Asset scope | STX-only MVP, denominated and settled in microSTX; no SIP-010 assets in v1 | Safe technical scope default | Proposed pending Protocol, Treasury, and Commercial approval |
| Closed period | `4320` burn blocks | Deterministic technical candidate | Proposed pending Commercial and Operations approval; this is **not a calendar-month guarantee** because burn-block time varies |
| Reporter | Only the reporter authorized by immutable registration/policy state may submit facts | Safe technical default | Baseline-decided |
| Policy binding | Bind the approved policy at registration; snapshot policy and payout inputs at accrual; revalidate status, expiry, revocation, scope, and authorization at settlement | Safe technical default | Baseline-decided |
| Failure behavior | Fail closed on missing, draft, stale, expired, revoked, unapproved, unsupported, mismatched, or unverifiable policy/scope/attestation state | Safe technical default | Baseline-decided |
| Fee base | Candidate: the actual partnership fee accrued under the approved policy, in the settlement asset’s atomic units; usage and economic volume are recorded separately and are not themselves split | Proposed commercial default | Pending Commercial, Treasury, Legal/Compliance, Tax, and Accounting approval; authoritative measurement source remains unset |
| Split | Inactive candidate only: `partner-bps = 5000`, `protocol-bps = 5000` | Proposed commercial default | Not approved; requires named Commercial, Treasury, Legal/Compliance, Tax, and partner-side approval |
| Rounding and dust | Candidate: `partner = floor(fee * partner-bps / 10000)`; `protocol = fee - partner`; protocol receives the deterministic remainder and no unit is unaccounted | Safe deterministic accounting candidate applied to an unapproved split | Pending Treasury, Accounting, Commercial, and Protocol approval |
| Beneficiaries | Derive partner and protocol beneficiaries from approved versioned policy/registry state; never from a usage report | Safe technical default | Baseline-decided structurally; beneficiary principals remain unset |
| Payer | Derive the authorized payer from registration/policy state | Safe technical default | Baseline-decided structurally; payer remains unset per integration |
| Corrections before settlement | Permit only authorized, replay-protected correction records with an audit link to the original fact; never rewrite history silently | Safe technical default | Baseline-decided; operational window pending approval |
| Refunds, chargebacks, and post-settlement corrections | Use auditable compensating adjustments under the approved agreement; do not mutate settled records retroactively and do not assume an automatic on-chain clawback | Safe accounting default | Allocation, liability, limits, and timing pending Commercial, Legal, Tax, Treasury, and Operations approval |
| Permitted jurisdictions | Empty allowlist | Unset human-controlled legal/compliance value | No jurisdiction is approved |
| Prohibited jurisdictions | Unset except where authoritative controls independently require denial | Unset human-controlled legal/compliance value | Requires Legal/Compliance approval; empty permitted scope still denies all activation |
| KYC/AML/sanctions/travel-rule requirements | Unset policy references; raw customer data must not enter the generic fee route | Unset human-controlled legal/compliance value plus safe data-minimization default | Requires Legal/Compliance and Security approval |
| Legal roles and agreement reference | Unset | Unset human-controlled legal value | Requires Legal/Jurisdiction and partner approval |
| Tax/VAT/withholding/revenue-recognition treatment | Unset | Unset human-controlled tax/accounting value | Requires Tax and Accounting approval |
| Effective period, expiry, renewal, and revocation authority | No effective period while draft; activation requires explicit future values and authorized signers/owners | Safe technical default with human-controlled values | Values and owners remain unset |
| Launch/deployment state | Disabled; no deployment or live activation authorized | Safe technical default | Baseline-decided |

The `5000/5000` basis-point split is therefore only a reviewable candidate. It
must not be represented as approved policy, a Stacks requirement, existing
contract behavior, or a mandate to change PR #514.

## 4. Edge-policy object

A future implementation should make the approved policy object canonical and
hashable. Exact field encoding belongs to [issue #528](https://github.com/Conxian/Conxian/issues/528),
but the baseline object must cover at least:

| Field group | Required content |
| --- | --- |
| Identity | Policy ID, monotonically increasing version, canonical schema version, canonical hash, prior-version reference |
| Lifecycle | Draft/approved/active/suspended/revoked/expired state, effective burn-block, expiry, revocation reason/reference, replacement version |
| Scope | Explicit network allowlist, integration/partner identifier, asset allowlist, billing mode, permitted jurisdictions, prohibited combinations |
| Parties | Registered owner, payer, reporter, partner beneficiary, protocol beneficiary; every change occurs through a new version where it can affect accrual |
| Accounting | Authoritative measurement source, usage fact schema, economic-volume schema, fee-base formula, atomic units/decimals, split basis points, rounding/dust rule |
| Controls | Replay namespace, attestation type, freshness/expiry, correction window, settlement cadence, closed-period rule, pause/revocation behavior |
| Legal/compliance/tax | Agreement/evidence reference or hash, legal-role classification, KYC/AML/sanctions/travel-rule policy references, tax treatment references, approved jurisdictions |
| Authority evidence | Approval roles, approval artifact references, signer/key version, governance proposal and timelock references where applicable |

### 4.1 Reporter boundary

An authorized reporter may submit only authenticated facts defined by the
policy, such as a source-event identifier, usage quantity, measured economic
volume, event time/height, and evidence reference. The policy determines which
facts are authoritative and how a fee is derived.

A reporter must **never** choose or override:

- partner or protocol beneficiary;
- payer;
- split basis points or fee formula;
- jurisdiction or legal classification;
- policy ID, version, or hash used for the registered integration;
- settlement asset or decimal interpretation; or
- activation, expiry, suspension, or revocation state.

## 5. Immutable-at-accrual snapshot

Every accrued obligation must retain an immutable snapshot sufficient to
reproduce its interpretation and payout:

- integration/partner and period identifiers;
- source-event identifier and reporter identity;
- policy ID, version, schema version, and hash;
- network and asset identifier, atomic-unit amount, and decimal convention;
- authoritative fee-base facts and derived fee amount;
- payer and both beneficiaries;
- protocol and partner basis points;
- rounding/dust rule and calculated shares;
- jurisdiction-policy reference, without raw personal compliance data;
- accrual height/time evidence and correction lineage; and
- policy approval/evidence references needed for audit.

Registration binds the policy version. Accrual snapshots it. Settlement must
then revalidate that the integration, reporter, network, asset, policy, and
attestation are still settleable. Revocation may block new accrual and/or
settlement according to the approved revocation mode, but it must not silently
delete debt or rewrite historical snapshots.

## 6. Lifecycle, governance, and revocation

1. **Draft:** inactive, empty network/jurisdiction allowlists, no accrual or
   settlement.
2. **Approved:** all required human approvals and evidence are attached, but
   activation is still a separate controlled action.
3. **Active:** activation occurs only after implementation, tests, timelock,
   deployment receipts, configured monitoring, and launch approval exist.
4. **Suspended:** reject new accrual fail-closed; settlement of existing debt is
   allowed only if the approved policy explicitly permits it.
5. **Revoked/expired:** reject new accrual; preserve historical records and
   follow the approved debt, refund, and compensating-adjustment procedure.
6. **Replacement:** publish a new immutable version. Never mutate an effective
   version or apply a replacement retroactively to prior accruals.

Governance may activate or replace only an approval-complete policy version,
within contractually bounded fields and after the approved timelock. Governance
cannot manufacture legal, tax, compliance, security, partner, or treasury
approval by itself. Emergency authority may fail closed sooner, but reopening
or broadening scope requires the normal approval and timelock path.

## 7. Authority matrix

| Actor | May do | Must not do |
| --- | --- | --- |
| Community | Propose parameters, evidence, risk findings, and new policy versions; review public audit records | Activate policy, approve legal/tax/compliance terms, mutate effective versions, or submit privileged facts without authorization |
| DAO/governance | Approve bounded protocol configuration for a future version after prerequisite human approvals; apply timelocked activation/suspension/revocation controls | Retroactively mutate accruals, override required specialist approvals, or let reporters select policy/payout fields |
| Agents | Research, simulate, recommend, monitor drift, verify deterministic constraints, and propose fail-closed actions | Sign legal/commercial agreements, infer approvals, hold unilateral activation authority, or silently tune economic/legal fields |
| Commercial owner role | Approve fee base, pricing/split, partner economics, payer/beneficiary semantics, disputes, and agreement compatibility | Override legal, compliance, tax, treasury, security, or governance controls |
| Legal/Jurisdiction owner role | Approve legal roles, agreement form, permitted jurisdictions, liability, corrections/refunds/chargebacks, and evidence obligations | Approve technical deployment or treasury custody alone |
| Compliance owner role | Approve KYC/AML, sanctions, travel-rule, eligibility, attestation, retention, and revocation requirements | Select commercial beneficiaries or waive unrelated tax/security controls |
| Tax/Accounting owner role | Approve tax/VAT/withholding, fee classification, gross/net treatment, revenue recognition, and accounting evidence | Activate contracts or select reporters alone |
| Treasury owner role | Approve assets, custody, payer/beneficiary destinations, reconciliation, rounding/dust, liquidity, and compensating-adjustment operations | Change legal scope or bypass governance/contract authorization |
| Security owner role | Approve authentication, signer/key lifecycle, attestation, replay protection, incident controls, monitoring, and release security evidence | Approve commercial/legal terms or expand scope alone |
| Protocol owner role | Approve contract invariants, versioning, migration compatibility, test evidence, and implementation readiness | Treat technical readiness as commercial/legal approval |
| Operations/Reconciliation owner role | Approve cadence, close procedures, correction operations, reconciliation, alerts, and runbooks | Rewrite immutable history or activate without upstream approvals |
| Partner authorized approver role | Approve partner beneficiary, reporter/payer responsibilities, agreement terms, and operational obligations | Alter protocol governance or other partners’ policies |

The exact accountable people or entities for these roles are intentionally
unset. They must be named in approval artifacts before status can advance.

## 8. Acceptance-criteria mapping for issue #527

| #527 acceptance criterion | Baseline status | Remaining owner roles / decision |
| --- | --- | --- |
| Define usage versus economic volume and authoritative source | **Proposed pending approval** | Record both separately; candidate fee base is the derived partnership fee. Commercial, Accounting, Operations, and Protocol must approve the authoritative source and formula. |
| Approve 50/50 applicability, fee base, beneficiary, payer, and reporter semantics | **Proposed pending approval** | `5000/5000` candidate applies only to the actual fee; partner floor/protocol remainder. Commercial, Treasury, Legal/Compliance, Tax, Partner, and Protocol approval required. |
| Decide STX-only MVP versus SIP-010 | **Proposed pending approval** | STX-only microSTX baseline; Protocol, Treasury, and Commercial approval required. SIP-010 remains future-version work. |
| Decide cadence and period boundaries | **Proposed pending approval** | `4320` burn-block closed period candidate; Commercial and Operations must accept that it is not a calendar-month guarantee. |
| Define rounding, dust, refunds, and chargebacks | **Partly baseline-decided; partly proposed/unresolved** | Deterministic partner-floor/protocol-remainder candidate and compensating-adjustment model recorded. Treasury, Accounting, Commercial, Legal, Tax, and Operations must approve allocation and windows. |
| Define reporter authorization, correction, and liability | **Partly baseline-decided; partly unresolved** | Authorized-facts-only and replay-protected correction lineage are baseline-decided. Reporter identity, liability, evidence, and correction window require Security, Operations, Legal, Commercial, and Partner approval. |
| Define authoritative edge-policy object | **Baseline-decided structurally** | Required field groups and immutable identity/version/hash are defined. Exact schema and human-controlled values remain for #528 and specialist approval. |
| Decide policy-selection stages | **Baseline-decided** | Bind at registration, snapshot at accrual, revalidate at settlement. |
| Require fail-closed behavior | **Baseline-decided** | Missing/invalid/unsupported/stale/revoked/unapproved state denies progress. |
| Prevent reporter policy/payout mutation | **Baseline-decided** | Explicit reporter prohibition is recorded and must be enforced/tested. |
| Decide on-chain version/hash plus off-chain matrix/agreement | **Proposed pending approval** | Use canonical version/hash and evidence references; Legal, Compliance, Tax, Security, and Protocol must approve artifact form, signer, and retention. |
| Name legal, compliance, tax, and jurisdiction owners | **Unresolved** | Accountable role categories are named; actual authorized people/entities must still be designated. |
| Preserve neutral-core / regulated-edge invariant | **Baseline-decided** | The edge supplies typed authorized policy evidence; generic fee/revenue primitives do not store raw legal/customer data. Implementation verification remains. |
| Keep partnership settlement separate from PR #514 | **Baseline-decided** | Legacy STX-only 100%-protocol route remains unchanged; future partnership route is separately versioned. |
| Publish immutable decision record | **Proposed pending approval** | This versioned repository record is immutable through Git history, but it remains `Proposed`; acceptance requires explicit approval and a successor/status change. |

## 9. Implementation handoff

Implementation remains ordered and gated:

1. [Issue #528](https://github.com/Conxian/Conxian/issues/528) defines the
   registry and immutable versioned policy schema, authorization, lifecycle,
   audit getters, and compatibility boundary.
2. [Issue #529](https://github.com/Conxian/Conxian/issues/529) implements the
   fact ledger, immutable accrual snapshots, checked arithmetic, replay-safe
   corrections, deterministic split/dust behavior, atomic settlement, and
   reconciliation.
3. [Issue #530](https://github.com/Conxian/Conxian/issues/530) implements the
   Gateway/SDK authorization boundary, typed calls, client post-conditions,
   indexing, retry/idempotency behavior, and end-to-end evidence.

Each child must preserve the no-retroactive-mutation rule and must test that a
reporter cannot choose a beneficiary, split, jurisdiction, policy, or asset.

## 10. No-go activation statement

This ADR does not authorize contract changes, addresses, secrets, signing,
broadcast, testnet/mainnet activation, capitalization, or partner settlement.

**No partnership policy may be activated or deployed** until all commercial,
partner, legal/jurisdiction, compliance, tax/accounting, treasury, security,
protocol, and operations approvals are attached to an immutable policy
version; governance/timelock requirements are satisfied; implementation and
independent review are complete; and launch evidence includes exact network,
deployer, contract identifiers, confirmed transaction receipts, interface and
read-only verification, reconciliation, monitoring, and pause/rollback proof.

Repository plans, workflow success, issue status, or this proposed record are
not deployment proof.

## 11. Canonical references

- [Parent commercialization workstream #496](https://github.com/Conxian/Conxian/issues/496)
- [Policy decision #527](https://github.com/Conxian/Conxian/issues/527)
- [Versioned registry implementation #528](https://github.com/Conxian/Conxian/issues/528)
- [Usage ledger and settlement #529](https://github.com/Conxian/Conxian/issues/529)
- [Gateway, SDK, and indexing #530](https://github.com/Conxian/Conxian/issues/530)
- [Related protocol-fee policy #488](https://github.com/Conxian/Conxian/issues/488)
- [Related enterprise subscription issue #503](https://github.com/Conxian/Conxian/issues/503)
- [Related registration fee issue #504](https://github.com/Conxian/Conxian/issues/504)
- [Legacy integration settlement PR #514](https://github.com/Conxian/Conxian/pull/514)
- [Architecture boundary](ARCHITECTURE.md)
- [Commercialization gates](COMMERCIALIZATION_GATES.md)
- [Funding and economics](FUNDING_AND_ECONOMICS.md)
- [Revenue analysis](REVENUE_ANALYSIS.md)
- [Integration module](../contracts/integrations/README.md)
- [Current integration registry](../contracts/integrations/integration-registry.clar)
- [Current integration fee collector](../contracts/integrations/integration-fee-collector.clar)
- [Protocol narrowing boundary](../CXIP-014.md)
