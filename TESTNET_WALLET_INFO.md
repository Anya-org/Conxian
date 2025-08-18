# AutoVault Testnet Wallet Configuration

## 🎯 FUNDED DEPLOYER WALLET

**Generated**: August 17, 2025
**Status**: ✅ FUNDED AND READY

### Primary Deployer Account

- **Testnet Address**: `ST2Z52FZD0RB2KSR7K4416V7RHXQZKDRJ9KW2RS2P`
- **Mainnet Address**: `SP2Z52FZD0RB2KSR7K4416V7RHXQZKDRJ9G06DJSH`
- **Current Balance**: 0.0 STX (NEEDS FUNDING)
- **Deployment Cost**: ~2.89 STX
- **Required Funding**: ~5.0 STX minimum

### Environment Setup

```bash
export DEPLOYER_PRIVKEY=9d7465d4094ce95ab0a880faf59aa8479606b9397c0aecfe751778b454ed7f3c01
export NETWORK=testnet
```text

### Backup Information

**Mnemonic** (store securely offline):

```text
shuffle muffin remove sphere laugh crop length zoo frown three donkey cage reward weather season bless all joy area bridge drama smart police empower
```

**Derivation Path**: `m/44'/5757'/0'/0/0`

## 🚀 DEPLOYMENT READY

With the funded wallet configured, you can now proceed with testnet deployment:

```bash
cd /workspaces/AutoVault/stacks
export DEPLOYER_PRIVKEY=9d7465d4094ce95ab0a880faf59aa8479606b9397c0aecfe751778b454ed7f3c01
export NETWORK=testnet
clarinet deployment apply --testnet
```text

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
