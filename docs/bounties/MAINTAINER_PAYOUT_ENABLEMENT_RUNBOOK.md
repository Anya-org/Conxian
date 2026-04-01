# Maintainer runbook: bounty payout enablement (ALEX-funded)

This is a maintainer-only checklist for enabling bounty payouts after ConxianCSF mainnet launch.

## Definitions

- **Payout-ready mode**: Maintainers have approved the program to begin sending bounty payments to contributors.
- **ALEX launch funding source (sole allowed source)**: `SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-vault-v2-01`.
- **Payout wallet**: The internal maintainer-controlled wallet/multisig that sends bounty payments.

This runbook assumes **Stacks mainnet**. If you see any principal starting with `ST` (testnet), stop and reconcile your deployment record before proceeding.

## Mainnet identifiers (March 2026 release)

- **ConxianCSF mainnet deployer principal**: `CONXIAN_CSF_DEPLOYER` (must start with `SP`).
  - Source of truth: the commit-pinned deployment plan you actually executed (example path in this repo: [`Conxian/deployments/mainnet-release-plan.yaml`](../../Conxian/deployments/mainnet-release-plan.yaml)).
  - Set it as an environment variable (example: `export CONXIAN_CSF_DEPLOYER='SP...'`) and substitute it into contract identifiers below.
- **ALEX DEX factory contract**: `${CONXIAN_CSF_DEPLOYER}.dex-factory`.

## Payout enablement checklist (short)

### 1) Verify ConxianCSF full deployment on Stacks mainnet

1. Confirm the `alex-adapter` mainnet deployment batch ran as planned (see the mainnet release plan in this repo: [`Conxian/deployments/mainnet-release-plan.yaml`](../../Conxian/deployments/mainnet-release-plan.yaml)).
   - In the go/no-go record, include a GitHub permalink to the release plan pinned to the exact deployment commit (in GitHub UI: press `y` to generate a commit-pinned URL).
   - `contract-publish` succeeded for `alex-adapter`.
   - The follow-up `contract-call` succeeded:
     - contract: `${CONXIAN_CSF_DEPLOYER}.dex-factory`
     - method: `register-csf-protocol`
     - parameter: `${CONXIAN_CSF_DEPLOYER}.alex-adapter`
2. Confirm core contracts are present on mainnet and readable (minimum set; fully-qualified):
   - `${CONXIAN_CSF_DEPLOYER}.conxian-protocol`
   - `${CONXIAN_CSF_DEPLOYER}.cxd-token`
   - `${CONXIAN_CSF_DEPLOYER}.bme-engine`
   - `${CONXIAN_CSF_DEPLOYER}.cxd-treasury`
   - `${CONXIAN_CSF_DEPLOYER}.revenue-distributor`
   - `${CONXIAN_CSF_DEPLOYER}.ops-engine`
   - `${CONXIAN_CSF_DEPLOYER}.alex-adapter`
3. Confirm mainnet read-only health calls succeed and return sane values:
   - `${CONXIAN_CSF_DEPLOYER}.bme-engine/get-protocol-status` decodes to `compliant: true`.
   - `${CONXIAN_CSF_DEPLOYER}.ops-engine/get-protocol-status` decodes to `compliant: true`.
   - `${CONXIAN_CSF_DEPLOYER}.alex-adapter/get-csf-health` decodes to `is-active: true`.

#### How to run the read-only checks (reproducible)

- Use the Stacks API / explorer of choice, but always attach raw outputs.
- Minimum explorer sanity check: open `https://explorer.hiro.so/address/$CONXIAN_CSF_DEPLOYER?chain=mainnet` and confirm the expected contracts exist under the deployer principal.

CLI example (raw output + optional decode):

Prereqs: `curl` + `jq`. Optional decode step: `bun` + `@stacks/transactions`.

```bash
set -euo pipefail

API_BASE='https://api.mainnet.hiro.so'
: "${CONXIAN_CSF_DEPLOYER:?Set CONXIAN_CSF_DEPLOYER to the ConxianCSF deployer principal (SP...)}"

if [[ "$CONXIAN_CSF_DEPLOYER" != SP* ]]; then
  echo "NO-GO: CONXIAN_CSF_DEPLOYER must start with SP on mainnet" >&2
  exit 1
fi

SENDER="$CONXIAN_CSF_DEPLOYER"
OUT_DIR="$(mktemp -d)"
OUT_JSON="$OUT_DIR/bme-engine.get-protocol-status.json"

curl -fsS -X POST \
  "$API_BASE/v2/contracts/call-read/$CONXIAN_CSF_DEPLOYER/bme-engine/get-protocol-status" \
  -H 'Content-Type: application/json' \
  -d "{\"sender\":\"$SENDER\",\"arguments\":[]}" \
  | tee "$OUT_JSON" \
  | jq -e '.okay == true' >/dev/null

result="$(jq -r '.result' "$OUT_JSON")"
echo "Raw call-read response saved to: $OUT_JSON" >&2
echo "After decoding, manually confirm the payload reports the expected values (example: 'compliant: true')." >&2

if command -v bun >/dev/null 2>&1; then
  # Optional decode (requires @stacks/transactions available in your environment)
  bun -e 'import { hexToCV, cvToJSON } from "@stacks/transactions";
  const hex = process.argv[2];
  console.log(JSON.stringify(cvToJSON(hexToCV(hex)), null, 2));' \
    "$result" \
    || echo "Decode failed (missing @stacks/transactions?). Attach raw JSON output instead: $OUT_JSON" >&2
else
  echo "Skipping decode (bun not installed). Attach raw JSON output: $OUT_JSON" >&2
fi
```

**Evidence to attach to the go/no-go record**: txids for the deployment and registration step, plus the read-only call outputs.

### 2) Verify ALEX launch source of funds is active and is the sole bounty funding source

1. Verify the ALEX funding source principal is exactly:
   - `SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-vault-v2-01`
2. Verify the payout wallet received at least one inbound funding transfer from the ALEX vault principal.
3. Verify the payout wallet received no inbound bounty funding transfers from any other principal since mainnet launch.

For this checklist, treat any inbound STX transfer or SIP-010 fungible-token transfer to the payout wallet as bounty funding unless explicitly reconciled as unrelated and documented in the decision record.

**Definition: inbound bounty funding transfer**: any inbound STX transfer or SIP-010 fungible-token transfer whose `recipient` is the payout wallet.

#### Funding-source verification procedure (reproducible)

1. Set `PAYOUT_ADDRESS` to the payout wallet STX address.
2. Set `LAUNCH_BLOCK_HEIGHT` to the Stacks block height of the `alex-adapter` publish txid from Step 1.
3. Page through the payout wallet transfer history (via Hiro API) and ensure:
   - there is **at least one** inbound transfer to `PAYOUT_ADDRESS` whose `sender` is `ALEX_VAULT`
   - there are **zero** inbound transfers to `PAYOUT_ADDRESS` whose `sender` is not `ALEX_VAULT`

```bash
set -euo pipefail

API_BASE='https://api.mainnet.hiro.so'
ALEX_VAULT='SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-vault-v2-01'

: "${PAYOUT_ADDRESS:?Set PAYOUT_ADDRESS to the payout wallet STX address}"

# Stacks block height of the alex-adapter publish txid (ConxianCSF mainnet launch boundary)
: "${LAUNCH_BLOCK_HEIGHT:?Set LAUNCH_BLOCK_HEIGHT to an integer block height}"

OUT_DIR="${OUT_DIR:-$(mktemp -d)}"
ALEX_OUT="$OUT_DIR/payout-wallet.inbound-alex.tsv"
NON_ALEX_OUT="$OUT_DIR/payout-wallet.inbound-non-alex.tsv"
: > "$ALEX_OUT"
: > "$NON_ALEX_OUT"
prev_oldest=""

limit=50
offset=0

while :; do
  page="$(curl -fsS "$API_BASE/extended/v1/address/$PAYOUT_ADDRESS/transactions_with_transfers?limit=$limit&offset=$offset&order=desc")"
  n="$(echo "$page" | jq '.results | length')"
  [ "$n" -eq 0 ] && break

  echo "$page" | jq -r --arg addr "$PAYOUT_ADDRESS" --arg alex "$ALEX_VAULT" --argjson launch "$LAUNCH_BLOCK_HEIGHT" '
    .results[] as $r
    | select($r.tx.block_height >= $launch)
    | (
        ($r.stx_transfers[]? | select(.recipient == $addr and .sender == $alex) | [$r.tx.tx_id, "stx", .sender, .amount])
        ,($r.ft_transfers[]? | select(.recipient == $addr and .sender == $alex) | [$r.tx.tx_id, "ft", .sender, .asset_identifier, .amount])
      )
    | @tsv
  ' >> "$ALEX_OUT"

  # Any output here is candidate non-ALEX inbound bounty funding.
  # Treat as NO-GO unless you can fully reconcile it as unrelated and document that reconciliation in the decision record.
  echo "$page" | jq -r --arg addr "$PAYOUT_ADDRESS" --arg alex "$ALEX_VAULT" --argjson launch "$LAUNCH_BLOCK_HEIGHT" '
    .results[] as $r
    | select($r.tx.block_height >= $launch)
    | (
        ($r.stx_transfers[]? | select(.recipient == $addr and .sender != $alex) | [$r.tx.tx_id, "stx", .sender, .amount])
        ,($r.ft_transfers[]? | select(.recipient == $addr and .sender != $alex) | [$r.tx.tx_id, "ft", .sender, .asset_identifier, .amount])
      )
    | @tsv
  ' >> "$NON_ALEX_OUT"

  oldest="$(echo "$page" | jq '.results | last.tx.block_height')"
  if [ -n "$prev_oldest" ] && [ "$oldest" -gt "$prev_oldest" ]; then
    echo "Unexpected API ordering: block_height increased between pages" >&2
    exit 1
  fi
  prev_oldest="$oldest"
  if [ "$oldest" -lt "$LAUNCH_BLOCK_HEIGHT" ]; then
    break
  fi

  offset=$((offset+limit))
done

echo 'ALEX inbound funding transfers (since launch):'
cat "$ALEX_OUT"
if [ ! -s "$ALEX_OUT" ]; then
  echo 'NO-GO: no inbound funding transfer from ALEX vault since launch' >&2
  exit 1
fi

if [ -s "$NON_ALEX_OUT" ]; then
  echo 'Non-ALEX inbound transfers (since launch):'
  cat "$NON_ALEX_OUT"
  echo 'NO-GO: non-ALEX inbound transfers present (must reconcile before proceeding)' >&2
  exit 1
fi

echo "Artifacts written under: $OUT_DIR" >&2
```

Treat any non-ALEX inbound bounty funding transfer as **NO-GO** unless explicitly reconciled as unrelated and documented in the decision record.

**Evidence to attach**: a short list of inbound funding txids to the payout wallet (last N transfers) with senders.

### 3) Verify signer / wallet ownership / approval controls (internal)

1. Confirm the payout wallet is controlled by maintainers (multisig or equivalent) and the signer set matches the internal custody record.
2. Confirm the minimum approval policy for bounty payouts is configured (example: 2-of-3 maintainers).
3. Confirm the incident owner (single human) is assigned for payout enablement week (who can make the stop decision immediately).

**Evidence to attach**: internal signoff record (no keys), signer set summary, and the incident owner name.

### 4) Verify post-deploy checks completed successfully

1. Confirm the last on-chain upgrade/deploy window is closed (no pending contract publishes or admin migrations).
2. Do not run state-changing "smoke calls" as part of payout enablement.
   - Prefer read-only checks (Step 1 health calls, plus `${CONXIAN_CSF_DEPLOYER}.ops-engine/get-engine-status`).
3. Confirm monitoring is live for:
   - `${CONXIAN_CSF_DEPLOYER}.ops-engine/get-engine-status` (last action advancing)
   - inbound transfers to the payout wallet
   - outbound transfers from the payout wallet

**Evidence to attach**: read-only outputs for `${CONXIAN_CSF_DEPLOYER}.ops-engine/get-engine-status`, plus monitoring links or screenshots.

### 5) Verify contributor-facing messaging is still non-payout before payout-ready is declared

Before enablement, contributor-facing copy must clearly state:

> Your submission/claim has been recorded, but payouts are not active yet. Do not treat any issue thread as payout-ready unless maintainers explicitly declare payout-ready mode.

## Maintainer-only go/no-go decision

**GO** only if all checklist sections 1–5 are complete and evidence is attached.

**NO-GO** if any of the following is true:

- The payout wallet has any non-ALEX inbound bounty funding transfers.
- `${CONXIAN_CSF_DEPLOYER}.alex-adapter/get-csf-health` is not active.
- Any of the core read-only health checks fail.
- No incident owner is assigned.

## Maintainer action: declare payout-ready

Payout-ready mode is operational-only: there is no on-chain or config toggle. Maintainers declare payout-ready mode via the decision record + announcement, then execute payouts manually from the payout wallet.

1. Create a maintainer-only decision record (internal) that includes:
   - the evidence items above
   - timestamp
   - 2 maintainer approvals
2. Post a short public announcement in the canonical bounty channel (GitHub issue / Linear) stating: "Payouts enabled" and the effective timestamp.
3. Begin processing payouts from the payout wallet according to the approval policy.

## Rollback: disable payouts (premature enablement or post-deploy issue)

### Immediate stop steps

1. Freeze outbound payments from the payout wallet (pause the signing flow; do not queue new transfers).
2. Post a public status update in the canonical bounty channel stating: "Payouts paused" and the effective timestamp.

### Funding-source containment

1. If the ALEX vault is no longer the sole funding source, treat this as a payout halt condition.
2. Reconcile inbound funding transfers and document the unexpected funding source(s) before resuming.

### Resume criteria

Resume only after:

- funding-source invariants are restored (ALEX vault is the sole inbound bounty funder)
- incident owner signs off that the triggering issue is resolved
- 2 maintainers re-approve payout-ready mode with updated evidence
