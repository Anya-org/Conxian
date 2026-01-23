# Contributing to Conxius Wallet

Thank you for your interest in contributing to Conxius Wallet! We are building the sovereign financial stack for the next generation of Bitcoiners.

## Code of Conduct

Please treat all contributors with respect. We value technical excellence, honesty, and a "Bitcoin-first" mindset.

## Development Standards

### Tech Stack
- **Frontend**: React, Tailwind CSS, Lucide Icons
- **State Management**: Zustand (if applicable), React Context
- **Mobile Bridge**: Capacitor
- **Native**: Java (Android)
- **Testing**: Vitest (JS/TS), JUnit (Java)

### Commits
- Use [Conventional Commits](https://www.conventionalcommits.org/).
- Sign your commits (`git commit -S -m "..."`). We enforce GPG signing for security.

### Pull Requests
1.  **Fork** the repository.
2.  Create a **feature branch** (`feat/new-security-feature`).
3.  Ensure all tests pass (`npm test`).
4.  Submit a PR with a clear description of the changes.

## Areas for Contribution

### 1. UI/UX (Components)
We follow **Bitcoin Design Principles**.
- Improve accessibility (A11y).
- Enhance the "Sovereignty Meter" visualization.
- Refine animations for transaction states.

### 2. Enclave & Security (Java/TS)
- Optimize `SecureEnclave` Java implementation.
- Add support for new hardware wallets (e.g., Passport, Trezor).
- Enhance the `signer.ts` service with more BIP/SIP standards.

### 3. Institutional Features
- Extend `InvestorDashboard.tsx` with more risk metrics.
- Improve "Ops Personas" logic in `GovernancePortal.tsx`.

## Testing

We require high test coverage for all security-critical components.
- **IdentityManager**: Must mock all external API calls.
- **Signer**: Must validate against official test vectors (BIP-39, BIP-84).

## Security

**Do not submit security vulnerabilities via PR.** See [SECURITY.md](../SECURITY.md) for our disclosure policy.
