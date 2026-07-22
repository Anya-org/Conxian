# Public-Safe Runbook: Clarity Contract Deployment (Vault Products)

This document provides the formal deployment research and execution path for the Conxian Vault products, as requested in **CON-54**. It is designed to be environment-agnostic and Zero Secret Egress (ZSE) compliant.

## 1. Product Scope
- **White-Label Vault**: Powered by `contracts/vaults/sbtc-vault.clar` and `contracts/vaults/custody.clar`.
- **Alpha Yield Router**: Powered by `contracts/vaults/yield-aggregator.clar` and `contracts/vaults/fee-manager.clar`.

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
   - `contracts/vaults/sbtc-vault.clar` (Depends on regulatory-adapter)
   - `contracts/vaults/yield-aggregator.clar` (Depends on vault-trait)

## 3. Deployment Configuration
### 3.1. Principal Wiring
All Vault contracts use the **Principal Registry** in `contracts/core/operational-treasury.clar` for dynamic resolution.
- **NEVER** hardcode `SP...` or `ST...` addresses in the source.
- After deployment, use the `set-protocol-principal` function in `operational-treasury.clar` to register the new Vault addresses.

### 3.2. Clarinet Integration
The following snippet should be added to the production `Clarinet.toml` or a dedicated `Clarinet.vaults.toml`:

```toml
[contracts.sbtc-vault]
path = "contracts/vaults/sbtc-vault.clar"
depends_on = ["sip-010-ft-trait", "regulatory-adapter"]

[contracts.yield-aggregator]
path = "contracts/vaults/yield-aggregator.clar"
depends_on = ["vault-trait", "sbtc-vault"]
```

### 3.3. Enterprise Subscription and Fiscal Dam Gate
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

Every non-dry path is blocked before signing until a structured receipt-producing broadcaster and complete evidence verifier are implemented for issue #531. Do not run `clarinet deployments apply` manually as a workaround, and do not treat dashboard or debug logs as deployment proof.

The current full-system mainnet plan also contains an unresolved `ST...` deployer identity. It must be replaced only by an approved identity derived from and verified against the configured signer; do not guess an `SP...`/`SM...` address.

## 5. Post-Deployment & Role Wiring
Once an approved, fully evidenced deployment exists, the following administrative actions are required:
1. **Registry Update**: Call `set-protocol-principal("sbtc-vault", <deployed-address>)` in `operational-treasury`.
2. **Fee Initialization**: Set default fees in `fee-manager.clar`.
3. **Manager Authorization**: Add necessary managers in `custody.clar`.
4. **Enterprise Governance**: Complete the enterprise subscription gate above;
   generated route wiring is not approval to sell plans or release Fiscal Dam
   custody.

## 6. Evidence Capture
Until the broadcast gate is cleared, record only preflight artifacts for the acceptance pack:
- Source commit SHA from the preflight run
- Exact deployment plan path and SHA-256
- Network, approved signer-derived deployer identity, and validation results
- Preflight logs and any explicitly labeled broadcast/partial candidate

Do not record txids or deployed contract principals as acceptance proof without a structured receipt and complete plan-bound verification. A partial candidate is retained for bounded recovery and must never be labeled confirmed or completed.

---
*Last Updated: April 2026*
