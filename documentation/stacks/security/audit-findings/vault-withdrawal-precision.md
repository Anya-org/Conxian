# Issue: Vault Withdrawal Without Proper Balance Check

- **Severity:** High
- **Contract:** vault.clar
- **Description:** The withdraw function may allow withdrawals exceeding user's actual share balance due to potential precision issues in share-to-balance calculations.
- **Impact:** Users could potentially withdraw more assets than they own, leading to vault insolvency.
- **Remediation:** Add explicit balance checks and use safe math operations to prevent precision attacks.
- **Status:** Open
