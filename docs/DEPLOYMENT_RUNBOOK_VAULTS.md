# Public-Safe Runbook: Clarity Contract Deployment (Vault Products)

This document provides the formal deployment research and execution path for the Conxian Vault products, as requested in **CON-54**. It is designed to be environment-agnostic and Zero Secret Egress (ZSE) compliant.

## 1. Product Scope
- **Phase 2A sBTC custody core**: `contracts/vaults/sbtc-vault.clar` accepts one immutable, admin-configured canonical SIP-010 token, reconciles deposit receipts against live balance deltas, accounts shares, and supports fail-closed withdrawals.
- **Separate vault modules**: `contracts/vaults/custody.clar`, `contracts/vaults/yield-aggregator.clar`, and `contracts/vaults/fee-manager.clar` are not strategy or bridge implementations for the Phase 2A sBTC boundary.
- **Explicit non-scope**: BTC bridging/redemption, signer logic, peg repair, official sBTC mint/burn calls, strategy allocation, donation sweeping, and peg-in/peg-out workflows remain later phases.

## 2. Contract Inventory & Dependency Order
To ensure successful deployment, contracts must be published in the following order:

1. **Traits & Standards** (Must exist on-chain or be deployed first)
   - `.sip-standards.sip-010-ft-trait`
   - `.vault-traits.vault-trait`
2. **Support & Logic Modules**
   - `contracts/compliance/regulatory-adapter.clar`
   - `contracts/monitoring/finance-metrics.clar`
3. **Vault Core Modules**
   - `contracts/vaults/fee-manager.clar`
   - `contracts/vaults/custody.clar`
4. **Product Entry Points**
   - `contracts/vaults/sbtc-vault.clar` (Depends on core-traits, regulatory-adapter, sip-standards, and vault-traits)
   - `contracts/vaults/yield-aggregator.clar` (Imports `.vault-traits.vault-trait` and `.sip-standards.sip-010-ft-trait`; the active manifest lists `sip-standards` and does not depend on `sbtc-vault`)

## 3. Deployment Configuration
### 3.1. Principal and token wiring
The Phase 2A `sbtc-vault` does **not** use `contracts/core/operational-treasury.clar`.
Its administrator, vault principal, and approved token are stored locally in the
contract. There is no `set-protocol-principal` step for this custody slice.

- **NEVER** hardcode `SP...` or `ST...` addresses in the source.
- Configure the canonical token with `set-approved-token` exactly once from the
  initial unconfigured state; the token is immutable afterward.

### 3.2. Clarinet Integration
The active production `Clarinet.toml` uses the following shape (a dedicated
vault manifest may mirror it):

```toml
[contracts.sbtc-vault]
path = "contracts/vaults/sbtc-vault.clar"
clarity-version = 4
depends_on = ["core-traits", "regulatory-adapter", "sip-standards", "vault-traits"]

[contracts.yield-aggregator]
path = "contracts/vaults/yield-aggregator.clar"
clarity-version = 4
depends_on = ["sip-standards"]
```

The names above mirror the source imports and the active `Clarinet.toml`:
`vault-traits` is the trait contract name, while `vault-trait` is only the
trait identifier. `yield-aggregator` does not require `sbtc-vault` and the
active manifest does not list `vault-traits` in that contract's
`depends_on` array.

### 3.3. Publication is not vault initialization

The checked-in `deployments/default.simnet-plan.yaml`,
`deployments/full-system.testnet-plan.yaml`, and
`deployments/full-system.mainnet-plan.yaml` each publish
`contracts/vaults/sbtc-vault.clar`. Their transactions do **not** call
`set-approved-token`, `set-deposit-cap`, `set-paused`, or `set-admin` for the
vault. Publishing the contract therefore does not prove that a network has an
approved canonical token, an operational cap, a pause policy, or an approved
admin handoff. The source defaults remain subject to the contract's own
configuration rules; deposits are not operationally enabled until the token
and cap are configured.

Network-specific vault initialization must be separately approved and
evidenced after publication. The evidence pack must identify the target
network, the officially documented token reference, the approved cap/pause/admin
values, the signer-derived caller, transaction receipts, and post-call readback
without treating a plan artifact or workflow success as deployment proof.

### 3.4. Checked-in mainnet manifest authority

Repository evidence does not make `deployments/mainnet-manifest-v1.yaml` the
authoritative mainnet workflow input. The checked-in generator produces
`deployments/full-system.mainnet-plan.yaml`, and `.github/workflows/deploy-mainnet.yml`
validates that plan plus `deployments/full-system.mainnet-plan.sha256`. No
current generator or deployment workflow references `mainnet-manifest-v1.yaml`.
Treat it as a non-authoritative legacy/reference artifact: do not use it to
infer current network principals, vault initialization, signer identity, or
deployment completion. The separate `deployments/mainnet-release-plan.yaml`
is explicitly disabled/readiness-gated and contains no actionable batches.

### 3.5. Enterprise Subscription and Fiscal Dam Gate
The enterprise subscription contracts are publishable in a fail-closed state,
but deployment does not publish plan prices, activate plan versions, configure
STX bucket recipients, or register arbitrary product consumers. Before product
activation, governance must complete these separate steps:

1. Publish an approved `{tier-id, version}` plan with nonzero monthly/annual
   prices and a valid nonzero KYC tier.
2. Publish all generic features, then explicitly activate the immutable plan
   version.
3. Register only audited product consumer contracts with
   `enterprise-subscription`; the generic facade is not trusted by default.
4. Configure each audited Fiscal Dam bucket recipient with
   `cxd-treasury.set-stx-bucket-recipient`. Unconfigured destinations must
   remain fail-closed.
5. Verify the generated plan contains the enterprise subscription ->
   revenue-automation -> revenue-distributor -> cxd-treasury route wiring.

Settled STX terminates in `cxd-treasury` accounting; it does not end at
`swap-router`. The buyback bucket is only a governed STX allocation until a
separate native-STX adapter is reviewed and approved.

## 4. Execution Workflow

### Step 1: Preflight & Safety
Run the contamination guard to ensure no testnet residue exists in the production branch:
```bash
python3 scripts/verify_contamination_guard.py
```

### Step 2: Local Validation
```bash
# Validate syntax and dependencies
clarinet check

# Generate deployment plans
# For Testnet (dev branch)
clarinet deployments generate --testnet --devnet
# For Mainnet (main branch)
clarinet deployments generate --mainnet
```

### Step 3: Broadcast Gate (Currently Blocked)
The repository workflows are currently preflight-only. They validate the config and exact plan digest, then emit clearly labeled plan/preflight/log artifacts; they do **not** invoke `clarinet deployments apply`, load a mnemonic, sign, or broadcast.

Completed work under issue #531 provides the preflight, plan-validation, and evidence-verifier foundations; issue #531 remains open for its original deployment/evidence acceptance criteria. Every non-dry path remains blocked before signing until an approved signer identity and authorized structured receipt-producing broadcaster/execution path exist and the applicable complete plan-bound evidence pack and readbacks are produced. Do not run `clarinet deployments apply` manually as a workaround, and do not treat dashboard or debug logs as deployment proof.

The current full-system mainnet plan also contains an unresolved `ST...` deployer identity. It must be replaced only by an approved identity derived from and verified against the configured signer; do not guess an `SP...`/`SM...` address.
The supported `Deploy Mainnet` workflow remains preflight-only. It requires
`confirm: DEPLOY_MAINNET` and an `expected_plan_sha256` matching the checked-in
`deployments/full-system.mainnet-plan.yaml` digest. Keep `dry_run: true` for
plan-only artifacts; setting `dry_run: false` is rejected by the fail-closed
gate before signing and does not deploy.

## 5. Post-Deployment & Role Wiring
If a later deployment is approved, configure the Phase 2A vault in this order
before accepting deposits:
1. **Canonical token**: Call `set-approved-token` once with the official sBTC SIP-010 contract reference for that network. It is only valid from the initial `none` state and cannot be reconfigured.
2. **Deposit cap**: Call `set-deposit-cap` with an explicit nonzero cap that is at least the current accounted assets.
3. **Optional pause**: Call `set-paused` only when an operational pause is required; withdrawals remain available while paused if the vault is solvent and the caller is compliant.
4. **Admin handoff**: If required, call `set-admin` last from the current admin and verify that the previous admin is rejected afterward.
5. **Compliance**: Ensure the existing `regulatory-adapter` has valid compliance records for intended users.

Do not register this Phase 2A vault through `operational-treasury`, and do not
treat `allocate-to-strategy` as available; it remains fail-closed.

For other registry-backed vault products, once an approved, fully evidenced
deployment exists, complete the corresponding administrative wiring:
1. **Registry Update**: Call `set-protocol-principal("sbtc-vault", <deployed-address>)` in `operational-treasury`.
2. **Fee Initialization**: Set default fees in `fee-manager.clar`.
3. **Manager Authorization**: Add necessary managers in `custody.clar`.
4. **Enterprise Governance**: Complete the enterprise subscription gate above;
   generated route wiring is not approval to sell plans or release Fiscal Dam
   custody.

## 6. Evidence Capture
The Phase 2A implementation task creates no deployment evidence. Until the
broadcast gate is cleared, record only preflight artifacts for the acceptance
pack:
- Source commit SHA from the preflight run
- Exact deployment plan path and SHA-256
- Network, approved signer-derived deployer identity, and validation results
- Preflight logs and any explicitly labeled broadcast/partial candidate

A later network-specific acceptance pack must additionally record transaction
IDs, the configured canonical token principal, and post-deployment
reconciliation checks before any production claim is made. Do not record txids
or deployed contract principals as acceptance proof without a structured
receipt and complete plan-bound verification. A partial candidate is retained
for bounded recovery and must never be labeled confirmed or completed.

## 7. Authoritative public sBTC references

- [Stacks sBTC overview](https://docs.stacks.co/learn/sbtc)
- [sBTC Clarity contracts](https://docs.stacks.co/learn/sbtc/clarity-contracts)
- [Clarinet sBTC integration](https://docs.stacks.co/clarinet/integrations/sbtc)
- [Stacks mainnet and testnets](https://docs.stacks.co/learn/network-fundamentals/mainnet-and-testnets)
- [stacks-sbtc source repository](https://github.com/stacks-sbtc/sbtc)

---
*Last Updated: July 22, 2026*
