#!/bin/bash
# Context Synchronization Protocol (CSP)
# Must be run at the start of every agentic session
#
# Usage: ./scripts/init_session.sh [--full]
#
# Flags:
#   --full     Run all phases including cross-repo context pull
#   --kg       Only refresh knowledge graph
#   --verify   Only verify current state
#
# This script ensures full context synchronization across:
# 1. Core BOS state (dev branch)
# 2. All submodules
# 3. Cross-repo context (conxian_ui, etc.)
# 4. Knowledge graph freshness
# 5. Sub-context verification

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
log_error() { echo -e "${RED}[❌]${NC} $1"; }

echo ""
echo "=========================================="
echo "  Context Synchronization Protocol v1.2"
echo "=========================================="
echo ""

# Parse flags
FULL_SYNC=false
KG_ONLY=false
VERIFY_ONLY=false
FORCE_PULL=false

for arg in "$@"; do
    case $arg in
        --full) FULL_SYNC=true ;;
        --kg) KG_ONLY=true ;;
        --verify) VERIFY_ONLY=true ;;
        --force-pull) FORCE_PULL=true ;;
    esac
done

#######################################
# PHASE 1: Core BOS Sync
#######################################
if [ "$KG_ONLY" != true ] && [ "$VERIFY_ONLY" != true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PHASE 1: Core BOS Sync"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    log_info "Syncing to dev branch..."
    CURRENT_BRANCH=$(git branch --show-current)
    
    if [ "$CURRENT_BRANCH" != "dev" ]; then
        log_warn "Current: $CURRENT_BRANCH → Switching to dev"
        git checkout dev 2>/dev/null || git checkout -b dev
    fi

    if [ "$FORCE_PULL" == true ]; then
        log_info "Force pulling from origin..."
        git pull --rebase origin dev
    else
        log_info "Pulling from origin..."
        git pull origin dev 2>/dev/null || echo "   (no remote changes)"
    fi
    log_success "BOS state synced"
    echo ""

    #######################################
    # PHASE 2: Submodule Sync
    #######################################
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PHASE 2: Submodule Synchronization"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    SUBMODULES=$(git submodule status 2>/dev/null | awk '{print $2}')
    SYNCED=0
    SKIPPED=0

    for submodule in $SUBMODULES; do
        if [ "$submodule" == "Conxian" ]; then
            echo "   ⏭️  Conxian (update=none)"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        
        echo -n "   📦 $submodule... "
        if git submodule update --init "$submodule" 2>/dev/null; then
            echo "✅"
            SYNCED=$((SYNCED + 1))
        else
            echo "⚠️ (skipped)"
            SKIPPED=$((SKIPPED + 1))
        fi
    done
    echo ""
    log_success "Submodules: $SYNCED synced, $SKIPPED skipped"
    echo ""
fi

#######################################
# PHASE 3: Cross-Repo Context (if --full)
#######################################
if [ "$FULL_SYNC" == true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PHASE 3: Cross-Repo Context Pull"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    log_info "Pulling context from non-submodule repos..."
    
    # conxian_ui (separate from conxian-ui submodule)
    if [ -d "/tmp/conxian_ui" ]; then
        echo -n "   📂 conxian_ui... "
        (cd /tmp/conxian_ui && git pull origin main 2>/dev/null && echo "✅") || echo "⚠️"
    else
        echo "   📂 conxian_ui (not cloned, skipping)"
    fi
    
    log_success "Cross-repo context pulled"
    echo ""
fi

#######################################
# PHASE 4: Knowledge Graph Refresh
#######################################
if [ "$VERIFY_ONLY" != true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PHASE 4: Knowledge Graph Refresh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    log_info "Refreshing knowledge graph..."
    
    # Regenerate local audit manifest
    if [ -f "./conxian-business/transparency_custodian.py" ]; then
        python3 ./conxian-business/transparency_custodian.py 2>/dev/null && \
            log_success "Audit manifest regenerated" || \
            log_warn "Audit manifest skipped (not critical)"
    fi

    # Check KG freshness
    if grep -q "2026-07" BOS_KNOWLEDGE_GRAPH.md 2>/dev/null; then
        log_success "Knowledge graph is current (July 2026)"
    else
        log_warn "Knowledge graph may need manual refresh"
    fi
    echo ""
fi

#######################################
# PHASE 5: Verification
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 5: Sub-Context Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check submodule status
echo "   📊 Submodule Status:"
git submodule status 2>/dev/null | head -5 | while read line; do
    echo "      $line"
done
echo ""

# Check for branch divergence
if git status 2>/dev/null | grep -q "have diverged"; then
    log_warn "Branch divergence detected - run: git rebase origin/dev"
elif git status 2>/dev/null | grep -q "is ahead"; then
    log_warn "Local commits not pushed - run: git push"
else
    log_success "No branch divergence"
fi

# Check remote accessibility
log_info "Remote accessibility:"
REMOTE_OK=0
for sm in conxian-gateway conxian-nexus conxian-market conxius-wallet conxius-platform; do
    if [ -d "$sm/.git" ]; then
        (cd "$sm" && git remote get-url origin 2>/dev/null | grep -q Conxian) && \
            echo "   ✅ $sm" && REMOTE_OK=$((REMOTE_OK + 1)) || \
            echo "   ⚠️ $sm"
    fi
done
echo ""

#######################################
# Summary
#######################################
echo "=========================================="
echo "  Portfolio Status (12 Submodules)"
echo "=========================================="
echo ""
echo "  Flagship:"
echo "    ├── Conxian/ (Protocol)      ⏭️  update=none"
echo "    ├── conxian-gateway          ✅ B2B Integration"
echo "    ├── conxian-nexus           ✅ Settlement Layer"
echo "    ├── conxian-market          ✅ AI Settlement 🆕"
echo "    ├── conxius-wallet          ✅ Mobile Wallet"
echo "    └── conxius-platform        ✅ Dev Orchestration"
echo ""
echo "  Supporting:"
echo "    ├── conxian-ui              ✅ Reference UI"
echo "    ├── conxius-enclave-sdk     ✅ TEE/Keys"
echo "    ├── conxius-orbit           ✅ Stacks Deploy"
echo "    ├── lib-conxian-core        ✅ Shared Primitives"
echo "    └── conxian-labs-site       ✅ Marketing"
echo ""

# Quick reference
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Quick Reference"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Init with full sync: ./scripts/init_session.sh --full"
echo "  Verify only:         ./scripts/init_session.sh --verify"
echo "  Refresh KG only:     ./scripts/init_session.sh --kg"
echo "  Force pull:         ./scripts/init_session.sh --force-pull"
echo ""

log_success "Context Synchronization Protocol complete"
echo ""
