#!/usr/bin/env bash
# AutoVault Minimal Static Check
# Purpose: Enforce convention that no new public/read-only function uses a raw `(chain-id uint)`
# parameter name (must be prefixed, e.g. `p-chain-id`). This targets the earlier
# NameAlreadyUsed("chain-id") compiler issue without over‑restricting generic names.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT_DIR="$ROOT_DIR/stacks/contracts"

FAIL_LINES=$(grep -R "(define-\(public\|read-only\)" -n "$CONTRACT_DIR" | grep "(chain-id uint)" || true)

if [ -n "$FAIL_LINES" ]; then
  echo "[ERROR] Found forbidden parameter pattern '(chain-id uint)' in the following lines:" >&2
  echo "$FAIL_LINES" >&2
  echo "Rename parameter to p-chain-id (or similar) to pass policy." >&2
  exit 1
fi

echo "Chain-id parameter naming check passed." >&2

# Optional strict mode (off by default)
# Enable by exporting AUTOVAULT_STRICT_PARAM_GUARD=1 in CI to scan for any parameter
# that exactly matches a data variable name (public & read-only functions).
if [ "${AUTOVAULT_STRICT_PARAM_GUARD:-0}" = "1" ]; then
  echo "Strict parameter shadow guard enabled (AUTOVAULT_STRICT_PARAM_GUARD=1)" >&2
  DATA_VARS=$(grep -R "(define-data-var" "$CONTRACT_DIR" | sed -E 's/.*\(define-data-var ([^ ]+) .*/\1/' | sort -u)
  FAIL=0
  while IFS= read -r line; do
    for VAR in $DATA_VARS; do
      if echo "$line" | grep -E "\(define-(public|read-only)" >/dev/null 2>&1; then
        if echo "$line" | grep -E "\(${VAR} (uint|int|bool|principal|string-ascii|string-utf8)" >/dev/null 2>&1; then
          # Allowlist some generic names that are acceptable operationally until refactor backlog tickets resolve
          case "$VAR" in
            token|enabled|lp-fee-bps|protocol-fee-bps|token-x|token-y) continue ;;
          esac
          echo "[STRICT][ERROR] Parameter '${VAR}' shadows data var in: $line" >&2
          FAIL=1
        fi
      fi
    done
  done < <(grep -R "(define-public" -n "$CONTRACT_DIR"; grep -R "(define-read-only" -n "$CONTRACT_DIR")
  if [ $FAIL -eq 1 ]; then
    echo "Strict mode failed. Resolve or add temporary allowlist entry with justification." >&2
    exit 1
  else
    echo "Strict parameter shadowing check passed." >&2
  fi
fi
