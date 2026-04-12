# Enterprise Control & Custody Baseline (CON-460)

This document defines the **minimum** enterprise/fintech baseline for custody and privileged control in the Conxian XaaP model.

Scope: this baseline applies to both enterprise and fintech deployments. A deployment may add stricter controls, but it MUST NOT relax any requirement in this document.

ZSE note: this is a public-safe spec. It intentionally avoids key-ceremony procedures, signer identities, concrete wallet principals, private endpoints, and other operational details.

Related references:

- Wallet classes and authority separation: `docs/BOS_WALLET_CONTROL_MODEL.md`
- Cross-unit change-control expectations: `docs/CROSS_UNIT_CHANGE_CONTROL.md`

## Terms

- **Privileged action**: any action that can move value, sign, rotate keys, modify policy, change identity/authorization, deploy/upgrade, or alter infrastructure control-plane settings.
- **Protected action**: a privileged action with an enforced policy/quorum boundary (for example: payments, treasury spends, key rotation, deploy/upgrade).
- **Agent**: any automation (LLM or non-LLM) that can request or perform actions.

Normative mapping: any privileged action that can move value, rotate keys, change identity/authorization, deploy/upgrade, or mutate production infrastructure control-plane MUST be implemented as a protected action under this baseline.

## 1) Key management baseline (custody)

- **Hardware-anchored keys**: signing keys MUST be held in an HSM/MPC/TEE-backed boundary (for example: StrongBox / enclave-class custody). Plaintext private keys MUST NOT exist in application containers, CI, or general-purpose agent runtimes.
- **Key separation**: payment, treasury, identity/admin, and deployment keys MUST be separate keys with separate policies and audit trails (no shared “root key”).
- **Quorum**: any key that can (a) move value above the policy-defined high-risk threshold or (b) mutate the control plane MUST require threshold approval (minimum 2-of-3; target 3-of-5 where liveness allows).
- **Fail-closed signing**: signing MUST fail closed if any of the following cannot be verified at request time:
  - policy version/hash
  - approval quorum and signer identities (as tracked by the custody system of record)
  - request integrity (tamper-evident payload hash)
  - freshness / replay protection (nonce, idempotency key, or equivalent)

## 2) Policy + approval controls (protected actions)

- **Policy is evaluated before signatures**: protected actions MUST not reach a signer boundary until policy checks pass.
- **Deterministic policy inputs**: policy evaluation MUST be deterministic over explicit inputs (request payload, actor identity, capability, policy hash/version, environment, and current approval state).
- **No “best effort” bypass**: if policy/quorum/authorization cannot be verified (provider outage, missing data, inconsistent state), protected actions MUST be blocked.
- **Separation of duties**: at least one approval step for value-bearing actions MUST be performed by an identity/capability that is not the requester.
- **Time-lock (baseline)**: high-risk actions (payments above the high-risk threshold, key rotations, deploy/upgrade) MUST enforce a minimum delay of 144 blocks on the asset’s settlement chain (for example: 144 Stacks L1 blocks for STX-settled flows). Policy MAY increase this delay but MUST NOT reduce or disable it for these flows. If the time-lock cannot be verified, the action MUST be blocked.

## 3) Capability boundaries for privileged tools/services

Conxian XaaP MUST implement explicit, least-privilege capability boundaries. A “privileged tool” is any service that can request or execute privileged actions.

Baseline requirements:

- **Capabilities are explicit**: privileged tools/services MUST be granted scoped capabilities (not blanket admin). Capabilities MUST be auditable and revocable.
- **No cross-domain tokens**: a credential that can initiate payments MUST NOT also be able to deploy, rotate keys, or modify authorization policy.
- **No single payment credential spans end-to-end execution**: in production, a credential/service principal MUST NOT hold more than one of {payment initiation, payment approval, payment signing/broadcast}.
- **Signer boundary is not a general API**: signing services MUST accept only well-typed, policy-linked signing requests (no arbitrary raw-sign endpoint).
- **Agents cannot self-expand privilege**: agents MUST NOT be able to mint/upgrade their own capabilities, modify their sandbox, or rewrite policy inputs.

Minimum capability domains to separate (non-exhaustive):

- payment initiation (request creation only)
- payment approval (quorum participant)
- payment signing/broadcast (execution)
- treasury allocation/funding (separate from payment execution)
- identity/authorization administration
- deployment/upgrade execution
- infrastructure operations (separate from identity)

## 4) Immutable identity + configuration assets (agent non-writable)

The following assets MUST be treated as immutable from the perspective of agents and routine automation (write access only via explicit, audited privileged workflows):

- **Identity roots**: enterprise IdP configuration, root service principals, and the authority that issues capability credentials.
- **Policy roots**: the policy source of truth and its versioned digest (for example: policy registry where every change is content-addressed).
- **Signing policy + key metadata**: key purpose bindings, allowed signing targets, and quorum definitions.
- **Audit roots**: audit log storage configuration and any tamper-evidence anchoring keys.
- **Control-plane roots**: deployment pipeline configuration, environment promotion gates, and production allowlists/deny-lists.

## 5) Sandbox requirements (workloads that touch keys/secrets/approval/deploy)

Any workload that touches keys, signing paths, secrets, approval logic, or deployment controls MUST run inside a hardened sandbox with:

- **No ambient credentials**: only short-lived, capability-scoped credentials; no long-lived tokens.
- **Ingress controls**: sandbox endpoints MUST NOT be directly exposed to public networks; only allowlisted orchestration layers or gateways may invoke them, under capability-scoped credentials.
- **Egress controls**: default-deny outbound network access except allowlisted dependencies required for policy verification.
- **Runtime isolation**: separate identity, file system, and process boundaries from general-purpose agents and application workloads.
- **No raw key material**: the sandbox MUST NOT have direct access to raw key material and may only call custody/HSM endpoints with well-typed, policy-linked signing requests.
- **Non-writable control plane**: the sandbox cannot mutate policy, identity roots, or deployment pipeline configuration. It may only invoke predefined, policy-guarded deployment operations via a narrow interface.
- **Tamper evidence**: sandbox execution MUST produce an append-only audit trail bound to the request idempotency key.

## 6) Deterministic approval + recovery state transitions

Protected workflows MUST be modeled as deterministic state machines with explicit terminal states. State transitions MUST be idempotent and replay-safe.

All payment initiation, approval, and signing/broadcast flows are protected actions and MUST follow this state model with fail-closed transitions.

All protected workflows (including payments, treasury, key management, identity/authorization changes, deployment/upgrade, and production infrastructure control-plane mutations) MUST either implement this state machine directly or map their internal states injectively onto this canonical set of states.

### 6.1 Privileged action state machine (generic)

```
CREATED
  -> POLICY_VALIDATED
    -> QUORUM_PENDING
      -> APPROVED
        -> EXECUTING
          -> COMPLETED

CREATED
  -> BLOCKED(policy)
  -> BLOCKED(auth)
  -> BLOCKED(verification)
  -> REJECTED(quorum)
  -> EXPIRED
  -> FAILED(execution)
```

Requirements:

- **Fail-closed transitions**: any transition that depends on external verification MUST transition to a blocked state (never “unknown, proceed anyway”) when verification is unavailable.
- **Terminal states are global**: `BLOCKED(...)`, `REJECTED(quorum)`, `EXPIRED`, and `FAILED(execution)` are terminal states that may be reached from any verification-dependent non-terminal state.
- **Deterministic approval set**: the set of approvals MUST be represented explicitly (who approved what, against which payload hash and policy hash).

### 6.2 Recovery state machine (key/capability recovery)

```
RECOVERY_REQUESTED
  -> IDENTITY_VERIFIED
    -> QUORUM_APPROVED
      -> ROTATION_EXECUTING
        -> ROTATION_COMPLETED

RECOVERY_REQUESTED
  -> REJECTED
  -> BLOCKED(verification)
  -> EXPIRED
  -> FAILED
```

Requirement:

- **Fail-closed recovery**: any recovery transition that depends on identity, custody, or quorum verification MUST transition to `BLOCKED(verification)` when verification is unavailable or inconsistent (never proceed on best-effort). The `FAILED` terminal state is reserved for execution errors that occur after verification has succeeded and rotation has begun.

## 7) Auditability requirements (attempted vs blocked vs completed)

Audit systems MUST be able to distinguish:

- **Attempted**: a privileged action was requested (even if it was blocked).
- **Blocked**: policy/quorum/auth checks failed or could not be verified.
- **Completed**: the privileged action executed and reached its defined post-state.

Minimum audit event types (names are illustrative; taxonomy is required):

- `PRIV_ACTION_ATTEMPTED`
- `PRIV_ACTION_BLOCKED`
- `PRIV_ACTION_APPROVED`
- `PRIV_ACTION_EXECUTION_STARTED`
- `PRIV_ACTION_COMPLETED`
- `PRIV_ACTION_FAILED`

Each privileged event MUST include:

- stable `request_id` / idempotency key
- actor identity + capability domain
- payload hash + policy hash/version
- approval set (or “none”)
- outcome + reason code (for blocked/failed)

Mapping requirements:

- entering `CREATED` MUST emit an attempted event (for example: `PRIV_ACTION_ATTEMPTED`)
- transitioning into `EXECUTING` MUST emit an execution-started event (for example: `PRIV_ACTION_EXECUTION_STARTED`)
- transitioning into `APPROVED` MUST emit an approved event (for example: `PRIV_ACTION_APPROVED`)
- transitioning into `COMPLETED` MUST emit a completed event (for example: `PRIV_ACTION_COMPLETED`)
- any transition into a `BLOCKED(...)` state MUST emit a blocked audit event (for example: `PRIV_ACTION_BLOCKED`)
- transitioning into `REJECTED(quorum)` MUST emit `PRIV_ACTION_BLOCKED` with a reason code that distinguishes quorum rejection
- transitioning into `EXPIRED` MUST emit `PRIV_ACTION_BLOCKED` with a reason code that distinguishes expiry
- `FAILED(execution)` MUST be reserved for execution errors after verification has succeeded

For recovery workflows, the same event taxonomy applies. At minimum:

- entering `RECOVERY_REQUESTED` MUST emit `PRIV_ACTION_ATTEMPTED`
- transitioning into `QUORUM_APPROVED` MUST emit `PRIV_ACTION_APPROVED`
- transitioning into `ROTATION_EXECUTING` MUST emit `PRIV_ACTION_EXECUTION_STARTED`
- transitioning into `ROTATION_COMPLETED` MUST emit `PRIV_ACTION_COMPLETED`
- transitions into `BLOCKED(verification)` MUST emit `PRIV_ACTION_BLOCKED`
- transitions into `FAILED` after verification MUST emit `PRIV_ACTION_FAILED`

Implementation note (public-safe): an append-only public audit manifest MAY be anchored to Stacks L1, while detailed logs are kept in an enterprise-controlled datastore, as long as both preserve the attempted/blocked/completed distinctions.

---
© 2026 Conxian-Labs (Pty) Ltd | Omphile Ndaloenhle Legacy Trust
