#!/usr/bin/env bash
# Run vitest and fail hard on WASM runtime errors.
# The clarinet-sdk WASM writes contract interpretation errors directly to fd 2
# at the WASI syscall level, bypassing Node.js stream hooks. We catch them here
# by scanning the combined output.
set -o pipefail

temp=$(mktemp)
trap "rm -f $temp" EXIT

npx vitest run --config vitest.config.ts "$@" 2>&1 | tee "$temp"
vitest_exit=${PIPESTATUS[0]}

runtime_errors=$(grep -c 'Runtime error while interpreting' "$temp" || true)

echo ""
echo "---"
echo "vitest exit: $vitest_exit"
echo "runtime errors: $runtime_errors"

if [ "$vitest_exit" -ne 0 ]; then
  echo "❌ Tests failed (vitest exit code: $vitest_exit)"
  exit $vitest_exit
fi

if [ "$runtime_errors" -gt 0 ]; then
  echo "❌ Tests had $runtime_errors runtime error(s) during contract interpretation"
  exit 1
fi

echo "✅ All checks passed"
