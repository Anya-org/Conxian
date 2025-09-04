#!/bin/bash

# Conxian Health Monitor Deployment Script
# Deploys health monitoring contract with network-aware alert routing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/scripts/common/logging.sh"
source "$PROJECT_ROOT/scripts/common/validation.sh"

# Configuration
HEALTH_CONTRACT="conxian-health-monitor"
TESTNET_CONFIG="$PROJECT_ROOT/Testnet.toml"

log_info "🏥 Starting Conxian Health Monitor Deployment"

# Check if we're in testnet or mainnet mode
NETWORK_TYPE="testnet"
DAO_CONTRACT=""

if [[ "${MAINNET_MODE:-false}" == "true" ]]; then
    NETWORK_TYPE="mainnet"
    DAO_CONTRACT="${DAO_GOVERNANCE_CONTRACT:-}"
    
    if [[ -z "$DAO_CONTRACT" ]]; then
        log_error "❌ DAO_GOVERNANCE_CONTRACT must be set for mainnet deployment"
        exit 1
    fi
fi

log_info "📊 Network: $NETWORK_TYPE"
log_info "🏛️  DAO Contract: ${DAO_CONTRACT:-"N/A (Testnet mode)"}"

# Deploy health monitoring contract
deploy_health_monitor() {
    log_info "🚀 Deploying health monitoring contract..."
    
    cd "$PROJECT_ROOT/stacks"
    
    # Check if contract exists
    if ! clarinet check --manifest-path "$TESTNET_CONFIG"; then
        log_error "❌ Contract validation failed"
        return 1
    fi
    
    # Deploy contract
    log_info "📄 Deploying $HEALTH_CONTRACT contract"
    
    if [[ "$NETWORK_TYPE" == "testnet" ]]; then
        clarinet deploy --network testnet "$HEALTH_CONTRACT" \
            --manifest-path "$TESTNET_CONFIG"
    else
        clarinet deploy --network mainnet "$HEALTH_CONTRACT" \
            --manifest-path "$PROJECT_ROOT/Clarinet.toml"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Health monitoring contract deployed successfully"
    else
        log_error "❌ Failed to deploy health monitoring contract"
        return 1
    fi
}

# Initialize health monitoring system
initialize_health_system() {
    log_info "⚙️  Initializing health monitoring system..."
    
    local dao_param="none"
    if [[ -n "$DAO_CONTRACT" ]]; then
        dao_param="(some '$DAO_CONTRACT)"
    fi
    
    # Call initialization function
    cat > /tmp/init_health.clar << EOF
(contract-call? .$HEALTH_CONTRACT initialize-health-monitoring $dao_param)
EOF
    
    clarinet console --manifest-path "$TESTNET_CONFIG" < /tmp/init_health.clar
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Health monitoring system initialized"
    else
        log_error "❌ Failed to initialize health monitoring system"
        return 1
    fi
    
    rm -f /tmp/init_health.clar
}

# Test health monitoring functionality
test_health_monitoring() {
    log_info "🧪 Testing health monitoring functionality..."
    
    # Test component health update
    cat > /tmp/test_health.clar << EOF
;; Test oracle health update
(contract-call? .$HEALTH_CONTRACT update-component-health
    "oracle-aggregator"
    u1500   ;; TPS
    u75     ;; Memory usage
    u2      ;; Error rate
    u150    ;; Response time
    u98)    ;; Success rate

;; Test Nakamoto performance monitoring
(contract-call? .$HEALTH_CONTRACT monitor-nakamoto-performance
    u12000  ;; Oracle TPS
    u55000  ;; SDK TPS
    u8000   ;; Factory TPS
    u10000  ;; Vault TPS
    u100    ;; Microblock confirmations
    u300)   ;; Bitcoin finality time
EOF
    
    clarinet console --manifest-path "$TESTNET_CONFIG" < /tmp/test_health.clar
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Health monitoring tests passed"
    else
        log_error "❌ Health monitoring tests failed"
        return 1
    fi
    
    rm -f /tmp/test_health.clar
}

# Verify alert routing configuration
verify_alert_routing() {
    log_info "🔔 Verifying alert routing configuration..."
    
    cat > /tmp/verify_alerts.clar << EOF
;; Get system health summary
(contract-call? .$HEALTH_CONTRACT get-system-health-summary)

;; Get network configuration
(contract-call? .$HEALTH_CONTRACT get-network-config)

;; Check notification targets
(contract-call? .$HEALTH_CONTRACT get-notification-target u1 u3) ;; Testnet, High severity
(contract-call? .$HEALTH_CONTRACT get-notification-target u2 u4) ;; Mainnet, Critical severity
EOF
    
    clarinet console --manifest-path "$TESTNET_CONFIG" < /tmp/verify_alerts.clar
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Alert routing configuration verified"
    else
        log_error "❌ Alert routing verification failed"
        return 1
    fi
    
    rm -f /tmp/verify_alerts.clar
}

# Generate deployment report
generate_deployment_report() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local report_file="$PROJECT_ROOT/health-monitor-deployment-$timestamp.md"
    
    cat > "$report_file" << EOF
# Conxian Health Monitor Deployment Report

**Deployment Date:** $(date)
**Network:** $NETWORK_TYPE
**Contract:** $HEALTH_CONTRACT

## Configuration

- **Network Type:** $NETWORK_TYPE
- **DAO Contract:** ${DAO_CONTRACT:-"N/A (Testnet mode)"}
- **Alert Routing:** $(if [[ "$NETWORK_TYPE" == "testnet" ]]; then echo "Deployer Wallet"; else echo "DAO Governance"; fi)

## Components Monitored

1. **Oracle Aggregator**
   - TPS Thresholds: Warning 1000, Critical 500
   - Memory Thresholds: Warning 85%, Critical 95%
   - Error Rate Thresholds: Warning 5%, Critical 10%

2. **DEX Factory**
   - TPS Thresholds: Warning 800, Critical 400
   - Memory Thresholds: Warning 80%, Critical 90%
   - Error Rate Thresholds: Warning 3%, Critical 8%

3. **Vault System**
   - TPS Thresholds: Warning 1200, Critical 600
   - Memory Thresholds: Warning 85%, Critical 95%
   - Error Rate Thresholds: Warning 2%, Critical 5%

4. **Nakamoto SDK**
   - TPS Thresholds: Warning 5000, Critical 2500
   - Memory Thresholds: Warning 90%, Critical 98%
   - Error Rate Thresholds: Warning 1%, Critical 3%

## Alert Severity Levels

- **SEVERITY_LOW (1):** Informational alerts
- **SEVERITY_MEDIUM (2):** Performance warnings
- **SEVERITY_HIGH (3):** High priority issues
- **SEVERITY_CRITICAL (4):** Critical system failures

## Notification Routing

### Testnet Mode
- All alerts sent to deployer wallet: \`$(clarinet accounts | head -1 | awk '{print $1}')\`
- Direct wallet notifications with urgency flags

### Mainnet Mode
- All alerts sent to DAO governance contract: \`$DAO_CONTRACT\`
- DAO proposal/alert system integration

## Health Monitoring Features

- ✅ Real-time component health tracking
- ✅ Nakamoto ultra-performance monitoring (50,000+ TPS)
- ✅ Network-aware alert routing
- ✅ Multi-severity alert system
- ✅ System health aggregation
- ✅ Alert acknowledgment and resolution
- ✅ Historical health data tracking

## Next Steps

1. Integrate with production monitoring dashboard
2. Configure webhook endpoints for external notifications
3. Set up automated health check scheduling
4. Implement alert escalation policies
5. Configure monitoring for mainnet migration

## Contract Functions

### Public Functions
- \`initialize-health-monitoring\`: Initialize system with DAO contract
- \`update-component-health\`: Update health metrics for components
- \`monitor-nakamoto-performance\`: Monitor Nakamoto-specific performance
- \`trigger-alert\`: Manually trigger alerts
- \`acknowledge-alert\`: Acknowledge active alerts
- \`resolve-alert\`: Mark alerts as resolved
- \`update-dao-contract\`: Update DAO contract for mainnet

### Read-Only Functions
- \`get-system-health-summary\`: Get overall system health
- \`get-component-health-status\`: Get specific component health
- \`get-alert-details\`: Get alert information
- \`get-network-config\`: Get current network configuration

## Deployment Status: ✅ SUCCESS

EOF

    log_success "📋 Deployment report generated: $report_file"
}

# Main deployment workflow
main() {
    log_info "🚀 Starting Conxian Health Monitor deployment process"
    
    # Step 1: Deploy contract
    deploy_health_monitor || exit 1
    
    # Step 2: Initialize system
    initialize_health_system || exit 1
    
    # Step 3: Test functionality
    test_health_monitoring || exit 1
    
    # Step 4: Verify alert routing
    verify_alert_routing || exit 1
    
    # Step 5: Generate report
    generate_deployment_report
    
    log_success "🎉 Conxian Health Monitor deployment completed successfully!"
    
    # Display summary
    echo ""
    echo "=== DEPLOYMENT SUMMARY ==="
    echo "Network: $NETWORK_TYPE"
    echo "Contract: $HEALTH_CONTRACT"
    echo "Alert Target: $(if [[ "$NETWORK_TYPE" == "testnet" ]]; then echo "Deployer Wallet"; else echo "DAO Governance"; fi)"
    echo "Status: ✅ READY"
    echo ""
    
    # Next steps reminder
    log_info "📝 Next steps:"
    echo "1. Configure monitoring dashboard integration"
    echo "2. Set up automated health check scheduling"
    echo "3. Test alert notifications"
    echo "4. Prepare for testnet stress testing"
    
    return 0
}

# Execute main function
main "$@"
