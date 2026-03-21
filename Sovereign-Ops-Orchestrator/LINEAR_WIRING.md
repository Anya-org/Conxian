# Ops Engine: Linear & Stitch Integration Wiring

## 1. Objective

Establish the programmatic link between the execution engine (Linear) and the state layer (Supabase).

## 2. Webhook Triggers

- **Issue Creation**: Tagged with `cxn-` suite labels (e.g., `Nakamoto-Guardian`) triggers a new state entry in `ats_violations` if ATS metadata is missing.
- **Issue Completion**: Triggers a performance update in `deployment_efficiency`.
- **Valuation Impact**: Issues with the `ValuationImpact` label update the `exit_velocity` integrity score upon completion.

## 3. Stitch Dashboard

The internal dashboard is hosted on Render and visualizes the Supabase state.

- **Project ID**: 17743348077285403443
- **Dashboard URL**: [CONXIAN-BOS-INTERNAL]
