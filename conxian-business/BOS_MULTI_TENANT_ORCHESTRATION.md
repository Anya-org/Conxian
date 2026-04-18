# BOS Multi-Tenant Orchestration Guide
**Model:** Agent-as-a-Service (AaaS)
**Alignment:** LangChain Multi-Agent / CrewAI Flow patterns

## 1. Orchestration Pattern
The BaaP model uses a **Supervisor-Worker** orchestration pattern for multi-tenant isolation.

### Supervisor Agent (Strategy Nexus)
- **Role**: Context switching and task dispatching.
- **Isolation**: Injects the `TenantID` into every tool call.
- **Decision Logic**: Routes business intents to specialized worker crews based on the `BOS_STATE_MACHINE.stub.json`.

### Worker Crews (EXCO Units)
- **Fiscal Vault Crew**: Manages liquidity, swaps, and payouts.
- **Nakamoto Guardian Crew**: Performs audits, AML/KYC checks, and policy validation.
- **Sovereign Ops Crew**: Connects to legacy ERPs (SAP/Oracle) via MCP.

## 2. Technical Implementation: Context Isolation
To prevent cross-tenant data leakage, all agentic execution must wrap tool calls in a `TenantContext`:

```python
# Example of Context-Aware Tool Dispatching
from langchain.tools import tool

@tool
def process_invoice(invoice_data: dict, tenant_id: str):
    """
    Processes an invoice within a specific tenant's secure namespace.
    Ensures that the Kwil database connection and encryption keys
    are scoped to the tenant_id.
    """
    with TenantNamespace(tenant_id):
        # Secure execution logic here
        return gateway.submit_x402_mandate(invoice_data)
```

## 3. Sovereign Node (BiaB) Akash SDL Template
Tenants can deploy their own BOS instance using the following Akash SDL (Stack Definition Language) snippet:

```yaml
---
version: "2.0"
services:
  sovereign-node:
    image: conxian/sovereign-node:v2.1
    env:
      - TENANT_ID=YOUR_BNS_NAME
      - STACKS_PRIVATE_KEY=SECRET_MOUNTED_VIA_ZSE
      - KWIL_ENDPOINT=https://kwil.conxian.network
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

## 4. Portability Strategy
By standardizing on **Portable Skills** (Markdown-defined prompts and YAML-defined toolsets), a business can move its entire "Autonomous Operating System" from Akash to local hardware or other clouds without re-engineering the core logic.

---
*Linked to CON-474 and CON-437.*
