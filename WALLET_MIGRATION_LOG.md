# AutoVault Testnet Wallet Migration

## Date: 2025-08-18

## Migration Type: Security-Driven Key Rotation

### Summary

Generated new secure testnet wallet to replace compromised keys following security incident.

### New Wallet Details

- **Generation Method**: AutoVault secure key generator (BIP39 compliant)
- **Testnet Address**: `ST2Z52FZD0RB2KSR7K4416V7RHXQZKDRJ9KW2RS2P`
- **Mainnet Address**: `SP2Z52FZD0RB2KSR7K4416V7RHXQZKDRJ9G06DJSH`
- **Derivation Path**: `m/44'/5757'/0'/0/0`
- **Current Balance**: 0.0 STX (requires funding)

### Old Wallet (DEPRECATED)

- **Testnet Address**: `ST14G8ACZNKBPR0WTX55NZ38NHN6K75AJ1ED4YDPC`
- **Status**: COMPROMISED - Do not use
- **Balance**: ~4.99 STX (needs transfer to new wallet)

### Required Actions

1. **Fund New Wallet**: Transfer STX from old address to new address
2. **Update Environment**: Use new private key for deployments
3. **Verify Security**: Confirm old keys are not used in any systems

### Deployment Configuration

```bash
# New secure configuration
export DEPLOYER_PRIVKEY=9d7465d4094ce95ab0a880faf59aa8479606b9397c0aecfe751778b454ed7f3c01
export NETWORK=testnet

# Deploy with new wallet
cd /workspaces/AutoVault/stacks
npm run deploy-contracts-ts
```

### Security Compliance

- ✅ BIP39 standard mnemonic generation
- ✅ Proper derivation path (SLIP-0044 Stacks coin type 5757)
- ✅ Secure random number generation
- ✅ Offline mnemonic backup instructions
- ✅ Bitcoin ethos compliance (user sovereignty)

---
**Status**: NEW WALLET GENERATED - Ready for funding and deployment
**Next Steps**: Fund new wallet and proceed with secure deployment
