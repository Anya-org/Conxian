# Partnership Deployment Runbook

This runbook defines the evidence and recovery controls for a future partnership deployment. It does **not** approve partnership economics, add partnership contracts, or assert that any Conxian deployment has occurred.

## 1. Scope and blocked upstream gates

The current issue #531 scope is deployment safety and evidence only.

- Issues #527–#530 are unresolved and remain upstream blockers. Do not add partnership Clarity contracts, guessed principals, wiring, economics, or release-plan entries until those decisions are approved and implemented.
- Release gates #515 and #526 must be explicitly cleared before a partnership release is considered.
- Existing integration-fee behavior is out of scope. Do not alter its economics as part of deployment work.
- A plan, a successful workflow job, or an accepted broadcast is not a receipt. Canonical success requires the evidence verifier to observe the transaction and interface through the network API.

## 2. Dependency order

Use the checked-in release plan as the source of dependency order. The generator reads only the active `Clarinet.toml`; `Clarinet.complete.toml` is not a release dependency source. Every active `depends_on` edge is treated as a hard publish prerequisite. If an edge is stale or its release meaning is ambiguous, resolve the manifest or classify the artifact explicitly before release; the validator does not guess. `python3 scripts/gen-deployment-plans.py --check` now fails closed on manifest/source drift, duplicate or unknown publishes, missing or excluded dependencies, dependency inversions/cycles, and testnet/mainnet topology drift. It retains the existing nine publish batches and final ten-call wiring batch while applying a stable topological order within that shape.

The current production sequence is:

1. Traits and standards.
2. Core access and protocol contracts.
3. Oracle contracts.
4. Tokens and treasury support.
5. Security and circuit-breaker contracts.
6. DEX and routing contracts.
7. Revenue, agent, and operations contracts.
8. Gateway and approved post-publication configuration calls.

Partnership contracts, principals, and configuration calls must be appended only after the blocked upstream issues are resolved. Never infer their order or addresses from a proposal, issue title, or prior broadcast.

## 3. Preflight

Run from a clean checkout and record the exact source commit before any broadcast:

```bash
git fetch origin
git status --short
git rev-parse HEAD
clarinet check --manifest-path Clarinet.toml
npm run test:deployment-evidence
npm run assert:community-voting-wiring
```

The plan generator requires the repository's pinned CI prerequisite. When Python does not already provide it, install the same version used by CI:

```bash
python3 -m pip install --user --disable-pip-version-check 'PyYAML==6.0.2'
python3 scripts/gen-deployment-plans.py --check
npm run validate:deployment-plans
npm run test:release-plan-validation
```

Capture all of the following in the evidence bundle and operator handoff:

- Full source commit SHA (`git rev-parse HEAD`).
- Exact plan path and SHA-256 (`sha256sum <plan>`).
- Network (`testnet` or `mainnet`).
- Deployer address, checked with the repository's Stacks principal validator and the selected network (`ST...`/`SN...` for testnet, `SP...`/`SM...` for mainnet).
- The approved release or change identifier that cleared the upstream gates.

The mainnet workflow also compares `deployments/full-system.mainnet-plan.yaml` with the committed digest in `deployments/full-system.mainnet-plan.sha256`. A mismatch or a non-mainnet deployer identity blocks a non-dry run. The current full-system mainnet plan still contains an unresolved `ST...` deployer identity; it is not a valid mainnet identity and must not be replaced by a guessed `SP...`/`SM...` address. Replace it only with an approved identity derived from, and verified against, the configured signer.

## 4. Evidence bundle

Start from `deployment/deployment-evidence.template.json`, replacing every deliberately invalid placeholder. The template cannot pass verification until all identity, hash, and transaction fields are populated.

The bundle must contain:

- `evidenceStatus` distinguishing `plan`, `workflow`, `broadcast`, and `confirmed`.
- Full source commit and plan SHA-256.
- Network and deployer identity.
- Every effective `contract-publish` and `contract-call` entry in the exact plan passed to `--plan`, bound by batch/transaction ordinal and expected contract/function identity.
- Contract-call arguments when present, checked against the canonical Clarity representation in the Hiro transaction payload.
- An interface expectation for every published contract, including required `public` and `read_only` functions.
- Optional `readOnlyChecks` for deterministic node-level checks. Each check must name the expected network, the exact contract principal covered by the bound plan and evidence, a canonical sender accepted by the call-read API (a standard address such as `ST...`/`SP...` or a contract principal such as `ST....contract-name`), the Clarity function, serialized Clarity argument hex values, `expectedOkay: true`, and the exact serialized Clarity result expected from the node. The verifier validates the sender address checksum and network and validates a contract sender's name; contract senders must also be present in the bound evidence.
- `claims.scope: checked-addresses` and `claims.globalNonexistence: false`.

The last two fields are intentional: a missing interface or transaction at one checked address is bounded evidence about that lookup, not proof that the contract is absent everywhere.

Verify a real bundle against Hiro without exposing a private key or API key:

```bash
npm run verify:deployment-evidence -- \
  --evidence deployment-artifacts/testnet-evidence.json \
  --network testnet \
  --deployer ST... \
  --plan deployments/full-system.testnet-plan.yaml \
  --source-commit "$(git rev-parse HEAD)" \
  --output deployment-artifacts/testnet-evidence.verified.json
```

The verifier parses the exact YAML plan supplied by `--plan`, requires one and only one evidence record for every effective publish/call entry, and rejects missing, extra, duplicate, reordered, or mismatched ordinals. It uses the network-specific Hiro API, requires a transaction to be found, canonical, anchored, and successful, and checks the expected transaction type, sender, contract, function, and—where applicable—canonical call arguments. It then requires HTTP 200 for each exact contract interface and checks the requested function access levels. Read-only checks must name a function present in that live interface as `read_only`; when the interface exposes an `args` array, the verifier also requires the declared serialized argument count to match. It deliberately does not infer Clarity type compatibility from interface type strings; the node validates the serialized Clarity arguments during execution, while the verifier enforces function, access, count, and exact node result. Unsupported or malformed API payloads fail closed. A successful bundle means complete plan evidence; a broadcast/partial candidate is never a deployment conclusion.

The `--api-base-url` option exists for deterministic local HTTP tests and controlled mirrors. Do not use a non-Hiro endpoint for production acceptance unless the operator records that exception and independently establishes equivalent canonical evidence.

When `readOnlyChecks` are declared, the verifier first binds each check to the live interface metadata, then performs it as a `POST /v2/contracts/call-read/{address}/{contract}/{function}` request with the declared standard or contract-principal `sender` and serialized `arguments`. A successful check proves only that the selected node evaluated that exact read-only function at that exact contract principal and returned HTTP 200, `okay: true`, and the exact declared Clarity result. It does **not** prove that a mutating/public function succeeded, that the contract was published by this run, that dependencies or economics are correct, or that any other address is empty. Missing, unknown-function, non-read-only, argument-count, HTTP, provider, timeout, malformed, `okay: false`, and result-mismatch responses fail the verifier; a declared check is never silently skipped.

## 5. Testnet proof

The active `scripts/deploy-testnet.ts` helper is bounded to testnet and the existing sequence. It:

- Verifies that `SYSTEM_ADDRESS` matches the supplied `DEPLOYER_PRIVKEY` without printing the key.
- Uses the corrected `contracts/treasury/revenue-automation.clar` path.
- Uses deny-mode post conditions.
- Stops on the first publish failure.
- Writes or updates a `broadcast`/`partial` candidate as `<evidence>.broadcast.json` after every accepted txid and on failure/finally paths.
- Polls with a bounded timeout and can write a confirmed evidence file only after canonical transaction, interface, and complete matching-plan verification.
- Never labels or prints a broadcast-only result as confirmed or completed.
- Performs a bounded preflight over every helper target before the first broadcast and aborts with a machine-readable `PREEXISTING_CONTRACT` failure if any target already exists. It does not skip that target or continue with a mixed run. Independent original publish receipt and interface evidence is required for a pre-existing contract; `preexistingContracts` cannot be used as confirmed coverage.

Required environment variables are `DEPLOYER_PRIVKEY`, `SYSTEM_ADDRESS`, and `DEPLOYMENT_PLAN_PATH`. The plan path must identify a generated testnet helper mini-plan whose entries exactly match the bounded sequence and whose deployer is `SYSTEM_ADDRESS`; the full-system plan is intentionally rejected. When git metadata is unavailable, `SOURCE_COMMIT` is also required. Optional controls are `CORE_API_URL`, `HIRO_API_KEY`, `DEPLOYMENT_EVIDENCE_PATH`, `DEPLOY_CONFIRM_TIMEOUT_MS`, and `DEPLOY_CONFIRM_POLL_MS`.

Do not treat an existing interface at a checked address as proof that this run published the contract. The helper is intentionally limited to a small testnet helper/preparatory sequence, not the full-system or partnership deployer. Its broadcast candidate is partial and cannot satisfy the full-system plan unless an explicit matching plan is supplied and every plan entry is independently evidenced; otherwise verification fails closed.

## 6. Mainnet human gate

Mainnet remains manual only, and the current GitHub workflow is preflight-only:

1. Keep `dry_run=true` unless the operator is ready for a real release.
2. Supply the exact confirmation string `DEPLOY_MAINNET`.
3. Use the protected `mainnet` GitHub environment and its required reviewers.
4. Confirm that the committed plan digest, network, source commit, and deployer identity are the approved values. The current `ST...` identity in the mainnet plan is an unresolved blocker, not an authorization to broadcast.
5. Expect the workflow to validate the plan and emit clearly labeled plan/preflight/log artifacts only. It does not invoke `clarinet deployments apply`, load a mnemonic, sign, or broadcast.
6. Every non-dry path must stop before signing until a structured receipt-producing broadcaster and complete evidence path exist for issue #531. Do not create placeholder txids or treat dashboard/debug logs as proof.

The mainnet preflight job always starts, validates the confirmation, and fails visibly when `confirm` is missing or differs from `DEPLOY_MAINNET`; an incorrect confirmation is never represented as a green skipped deployment job. This confirmation gate does not authorize signing or broadcasting.

There is no testnet-to-mainnet promotion job. A testnet result never authorizes a mainnet run.

## 7. API and read-only checks

For each transaction, retain the verifier's sanitized API evidence:

- txid and API observation timestamp;
- successful status, `canonical: true`, and `isUnanchored: false`;
- transaction type and expected contract/function;
- sender address;
- Stacks block hash/height and the required positive burn-block height; preserve `burn_block_hash` only when Hiro supplies a non-null value;
- optional block timestamps.

For each checked contract, retain:

- the exact interface endpoint and observation timestamp;
- HTTP 200;
- the function inventory and access classification;
- confirmation that every required `public` or `read_only` function is present.

For each declared read-only check, retain the sanitized endpoint, observation timestamp, canonical sender, serialized argument list, HTTP 200 status, `okay: true`, and returned serialized result. Do not retain provider credentials or raw authorization headers. A read-only result is a bounded state observation, not a substitute for a canonical publish receipt or complete plan coverage.

Configuration calls are verified as `contract-call` transactions. A workflow summary or read-only smoke test without these API records is not acceptance evidence.

## 8. Correction, pause, and recovery

### Current pause gate

The current GitHub workflows are preflight-only and cannot pause routes or submit a transaction. If a future approved broadcaster is used, pause the affected routes before the first write and keep them paused through read-after-write verification. Use only the approved admin/governance path; do not invent a principal or bypass authorization.

The current Clarity pause controls are:

- Protocol-wide pause write: `ops-engine.trigger-emergency-pause`, which is admin-gated and calls `enhanced-circuit-breaker.toggle-global-pause`.
- Targeted pause write: `enhanced-circuit-breaker.toggle-contract-pause(target)`, also admin-gated.
- Pause reads before and after each release segment: `enhanced-circuit-breaker.is-globally-paused()`, `enhanced-circuit-breaker.is-contract-paused(target)`, `conxian-protocol.is-paused()`, and `conxian-protocol.get-protocol-status()`.
- The older `circuit-breaker.is-contract-paused(target)` read is retained for contracts using that trait implementation; do not treat it as equivalent to the enhanced global pause read.

Record the pause read results, observed block height, target principals, and operator decision in the evidence pack. A failed or contradictory pause read is a stop condition.

### Read-before-write controls

Before every publish or configuration call, record and compare:

1. Clean worktree, source commit, exact plan bytes, generated-plan check result, and plan SHA-256.
2. Network and deployer identity. Derive the signer address from the configured signer and compare it to the plan; never replace the unresolved mainnet `ST...` identity with a guessed `SP...`/`SM...` address.
3. Pause state using the read-only controls above, plus the current route/registry/treasury state that the next call is expected to change.
4. Network API observations for the target address/interface and any prior transaction. An existing interface is recorded as `preexisting`/`checked-addresses` evidence, not proof that this run published it.
5. The exact batch and transaction ordinal, contract path, function, and canonical call arguments that will be written.

Do not write when the plan hash, signer, pause state, interface, read-only state, or expected ordinal is unknown or mismatched. The current workflows stop at this preflight boundary and do not sign or broadcast.

### Read-after-write controls

After each future accepted transaction, pause the next dependent write until the network API shows a canonical, anchored, successful transaction with the expected sender, contract/function, and arguments. For a publish, also require HTTP 200 interface evidence and the requested `public`/`read_only` function inventory. For a call, re-read the exact state changed by that call and repeat the pause/route/registry/treasury reads before continuing. Pending, aborted, dropped, noncanonical, missing-interface, or read-only-mismatch results remain non-confirmed evidence and stop the sequence.

### Before broadcast

Stop on any mismatch in plan hash, source commit, network, deployer, contract path, or expected identity. Correct the artifact and re-run preflight. Do not bypass a gate by editing a report or summary.

### Pending, aborted, or noncanonical transaction

Pause the sequence. Do not rebroadcast the same nonce or assume that a pending tx will succeed. Preserve the broadcast candidate, API responses/statuses, and timestamps. The bounded poller may retry transient absence/pending/interface availability, but it ultimately fails closed.

### Published immutable contract

A published Clarity contract cannot be rolled back or deleted from the chain. A correction requires an explicitly reviewed forward deployment under a new contract identity, followed by approved registry/configuration changes. Never overwrite evidence to make the immutable publication appear corrected.

### Partial deployment or settlement

Record exactly which publications and calls are confirmed, pending, failed, or pre-existing. Pause dependent configuration until the dependency graph is repaired. Any recovery of partial settlement must preserve debt, claim, and settlement state; do not silently erase obligations or invent partnership fee treatment. Resume forward only from an approved plan revision with a new source commit and plan hash.

### Recovery decision table

| Condition | Immediate control | Recovery decision |
| --- | --- | --- |
| Plan hash mismatch | Pause before any write; retain both hashes and source commits. | Regenerate from the reviewed source, review the diff, and issue a new approved plan/hash. Never edit evidence to make the old hash pass. |
| Signer identity mismatch | Pause before signing; do not guess or substitute an address. | Derive the identity from the configured signer, re-run network validation, and obtain approval for a new plan if the deployer changes. |
| Pending, aborted, or dropped transaction | Keep routes paused; preserve txid, nonce/ordinal, API responses, and timestamps. | Reconcile canonical status with bounded polling. Do not blindly rebroadcast the same nonce or treat absence as success; resume only from an approved forward plan. |
| Confirmed publish followed by a failed call | Keep dependent routes paused; mark the publish confirmed and the call failed separately. | Do not republish the same contract identity. Repair with an approved forward call or new contract/configuration identity, then verify the complete revised plan. |
| Missing interface | Treat the publication as unconfirmed and keep routes paused. | Retry only the bounded read path. If the interface remains absent or malformed, fail closed and classify the result as checked-address evidence, not global absence. |
| Read-only mismatch | Pause before the next write; preserve pre-state, post-state, and expected value. | Reconcile the exact getter/argument/ordinal and investigate the failed or unexpected state transition. Do not issue a compensating write without an approved recovery plan. |
| Immutable defect | Keep affected routes paused and preserve the original publication evidence. | Clarity publication is immutable. Deploy a reviewed replacement under a new identity and migrate registry/router/configuration state forward-only. |
| Partial settlement | Pause dependent settlement and record confirmed, pending, failed, and pre-existing obligations separately. | Preserve debt, claims, and settlement state. Resume only with an approved forward recovery plan; never silently erase obligations or alter integration-fee economics. |

Clarity publication is immutable. After routes are paused, every recovery is forward-only: preserve the original evidence, create a reviewed plan revision with a new source commit and hash, and verify the revised transaction/interface set before resuming routes.

## 9. Evidence retention and handoff

Retain, as a single evidence pack:

- source commit and plan files/digests;
- the non-proof broadcast candidate, if one exists;
- the confirmed evidence bundle, if verification succeeded;
- deployment command output and workflow artifact links;
- sanitized API observations, block identifiers, interface inventories, and timestamps;
- the operator, network, deployer address, gate approvals, and any pause/recovery decision.

Never retain private keys, mnemonics, API keys, or secret environment values in logs or evidence artifacts. Store artifacts with immutable retention appropriate to the release process and hand the pack to the next operator before any forward recovery.

## 10. Acceptance rule

The release is accepted only when the verifier returns `evidenceStatus: confirmed` for the intended network, source commit, plan hash, deployer, transaction set, and interface set. Anything else is a plan, workflow result, broadcast, pending state, failure, or bounded checked-address observation—not proof of deployment and not a global nonexistence claim.

Green CI is not on-chain deployment proof. CI can validate source, plan binding, schema shape, workflow gates, and deterministic mocks; only complete canonical network evidence for the intended plan can establish the bounded evidence conclusion described above.
