#!/usr/bin/env bash
# Read-only compatibility entrypoint for knowledge-base verification.
# Usage: scripts/kb-sync.sh [--dry-run]

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/kb-sync.sh [--dry-run]

Runs the authoritative local documentation and knowledge-base checks. The
--dry-run flag is retained for compatibility; all supported modes are read-only.
This script never edits files, fetches, commits, pushes, labels issues, or
mutates GitHub.
EOF
}

case "${1:-}" in
  ""|--dry-run)
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  --commit)
    echo "kb-sync.sh is read-only; --commit is no longer supported." >&2
    exit 2
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

REPO="Conxian/Conxian"

echo "=== Conxian Knowledge Verification (read-only) ==="
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo

echo "[1/3] Verifying generated repository facts"
npm run verify:knowledge-base
echo

echo "[2/3] Validating documentation and knowledge JSON"
npm run validate:docs
echo

echo "[3/3] Optional live GitHub issue count"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  issue_count=$(gh issue list --repo "$REPO" --state open --limit 1000 --json number --jq 'length')
  echo "Open issues reported by GitHub: $issue_count"
  echo "Inspect labels live with: gh issue list --repo $REPO --state open --json number,title,labels"
else
  echo "Skipped: gh is unavailable or not authenticated."
fi
echo

if git diff --quiet && git diff --cached --quiet; then
  echo "Working tree diff: clean"
else
  echo "Working tree diff: local changes present (not modified by this script)"
fi

echo "Knowledge verification completed. No changes were made."
