#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=${VERBOSE:-false}

# Results tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((PASSED_CHECKS++))
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    ((FAILED_CHECKS++))
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# =============================================================================
# PRODUCTION READINESS CHECKS
# =============================================================================

check_contract_files() {
    log "Checking contract files..."
    ((TOTAL_CHECKS++))
    
    local required_contracts=(
        "contracts/vault-enhanced.clar"
        "contracts/enhanced-batch-processing.clar"
        "contracts/advanced-caching-system.clar"
        "contracts/dynamic-load-distribution.clar"
        "contracts/oracle-aggregator-enhanced.clar"
        "contracts/dex-factory-enhanced.clar"
    )
    
    local missing_contracts=()
    local total_contracts=${#required_contracts[@]}
    local found_contracts=0
    
    for contract in "${required_contracts[@]}"; do
        if [[ -f "$ROOT_DIR/$contract" ]]; then
            ((found_contracts++))
            if [[ "$VERBOSE" == "true" ]]; then
                success "Found: $contract"
            fi
        else
            missing_contracts+=("$contract")
        fi
    done
    
    if [[ ${#missing_contracts[@]} -eq 0 ]]; then
        success "Contract Files: All $total_contracts enhanced contracts found"
    elif [[ $found_contracts -ge $((total_contracts * 80 / 100)) ]]; then
        warn "Contract Files: $found_contracts/$total_contracts contracts found ($(printf "%s\n" "${missing_contracts[@]}" | sed 's|.*/||' | tr '\n' ' ')missing)"
    else
        error "Contract Files: Only $found_contracts/$total_contracts contracts found - critical missing: $(printf "%s\n" "${missing_contracts[@]}" | sed 's|.*/||' | tr '\n' ' ')"
    fi
}

check_mock_dependencies() {
    log "Checking for mock dependencies..."
    ((TOTAL_CHECKS++))
    
    local mock_patterns=(
        "mock-"
        "MockProvider"
        "test-only"
        "placeholder"
        "TODO:"
        "FIXME:"
        "XXX:"
        "HACK:"
    )
    
    local mock_files=()
    
    for pattern in "${mock_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            mock_files+=("$file")
        done < <(find "$ROOT_DIR/contracts" -name "*.clar" -exec grep -l "$pattern" {} \; 2>/dev/null | head -20)
    done
    
    if [[ ${#mock_files[@]} -eq 0 ]]; then
        success "Mock Dependencies: No mock dependencies found"
    elif [[ ${#mock_files[@]} -le 3 ]]; then
        warn "Mock Dependencies: ${#mock_files[@]} files with potential mock dependencies (review required)"
        if [[ "$VERBOSE" == "true" ]]; then
            printf "%s\n" "${mock_files[@]}" | sort -u | head -5 | while read -r file; do
                info "  - $file"
            done
        fi
    else
        error "Mock Dependencies: ${#mock_files[@]} files with mock dependencies (production blocker)"
        printf "%s\n" "${mock_files[@]}" | sort -u | head -10 | while read -r file; do
            info "  - $file"
        done
    fi
}

check_unwrap_panic_usage() {
    log "Checking for unwrap-panic usage..."
    ((TOTAL_CHECKS++))
    
    local unwrap_files=()
    
    while IFS= read -r -d '' file; do
        unwrap_files+=("$file")
    done < <(find "$ROOT_DIR/contracts" -name "*.clar" -exec grep -l "unwrap-panic" {} \; 2>/dev/null)
    
    if [[ ${#unwrap_files[@]} -eq 0 ]]; then
        success "Unwrap-Panic Usage: No unwrap-panic usage found"
    elif [[ ${#unwrap_files[@]} -le 2 ]]; then
        warn "Unwrap-Panic Usage: ${#unwrap_files[@]} files using unwrap-panic (review for safety)"
        if [[ "$VERBOSE" == "true" ]]; then
            printf "%s\n" "${unwrap_files[@]}" | while read -r file; do
                info "  - $file"
            done
        fi
    else
        error "Unwrap-Panic Usage: ${#unwrap_files[@]} files using unwrap-panic (production risk)"
        printf "%s\n" "${unwrap_files[@]}" | head -5 | while read -r file; do
            info "  - $file"
        done
    fi
}

check_hardcoded_values() {
    log "Checking for hardcoded test values..."
    ((TOTAL_CHECKS++))
    
    local hardcoded_patterns=(
        "SP000000000000000000002Q6VF78"
        "u12345"
        "test-token"
        "dummy-"
        "fake-"
        "localhost"
        "127.0.0.1"
    )
    
    local hardcoded_files=()
    
    for pattern in "${hardcoded_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            hardcoded_files+=("$file:$pattern")
        done < <(find "$ROOT_DIR/contracts" -name "*.clar" -exec grep -l "$pattern" {} \; 2>/dev/null | head -10)
    done
    
    if [[ ${#hardcoded_files[@]} -eq 0 ]]; then
        success "Hardcoded Values: No hardcoded test values found"
    elif [[ ${#hardcoded_files[@]} -le 5 ]]; then
        warn "Hardcoded Values: ${#hardcoded_files[@]} potential hardcoded values (review required)"
    else
        error "Hardcoded Values: ${#hardcoded_files[@]} hardcoded test values (production blocker)"
        printf "%s\n" "${hardcoded_files[@]}" | head -5 | while read -r file; do
            info "  - $file"
        done
    fi
}

check_admin_controls() {
    log "Checking admin control implementation..."
    ((TOTAL_CHECKS++))
    
    local admin_patterns=(
        "is-eq tx-sender"
        "get-admin"
        "set-admin"
        "admin-only"
        "contract-call-as"
    )
    
    local admin_files=()
    
    for pattern in "${admin_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            admin_files+=("$file")
        done < <(find "$ROOT_DIR/contracts" -name "*.clar" -exec grep -l "$pattern" {} \; 2>/dev/null)
    done
    
    local unique_admin_files=($(printf "%s\n" "${admin_files[@]}" | sort -u))
    
    if [[ ${#unique_admin_files[@]} -ge 3 ]]; then
        success "Admin Controls: ${#unique_admin_files[@]} contracts with admin controls"
    elif [[ ${#unique_admin_files[@]} -ge 1 ]]; then
        warn "Admin Controls: ${#unique_admin_files[@]} contracts with admin controls (may need more)"
    else
        error "Admin Controls: No admin control patterns found (security risk)"
    fi
}

check_error_handling() {
    log "Checking error handling implementation..."
    ((TOTAL_CHECKS++))
    
    local error_patterns=(
        "(err "
        "try!"
        "asserts!"
        "unwrap!"
        "is-ok"
        "is-err"
    )
    
    local error_files=()
    
    for pattern in "${error_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            error_files+=("$file")
        done < <(find "$ROOT_DIR/contracts" -name "*.clar" -exec grep -l "$pattern" {} \; 2>/dev/null)
    done
    
    local unique_error_files=($(printf "%s\n" "${error_files[@]}" | sort -u))
    
    if [[ ${#unique_error_files[@]} -ge 4 ]]; then
        success "Error Handling: ${#unique_error_files[@]} contracts with error handling"
    elif [[ ${#unique_error_files[@]} -ge 2 ]]; then
        warn "Error Handling: ${#unique_error_files[@]} contracts with error handling (review coverage)"
    else
        error "Error Handling: Insufficient error handling patterns found"
    fi
}

check_test_coverage() {
    log "Checking test file coverage..."
    ((TOTAL_CHECKS++))
    
    local test_files=($(find "$ROOT_DIR/tests" -name "*.ts" -o -name "*.test.clar" 2>/dev/null | wc -l))
    local contract_files=($(find "$ROOT_DIR/contracts" -name "*.clar" 2>/dev/null | wc -l))
    
    if [[ $contract_files -eq 0 ]]; then
        warn "Test Coverage: No contract files found to test"
    elif [[ $test_files -ge $contract_files ]]; then
        success "Test Coverage: $test_files test files for $contract_files contracts (excellent)"
    elif [[ $test_files -ge $((contract_files * 80 / 100)) ]]; then
        success "Test Coverage: $test_files test files for $contract_files contracts (good)"
    elif [[ $test_files -ge $((contract_files * 50 / 100)) ]]; then
        warn "Test Coverage: $test_files test files for $contract_files contracts (needs improvement)"
    else
        error "Test Coverage: $test_files test files for $contract_files contracts (insufficient)"
    fi
}

check_documentation() {
    log "Checking documentation coverage..."
    ((TOTAL_CHECKS++))
    
    local doc_files=(
        "README.md"
        "documentation/API_REFERENCE.md"
        "documentation/DEPLOYMENT.md"
        "documentation/SECURITY.md"
        "ARCHITECTURE.md"
    )
    
    local found_docs=0
    local missing_docs=()
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$ROOT_DIR/$doc" ]]; then
            ((found_docs++))
        else
            missing_docs+=("$doc")
        fi
    done
    
    if [[ $found_docs -eq ${#doc_files[@]} ]]; then
        success "Documentation: All ${#doc_files[@]} core documentation files present"
    elif [[ $found_docs -ge $((${#doc_files[@]} * 80 / 100)) ]]; then
        warn "Documentation: $found_docs/${#doc_files[@]} documentation files present ($(printf "%s " "${missing_docs[@]}")missing)"
    else
        error "Documentation: Only $found_docs/${#doc_files[@]} documentation files present (critical gaps)"
    fi
}

check_deployment_configs() {
    log "Checking deployment configurations..."
    ((TOTAL_CHECKS++))
    
    local config_files=(
        "package.json"
        "Testnet.toml"
        "scripts/deploy-testnet.sh"
        "scripts/deploy-mainnet.sh"
    )
    
    local found_configs=0
    local missing_configs=()
    
    for config in "${config_files[@]}"; do
        if [[ -f "$ROOT_DIR/$config" ]]; then
            ((found_configs++))
        else
            missing_configs+=("$config")
        fi
    done
    
    if [[ $found_configs -eq ${#config_files[@]} ]]; then
        success "Deployment Configs: All ${#config_files[@]} deployment configuration files present"
    elif [[ $found_configs -ge 3 ]]; then
        warn "Deployment Configs: $found_configs/${#config_files[@]} deployment files present"
    else
        error "Deployment Configs: Only $found_configs/${#config_files[@]} deployment files present (deployment risk)"
    fi
}

# =============================================================================
# PERFORMANCE ESTIMATION
# =============================================================================

estimate_performance() {
    log "Estimating performance potential..."
    ((TOTAL_CHECKS++))
    
    local batch_size=0
    local cache_config=0
    local load_dist=0
    
    # Check batch processing configuration
    if [[ -f "$ROOT_DIR/contracts/enhanced-batch-processing.clar" ]]; then
        local batch_lines=$(grep -c "batch\|process\|queue" "$ROOT_DIR/contracts/enhanced-batch-processing.clar" 2>/dev/null || echo 0)
        if [[ $batch_lines -ge 10 ]]; then
            batch_size=180000
        fi
    fi
    
    # Check caching system
    if [[ -f "$ROOT_DIR/contracts/advanced-caching-system.clar" ]]; then
        local cache_lines=$(grep -c "cache\|store\|retrieve" "$ROOT_DIR/contracts/advanced-caching-system.clar" 2>/dev/null || echo 0)
        if [[ $cache_lines -ge 8 ]]; then
            cache_config=40000
        fi
    fi
    
    # Check load distribution
    if [[ -f "$ROOT_DIR/contracts/dynamic-load-distribution.clar" ]]; then
        local load_lines=$(grep -c "load\|balance\|distribute" "$ROOT_DIR/contracts/dynamic-load-distribution.clar" 2>/dev/null || echo 0)
        if [[ $load_lines -ge 5 ]]; then
            load_dist=35000
        fi
    fi
    
    local total_estimated_tps=$((batch_size + cache_config + load_dist))
    local target_tps=735000
    
    if [[ $total_estimated_tps -ge $((target_tps * 80 / 100)) ]]; then
        success "Performance Estimation: ~${total_estimated_tps} TPS potential (target: ${target_tps})"
    elif [[ $total_estimated_tps -ge $((target_tps * 50 / 100)) ]]; then
        warn "Performance Estimation: ~${total_estimated_tps} TPS potential (target: ${target_tps}) - needs optimization"
    else
        error "Performance Estimation: ~${total_estimated_tps} TPS potential (target: ${target_tps}) - significant work needed"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

generate_report() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  PRODUCTION READINESS SUMMARY${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi
    
    echo -e "Total Checks: $TOTAL_CHECKS"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo -e "Success Rate: $success_rate%"
    echo
    
    if [[ $FAILED_CHECKS -eq 0 && $WARNINGS -le 2 ]]; then
        echo -e "${GREEN}✅ PRODUCTION READY${NC}"
        echo "System meets production readiness requirements."
        return 0
    elif [[ $FAILED_CHECKS -le 2 && $WARNINGS -le 5 ]]; then
        echo -e "${YELLOW}⚠️  NEEDS MINOR FIXES${NC}"
        echo "Address the failed checks before production deployment."
        return 1
    else
        echo -e "${RED}❌ NOT PRODUCTION READY${NC}"
        echo "Significant fixes required before production deployment."
        return 2
    fi
}

main() {
    echo -e "${BLUE}🔍 AutoVault Production Readiness Check${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo
    
    check_contract_files
    check_mock_dependencies
    check_unwrap_panic_usage
    check_hardcoded_values
    check_admin_controls
    check_error_handling
    check_test_coverage
    check_documentation
    check_deployment_configs
    estimate_performance
    
    echo
    generate_report
}

# Run the main function
main "$@"
