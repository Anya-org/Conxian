# AutoVault

[![Tests](https://img.shields.io/badge/Tests-58%2F58%20Passing-green)](https://github.com/Anya-org/AutoVault)
[![Contracts](https://img.shields.io/badge/Contracts-18%2F18%20Compiled-blue)](https://github.com/Anya-org/AutoVault)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready DeFi platform on Stacks with enhanced tokenomics,
automated DAO governance, and Bitcoin-aligned principles.

## Status

✅ **Production Ready** - All 18 contracts deployed and tested with
58/58 tests passing.

[View Complete Status](./documentation/STATUS.md)

## Features

- **Enhanced Tokenomics**: 10M AVG governance token, 5M AVLP liquidity
  token with progressive migration
- **Automated DAO**: Market-responsive buybacks and treasury management  
- **Creator Economy**: Merit-based bounty system with Bitcoin-aligned
  principles
- **Security**: Multi-signature treasury, emergency controls,
  comprehensive testing

[Complete Feature Documentation](./documentation/)

## Quick Start

### Requirements

- Clarinet CLI (v2.0+)
- Node.js (v18+)

### Setup

```bash
git clone https://github.com/Anya-org/AutoVault.git
cd AutoVault/stacks
npm install
clarinet check    # ✅ 18/18 contracts
npm test          # ✅ 58/58 tests
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

## Documentation

| Topic | Description |
|-------|-------------|
| [Architecture](./documentation/ARCHITECTURE.md) | System design and smart contracts |
| [Tokenomics](./documentation/TOKENOMICS.md) | Economic model and token mechanics |
| [Security](./documentation/SECURITY.md) | Security features and audit information |
| [API Reference](./documentation/API_REFERENCE.md) | Smart contract functions |
| [Deployment](./documentation/DEPLOYMENT.md) | Production deployment guide |
| [Developer Guide](./documentation/DEVELOPER_GUIDE.md) | Development setup and contributing |

[View All Documentation](./documentation/)

## License

MIT License

## Links

- **Repository**: [github.com/Anya-org/AutoVault](https://github.com/Anya-org/AutoVault)
- **Issues**: [Report bugs or request features](https://github.com/Anya-org/AutoVault/issues)
- **Documentation**: [Complete documentation](./documentation/)
