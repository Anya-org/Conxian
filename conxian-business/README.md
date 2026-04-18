# Conxian Business

> Current workspace release: **v1.9.1** (see [`CHANGELOG.md`](../CHANGELOG.md))

**Conxian Business** defines the core service loop and state machine transitions of the Sovereign Autonomous Business (SAB), now evolving into a **Business-as-a-Platform (BaaP)** ecosystem.

This repository is public. Internal BOS state-machine configuration, multi-tenant templates, and compliance reports are maintained in Linear:

- https://linear.app/conxian-labs
- https://linear.app/conxian-labs/issue/CON-256
- https://linear.app/conxian-labs/issue/CON-474 (Platforming)

## Purpose

- **Service Loop Orchestration**: Managing the relationship between the BOS as a Client (Intelligence/Yield) and the BOS as a Supplier (Governance/Settlement).
- **Multi-Tenant Platforming**: Providing standardized templates and MCP interfaces for 3rd-party businesses to adopt the Conxian Sovereign BOS model.
- **Compliance Monitoring**: Compliance reporting and enforcement workflows (internal details live in Linear).
- **Transparency Custody**: Managing the Python-based transparency custodian for verifiable operations.
- **Business Logic Layer**: Handling Commercial & Legal integrity for R200M–R2B+ exit readiness.

## Status

active — This module documents BOS-level service-loop expectations and public-safe operational boundaries; detailed state-machine configuration and compliance reports live in Linear. Internal details: <https://linear.app/conxian-labs/issue/CON-435/improve-portfolio-clarity-across-org-facing-repositories>.

## Key Components

- **[Service Loop Specification](./SERVICE_LOOP.md)**: Mermaid diagrams of the BOS Gateway and Nexus relationship, including multi-tenant orchestration.
- **[BOS State Machine](./BOS_STATE_MACHINE.stub.json)**: Morgan Stanley CALM Standard state transitions (ZSE Stub).
- **[IP & Compliance Audit](./system_ip_audit.md)**: Intellectual Property ownership audit (ZSE Stub).
- **[Section 42 Swap Agreement](./SECTION_42_SWAP_AGREEMENT.md)**: Legal integrity for asset transfer (ZSE Stub).

## Business Logic Skills (Skills 07-09)

The office environment is equipped with specific skills to manage commercial integrity:

- **cxn-duality-orchestrator**: Manages the Client/Supplier service loop duality and multi-business context isolation.
- **cxn-ip-auditor**: Audits code and directives for IP ownership compliance.
- **cxn-calm-validator**: Enforces CALM schema standards for state machine updates.

## Governance

This module is part of the Conxian Sovereign Autonomous Business (SAB).

See [`GOVERNANCE.md`](../GOVERNANCE.md) for CONTRIBUTING, SECURITY, and LICENSE.
