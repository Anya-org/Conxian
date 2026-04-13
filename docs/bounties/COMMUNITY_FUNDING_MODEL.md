# Community Funding Model (CON-137)

## Overview
This document defines how community funding supports system delivery for Conxian-Labs. It establishes the rules for bounty participation, funding sources, and operational boundaries to ensure progress while protecting critical system integrity.

## Core Funding Principles
1. **ALEX-Anchored**: All bounty funding is strictly sourced from the ALEX launch path. No other budget is assumed until ConxianCSF is fully deployed and the ALEX treasury path is verified.
2. **System-First**: Funding is prioritized for externalizable capabilities that support protocol expansion without exposing core security or deployment logic.
3. **Proof-of-Work**: All payouts require maintainer-verified implementation artifacts and evidence of system alignment.

## Participation Model

### 1. Bounty Classification
Issues in Linear are tagged with the `Bounty` label and classified into three categories:
- **Externally Claimable**: Public tasks suitable for community contribution (UI polish, research, non-core logic).
- **Security-Sensitive**: Requires pre-qualification or specific contributor trust levels.
- **Internal-Only**: Strategic, deployment, wallet, or core security tasks reserved for maintainers.

### 2. Claim & Approval Workflow
- **Inbound (Triage)**: Bounties identified but not yet open for claims.
- **Approved (Todo)**: Open for community claims.
- **Claimed (In Progress)**: Assigned to a contributor.
- **Submission (In Review)**: Implementation delivered and awaiting verification.
- **Accepted (Done)**: Payout triggered through the verified ALEX path.

## Operational Boundaries

### Internal-Only Domains
The following domains are strictly reserved for internal maintainers and are **not** eligible for community funding/claims:
- Mainnet Deployment & Orchestration
- Signer Paths & Hardware Security (Android TEE/StrongBox)
- Principal Registry Management
- Treasury Policy (Fiscal Dam) Control
- Final Release Gating (Go/No-Go)

### Externally Claimable Domains
- User Interface & Dashboard Improvements
- Regional Compliance Research
- ERP Integration Adapters (SAP/Oracle OData mappings)
- Documentation & Diátaxis Alignment
- Non-critical Utility Libraries

## Payout Governance
- Payouts are only enabled **post-mainnet launch**.
- Every payout must be mapped to a specific ALEX-funded treasury disbursement.
- Standardized verification evidence (PR links, CI status, audit report) is mandatory for every disbursement.

---
**Status**: Baselined (April 2026)
**Reference**: CON-137, CON-129, CON-231
