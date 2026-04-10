# Cross-Unit Change Control

This document defines the rules for when a change in an individual business unit repository requires an update to the BOS (Business Operations System) or OpenSpec in the `conxian-business` repository.

## Rule 1: Boundary Interface Changes
If a change modifies a versioned API, shared schema (e.g., CJCS), or contract trait that is consumed by another business unit, it **MUST** be accompanied by an update to the relevant OpenSpec in `conxian-business`.

## Rule 2: Protocol Invariants
Any change that alters the fundamental security model, fee split logic, or settlement guarantees of the Conxian protocol **MUST** be documented in `conxian-business` before implementation begins.

## Rule 3: Public Trust Surface
Changes to `README.md` role lines, `LICENSE` terms, or `SECURITY.md` policies that deviate from the organizational baseline **MUST** be approved by the Governance Lead and recorded in the Portfolio Inventory.

## Rule 4: Release Signaling
When a repository transitions status (e.g., from `Beta` to `Stable`), the `docs/PORTFOLIO_DASHBOARD.md` and `docs/PORTFOLIO_REPOSITORY_INVENTORY.md` in this repository **MUST** be updated to reflect the new maturity state.

---
© 2026 Conxian-Labs (Pty) Ltd | Omphile Ndaloenhle Legacy Trust
