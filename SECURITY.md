# Security Policy

## Supported Versions

We only support the latest release of Conxius Wallet. Please ensure you are running the most recent version available on GitHub Releases or the Google Play Store.

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do not open a public issue.**

If you discover a vulnerability in Conxius Wallet (Enclave, Mobile App, or Signing Service), please report it privately.

### Disclosure Process

1. **Email**: Send details to `security@conxian.com`.
1. **PGP Key**: Use our [PGP Key](https://conxian.com/security.asc) (Fingerprint: `XXXX XXXX ...`) to encrypt your message.
1. **Response**: We will acknowledge receipt within 48 hours.
1. **Timeline**: We aim to resolve critical issues within 30 days. We ask for a 90-day embargo on public disclosure to allow for user upgrades.

## Bounty Program

We appreciate the work of security researchers. Bounties for critical vulnerabilities (e.g., Key Extraction, Remote Code Execution, Seed Leakage) are awarded at the discretion of Conxian Labs.

- **Critical**: Up to $50,000 USD (BTC/USDC)
- **High**: Up to $10,000 USD
- **Medium**: Up to $2,000 USD
- **Low**: Swag / Hall of Fame

## Scope

- **In Scope**:
  - `android/` (Native Enclave implementation)
  - `services/signer.ts` (Cryptographic operations)
  - `components/` (XSS vectors in UI)
  - Hardware Wallet Integration logic

- **Out of Scope**:
  - Third-party libraries (unless a novel implementation issue)
  - Phishing attacks against users
  - Physical attacks on unlocked devices (Evil Maid)

## Safe Harbor

Conxian Labs will not pursue legal action against researchers who:

- Engage in testing of systems/research without harming Conxian or its users.
- Adhere to this policy.
- Report vulnerabilities in good faith.
