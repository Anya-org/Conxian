# ECONOMIC_RIGHTS_MAP (public-safe policy summary)

This document is the public-safe policy description for Conxian economic-rights routing.

Detailed bucket allocations, principal mappings, and gate-state snapshots are intentionally maintained in private governance and operations records.

## Policy principles

1. **No hardcoded production principals in public artifacts**
   - Public documentation must not expose direct address literals or signer identifiers.

2. **Versioned economics surfaces**
   - Economic-rights behavior is versioned and governance-controlled.
   - Material routing changes require explicit approval and traceable change history.

3. **Deterministic and auditable routing**
   - Execution logic should be deterministic and evidence-backed.
   - Systems should fail closed when required authority or configuration is unavailable.

4. **Governance separation of duties**
   - Execution authority and policy-mutation authority are separated.
   - Staged control transitions are governed by approved lifecycle protocols.

## Machine-readable companion

- `docs/protocols/data/ECONOMIC_RIGHTS_MAP.v1.csv` is retained as a public-safe placeholder.
- Detailed machine-readable allocation registries are private by design.

## Documentation boundary

Per Zero Secret Egress (ZSE), public docs keep policy-level intent while sensitive operational/economic details remain in restricted governance records.
