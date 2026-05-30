# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.1.x | ✅ |
| 0.7.x | ✅ |
| < 0.7.0 | ❌ |

## Reporting a Vulnerability

We take the security of the Conxian Protocol seriously.

Do **not** disclose vulnerabilities in public issues.

Report privately using one of these channels:

- GitHub private vulnerability reporting on this repository
- Email [security@conxian-labs.com](mailto:security@conxian-labs.com)

We aim to acknowledge reports within 48 hours.

## Secret handling

- do not commit `.env*` files, private keys, or API tokens
- use `.env.example` only as a non-secret template
- rotate any exposed credentials immediately

## Security expectations

- protocol logic should remain verifiable and reviewable
- breaking security changes should be documented clearly
- governance and admin controls should be explicit in code and docs
