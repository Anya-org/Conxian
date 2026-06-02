# BOS wallet control model (SAB-owned custody + DAO-aligned governance)

This document defines the canonical wallet-control model for BOS and related ConxianCSF system operations so automation stays **system-controlled** (SAB custody + contract principals) rather than **person-controlled**, with policy changes delegated to DAO-aligned governance (DAO = decentralized autonomous organization).

This repository is public. Under Zero Secret Egress (ZSE: no sensitive operational, strategy, or financial material in the active Git index), this doc:

- **does** define wallet classes, authority boundaries, and on-chain control paths
- **does not** include signer identities, key material, key-ceremony steps, or concrete wallet principals (those belong in the custody system of record outside Git; public-safe pointer stub: [`admin/SECRETS.md`](../admin/SECRETS.md))

## Canonical references

- SAB program and migration context: [docs/SAB_MIGRATION_CONTROL_PLANE.md](SAB_MIGRATION_CONTROL_PLANE.md)
- ConxianCSF launch gates + ALEX funding path: [docs/CSF_MAINNET_READINESS_GATE.md](CSF_MAINNET_READINESS_GATE.md)
- Custody system of record pointer (public-safe stub; system of record lives outside Git): [admin/SECRETS.md](../admin/SECRETS.md)

## Terms (used in this document)

- **BOS**: Conxian's Business Operations System (the orchestration/policy/evidence layer for system operations; see [README.md](../README.md)).
- **SAB**: Conxian Sovereign Autonomous Business (the governing entity for this repo; see [GOVERNANCE.md](../GOVERNANCE.md)).
- **ConxianCSF**: the Conxian Finance protocol system on Stacks (see [docs/CSF_MAINNET_READINESS_GATE.md](CSF_MAINNET_READINESS_GATE.md)).
- **DAO**: the ConxianCSF-aligned governance authority for policy changes, executed via `DAO_TIMELOCK`.
- **ALEX**: the ALEX protocol's Stacks smart contracts, used as an execution venue and launch funding path for ConxianCSF flows (see [docs/CSF_MAINNET_READINESS_GATE.md](CSF_MAINNET_READINESS_GATE.md)).
- **ZSE**: Zero Secret Egress, the public-repo operating constraint that keeps signer identities, key material, and concrete principals out of Git (see [docs/SAB_MIGRATION_CONTROL_PLANE.md](SAB_MIGRATION_CONTROL_PLANE.md)).

## Canonical model (stable)

### Core invariants (what must stay true)

1. **Wallet/enclave = signing authority (where a signature is required).** If a standard-principal transaction is broadcast, it must have been signed by the correct authority wallet/enclave. For contract principals, authority is enforced by on-chain access control.
2. **BOS = orchestration + policy enforcement + evidence capture.** BOS may build unsigned transactions, check policy, and record evidence, but it must not "be the signing key".
3. **ALEX = execution venue (on-chain).** Protocol deployment/funding/payout flows that depend on ALEX must treat ALEX contracts as the execution venue and on-chain source of truth (see [docs/CSF_MAINNET_READINESS_GATE.md](CSF_MAINNET_READINESS_GATE.md)).
4. **Custody lives in contract principals.** Treasury/vault balances should live in contract principals (vaults/treasuries), not in human wallets.
5. **No single personal wallet after handoff.** After the automation cutover stage, no launch-critical automation may depend on a single personal/bootstrap wallet.

### Current bootstrap constraint

Treat `BOOTSTRAP_OPERATOR_WALLET` as the **current bootstrap wallet** under operator control (see the custody system of record outside Git; public-safe pointer stub: [admin/SECRETS.md](../admin/SECRETS.md)).

Bootstrap use is allowed only for launch preparation and one-time initialization. It must not remain a durable deployer/admin/treasury/payout authority after handoff.

### Canonical wallet inventory (v1)

Naming convention: identifiers below are **wallet classes**. Concrete principals and signer sets are tracked in the custody system of record outside Git; public-safe pointer stub: [admin/SECRETS.md](../admin/SECRETS.md).

| Wallet / principal class | Type | Custody owner | Purpose | Recommended signer model | Spend / authority limits (policy) |
| --- | --- | --- | --- | --- | --- |
| `BOOTSTRAP_OPERATOR_WALLET` | Standard principal | Operator (temporary) | Bootstrap deploy + one-time init only | 1-of-1 (temporary) | Must not be treasury, payout source, or automation signer after handoff |
| `SAB_DEPLOYER_MULTISIG` | Standard principal | SAB | Contract deploys/upgrades; initial role/admin wiring; ownership transfers | Start 2-of-3, target 3-of-5 | Holds only deploy gas; no long-lived treasury custody |
| `SAB_BOS_EXECUTOR_KEY` | Standard principal (system-custodied) | SAB (system custody) | Non-human automation signer (keepers) | 1-of-1 (system key) | Gas-buffer only; only allowlisted operational calls; no admin/owner writes |
| `SAB_PAYOUT_MULTISIG` | Standard principal | SAB | Manual maintainer/bounty payouts | Prefer 3-of-5 (or 2-of-3 with strict caps) | Funded in small tranches; payouts disabled until payout enablement decision; no protocol fee custody |
| `SAB_EMERGENCY_PAUSE_MULTISIG` | Standard principal | SAB | Fast pause/isolation actions | 2-of-3 | Pause/isolate only; no treasury withdrawals |
| `SAB_EMERGENCY_RECOVERY_MULTISIG` | Standard principal | SAB (+ independent signer if possible) | Unpause, key rotation, role revokes, recovery actions | 3-of-5 | No routine ops; used only for incidents and recovery |
| `DAO_TIMELOCK` (e.g., `...timelock`) | Contract principal | DAO-aligned governance | Time-delayed execution controller for policy / high-risk changes | Queue/cancel: DAO authority; execute: permissionless | Minimum delay per governance policy; emergency is handled separately |
| `DAO_POLICY_AUTHORITY` | Standard principal or contract principal | DAO-aligned governance | Holds on-chain governance role(s) needed to queue/cancel timelock actions | 3-of-5 (recommended) | Policy-only: does not directly custody treasury assets |
| `PROTOCOL_VAULTS` (e.g., `...operational-treasury`, `...dao-treasury`, `...vaults.custody`) | Contract principals | System / DAO via contracts | Custody layer for fees/treasury/royalties | N/A | "Deny by default": withdrawals only via approved on-chain authority paths |

### Quorum note (3-of-5)

3-of-5 is the preferred end-state quorum for any SAB-held key that can (a) move meaningful value, or (b) change control-plane authority. If a 5-signer bench is not truly reachable, start with 2-of-3 and migrate to 3-of-5 once liveness is proven.

Splitting emergency into **fast pause** (2-of-3) vs **slow recovery** (3-of-5) is the main way to keep incident response fast without weakening the "no single person / no 2-person collusion" line.

### Control matrix (owner, purpose, signer model, allowed actions)

| Class | Owner | Allowed actions (canonical) | Not allowed |
| --- | --- | --- | --- |
| `BOOTSTRAP_OPERATOR_WALLET` | Operator (temporary) | Initial deployment and one-time initialization to create SAB/DAO control paths | Any ongoing automation signing; durable admin authority; durable treasury/payout custody |
| `SAB_DEPLOYER_MULTISIG` | SAB multisig | Deploy/upgrade contracts; transfer ownership away from bootstrap; set admin principals; grant/revoke roles during migration | Routine treasury spending; signing day-to-day keeper ops; discretionary payouts |
| `SAB_BOS_EXECUTOR_KEY` | SAB (system custody) | Keeper ops: epoch triggers, fee sweeps, reporting, explicitly allowlisted operational calls, and automated payments for approved Web3 SaaS subscriptions (e.g., Charmverse) and ZSE decentralized storage (e.g., Lit Protocol/IPFS). | Any admin/owner writes; any payout signing; acting as custody wallet |
| `SAB_PAYOUT_MULTISIG` | SAB multisig | Sign outbound maintainer/bounty payouts only after payout enablement evidence | Receiving protocol fee sweeps; acting as treasury vault; uncapped/discretionary payouts |
| `SAB_EMERGENCY_PAUSE_MULTISIG` | SAB multisig | Pause/isolate specific contracts or the protocol globally | Unpause; governance parameter changes; treasury withdrawals |
| `SAB_EMERGENCY_RECOVERY_MULTISIG` | SAB multisig | Unpause (after review); rotate/revoke executor keys; revoke compromised roles; restore safe configuration | Routine ops; policy changes outside timelock |
| `DAO_TIMELOCK` | DAO-aligned governance | Queue/cancel proposals via `DAO_POLICY_AUTHORITY`; execute matured proposals permissionlessly | Fast-path "instant" policy change (except separately defined emergency controls) |
| `DAO_POLICY_AUTHORITY` | DAO-aligned governance | Queue/cancel timelock proposals; set/rotate governance role holders | Direct custody withdrawals (should route via timelock + vault rules) |
| `PROTOCOL_VAULTS` | System / DAO via contracts | Custody + rules-based withdraw via timelock and narrowly scoped agent contracts | Direct spend by a standard principal without an on-chain approval path |

### Approval policy, spending limits, rollback authority (v1 defaults)

These are policy-level defaults; concrete numbers (caps, tranche sizes, delay windows) belong in the custody system of record outside Git; public-safe pointer stub: [admin/SECRETS.md](../admin/SECRETS.md).

- `SAB_DEPLOYER_MULTISIG`
  - Approval: only signs deploy/upgrade/admin-migration transactions that are linked to an approved change record (issue + commit/PR) and have a reviewed transaction plan.
  - Rollback: if a deploy/upgrade is faulty, rollback authority is (a) redeploying the last known good version and (b) restoring last known good role mappings (typically via timelock once Stage 4 is live).

- `SAB_BOS_EXECUTOR_KEY`
  - Spending limit: keep balance capped to a small, rotating gas buffer.
  - Approval: on-chain allowlists (and any keeper role grants) are updated only by `SAB_DEPLOYER_MULTISIG` during migration, then by `DAO_TIMELOCK` after Stage 4.
  - Rollback: revoke keeper role / rotate the key, then re-run automation from the last known good BOS state.

- `SAB_PAYOUT_MULTISIG`
  - Spending limit: funded in small tranches; enforce a per-tx cap and a rolling period cap.
  - Approval: payouts require quorum plus an auditable payout list (e.g., issue/PR references) before signing.
  - Rollback: pause further payouts (stop signing), then reconcile on-chain transfers against the approved payout list.

- `SAB_EMERGENCY_PAUSE_MULTISIG` / `SAB_EMERGENCY_RECOVERY_MULTISIG`
  - Emergency pause is allowed without timelock to stop the bleeding.
  - Unpause and recovery actions require the higher-quorum recovery authority plus a documented incident record.
  - Rollback: restore last known good configuration (roles, allowlists, timelock targets) and rotate any suspected-compromised keys.

### Governance boundary (SAB execution authority vs DAO policy authority)

This is the canonical boundary:

- **SAB execution authority** runs automation and operations **within** fixed permissions.
  - keeper/executor signing (`SAB_BOS_EXECUTOR_KEY`)
  - deploy/upgrade execution (`SAB_DEPLOYER_MULTISIG`) under explicit approval policy
  - emergency pause/recovery (split emergency model)

- **DAO policy authority** defines and changes the policy surface through `DAO_TIMELOCK`.
  - fees/splits/limits, admin rotations, and high-risk configuration changes
  - ability to replace/rotate **on-chain admin/role principals** via timelocked changes where supported (signer-set changes for SAB multisigs remain an off-chain custody process)

Operationally:

```
DAO policy
  -> queue/cancel proposals (DAO_POLICY_AUTHORITY)
  -> execute after delay (DAO_TIMELOCK, permissionless execute)
  -> changes roles/limits/admins inside contracts

SAB operations
  -> signs allowlisted operational calls (SAB_BOS_EXECUTOR_KEY)
  -> can pause/isolate immediately (SAB_EMERGENCY_PAUSE_MULTISIG)
  -> can recover / rotate keys with higher quorum (SAB_EMERGENCY_RECOVERY_MULTISIG)
```

### Staged migration protocol (bootstrap -> SAB custody -> DAO-aligned governance)

#### Stage 0 — Bootstrap allowed (now)

- `BOOTSTRAP_OPERATOR_WALLET` may deploy and initialize.
- No production automation may permanently assume the bootstrap key exists.

#### Stage 1 — Establish SAB custody (durable control plane)

- Create `SAB_DEPLOYER_MULTISIG`, `SAB_PAYOUT_MULTISIG`, `SAB_EMERGENCY_PAUSE_MULTISIG`, `SAB_EMERGENCY_RECOVERY_MULTISIG`.
- Provision `SAB_BOS_EXECUTOR_KEY` in system custody (enclave/HSM-equivalent) with a strict operational allowlist.
- Record signer set + quorum + recovery contacts in the custody system of record outside Git; public-safe pointer stub: [admin/SECRETS.md](../admin/SECRETS.md).

#### Stage 2 — Move admin/owner surfaces out of bootstrap

- Transfer contract-level `admin`/`contract-owner` variables away from bootstrap to SAB authorities (typically `SAB_DEPLOYER_MULTISIG` and the emergency model). Where timelock-gated governance is required, defer final transfer to `DAO_TIMELOCK` in Stage 4.
- Set `.conxian-access` owner + roles so:
  - governance policy changes are timelock-gated once `DAO_TIMELOCK` is live (Stage 4)
  - keeper/executor can perform allowlisted operational calls
  - emergency pause authority is distinct from deploy authority

#### Stage 3 — Automation cutover (hard requirement before broad launch)

- All BOS automation that signs transactions must use `SAB_BOS_EXECUTOR_KEY`.
- The bootstrap wallet must not be required for:
  - keeper runs
  - deployment control
  - treasury custody
  - payout signing

**Explicit rule:** after Stage 3, no launch-critical automation may depend on a single personal wallet.

#### Stage 4 — DAO alignment (policy control moves behind timelock)

- Configure `DAO_TIMELOCK` and set governance role holders (`DAO_POLICY_AUTHORITY`).
- Transfer policy-critical admin surfaces to timelock where supported.
- Leave SAB with execution + emergency, but remove unilateral policy mutation capability.

#### Stage 5 — Bootstrap decommission

- Remove bootstrap principal from allowlists/roles.
- Treat the bootstrap key as revoked for production.

### BOS initiation rules (what BOS may do without signing authority)

BOS may:

- compile and validate unsigned transaction payloads
- enforce policy checks (limits, allowlists, timelock status)
- create and store evidence (inputs, expected post-state, tx hashes once broadcast)
- submit signing requests to the correct authority wallet

BOS must not:

- hold or embed signing secrets
- broadcast unsigned or personally signed production transactions
- use bootstrap keys in any automated production path after Stage 3

## Current implementation status (as-of pinned contracts)

This section is intentionally mutable. Update it whenever the `Conxian/` submodule pin or runtime signing surfaces change.

### Authority surfaces that must migrate off personal/placeholder control (current pinned contracts)

This is the concrete "move into SAB/DAO control" checklist visible in the pinned `Conxian/contracts` set (paths relative to the `Conxian/` submodule):

- `contracts/core/conxian-access.clar`
  - `contract-owner` and `timelock-principal` must be set to the intended SAB/DAO authorities.
  - `grant-role`/`revoke-role` must be callable only by the intended admin authority.
- `contracts/governance/timelock.clar`
  - `admin` and `governance-contract` must not remain hardcoded placeholder principals.
- `contracts/core/operational-treasury.clar`
  - `contract-owner` must not remain a placeholder; withdraw paths must route through approved authorities.
- `contracts/core/ops-engine.clar`
  - `admin` must be moved to SAB/DAO authority; emergency pause must be bound to the emergency authority model.
- `contracts/agents/agent-treasury.clar`
  - `admin` must be moved to the intended authority.
- `contracts/treasury/cxd-treasury.clar`
  - `admin`, `agent-treasury-principal`, and `revenue-distributor-principal` must not remain placeholders.
- `contracts/security/*`
  - pause/circuit-breaker admin must map to `SAB_EMERGENCY_PAUSE_MULTISIG` / `SAB_EMERGENCY_RECOVERY_MULTISIG`.

### Runtime/automation surfaces in this repo

- `scripts/register-sbcs.ts` uses `STX_PRIVATE_KEY` for signing.
  - In production, that key must map to `SAB_BOS_EXECUTOR_KEY` or `SAB_DEPLOYER_MULTISIG` (depending on the action), never to a personal bootstrap key.

Note: the pinned contract set still contains placeholder/testnet principals (e.g., `ST...`) and some authorization checks that are not yet compatible with contract-mediated governance (timelock/agent contracts). Treat those as hard blockers to completing Stage 4 until remediated.

### Pre-launch verification checklist (authority-path / secret-ownership)

Before broad launch or payout enablement:

1. Verify which principal `STX_PRIVATE_KEY` currently corresponds to in every runtime that signs transactions.
2. Verify that principal is either:
   - the temporary bootstrap wallet (Stage 0 only), or
   - the intended SAB-controlled authority (Stages 3+)
3. Verify deploy / keeper / payout / emergency keys are not unintentionally shared.
4. Record last-rotation / replacement status for each production signing secret in the custody system of record outside Git; public-safe pointer stub: [admin/SECRETS.md](../admin/SECRETS.md).
