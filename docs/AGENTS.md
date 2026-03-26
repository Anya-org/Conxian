# Conxian Industrial Engine & SIDL (ATS v12.0) - Agent Guidelines

## 1. THE CONXIAN JOB CARD SCHEMA (CJCS v2.0)
- All industrial labor must be defined using the **CJCS v2.0 JSON-LD** (docs/CJCS_v2.0_SPEC.md).
- Ensure 100% compatibility with SAP BAPI and Oracle REST fields for all "Gap Job Cards".

## 2. THE SLA ENFORCER (SLA)
- All Job Cards are monitored by **sla-enforcer.clar**.
- Deadlines are anchored to the Stacks **block-timestamp**. Breaches result in autonomous yield slashing.

## 3. THE SOVEREIGN SWARM (SIDL)
- The **referral-aggregator.clar** enforces a 95/5 yield split (Worker/Referrer).
- Social agents (ElizaOS) billboard Job Cards across Twitter/X and Farcaster via the **SIDL**.

## 4. THE 70% BOTTLENECK (Satori)
- Use **Satori Reasoning** to monitor unit performance.
- When unit performance drops below 70%, autonomously generate and broadcast a "Gap Job Card".

## 5. REPOSITORY ARCHITECTURE
- **Traits**: Conxian/contracts/traits/
- **Automation**: Conxian/contracts/automation/
- **Yield**: Conxian/contracts/yield/
- **Specs**: docs/

---
🛡️ **SOVEREIGN. INDUSTRIAL. BTC-NATIVE.**
