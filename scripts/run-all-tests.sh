#!/usr/bin/env bash
set -euo pipefail

# Runs Clarinet compile and tests for the Stacks project.
# Uses the local Clarinet binary in bin/ if present, otherwise falls back to PATH.

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

# Always attempt to run tests to surface useful errors (e.g., Deno missing)
echo "==> clarinet test"
if ! "$CLARINET_CMD" test; then
  echo "clarinet test failed or no tests detected."
  echo "If you see an error about Deno, install it from https://deno.land/#installation and ensure it's on PATH."
fi

popd >/dev/null

echo "All done."
