# Bitcoin/Lightning/Stacks Capability Ownership Matrix (M0)

## Status

Canonical M0 ownership lock for [#662](https://github.com/Conxian/conxian-business/issues/662), decomposed from [#638](https://github.com/Conxian/conxian-business/issues/638).

## Purpose

Freeze capability ownership for first-class layer support across:

- Bitcoin mainnet
- Lightning
- Stacks

This artifact is the owner-of-record baseline for M0.

## Canonical references

- Parent roadmap issue: [#638](https://github.com/Conxian/conxian-business/issues/638)
- M0 execution issue: [#662](https://github.com/Conxian/conxian-business/issues/662)
- Source-of-truth owner/readiness proposal: [#638 comment 4426922434](https://github.com/Conxian/conxian-business/issues/638#issuecomment-4426922434)
- Shared readiness gate checklist: [`docs/BITCOIN_LAYER_MAINNET_READINESS_GATE_CHECKLIST_M0.md`](./BITCOIN_LAYER_MAINNET_READINESS_GATE_CHECKLIST_M0.md)

## Capability ownership matrix (locked)

| Layer | Adapter owner | Signer owner | Verification owner | Simulation owner | Reference example owner |
| --- | --- | --- | --- | --- | --- |
| Bitcoin mainnet | `conxian-gateway` | `conxius-enclave-sdk` | `lib-conxian-core` (+ `conxian-nexus` integration) | `conxius-platform` | `conxius-wallet` |
| Lightning | `conxian-gateway` | `conxius-enclave-sdk` | `lib-conxian-core` (+ gateway/nexus settlement checks) | `conxius-platform` | `conxius-wallet` |
| Stacks | `conxian-gateway` | `conxius-enclave-sdk` | `lib-conxian-core` (+ `conxian-nexus` integration) | `conxius-platform` | `conxius-wallet` |

## Layer-specific readiness and recovery requirements

### Bitcoin mainnet

- Mainnet-readiness: adapter completeness closed; signer-controlled tx flow validated; verify/settle paths evidenced in the gate artifact; no simulated production path.
- Recovery: reorg replay, idempotent rebroadcast, signer rotation procedure, degraded-mode runbook.

### Lightning

- Mainnet-readiness: gateway-first Lightning adapter boundary enforced; production signer + verification path evidenced; integration suite included in release gates.
- Recovery: stuck-payment reconciliation, timeout handling, invoice/channel state reconciliation, credential rotation runbook.

### Stacks

- Mainnet-readiness: signer path standardized; verification evidence complete; deployment principal validation complete; fail-closed behavior enforced.
- Recovery: microblock/reorg reconciliation, pending transaction replay, rollback/containment runbook.

## Canonical Lightning boundary decision

Lightning is **gateway-first / gateway-owned adapter surface**.

Interpretation:

- Lightning adapter implementation ownership is in `conxian-gateway`.
- Shared interface and verification primitives remain in `lib-conxian-core`.
- Signer controls remain in `conxius-enclave-sdk` and are consumed through gateway-owned adapter flows.

For release gating implications, see: [`docs/BITCOIN_LAYER_MAINNET_READINESS_GATE_CHECKLIST_M0.md`](./BITCOIN_LAYER_MAINNET_READINESS_GATE_CHECKLIST_M0.md).
