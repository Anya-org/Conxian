# Specifications: CSF Autonomous Launch

(Note: Formal requirements are in `specs/launch-mechanics/spec.md`)

## 1. Governance & Autonomy
- **SPEC-GOV-001**: **ExecutorDAO Handover**. Admin rights MUST be transferred to the DAO within 24 months.
- **SPEC-GOV-002**: **Key Relinquishment**. Final admin principal MUST be the burn address (0x0).

## 2. Revenue & Fees
- **SPEC-REV-001**: **Founder's Cut**. A 0.1% hardcoded fee MUST be routed to the founder address.
- **SPEC-REV-002**: **5-5-5 Growth**. Referrers and referees MUST receive 5% of fees as specified.

## 3. Financial Integration
- **SPEC-FIN-001**: **ALEX Connectivity**. The Gateway MUST integrate with ALEX AMM for liquidity.
- **SPEC-FIN-002**: **Portal Swap**. Native BTC/sBTC swaps MUST be facilitated via Portal SDK.
- **SPEC-FIN-003**: **sBTC Nakamoto**. sBTC MUST be supported without supply caps.

## 4. Growth & Marketing
- **SPEC-GR-001**: **Activity Bots**. Chainhooks MUST trigger real-time updates on X/Telegram.
- **SPEC-GR-002**: **3-Second Referral**. Links MUST be wallet-integrated for instant sharing.
