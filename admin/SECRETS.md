# Secret management (migrated to Linear)

This repository is public.

Do not add operational, security, financial, legal, or strategic details to this repository file beyond this pointer stub.

The canonical content for secret inventory, provisioning instructions, and operational key-management procedures is maintained in the Lit Protocol vault to comply with our Zero Secret Egress (ZSE) mandate and to protect sensitive operational, security, financial, legal, or strategic details.

This file is intentionally kept as a stub so existing links continue to resolve.

---

## GitHub Secrets Inventory (metadata only — no secret values)

Audited: 2026-07-08 | Source: `.github/workflows/*.yml` | Status: 8/18 configured

| Secret | Used By | Status | Source Required |
|---|---|---|---|
| `CONXIAN_DEPLOY_KEY_1` | deploy workflows | ✅ Set | — |
| `CONXIAN_DEPLOY_KEY_2` | deploy workflows | ✅ Set | — |
| `CONXIAN_DEPLOY_KEY_3` | deploy workflows | ✅ Set | — |
| `CONXIAN_INTERNAL_KEY_1` | internal workflows | ✅ Set | — |
| `CONXIAN_INTERNAL_KEY_2` | internal workflows | ✅ Set | — |
| `NEXUS_ADMIN_API_TOKEN` | conxian-nexus Admin API | ✅ Set | — |
| `NOSTR_SECRET_KEY` | Nostr telemetry bridge | ✅ Set | — |
| `GITLEAKS_LICENSE` | secret-scan workflow | ✅ Set | Gitleaks GitHub Action license key (enables full gitleaks v8.24.2 functionality) |
| `CI_SUBMODULES_PAT` | ALL workflows (submodule checkout) | ❌ Missing | GitHub PAT with `repo` scope for `Conxian/*` org repos; fallback `github.token` has limited cross-org scope |
| `APP_PRIVATE_KEY` | Gemini AI workflows | ❌ Missing | GitHub App private key (PEM); created in GitHub App settings |
| `GEMINI_API_KEY` | Gemini AI workflows | ❌ Missing | Google AI Studio API key |
| `GOOGLE_API_KEY` | Gemini AI workflows | ❌ Missing | Google Cloud API key |
| `VERCEL_ORG_ID` | Vercel deployment | ❌ Missing | Vercel project settings > Team ID |
| `VERCEL_PROJECT_ID_SHOWCASE` | Vercel deployment | ❌ Missing | Vercel project settings > Project ID |
| `VERCEL_TOKEN` | Vercel deployment | ❌ Missing | Vercel account settings > Tokens |
| `GCP_PROJECT_ID` | GCP Cloud Run deployment | ❌ Missing | GCP project dashboard |
| `GCP_SA_KEY` | GCP Cloud Run deployment (IAM) | ❌ Missing | GCP service account JSON key |

**Priority order for provisioning:**
1. `CI_SUBMODULES_PAT` — highest blast radius (blocked workflows if submodule access fails)
2. `APP_PRIVATE_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY` — Gemini workflows blocked
3. `VERCEL_*` — Showcase dapp deployment blocked
4. `GCP_*` — Gateway Cloud Run deployment blocked

**DID-based replacement**: See `docs/architecture/DID_IDENTITY_AND_SECRET_MANAGEMENT.md` for the phased migration plan to replace all static GitHub secrets with DID Auth + OIDC federation (target Phase 4, Sprint +3).
