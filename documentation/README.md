# Conxian Protocol Documentation

Welcome to the central documentation hub for the Conxian Protocol. This repository contains all of the technical specifications, architectural diagrams, strategic documents, and developer guides for the protocol.

The documentation is organized to provide a clear path for various audiences, from new community members to institutional partners and core developers.

## 1. Core Documents

If you are new to the Conxian Protocol, we recommend starting with these key documents to understand our vision, architecture, and technical design.

-   **[Project README](../README.md)**: The main project README. It provides a high-level overview of the protocol and instructions for development setup.
-   **[Product Requirement Document (PRD)](./PRD.md)**: The central "source of truth" for the Conxian Protocol, outlining its architecture, governance model, and development roadmap.
-   **[Whitepaper](./whitepaper/Conxian-Whitepaper.md)**: The complete technical vision and protocol design.
-   **[Changelog](./CHANGELOG.md)**: A log of all notable changes to the protocol.

## 2. Technical & Architectural Documentation

This section contains the detailed technical specifications and architectural decision records (ADRs).

-   **[Smart Contract `README`s](../contracts/)**: Specific module architecture details (found in each contract subdirectory).
-   **[Naming Standards](./reference/NAMING_STANDARDS.md)**: Official naming conventions for tokens and governance bodies.

## 3. Guides & Manuals

This section provides practical guides for different user groups.

### For Developers

-   **[Developer Guide](./developer/DEVELOPER_GUIDE.md)**: Comprehensive guide for building on or contributing to Conxian.
-   **[Contributing Guide](./guides/CONTRIBUTING.md)**: Guidelines for contributing code and documentation.

### For Enterprise & Institutional Users

-   **[Enterprise Onboarding](./enterprise/ONBOARDING.md)**: Integration guide for institutional partners.

### For Governance Participants

-   **[Governance Model](./PRD.md#3-governance-model)**: Explanation of the Conxian DAO, council structure, and voting process.

## 4. System Analysis, Strategy & Reports

This section contains in-depth analysis and reports related to the protocol's risk profile, security, and overall readiness.

-   **[System Analysis](./SYSTEM_ANALYSIS.md)**: Analysis of the protocol's market, competitive landscape, and risks.
-   **[Security Documentation](./security/SECURITY.md)**: Overview of security strategy.
-   **[Audit & Analysis Reports](./reports/)**: Security audits, gap analyses, and other system reports.

## 5. Recovery Registry (Quarantined Contracts)

The following contracts are temporarily quarantined in the `contracts/drafts` directory. They are not part of the active testnet deployment and are undergoing significant refactoring or review. This is done to maintain the stability of the core protocol and the integrity of the test suite.

| Contract                        | Reason for Quarantine                                       |
| ------------------------------- | ----------------------------------------------------------- |
| `federated-oracle-adapter.clar` | Non-functional stub awaiting implementation.                |
| `interest-rate-model.clar`      | Pending a comprehensive security review.                    |
| `lending-manager.clar`          | Awaiting architectural redesign to align with the new PRD. |
| `regulatory-adapter.clar`       | Being updated to support the latest SIP-018 standards.    |
