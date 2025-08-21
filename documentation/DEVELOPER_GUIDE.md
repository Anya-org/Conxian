# AutoVault Developer Guide

This guide provides everything you need to develop, test, and deploy
AutoVault smart contracts.

## Quick Start

### Prerequisites

- Clarinet SDK (pinned via npm to v3.5.0 in `stacks/package.json`)
- Node.js (v18+)
- Git for version control

### Setup

```bash
# Clone repository
git clone https://github.com/Anya-org/AutoVault.git
cd AutoVault/stacks

# Install dependencies
npm install

# Verify setup
npx clarinet check   # ✅ 30 contracts
npm test             # ✅ 65/65 tests
```

## Project Structure

```text
AutoVault/
├── stacks/                     # Smart contract development
│   ├── contracts/              # Smart contract source files
│   ├── sdk-tests/              # TypeScript test files
│   ├── governance/             # DAO governance proposals
│   ├── Clarinet.toml           # Project configuration
│   ├── package.json            # Node.js dependencies
│   └── vitest.config.ts        # Test configuration
├── documentation/              # Project documentation
├── scripts/                    # Deployment and utility scripts
├── chainhooks/                 # Blockchain event monitoring
└── bin/                        # Binary tools
```

## Development Workflow

### 1. Smart Contract Development

#### Creating a New Contract

```bash
cd stacks/contracts
# Create new contract file
touch my-contract.clar

# Add to Clarinet.toml
vim ../Clarinet.toml
```

#### Contract Template

```clarity
;; my-contract.clar
;; Description: Brief description of contract functionality

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))

;; Data variables
(define-data-var counter uint u0)

;; Public functions
(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) u1))
    (ok (var-get counter))
  )
)

;; Read-only functions  
(define-read-only (get-counter)
  (var-get counter)
)
```

#### Best Practices

- **Use descriptive names** for functions and variables
- **Include comprehensive error handling** with descriptive error codes
- **Add detailed comments** explaining complex logic
- **Follow naming conventions**: kebab-case for functions, UPPER_CASE for constants
- **Implement proper access controls** for admin functions

### 2. Testing

#### Test Structure

```typescript
// sdk-tests/my-contract.spec.ts
import { describe, expect, it, beforeEach } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';

describe('My Contract Tests', () => {
  let simnet: Simnet;
  let accounts: Map<string, string>;

  beforeEach(async () => {
    simnet = await Simnet.fromFile('Clarinet.toml');
    accounts = simnet.getAccounts();
  });

  it('should increment counter', () => {
    const result = simnet.callPublicFn(
      'my-contract',
      'increment',
      [],
      accounts.get('deployer')!
    );
    
    expect(result.result).toBeOk();
    expect(result.result.value).toBe(1);
  });
});
```

#### Running Tests

```bash
# Run all tests
npm test

# Run specific test file
npm test -- my-contract.spec.ts

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

#### Test Categories

- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Cross-contract interaction testing
- **Production Tests**: End-to-end system validation
- **Security Tests**: Vulnerability and attack vector testing

### 3. Contract Compilation

```bash
# Check all contracts
npx clarinet check

# Check specific contract
npx clarinet check --contract my-contract

# Format contracts
npx clarinet format

# Generate documentation
npx clarinet docs
```

## Testing Framework

### Test Environment Setup

```typescript
// Test setup with Simnet
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Initialize test environment
const simnet = await Simnet.fromFile('Clarinet.toml');
const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const user1 = accounts.get('wallet_1')!;
```

### Common Test Patterns

#### Testing Public Functions

```typescript
const result = simnet.callPublicFn(
  'contract-name',
  'function-name',
  [Cl.uint(100), Cl.stringAscii('test')],
  deployer
);

expect(result.result).toBeOk();
```

#### Testing Read-Only Functions

```typescript
const result = simnet.callReadOnlyFn(
  'contract-name',
  'read-function',
  [Cl.principal(user1)],
  deployer
);

expect(result.result.type).toBe('uint');
```

#### Testing Error Conditions

```typescript
const result = simnet.callPublicFn(
  'contract-name',
  'restricted-function',
  [],
  user1 // Non-admin user
);

expect(result.result).toBeErr();
expect(result.result.value).toBe(Cl.uint(1)); // ERR_UNAUTHORIZED
```

### Mock Data and Fixtures

```typescript
// Test fixtures
const testUsers = [
  { address: deployer, name: 'deployer' },
  { address: user1, name: 'user1' }
];

const testAmounts = [
  1000n,    // Small amount
  100000n,  // Medium amount  
  10000000n // Large amount
];
```

## 🚀 Deployment

### Local Development

```bash
# Start local blockchain
npx clarinet devnet start

# Deploy contracts locally
npx clarinet devnet deploy

# Interact with contracts
npx clarinet console
```

### Testnet Deployment

```bash
# Configure testnet settings in Clarinet.toml
[network.testnet]
node_rpc_api = "https://stacks-node-api.testnet.stacks.co"

# Deploy to testnet
npx clarinet deploy --testnet

# Verify deployment
npx clarinet deployment describe --testnet
```

### Mainnet Deployment

```bash
# Configure mainnet settings
[network.mainnet]
node_rpc_api = "https://stacks-node-api.mainnet.stacks.co"

# Deploy to mainnet (requires careful preparation)
npx clarinet deploy --mainnet

# Monitor deployment
npx clarinet deployment status --mainnet
```

## Debugging

### Common Issues

#### Contract Compilation Errors

```bash
# Check syntax errors
npx clarinet check --contract problematic-contract --sdk-version 3.5.0

# View detailed error messages
npx clarinet check --verbose --sdk-version 3.5.0
npx clarinet check --verbose
```

#### Test Failures

```bash
# Run tests with detailed output
npm test -- --reporter=verbose

# Debug specific test
npm test -- --grep "failing test name"

# Check simnet state
console.log(simnet.getBlockHeight());
console.log(simnet.getAssetsMap());
```

#### Deployment Issues

```bash
# Check network connectivity
npx clarinet network status

# Verify account balances
npx clarinet accounts

# Check transaction status
npx clarinet tx status <tx-id>
```

### Debugging Tools

- **Clarinet Console**: Interactive contract testing
- **Simnet Inspector**: Test blockchain state examination
- **Transaction Tracer**: Step-by-step execution analysis
- **Error Logging**: Comprehensive error reporting

## 📚 Code Standards

### Clarity Style Guide

```clarity
;; Constants (UPPER_CASE)
(define-constant MAX_SUPPLY u1000000)

;; Data variables (kebab-case)
(define-data-var total-supply uint u0)

;; Functions (kebab-case)
(define-public (mint-tokens (amount uint))
  ;; Function implementation
)

;; Error codes (descriptive)
(define-constant ERR_INSUFFICIENT_BALANCE (err u100))
(define-constant ERR_UNAUTHORIZED_MINT (err u101))

### Chain ID Parameter Naming Convention (NEW)

To prevent the prior `NameAlreadyUsed("chain-id")` compiler error, public & read-only functions must NOT declare parameters exactly named `(chain-id uint)`. Use a prefixed variant such as `p-chain-id`.

Enforcement:

- Static script: `npm run clarity:shadow-check` (see `scripts/static-check.sh`). Fails CI if any `(chain-id uint)` parameter remains.
- Existing refactors renamed parameters to `p-chain-id` across cross-chain & analytics modules.

Example (bad → good):

```clarity
;; BAD
(define-public (sync-chain (chain-id uint)) ...)

;; GOOD
(define-public (sync-chain (p-chain-id uint))
  (let ((info (map-get? chain-registry { chain-id: p-chain-id })))
    ...))
```

Run before committing:

```bash
npm run clarity:shadow-check
```

If it fails, rename only the parameter (keep storage variable identifiers stable unless a formal migration is approved).

Strict Mode (optional / CI only):

Set `AUTOVAULT_STRICT_PARAM_GUARD=1` to additionally scan for any public/read-only parameter that exactly matches a data var (with a small temporary allowlist). Use this in hardened branches prior to release freezes.

```

### Financial Ledger & Revenue Accounting (Feature Flag)

The `enhanced-analytics` contract (CONTRACT_VERSION u2) now includes a feature‑flagged on-chain financial ledger for standardized revenue and expense periodization.

Key elements:

- Feature Flag: `financial-ledger-enabled` (default `false`). Enable via:
  ```clarity
  (contract-call? .enhanced-analytics set-financial-ledger-enabled true)
  ```
- Period Map: `financial-period-ledger` keyed by `{ period-type, period-id }` storing immutable snapshots once finalized.
- Accumulators (reset each finalization): gross / performance fees / rebates / operating expenses / extraordinary items / buybacks / distributions.
- Fee Source Enumeration (standard event indexing):
  - `FEE_SRC_DEPOSIT = u0`
  - `FEE_SRC_WITHDRAW = u1`
  - `FEE_SRC_PERFORMANCE = u2`
  - `FEE_SRC_FLASH_LOAN = u3`
  - `FEE_SRC_LIQUIDATION = u4`
  - `FEE_SRC_TRADING = u5`
  - `FEE_SRC_STRATEGY = u6`
  - `FEE_SRC_MISC = u7`
- Unified Fee Recording:
  ```clarity
  (define-public (record-fee (source uint) (amount uint)) ...)
  ```
  Emits: `{ event: "fee-accrued", source, amount, performance }` where `performance` is auto true when `source = FEE_SRC_PERFORMANCE`.
- Backward Compatibility: `(record-revenue amount is-performance)` wrapper remains; new integrations must migrate to `record-fee`.
- Adjusted EBITDA Formula (current implementation):
  ```text
  net = max(gross - rebates, 0)
  ebitda = max(net - operating-expenses, 0)
  adjusted-ebitda = max( max(ebitda + extraordinary-items - buybacks, 0) - distributions, 0)
  ```
  (All math is clamped at zero to avoid unsigned underflow.)
- Period Finalization:
  ```clarity
  (finalize-financial-period period-type period-id data-complete notes-hash)
  ```
  Stores snapshot & resets accumulators. Rejects duplicate keys (`err u802`).

Error Codes (u800+):
- `u800` ledger disabled
- `u801` unauthorized (non-admin/non-oracle/non-governance-metrics)
- `u802` period already finalized
- `u804` invalid period type (must be <= yearly)

Events (ledger):
- `fee-accrued`
- `fin-rebate-recorded`
- `fin-op-ex-recorded`
- `fin-extraordinary-recorded`
- `fin-buyback-recorded`
- `fin-distribution-recorded`
- `fin-period-finalized`
- `fin-ledger-toggled`

Testing Guidelines:
1. Enable flag, record multiple fee types, finalize, assert snapshot tuple fields.
2. Verify performance fee counts increase both gross and performance buckets.
3. Attempt duplicate finalization (expect `err u802`).
4. Attempt recording while disabled (expect `err u800`).
5. Ensure accumulators reset post-finalization (second period starts at zero).

Future Enhancements (tracked):
- Automatic period-id derivation helpers (epoch, monthly, quarterly) – pending.
- Cross-contract hooks from `vault` and DEX pools to call `record-fee` automatically – pending integration PR.
- Strategy adapter standardized yield fee forwarding.

Security & Governance Considerations:
- Only authorized actors can mutate ledger state; snapshots are immutable once finalized.
- Avoid calling ledger write functions inside high-frequency loops; aggregate off-chain where possible to minimize gas.
- Indexers should rely on `fee-accrued` + `fin-period-finalized` events for real-time dashboards.

### TypeScript Style Guide

```typescript
// Use descriptive variable names
const deployerAddress = accounts.get('deployer')!;

// Use type annotations
const amount: bigint = 1000n;

// Use async/await for async operations
const result = await simnet.callPublicFn(...);

// Use consistent naming
describe('Vault Contract Tests', () => {
  it('should handle deposits correctly', () => {
    // Test implementation
  });
});
```

### Documentation Standards

- **Function Documentation**: Clear description, parameters, return values
- **Error Documentation**: All error codes documented with explanations
- **Example Usage**: Practical examples for each public function
- **Architecture Documentation**: High-level system design explanations

## 🤝 Contributing

### Development Process

1. **Fork Repository**: Create your own fork
2. **Create Branch**: `git checkout -b feature/new-feature`
3. **Develop & Test**: Write code and comprehensive tests
4. **Documentation**: Update relevant documentation
5. **Pull Request**: Submit for review

### Code Review Checklist

- [ ] All tests pass
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Security considerations addressed
- [ ] Performance implications considered

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push to fork
git push origin feature/my-feature

# Create pull request on GitHub
```

## 📞 Support

### Getting Help

- **Documentation**: Check `/documentation/` directory
- **GitHub Issues**: [Report bugs or request features](https://github.com/Anya-org/AutoVault/issues)
- **Code Examples**: See `sdk-tests/` for comprehensive examples
- **Community**: Join development discussions

### Common Resources

- **Clarity Language Guide**: [Official Clarity Documentation](https://docs.stacks.co/clarity)
- **Clarinet CLI Guide**: [Clarinet Documentation](https://github.com/hirosystems/clarinet)
- **Stacks.js SDK**: [Stacks.js Documentation](https://stacks.js.org/)

---

## Summary

This developer guide provides:

- **Complete development setup** instructions
- **Comprehensive testing** framework and examples
- **Deployment procedures** for all environments
- **Code standards** and best practices
- **Debugging tools** and troubleshooting guides

Follow this guide to contribute effectively to the AutoVault project.

*Last Updated: August 17, 2025*  
*Framework Version: Clarinet v2.0+, clarinet-sdk v3.5.0*
