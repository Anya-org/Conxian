# Protocol-First Repository Narrowing Strategy

## 1. Vision
The Conxian repository is the definitive source of truth for the Conxian Protocol. To maintain this "protocol-first" identity, all concerns related to service runtime, frontend applications, and non-canonical integration adapters are scheduled for relocation.

## 2. Rationale
- **Decoupling**: Protocol development should not be blocked by UI or Gateway service issues.
- **Focus**: Clear boundaries ensure that audit and verification efforts are focused on the core smart contracts.
- **Scalability**: Independent service repositories allow for specialized CI/CD pipelines and deployment cadences.

## 3. Inventory Classification (June 2026)

### 3.1. Core (STAY)
- `contracts/`: All Clarity smart contracts.
- `deployments/`: Canonical deployment manifests.
- `docs/`: Protocol specifications, CXIPs, and research.
- `tests/`: Core protocol logic tests.

### 3.2. Applications (MOVE)
- `ui/`: The Conxian Unified Interface (Web/Mobile).
- `gateway/`: The ERP and Institutional bridge runtime.

### 3.3. Adapters (MOVE/SPLIT)
- Service-specific adapters (e.g., ISO 20022 parsing logic) move to the Gateway repo.
- Protocol-facing traits remain in the Core repo.

## 4. Implementation Status
- **CXIP-014**: Proposal drafted to formalize the move.
- **CI Isolation**: Separate workflows implemented for Protocol (`sovereign-guard`) and UI (`conxian-ui-ci`).
- **Narrowing Inventory**: Completed and tracked in `gateway/NARROWING_INVENTORY.md`.

## 5. Next Steps
1. Finalize the target repositories for Gateway and UI.
2. Execute subtree splits for classified directories.
3. Update all cross-repo documentation links.
