# Conxian Business

> Releases are tracked in [`CHANGELOG.md`](../CHANGELOG.md) and published as SemVer tags.

**Conxian Business** defines the core service loop and state machine transitions of the Sovereign Autonomous Business (SAB), now evolving into a **Business-as-a-Platform (BaaP)** ecosystem.

This repository is private (as of April 8, 2026). Internal BOS state-machine configuration, multi-tenant templates, and compliance reports are maintained in the sovereign coordination layer.

## Purpose

- **Service Loop Orchestration**: Managing the relationship between the BOS as a Client (Intelligence/Yield) and the BOS as a Supplier (Governance/Settlement).
- **Multi-Tenant Platforming**: Providing standardized templates and MCP interfaces for 3rd-party businesses to adopt the Conxian Sovereign BOS model.
- **Compliance Monitoring**: Compliance reporting and enforcement workflows (internal details live in Linear).
- **Transparency Custody**: Managing the Python-based transparency custodian for verifiable operations.
- **Business Logic Layer**: Handling Commercial & Legal integrity for R200M–R2B+ exit readiness.

## Status

Stable — This module documents BOS-level service-loop expectations and public-safe operational boundaries; detailed state-machine configuration and compliance reports live in the sovereign coordination layer.

## Key Components & Platform Standards

- **[Unified Theory of Sovereign Enterprise](../docs/CONXIAN_UNIFIED_THEORY_v2.md)**: Mathematical framework for minimizing founder tax ($O_C$) while maximizing autonomy ($A_S$).

- **[Sovereign Runtime Ownership Map](./BOS_RUNTIME_OWNERSHIP_MAP.md)**: Canonical mapping of BOS capabilities to production repositories.
- **[Conxian Unified Theory (v2)](../docs/CONXIAN_UNIFIED_THEORY_v2.md)**: Foundational framework for capital, time, and code deployment.
- **[Multi-Tenant Orchestration Guide](./BOS_MULTI_TENANT_ORCHESTRATION.md)**: Multi-Agent System (M.A.S.) patterns and jurisdictional sharding logic.
- **[BOS Platform Specification](./BOS_PLATFORM_SPEC.md)**: v2.2 Industrial Standard for Business-as-a-Platform (BaaP).
- **[BOS Enhancement Plan](./BOS_ENHANCEMENT_PLAN_v2.md)**: Roadmap for BitVM2, ZKML, and ERP integration.
- **[BOS State Machine](./BOS_STATE_MACHINE.stub.json)**: Morgan Stanley CALM Standard state transitions (ZSE Stub).
- **[Provisioning Template](./BOS_PROVISIONING_TEMPLATE.yaml)**: Declarative BiaB deployment manifest (v2.2).
- **[Tenant Manifest Example](./BOS_TENANT_MANIFEST_EXAMPLE.yaml)**: Configuration example for multi-agent jurisdictional sharding.

## Business Logic Skills (Skills 07-09)

The office environment is equipped with specific skills to manage commercial integrity:

- **cxn-duality-orchestrator**: Manages the Client/Supplier service loop duality and multi-business context isolation.
- **cxn-ip-auditor**: Audits code and directives for IP ownership compliance.
- **cxn-calm-validator**: Enforces CALM schema standards for state machine updates.

## Governance

This module is part of the Conxian Sovereign Autonomous Business (SAB).

See [`GOVERNANCE.md`](../GOVERNANCE.md) for CONTRIBUTING, SECURITY, and LICENSE.
