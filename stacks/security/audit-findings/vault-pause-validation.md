# Issue: Missing Pause State Validation

- **Severity:** Medium
- **Contract:** vault.clar
- **Description:** Some functions in the vault contract don't check the paused state, potentially allowing operations during emergency situations.
- **Impact:** Operations may continue during emergencies when they should be halted.
- **Remediation:** Add pause state checks to all critical vault functions (deposit, withdraw, etc.).
- **Status:** Open
