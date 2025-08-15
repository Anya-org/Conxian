#!/usr/bin/env bash
set -euo pipefail

# Usage:
# TX_BIN=./out/signed_tx.bin ./scripts/broadcast-tx.sh
# Optional env:
# STACKS_API_BASE (default https://api.testnet.hiro.so)
# HIRO_API_KEY (optional)
# HIRO_API_HEADER (default "Authorization: Bearer")

STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}

: "${TX_BIN:?Set TX_BIN to path of signed transaction binary}"

URL="$STACKS_API_BASE/v2/transactions"

HDRS=( -H 'Content-Type: application/octet-stream' )
if [[ "${HIRO_API_KEY:-}" != "" ]]; then
  HDRS+=( -H "$HIRO_API_HEADER $HIRO_API_KEY" )
fi

curl -s -X POST "${HDRS[@]}" --data-binary @"$TX_BIN" "$URL"
