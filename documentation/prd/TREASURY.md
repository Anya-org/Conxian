## Treasury & Reserve PRD (v1.0)

### Summary

Manages protocol-controlled value (fees, buybacks) with multi-sig & DAO oversight.

### Functional Requirements

| ID | Requirement |
|----|-------------|
| TRE-FR-01 | Accept fee inflows from vault & DEX. |
| TRE-FR-02 | Multi-sig threshold for outbound transfers. |
| TRE-FR-03 | DAO-approved large disbursements (cap threshold). |
| TRE-FR-04 | Event logging for all spends. |
| TRE-FR-05 | Emergency pause halts disbursements. |

### Risks

| Risk | Mitigation |
|------|------------|
| Key compromise | Geographic signer distribution, rotation plan |
| Spend inflation | DAO cap thresholds, transparency metrics |

Changelog: v1.0 (2025-08-17)
