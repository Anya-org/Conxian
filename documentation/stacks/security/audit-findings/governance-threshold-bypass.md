# Issue: Governance Token Threshold Bypass

- **Severity:** High
- **Contract:** dao-governance.clar
- **Description:** The proposal threshold (100k tokens) could be bypassed through flash loans or temporary token borrowing.
- **Impact:** Malicious actors could create proposals without proper long-term stake in the protocol.
- **Remediation:** Implement time-weighted voting power or snapshot-based thresholds to prevent flash loan attacks.
- **Status:** Open
