# ConxianCSF Commercialization & Market Access Gates

## 1. Release Phases
Commercialization of ConxianCSF follows a three-phase activation sequence:

### Phase 1: Mainnet Genesis (Immediate)
- **CSF Core**: Universal Router and Concentrated Liquidity Pools enabled.
- **BME Engine**: Fee collection and buy-back/burn mechanism active.
- **ALEX Adapter**: Production ALEX routing is disabled pending the verified
  inputs and evidence listed in `docs/ALEX_LAUNCH_READINESS.md`. Local simnet
  fixtures remain available for integration coverage only.
- **Internal Bounty Funding**: ALEX-linked treasury flow remains disabled; no
  production ALEX funding path is active until the same readiness gate is
  satisfied.
- **Integration Fee MVP (contract scope)**: STX per-use and monthly billing is
  implemented through the registry/collector pair, with exact payer
  settlement routed through the existing revenue distributor. Activation is
  still gated on production-profile/ALEX drift repair and deployment review.

### Phase 2: Community Expansion (L+30 Days)
- **External CSF Registry**: Permitting community-governed addition of new protocols (e.g., Zest, StackingDAO).
- **Public Bounty Program**: Open enrollment for community contributors.
- **Retail UI**: Launch of the full Conxian Unified Interface.

### Phase 3: Institutional Scale (L+90 Days)
- **Gateway Activation**: ISO 20022 and ERP bridging enabled for institutional partners.
- **Enterprise Vaults**: Deployment of specialized sBTC yield strategies.
- **Global Compliance**: Activation of MiCA/VASP reporting logic.

### Enterprise Subscription Activation Gate
The enterprise subscription contracts may be published without being
commercially active. Before a product sale is enabled, governance must:

- publish and review a `{tier-id, version}` plan with nonzero monthly/annual
  prices and a valid KYC tier;
- explicitly activate the approved plan version and publish all immutable
  generic features before activation;
- register only audited product consumer contracts; the deployment plan leaves
  the consumer allowlist empty and does not auto-register the generic facade;
- configure audited recipients for each STX Fiscal Dam bucket before any
  release; unconfigured buckets are intentionally fail-closed;
- verify the generated route wiring and policy-version receipt evidence.

Buyback is only an STX allocation bucket until a separate native-STX adapter
has been reviewed and approved; no deployment step may imply native buyback
execution.

## 2. Market-Access Gates
Before moving between phases, the following gates must be satisfied:
- **Legal Review**: Counsel sign-off on token rights and royalty distribution model.
- **Audit Verification**: Final security report for all CSF-compliant adapters.
- **Liquidity Depth**: Minimum TVL (M equivalent) in core pools.
- **Agent Performance**: Verified PID stability in `agent-risk` for at least 14 days on mainnet.
- **Integration Billing Controls**: Each integration has an active owner/payer,
  reporter, fee configuration, and rotated key commitment; monthly settlement
  is gated by burn-block period closure. Reporter trust is an MVP boundary,
  with payer-signed attestations reserved for a later hardening phase.

## 3. Prohibited Actions (Ethos Compliance)
To preserve the Conxian Sovereign Ethos, the following are strictly avoided:
- **Manual Intervention**: Direct admin minting or treasury drainage.
- **Obfuscated Logic**: All fee split rules must remain on-chain and verifiable.
- **Closed Governance**: Major policy shifts must involve the Community Board.
