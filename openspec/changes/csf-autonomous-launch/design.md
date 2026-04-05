# Design: Conxian CSF Autonomous Infrastructure

## 1. Governance: The ExecutorDAO Roadmap
- **Phase 0 (Now)**: Founding team oversight (March 2026).
- **Phase 1 (12m)**: Multi-sig transition with community delegates.
- **Phase 2 (24m)**: Full ExecutorDAO control with "Admin" address set to 0x0.

## 2. Revenue Architecture: The Founder's Cut
- **Logic**: Every trade/mint/burn event triggers a 0.1% fee.
- **Routing**: Fees are routed to a TEE-managed non-custodial address.
- **Abstraction**: Users pay fees in sBTC; backend handles conversion to STX if needed.

## 3. Financial Connectivity: ALEX & Portal Integration
- **Liquidity**: ALEX AMM SDK used for dynamic pool management.
- **Trading**: Portal Swap SDK provides atomic native BTC to sBTC swaps.
- **Assets**: sBTC (Nakamoto Native, uncapped), USDCx (Circle-native).

## 4. Growth Mechanics: Autonomous Engines
- **Referral**: "5-5-5" structure (Referrer, Referee, Protocol Health).
- **Transparency**: Chainhook-triggered bots for X/Telegram alerts on volume/TVL milestones.
- **Onboarding**: "3-Second Rule" wallet-integrated referral links.

## 5. Security Strategy
- **Audit**: Magnus platform for continuous adversarial testing.
- **Bounties**: Immunefi integration for bug disclosure.
