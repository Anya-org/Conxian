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

# The real batch-processor API rejects an 11-item list at the Clarity type
# boundary. Its test asserts that rejection, but clarinet-sdk still emits the
# expected runtime diagnostic on stderr. Match the test's stderr context and
# the complete diagnostic line so an unrelated batch-processor error cannot be
# hidden by a contract-name allowlist.
BATCH_BOUNDARY_CONTEXT='stderr | tests/transaction-batch-processor.test.ts > Transaction Batch Processor > rejects an eleven-item batch at the contract list boundary'
BATCH_BOUNDARY_DIAGNOSTIC_RE='^Error: Runtime error while interpreting [A-Z0-9]+[.]batch-processor$'

simnet_plan='deployments/default.simnet-plan.yaml'
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/conxian-tests.XXXXXX") || {
  echo "❌ Could not create a secure temporary directory" >&2
  exit 1
}
temp=$(mktemp "$temp_dir/vitest-output.XXXXXX") || {
  echo "❌ Could not create a secure test-output file" >&2
  rm -rf -- "$temp_dir"
  exit 1
}
canonical_plan=$(mktemp "$temp_dir/canonical-simnet-plan.XXXXXX") || {
  echo "❌ Could not create a secure canonical-plan snapshot" >&2
  rm -rf -- "$temp_dir"
  exit 1
}
snapshot_ready=0

cleanup() {
  local status=$?
  local cleanup_status=0

  if [ "$snapshot_ready" -eq 1 ]; then
    if ! cp -- "$canonical_plan" "$simnet_plan"; then
      echo "❌ Could not restore $simnet_plan from the canonical snapshot" >&2
      cleanup_status=1
    fi
  else
    echo "❌ No canonical snapshot was available for restoration" >&2
    cleanup_status=1
  fi
  if ! rm -rf -- "$temp_dir"; then
    echo "❌ Could not remove temporary test files" >&2
    cleanup_status=1
  fi

  if [ "$status" -eq 0 ] && [ "$cleanup_status" -ne 0 ]; then
    status=$cleanup_status
  fi
  exit "$status"
}
trap cleanup EXIT

# Clarinet may rewrite the checked-in plan during Simnet initialization. Keep a
# read-only snapshot for child tests and restore the worktree from it on exit.
cp -- "$simnet_plan" "$canonical_plan" || {
  echo "❌ Could not snapshot $simnet_plan" >&2
  exit 1
}
snapshot_ready=1
chmod 400 -- "$canonical_plan" || {
  echo "❌ Could not make the canonical plan snapshot read-only" >&2
  exit 1
}
export CONXIAN_CANONICAL_SIMNET_PLAN_PATH="$canonical_plan"

npx vitest run --config vitest.config.ts "$@" 2>&1 | tee "$temp"
pipeline_status=("${PIPESTATUS[@]}")
vitest_exit=${pipeline_status[0]}
tee_exit=${pipeline_status[1]}
if [ "$vitest_exit" -eq 0 ] && [ "$tee_exit" -ne 0 ]; then
  vitest_exit=$tee_exit
fi

total_errors=$(grep -cE '^Error: Runtime error while interpreting [^ ]+$' "$temp" || true)
known_errors=$(grep -cE "^Error: Runtime error while interpreting [^ ]+\.($ALLOWLIST)$" "$temp" || true)
expected_contexts=$(grep -Fc "$BATCH_BOUNDARY_CONTEXT" "$temp" || true)
expected_errors=$(awk \
  -v context="$BATCH_BOUNDARY_CONTEXT" \
  -v diagnostic_re="$BATCH_BOUNDARY_DIAGNOSTIC_RE" \
  '
    $0 == context {
      saw_context = 1
      next
    }
    saw_context {
      if ($0 ~ diagnostic_re) {
        count++
      }
      saw_context = 0
    }
    END { print count + 0 }
  ' "$temp")
new_errors=$((total_errors - known_errors - expected_errors))

echo ""
echo "---"
echo "vitest exit: $vitest_exit"
echo "runtime errors: $total_errors ($known_errors known, $expected_errors expected, $new_errors new)"

if [ "$expected_contexts" -gt 0 ]; then
  # Targeted runs that do not select the boundary test have no matching
  # context and must not be required to emit its expected diagnostic. When
  # the context is present, fail closed unless it pairs with exactly one
  # exact diagnostic; any additional diagnostic remains a new error below.
  if [ "$expected_contexts" -ne 1 ] || [ "$expected_errors" -ne 1 ]; then
    echo "❌ Expected exactly one 11-item batch boundary diagnostic with its test context"
    echo "   matching contexts: $expected_contexts"
    echo "   matching diagnostics: $expected_errors"
    exit 1
  fi
fi

if [ "$vitest_exit" -ne 0 ]; then
  echo "❌ Tests failed (vitest exit code: $vitest_exit)"
  exit $vitest_exit
fi

if [ "$new_errors" -gt 0 ]; then
  echo "❌ Tests had $new_errors unexpected runtime error(s)"
  grep -E '^Error: Runtime error while interpreting ' "$temp" || true
  exit 1
fi

if [ "$known_errors" -gt 0 ]; then
  echo "⚠️  $known_errors known benign runtime warning(s) — suppressed (clarinet-sdk bug)"
fi

if [ "$expected_errors" -gt 0 ]; then
  echo "ℹ️  $expected_errors expected contract-boundary rejection(s) — asserted by tests"
fi

echo "✅ All checks passed"
