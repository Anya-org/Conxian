#!/usr/bin/env bash
set -euo pipefail

# Usage:
# CONTRACT_ADDR=SP... CONTRACT_NAME=vault ./scripts/get-abi.sh
# Optional:
# STACKS_API_BASE (default https://api.testnet.hiro.so)
# HIRO_API_KEY (optional)
# HIRO_API_HEADER (default "Authorization: Bearer")

STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}

: "${CONTRACT_ADDR:?Set CONTRACT_ADDR (e.g., SP...)}"
: "${CONTRACT_NAME:?Set CONTRACT_NAME (e.g., vault)}"

URL="$STACKS_API_BASE/v2/contracts/interface/$CONTRACT_ADDR/$CONTRACT_NAME"

HDRS=( )
if [[ "${HIRO_API_KEY:-}" != "" ]]; then
  HDRS+=( -H "$HIRO_API_HEADER $HIRO_API_KEY" )
fi

curl -s "${HDRS[@]}" "$URL"
