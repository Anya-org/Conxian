# BOS Canonical Reference Cleanup Checklist

This checklist is intended to repair trust in BOS as a source-of-truth repository.

## Problem summary

Several BOS-facing documents point to files or canonical references that do not currently resolve in the active repository tree. A document cannot remain marked canonical if its linked source-of-truth dependencies are missing or broken.

## Immediate cleanup tasks

- [ ] Audit all references in `README.md`
- [ ] Audit all references in `docs/DOCUMENTATION_ALIGNMENT_INDEX.md`
- [ ] Audit all references in `docs/REPO_PORTFOLIO.md`
- [ ] Verify every document labeled **Canonical** exists and resolves from its cited path
- [ ] Downgrade any incorrect canonical label until the missing source is restored
- [ ] Restore or replace broken references for BOS buildout and runtime ownership documents

## Known concerns to resolve

- [ ] `docs/BOS_BUSINESS_BUILDOUT.md`
- [ ] `conxian-business/BOS_RUNTIME_OWNERSHIP_MAP.md`

## Canonical labeling rules

Use **Canonical** only when all of the following are true:
- the file exists in the active repository tree
- the file is intended as the current source of truth
- all important inbound references point to the active path
- no contradictory document is also marked canonical for the same domain

## Acceptable outcomes for missing references

1. Restore the missing file
2. Replace the link with the correct active file
3. Mark the file as supporting or deprecated and point to the real canonical source
4. Replace the reference with a public-safe stub only if the canonical source truly lives elsewhere under ZSE

## Exit criteria

- no broken canonical references remain in the BOS README or documentation index
- every canonical link resolves from the current repo tree
- repo role and boundary docs point to active source-of-truth documents only

## Related work
- `conxian-business` issue #717
