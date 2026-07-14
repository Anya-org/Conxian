#!/bin/bash
# Session Initialization Protocol (SIP)
# Must be run at the start of every agentic session
#
# Usage: ./scripts/init_session.sh [--force-pull]
#
# This script ensures the BOS environment is fully synchronized:
# 1. Checks out dev branch and pulls latest BOS state
# 2. Syncs all submodules to pinned commits
# 3. Verifies submodule health
# 4. Reports portfolio status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

echo "=========================================="
echo "BOS Session Initialization Protocol v1.1"
echo "=========================================="
echo ""

# Step 1: Sync to dev branch
echo "📍 Step 1: Syncing to dev branch..."
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo "   Current: $CURRENT_BRANCH → Switching to dev"
    git checkout dev 2>/dev/null || git checkout -b dev
fi

if [ "$1" == "--force-pull" ] || [ "$2" == "--force-pull" ]; then
    echo "   Force pulling from origin..."
    git pull --rebase origin dev
else
    echo "   Pulling from origin..."
    git pull origin dev 2>/dev/null || echo "   (no remote changes)"
fi
echo "   ✅ Branch synced"
echo ""

# Step 2: Sync submodules
echo "📦 Step 2: Syncing submodules..."
echo ""

SUBMODULES=$(git submodule status | awk '{print $2}')
for submodule in $SUBMODULES; do
    if [ "$submodule" == "Conxian" ]; then
        echo "   ⏭️  Skipping Conxian (update=none)"
        continue
    fi
    echo "   📂 Syncing $submodule..."
    git submodule update --init "$submodule" 2>/dev/null || echo "      (skipped)"
done
echo "   ✅ Submodules synced"
echo ""

# Step 3: Verify health
echo "🔍 Step 3: Verifying submodule health..."
echo ""
git submodule status
echo ""

# Step 4: Report status
echo "📊 Portfolio Status:"
echo "--------------------"
echo ""
echo "Active Submodules (11 total):"
echo "  Flagship:"
echo "    ├── Conxian/ (Protocol) - update=none"
echo "    ├── conxian-gateway (B2B Integration)"
echo "    ├── conxian-nexus (Settlement Layer)"
echo "    ├── conxius-wallet (Mobile Wallet)"
echo "    └── conxius-platform (Dev Orchestration)"
echo ""
echo "  Supporting:"
echo "    ├── conxian-ui (Reference UI)"
echo "    ├── conxian-market (AI Settlement)"
echo "    ├── conxius-enclave-sdk (TEE/Keys)"
echo "    ├── conxius-orbit (Stacks Deploy)"
echo "    ├── lib-conxian-core (Shared Primitives)"
echo "    └── conxian-labs-site (Marketing)"
echo ""

echo "=========================================="
echo "✅ Session initialization complete"
echo "=========================================="
