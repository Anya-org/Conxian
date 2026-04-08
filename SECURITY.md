# Security Policy

## Support Policy

Security fixes are applied on a rolling basis to the default branch (`main`).

When a tagged release line exists, only the latest release is supported with security updates.

| Channel | Security fixes |
| --- | --- |
| `main` (default branch) | Yes |
| Releases/tags older than the latest | No |
| Other branches/commits | Not actively maintained for security |

## Reporting a Vulnerability

Do not report security vulnerabilities via public GitHub issues.

Report vulnerabilities privately using one of these channels:

1. GitHub private vulnerability reporting (Security Advisories): use the repository Security tab and choose "Report a vulnerability".
2. Email: security@conxian-labs.com

When possible, include:

- A description of the vulnerability and potential impact
- Steps to reproduce (or a minimal proof-of-concept)
- The affected repository path/component (for example, `openspec/`, `scripts/`, or a specific submodule path)
- Any relevant logs, error messages, or stack traces (redact secrets)

If you cannot use either of the above, email admin@conxian-labs.com and clearly mark the message as a security report.

## Disclosure Policy

We follow a coordinated disclosure model:

1. We will acknowledge receipt of your report within 48-72 hours.
2. We will investigate and provide a timeline for remediation.
3. We ask that you do not disclose the vulnerability publicly until a fix has been released and coordinated.
4. We will credit you in a security advisory unless you prefer to remain anonymous.

## Secrets and environment files

- Do not commit any secret-bearing environment files (for example: `.env`, `.env.local`), private keys, or API tokens.
- `.env.example` may be committed as a non-secret template, but it must never contain real secrets.
- Ensure `.env`/`.env.*` patterns are listed in `.gitignore` so they are never committed by default (use an `!.env.example` exception if needed).
- This repository runs a `gitleaks` secret scan in GitHub Actions (see [`.github/workflows/secret-scan.yml`](./.github/workflows/secret-scan.yml)) on pull requests and pushes to `main`, `staged`, and `dev` to catch new secret leaks.

If a secret was committed to a public branch (even temporarily), treat it as compromised:

- Rotate/revoke the secret at the source (wallet/private key, API provider, cloud console).
- Update any dependent deployments/configuration to use the new secret.
- Consider rewriting Git history to remove the secret material (rotation is still required regardless).

If you discover that a secret was previously committed, also follow the reporting process in [Reporting a Vulnerability](#reporting-a-vulnerability) so the team can assess impact and coordinate incident response.

## Security Controls

Conxian-Labs utilizes several core security principles:

- **Zero Secret Egress (ZSE)**: Hardware-anchored private key derivation via Android StrongBox/Secure Enclave.
- **Veto-Quorum v2**: Protocol-level circuit breakers for automated risk management.
- **ATS Enforcement**: Automated compliance checks for all on-chain settlements.
