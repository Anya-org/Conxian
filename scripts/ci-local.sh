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

echo "==> Resolving Clarinet binary"

# Prefer npx clarinet (from devDependency alias), fallback to repo bin/clarinet
CLARINET_CMD=""
if ( cd "$ROOT_DIR/stacks" && npx --yes clarinet --version >/dev/null 2>&1 ); then
  CLARINET_CMD="npx clarinet"
else
  if [ -x "$ROOT_DIR/bin/clarinet" ]; then
    CLARINET_CMD="$ROOT_DIR/bin/clarinet"
  else
    echo "ERROR: Could not resolve Clarinet binary via npx or $ROOT_DIR/bin/clarinet" >&2
    exit 1
  fi
fi

echo "==> Clarinet version"
if [ "$CLARINET_CMD" = "npx clarinet" ]; then
  VER=$(cd "$ROOT_DIR/stacks" && $CLARINET_CMD --version | awk '{print $2}')
else
  VER=$($CLARINET_CMD --version | awk '{print $2}')
fi
echo "Found Clarinet $VER (expected $CLARINET_VERSION)"
if [ "$VER" != "$CLARINET_VERSION" ]; then
  echo "ERROR: Expected Clarinet $CLARINET_VERSION but got $VER" >&2
  exit 1
fi

echo "==> clarinet check"
if [ "$CLARINET_CMD" = "npx clarinet" ]; then
  ( cd "$ROOT_DIR/stacks" && $CLARINET_CMD check )
else
  ( cd "$ROOT_DIR/stacks" && "$CLARINET_CMD" check )
fi

echo "==> npm test"
( cd "$ROOT_DIR/stacks" && npm test )

echo "✅ Local CI checks passed"
