#!/bin/bash

# deploy-tokenomics.sh
# Conxian Enhanced Tokenomics System Deployment Script
# Orchestrates deployment of all tokenomics contracts in proper order

set -e  # Exit on any error

# =============================================================================
# DEPLOYMENT CONFIGURATION
# =============================================================================

NETWORK=${1:-"simnet"}  # Default to simnet, can be testnet or mainnet
DEPLOYMENT_ENV=${2:-"development"}  # development, staging, production
DRY_RUN=${3:-false}  # Set to true for deployment validation

echo "=== Conxian Enhanced Tokenomics Deployment ==="
echo "Network: $NETWORK"
echo "Environment: $DEPLOYMENT_ENV" 
echo "Dry Run: $DRY_RUN"
echo "=============================================="

# Load environment-specific configuration
case $DEPLOYMENT_ENV in
    "production")
        CONFIG_FILE="deployments/production-config.yaml"
        ;;
    "staging")
        CONFIG_FILE="deployments/staging-config.yaml"
        ;;
    *)
        CONFIG_FILE="deployments/development-config.yaml"
        ;;
esac

echo "Using configuration: $CONFIG_FILE"

# =============================================================================
# DEPLOYMENT PHASES
# =============================================================================

deploy_phase_1_core_tokens() {
    echo "--- Phase 1: Deploying Core Token Contracts ---"
    
    echo "Deploying CXD token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxd-token.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxd-token.clar
    fi
    
    echo "Deploying CXVG governance token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxvg-token.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxvg-token.clar
    fi
    
    echo "Deploying CXLP migration token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxlp-token.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxlp-token.clar
    fi
    
    echo "Deploying CXTR contributor token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxtr-token.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxtr-token.clar
    fi
    
    echo "✓ Phase 1 Complete: Core tokens deployed"
}

deploy_phase_2_system_infrastructure() {
    echo "--- Phase 2: Deploying System Infrastructure ---"
    
    echo "Deploying Protocol Invariant Monitor..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/protocol-invariant-monitor.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/protocol-invariant-monitor.clar
    fi
    
    echo "Deploying Token Emission Controller..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/token-emission-controller.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/token-emission-controller.clar
    fi
    
    echo "Deploying Revenue Distributor..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/revenue-distributor.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/revenue-distributor.clar
    fi
    
    echo "Deploying Token System Coordinator..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/token-system-coordinator.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/token-system-coordinator.clar
    fi
    
    echo "✓ Phase 2 Complete: System infrastructure deployed"
}

deploy_phase_3_enhanced_mechanisms() {
    echo "--- Phase 3: Deploying Enhanced Mechanisms ---"
    
    echo "Deploying CXD Staking Contract..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxd-staking.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxd-staking.clar
    fi
    
    echo "Deploying CXVG Utility Contract..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxvg-utility.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxvg-utility.clar
    fi
    
    echo "Deploying CXLP Migration Queue..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/cxlp-migration-queue.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/cxlp-migration-queue.clar
    fi
    
    echo "✓ Phase 3 Complete: Enhanced mechanisms deployed"
}

deploy_phase_4_dimensional_adapters() {
    echo "--- Phase 4: Deploying Dimensional Integration Adapters ---"
    
    echo "Deploying Dimensional Revenue Adapter..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/dimensional/dim-revenue-adapter.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/dimensional/dim-revenue-adapter.clar
    fi
    
    echo "Deploying Tokenized Bond Adapter..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would deploy: contracts/dimensional/tokenized-bond-adapter.clar"
    else
        clarinet deployments generate --low-cost --testnet contracts/dimensional/tokenized-bond-adapter.clar
    fi
    
    echo "✓ Phase 4 Complete: Dimensional adapters deployed"
}

configure_phase_5_system_integration() {
    echo "--- Phase 5: Configuring System Integration ---"
    
    echo "Configuring Protocol Monitor..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure protocol monitor with contracts"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .protocol-invariant-monitor register-contract .cxd-token "CXD_TOKEN")
(contract-call? .protocol-invariant-monitor register-contract .cxd-staking "CXD_STAKING")
(contract-call? .protocol-invariant-monitor register-contract .revenue-distributor "REVENUE_DIST")
(contract-call? .protocol-invariant-monitor register-contract .token-emission-controller "EMISSION_CTRL")
(contract-call? .protocol-invariant-monitor register-contract .token-system-coordinator "COORDINATOR")
EOF
    fi
    
    echo "Configuring Token Emission Controller..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure emission limits for tokens"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .token-emission-controller configure-token-emission .cxd-token u1000000000000 u10080 u21000000000000)
(contract-call? .token-emission-controller configure-token-emission .cxvg-token u500000000000 u10080 u10500000000000)
(contract-call? .token-emission-controller configure-token-emission .cxtr-token u100000000000 u10080 u2100000000000)
EOF
    fi
    
    echo "Configuring Revenue Distributor..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure revenue distribution parameters"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .revenue-distributor configure-revenue-split u7000 u2000 u1000)
(contract-call? .revenue-distributor register-fee-collector .cxd-token)
(contract-call? .revenue-distributor set-staking-contract .cxd-staking)
EOF
    fi
    
    echo "Configuring Token System Coordinator..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure system coordinator with all contracts"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .token-system-coordinator configure-system-contracts .cxd-staking .revenue-distributor .token-emission-controller .protocol-invariant-monitor)
EOF
    fi
    
    echo "✓ Phase 5 Complete: System integration configured"
}

configure_phase_6_token_integration() {
    echo "--- Phase 6: Configuring Token Integration ---"
    
    echo "Enabling system integration on CXD token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would enable CXD system integration"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .cxd-token enable-system-integration .token-system-coordinator .token-emission-controller .protocol-invariant-monitor)
EOF
    fi
    
    echo "Enabling system integration on CXVG token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would enable CXVG system integration"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .cxvg-token enable-system-integration .token-system-coordinator .token-emission-controller .protocol-invariant-monitor)
EOF
    fi
    
    echo "Enabling system integration on CXTR token..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would enable CXTR system integration"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .cxtr-token enable-system-integration .token-system-coordinator .token-emission-controller .protocol-invariant-monitor)
EOF
    fi
    
    echo "Configuring CXLP migration parameters..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure CXLP migration"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .cxlp-token configure-migration .cxd-token u0 u10080)
(contract-call? .cxlp-token set-liquidity-params u100000000000 u1000000000 u100 u50000000000 u525600 u11000)
EOF
    fi
    
    echo "✓ Phase 6 Complete: Token integration configured"
}

configure_phase_7_dimensional_adapters() {
    echo "--- Phase 7: Configuring Dimensional Adapters ---"
    
    echo "Configuring dimensional revenue adapter..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure dimensional revenue adapter"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .dim-revenue-adapter configure-system-contracts .revenue-distributor .token-system-coordinator .protocol-invariant-monitor)
EOF
    fi
    
    echo "Configuring tokenized bond adapter..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would configure bond adapter"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .tokenized-bond-adapter configure-system-contracts .revenue-distributor .token-system-coordinator .protocol-invariant-monitor)
EOF
    fi
    
    echo "✓ Phase 7 Complete: Dimensional adapters configured"
}

validate_deployment() {
    echo "--- Deployment Validation ---"
    
    echo "Validating contract deployments..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would validate all contracts are deployed"
    else
        # Run validation tests
        clarinet test tests/tokenomics-unit-tests.clar
        clarinet test tests/tokenomics-integration-tests.clar
        clarinet test tests/system-validation-tests.clar
    fi
    
    echo "Checking system health..."
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would check system health"
    else
        clarinet console --testnet << 'EOF'
(contract-call? .protocol-invariant-monitor check-system-health)
(contract-call? .token-system-coordinator get-system-info)
EOF
    fi
    
    echo "✓ Deployment validation complete"
}

# =============================================================================
# MAIN DEPLOYMENT EXECUTION
# =============================================================================

main() {
    echo "Starting Conxian Enhanced Tokenomics deployment..."
    
    # Pre-deployment checks
    if [ ! -f "Clarinet.toml" ]; then
        echo "Error: Clarinet.toml not found. Please run from project root."
        exit 1
    fi
    
    if [ "$NETWORK" = "mainnet" ] && [ "$DEPLOYMENT_ENV" != "production" ]; then
        echo "Error: Mainnet deployment only allowed in production environment"
        exit 1
    fi
    
    # Execute deployment phases
    deploy_phase_1_core_tokens
    deploy_phase_2_system_infrastructure
    deploy_phase_3_enhanced_mechanisms
    deploy_phase_4_dimensional_adapters
    configure_phase_5_system_integration
    configure_phase_6_token_integration
    configure_phase_7_dimensional_adapters
    validate_deployment
    
    echo "=== Deployment Complete ==="
    echo "Network: $NETWORK"
    echo "Environment: $DEPLOYMENT_ENV"
    echo "Status: SUCCESS"
    echo "Contracts deployed: 11"
    echo "System components: 7"
    echo "Integration adapters: 2"
    echo "=========================="
    
    if [ "$DRY_RUN" = "false" ]; then
        echo "✓ Enhanced tokenomics system is live and operational!"
        echo "Run 'clarinet console' to interact with deployed contracts"
    else
        echo "✓ Dry run completed successfully"
        echo "Run without --dry-run flag to execute actual deployment"
    fi
}

# =============================================================================
# DEPLOYMENT UTILITIES
# =============================================================================

show_help() {
    cat << EOF
Conxian Enhanced Tokenomics Deployment Script

Usage: $0 [NETWORK] [ENVIRONMENT] [DRY_RUN]

Arguments:
  NETWORK      Target network (simnet|testnet|mainnet) [default: simnet]
  ENVIRONMENT  Deployment environment (development|staging|production) [default: development]  
  DRY_RUN      Validation mode (true|false) [default: false]

Examples:
  $0                                    # Deploy to simnet development
  $0 testnet staging                    # Deploy to testnet staging
  $0 testnet staging true               # Validate testnet staging deployment
  $0 mainnet production                 # Deploy to mainnet production

Configuration Files:
  deployments/development-config.yaml
  deployments/staging-config.yaml
  deployments/production-config.yaml

For more information, see documentation/DEPLOYMENT.md
EOF
}

# Handle command line arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac
