# GCP Infrastructure Documentation (March 2026 Revision)

## Deployment Topology
The Conxian network infrastructure is a modular, high-availability architecture centered around the **Fusion Gateway** and **Conxian Nexus**.

### Unified Entry Point
The Gateway serves as the single entry point for all sovereign services and Bitcoin L2s.
- **Institutional Integrations**: Built-in support for ALEX Lab (Liquidity) and Portal Swap (Cross-chain BTC).
- **ERP Sync**: Persistent Event Service for deterministic accounting via "The Engine".

### Modular Infrastructure
GCP configurations are managed within the `gateway/` submodule to ensure audit-readiness.
- **Path**: `gateway/infrastructure/gcp/`

### Monitoring & Metrics
- **Nexus-First**: Authoritative system telemetry originates from the Nexus state node.
- **Observability**: Prometheus-compatible metrics are exposed via the Gateway and Nexus on ports 8080/3000 respectively.

---
[Return to Root README](../../README.md) | [Strategic Alignment](../ALIGNMENT.md)
