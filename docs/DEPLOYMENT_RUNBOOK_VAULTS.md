# Public-Safe Runbook: Clarity Contract Deployment (Vault Products)

This document provides the formal deployment research and execution path for the Conxian Vault products, as requested in **CON-54**. It is designed to be environment-agnostic and Zero Secret Egress (ZSE) compliant.

## 1. Product Scope
- **Phase 2A sBTC custody core**: `contracts/vaults/sbtc-vault.clar` accepts an admin-configured canonical SIP-010 token, accounts shares, and supports safe withdrawals.
- **Separate vault modules**: `contracts/vaults/custody.clar`, `contracts/vaults/yield-aggregator.clar`, and `contracts/vaults/fee-manager.clar` are not strategy or bridge implementations for the Phase 2A sBTC boundary.
- **Explicit non-scope**: BTC bridging/redemption, signer logic, peg repair, official sBTC mint/burn calls, and yield allocation remain later phases.

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
clarity-version = 4
depends_on = ["core-traits", "regulatory-adapter", "sip-standards", "vault-traits"]

[contracts.yield-aggregator]
path = "contracts/vaults/yield-aggregator.clar"
depends_on = ["vault-trait", "sbtc-vault"]
```

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
Once an approved, fully evidenced deployment exists, the operator must configure
the vault before accepting deposits. The required administrative actions are:
1. **Registry Update**: Call `set-protocol-principal("sbtc-vault", <deployed-address>)` in `operational-treasury`.
2. **Canonical token**: Call `set-approved-token` with the official sBTC SIP-010 contract reference for that network.
3. **Deposit cap**: Call `set-deposit-cap` with an explicit nonzero cap.
4. **Compliance**: Ensure the existing regulatory-adapter has valid compliance records for intended users.
5. **Fee Initialization**: Set default fees in `fee-manager.clar`.
6. **Manager Authorization**: Add necessary managers in `custody.clar`.
7. **Strategy boundary**: Do not treat `allocate-to-strategy` as available; it remains fail-closed in Phase 2A.

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

---
*Last Updated: April 2026*
