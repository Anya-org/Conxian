# Conxian Protocol Naming Standards

## **Institutional-Grade Naming Conventions**

This document establishes the official naming standards for the Conxian Protocol ecosystem to ensure consistency, clarity, and institutional-grade professionalism across all code, documentation, and communications.

---

## **🏛️ CORE PRINCIPLES**

### **1. Brand Identity**

- **Primary Name**: "Conxian Protocol"
- **Short Name**: "Conxian"
- **Tagline**: "Sovereign Autonomous Business Model"
- **Architecture**: "SAB" (Smart Asset Bank) Multi-Dimensional DeFi

### **2. Naming Philosophy**

- **Clarity**: Names must be self-descriptive
- **Consistency**: Uniform patterns across all components
- **Professionalism**: Institutional-grade terminology
- **Scalability**: Names must accommodate future expansion

---

## **📋 CONTRACT NAMING STANDARDS**

### **Core Protocol Contracts**

```
conxian-protocol.clar          # Main protocol coordinator
conxian-access.clar            # Access control system
conxian-operations-engine.clar # Autonomous operations
conxian-paas-factory.clar      # Business-as-a-Service factory
```

### **Token Contracts**

```
cxd-token.clar                 # Core protocol token
cxvg-token.clar                # Governance token
cxs-token.clar                 # Staking token
cxlp-token.clar                # Liquidity provider token
cxtr-token.clar                # Treasury token
```

### **Compliance & Identity**

```
regulatory-adapter.clar        # Clean-Hands compliance
kyc-registry.clar             # KYC verification registry
identity-badge.clar            # SIP-009 soulbound credentials
travel-rule-service.clar       # FATF Travel Rule implementation
```

### **Governance System**

```
enhanced-governance-nft.clar   # SIP-009 governance seat tokens
proposal-engine.clar           # Proposal management
proposal-executor.clar         # Proposal execution
proposal-registry.clar         # Proposal tracking
reputation-engine.clar         # Activity-based voting power
community-dao.clar             # Community DAO template
community-governance-token.clar # Community governance token
```

### **Financial System**

```
token-system-coordinator.clar  # Central token operations
cxd-bonding-curve-amm.clar     # Algorithmic liquidity
cxd-staking.clar               # Staking system
token-emission-controller.clar # Emission management
self-launch-coordinator.clar   # Community launch funding
```

### **Risk & Treasury**

```
agent-risk.clar                 # Autonomous risk management
agent-treasury.clar            # Automated treasury
governance-handover.clar       # Governance transition
```

### **Dimensional Trading (SAB Core)**

```
dimensional-engine.clar        # Core dimensional trading
dim-registry.clar              # Asset registry
dim-graph.clar                 # Asset relationships
dim-metrics.clar               # Metrics collection
dim-oracle-automation.clar     # Oracle automation
dim-revenue-adapter.clar       # Revenue distribution
dim-yield-stake.clar           # Dimensional staking
tokenized-bond.clar            # Tokenized bonds
tokenized-bond-adapter.clar    # External bond integration
```

### **DEX System**

```
dex-facade.clar                # DEX public interface
dex-backend.clar               # DEX business logic
liquidity-manager.clar         # Liquidity operations
route-manager.clar             # Routing logic
concentrated-liquidity-pool.clar # CL pool implementation
stable-swap-pool.clar          # Stablecoin pools
```

### **Lending System**

```
comprehensive-lending-system.clar # Complete lending platform
liquidation-manager.clar        # Liquidation operations
interest-rate-model.clar        # Interest calculations
lending-protocol-governance.clar # Lending governance
```

### **Oracle System**

```
oracle.clar                     # Core oracle implementation
oracle-aggregator-v2.clar      # Multi-source aggregation
oracle-trait.clar              # Oracle interface standard
```

### **Vault System**

```
sbtc-vault.clar                 # sBTC integration
conxian-vaults.clar            # Multi-asset vaults
fee-manager.clar               # Fee collection
```

### **Enterprise System**

```
enterprise-facade.clar         # Institutional interface
institutional-account-manager.clar # Account management
advanced-order-manager.clar    # Sophisticated order types
```

### **Automation & Agents**

```
automation-manager.clar        # Task automation
batch-processor.clar           # Batch operations
stacks-native-launch-script.clar # Native automation
```

---

## **🔧 TRAIT NAMING STANDARDS**

### **Core Traits**

```
core-traits.clar               # Fundamental protocol traits
rbac-trait.clar               # Role-based access control
ownership-trait.clar          # Ownership patterns
access-control-trait.clar     # Access management
```

### **DeFi Traits**

```
defi-traits.clar               # DeFi standard interfaces
dimensional-traits.clar        # Dimensional trading traits
governance-traits.clar         # Governance interfaces
enterprise-traits.clar         # Enterprise features
```

### **Standard Traits**

```
sip-009-nft-trait.clar         # SIP-009 NFT standard
sip-010-ft-trait.clar          # SIP-010 Fungible Token standard
sip-018-signed-messages-trait.clar # SIP-018 message signing
```

---

## **📁 DIRECTORY STRUCTURE STANDARDS**

### **Primary Directories**

```
contracts/
├── access/                     # Access control systems
├── agents/                     # Autonomous agents
├── automation/                 # Automation systems
├── compliance/                 # Regulatory compliance
├── core/                       # Core protocol logic
├── dex/                        # Decentralized exchange
├── dimensional/                # SAB dimensional trading
├── enterprise/                 # Institutional features
├── governance/                 # Governance systems
├── identity/                   # Identity management
├── integrations/               # External integrations
├── lending/                    # Lending protocols
├── math-utilities/             # Mathematical utilities
├── oracle/                     # Price oracles
├── security/                   # Security systems
├── tokens/                     # Token contracts
├── traits/                     # Trait definitions
├── utils/                      # Utility contracts
└── vaults/                     # Asset vaults
```

---

## **🏷️ FUNCTION & VARIABLE NAMING**

### **Function Naming**

- **Public Functions**: `kebab-case` (e.g., `create-proposal`, `set-contract-owner`)
- **Read-Only Functions**: `kebab-case` (e.g., `get-balance`, `check-compliance`)
- **Private Functions**: `kebab-case` with descriptive names (e.g., `calculate-risk-score`)

### **Variable Naming**

- **Constants**: `UPPER_SNAKE_CASE` (e.g., `ERR_UNAUTHORIZED`, `BLOCKS_PER_DAY`)
- **Data Variables**: `kebab-case` (e.g., `contract-owner`, `total-supply`)
- **Map Names**: `kebab-case` (e.g., `user-balances`, `proposal-registry`)
- **Local Variables**: `kebab-case` (e.g., `proposal-id`, `current-block`)

### **Error Codes**

- **Format**: `ERR_[CATEGORY]_[SPECIFIC]`
- **Examples**: `ERR_UNAUTHORIZED`, `ERR_INSUFFICIENT_BALANCE`, `ERR_PROPOSAL_NOT_FOUND`

---

## **📖 DOCUMENTATION STANDARDS**

### **File Headers**

```clarity
;; contract-name.clar
;; Conxian [Category]: [Brief Description]
;; [Detailed purpose explanation]

;; Dependencies
(use-trait trait-name .trait-path.trait-name)

;; Constants
(define-constant ERR_NAME (err uXXXX))

;; Data Variables
(define-data-var var-name type initial-value)

;; Storage Maps
(define-map map-name key-type value-type)
```

### **Comments**

- **Section Headers**: `;; @SECTION [SECTION_NAME]`
- **Function Descriptions**: `;; @desc [Description]`
- **Complex Logic**: Inline comments explaining purpose
- **TODO Items**: `;; TODO: [Action item]`

---

## **🔄 VERSIONING STANDARDS**

### **Contract Versioning**

- **Major Changes**: New contract name with version suffix
- **Minor Changes**: Same contract, updated comments
- **Backwards Compatibility**: Maintain old contracts during transition

### **API Versioning**

- **Trait Versions**: Include version in trait name if breaking changes
- **Function Versions**: Use function overloading for backwards compatibility

---

## **🏢 INSTITUTIONAL TERMINOLOGY**

### **Preferred Terms**

- **"Sovereign Autonomous Business"** → Not "DeFi Protocol"
- **"Clean-Hands Compliance"** → Not "KYC System"
- **"Dimensional Trading"** → Not "Multi-Asset Trading"
- **"Operations Engine"** → Not "Admin System"
- **"Business-as-a-Service"** → Not "Protocol Factory"

### **Professional Language**

- Use institutional-grade terminology
- Avoid crypto slang and informal language
- Maintain professional tone in all documentation
- Use precise technical language

---

## **✅ COMPLIANCE CHECKLIST**

### **Before Commit**

- [ ] Contract name follows naming standards
- [ ] File header is complete and accurate
- [ ] Function names use kebab-case
- [ ] Constants use UPPER_SNAKE_CASE
- [ ] Error codes follow ERR_CATEGORY_SPECIFIC format
- [ ] Comments are professional and clear
- [ ] Directory placement is correct

### **Code Review**

- [ ] Naming consistency across related contracts
- [ ] Professional terminology used throughout
- [ ] Documentation is complete and accurate
- [ ] No deprecated naming patterns

---

## **📚 REFERENCE MATERIALS**

### **Related Documents**

- [Architecture Overview](./architecture/OVERVIEW.md)
- [SAB Design Principles](./architecture/SAB_DESIGN.md)
- [Compliance Framework](./compliance/COMPLIANCE_FRAMEWORK.md)
- [Governance Model](./governance/GOVERNANCE_MODEL.md)

### **External Standards**

- [SIP-009 NFT Standard](https://github.com/stacksgov/sips/blob/main/sips/sip-009/sip-009-nft-standard.md)
- [SIP-010 Fungible Token Standard](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md)
- [SIP-018 Signed Messages](https://github.com/stacksgov/sips/blob/main/sips/sip-018/sip-018-signed-messages.md)

---

## **🔄 MAINTENANCE**

### **Regular Reviews**

- Quarterly review of naming consistency
- Annual update of terminology standards
- Continuous improvement of documentation

### **Update Process**

1. Propose changes in governance
1. Community review period
1. Implementation across codebase
1. Documentation updates
1. Communication of changes

---

**This document serves as the authoritative source for all Conxian Protocol naming standards. All contributors must adhere to these guidelines to maintain consistency and professional quality across the ecosystem.**

*Last Updated: January 2026*
*Version: 1.0*
