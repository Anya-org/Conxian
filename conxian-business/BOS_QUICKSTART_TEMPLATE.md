# BOS "Business-in-a-Box" Quickstart Template
**For New Tenants & Sovereign Node Operators**

## 1. Prerequisites
- **Stacks Wallet**: Principal for state anchoring.
- **Akash Account**: For hosting your Sovereign Node.
- **Kwil Database**: For decentralized relational storage.

## 2. Setup Procedure
### Step A: Initialize the Sovereign Node
```bash
# Pull the latest EXCO suite
docker pull conxian/sovereign-node:latest

# Configure your Tenant DID
export TENANT_DID="did:stack:your_principal"
./init-node.sh --did $TENANT_DID
```

### Step B: Configure Sovereign Guardrails
Edit your `guardrails.yaml` to set your risk parameters:
```yaml
governance:
  timelock_blocks: 144
  multisig_threshold: 3
  emergency_guardian: "SP..."
treasury:
  max_drawdown_percent: 5
  auto_rebalance: true
```

### Step C: Connect your ERP (Optional)
Link your legacy ERP via the MCP bridge:
```bash
# Start the OData-to-MCP bridge
./cxn-gateway-bridge --erp-url https://your-erp.com --mcp-port 8080
```

## 3. Operational Checklist
- [ ] Verify Stacks Anchor connectivity.
- [ ] Run initial IP & Compliance Audit (`bos/audit-verify-ip`).
- [ ] Fund the Operational Treasury (Fiscal Vault).
- [ ] Test the x402 Payment Loop.

## 4. Support
- **Linear**: [Open a tenant-support issue](https://linear.app/conxian-labs/team/TENANT)
- **Docs**: [Full BaaP Specification](./BOS_PLATFORM_SPEC.md)

---
🛡️ **SOVEREIGNTY IS JUST ONE COMMAND AWAY.**
