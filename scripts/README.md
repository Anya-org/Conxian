# AutoVault - Fully Decentralized DeFi Protocol

[![CI](https://github.com/Anya-org/AutoVault/workflows/CI/badge.svg)](https://github.com/Anya-org/AutoVault/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully decentralized DeFi protocol built on Stacks blockchain with comprehensive DAO governance, creator token economics, and automated yield strategies.

## 🚀 Features

### Core Protocol

- **Vault System**: Multi-asset yield farming with automated strategies
- **DAO Governance**: Community-driven protocol decisions and parameter updates
- **Creator Tokens**: Fair launch mechanism with bonding curves and revenue sharing
- **Treasury Management**: Multi-signature treasury with transparent fund allocation
- **Bounty System**: Incentivized development and community contributions
- **Analytics**: Real-time protocol metrics and performance tracking

### Decentralization

- **No Admin Keys**: All protocol functions governed by DAO
- **Community Ownership**: Creator tokens distributed to contributors
- **Transparent Operations**: All transactions and decisions on-chain
- **Permissionless**: Anyone can participate in governance and yield farming

## 📁 Project Structure

```text
├── stacks/
│   ├── contracts/           # Smart contracts
│   │   ├── vault.clar      # Core vault functionality
│   │   ├── dao-governance.clar  # DAO voting and proposals
│   │   ├── creator-token.clar   # Token economics
│   │   ├── treasury.clar   # Treasury management
│   │   ├── bounty-system.clar   # Development incentives
│   │   └── analytics.clar  # Protocol metrics
│   ├── tests/              # Comprehensive test suites
│   └── settings/           # Network configurations
├── docs/                   # Documentation
│   ├── prd-full-decentralization.md
│   ├── implementation-summary.md
│   └── on-chain-completeness-assessment.md
├── .github/                # CI/CD and templates
└── scripts/                # Deployment and utility scripts
```

## 🛠 Requirements

- **Clarinet CLI** (v3.5.0+)
  - macOS: `brew install hirosystems/tap/clarinet`
  - Linux: `curl -sSfL https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-installer.sh | sh`
- **Node.js** (v18+) for tests
- **Git** for version control

## 🚀 Quick Start

1. **Clone the repository**

   ```bash
   git clone https://github.com/Anya-org/AutoVault.git
   cd AutoVault
   ```

2. **Run contract checks**

   ```bash
   ./bin/clarinet check
   ```

3. **Run tests**

   ```bash
   ./bin/clarinet test
   ```

4. **Start local development**

   ```bash
   ./bin/clarinet console
   ```

## 📖 Usage Examples

### Vault Operations

```clj
;; Deposit assets
(contract-call? .vault deposit u1000)

;; Check balance
(contract-call? .vault get-balance tx-sender)

;; Withdraw with yield
(contract-call? .vault withdraw u500)
```

### DAO Governance

```clj
;; Create proposal
(contract-call? .dao-governance create-proposal 
  "Increase yield farming rewards" 
  "vault" 
  "set-reward-rate" 
  u150)

;; Vote on proposal
(contract-call? .dao-governance vote u1 true)
```

### Creator Tokens

```clj
;; Mint creator tokens
(contract-call? .creator-token mint-tokens u100)

;; Claim rewards
(contract-call? .creator-token claim-rewards)
```

## 🏗 Development

### Running Tests

```bash
# Run all tests
./bin/clarinet test

# Run specific test file
./bin/clarinet test tests/vault_test.ts
```

### Deployment

```bash
# Deploy to testnet
./scripts/deploy-testnet.sh

# Deploy to mainnet (requires multi-sig)
./scripts/deploy-mainnet.sh

### SDK Deployment (Sequential)
Automated broadcast of all contracts (testnet):
```bash
cd stacks
DEPLOYER_PRIVKEY=your_testnet_privkey NETWORK=testnet npm run deploy-contracts
```
This writes/updates `deployment-registry-testnet.json` with txids & block heights.
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

See our [Contributing Guidelines](.github/pull_request_template.md) for detailed information.

## 📊 Protocol Metrics

- **Total Value Locked**: Tracked on-chain via analytics contract
- **Active Users**: Real-time user engagement metrics
- **Governance Participation**: DAO voting statistics
- **Yield Performance**: Historical APY and strategy performance

## 🛡 Security

- **Audited Contracts**: All smart contracts undergo security review
- **Multi-sig Treasury**: Requires multiple signatures for fund movements
- **Time-locked Governance**: Proposals have mandatory delay periods
- **Emergency Pause**: Community-controlled emergency mechanisms

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Documentation**: [docs/](./docs/)
- **GitHub**: [Repository](https://github.com/Anya-org/AutoVault)
- **Issues**: [Bug Reports & Feature Requests](https://github.com/Anya-org/AutoVault/issues)

## 💡 Vision

AutoVault represents the future of DeFi - fully decentralized, community-owned, and built on Bitcoin's security through Stacks. We're creating sustainable yield strategies while maintaining complete transparency and community governance.

## 🤖 Autonomic Economics & Simulation

The vault includes on-chain autonomic controllers to keep fees and treasury reserves within healthy bands while remaining fully governable:

### On-Chain Controllers
 
 - Utilization-based withdraw fee adjustment (`update-fees-based-on-utilization`)
 - Reserve band driven deposit fee adjustment (`update-autonomics`)
 - Governance/timelock gated parameter setters: `set-reserve-bands`, `set-fee-ramps`, `set-auto-economics-enabled`, `set-util-thresholds`, `set-fee-bounds`, `set-auto-fees-enabled`

### Keeper Model
 
Anyone may call `update-autonomics` once enabled, making the system permissionless while proposals still define bounds. See `scripts/keeper_watchdog.py` for an automation scaffold.

For testnet on-chain triggering via the Stacks SDK, use:
```bash
cd stacks
STACKS_PRIVKEY=your_hex_privkey VAULT_CONTRACT=SPXXXX.vault npm run update-autonomics
```
Scheduled dry-run keeper action lives in `.github/workflows/keeper-cron.yml` (configure secrets `KEEPER_PRIVKEY` & `VAULT_CONTRACT`).

Python read-only snapshot + optional broadcast:
```bash
STACKS_API_BASE=https://api.testnet.hiro.so VAULT_CONTRACT=SPXXXX.vault \
   python scripts/python_update_autonomics.py --broadcast
```
Integration harness (placeholder) to exercise SDK script:
```bash
cd stacks
npm run int-autonomics
```

### Off-Chain Simulation
 
Use the economic simulator to stress-test fee dynamics:

```bash
python scripts/economic_simulation.py | jq '.final'
```

### ML Strategy Recommender (Placeholder)
 
Prototype recommender emits governance proposal suggestions:

```bash
python scripts/ml_strategy_recommender.py --state-json '{"utilization_bps":8400,"reserve_ratio_bps":450,"global_cap":1000000}'
```

Outputs JSON with recommended parameter changes (future: integrate real ML / RL agent).

### Analytics Integration
 
Autonomic adjustments emit events (`update-autonomics` plus analytics hook `record-autonomics`) enabling off-chain dashboards to track fee evolution, utilization, and reserve ratios. Tested in `analytics_autonomics_event_test.ts`.

### Proposal / Governance Tooling
 
Generated recommendations can be converted into structured governance action bundles with `scripts/governance_proposal_builder.py`.

### Safety & Bounds
 
All automatic adjustments obey governance-defined min/max bounds; disabling controllers is a single on-chain transaction (`set-auto-economics-enabled false`).
