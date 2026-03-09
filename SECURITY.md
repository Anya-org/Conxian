# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x (Apex) | :white_check_mark: |
| 0.7.x   | :white_check_mark: |
| < 0.7.0 | :x:                |

## Reporting a Vulnerability

We take the security of the Conxian Protocol very seriously. If you find a security vulnerability, please report it via:

- **Email**: security@conxian.io
- **GitHub**: Use the "Report a vulnerability" button on the Security tab.

We acknowledge reports within 48 hours.

## Security Standards (Apex Upgrade v1.1.0)

- **Code is Law**: All logic is verifiable and sovereign.
- **Enhanced Circuit Breakers**: Protocol features a multi-tier system including global pauses and per-protocol **Isolation Mode** (`enhanced-circuit-breaker.clar`).
- **Contagion Guard**: Trustlessly isolate from external CSF-compliant protocol insolvency.
- **Rate Limiting**: Sensitive operations protected via window-based limiting.
- **Proof of Reserves**: Treasury verified via multi-attestor system.
- **Sovereign Handoff**: Admin roles transferable to DAO via staged process.
- **Compliance**: SIP-018 and jurisdictional compliance via `regulatory-adapter.clar`.

## Security Features (March 2026)

### Operational Safety
- **Enhanced Circuit Breaker**: Automated and manual pause triggers with fine-grained isolation for external liquidity sources.
- **Proof of Reserves**: Multi-attestor verification requiring 3+ attestations.
- **Rate Limiting**: 600-block window limiting per operation type.

### Access Control
- **Timelock Governance**: Delayed execution for critical parameter changes.
- **CSF Registry**: Restricted discovery and management of third-party routing targets.

### Compliance
- **Regulatory Adapter**: SIP-018 attestation aggregation.
- **KYC Registry**: On-chain verification of user/provider status.

---

*Last updated: March 15, 2026*
