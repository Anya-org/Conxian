# Spec: CON-383 Full BOS Buildout — Stub Removal, Production Implementation & Verification

**Linear:** [CON-383](https://linear.app/conxian-labs/issue/CON-383/remove-bos-state-machine-stub-from-production-path)  
**Related:** CON-385, CON-392, CON-394, CON-396  
**Scope:** `conxian-business` (primary), `conxian-nexus` (stubs), devcontainer

---

## Problem Statement

The Conxian stack has two categories of unresolved stub/placeholder contamination that block mainnet readiness:

1. **BOS production path (CON-383 / CON-392):** `conxian-business/` contains three `*.stub.json` files (`BOS_STATE_MACHINE`, `AUDIT_MANIFEST`, `SARB_COMPLIANCE_REPORT`) that are correctly isolated under `conxian-business/` and allowlisted in the contamination guard — but the CI script `verify_bos_production_boundary.py` enforces that no production/CI code may _reference_ them. The `transparency_custodian.py` script generates a real `AUDIT_MANIFEST.json` into `.generated/` (gitignored), but the stub files themselves have no automated verification that they remain non-runtime. The `execute_tx` handler in `conxian-nexus` still contains `// Simulate execution success` — a residual placeholder comment in a production-facing path.

2. **Nexus experimental stubs (CON-394 follow-on):** Six modules in `conxian-nexus/src/` contain `[STUB]` markers that are currently allowlisted in `verify_contamination_guard.py` REPO_EXCLUSIONS. The user has requested full production implementation of these stubs:
   - `src/api/zkml.rs` — ZKML verification (Groth16/PlonK), returns fake `valid=true` on non-empty proof
   - `src/api/dlc.rs` — DLC bond orchestrator, returns placeholder `oracle_announcement`
   - `src/api/identity.rs` — ENS/BNS/WorldID resolution, returns hardcoded addresses
   - `src/api/erp.rs` — OData→x402 mandate translation, mocks enclave attestation
   - `src/storage/kwil.rs` — Kwil gRPC persistence, returns `kwil_tx_stub_*` hashes
   - `src/storage/tableland.rs` — Tableland REST persistence, returns random hash
   - `src/executor/mod.rs:109` — ARR/MRR/Churn metrics, Redis increment only (no Supabase write)
   - `src/config.rs` — `ORACLE_SERVICE_IS_STUBBED = true` blocks oracle in production

3. **Devcontainer gap:** No Rust or Python toolchain is installed, making local test execution impossible. CI uses Python 3.10 and Rust stable.

4. **Test coverage gaps:** `test_health_check_stub` in `api_test.rs` is an empty test body. No tests exist for the experimental API handlers (ZKML, DLC, Identity, ERP), Kwil/Tableland adapters, or the oracle service.

---

## Requirements

### R1 — Devcontainer: Install Rust + Python
- Add Rust (stable) and Python 3.10 to `.devcontainer/Dockerfile`
- Verify `cargo test` and all `scripts/*.py` run locally after rebuild

### R2 — BOS Production Boundary (CON-383)
- Confirm `BOS_STATE_MACHINE.stub.json`, `AUDIT_MANIFEST.stub.json`, `SARB_COMPLIANCE_REPORT.stub.json` remain under `conxian-business/` and are non-runtime (no code path reads them at runtime)
- Remove the `// Simulate execution success` comment from `src/api/rest.rs:execute_tx` — replace with a factual comment or none
- Add a test to `api_test.rs` replacing the empty `test_health_check_stub` body with a real health-check assertion
- Run `scripts/verify_bos_production_boundary.py` and `scripts/verify_contamination_guard.py` locally and confirm both pass

### R3 — Nexus Stub Production Implementations
Each stub must be replaced with a real implementation or, where a live external dependency is not available in this environment, a properly fail-closed `NOT_IMPLEMENTED` / `SERVICE_UNAVAILABLE` response with no simulated success data. The contamination guard exclusions for these files must be removed once `[STUB]` markers are gone.

#### R3a — `src/api/zkml.rs` (ZKML verification)
- Replace stub with a fail-closed `501 Not Implemented` response
- Document the required integration path (Groth16/PlonK verifier library) in a `// TODO(CON-70):` comment
- Remove `[STUB]` marker; remove file from `REPO_EXCLUSIONS` in `verify_contamination_guard.py`
- Add unit test: verify handler returns 501 when called

#### R3b — `src/api/dlc.rs` (DLC bond orchestrator)
- Replace stub with a fail-closed `501 Not Implemented` response
- Remove placeholder `oracle_announcement` string
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`
- Add unit test: verify handler returns 501

#### R3c — `src/api/identity.rs` (ENS/BNS/WorldID resolution)
- Replace hardcoded addresses and `[STUB]` with a real HTTP resolution call to the BNS API (`https://api.bns.xyz/v1/names/{name}`) for BNS protocol; return `503 Service Unavailable` for ENS and WorldID until those integrations are wired
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`
- Add unit test: verify BNS path makes an HTTP call (mock with `reqwest` test client or verify error path)

#### R3d — `src/api/erp.rs` (OData→x402 mandate translation)
- Remove `// Mocking Enclave Attestation` and the fake `enclave_sig_*` UUID
- Wire attestation through `lib-conxian-core`'s `Wallet::sign()` (already used in Kwil adapter) — sign the mandate hash with the Nexus wallet
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`
- Add unit test: verify mandate_id is returned and attestation is a valid hex signature

#### R3e — `src/storage/kwil.rs` (Kwil persistence)
- Replace `kwil_tx_stub_*` prefix with a real Kwil HTTP/gRPC call using `reqwest` to `KWIL_PROVIDER_URL`
- If `KWIL_PROVIDER_URL` is not set, return `Err` (fail closed) — do not fall back to stub hash
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`
- Existing unit tests in `kwil_test.rs` must be updated to reflect the new error-on-missing-config behavior

#### R3f — `src/storage/tableland.rs` (Tableland persistence)
- Replace random hash stub with a real HTTP POST to `https://validator.tableland.xyz/api/v1/mutate` using `reqwest`
- If the call fails, return `Err` (fail closed)
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`
- Add unit test: verify error path when endpoint is unreachable

#### R3g — `src/executor/mod.rs` — ARR/MRR metrics
- Replace the `// [STUB] Update ARR/MRR/Churn metrics in Supabase/Redis` comment with a real Supabase REST upsert via `reqwest` to `SUPABASE_URL` + `SUPABASE_ANON_KEY` env vars
- If env vars are absent, log a warning and skip (non-fatal) — metrics must not block execution
- Remove `[STUB]` marker; remove from `REPO_EXCLUSIONS`

#### R3h — `src/config.rs` — Oracle stub flag
- Flip `ORACLE_SERVICE_IS_STUBBED` to `false` once `OracleService` is verified production-ready
- The `push_state_to_contract` in `ppp_tracker.rs` currently uses `ContractBridge::create_signed_call` — verify this is a real signed Stacks contract call (not a simulation) and document the result
- Remove oracle from `REPO_EXCLUSIONS` if `[STUB]` markers are gone

### R4 — Remove contamination guard exclusions
Once all `[STUB]` markers are removed from the above files, remove those file paths from `REPO_EXCLUSIONS["conxian-nexus"]` in `scripts/verify_contamination_guard.py`. The guard must then catch any future regressions.

### R5 — Test suite completeness
- All new production implementations must have at minimum one unit test covering the happy path and one covering the fail-closed/error path
- Replace empty `test_health_check_stub` with a real assertion (e.g. verify `health_check()` returns `"OK"`)
- `cargo test` must pass with zero failures (excluding `#[ignore]` tests that require live DB)
- `scripts/verify_contamination_guard.py` must pass
- `scripts/verify_bos_production_boundary.py` must pass
- `scripts/verify_knowledge_retention.py` must pass

### R6 — CHANGELOG + Linear update
- Add a `[Unreleased]` entry to `CHANGELOG.md` covering: devcontainer fix, stub removals, production implementations
- Update `audit/active_session.json` to reflect completion status
- Update `audit/contamination_audit_report_2026_04_05.md` to reflect newly remediated stubs

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC-1 | `cargo test` passes in `conxian-nexus/` with no failures | Run locally after devcontainer rebuild |
| AC-2 | `scripts/verify_contamination_guard.py` exits 0 | Run locally |
| AC-3 | `scripts/verify_bos_production_boundary.py` exits 0 | Run locally |
| AC-4 | `scripts/verify_knowledge_retention.py` exits 0 | Run locally |
| AC-5 | No `[STUB]` markers remain in `conxian-nexus/src/` | `grep -r "\[STUB\]" conxian-nexus/src/` returns empty |
| AC-6 | No `REPO_EXCLUSIONS` entries remain for the 7 stub files | Inspect `scripts/verify_contamination_guard.py` |
| AC-7 | Experimental API handlers return 501/503, not simulated success | Unit tests assert non-2xx for unimplemented paths |
| AC-8 | ERP handler uses real wallet signing, not UUID mock | Unit test asserts `mandate_id` + hex `attestation` |
| AC-9 | Kwil/Tableland adapters fail closed when env vars absent | Unit tests assert `Err` on missing config |
| AC-10 | `test_health_check_stub` has a real assertion | Inspect test body |
| AC-11 | `CHANGELOG.md` has an `[Unreleased]` entry | Inspect file |
| AC-12 | Devcontainer has Rust stable + Python 3.10 | `rustc --version` and `python3 --version` after rebuild |

---

## Implementation Approach (ordered)

1. **Fix devcontainer** — Add Rust stable + Python 3.10 to `.devcontainer/Dockerfile`. Rebuild and verify `cargo test` and `python3 scripts/verify_contamination_guard.py` run.

2. **BOS production boundary cleanup (CON-383)**
   - Remove `// Simulate execution success` comment from `src/api/rest.rs:execute_tx`
   - Replace empty `test_health_check_stub` with a real assertion
   - Run `verify_bos_production_boundary.py` and `verify_contamination_guard.py` to confirm baseline passes

3. **Implement ERP handler (R3d)** — Highest value, uses existing `Wallet::sign()` pattern already in Kwil adapter. Wire real signing, remove mock attestation UUID.

4. **Implement Kwil adapter (R3e)** — Replace stub hash with real `reqwest` HTTP call; fail closed on missing config. Update `kwil_test.rs`.

5. **Implement Tableland adapter (R3f)** — Replace random hash with real HTTP POST; fail closed on error.

6. **Implement ARR/MRR metrics (R3g)** — Wire Supabase REST upsert; non-fatal if env vars absent.

7. **Fail-close ZKML, DLC, Identity handlers (R3a/b/c)** — Replace simulated-success stubs with explicit `501 Not Implemented` or `503 Service Unavailable`. Add unit tests.

8. **Verify and flip Oracle stub flag (R3h)** — Audit `push_state_to_contract`, confirm it is a real signed call, flip `ORACLE_SERVICE_IS_STUBBED = false`.

9. **Remove contamination guard exclusions (R4)** — Remove all 7 file paths from `REPO_EXCLUSIONS["conxian-nexus"]`. Run guard to confirm it passes.

10. **Full test run (R5)** — `cargo test` in `conxian-nexus/`. Fix any failures. Confirm all CI scripts pass.

11. **CHANGELOG + audit docs (R6)** — Update `CHANGELOG.md`, `audit/active_session.json`, `audit/contamination_audit_report_2026_04_05.md`.

12. **Commit on feature branch** — Branch name: `con-383-bos-full-buildout`. Commit with Linear issue reference.
