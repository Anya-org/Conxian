#!/usr/bin/env bash
set -euo pipefail

# AutoVault verification helper
# - Runs Clarinet compile checks
# - Prints guided steps for local console and testnet verification

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STACKS_DIR="$ROOT_DIR/stacks"
CLARINET_BIN="$ROOT_DIR/bin/clarinet"

if [[ -x "$CLARINET_BIN" ]]; then
  CLARINET_CMD="$CLARINET_BIN"
else
  if command -v clarinet >/dev/null 2>&1; then
    CLARINET_CMD="clarinet"
  else
    echo "Error: Clarinet binary not found at $CLARINET_BIN and not on PATH." >&2
    echo "Install Clarinet or place the binary in bin/ (see stacks/README.md)." >&2
    exit 1
  fi
fi

pushd "$STACKS_DIR" >/dev/null

echo "==> clarinet --version"
"$CLARINET_CMD" --version || true

echo "==> clarinet check"
"$CLARINET_CMD" check

cat <<'EOF'

=====================================
Local console verification (Guided)
=====================================
From a new terminal:
  $ cd stacks
  $ clarinet console

In the console, run:
  ;; Mint mock tokens to yourself (tx-sender)
  (contract-call? .mock-ft mint tx-sender u1000000)
  ;; Approve the vault to pull tokens
  (contract-call? .mock-ft approve .vault u500000)
  ;; Deposit and check balance
  (contract-call? .vault deposit u100000)
  (contract-call? .vault get-balance tx-sender)
  ;; Withdraw and confirm
  (contract-call? .vault withdraw u20000)

Timelock governance flow:
  ;; Make timelock the admin
  (contract-call? .vault set-admin .timelock)
  ;; Queue pause
  (contract-call? .timelock queue-set-paused true)
  ;; Mine >= min-delay blocks
  (advance-chain-tip u20)
  ;; Execute pause
  (contract-call? .timelock execute-set-paused u0)
  ;; Verify paused
  (contract-call? .vault get-paused)

=====================================
Testnet read-only verification
=====================================
Set env and run the helper script:
  CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-total-balance ./scripts/call-read.sh

Examples:
  # Get vault fees
  CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-fees ./scripts/call-read.sh | jq

  # Get paused flag
  CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-paused ./scripts/call-read.sh | jq

  # Get user balance (principal arg)
  ARGS_JSON='["0x0b00000000000000000000000000000000000000000000000000000000000001"]' \
  CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-balance ./scripts/call-read.sh | jq

Notes:
- Replace SP... with your deployed contract address on testnet.
- For principal arguments, pass Clarity Value hex (use Clarinet console `(print <cv>)` to see hex).
EOF

popd >/dev/null

echo "Verification guidance printed above."
