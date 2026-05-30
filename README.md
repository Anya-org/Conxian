# Conxian Finance Protocol

[![Status](https://img.shields.io/badge/Status-Active-green.svg)](https://www.conxian-labs.com)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

## Purpose

Ship the Conxian Protocol smart contracts and related protocol logic for the Conxian ecosystem.

## Status

**Active development.** This repository is the canonical public protocol codebase and should be treated as the source repository for protocol-facing smart-contract development.

## Scope

This repository contains protocol contracts, protocol documentation, and related technical materials. It does not contain company administrative systems, legal operations, or private business workflows.

## Governance relation

This repository is maintained by Conxian Labs. The code is public and GPL-3.0 licensed, while governance of the protocol is intended to decentralize progressively after mainnet.

## Audience

- protocol engineers
- security reviewers
- integrators and indexer developers
- contributors building on Conxian contracts

## Relationship to the Conxian stack

- protocol core: this repository
- middleware and indexing: [Conxian Gateway](https://github.com/Conxian/conxian-gateway)
- wallet and reference client: [Conxius Wallet](https://github.com/Conxian/conxius-wallet)
- interface layer: [Conxian UI](https://github.com/Conxian/conxian_ui)

## Repository structure

```text
/contracts/
├── traits/
├── core/
├── dex/
├── agents/
├── tokens/
├── oracle/
├── treasury/
└── ...
```

## Security

Do not disclose vulnerabilities publicly. Use [SECURITY.md](SECURITY.md) or GitHub private vulnerability reporting.

## Contact

- General: [info@conxian-labs.com](mailto:info@conxian-labs.com)
- Support: [support@conxian-labs.com](mailto:support@conxian-labs.com)
- Security: [security@conxian-labs.com](mailto:security@conxian-labs.com)

## License

GPL-3.0
