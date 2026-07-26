# Protocol-Fee Bootstrap Specification (Preflight Only)

This runbook specifies a future, approved bootstrap sequence for the canonical
collector and lending sources. It is not an executable release plan and does
not claim any address, deployment, activation, authorization, or custody.

## Placeholders

- `<NETWORK>`: approved target network.
- `<PUBLISH_ADMIN>`: signer-derived collector publish transaction sender.
- `<GOVERNANCE_CONTRACT>`: approved contract principal, not a wallet.
- `<ORCHESTRATOR_ASSET>` / `<MANAGER_ASSET>`: approved SIP-010 principals.
- `<FIXED_STREAM_ID>` / `<SCHEDULED_STREAM_ID>`: reviewed nonzero IDs.
- `<ACTIVATION_BURN_HEIGHT>`: separately approved scheduled-policy anchor.

Do not replace placeholders with guessed principals or heights.

## Required order

1. Verify the source commit, generated plan hash, dependency order, and clean
   preflight results. Plan/workflow success is not publication evidence.
2. Obtain structured receipts and live interfaces proving publication of
   `.operational-treasury`, `.protocol-fee-collector`, `.lending-manager`, and
   `.lending-orchestrator` under the approved signer-derived identity.
3. Initialize `.operational-treasury` through its guarded interface and record
   the successful receipt plus `is-initialized` readback.
4. From `<PUBLISH_ADMIN>`, call collector `set-governance` with
   `<GOVERNANCE_CONTRACT>`, then call collector `set-admin` with the approved
   admin contract. The collector has publish-time admin plus `set-admin`; it has
   no `initialize` entrypoint.
5. If approved, set `<ACTIVATION_BURN_HEIGHT>` before the first settlement.
   Record `get-schedule`; do not infer activation from publication.
6. Authorize `.lending-manager`, register `<SCHEDULED_STREAM_ID>` with
   `register-ft-stream`, and bind it through manager
   `set-protocol-fee-stream`. Verify policy `{rate-policy: u1, rate-bps: u0}`.
7. Authorize `.lending-orchestrator`, register `<FIXED_STREAM_ID>` with
   `register-ft-fixed-100-bps-stream`, and bind it through orchestrator
   `set-protocol-fee-stream`. Verify policy `{rate-policy: u2, rate-bps: u100}`
   and rate tuple `{rate-policy: u2, rate-bps: u100, phase: u4}`.
8. Verify each stream config source, asset, route, and active flag; verify local
   lending bindings; verify unauthorized and mismatched calls fail closed.
9. Only after separate operational approval, exercise a bounded transaction and
   correlate collector/source events by source, stream ID, settlement ID,
   policy, rate, phase, eligible base, and settled amount.

## Evidence checklist

- Approved change/release identifier and reviewer sign-off.
- Full source commit and exact plan SHA-256.
- Network and signer-derived caller identities.
- Canonical transaction receipts for every public call above.
- Post-call readbacks for treasury initialization, collector admin/governance,
  authorization, stream config, stream policy/rate, and lending bindings.
- For any settlement, exact custody transfer/balance-delta evidence and cleared
  pending callback state.

The checked-in deployment workflows remain preflight-only. This file adds no
active wiring to deployment plans and must not be cited as proof that bootstrap
or custody occurred.
