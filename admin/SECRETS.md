# Conxian Workspace Secret Management

This document defines the central registry of secrets required to operate the Conxian workspace, build systems, and deployment pipelines.

## 🛡️ Zero Secret Egress (ZSE) Compliance

In accordance with the **Zero Secret Egress (ZSE)** mandate, all sensitive keys and operational secrets have been migrated to the **Linear Virtual Office**.

**Access Requirements:**
- **Strategy & Governance**: [Linear Virtual Office (Strategic)](https://linear.app/conxian-labs)
- **Sensitive Operations**: [Linear Virtual Office (Operations)](https://linear.app/conxian-labs)

## GitHub Organization / Repository Secrets

Secrets for CI/CD automation (e.g., `PAT_TOKEN`, `NPM_TOKEN`, `GCP_CREDENTIALS`) must be set up in the GitHub Settings. For detailed provisioning instructions, refer to the [Secret Management Specification](https://linear.app/conxian-labs/document/sensitive-secret-management-spec) in Linear.

## Local Development Environments (`.env`)

For local development, refer to the `.env.example` files in each repository. **Never commit `.env` files.**

### 1. Smart Contracts & Deployment (`Conxian` & `stacksorbit`)
- `HIRO_API_KEY`
- `DEPLOYER_PRIVKEY`
- `SYSTEM_PRIVKEY`

### 2. Backend & Gateway (`conxius-platform` & `conxian-nexus`)
- `DATABASE_URL`
- `GATEWAY_JWT_SECRET`

---

## Secret Provisioning Script

To validate that your local environment is correctly configured, you can run the validation script located at `admin/validate-env.ps1`.

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs. Powered by Bitcoin.
