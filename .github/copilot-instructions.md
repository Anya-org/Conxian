# Conxian DeFi Protocol

Conxian is a production-ready DeFi platform on Stacks with 75 Clarity smart contracts (traits, governance, vault system, DEX foundations), comprehensive TypeScript testing, and advanced development tooling.

**Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Bootstrap, Build & Test (CRITICAL - NEVER CANCEL)
**ALWAYS run these commands with appropriate timeouts and NEVER cancel long-running operations:**

- `npm run ci` -- **takes 60 seconds. NEVER CANCEL. Set timeout to 120+ seconds.**
  - Installs all dependencies 
  - Runs contract checker (`npx clarinet check`)
  - Runs full test suite (`npx vitest run`)
  - Expected: ✅ 67 contracts checked, ✅ 130/131 tests passed

- Individual commands:
  - `npm install` -- installs Node.js dependencies (8 seconds)
  - `npx clarinet check` -- validates all Clarity contracts (1 second) 
  - `npm test` -- runs TypeScript test suite (**takes 50 seconds. NEVER CANCEL. Set timeout to 90+ seconds.**)

### Development Commands
- **Contract checking**: `npx clarinet check` (1 second)
- **Interactive console**: `npx clarinet console` (loads all 67 contracts, shows function table)
- **Manual testing**: `./scripts/manual-testing.sh` (1 second - prepares testing commands)
- **Format checking**: `npx clarinet format --file contracts/[CONTRACT].clar --check`
- **Generate deployer keys**: `npm run gen-key -- --help` (generates Stacks addresses and private keys)

### Deployment & Verification
- **Local CI validation**: `./scripts/ci-local.sh` (**takes 45 seconds. Set timeout to 90+ seconds.**)
- **Testnet deployment**: `./scripts/deploy-testnet.sh` (with proper environment variables)
- **Manual testing setup**: `./scripts/manual-testing.sh` then `npx clarinet console`

## Validation Requirements

### ALWAYS Run Complete End-to-End Scenarios
**CRITICAL**: After making changes, always validate by running through complete workflows:

1. **Full CI Process**: `npm run ci` (validates everything works together)
2. **Interactive Console Testing**: 
   - Run `npx clarinet console` 
   - Execute commands from `stacks/manual_test_commands.clar`
   - Verify contract interactions work (example: `(contract-call? .avg-token get-total-supply)` returns `(ok u0)`)
3. **Contract Format Validation**: `npx clarinet format --file contracts/[CONTRACT].clar --check`

### Pre-Commit Validation
**ALWAYS run these before committing changes or CI will fail:**
- `npm run ci` -- full CI pipeline
- `npx clarinet check` -- contract compilation
- Manual testing via console for affected contracts

## Project Structure & Navigation

### Repository Layout
```
/home/runner/work/Conxian/Conxian/    # Use ABSOLUTE paths
├── contracts/                           # 75 Clarity smart contracts (.clar files)
│   ├── traits/                         # Core interfaces (10 trait contracts)
│   ├── vault.clar, treasury.clar       # Core DeFi contracts
│   ├── avg-token.clar, avlp-token.clar # Protocol tokens  
│   └── dao-governance.clar             # DAO governance
├── stacks/                             # Development environment
│   ├── sdk-tests/                      # 20 TypeScript test files (.spec.ts)
│   ├── manual_test_commands.clar       # Interactive testing commands
│   ├── clarinet-wrapper/               # Clarinet SDK wrapper
│   └── package.json                    # Dependencies (Clarinet SDK v3.5.0)
├── scripts/                            # 30+ utility scripts (.sh, .ts, .py)
│   ├── deploy-testnet.sh               # Testnet deployment
│   ├── manual-testing.sh               # Manual test framework
│   └── ci-local.sh                     # Local CI runner
├── documentation/                      # Complete documentation
│   ├── DEVELOPER_GUIDE.md              # Detailed dev workflow
│   ├── API_REFERENCE.md                # Contract functions
│   └── ARCHITECTURE.md                 # System design
├── package.json                        # Root project configuration
├── Clarinet.toml                       # Contract deployment config
└── vitest.config.ts                    # Test configuration
```

### Key Contract Categories
- **Traits** (10): Core interfaces - `sip-010-trait`, `vault-trait`, `strategy-trait`
- **Governance** (5): DAO system - `dao`, `dao-governance`, `timelock`, `gov-token`
- **Vault System** (8): Core DeFi - `vault`, `treasury`, `vault-enhanced`, `vault-production`
- **Tokens** (3): Protocol tokens - `avg-token`, `avlp-token`, `creator-token`
- **DEX Foundations** (15): AMM infrastructure - `dex-factory`, `dex-pool`, `multi-hop-router`
- **Analytics** (5): Monitoring - `analytics`, `enterprise-monitoring`, `bounty-system`

### Most Frequently Used Files
- `package.json` - NPM scripts and dependencies
- `Clarinet.toml` - Contract configuration (67 contracts listed)
- `stacks/manual_test_commands.clar` - Ready-to-use console commands
- `contracts/vault.clar` - Main vault contract
- `documentation/DEVELOPER_GUIDE.md` - Detailed workflows
- `scripts/manual-testing.sh` - Testing framework

## Common Development Tasks

### Testing Workflow
```bash
# Run full test suite (NEVER CANCEL - 50 seconds)
npm test

# Run specific test category
npm test -- --grep "vault"
npm test -- --grep "governance"

# Watch mode for development
npm run test:watch

# Manual interactive testing
./scripts/manual-testing.sh  # Prepares test commands
npx clarinet console          # Interactive REPL
# Then copy commands from stacks/manual_test_commands.clar
```

### Console Testing Examples
```clarity
;; Basic contract verification
(contract-call? .avg-token get-total-supply)      ;; Expected: (ok u0)
(contract-call? .vault get-admin)                 ;; Verify vault admin
(contract-call? .dao-governance get-governance-data) ;; Check governance

;; Test token interactions
(contract-call? .avg-token get-name)              ;; Token metadata
(contract-call? .avlp-token get-total-supply)     ;; AVLP supply
```

### Known Working Commands (Validated)
- ✅ `npm run ci` (60 seconds - 67 contracts, 130/131 tests)
- ✅ `npx clarinet check` (1 second - validates all contracts)
- ✅ `npx clarinet console` (interactive contract REPL)
- ✅ `./scripts/manual-testing.sh` (test framework setup)
- ✅ `npm run gen-key` (key generation utility)
- ✅ `npx clarinet format --file [CONTRACT] --check` (format validation)

### Known Issues & Workarounds
- **TypeScript compilation errors** in some deployment scripts (non-blocking for core development)
- **Import issues** with @stacks/transactions in scripts (use npm scripts instead of direct execution)
- **Format command syntax**: Use `--file [path]` instead of just the path
- **Console exit**: Use Ctrl+C instead of `exit` command

### Build Timing Expectations (**CRITICAL - NEVER CANCEL**)
- **Full CI**: 60 seconds (npm run ci)
- **Test suite only**: 50 seconds (npm test) 
- **Contract check**: 1 second (npx clarinet check)
- **Manual testing setup**: 1 second (./scripts/manual-testing.sh)
- **Dependencies install**: 8 seconds (npm install)

**Set timeouts to at least 2x expected time. If builds appear to hang, wait at least 120 seconds before considering alternatives.**

## Dependencies & Requirements

### System Requirements
- **Node.js**: v18+ (verified: v20.19.4)
- **NPM**: 10.8.2+ 
- **Clarinet SDK**: v3.5.0 (pinned via package.json)

### Exact Installation Commands
```bash
# Verified working setup commands
npm install                    # Install all dependencies (8 seconds)
npx clarinet --version         # Verify Clarinet v3.5.0
npm run check                  # Alias for npx clarinet check
```

### Environment Setup Validation
```bash
# Verify setup is working
node --version                 # Should be v18+
npm --version                  # Should be 10.8.2+
npx clarinet --version         # Should be v3.5.0
npm run ci                     # Full validation (NEVER CANCEL - 60 seconds)
```

## Important Notes

### Development Best Practices
- **Always use absolute paths**: `/home/runner/work/Conxian/Conxian/[file]`
- **Use npm scripts**: Prefer `npm run [script]` over direct command execution
- **Timeout appropriately**: Set 2x expected time for all builds and tests
- **Test interactively**: Use `npx clarinet console` for contract validation
- **Follow format**: Use `npx clarinet format --file [contract] --check` for linting

### Critical Reminders
- **NEVER CANCEL** builds or tests in progress - they may take 60+ seconds
- **ALWAYS** run `npm run ci` after changes to validate everything works
- **ALWAYS** use the interactive console to test contract modifications
- **ALWAYS** wait for commands to complete naturally rather than timing out prematurely

The codebase is production-ready with comprehensive testing. Follow these instructions for reliable development workflows.