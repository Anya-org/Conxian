#!/usr/bin/env bash
# Run vitest and fail hard on unexpected WASM runtime errors.
# The clarinet-sdk WASM writes contract interpretation errors directly to fd 2
# at the WASI syscall level, bypassing Node.js stream hooks. We catch them here
# by scanning the combined output.
#
# Known benign errors (clarinet-sdk v3.21.0 bug): the plan generator and
# simnet init use different random seeds, causing plan mismatch and regeneration
# on every first initSimnet call. This produces non-fatal interpretation
# warnings for these 4 contracts. Contracts are valid (clarinet check passes)
# and all tests pass despite the warnings.
#   conxian-protocol, dex-factory, office-manager, mock-token
set -o pipefail

# Contracts with known benign runtime warnings
ALLOWLIST="conxian-protocol|dex-factory|office-manager|mock-token"

temp=$(mktemp)
trap "rm -f $temp deployments/default.simnet-plan.yaml.bak" EXIT

# Snapshot simnet plan to prevent corruption
cp deployments/default.simnet-plan.yaml deployments/default.simnet-plan.yaml.bak

npx vitest run --config vitest.config.ts "$@" 2>&1 | tee "$temp"
vitest_exit=${PIPESTATUS[0]}

# Restore simnet plan
cp deployments/default.simnet-plan.yaml.bak deployments/default.simnet-plan.yaml

total_errors=$(grep -c 'Runtime error while interpreting' "$temp" || true)
known_errors=$(grep -cE "Runtime error while interpreting [^ ]*\.($ALLOWLIST)" "$temp" || true)
new_errors=$((total_errors - known_errors))

echo ""
echo "---"
echo "vitest exit: $vitest_exit"
echo "runtime errors: $total_errors ($known_errors known, $new_errors new)"

if [ "$vitest_exit" -ne 0 ]; then
  echo "❌ Tests failed (vitest exit code: $vitest_exit)"
  exit $vitest_exit
fi

if [ "$new_errors" -gt 0 ]; then
  echo "❌ Tests had $new_errors unexpected runtime error(s)"
  grep -E 'Runtime error' "$temp" | grep -vE "\.($ALLOWLIST)" || true
  exit 1
fi

if [ "$known_errors" -gt 0 ]; then
  echo "⚠️  $known_errors known benign runtime warning(s) — suppressed (clarinet-sdk bug)"
fi

echo "✅ All checks passed"
