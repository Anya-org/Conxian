## Pull Request Description
Provide a concise but comprehensive summary of the changes in this Pull Request. Explain **why** this change is necessary and **what** it accomplishes.

### Strategic Alignment
- [ ] This PR aligns with the BOS operating model docs ([SERVICE_LOOP.md](https://github.com/Conxian/conxian-business/blob/main/conxian-business/SERVICE_LOOP.md), [openspec/](https://github.com/Conxian/conxian-business/tree/main/openspec/)).
- [ ] If this introduces new documentation or files, `SUMMARY.md` has been updated accordingly.
- [ ] Security and Compliance considerations have been reviewed (refer to [SECURITY.md](https://github.com/Conxian/conxian-business/blob/main/SECURITY.md) and [CSF_MAINNET_READINESS_GATE.md](https://github.com/Conxian/conxian-business/blob/main/docs/CSF_MAINNET_READINESS_GATE.md) where applicable).

### Type of Change
*Select all that apply:*
- [ ] 📝 Documentation Update
- [ ] 📈 Strategy / Business Model Refinement
- [ ] ⚙️ Administrative / CI/CD Configuration
- [ ] 🔒 Security / Compliance Enhancement
- [ ] 🧹 Maintenance / Chore

### Checklist
- [ ] I have performed a self-review of my own work.
- [ ] I targeted the correct base branch (`dev`, `staged`, or `main`) per [`docs/BRANCHING_AND_PROMOTION_POLICY.md`](../docs/BRANCHING_AND_PROMOTION_POLICY.md).
- [ ] If label-gated suites apply, I have applied (or requested a maintainer to apply) the correct PR label(s) so the relevant CI suites run (see [`RELEASE_HYGIENE.md`](./RELEASE_HYGIENE.md)).
- [ ] I have verified that all automated checks (if any) pass successfully.
- [ ] The language and tone adhere to the Earthy Corporate Finance standard.
- [ ] Any references to temporal events on-chain are properly anchored (e.g., Bitcoin burn-block-height).
- [ ] My commits follow the [Conventional Commits](https://www.conventionalcommits.org/) format.

Reference: `docs/PROMOTION_CHECKLISTS.md`
Delete the sections that do not apply to your PR.

<!-- PROMOTION:FEATURE->DEV -->
### Feature -> dev promotion checklist

- [ ] I targeted `dev` (not `staged`/`main`) and the change is appropriate for testnet/non-production validation.
- [ ] I ran the relevant local validation for the touched areas.
- [ ] The PR is scoped and does not mix unrelated changes (especially across `.github/`, `openspec/`, `docs/`, `scripts/`).
- [ ] If this change touches wallets/signers/treasury/deployment surfaces, I described the change boundary and the expected runtime lane (`dev`/testnet).

<!-- PROMOTION:DEV->STAGED -->
### Dev -> staged promotion checklist

- [ ] Integrated testnet validation completed on `dev` and is linked here.
- [ ] Required CI checks are green for the exact promotion candidate commit.
- [ ] Wallet / signer / treasury boundary checks are explicitly recorded.
- [ ] Deployment boundary checks are explicitly recorded.
- [ ] Any required submodule pins, lockfiles, and artifact provenance are updated for the promotion candidate.

<!-- PROMOTION:STAGED->MAIN -->
### Mainnet acceptance evidence pack

Required for `staged` -> `main` promotions. Provide the evidence pack under this heading, or link to a versioned in-repo file per `openspec/specs/mainnet-acceptance-evidence-pack/spec.md`.

### Additional Notes
*Any other relevant information, context, or blocking dependencies for the reviewers.*
