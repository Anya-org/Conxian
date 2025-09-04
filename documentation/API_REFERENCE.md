# Conxian Enhanced Tokenomics API Reference

This comprehensive API reference covers all contracts and functions in the Conxian Enhanced Multi-Token Tokenomics system. Use this guide to integrate with the protocol programmatically.

## Table of Contents

- [Overview](#overview)
- [Core Token Contracts](#core-token-contracts)
- [System Infrastructure](#system-infrastructure)
- [Enhanced Mechanisms](#enhanced-mechanisms)
- [Dimensional Integration](#dimensional-integration)
- [Integration Examples](#integration-examples)
- [Error Codes](#error-codes)
- [SDK Usage](#sdk-usage)

## Overview

The Conxian Enhanced Tokenomics system consists of 11 smart contracts working together to provide a comprehensive DeFi tokenomics solution. All contracts follow SIP-010 (fungible tokens) and SIP-009 (NFTs) standards where applicable.

### Contract Architecture

```
Core Tokens → System Infrastructure → Enhanced Mechanisms → Dimensional Integration
     ↓                    ↓                      ↓                    ↓
- cxd-token          - protocol-monitor    - cxd-staking      - dim-revenue-adapter
- cxvg-token         - emission-controller - cxvg-utility     - tokenized-bond-adapter  
- cxlp-token         - revenue-distributor - cxlp-migration
- cxtr-token         - system-coordinator
```

### Network Endpoints

**Mainnet:**
- API Base: `https://api.mainnet.hiro.so`
- Deployer: `SP1234...` (Production deployment address)

**Testnet:**
- API Base: `https://api.testnet.hiro.so`  
- Deployer: `ST1234...` (Staging deployment address)

**Local Development:**
- API Base: `http://localhost:3999`
- Deployer: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`

## Core Token Contracts

### CXD Token (cxd-token.clar)

The primary revenue-generating token for the Conxian ecosystem.

#### SIP-010 Standard Functions

**Transfer**
```javascript
// Transfer CXD tokens
(transfer amount sender recipient memo)
```

**Get Balance**
```javascript
// Get CXD balance for a principal
(get-balance account)
```

**Get Total Supply**
```javascript
// Get total CXD supply
(get-total-supply)
```

#### Enhanced Functions

**Mint (Admin Only)**
```javascript
// Mint new CXD tokens (requires emission controller approval)
(mint recipient amount)
```

**Burn**
```javascript
// Burn CXD tokens from caller's balance
(burn amount)
```

**Enable System Integration**
```javascript
// Enable integration with tokenomics system (admin only)
(enable-system-integration coordinator emission-controller monitor)
```

#### System Integration Functions

**System Transfer**
```javascript
// Transfer via system coordinator
(system-transfer amount sender recipient)
```

**Get Integration Status**
```javascript
// Check if system integration is enabled
(get-integration-status)
```

### CXVG Token (cxvg-token.clar)

Governance token with utility mechanisms and fee discount features.

#### Core Functions

**Transfer**
```javascript
// Standard SIP-010 transfer
(transfer amount sender recipient memo)
```

**Lock for Governance**
```javascript
// Lock CXVG for governance utilities
(lock-tokens amount duration)
```

**Unlock Tokens**
```javascript
// Unlock expired governance locks
(unlock-tokens)
```

#### Governance Functions

**Create Bonded Proposal**
```javascript
// Bond CXVG to create governance proposal
(create-bonded-proposal bond-amount emergency)
```

**Vote on Proposal**
```javascript
// Vote on governance proposal
(vote proposal-id vote-choice)
```

**Get Voting Power**
```javascript
// Get current voting power for address
(get-voting-power account)
```

**Get Fee Discount**
```javascript
// Get fee discount percentage for locked tokens
(get-fee-discount account)
```

### CXLP Token (cxlp-token.clar)

Legacy migration token with time-banded conversion bonuses.

#### Migration Functions

**Configure Migration**
```javascript
// Configure migration parameters (admin only)
(configure-migration target-token start-delay epoch-length)
```

**Set Liquidity Parameters**
```javascript
// Set migration limits and bonuses (admin only)
(set-liquidity-params epoch-cap user-base-cap duration-factor 
                      user-max-cap midyear-blocks adjustment-factor)
```

**Initiate Migration**
```javascript
// Migrate CXLP to CXD tokens
(initiate-migration amount)
```

**Get Migration Status**
```javascript
// Get current migration band and conversion rate
(get-migration-status)
```

**Get User Migration Info**
```javascript
// Get user's migration history and limits
(get-user-migration-info account)
```

### CXTR Token (cxtr-token.clar)

Contributor token with soulbound characteristics and reputation system.

#### Core Functions

**Mint Contribution**
```javascript
// Mint CXTR for contributions (admin only)
(mint-contribution recipient amount contribution-type)
```

**Get Contribution History**
```javascript
// Get contribution history for account
(get-contribution-history account)
```

**Get Reputation Score**
```javascript
// Calculate reputation score based on contributions
(get-reputation-score account)
```

#### Integration Functions

**Enable Governance Integration**
```javascript
// Enable CXTR integration with governance utilities
(enable-governance-integration utility-contract)
``` \
  --data-binary @signed_tx.bin \
  'https://api.testnet.hiro.so/v2/transactions'
```

- `signed_tx.bin` is a fully signed Stacks transaction (e.g., contract-call to `deposit`).
- Build and sign with stacks.js or a backend signer; then broadcast using this endpoint.

## Get transaction status

Extended endpoint: `GET /extended/v1/tx/{txid}`

```bash
curl -s 'https://api.testnet.hiro.so/extended/v1/tx/0xYOUR_TXID'
```

## Contract interface and ABI

Endpoint: `GET /v2/contracts/interface/{contract_address}/{contract_name}`

```bash
curl -s 'https://api.testnet.hiro.so/v2/contracts/interface/{deployer-address}/vault'
```

## Events (indexer)

Get events for a contract (Extended API):

```bash
curl -s 'https://api.testnet.hiro.so/extended/v1/contract/{deployer-address}.vault/events?limit=50'
```

## Helper scripts

In `scripts/` we provide small utilities that respect env vars and inject the API key header if present:

- `scripts/ping.sh` — sanity check against `/v2/info`
- `scripts/call-read.sh` — POST call-read for read-only functions
- `scripts/get-abi.sh` — GET ABI for a contract
- `scripts/broadcast-tx.sh` — POST a signed tx binary

Make them executable and run:

```bash
chmod +x scripts/*.sh

# Example: call-read get-fees (no args)
CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-fees ./scripts/call-read.sh

# Example: ping with API key header
export HIRO_API_KEY="<your-key>"
./scripts/ping.sh | jq .network_id
```

## Local development (Clarinet)

Note: This repo pins Clarinet SDK v3.5.0 via npm. Use `npx clarinet` to ensure the correct version.

- `npx clarinet check` — compile and static analysis.
- `npx clarinet console` — ephemeral devnet + REPL to call functions:

```clj
;; inside console
(contract-call? .vault deposit u100)
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault withdraw u50)
```

Clarinet console uses a local stacks-devnet under the hood; to interact programmatically from a script, you can point clients to the local API exposed by the devnet (Clarinet will show the URL when running the console).

## Suggested client stack

- Browser dApp: `@stacks/connect`, `@stacks/transactions`, `@stacks/network`
- Backend signer (optional): `@stacks/transactions` in Node.js for assembling and signing txs
- Monitoring: poll `extended/v1/tx`, consume events via extended API

## Notes

- Always test on testnet/devnet before mainnet.
- Use post-conditions in contract-calls to guard against unintended transfers.
- Keep arguments small to minimize gas and payload size.

## Router Error Codes (Multi-Hop Router)

| Code | Symbol | Description |
|------|--------|-------------|
| u600 | ERR_INVALID_PATH | Path or pools list length mismatch / invalid structure |
| u601 | ERR_INSUFFICIENT_OUTPUT | Final output less than required (exact-out safety) |
| u602 | ERR_SLIPPAGE_EXCEEDED | User slippage bound breached (legacy check) |
| u603 | ERR_INVALID_ROUTE | Route/pool mismatch or unsupported params |
| u604 | ERR_NO_LIQUIDITY | Pool returned insufficient liquidity |
| u605 | ERR_EXPIRED | Deadline lower than current block-height |
| u606 | ERR_UNAUTHORIZED | Caller lacks admin rights |
| u607 | ERR_INVALID_POOL_TYPE | Pool type not in allowed whitelist |
| u608 | ERR_IDENTICAL_TOKENS | Identical input/output token in path or pool registration |
| u609 | ERR_INACTIVE_POOL | Pool flagged inactive in registry |
| u610 | ERR_INVALID_FEE_TIER | Fee tier not present or disabled in `fee-tiers` map |
| u611 | ERR_SLIPPAGE_POLICY | User-specified min/max violates protocol slippage policy |

### Slippage Policy Enforcement

Global variable: `max-slippage-bps` (basis points, denominator 10000). Default: `u1000` (10%).

Rules:
1. swap-exact-in-multi-hop: `min-amount-out >= gross-out - (gross-out * max-slippage-bps / 10000)` or `ERR_SLIPPAGE_POLICY`.
2. swap-exact-out-multi-hop: `max-amount-in <= required-in + (required-in * max-slippage-bps / 10000)` or `ERR_SLIPPAGE_POLICY`.

Rationale: Prevents overly permissive parameters that expand MEV extraction surface or silent value leakage.

### Pool Type Validation
Allowed types (constant list): `constant-product`, `stable`, `weighted`, `concentrated`.

### Fee Tier Validation
`register-pool` checks `fee-tiers` map for an enabled record; otherwise `ERR_INVALID_FEE_TIER`.

### Path / Hop Constraints
`MAX_HOPS = 5`; pools length must equal `path length - 1`; iterative unrolled execution avoids recursion limits in Clarity.

## DEX Router Direct API (Integration Guide)

The DEX router exposes direct trait-typed entry points. Resolve your pool from the factory and call the "-direct" functions with the pool contract principal.

Public functions:
- add-liquidity-direct(pool, dx, dy, min-shares, deadline)
- remove-liquidity-direct(pool, shares, min-dx, min-dy, deadline)
- swap-exact-in-direct(pool, amount-in, min-out, x-to-y, deadline)
- get-amount-out-direct(pool, amount-in, x-to-y) -> response uint uint

Factory read-only:
- get-pool(token-x, token-y) -> (optional { pool: principal })

Integration steps:
1) Call `dex-factory.get-pool(token-x, token-y)` (order-insensitive) to get the pool principal.
2) Pass the pool principal into router "-direct" calls as a contract principal argument.

Tip: See `stacks/tests/helpers/routerSdk.ts` for a tiny helper that abstracts these steps in tests.

## Enhanced Tokenomics System

### xCXD Staking Contract

The xCXD staking system provides enhanced yield through time-locked CXD deposits with warmup/cooldown periods.

#### Staking Functions

**Initiate Stake**
```javascript
// Start CXD staking with warmup period
await callContractFunction({
  contractAddress: 'ST...', 
  contractName: 'xcxd-staking',
  functionName: 'initiate-stake',
  functionArgs: [uintCV(1000000)] // 1 CXD
});
```

**Complete Stake**
```javascript
// Complete stake after warmup period
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'xcxd-staking', 
  functionName: 'complete-stake',
  functionArgs: []
});
```

**Initiate Unstake**
```javascript
// Begin unstaking process
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'xcxd-staking',
  functionName: 'initiate-unstake', 
  functionArgs: [uintCV(500000)] // 0.5 CXD
});
```

**Complete Unstake**
```javascript
// Complete unstake after cooldown
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'xcxd-staking',
  functionName: 'complete-unstake',
  functionArgs: []
});
```

#### Staking Read Functions

**Get Staking Info**
```javascript
// Get user staking details
const result = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'xcxd-staking',
  functionName: 'get-staking-info',
  functionArgs: [principalCV('ST...')]
});
```

**Get Rewards**
```javascript
// Calculate pending rewards
const rewards = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'xcxd-staking', 
  functionName: 'get-pending-rewards',
  functionArgs: [principalCV('ST...')]
});
```

### CXLP Migration Contract

Handles time-banded CXLP → CXD migration with pro-rata settlement and intent queues.

#### Migration Functions

**Create Migration Intent**
```javascript
// Create CXLP migration intent
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'cxlp-migration',
  functionName: 'create-migration-intent',
  functionArgs: [
    uintCV(10000000), // 10 CXLP
    uintCV(block.height + 1000) // Execution block
  ]
});
```

**Execute Migration**
```javascript
// Execute pending migration
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'cxlp-migration',
  functionName: 'execute-migration',
  functionArgs: [uintCV(intentId)]
});
```

**Cancel Migration**
```javascript
// Cancel pending migration intent
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'cxlp-migration',
  functionName: 'cancel-migration-intent',
  functionArgs: [uintCV(intentId)]
});
```

#### Migration Read Functions

**Get Migration Rate**
```javascript
// Get current CXLP → CXD conversion rate
const rate = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'cxlp-migration',
  functionName: 'get-migration-rate',
  functionArgs: []
});
```

**Get Intent Status**
```javascript
// Check migration intent status
const intent = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'cxlp-migration',
  functionName: 'get-migration-intent',
  functionArgs: [uintCV(intentId)]
});
```

### Revenue Distribution System

Manages protocol fee collection and distribution to token holders.

#### Revenue Functions

**Distribute Revenue**
```javascript
// Trigger revenue distribution (admin only)
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'revenue-distributor',
  functionName: 'distribute-revenue',
  functionArgs: []
});
```

**Claim Rewards**
```javascript
// Claim user rewards
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'revenue-distributor',
  functionName: 'claim-rewards',
  functionArgs: []
});
```

#### Revenue Read Functions

**Get Claimable Rewards**
```javascript
// Check claimable rewards for user
const rewards = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'revenue-distributor',
  functionName: 'get-claimable-rewards',
  functionArgs: [principalCV('ST...')]
});
```

**Get Revenue Stats**
```javascript
// Get revenue distribution statistics
const stats = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'revenue-distributor',
  functionName: 'get-revenue-stats',
  functionArgs: []
});
```

### Dimensional Integration

Connects the tokenomics system with dimensional vault protocols for enhanced yield.

#### Dimensional Adapter Functions

**Deposit to Dimensional Vault**
```javascript
// Deposit tokens to dimensional yield vault
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'dimensional-adapter',
  functionName: 'deposit-to-vault',
  functionArgs: [
    uintCV(1000000), // Amount
    stringAsciiCV('yield-vault-1') // Vault ID
  ]
});
```

**Harvest Dimensional Yield**
```javascript
// Harvest yield from dimensional vaults
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'dimensional-adapter',
  functionName: 'harvest-yield',
  functionArgs: [stringAsciiCV('yield-vault-1')]
});
```

#### Dimensional Read Functions

**Get Vault Info**
```javascript
// Get dimensional vault information
const vaultInfo = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'dimensional-adapter',
  functionName: 'get-vault-info',
  functionArgs: [stringAsciiCV('yield-vault-1')]
});
```

**Get User Position**
```javascript
// Get user position in dimensional vault
const position = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'dimensional-adapter',
  functionName: 'get-user-position',
  functionArgs: [
    principalCV('ST...'),
    stringAsciiCV('yield-vault-1')
  ]
});
```

### System Integration

Coordinates interactions between all tokenomics system components.

#### Token Coordinator Functions

**Coordinate Revenue Flow**
```javascript
// Coordinate revenue flow between systems (admin only)
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'token-coordinator',
  functionName: 'coordinate-revenue-flow',
  functionArgs: []
});
```

**Update System Parameters**
```javascript
// Update system-wide parameters (governance only)
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'token-coordinator',
  functionName: 'update-system-parameter',
  functionArgs: [
    stringAsciiCV('emission-rate'),
    uintCV(5000) // 50 basis points
  ]
});
```

#### System Monitor Functions

**Check System Health**
```javascript
// Check overall system health
const health = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'protocol-invariant-monitor',
  functionName: 'check-system-health',
  functionArgs: []
});
```

**Get System Metrics**
```javascript
// Get comprehensive system metrics
const metrics = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'protocol-invariant-monitor',
  functionName: 'get-system-metrics',
  functionArgs: []
});
```

### Circuit Breaker System

Provides emergency controls and automated safety mechanisms.

#### Circuit Breaker Functions

**Emergency Pause**
```javascript
// Emergency pause system (admin only)
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'circuit-breaker',
  functionName: 'emergency-pause',
  functionArgs: [stringAsciiCV('SECURITY_BREACH')]
});
```

**Resume Operations**
```javascript
// Resume operations after pause
await callContractFunction({
  contractAddress: 'ST...',
  contractName: 'circuit-breaker',
  functionName: 'resume-operations',
  functionArgs: []
});
```

#### Circuit Breaker Read Functions

**Is System Paused**
```javascript
// Check if system is paused
const isPaused = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'circuit-breaker',
  functionName: 'is-system-paused',
  functionArgs: []
});
```

**Get Pause Reason**
```javascript
// Get reason for system pause
const reason = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'circuit-breaker',
  functionName: 'get-pause-reason',
  functionArgs: []
});
```

## System Error Codes

### Core Token Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller lacks required permissions |
| u101 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| u102 | ERR_INVALID_AMOUNT | Amount must be greater than zero |
| u103 | ERR_TRANSFER_FAILED | Token transfer operation failed |
| u104 | ERR_MINT_FAILED | Token minting operation failed |
| u105 | ERR_BURN_FAILED | Token burning operation failed |

### Staking System Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u200 | ERR_STAKE_NOT_FOUND | No staking position found |
| u201 | ERR_WARMUP_PERIOD | Still in warmup period |
| u202 | ERR_COOLDOWN_PERIOD | Still in cooldown period |
| u203 | ERR_INSUFFICIENT_STAKE | Insufficient staked amount |
| u204 | ERR_STAKE_LOCKED | Stake is time-locked |
| u205 | ERR_ALREADY_STAKING | User already has active stake |

### Migration System Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u300 | ERR_INTENT_NOT_FOUND | Migration intent not found |
| u301 | ERR_INTENT_EXPIRED | Migration intent has expired |
| u302 | ERR_EXECUTION_TOO_EARLY | Cannot execute before target block |
| u303 | ERR_MIGRATION_PAUSED | Migration system is paused |
| u304 | ERR_INVALID_CONVERSION_RATE | Invalid conversion rate |
| u305 | ERR_QUEUE_FULL | Migration intent queue is full |

### Revenue System Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u400 | ERR_NO_REWARDS | No rewards available to claim |
| u401 | ERR_DISTRIBUTION_FAILED | Revenue distribution failed |
| u402 | ERR_CLAIM_FAILED | Reward claim operation failed |
| u403 | ERR_INSUFFICIENT_REVENUE | Insufficient revenue for distribution |
| u404 | ERR_ALREADY_CLAIMED | Rewards already claimed for period |

### System Monitor Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u500 | ERR_SYSTEM_PAUSED | System operations are paused |
| u501 | ERR_INVARIANT_VIOLATED | Protocol invariant check failed |
| u502 | ERR_THRESHOLD_EXCEEDED | System threshold exceeded |
| u503 | ERR_MONITOR_DISABLED | System monitor is disabled |
| u504 | ERR_HEALTH_CHECK_FAILED | System health check failed |

### Dimensional Integration Errors

| Code | Symbol | Description |
|------|--------|-------------|
| u600 | ERR_VAULT_NOT_FOUND | Dimensional vault not found |
| u601 | ERR_VAULT_PAUSED | Dimensional vault is paused |
| u602 | ERR_YIELD_HARVEST_FAILED | Yield harvest operation failed |
| u603 | ERR_POSITION_NOT_FOUND | User position not found |
| u604 | ERR_INSUFFICIENT_LIQUIDITY | Insufficient vault liquidity |

## Testing and Deployment

### Contract Testing

**Unit Tests**
```bash
# Run unit tests for all contracts
npx clarinet test tests/*unit*.test.ts

# Run specific contract tests
npx clarinet test tests/cxd-token.test.ts
```

**Integration Tests**
```bash
# Run integration tests
npx clarinet test tests/tokenomics-integration-tests.clar

# Run system validation tests
npx clarinet test tests/system-validation-tests.clar
```

### Deployment

**Environment Configuration**
```bash
# Development deployment
./scripts/deploy-tokenomics.sh development

# Staging deployment  
./scripts/deploy-tokenomics.sh staging

# Production deployment
./scripts/deploy-tokenomics.sh production
```

**Deployment Validation**
```bash
# Validate deployment readiness
./scripts/test-deployment.ps1

# Check contract compilation
npx clarinet check
```

### Monitoring and Analytics

**System Health Monitoring**
```javascript
// Monitor system health
const healthCheck = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'protocol-invariant-monitor',
  functionName: 'get-system-status',
  functionArgs: []
});
```

**Performance Metrics**
```javascript
// Get performance metrics
const metrics = await callReadOnlyFunction({
  contractAddress: 'ST...',
  contractName: 'token-coordinator',
  functionName: 'get-performance-metrics',
  functionArgs: []
});
```

## Best Practices

### Security Considerations

1. **Post-Conditions**: Always use post-conditions for critical operations
2. **Input Validation**: Validate all inputs before processing
3. **Access Control**: Implement proper role-based access control
4. **Circuit Breakers**: Monitor for system anomalies and implement emergency stops
5. **Audit Trails**: Log all significant operations for transparency

### Performance Optimization

1. **Batch Operations**: Group related operations when possible
2. **Gas Optimization**: Use efficient data structures and algorithms
3. **State Management**: Minimize on-chain state storage
4. **Read-Only Caching**: Cache frequently accessed read-only data
5. **Event Emission**: Use events for off-chain monitoring

### Integration Guidelines

1. **Error Handling**: Implement comprehensive error handling
2. **Version Compatibility**: Maintain backward compatibility
3. **Testing**: Comprehensive unit and integration testing
4. **Documentation**: Keep API documentation up to date
5. **Monitoring**: Implement real-time system monitoring

## Support and Resources

### Documentation Links

- [User Guide](USER_GUIDE.md) - Complete user guide for the tokenomics system
- [Architecture Documentation](ARCHITECTURE.md) - System architecture and design
- [Security Documentation](SECURITY.md) - Security practices and audit information
- [Nakamoto Integration](NAKAMOTO_SBTC_INTEGRATION.md) - Bitcoin integration opportunities

### Community Resources

- **GitHub**: [Conxian Repository](https://github.com/anyachainlabs/Conxian)
- **Discord**: [Conxian Community](https://discord.gg/conxian)
- **Documentation**: [Conxian Docs](https://docs.conxian.io)
- **Blog**: [Conxian Updates](https://blog.conxian.io)

### Development Support

- **Clarinet**: [Stacks Development Framework](https://github.com/hirosystems/clarinet)
- **Stacks.js**: [JavaScript SDK](https://github.com/blockstack/stacks.js)
- **Hiro API**: [Stacks API Documentation](https://docs.hiro.so/api)
- **Testnet**: [Stacks Testnet](https://testnet.hiro.so)

---

*This API reference is continuously updated. For the latest version, please refer to the official documentation.*
