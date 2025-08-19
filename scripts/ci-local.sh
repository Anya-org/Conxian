#!/usr/bin/env bash
set -euo pipefail

# Local CI runner mirroring .github/workflows/ci.yml critical gates
# Usage: ./scripts/ci-local.sh [CLARINET_VERSION]

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CLARINET_VERSION=${1:-3.5.0}

echo "==> npm ci (stacks)"
( cd "$ROOT_DIR/stacks" && npm ci --no-audit --no-fund )

echo "==> TypeScript typecheck (no emit)"
( cd "$ROOT_DIR/stacks" && npx tsc --noEmit )

echo "==> Clarinet version"
VER=$(cd "$ROOT_DIR/stacks" && npx --yes clarinet --version | awk '{print $2}')
echo "Found Clarinet $VER (expected $CLARINET_VERSION)"
if [ "$VER" != "$CLARINET_VERSION" ]; then
  echo "ERROR: Expected Clarinet $CLARINET_VERSION but got $VER" >&2
  exit 1
fi

echo "==> clarinet check"
( cd "$ROOT_DIR/stacks" && npx clarinet check )

echo "==> npm test"
( cd "$ROOT_DIR/stacks" && npm test )

echo "✅ Local CI checks passed"
