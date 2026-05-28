# ExCo Sovereign-first intake and wiring (public-safe)

This repository is public. ExCo-relevant newly discovered work is **Sovereign-first**.

Detailed strategic, financial, legal, security, and deep operational runbook content remains canonical in the sovereign coordination layer under Zero Secret Egress (ZSE).

Traceability:

- Canonical coordination layer (see docs/SOVEREIGN_COORDINATION_LAYER.md)

## Minimum required intake fields

Every ExCo intake issue in Linear must include:

1. **Operating lens**
2. **Owner** (single accountable owner)
3. **Repo/business surface**
4. **Urgency/priority**
5. **Outcome + acceptance signal**
6. **Source links**

## Protocol-adapter intake extension (required for emerging rails)

When intake touches protocol-adapter execution (including emerging rails), include the lane extension fields from
[`docs/architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md`](../docs/architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md):

1. **Maturity lane** (`Build-now`, `Pilot`, `Partner`, `Research`)
2. **Default handling note** (if lane was omitted at creation, record that it defaulted to `Research`)
3. **Rail scope**
4. **Target adapter interface**
5. **Owner** (single accountable owner)
6. **Review cadence**
7. **Risk register**
8. **Promotion blockers**

## Intake flow (concise)

1. **Discover**: capture the originating signal and links.
2. **Create/route issue (Linear-first)**: open or route the issue in Linear with all required fields.
3. **Triage**: confirm owner, urgency, and execution surface.
4. **Execution linkbacks**: link implementation artifacts (PRs/issues/docs) back to the Linear issue, and include the Linear URL in mirrored public-safe GitHub items.

## ZSE boundary

Sensitive strategic, financial, legal, security, and detailed operational material stays in the sovereign coordination layer only.

Public GitHub artifacts must remain sanitized/public-safe and should point back to the canonical coordination layer issue.
