
## 4. Remediation Standard (April 2026)

Following the remediation of CON-394 and CON-61:
- **No Hardcoded Principals:** Production Clarity contracts must use `tx-sender` or dynamic `data-vars` for administrative roles.
- **Fail-Closed by Default:** Functional stubs (e.g., ZKML, DLC) must return explicit errors in the production path if the implementation is incomplete. Simulated data is only allowed on `dev` branches or behind explicit `mock-integrations` feature gates.
- **Contamination Guard:** All PRs targeting `main` or `staged` are subject to the `verify_contamination_guard.py` check.
