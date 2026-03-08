---
description: Analyze and repair Clarinet compilation and test issues
auto_execution_mode: 3
---

# Clarinet Check & Repair Workflow

This workflow uses the `analyze-clarinet.ps1` script to identify and fix compilation and test issues.

## Usage

```bash
# Run analysis only
scripts\analyze-clarinet.ps1 -ReportOnly

# Run analysis with auto-fix attempts
scripts\analyze-clarinet.ps1 -Fix

# Generate markdown report
scripts\analyze-clarinet.ps1 -OutputPath ./reports/clarinet-analysis.md
```

## Workflow Steps

### 1. Initial Analysis

// turbo

```bash
clarinet check 2>&1 | Out-File -FilePath clarinet-check-raw.txt -Encoding UTF8
```

### 2. Parse Issues

Run the analyzer script to categorize issues:

- Syntax errors (critical)
- Type errors (critical)
- Trait mismatches (critical)
- Contract reference errors (high)
- Unresolved functions (high)
- Warnings (medium)

### 3. Remediation Priority

#### P0 - Critical (Blocks compilation)

- [ ] Fix syntax errors
- [ ] Resolve type mismatches
- [ ] Implement missing trait methods
- [ ] Fix circular dependencies

#### P1 - High (Blocks tests)

- [ ] Add missing contracts to Clarinet.toml
- [ ] Fix missing contract methods
- [ ] Resolve contract deployment order
- [ ] Fix mock contract references

#### P2 - Medium (Warnings)

- [ ] Address deprecation warnings
- [ ] Clean up unused variables
- [ ] Standardize error codes

### 4. Verification

// turbo

```bash
clarinet check
npm test
```

## Common Fixes

### Missing Contract in Clarinet.toml

```toml
[contracts.contract-name]
path = "contracts/path/contract.clar"
clarity_version = 2
epoch = "2.4"
depends_on = ["dependency1", "dependency2"]
```

### Missing Trait Method

Add required method to implementing contract:

```clarity
(define-public (missing-method (param uint))
  (begin
    ;; implementation
    (ok true)
  )
)
```

### Circular Reference

Replace direct contract calls with trait-based calls or data-var injection.

## Reports

Analysis reports are generated in markdown format with:

- Error counts by category
- Contract-by-contract breakdown
- Auto-fix results
- Manual intervention checklist
