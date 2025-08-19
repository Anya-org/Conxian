#!/usr/bin/env bash
set -euo pipefail

# Runs Clarinet compile and tests for the Stacks project.
# Uses the project-pinned Clarinet SDK via npx.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STACKS_DIR="$ROOT_DIR/stacks"

pushd "$STACKS_DIR" >/dev/null

echo "==> npx clarinet --version"
npx clarinet --version || true

echo "==> npx clarinet check"
npx clarinet check

# Always attempt to run tests to surface useful errors (e.g., Deno missing)
echo "==> npx clarinet test"
if ! npx clarinet test; then
  echo "clarinet test failed or no tests detected."
  echo "If you see an error about Deno, install it from https://deno.land/#installation and ensure it's on PATH."
fi

popd >/dev/null

echo "All done."
