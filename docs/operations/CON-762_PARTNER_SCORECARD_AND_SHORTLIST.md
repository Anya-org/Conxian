# CON-762 Partner scorecard and shortlist artifacts

Issue: https://linear.app/conxian-labs/issue/CON-762/build-weighted-partner-scorecard-and-shortlist

## Purpose

This document is the human-readable index/spec for the CON-762 partner scorecard artifact set.
It captures the baseline partner-dimension inputs, scenario weights, scoring method, recommendation-tier policy, and the generated CSV outputs used for shortlist decisions.

## Artifact bundle

All machine-readable artifacts are under:

- `docs/operations/con-762-partner-scorecard/balanced/`
- `docs/operations/con-762-partner-scorecard/speed-first/`
- `docs/operations/con-762-partner-scorecard/sovereignty-first/`

Each scenario folder includes:

- `weights.csv`
- `partner_scores.csv`
- `first_wave_recommendation.csv`
- `build_vs_partner.csv`

## Baseline raw partner dimension scores

| partner | category | integration_speed | sovereignty_fit | erp_compatibility | compliance_leverage | operational_control_value | buyer_trust_impact | cost_switching_risk |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Fireblocks | Custody/KMS | 4.5 | 3.5 | 3.0 | 4.0 | 4.5 | 4.0 | 3.0 |
| BitGo | Custody/KMS | 3.5 | 4.0 | 2.5 | 3.5 | 4.0 | 4.0 | 3.0 |
| TRM | Compliance analytics | 3.5 | 3.0 | 2.5 | 4.5 | 4.0 | 4.5 | 2.5 |
| Chainalysis | Compliance analytics | 3.5 | 2.5 | 2.5 | 4.5 | 3.5 | 4.5 | 2.5 |
| Circle | Payments/settlement | 4.0 | 2.5 | 2.0 | 4.0 | 3.5 | 4.5 | 2.5 |
| QuickNode | Bitcoin infra | 4.0 | 3.0 | 2.0 | 3.0 | 3.5 | 4.0 | 3.0 |
| Hiro | Bitcoin infra | 2.5 | 4.0 | 2.0 | 2.5 | 3.5 | 3.0 | 2.5 |
| SAP | ERP | 3.0 | 3.0 | 4.5 | 3.5 | 3.5 | 4.5 | 2.5 |
| Oracle/NetSuite | ERP | 3.5 | 2.5 | 4.0 | 3.0 | 3.0 | 4.0 | 2.0 |

## Scoring method

For each scenario:

- `weighted_score = Σ(dimension_score × dimension_weight)`
- `weighted_score` is rounded to 2 decimal places in `partner_scores.csv`.
- `shortlist_rank` is computed within each `category` (`1` = highest weighted score in that category).

## Recommendation tiers

`recommendation_tier` is scenario-aware and uses four action lanes:

- `first_wave`: immediate partner-engagement lane for initial launch sequence.
- `second_wave`: strong option, sequenced after first-wave contracting/integration.
- `discovery_lane`: targeted due-diligence lane before commit.
- `monitor`: keep active watchlist posture; no near-term integration commitment.

## Scenario weight profiles

| dimension | balanced | speed-first | sovereignty-first |
| --- | ---: | ---: | ---: |
| integration_speed | 0.20 | 0.30 | 0.10 |
| sovereignty_fit | 0.15 | 0.10 | 0.30 |
| erp_compatibility | 0.15 | 0.10 | 0.05 |
| compliance_leverage | 0.15 | 0.15 | 0.15 |
| operational_control_value | 0.15 | 0.15 | 0.20 |
| buyer_trust_impact | 0.10 | 0.10 | 0.05 |
| cost_switching_risk | 0.10 | 0.10 | 0.15 |

## Build-vs-partner baseline

`build_vs_partner.csv` is intentionally consistent across scenarios unless strategy materially changes:

- Partner where external certification/network effects materially accelerate delivery.
- Build where sovereign governance, policy control, and enterprise workflow semantics are core IP/control-plane responsibilities.
- Use hybrid where near-term partner acceleration is useful but long-term internal optionality is required.

## Validation criteria

The generated artifacts satisfy these checks:

1. Each `weights.csv` sums to exactly `1.00`.
2. Each `partner_scores.csv` weighted score matches the scenario formula (rounded to 2 decimals).
3. CSV files have valid headers and no malformed rows.
