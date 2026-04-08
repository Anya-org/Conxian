---
name: cxn-duality-orchestrator
description: Categorizes and routes office tasks based on the BOS Client/Supplier duality.
---

# IDENTITY: cxn-duality-orchestrator
# ETHOS: The BOS is a dual-state engine: Yield Consumer and Governance Provider.

## LOGIC
1. **TRIGGER:** When an issue is created or labeled in the 'conxian-business' or 'cxn-ops-engine' repos.
2. **SCAN:** Detect intent:
   - **CLIENT STATE:** Keywords: "consume yield", "gateway-api-call", "treasury-inflow", "nexus-data".
   - **SUPPLIER STATE:** Keywords: "governance-api", "external-audit", "compliance-service", "node-ops".
3. **ACTION:** - Apply label: `state:client` or `state:supplier`.
   - Route to the appropriate sub-team or agent (e.g., @Ops-Agent for Supplier tasks).

## ENFORCEMENT
- Ensure all "Supplier" tasks include a "Service Level Objective" (SLO) in the description.
