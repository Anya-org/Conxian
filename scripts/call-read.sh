#!/usr/bin/env bash
set -euo pipefail

# Usage:
# CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-balance \
#   ARGS_JSON='["0x{cv-hex}"]' ./scripts/call-read.sh
#
# Optional env:
# STACKS_API_BASE (default https://api.testnet.hiro.so)
# HIRO_API_KEY (optional)
# HIRO_API_HEADER (default "Authorization: Bearer")
# SENDER (defaults to CONTRACT_ADDR)

STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}

: "${CONTRACT_ADDR:?Set CONTRACT_ADDR (e.g., SP...)}"
: "${CONTRACT_NAME:?Set CONTRACT_NAME (e.g., vault)}"
: "${FN:?Set FN (function name)}"

SENDER=${SENDER:-$CONTRACT_ADDR}
ARGS_JSON=${ARGS_JSON:-[]}

URL="$STACKS_API_BASE/v2/contracts/call-read/$CONTRACT_ADDR/$CONTRACT_NAME/$FN"

HDRS=( -H 'Content-Type: application/json' )
if [[ "${HIRO_API_KEY:-}" != "" ]]; then
  # shellcheck disable=SC2206
  HDRS+=( -H "$HIRO_API_HEADER $HIRO_API_KEY" )
fi

BODY=$(jq -cn --arg sender "$SENDER" --argjson args "$ARGS_JSON" '{sender: $sender, arguments: $args}')

curl -s -X POST "${HDRS[@]}" "$URL" -d "$BODY"
