# Issue: Unrestricted set-admin function

- **Severity:** High
- **Contract:** dao.clar
- **Description:** The set-admin function can be called by any principal, allowing unauthorized changes to the admin address.
- **Impact:** Potential for malicious actors to take control of DAO administration.
- **Remediation:** Restrict set-admin to only be callable by the contract owner or a designated multi-sig.
- **Status:** Open
