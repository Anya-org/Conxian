# Documentation Governance for Agents

## Root-to-Leaf Navigation
- The `README.md` and `ALIGNMENT.md` are the primary entry points.
- All detailed documents in `01_*` through `06_*` must include a footer linking back to the root.

## Leaf-to-Root Consistency
- When updating a sub-document (e.g., a roadmap level), verify that the master summary in `ALIGNMENT.md` or `WHITEPAPER.md` remains accurate.

## Submodule Referencing
- Always use relative paths when linking between the business repo and submodule directories (e.g., `./conxian-gateway`).
