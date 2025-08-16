# Issue: Missing Emergency Pause Mechanism

- **Severity:** Medium
- **Contract:** vault.clar
- **Description:** The vault contract does not implement an emergency pause function, which could prevent contract operations in case of a detected exploit or vulnerability.
- **Impact:** Inability to quickly halt vault operations during emergencies, increasing risk to user funds.
- **Remediation:** Add a multi-sig controlled emergency pause/unpause function to the vault contract.
- **Status:** Open
