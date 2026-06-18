# CXIP-014: Protocol-First Repository Narrowing

## Overview
This proposal formalizes the "protocol-first" narrowing strategy for the `Conxian/Conxian` repository. The goal is to isolate canonical protocol identity and artifacts from integration runtime and service-specific concerns.

## Strategic Goal
- **Purity**: Ensure the `Conxian` repo is the single source of truth for the protocol, not its various implementations or service adapters.
- **Maintenance**: Reduce build/test noise from unrelated sub-systems (e.g., Gateway UI or legacy parsers).
- **Security**: Minimize the attack surface by moving sensitive service-layer logic to specialized, isolated repositories.

## Narrowing Inventory (Target for Relocation)
- **Gateway Runtime**: Express server, ISO 20022 parsers, and OData translators.
- **UI Applications**: Web application code and frontend-specific configuration.
- **Mixed Adapters**: Logic that bridges protocol traits to specific 3rd party service providers (where not required for core protocol truth).

## Implementation Path
1. **Inventory Classification**: (COMPLETED - `gateway/NARROWING_INVENTORY.md`).
2. **CI Isolation**: Separate PR validation for UI and Gateway paths (IN PROGRESS).
3. **Subtree Relocation**: Systematic move of classified directories to dedicated repositories.

## Governance Impact
This narrowing does not affect protocol logic or user funds. It is a technical hygiene and organizational alignment maneuver intended to strengthen the Conxian ecosystem's resilience.
