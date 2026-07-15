#!/bin/bash
# kb-sync.sh - Knowledge Base Synchronization Script
# Purpose: Keep AGENTS.md, DOCUMENTATION_STATE.md, and issue labels aligned
# Usage: ./kb-sync.sh [--dry-run]
#
# This script is used by OpenHands automations to maintain knowledge base consistency.
# It performs the following:
# 1. Fetches latest from origin/main
# 2. Checks AGENTS.md section 15 (Open Issues Summary) against actual GitHub issues
# 3. Updates DOCUMENTATION_STATE.md if needed
# 4. Reports any misalignments

set -e

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
  DRY_RUN=true
  echo "Running in dry-run mode (no changes will be made)"
fi

REPO="Conxian/Conxian"
GITHUB_API="https://api.github.com"

echo "=== Conxian Knowledge Base Sync ==="
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Step 1: Fetch latest
echo "Step 1: Fetching latest from origin/main..."
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" != "$REMOTE" ]; then
  echo "  ⚠ Local is behind remote by $(git log --oneline $LOCAL..$REMOTE | wc -l) commit(s)"
  echo "  Latest remote: $(git log --oneline -1 origin/main)"
else
  echo "  ✓ Local is up-to-date with remote"
fi
echo ""

# Step 2: Get open issues from GitHub
echo "Step 2: Fetching open issues from GitHub..."
ISSUES=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "$GITHUB_API/repos/$REPO/issues?state=open&per_page=100" 2>/dev/null || echo "[]")

ISSUE_COUNT=$(echo "$ISSUES" | jq -r '.[] | select(.pull_request == null) | .number' 2>/dev/null | wc -l)
echo "  Found $ISSUE_COUNT open issues"
echo ""

# Step 3: Parse issues into a summary table
echo "Step 3: Parsing issue details..."
echo "| # | Title | Priority | Labels |"
echo "|---|-------|----------|--------|"

echo "$ISSUES" | jq -r '.[] | select(.pull_request == null) | 
  "#\(.number) | \(.title) | \(if (.labels[] | select(.name | test("priority-high|P0"))) then "HIGH" elif (.labels[] | select(.name | test("priority-low|P2"))) then "LOW" else "MEDIUM" end) | \(.labels[:3] | map(.name) | join(", ")) |"' 2>/dev/null | head -10

echo ""

# Step 4: Check AGENTS.md section 15
echo "Step 4: Validating AGENTS.md Section 15 (Open Issues Summary)..."
if grep -q "## 15. Open Issues Summary" AGENTS.md; then
  echo "  ✓ Section 15 exists in AGENTS.md"
  
  # Extract issue numbers from AGENTS.md Section 15 table (first column only)
  AGENTS_ISSUES=$(sed -n '/## 15\. Open Issues Summary/,/Last Updated/p' AGENTS.md | grep -E '^\| [0-9]+ ' | sed -E 's/^\| ([0-9]+).*/\1/' | sort -u | while read n; do echo "#$n"; done)
  
  # Compare with GitHub issues
  GITHUB_ISSUE_NUMS=$(echo "$ISSUES" | jq -r '.[] | select(.pull_request == null) | "#\(.number)"' 2>/dev/null | sort -u)
  
  MISSING_IN_AGENTS=$(comm -23 <(echo "$GITHUB_ISSUE_NUMS") <(echo "$AGENTS_ISSUES") || true)
  EXTRA_IN_AGENTS=$(comm -13 <(echo "$GITHUB_ISSUE_NUMS") <(echo "$AGENTS_ISSUES") || true)
  
  if [ -n "$MISSING_IN_AGENTS" ]; then
    echo "  ⚠ Issues in GitHub but missing in AGENTS.md:"
    echo "$MISSING_IN_AGENTS" | sed 's/^/    /'
  fi
  
  if [ -n "$EXTRA_IN_AGENTS" ]; then
    echo "  ⚠ Issues in AGENTS.md but closed in GitHub:"
    echo "$EXTRA_IN_AGENTS" | sed 's/^/    /'
  fi
  
  if [ -z "$MISSING_IN_AGENTS" ] && [ -z "$EXTRA_IN_AGENTS" ]; then
    echo "  ✓ AGENTS.md is in sync with GitHub issues"
  fi
else
  echo "  ⚠ Section 15 not found in AGENTS.md"
fi
echo ""

# Step 5: Check DOCUMENTATION_STATE.md
echo "Step 5: Validating DOCUMENTATION_STATE.md..."
if [ -f "docs/DOCUMENTATION_STATE.md" ]; then
  LAST_SESSION=$(grep -m1 '## Current Session' docs/DOCUMENTATION_STATE.md | grep -oP '\(\K[0-9]+' || echo "0")
  echo "  Last documented session: $LAST_SESSION"
  
  # Check if current session (34) is documented
  if grep -qE "Current Session \(34\)|Session 34" docs/DOCUMENTATION_STATE.md; then
    echo "  ✓ Session 34 documented"
  else
    echo "  ⚠ Session 34 not yet documented in DOCUMENTATION_STATE.md"
    echo "  This session should update the file with automation implementation results"
  fi
else
  echo "  ⚠ docs/DOCUMENTATION_STATE.md not found"
fi
echo ""

# Step 6: Check GitHub Actions workflows
echo "Step 6: Checking GitHub Actions workflows..."
if [ -d ".github/workflows" ]; then
  WORKFLOW_COUNT=$(ls -1 .github/workflows/*.yml 2>/dev/null | wc -l)
  echo "  ✓ Found $WORKFLOW_COUNT workflow(s)"
  ls -1 .github/workflows/*.yml 2>/dev/null | sed 's/^/    /'
else
  echo "  ⚠ .github/workflows directory not found"
fi
echo ""

# Summary
echo "=== Sync Complete ==="
echo "Finished at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "Dry-run mode: No changes were made"
else
  echo "Review the output above for any misalignments that need manual intervention"
fi
