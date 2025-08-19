#!/usr/bin/env bash
set -euo pipefail

# Evaluate a GitHub PR locally and run CI-equivalent checks.
# Usage: ./scripts/evaluate-pr.sh <PR_NUMBER> [REMOTE]
# Requires: git, bash, jq (optional), Node 20 toolchain (for stacks)

if [ $# -lt 1 ]; then
  echo "Usage: $0 <PR_NUMBER> [REMOTE]" >&2
  exit 2
fi

PR_NUM=$1
REMOTE=${2:-origin}
BRANCH=pr-${PR_NUM}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

cleanup() {
  git rev-parse --verify "$BRANCH" >/dev/null 2>&1 && git branch -D "$BRANCH" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Fetching PR #$PR_NUM from $REMOTE"
set +e
# GitHub fetch patterns
git fetch "$REMOTE" "pull/$PR_NUM/head:$BRANCH"
FETCH_RC=$?
set -e
if [ $FETCH_RC -ne 0 ]; then
  echo "Fallback: fetching refs/pull/$PR_NUM/head"
  git fetch "$REMOTE" "refs/pull/$PR_NUM/head:$BRANCH"
fi

echo "==> Checking out $BRANCH"
git checkout -q "$BRANCH"

echo "==> Showing diffstat vs main"
git fetch "$REMOTE" main -q || true
git diff --stat "$REMOTE/main"..."$BRANCH"

# Run local CI
echo "\n==> Running local CI checks"
"$ROOT_DIR/scripts/ci-local.sh" 3.5.0

# Summarize
echo "\n=== PR Evaluation Summary ==="
echo "PR: #$PR_NUM"
echo "Branch: $BRANCH"
echo "Base: main (assumed; verify in GitHub UI)"
echo "Result: ✅ CI-equivalent checks passed locally"
echo "Next:"
echo "  * If this is an enhancement, retarget to 'enhancements' branch before merge."
echo "  * If production-only (bugfix/security/docs), keep base 'main'."
echo "  * Resolve conflicts in GitHub or rebase: git rebase $REMOTE/main && git push -f $REMOTE $BRANCH"
