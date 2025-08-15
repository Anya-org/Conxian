#!/usr/bin/env bash
set -euo pipefail

# Claim vested creator tokens (stub/guidance).
# This script checks for a vesting contract presence and provides guidance.
# Env:
#  - STACKS_API_BASE (default https://api.testnet.hiro.so)
#  - VESTING_CONTRACT_ADDR (SP... or ST...)
#  - VESTING_CONTRACT_NAME (e.g., vesting)
#  - BENEFICIARY (principal of creator)
#  - HIRO_API_KEY (optional), HIRO_API_HEADER (default "Authorization: Bearer")

STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}

if [[ -z "${VESTING_CONTRACT_ADDR:-}" || -z "${VESTING_CONTRACT_NAME:-}" ]]; then
  cat <<'EOF'
[AutoVault] Creator vesting contract not configured.
Provide env vars and re-run:
  export VESTING_CONTRACT_ADDR=SP...
  export VESTING_CONTRACT_NAME=vesting
  export BENEFICIARY=SP...
Then this script will fetch the ABI and show claim methods.
EOF
  exit 0
fi

ABI_URL="$STACKS_API_BASE/v2/contracts/interface/$VESTING_CONTRACT_ADDR/$VESTING_CONTRACT_NAME"
echo "==> Fetching ABI: $ABI_URL"
curl -s "$ABI_URL" | jq '.trait || .functions | map({name, access})' || true

cat <<EOF

Next steps to claim (manual, as signing is required client-side):
  1) Identify the claim function in the ABI (e.g., 'claim' or 'claim-available').
  2) Use stacks.js or your wallet to assemble and sign a contract-call tx to:
       $VESTING_CONTRACT_ADDR.$VESTING_CONTRACT_NAME::<claim_function>
     with arguments: (beneficiary: principal = ${BENEFICIARY:-<your-principal>}) and any epoch/amount if required.
  3) Broadcast the signed tx via scripts/broadcast-tx.sh or directly to /v2/transactions.

Tip: Use scripts/get-abi.sh and scripts/api.md examples for signing/broadcasting.
EOF
