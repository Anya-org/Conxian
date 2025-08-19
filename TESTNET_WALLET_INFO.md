# AutoVault Testnet Wallet Configuration

## 🎯 FUNDED DEPLOYER WALLET

**Generated**: August 17, 2025
**Status**: ✅ FUNDED AND READY

### Primary Deployer Account

- **Testnet Address**: `ST14G8ACZNKBPR0WTX55NZ38NHN6K75AJ1ED4YDPC`
- **Mainnet Address**: `SP14G8ACZNKBPR0WTX55NZ38NHN6K75AJ1CWEMN41`
- **Current Balance**: 4.9905 STX (499,050,000 µSTX)
- **Deployment Cost**: ~2.89 STX
- **Remaining After Deployment**: ~2.1 STX

### Environment Setup

```bash
export DEPLOYER_PRIVKEY=ddf291b96c4b6c193440e3652470738bc064b587681edc76112c2695ac33644f01
export NETWORK=testnet
```

### Backup Information

**Mnemonic** (store securely offline):

```
light glare bench random limit flame change call boil wolf exercise bar test argue parade envelope execute chimney good seven warrior blue gorilla jaguar
```

**Derivation Path**: `m/44'/5757'/0'/0/0`

## 🚀 DEPLOYMENT READY

With the funded wallet configured, you can now proceed with testnet deployment:

```bash
cd /workspaces/AutoVault/stacks
export DEPLOYER_PRIVKEY=ddf291b96c4b6c193440e3652470738bc064b587681edc76112c2695ac33644f01
export NETWORK=testnet
npx clarinet deployment apply --testnet
```

## 📊 Balance Verification

Last checked: August 17, 2025

- ✅ Balance sufficient for deployment
- ✅ No pending transactions
- ✅ Address active on testnet

---

**Security Reminder**:

- Keep mnemonic offline and secure
- Never share private keys in public channels
- This is a testnet-only configuration
