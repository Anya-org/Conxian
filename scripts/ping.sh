#!/usr/bin/env bash
set -euo pipefail

# Simple connectivity check
# Optional env:
# STACKS_API_BASE (default https://api.testnet.hiro.so)
# HIRO_API_KEY (optional)
# HIRO_API_HEADER (default "Authorization: Bearer")

STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}

URL="$STACKS_API_BASE/v2/info"
HDRS=( )
if [[ "${HIRO_API_KEY:-}" != "" ]]; then
  HDRS+=( -H "$HIRO_API_HEADER $HIRO_API_KEY" )
fi

RESP=$(curl -s "${HDRS[@]}" "$URL")
if command -v jq >/dev/null 2>&1; then
  echo "$RESP" | jq .
else
  echo "$RESP"
fi
