# Changelog

## [2024-07-22] - Documentation Realignment

### Changed

- Realigned all module-level `README.md` files in the `contracts` directory to accurately reflect the implemented contract architecture, public functions, and current status.
- Updated the main `README.md` and `documentation/README.md` to ensure they provide an accurate overview of the project and link to the realigned module-level documentation.
- Removed the redundant `PRD.md` file from the `documentation` directory.
- Moved the `DOCUMENTATION_STRUCTURE.md` file to the `documentation/reference` directory.

## [0.3.0] - 2024-08-20

### Added

- **Investment-Grade Analysis**: Integrated refined SWOT, PESTLE, and Six-Pillar View into `PRD.md`.
- **Project Roadmap**: Refined `docs/ROADMAP.md` (v0.3.0) detailing 4-phase execution (MVP to Scale).
- **SAB Whitepaper**: Enhanced `docs/WHITEPAPER.md` with Sovereign Autonomous Business (SAB) narrative and VC pitch.
- **Verification Suite**: Updated `docs/REQUIREMENTS_TESTING.md` with specific unit tests for autonomous agents and fiscal policy.
- **CAPEX/OPEX Modeling**: Integrated detailed financial estimates and "Staff" payroll models in `PRD.md`.
- **Research Findings**: Documented 2024 Bitcoin L2 landscape and MiCA regulatory findings in `docs/RESEARCH.md` (updated to 2026).

### Changed

- **PRD Synchronization**: Fully synchronized `PRD.md` with implementation state, including "Kill-Switch" risks and "Blue Ocean" opportunities.
- **Configuration Alignment**: Re-enabled `agent-risk` in `Clarinet.toml` and verified dependency chain.
- **Protocol Recovery**: Completed "Full Truth" consolidation of core DeFi and Governance modules.

### Security

- **Circuit Breaker**: Documented integration of the protocol-wide circuit breaker in all service modules.
- **Regulatory Hardening**: Documented "Clean-Hands" compliance via `regulatory-adapter`.

## [0.5.0] - 2026-01-31 - Protocol Repairs Complete

### Added (Priority Repairs P1-P6)

- **Sovereign Handoff**: Timelock execution engine, 5-step transfer orchestration (`governance-handover.clar`)
- **Compliance System**: Provider-based KYC/AML with `compliance-manager.clar` and `compliance-hooks.clar`
- **Tokenomics Caps**: CXD max supply (1B tokens), allocation policy immutability lock
- **ICO Security**: Compliance gating, purchase caps (1M/10K), buyer tracking
- **CXLP Position NFT**: Full SIP-009 implementation with metadata and fee tracking
- **Operational Safety**: Rate limiter (window-based), Proof-of-Reserves (multi-attestor)

### Changed

- **Timelock**: From simple queue to executable proposal system with permissionless execution
- **Compliance**: Removed mock sanctions, added real provider attestation
- **Allocation Policy**: Admin-only → timelock-governed with `lock-policy` immutability
- **CXD Token**: Fixed supply → capped mintable with events and tracking

### Security

- **Rate Limiting**: Window-based operation limiting (600 block default)
- **Proof of Reserves**: 3+ attestor requirement, 7-day validity
- **Sovereign Transfer**: Explicit 5-step handoff with verification

## [0.4.0] - 2026-01-20

### Added

- **Clarity 4 Mainnet Standard**: Full refactor of all contracts to Clarity 4 (Epoch 3.0).
- **Passkey Support**: Integrated `secp256r1-verify` in `conxian-access.clar` for biometric signing.
- **Sovereign Post-Conditions**: Implemented `restrict-assets?` in `vault.clar` for native security.
- **Module Integrity**: Added `contract-hash?` validation in `conxian-protocol.clar`.
- **Human-Readable Logs**: Integrated `to-ascii?` in `regulatory-adapter.clar` and other core modules.

### Changed

- **Precision Temporal Logic**: Replaced `block-height` and `burn-block-height` with `stacks-block-time` for all yield, vesting, and governance logic.
- **Gap Analysis**: Updated `gap-analysis.md` with Jan 2026 "Jules Persona" investment-grade analysis.

## [2024-07-22] - Documentation Realignment
