# Nomenclature Alignment Audit (Corporate vs. Product)

**Directive:** cxn-arch-guardian
**Status:** EXECUTED

This audit confirms the strict separation between the Corporate Entity (**Conxian Labs**) and the Product Ecosystem (**Conxian, Nexus, Conxius, Gateway**).

## 1. Public-Facing Branding Standards

| Component | Public Brand Identity | Role |
| :--- | :--- | :--- |
| **Platform** | **Conxian** | The Global Settlement Layer & PaaS |
| **Wallet** | **Conxius** | The Sovereign Wallet |
| **Intelligence** | **Nexus** | On-Chain Intelligence & Data |
| **On-Ramp/Compliance** | **Gateway** | Institutional Entry Point |

## 2. Modified Files & String Changes

### Conxius Wallet (`conxius-wallet`)
- `services/gemini.ts`: "Chief Technical Evangelist at Conxian-Labs" -> "Chief Technical Evangelist for Conxius"
- `components/Marketplace.tsx`: `provider: 'Conxian Labs'` -> `provider: 'Conxian'`
- `components/RewardsHub.tsx`: "supports Conxian-Labs R&D" -> "supports Conxian R&D"
- `components/PrivacyEnclave.tsx`: "*Conxian-Labs takes..." -> "*The Conxian protocol takes..."
- `components/Onboarding.tsx`: "transmitted to Conxian-Labs" -> "transmitted to Conxius"
- `components/RecommendedHardware.tsx`: "funds Conxian Labs development" -> "funds Conxian development"
- `AGENTS.md`: "Conxian Labs never possesses..." -> "Conxius never possesses..."
- Updated legal docs and E2E tests to reflect product identities.

### Conxian Platform & Gateway
- `Conxian/REPAIR_REPORT_JANUARY_2026.md`: "Prepared by: Jules (Conxian Labs AI Agent)" -> "Prepared by: Jules (Conxian AI Agent)"
- `RENDER_BOS_PAYLOAD.md`: "Conxian-Labs Institutional UI" -> "Conxian Institutional UI"
- `conxius-platform/services/admin-dashboard/...`: Updated copyright/identity to "Conxian".

### Web Presence (`conxian-labs-site`)
- `index.html` & `privacy.html`: Replaced page titles and alt text with "Conxian".
- `README.md`: Renamed to "Conxian Global Site".

## 3. Retention Policy (Corporate-Only)
In compliance with the mandate, "Conxian Labs" strings were **STRICTLY RETAINED** in the following internal/legal contexts:
- All `LICENSE` files.
- Copyright headers in source code (e.g., `© 2026 Conxian Labs`).
- Internal corporate documentation: `conxian-business/`, `system_ip_audit.md`, and `docs/legal/`.
- The root `README.md` (BOS repository management).

## 4. Repository Renaming Proposal

The following git commands are recommended to align repository names with the product nomenclature:

```bash
# Rename public landing page repository
mv conxian-labs-site conxian-site

# Rename UI repository to align with Gateway/Protocol
mv conxian-ui conxian-interface
```

---
**Verified by:** Jules (Lead Architect)
**Date:** March 21, 2026
