# Conxian Labs - Agent Context (Jules)

## Service Domains: Dual-Viewpoint Mapping

### Viewpoint A: Internal Ops (The Engine Room)

| Domain | Contracts | Description |
| :--- | :--- | :--- |
| **DAO Services** | `proposal-registry`, `proposal-executor`, `proposal-engine`, `community-voting-engine`, `voting`, `dao-treasury`, `upgrade-controller`, `timelock` | Core governance logic, voting mechanisms, and timelock execution. |
| **Platform Services** | `conxian-protocol`, `ops-engine`, `economic-policy-engine`, `allocation-policy`, `office-manager`, `circuit-breaker`, `token-system-coordinator` | Protocol coordination, economic policies, and emergency fail-safes. |
| **Admin Ops** | `conxian-access`, `admin-facade`, `operational-treasury`, `reputation-engine`, `legal-representative-registry` | RBAC, administrative facades, and reputation tracking. |
| **Cross-Chain Ops** | `wormhole-outbox`, `oracle-aggregator`, `*-oracle-adapter`, `twap-oracle` | Bridge hooks and hybrid oracle aggregation. |

### Viewpoint B: External Ops (The User Experience)

| Domain | Contracts | Description |
| :--- | :--- | :--- |
| **Retail** | `cxd-token`, `cxvg-token`, `cxs-token`, `cxtr-token`, `cxlp-token`, `enhanced-governance-nft`, `position-nft`, `ico-offering` | User-facing tokens, NFTs, and onboarding tools. |
| **DeFi** | `swap-manager`, `vault`, `dimensional-engine`, `dimensional-core`, `liquidity-provider`, `revenue-distributor`, `lending-manager`, `position-manager`, `collateral-manager`, `risk-manager`, `cxd-staking`, `swap-router`, `yield-optimizer` | Core DeFi primitives: Swaps, Lending, Yield, and Dimensional Trading. |
| **Business** | `founder-vesting`, `regulatory-adapter`, `agent-treasury`, `agent-risk`, `travel-rule-service`, `compliance-manager` | B2B settlements, regulatory compliance, and autonomous risk management. |

---

## Technical Directives (BOLT Initiative)

1.  **Clarity 4 Native**: Leverage `SIP-033` features (e.g., `contract-hash?`, `stacks-block-time`, `secp256r1-verify`).
2.  **Initialization**: DO NOT use dynamic values (`tx-sender`, `burn-block-height`) in top-level `define-data-var` or `define-constant`. Use literal placeholders and initialize via public functions or use `tx-sender` only during deployment if strictly necessary and allowed by the environment.
3.  **Zero Gas Ops**: Maximize `read-only` functions. Identify public functions that can be converted.
4.  **Safety**: All `contract-call?` must be wrapped in `unwrap!` or `try!`. No swallowed errors.
5.  **Data Packing**: Merge multiple state variables into single `uint` or `buff` where applicable to save gas on storage.
