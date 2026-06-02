# BOS Multi-Tenant Orchestration Guide
**Model:** Agent-as-a-Service (AaaS)
**Alignment:** LangChain Multi-Agent / CrewAI Flow / Open Multi-Agent (TS)
**Version:** v2.2 (M.A.S. Era)

## 1. Orchestration Pattern: Multi-Agent Systems (M.A.S.)
The BaaP model uses a hierarchical **Supervisor-Worker** M.A.S. pattern for multi-tenant isolation and goal decomposition.

### Supervisor Agent (Strategy Nexus - EXCO)
- **Role**: High-level goal decomposition, context switching, and task dispatching.
- **Isolation**: Injects the `TenantID` into every tool call.
- **Inter-Agent Communication**: Standardized via **MCP Tool Handshakes**.
- **Decision Logic**: Routes business intents to specialized worker crews based on the dynamic state transition logic in `BOS_STATE_MACHINE.stub.json`.

### Worker Crews (Specialized EXCO Units)
- **Fiscal Vault Crew**:
    - **Agents**: Liquidity Analyst, Payout Executor, Yield Optimizer.
    - **Goal**: Manage per-tenant treasury with strict 144-block timelocks.
- **Nakamoto Guardian Crew**:
    - **Agents**: Policy Auditor, ZK-Proof Verifier, AML/KYC Guardian.
    - **Goal**: Perform verifiable attestations (BitVM2/ZKML) without PII leakage.
- **Sovereign Ops Crew**:
    - **Agents**: ERP Bridge, Industrial Labor Coordinator, Supply Chain Oracle.
    - **Goal**: Bidirectional sync with SAP/Oracle via OData v4 and MCP.

## 2. Jurisdictional Sharding & Context Isolation
To prevent cross-tenant data leakage ("The Contamination Risk"), the BOS implements multi-layer sharding:

### Layer 1: Identity & State Sharding
- **BNS/DID Isolation**: Each tenant uses a unique Decentralized Identifier (DID) anchored to Bitcoin/Stacks.
- **Kwil Namespace**: Relational state is logically isolated into tenant-specific schemas.
- **Tableland RLAC**: Public audit logs use Row-Level Access Control (RLAC) to ensure only authorized agents can read sensitive state roots.

### Layer 2: Execution Isolation (The Handshake)
All agentic execution must wrap tool calls in a secure `TenantContext`. The supervisor ensures that the worker crew only receives data relevant to their specific `tenant_id`.

```typescript
// Example of M.A.S. Handshake via MCP
interface MASHandshake {
  source_agent: string;
  target_agent: string;
  tenant_id: string; // Mandatory for all BaaP operations
  intent_hash: string;
  payload: any;
}

async function performHandshake(handshake: MASHandshake) {
  const guardianResponse = await mcp.callTool("nakamoto_guardian", "verify_policy", {
    tenant_id: handshake.tenant_id,
    action: handshake.payload.action
  });

  if (guardianResponse.approved) {
    return await mcp.callTool("fiscal_vault", "execute_transaction", handshake.payload);
  }
}
```

## 3. Sovereign Node (BiaB) Akash SDL Template
Tenants deploy their own BOS instance using the standard **Sovereign Blueprint**:

```yaml
---
version: "2.0"
services:
  sovereign-node:
    image: conxian/sovereign-node:v2.2
    env:
      - TENANT_ID=YOUR_BNS_NAME
      - STACKS_PRIVATE_KEY=SECRET_MOUNTED_VIA_ZSE
      - TELEMETRY_PROTOCOL=nostr
      - PERSISTENCE_LAYER=kwil_hybrid
    expose:
      - port: 8080
        as: 80
        to:
          - global: true
profiles:
  compute:
    sovereign-node:
      resources:
        cpu:
          units: 2.0
        memory:
          size: 4Gi
        storage:
          size: 10Gi
  placement:
    akash:
      attributes:
        host: akash
      pricing:
        sovereign-node:
          denom: uakt
          amount: 100
deployment:
  sovereign-node:
    akash:
      profile: sovereign-node
      count: 1
```

## 4. Transparency & Governance Standard
- **Verifiable Telemetry**: All M.A.S. internal logs (Kind 26001/26002) are broadcast via Nostr for real-time observability.
- **MMR State Proofs**: Every business transaction updates a per-tenant Merkle Mountain Range (MMR), ensuring O(log N) inclusion proofs for any historical event.
- **Sovereign Portability**: Businesses can migrate their entire M.A.S. "Brain" from cloud to local hardware by simply moving their Kwil/Tableland state anchors.

---
*Maintained by the Sovereign Orchestrator. Linked to CON-474 and CON-619.*
