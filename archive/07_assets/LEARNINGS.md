# Learnings: Documentation Maintenance & Alignment

## GitBook & GitHub Pages
- Use `.gitbook.yaml` to define the root and structure (readme/summary).
- `SUMMARY.md` is the table of contents for GitBook; all links must be valid.
- Parentheses in link titles (e.g., `[Title (Text)](path.md)`) can confuse simple regex link checkers; avoid them or handle with care.

## Documentation Alignment
- Consolidated 6-phase roadmap into `ALIGNMENT.md` and `ROADMAP.md` to prevent drift.
- Navigation footers in sub-documents improve the "Leaf-to-Root" UX.
- `AGENTS.md` is an effective place to define documentation governance for future AI agents.

## Repository Standards
- GitHub best practices (`CONTRIBUTING.md`, templates, etc.) should be in the `.github/` directory to keep the root clean.

## CI Maintenance
- Replaced generic Autotools-based Makefile CI with a purpose-built Documentation CI for the business repo.
- The new CI validates the `SUMMARY.md` structure and checks for broken internal markdown links.
