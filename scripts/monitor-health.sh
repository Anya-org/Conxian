#!/usr/bin/env bash
set -euo pipefail

# Monitor Conxian health via Hiro API and contract read-only calls.
# Requirements: curl, jq, and scripts/call-read.sh in this repo.
# Env:
#  - STACKS_API_BASE (default https://api.testnet.hiro.so)
#  - HIRO_API_KEY (optional) and HIRO_API_HEADER (default "Authorization: Bearer")
#  - CONTRACT_ADDR (preferred) or DEPLOYER_ADDRESS for event queries
#  - CONTRACT_NAME (default vault)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}
HIRO_API_HEADER=${HIRO_API_HEADER:-Authorization: Bearer}
CONTRACT_ADDR=${CONTRACT_ADDR:-${DEPLOYER_ADDRESS:-}}
CONTRACT_NAME=${CONTRACT_NAME:-vault}

if [[ -z "$CONTRACT_ADDR" ]]; then
  echo "Error: Set CONTRACT_ADDR (or DEPLOYER_ADDRESS)." >&2
  exit 1
fi

# Ping
echo "==> Ping: $STACKS_API_BASE/v2/info"
HDRS=( -H 'Content-Type: application/json' )
if [[ "${HIRO_API_KEY:-}" != "" ]]; then
  HDRS+=( -H "$HIRO_API_HEADER $HIRO_API_KEY" )
fi
curl -s "${HDRS[@]}" "$STACKS_API_BASE/v2/info" | jq '{network_id, burn_block_height, stacks_tip_height}'

# Recent events for the contract
EXT_BASE="$STACKS_API_BASE/extended/v1"
EVENTS_URL="$EXT_BASE/contract/${CONTRACT_ADDR}.${CONTRACT_NAME}/events?limit=20"
echo "==> Recent events: $EVENTS_URL"
curl -s "$EVENTS_URL" | jq '.results[] | {tx_id, event_index, event_type, contract_event: .contract_event | {topic, value}}' || true

# Read-only getters
CALL_READ="$ROOT_DIR/scripts/call-read.sh"

call_ro() {
  local fn="$1"
  CONTRACT_ADDR="$CONTRACT_ADDR" CONTRACT_NAME="$CONTRACT_NAME" FN="$fn" "$CALL_READ" | jq
}

echo "==> get-total-balance"
call_ro get-total-balance || true

echo "==> get-protocol-reserve"
call_ro get-protocol-reserve || true

echo "==> get-fees"
call_ro get-fees || true

echo "==> get-paused"
call_ro get-paused || true

echo "==> get-auto-fees-enabled (if present)"
call_ro get-auto-fees-enabled || true

echo "Health check complete."
