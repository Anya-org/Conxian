# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3.0 | :x:                |

## Reporting a Vulnerability

We take the security of the Conxian Protocol very seriously. If you find a security vulnerability, please do not report it publicly. Instead, please report it via one of the following methods:

- **Email**: security@conxian.io
- **GitHub**: Use the "Report a vulnerability" button on the Security tab.

We will acknowledge your report within 48 hours and provide a timeline for resolution.

## Security Standards

- **Code is Law**: All logic must be verifiable and sovereign.
- **Circuit Breakers**: Critical modules include circuit breakers for emergency pausing.
- **Rate Limiting**: Sensitive operations protected via `rate-limiter.clar` (window-based limiting per operation type).
- **Proof of Reserves**: Treasury assets verified via multi-attestor `proof-of-reserves.clar` system.
- **Sovereign Handoff**: Admin roles transferable to timelock/DAO via staged 5-step process.
- **Compliance**: KYC/AML verification via provider-based `compliance-manager.clar`.
- **Audits**: Core contracts undergo regular security audits.

## Security Features (January 2026)

### Operational Safety
- **Rate Limiter**: Window-based rate limiting (default 600 blocks/10 min) with operation-specific configuration
- **Proof of Reserves**: Multi-attestor verification requiring 3+ attestations, 7-day validity period
- **Circuit Breakers**: Automated pause triggers for emergency situations

### Access Control
- **Timelock Governance**: All critical changes require time-delayed execution
- **Role-Based Access**: Granular roles (owner, timelock, governance, operator) via `conxian-access.clar`
- **Sovereign Handoff**: Explicit 5-step procedure to transfer control from deployer to DAO

### Compliance
- **Provider Registry**: Authorized KYC/AML providers with structured registration
- **Sanctions Screening**: Integration points for sanctions list checking
- **Clean Hands**: On-chain compliance verification for sensitive operations

---

*Last updated: January 31, 2026*
