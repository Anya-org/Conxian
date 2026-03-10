# Infrastructure & Deployment

This directory contains the authoritative specifications and guides for deploying and managing the Conxian Sovereign Autonomous Business (SAB) infrastructure.

## Core Documents

- **[Onsite Server Spec Sheet](./ONSITE_SERVER_SPEC_SHEET.md)**: Hardware, networking, and security requirements for "Citadel" deployments.
- **[Citadel Deployment Guide](./CITADEL_DEPLOYMENT_GUIDE.md)**: Step-by-step instructions for initializing a sovereign onsite node.
- **[Monitoring Configuration (Prometheus)](../conxius-platform/prometheus.yml)**: Metrics scraping configuration for Gateway and Nexus.

## System Architecture

The Conxian stack is designed for **Zero Secret Egress** and **Nexus-First** state authority. This requires:
1.  **Hardware Enclaves**: Intel SGX or AMD SEV for TEE-enclosed execution.
2.  **Deterministic Sync**: Persistent event queueing via "The Engine" for ERP integration.
3.  **Glass Node Telemetry**: Real-time visibility into protocol health via Prometheus and the Admin Dashboard.

---
© 2026 Conxian. Sovereign Autonomous Business.
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
