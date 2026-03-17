# Conxian-Labs System IP Audit & Lexicon Enforcement Protocol

## 1. Objective
To maintain 100% IP sovereignty and eliminate legacy nomenclature that creates M&A friction or technical debt. Specifically, purging the vulnerable "Conxian" abbreviation in favor of standardized "cxn-" agent prefixes and the full "Conxian" name.

## 2. Audit Scope
- All Markdown documentation (.md).
- Business strategy files.
- Agent suite identifiers.
- Internal state machine schemas.

## 3. Enforcement Logic
1. **Full Name Primacy**: Use "Conxian" for the protocol and "Conxius" for the access layer.
2. **Agent Standardization**: All internal executive modules must use the `cxn-` prefix (e.g., `cxn-strategy-nexus`).
3. **Legacy Purge**:
   - Search for "Conxian".
   - Replace with "cxn-" where referring to internal agents.
   - Replace with "Conxian" where referring to the protocol/business.
   - Exception: Do not modify critical system hashes, binary files, or external dependency integrity strings (e.g., pnpm-lock.yaml) unless they are strictly internal identifiers.

## 4. Initialization
- **Date**: March 2026
- **Status**: ACTIVE
- **Authority**: CEO (cxn-strategy-nexus)
