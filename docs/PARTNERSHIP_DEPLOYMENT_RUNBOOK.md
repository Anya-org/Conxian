# Partnership Deployment Runbook

This runbook defines the evidence and recovery controls for a future partnership deployment. It does **not** approve partnership economics, add partnership contracts, or assert that any Conxian deployment has occurred.

## 1. Scope and blocked upstream gates

The current issue #531 scope is deployment safety and evidence only.

- Issues #527–#530 are unresolved and remain upstream blockers. Do not add partnership Clarity contracts, guessed principals, wiring, economics, or release-plan entries until those decisions are approved and implemented.
- Release gates #515 and #526 must be explicitly cleared before a partnership release is considered.
- Existing integration-fee behavior is out of scope. Do not alter its economics as part of deployment work.
- A plan, a successful workflow job, or an accepted broadcast is not a receipt. Canonical success requires the evidence verifier to observe the transaction and interface through the network API.

## 2. Dependency order

Use the checked-in release plan as the source of dependency order. The current production sequence is:

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
```

Capture all of the following in the evidence bundle and operator handoff:

- Full source commit SHA (`git rev-parse HEAD`).
- Exact plan path and SHA-256 (`sha256sum <plan>`).
- Network (`testnet` or `mainnet`).
- Deployer address, checked against the network prefix (`ST...` for testnet, `SP...` for mainnet).
- The approved release or change identifier that cleared the upstream gates.

The mainnet workflow also compares `deployments/full-system.mainnet-plan.yaml` with the committed digest in `deployments/full-system.mainnet-plan.sha256`. A mismatch or a non-mainnet deployer identity blocks a non-dry run.

## 4. Evidence bundle

Start from `deployment/deployment-evidence.template.json`, replacing every deliberately invalid placeholder. The template cannot pass verification until all identity, hash, and transaction fields are populated.

The bundle must contain:

- `evidenceStatus` distinguishing `plan`, `workflow`, `broadcast`, and `confirmed`.
- Full source commit and plan SHA-256.
- Network and deployer identity.
- Every contract publication transaction, with expected contract ID and sender.
- Optional configuration/contract-call transactions, with expected contract ID, function, and sender.
- An interface expectation for every published contract, including required `public` and `read_only` functions.
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

The verifier uses the network-specific Hiro API, requires a transaction to be found, canonical, anchored, and successful, and checks the expected transaction type, sender, contract, and function. It then requires HTTP 200 for each contract interface and checks the requested function access levels. Unsupported or malformed API payloads fail closed.

The `--api-base-url` option exists for deterministic local HTTP tests and controlled mirrors. Do not use a non-Hiro endpoint for production acceptance unless the operator records that exception and independently establishes equivalent canonical evidence.

## 5. Testnet proof

The active `scripts/deploy-testnet.ts` helper is bounded to testnet and the existing sequence. It:

- Verifies that `SYSTEM_ADDRESS` matches the supplied `DEPLOYER_PRIVKEY` without printing the key.
- Uses the corrected `contracts/treasury/revenue-automation.clar` path.
- Uses deny-mode post conditions.
- Stops on the first publish failure.
- Writes a broadcast-only candidate as `<evidence>.broadcast.json`.
- Polls with a bounded timeout and writes the confirmed evidence file only after canonical transaction and interface verification.
- Never prints a completion message from broadcast-only results.

Required environment variables are `DEPLOYER_PRIVKEY`, `SYSTEM_ADDRESS`, and, when git metadata is unavailable, `SOURCE_COMMIT`. Optional controls are `CORE_API_URL`, `HIRO_API_KEY`, `DEPLOYMENT_PLAN_PATH`, `DEPLOYMENT_EVIDENCE_PATH`, `DEPLOY_CONFIRM_TIMEOUT_MS`, and `DEPLOY_CONFIRM_POLL_MS`.

Do not treat an existing interface at a checked address as proof that this run published the contract. The helper records such contracts as pre-existing and requires at least one new publication before it can produce a confirmed deployment bundle.

## 6. Mainnet human gate

Mainnet remains manual only:

1. Keep `dry_run=true` unless the operator is ready for a real release.
2. Supply the exact confirmation string `DEPLOY_MAINNET`.
3. Use the protected `mainnet` GitHub environment and its required reviewers.
4. Confirm that the committed plan digest, network, source commit, and deployer identity are the approved values.
5. Provide a real evidence bundle to the workflow's evidence step. If the deployment tool did not produce one, the workflow must fail; do not create placeholder txids or call logs proof.

There is no testnet-to-mainnet promotion job. A testnet result never authorizes a mainnet run.

## 7. API and read-only checks

For each transaction, retain the verifier's sanitized API evidence:

- txid and API observation timestamp;
- successful status, `canonical: true`, and `isUnanchored: false`;
- transaction type and expected contract/function;
- sender address;
- Stacks block hash/height and burn-block hash/height;
- optional block timestamps.

For each checked contract, retain:

- the exact interface endpoint and observation timestamp;
- HTTP 200;
- the function inventory and access classification;
- confirmation that every required `public` or `read_only` function is present.

Configuration calls are verified as `contract-call` transactions. A workflow summary or read-only smoke test without these API records is not acceptance evidence.

## 8. Correction, pause, and recovery

### Before broadcast

Stop on any mismatch in plan hash, source commit, network, deployer, contract path, or expected identity. Correct the artifact and re-run preflight. Do not bypass a gate by editing a report or summary.

### Pending, aborted, or noncanonical transaction

Pause the sequence. Do not rebroadcast the same nonce or assume that a pending tx will succeed. Preserve the broadcast candidate, API responses/statuses, and timestamps. The bounded poller may retry transient absence/pending/interface availability, but it ultimately fails closed.

### Published immutable contract

A published Clarity contract cannot be rolled back or deleted from the chain. A correction requires an explicitly reviewed forward deployment under a new contract identity, followed by approved registry/configuration changes. Never overwrite evidence to make the immutable publication appear corrected.

### Partial deployment or settlement

Record exactly which publications and calls are confirmed, pending, failed, or pre-existing. Pause dependent configuration until the dependency graph is repaired. Any recovery of partial settlement must preserve debt, claim, and settlement state; do not silently erase obligations or invent partnership fee treatment. Resume forward only from an approved plan revision with a new source commit and plan hash.

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
