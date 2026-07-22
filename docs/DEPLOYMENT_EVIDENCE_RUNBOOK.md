# Deployment Evidence Runbook

This is the policy-independent evidence and recovery foundation for GitHub
issue #531 / Linear CON-1539. It does **not** add partnership contracts,
beneficiaries, fee splits, asset scope, registry semantics, collector logic, or
gateway ABIs. Partnership deployment readiness remains blocked on #527, #528,
#529, and #530.

## Evidence boundary

Deployment is verified only when a versioned manifest passes
`scripts/verify-deployment-evidence.ts` against the selected live Hiro API.
The verifier requires:

- explicit `testnet` or `mainnet` network and matching Hiro API base URL;
- the expected deployer address;
- each exact contract name and principal;
- each publish transaction ID, with `success`, `canonical: true`, and block metadata;
- a successful interface response at the documented contract address; and
- every declared read-only check to return its expected Clarity value.

A deployment plan, a green workflow, a broadcast-only transaction ID, a local
simnet test, or a missing result is not proof. A missing transaction or
interface is reported only for the documented transaction/address; it is not a
claim of global nonexistence.

The checked-in example at
`deployment/evidence/examples/testnet.example.json` is a shape/template only.
It contains zero-value identifiers and must not be used as live evidence.

## 1. Preflight

1. Confirm the target branch, commit SHA, selected network, and expected deployer
   with a second operator. Do not put a mnemonic, private key, API key, or raw
   environment value in a manifest, log, issue, or artifact.
2. Run the repository checks that are available in the environment:

   ```bash
   python3 scripts/verify_contamination_guard.py
   npx vitest run tests/deployment-evidence.test.ts \
     tests/deployment-verification-regression.test.ts \
     --config vitest.config.ts --pool=threads
   ```

3. Review the exact network plan, but treat the plan only as input to the
   deployment. Record an optional plan hash in the manifest for correlation;
   it does not replace receipt evidence.
4. Keep mainnet approval separate from testnet validation. The mainnet workflow
   is manual and requires the literal `DEPLOY_MAINNET` confirmation plus the
   protected `mainnet` environment.

## 2. Confirmed receipt capture

Clarinet's current `deployments apply` output is not a reliable, machine-readable
receipt manifest. It may broadcast transactions and print IDs without proving
inclusion, success, canonicality, or contract contents. Do not parse that output
as verification and do not report success from the plan artifact.

After an approved deployment attempt, capture the transaction IDs and query the
matching Hiro API. For every contract publish, record the response fields that
the verifier checks: transaction ID, transaction type, sender, exact contract
principal, status, canonical flag, block hash, and block height. Use the same
network named in the manifest.

Populate a copy of the versioned manifest, setting
`evidence.source` to `confirmed-receipts`. Keep contract entries exact; do not
invent names or principals for unresolved partnership work.

## 3. Interface and read-only verification

Declare the interface requirement for every contract. Add read-only checks only
when the function, sender, Clarity arguments, and expected serialized result
are already approved and known. Then run:

```bash
npx tsx scripts/verify-deployment-evidence.ts \
  --manifest path/to/deployment-evidence.json \
  --output deployment-evidence-report.json
```

The command exits non-zero for pending, failed, non-canonical, missing, wrong,
or malformed evidence. Keep the JSON report beside the manifest. The report is
bounded to the documented transaction IDs and contract addresses.

## 4. Artifact retention and correction

- Retain the manifest, verifier report, commit SHA, optional plan hash, and
  workflow run link together as a reviewable evidence pack.
- Never retain secrets in the evidence pack. Redact or discard logs that may
  contain credentials before uploading them.
- If the network, deployer, contract name, principal, transaction ID, interface,
  or read-only expectation is wrong, stop and correct the source artifact. Do
  not weaken the verifier or reinterpret a mismatch as success.
- A plan-only artifact must remain visibly labeled as a plan. It cannot satisfy
  #531 or be used to claim partnership deployment readiness.

## 5. Pause, pending, failed, and reorg handling

- **Pending/mempool:** pause downstream wiring and wait for a fresh Hiro query.
  Do not replace the transaction ID in the manifest based on guesswork.
- **Failed/aborted/dropped:** pause. Capture the failure classification and
  follow the approved deployment correction path before retrying.
- **Non-canonical/reorg signal:** treat the transaction as unverified, pause,
  and re-query after chain state is stable. A previously successful response is
  not enough if canonicality is no longer proven.
- **Missing transaction/interface:** confirm the selected network and exact
  documented address/ID, then stop. This bounded result does not prove the
  contract or transaction is globally absent.
- **Hiro/API error:** preserve the failure classification and retry only after
  the API path and network are independently confirmed. Never convert an API
  error into a success claim.

## 6. Rollback and forward recovery

The verifier does not perform rollback and Stacks contract publication is not
made reversible by deleting a plan. If an approved deployment is wrong, pause
external traffic and follow the separately approved governance, circuit-breaker,
or operational recovery procedure. Do not add unapproved partnership routes to
compensate for a failed deployment.

Forward recovery requires new, confirmed, canonical transactions and a fresh
manifest/report. Retain the failed evidence pack for audit; never overwrite it
with a later successful attempt.

## 7. Explicit mainnet approval gate

Testnet validation cannot invoke mainnet. The testnet workflow has no automatic
promotion job. Mainnet remains a manual `workflow_dispatch` operation with:

1. explicit `confirm=DEPLOY_MAINNET`;
2. `dry_run=false` only after human approval; and
3. a supplied evidence manifest that passes the verifier before the workflow can
   report a verified deployment.

If Clarinet cannot supply the manifest in the same run, the workflow must fail
closed rather than guess, forge, or infer evidence. This limitation is
intentional until a reliable receipt-producing deployment path exists.

## Current documentation state

Use `docs/DOCUMENTATION_STATE.md` as the current repository state. Historical
readiness documents describe plans or earlier simulation findings and are not
receipt evidence. This runbook does not claim partnership deployment readiness;
the #527–#530 dependency gate remains unresolved.
