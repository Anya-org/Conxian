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

## Security Controls

Conxian-Labs utilizes several core security principles:

- **Zero Secret Egress (ZSE)**: Hardware-anchored private key derivation via Android StrongBox/Secure Enclave.
- **Veto-Quorum v2**: Protocol-level circuit breakers for automated risk management.
- **ATS Enforcement**: Automated compliance checks for all on-chain settlements.

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs.
