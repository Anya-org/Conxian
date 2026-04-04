Proposal-only external settlement triggers define how ISO 20022 / PAPSS / BRICS messages may enter the sovereign system.

## 1. Normative rules

1. **TradFi payloads are never execution authority**
   - A raw ISO 20022 / PAPSS / BRICS payload MUST NOT be consumed by any execution function.
   - Raw payloads MAY be parsed/normalized for audit and mapping.

2. **TEE verification is required before proposal emission**
   - A proposal MUST NOT be emitted unless a TEE/StrongBox/CloudTEE attestation verifies:
     - the payload digest,
     - the oracle authenticity proof,
     - and the deterministic mapping to `asset_path`.

3. **Timelock is mandatory**
   - Verified external triggers MUST initiate the standard 144-block timelock.
   - The start height MUST use the same canonical chain-height source used by the native path.

4. **Multi-sig approvals are mandatory**
   - Verified external triggers MUST enter the same multi-sig approval policy as native proposals.

5. **Yield routing invariance**
   - Downstream yield routing MUST be identical for native vs external-triggered lock events.
   - Trigger source MUST NOT change the 5/5/90 productive streaming behavior.

## 2. Required artifacts

### 2.1 `AttestedExternalSettlementTrigger`

Minimum fields:

- `rail`
- `raw_payload_hash`
- `trigger_id`
- `asset_path`
- `timelock_delay_blocks` (must equal `144`)
- `tee_attestation`
- `oracle_verification`

### 2.2 `SovereignProposal` (trigger-kind)

Minimum fields:

- `proposal_kind = EXTERNAL_SETTLEMENT_TRIGGER`
- `trigger_id`
- `asset_path`
- `timelock` (start + release heights)
- `approval_policy`

Prohibited fields:

- Any “call data” / executable contract payload that is derived from the raw TradFi bytes.

## 3. Negative test cases (must exist)

1. Missing or invalid TEE attestation → proposal emission fails.
2. Valid payload but invalid oracle proof → proposal emission fails.
3. Any attempt to supply raw TradFi payload to execution code → rejected at type boundary.
4. Any attempt to skip multi-sig approvals → rejected.
5. Any attempt to reduce timelock below 144 blocks → rejected.
