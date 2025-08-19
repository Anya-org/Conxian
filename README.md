# AutoVault

[![Tests](https://img.shields.io/badge/Tests-65%2F65%20Passing-green)](https://github.com/Anya-org/AutoVault)
[![Contracts](https://img.shields.io/badge/Contracts-30%20Compiled-blue)](https://github.com/Anya-org/AutoVault)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready DeFi platform on Stacks with enhanced tokenomics,
automated DAO governance, DEX subsystem groundwork, circuit breaker &
enterprise monitoring, and Bitcoin-aligned principles.

## Status

✅ **Production Ready** – 30 contracts compile successfully with
65/65 tests passing (unit, integration, production validation, security).

[View Complete Status](./documentation/STATUS.md)

## Features

- **Enhanced Tokenomics**: 10M AVG governance token, 5M AVLP liquidity token with progressive migration & revenue sharing
- **Automated DAO**: Time-weighted voting, timelock, automation & buybacks
- **DEX Foundations**: Factory, pool, router, math-lib, multi-hop & pool variants (design + partial impl)
- **Circuit Breaker & Monitoring**: Structured numeric event codes for volatility, volume & liquidity safeguards
- **Creator Economy**: Merit & automation-driven bounty systems
- **Security & Precision**: Multi-sig treasury, emergency pause, precision math, enterprise monitoring

[Complete Feature Documentation](./documentation/)

## Quick Start

### Requirements

- Node.js (v18+)
  
Note: This repo pins Clarinet SDK v3.5.0 via npm. Always use `npx clarinet`.

### Setup

```bash
git clone https://github.com/Anya-org/AutoVault.git
cd AutoVault/stacks
npm install
npx clarinet check    # ✅ 30 contracts
npm test          # ✅ 65/65 tests
```

### Deploy

```bash
# Testnet
../scripts/deploy-testnet.sh

# Production  
../scripts/deploy-mainnet.sh
```

[Complete Setup Guide](./documentation/DEVELOPER_GUIDE.md)

📚 **[Complete Architecture Documentation](./documentation/)**

## Documentation (Aligned – Updated Aug 17, 2025)

| Topic | Description |
|-------|-------------|
| [Architecture](./documentation/ARCHITECTURE.md) | System design (incl. DEX, breaker, monitoring) |
| [Tokenomics](./documentation/TOKENOMICS.md) | Economic model and token mechanics |
| [Security](./documentation/SECURITY.md) | Security features and audit information |
| [API Reference](./documentation/API_REFERENCE.md) | Smart contract functions |
| [Deployment](./documentation/DEPLOYMENT.md) | Production deployment guide |
| [Developer Guide](./documentation/DEVELOPER_GUIDE.md) | Development setup and contributing |
| [Status](./documentation/STATUS.md) | Current contract & test inventory |

[View All Documentation](./documentation/)

## License

MIT License

## Links

- **Repository**: [github.com/Anya-org/AutoVault](https://github.com/Anya-org/AutoVault)
- **Issues**: [Report bugs or request features](https://github.com/Anya-org/AutoVault/issues)
- **Documentation**: [Complete documentation](./documentation/)

*Counts reflect repository state as of Aug 17, 2025.*
