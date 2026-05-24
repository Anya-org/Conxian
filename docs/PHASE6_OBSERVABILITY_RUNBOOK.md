# Phase 6: Production Rollout, Observability & Rollback Drills

**Status**: Active
**Scope**: Conxian Sovereign Gateway & Stacks Smart Contracts

## 1. Rollout Runbook
1. **Pre-Flight Checks**: Ensure `clarinet check --coverage` reports 100% test pass and zero warnings for Clarity 4 contracts.
2. **Deploy Gateway**: Promote the `conxian-gateway` to the production edge via Conxius Orbit.
3. **Enable Phase 6 Guards**: Trigger `(contract-call? .agent-risk enable-phase6)` using the Sovereign Treasury account.
4. **Validation**: Check MCP telemetry endpoint `/api/v1/mcp` (`get_system_telemetry`) to ensure the agent reports stable TVL.

## 2. Observability Metrics
- **MCP Telemetry Logging**: Monitor the rate of `get_system_telemetry` and `get_yield_metrics` calls. Elevated latency (>200ms) indicates Gateway strain.
- **Contract Emissions**: Monitor for the `tier1-counterparty-updated` event on `jurisdictional-sharding.clar` to verify entity tracking.
- **Enclave Yield Stats**: Stream the enclave attestation success rate. If biometric signature failure rate > 5%, alert the on-call engineer.

## 3. Rollback Drills
### Scenario A: Gateway Disconnected from ERP
1. Isolate the MCP tool `authorize_intent`.
2. Disable the tool at the proxy level or return `HTTP 503`.
3. Escalate to the SAP/Oracle integration admins.

### Scenario B: Smart Contract Vulnerability
1. Identify the compromised feature flag.
2. Trigger the `(contract-call? .automation-manager emergency-pause)` if implemented, or disable specific phase flags.
3. If Phase 6 introduces systemic instability, revoke the flag by executing a counter-proposal to set `phase6-active` to `false`.
