This is an audit artifact for CON-135.

Snapshot date: 2026-04-04 (UTC)

Visibility: this snapshot is stored in a public repository. To reduce accidental disclosure of internal security/release posture, `internal-only` issue details are intentionally redacted (labels, titles, and states); identifiers and high-level categories are retained.

Scope: open CON system issues, operationally defined as issues in states Triage/Todo/In Progress/In Review/Backlog that have at least one of these labels: `Release`, `Governance`, `Security`, `Hygiene`, `Bounty`.

Query (as of snapshot): union of `ch-linear issue list -T CON -l <LABEL> -s Triage -s Todo -s "In Progress" -s "In Review" -s Backlog --json` for each label in [`Release`, `Governance`, `Security`, `Hygiene`, `Bounty`], de-duplicated by `identifier` (use pagination / a sufficiently high limit so results are not truncated).

## Reproducibility

- For each label in scope, export issues as JSON with a high enough limit to avoid truncation (rerun with a higher `--limit` if the result count equals the limit):
  - `ch-linear issue list -T CON -l <LABEL> -s Triage -s Todo -s "In Progress" -s "In Review" -s Backlog --limit 200 --json`
- Merge the per-label arrays and de-duplicate by `identifier`.
- Apply redaction for `internal-only` rows (this snapshot: redact `State`, `Labels`, and `Title`).
- Verify:
  - `Total issues in scope` equals the number of unique identifiers captured (this snapshot: **90**).
  - The `Full classification` table has one row per identifier (this snapshot: **90** rows).

## Operating definitions

- **Claim-open now (mechanical)**: `state == Todo` AND unassigned AND labels include `Bounty` and `Bounty Open`.
- **Eligible for claim-open promotion (safety)**: classified as `community-claimable` in this audit (this corresponds to the `Community-claimable` count in the Summary; i.e., safe for maintainers to apply the `Bounty` and `Bounty Open` labels when the other `Claim-open now (mechanical)` conditions are met).
- **Community-claimable**: safe to execute externally (docs/repo hygiene), with no privileged deploy/wallet/treasury access required. For governance/content work, this only applies when the issue has concrete acceptance criteria and maintainers retain final approval.
- **Internal-only**: security-sensitive, deployment-sensitive, wallet/treasury/signer, or release-gating work.
- **Blocked**: intended work, but can't proceed until a prerequisite is resolved.
- **Not suitable for bounty execution**: decision-heavy, underspecified, or otherwise not a good fit for external bounty execution as-is.

> Note: `community-claimable` is an audit-only safety classification (not a native Linear field). It does not by itself make an issue claim-open; claim-open status is controlled mechanically via state and labels as defined in `Claim-open now (mechanical)`. Other `community-claimable` issues remain maintainer-gated until maintainers apply `Bounty` and `Bounty Open`.

## Payout alignment

- Claim intake and maintainer review can proceed before payout readiness exists.
- **Payout-enabled bounty execution begins only after**:
  - ConxianCSF full system deployment is verified on Stacks mainnet
  - ALEX launch funding path is live and confirmed as the bounty source
  - signer, wallet, and approval controls are verified internally
  - post-deploy verification and rollback expectations are documented
- All bounty funds must be sourced exclusively from the ALEX launch pathway once deployment is live; do not use ad hoc or implied treasury commitments before that point.
- **A claim is not a payout commitment** until all of the above are satisfied and the ALEX-funded payout path is verified end-to-end with internal signer/wallet/approval controls.
- Until those checks are complete, issues may be claim-screened and worked only under explicit maintainer approval and without any implied payout commitment.

## Summary

- Total issues in scope: **90**
- Community-claimable: **14**
- Internal-only: **55**
- Blocked: **1**
- Not suitable for bounty execution: **20**
- Claim-open now (mechanical subset): **8**

## Claim-open now (mechanical)

| Issue | Title | Assignee | Labels |
| --- | --- | --- | --- |
| [CON-178](https://linear.app/conxian-labs/issue/CON-178/release-hygiene-github) | Release hygiene — .github | (unassigned) | Bounty, Bounty Open, Release |
| [CON-182](https://linear.app/conxian-labs/issue/CON-182/release-hygiene-conxian) | Release hygiene — Conxian | (unassigned) | Bounty, Bounty Open, Release |
| [CON-186](https://linear.app/conxian-labs/issue/CON-186/release-hygiene-conxian-ui) | Release hygiene — Conxian_UI | (unassigned) | Bounty, Bounty Open, Release |
| [CON-198](https://linear.app/conxian-labs/issue/CON-198/release-hygiene-conxian-labs-site) | Release hygiene — conxian-labs-site | (unassigned) | Bounty, Bounty Open, Release |
| [CON-214](https://linear.app/conxian-labs/issue/CON-214/release-hygiene-lib-conclave-sdk) | Release hygiene — lib-conclave-sdk | (unassigned) | Bounty, Bounty Open, Release |
| [CON-218](https://linear.app/conxian-labs/issue/CON-218/release-hygiene-lib-conxian-core) | Release hygiene — lib-conxian-core | (unassigned) | Bounty, Bounty Open, Release |
| [CON-222](https://linear.app/conxian-labs/issue/CON-222/release-hygiene-stacksorbit) | Release hygiene — stacksorbit | (unassigned) | Bounty, Bounty Open, Release |
| [CON-78](https://linear.app/conxian-labs/issue/CON-78/con-75-bounty-gateway-edge-offline-first-pos-sync) | CON-75: [BOUNTY] Gateway Edge - Offline-First POS Sync | (unassigned) | Bounty, Bounty Open |

## Full classification

| Issue | State | Category | Labels | Title |
| --- | --- | --- | --- | --- |
| CON-129 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-131 | In Progress | not suitable for bounty execution | Bounty | Adopt stricter bounty workflow for Conxian-Labs |
| CON-132 | In Review | not suitable for bounty execution | Governance | Update conxian-business for BOS operating requirements |
| CON-133 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-135 | Todo | not suitable for bounty execution | Bounty, Governance, Release | Roll out claimable community workflow across system issues |
| CON-136 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-140 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-141 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-142 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-143 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-144 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-146 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-148 | In Progress | not suitable for bounty execution | Governance | BOS business buildout — conxius-wallet |
| CON-149 | Todo | not suitable for bounty execution | Governance | BOS business buildout — conxius-platform |
| CON-150 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — Conxian_UI |
| CON-151 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — conxian-gateway |
| CON-152 | In Progress | not suitable for bounty execution | Governance | BOS business buildout — conxian-business |
| CON-153 | Todo | not suitable for bounty execution | Governance | BOS business buildout — Conxian/Conxian |
| CON-154 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — lib-conxian-core |
| CON-155 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — stacksorbit |
| CON-156 | In Review | not suitable for bounty execution | Governance | BOS business buildout — business units and portfolio separation |
| CON-161 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-162 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-165 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-166 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-167 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-168 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-169 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-171 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-172 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — conxian-labs-site |
| CON-173 | Backlog | not suitable for bounty execution | Governance | BOS business buildout — conxian-nexus |
| CON-176 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-177 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-178 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — .github |
| CON-179 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-180 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-181 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-182 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — Conxian |
| CON-183 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-184 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-185 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-186 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — Conxian_UI |
| CON-187 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-192 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-195 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-196 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-197 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-198 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — conxian-labs-site |
| CON-199 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-200 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-201 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-202 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-204 | In Review | community-claimable | Governance | Release hygiene — conxian-nexus |
| CON-205 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-207 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-208 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-210 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-211 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-212 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-214 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — lib-conclave-sdk |
| CON-215 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-216 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-217 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-218 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — lib-conxian-core |
| CON-219 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-220 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-221 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-222 | Todo | community-claimable | Bounty, Bounty Open, Release | Release hygiene — stacksorbit |
| CON-223 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-226 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-227 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-229 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-230 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-231 | Backlog | blocked | Bounty, Governance | Decide which bounties can open before mainnet go-live |
| CON-232 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-233 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-239 | In Review | community-claimable | Governance | Add purpose and status sections to flagship READMEs |
| CON-259 | Backlog | community-claimable | Governance | Improve clarity across public-facing Conxian repos |
| CON-260 | Backlog | not suitable for bounty execution | Governance | Clarify org portfolio and pinned repositories |
| CON-269 | Backlog | community-claimable | Governance | Audit Conxian_UI public-facing clarity |
| CON-294 | Backlog | not suitable for bounty execution | Governance | Define public repo taxonomy and site navigation |
| CON-296 | In Progress | not suitable for bounty execution | Governance | Define trust and proof messaging for public surfaces |
| CON-298 | Backlog | not suitable for bounty execution | Governance | Select and order pinned flagship repos |
| CON-299 | Backlog | community-claimable | Governance | Standardize flagship repo README structure |
| CON-300 | Backlog | not suitable for bounty execution | Governance | Draft trust, governance, and proof content |
| CON-301 | Backlog | community-claimable | Governance | Classify public repos by external role |
| CON-305 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-369 | (redacted) | internal-only | (redacted) | (redacted) |
| CON-370 | Triage | not suitable for bounty execution | Governance | BOS business buildout — lib-conclave-sdk |
| CON-78 | Todo | community-claimable | Bounty, Bounty Open | CON-75: [BOUNTY] Gateway Edge - Offline-First POS Sync |

