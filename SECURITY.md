# Security Policy

## Supported Versions

Only the latest release (or the current `main` branch if no releases exist) is supported with security updates.

## Reporting a Vulnerability

If you find a security vulnerability, please do NOT open a public issue. Instead, report it privately to security@conxian-labs.com.

When possible, include:

- A clear description of the issue and impact
- Steps to reproduce (or a minimal PoC)
- The affected path/component (for example, `conxius-wallet`, `conxian-gateway`, `Conxian/contracts`)
- Any relevant logs, error messages, or stack traces (redact secrets)

We will acknowledge your report within 48 hours and provide a timeline for remediation. We ask for 90 days of responsible disclosure before any public announcement.

## Coordinated Disclosure

If you prefer, you may also use GitHub's private vulnerability reporting (when enabled for this repository). We will coordinate the fix and disclosure timeline with you.

## Secrets and environment files

- Do not commit any secret-bearing environment files (for example: `.env`, `.env.local`), private keys, or API tokens.
- `.env.example` may be committed as a non-secret template, but it must never contain real secrets.
- Ensure `.env`/`.env.*` patterns are listed in `.gitignore` so they are never committed by default (use an `!.env.example` exception if needed).
- This repository runs a `gitleaks` secret scan in GitHub Actions on pull requests and pushes to `main` to catch new secret leaks.

If a secret was committed to a public branch (even temporarily), treat it as compromised:

- Rotate/revoke the secret at the source (wallet/private key, API provider, cloud console).
- Update any dependent deployments/configuration to use the new secret.
- Consider rewriting Git history to remove the secret material (rotation is still required regardless).

If you discover that a secret was previously committed, also follow the reporting process in "Reporting a Vulnerability" so the team can assess impact and coordinate incident response.

## Security Controls

Conxian-Labs utilizes several core security principles:

- **Zero Secret Egress (ZSE)**: Hardware-anchored private key derivation via Android StrongBox/Secure Enclave.
- **Veto-Quorum v2**: Protocol-level circuit breakers for automated risk management.
- **ATS Enforcement**: Automated compliance checks for all on-chain settlements.

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs.
