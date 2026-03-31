# Conxian Workspace Secret Management

This document defines the central registry of secrets required to operate the Conxian workspace, build systems, and deployment pipelines.

## GitHub Organization / Repository Secrets

These secrets must be set up in the GitHub Settings for the `conxian-business` repository (or organization-wide if preferred) to enable full CI/CD automation across the workspace.

| Secret Name | Purpose | Required By |
|-------------|---------|-------------|
| `PAT_TOKEN` | Personal Access Token with repo scope to bypass branch protection rules for automated submodule syncing. | Auto-sync workflow (`auto-sync-submodules.yml`) |
| `NPM_TOKEN` | Authentication token to publish NPM packages. | `conxius-wallet`, `stacksorbit`, `conxian-ui` |
| `PYPI_API_TOKEN` | Authentication token to publish Python packages. | `stacksorbit` |
| `GCP_CREDENTIALS` | JSON key for Google Cloud Platform Service Account to handle infrastructure deployments and serverless proxies. | `conxius-wallet`, `conxius-platform` |
| `CHANGELLY_API_KEY` | API Key for Changelly exchange integration. | `conxius-wallet` (Proxy deployment) |
| `CHANGELLY_API_SECRET` | Secret Key for Changelly exchange integration. | `conxius-wallet` (Proxy deployment) |

*Note: `GITHUB_TOKEN` is automatically provided by GitHub Actions and does not need to be manually provisioned.*

---

## Local Development Environments (`.env`)

For local development, different repositories require specific `.env` variables. **Never commit `.env` files.**

### 1. Smart Contracts & Deployment (`Conxian` & `stacksorbit`)

These repositories interact with the Stacks blockchain.

- `NETWORK`: (e.g., `testnet` or `mainnet`)
- `HIRO_API_KEY`: API Key for Hiro Platform
- `DEPLOYER_ADDRESS`: The Stacks address deploying the contracts
- `DEPLOYER_PRIVKEY` / `STACKS_DEPLOYER_PRIVKEY`: Private key for the deployer address
- `SYSTEM_ADDRESS`: Operations wallet address
- `SYSTEM_PRIVKEY`: Private key for the system address
- `CORE_API_URL` / `STACKS_API_BASE`: Node RPC URL (e.g., `https://api.testnet.hiro.so`)

### 2. Backend & Gateway (`conxius-platform` & `conxian-nexus`)

These repositories run the core backend logic, rust engine, and API gateway.

- `DATABASE_URL` / `CORE_DB_URI`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `GATEWAY_JWT_SECRET`: Secret used to sign authentication tokens
- `GATEWAY_ADMIN_API_KEY`: Fixed token for internal admin requests
- `GCP_PROJECT_ID` & `GCP_REGION`: Cloud infrastructure targeting

---

## Secret Provisioning Script

To validate that your local environment is correctly configured, you can run the validation script located at `admin/validate-env.ps1`.

---

## 3. Local Development Keys & Security (ZSE Compliance)

**WARNING: NEVER COMMIT PRIVATE KEYS OR SENSITIVE CREDENTIALS TO THIS REPOSITORY.**

In accordance with the **Zero Secret Egress (ZSE)** mandate, all sensitive keys (such as `DEPLOYER_PRIVKEY` or `SYSTEM_PRIVKEY`) must be managed via:
1.  **Secure Environment Variables**: Use local `.env` files (which are ignored by git).
2.  **Hardware Security Modules (HSM)**: For production, use Android StrongBox/Secure Enclave as specified in our architecture.
3.  **Encrypted Password Managers**: For shared development secrets, use an organization-approved vault.

If you need to provision a new environment, refer to the `admin/validate-env.ps1` script and ensure your local `.env` matches the requirements listed in Section 2.
