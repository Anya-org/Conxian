# Conxian Industrial Engine & SIDL (ATS v12.0) - Agent Guidelines

## 0. THE CONXIAN UNIFIED THEORY (v2.0)
All agentic sessions must adhere to the equations defined in `docs/CONXIAN_UNIFIED_THEORY_v2.md`.
- **Execution Velocity ($V_X$)**: Prioritize AI leverage to crush milestones before $O_C$ exhaustion.
- **System Autonomy ($A_S$)**: Minimize manual oversight. Manual intervention is a Phase 3 failure; drive $O_C 	o 0$.


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
**SOVEREIGN. INDUSTRIAL. BTC-NATIVE.**

## 6. KNOWLEDGE RETENTION & HYGIENE (March 2026 Mandate)
- **Zero Secret Egress (ZSE)**: No sensitive operational, strategy, or financial material may be tracked in the active Git index.
- **Migration Mandate**: Before any path containing sensitive material (e.g., `internal/strategy/`, `archive/`) is added to `.gitignore`, all contained knowledge must be migrated to the **Linear Virtual Office** (e.g., parent issue CON-306).
- **Verification**: Run `python3 scripts/verify_knowledge_retention.py` to ensure all ignored sensitive paths are accounted for in the `audit/migration_manifest.json`.
- **Hygiene**: The root directory must remain clean of build artifacts (`*.log`, `*.txt`, `*.patch`).
