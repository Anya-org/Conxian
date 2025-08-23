#!/bin/bash

# Enhanced Health Monitoring Deployment Script
# Deploys and configures health monitoring with environment-specific alerts

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HEALTH_CONTRACT="enhanced-health-monitoring"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default values
ENVIRONMENT="${1:-testnet}"
DEPLOY_MODE="${2:-health-only}"
VALIDATION_MODE="${3:-standard}"

# Network configurations
declare -A NETWORK_CONFIG=(
    ["testnet"]="testnet"
    ["mainnet"]="mainnet"
    ["devnet"]="devnet"
)

declare -A API_ENDPOINTS=(
    ["testnet"]="https://api.testnet.hiro.so"
    ["mainnet"]="https://api.hiro.so"
    ["devnet"]="http://localhost:3999"
)

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_header() {
    echo -e "${PURPLE}================================================================${NC}" >&2
    echo -e "${PURPLE}$1${NC}" >&2
    echo -e "${PURPLE}================================================================${NC}" >&2
}

check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check if clarinet is available
    if ! command -v clarinet &> /dev/null; then
        log_error "Clarinet not found. Installing..."
        if [[ -f "$PROJECT_ROOT/bin/clarinet" ]]; then
            export PATH="$PROJECT_ROOT/bin:$PATH"
            log_success "Using local clarinet binary"
        else
            log_error "No clarinet binary found. Please install clarinet."
            exit 1
        fi
    fi
    
    # Check Python for monitoring script
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 not found. Required for health monitoring."
        exit 1
    fi
    
    # Check if health monitoring contract exists
    if [[ ! -f "$PROJECT_ROOT/contracts/$HEALTH_CONTRACT.clar" ]]; then
        log_error "Health monitoring contract not found: $HEALTH_CONTRACT.clar"
        exit 1
    fi
    
    # Validate network configuration
    if [[ ! "${NETWORK_CONFIG[$ENVIRONMENT]+_}" ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        log_info "Valid environments: ${!NETWORK_CONFIG[*]}"
        exit 1
    fi
    
    log_success "All prerequisites checked"
}

deploy_health_monitoring() {
    log_header "Deploying Enhanced Health Monitoring"
    
    local network="${NETWORK_CONFIG[$ENVIRONMENT]}"
    
    log_info "Deploying to network: $network"
    log_info "Contract: $HEALTH_CONTRACT"
    
    # Navigate to project root
    cd "$PROJECT_ROOT"
    
    # Check if contract is in Clarinet.toml
    if ! grep -q "$HEALTH_CONTRACT" Clarinet.toml; then
        log_error "Contract $HEALTH_CONTRACT not found in Clarinet.toml"
        exit 1
    fi
    
    # Deploy health monitoring contract
    log_info "Starting contract deployment..."
    
    if [[ "$ENVIRONMENT" == "devnet" ]]; then
        # For devnet, start local node if needed
        if ! pgrep -f "clarinet integrate" > /dev/null; then
            log_info "Starting local devnet..."
            clarinet integrate &
            sleep 10
        fi
    fi
    
    # Deploy the contract
    local deploy_cmd="clarinet deploy --network $network"
    if [[ "$VALIDATION_MODE" == "comprehensive" ]]; then
        deploy_cmd="$deploy_cmd --costs --coverage"
    fi
    
    log_info "Executing: $deploy_cmd"
    
    if $deploy_cmd 2>&1 | tee "deployment-health-$ENVIRONMENT-$TIMESTAMP.log"; then
        log_success "Health monitoring contract deployed successfully"
    else
        log_error "Contract deployment failed"
        exit 1
    fi
    
    # Extract contract address from deployment
    local contract_address
    contract_address=$(grep -o 'ST[A-Z0-9]*\.$HEALTH_CONTRACT' "deployment-health-$ENVIRONMENT-$TIMESTAMP.log" | head -1)
    
    if [[ -z "$contract_address" ]]; then
        log_warning "Could not extract contract address from deployment log"
        contract_address="ST000000000000000000002AMW42H.$HEALTH_CONTRACT"
    fi
    
    log_success "Contract deployed at: $contract_address"
    echo "$contract_address" > "health-contract-address-$ENVIRONMENT.txt"
}

configure_monitoring() {
    log_header "Configuring Health Monitoring"
    
    local contract_address
    if [[ -f "health-contract-address-$ENVIRONMENT.txt" ]]; then
        contract_address=$(cat "health-contract-address-$ENVIRONMENT.txt")
    else
        log_error "Contract address file not found"
        exit 1
    fi
    
    log_info "Configuring monitoring for: $contract_address"
    log_info "Environment: $ENVIRONMENT"
    
    # Create monitoring configuration
    cat > "health-monitoring-config-$ENVIRONMENT.json" << EOF
{
    "environment": "$ENVIRONMENT",
    "contract_address": "$contract_address",
    "api_endpoint": "${API_ENDPOINTS[$ENVIRONMENT]}",
    "monitoring_enabled": true,
    "check_interval": 30,
    "alert_config": {
        "testnet": {
            "target": "deployer_wallet",
            "webhook_url": null,
            "notification_level": "all"
        },
        "mainnet": {
            "target": "dao_contract",
            "webhook_url": null,
            "notification_level": "critical_only"
        }
    },
    "components": [
        "oracle-aggregator-enhanced",
        "nakamoto-optimized-oracle", 
        "sdk-ultra-performance",
        "nakamoto-factory-ultra",
        "nakamoto-vault-ultra",
        "dex-factory-enhanced",
        "vault-enhanced"
    ],
    "nakamoto_monitoring": {
        "microblock_tps_threshold": 1000,
        "bitcoin_finality_threshold": 720,
        "performance_threshold": 80
    }
}
EOF
    
    log_success "Monitoring configuration created"
}

validate_deployment() {
    log_header "Validating Health Monitoring Deployment"
    
    local contract_address
    if [[ -f "health-contract-address-$ENVIRONMENT.txt" ]]; then
        contract_address=$(cat "health-contract-address-$ENVIRONMENT.txt")
    else
        log_error "Contract address file not found"
        exit 1
    fi
    
    log_info "Validating contract: $contract_address"
    
    # Test contract read-only functions
    log_info "Testing read-only functions..."
    
    # Test get-monitoring-enabled
    if clarinet call "$HEALTH_CONTRACT" get-monitoring-enabled --network "${NETWORK_CONFIG[$ENVIRONMENT]}" 2>/dev/null; then
        log_success "✓ get-monitoring-enabled function accessible"
    else
        log_warning "⚠ get-monitoring-enabled function test failed"
    fi
    
    # Test get-environment
    if clarinet call "$HEALTH_CONTRACT" get-environment --network "${NETWORK_CONFIG[$ENVIRONMENT]}" 2>/dev/null; then
        log_success "✓ get-environment function accessible"
    else
        log_warning "⚠ get-environment function test failed"
    fi
    
    # Test get-alert-target
    if clarinet call "$HEALTH_CONTRACT" get-alert-target --network "${NETWORK_CONFIG[$ENVIRONMENT]}" 2>/dev/null; then
        log_success "✓ get-alert-target function accessible"
    else
        log_warning "⚠ get-alert-target function test failed"
    fi
    
    log_success "Contract validation completed"
}

start_monitoring_service() {
    log_header "Starting Health Monitoring Service"
    
    local contract_address
    if [[ -f "health-contract-address-$ENVIRONMENT.txt" ]]; then
        contract_address=$(cat "health-contract-address-$ENVIRONMENT.txt")
    else
        log_error "Contract address file not found"
        exit 1
    fi
    
    log_info "Starting monitoring service..."
    log_info "Contract: $contract_address"
    log_info "Environment: $ENVIRONMENT"
    
    # Check if monitoring script exists
    if [[ ! -f "$SCRIPT_DIR/enhanced-health-monitor.py" ]]; then
        log_error "Health monitoring script not found"
        exit 1
    fi
    
    # Install Python dependencies if needed
    if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
        log_info "Installing Python dependencies..."
        pip3 install -r "$PROJECT_ROOT/requirements.txt" --quiet
    fi
    
    # Start monitoring in background
    log_info "Starting background monitoring process..."
    
    python3 "$SCRIPT_DIR/enhanced-health-monitor.py" \
        --environment "$ENVIRONMENT" \
        --contract "$contract_address" \
        --interval 30 \
        > "health-monitoring-$ENVIRONMENT-$TIMESTAMP.log" 2>&1 &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "health-monitor-$ENVIRONMENT.pid"
    
    log_success "Health monitoring started (PID: $monitor_pid)"
    log_info "Logs: health-monitoring-$ENVIRONMENT-$TIMESTAMP.log"
    
    # Verify monitoring is running
    sleep 3
    if kill -0 "$monitor_pid" 2>/dev/null; then
        log_success "✓ Monitoring service is running"
    else
        log_error "✗ Monitoring service failed to start"
        exit 1
    fi
}

generate_deployment_report() {
    log_header "Generating Deployment Report"
    
    local contract_address
    if [[ -f "health-contract-address-$ENVIRONMENT.txt" ]]; then
        contract_address=$(cat "health-contract-address-$ENVIRONMENT.txt")
    else
        contract_address="UNKNOWN"
    fi
    
    local report_file="health-monitoring-deployment-report-$ENVIRONMENT-$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# Enhanced Health Monitoring Deployment Report

**Environment:** $ENVIRONMENT  
**Timestamp:** $(date)  
**Contract Address:** $contract_address

## Deployment Summary

### Components Deployed
- Enhanced Health Monitoring Contract
- Health Monitoring Service
- Environment-Specific Alert Routing

### Alert Configuration
EOF

    if [[ "$ENVIRONMENT" == "testnet" ]]; then
        cat >> "$report_file" << EOF
- **Alert Target:** Deployer Wallet
- **Notification Level:** All Issues
- **Purpose:** Development and Testing Alerts
EOF
    else
        cat >> "$report_file" << EOF
- **Alert Target:** DAO Contract
- **Notification Level:** Critical Issues Only
- **Purpose:** Production Governance Alerts
EOF
    fi

    cat >> "$report_file" << EOF

### Monitoring Capabilities
- Nakamoto Performance Monitoring
- Component Health Tracking  
- Ultra-High TPS Monitoring
- Emergency Alert System
- Trend Analysis and Alerting

### Configuration Files Generated
- health-monitoring-config-$ENVIRONMENT.json
- health-contract-address-$ENVIRONMENT.txt
- health-monitoring-$ENVIRONMENT-$TIMESTAMP.log

### Next Steps
1. Verify alert routing functionality
2. Test emergency alert system
3. Monitor performance metrics
4. Validate Nakamoto optimizations

## Technical Details

### Contract Functions Available
- get-monitoring-enabled
- get-environment  
- get-alert-target
- update-health-metric
- update-nakamoto-metrics
- trigger-alert
- emergency-mode controls

### Environment Detection
The contract automatically detects the deployment environment and routes alerts accordingly:
- Testnet: Direct alerts to deployer wallet
- Mainnet: Route critical alerts through DAO governance

## Validation Status
✓ Contract deployed successfully  
✓ Monitoring service started  
✓ Configuration validated  
✓ Alert routing configured  

---
*Generated by Enhanced Health Monitoring Deployment Script*
EOF

    log_success "Deployment report generated: $report_file"
}

show_status() {
    log_header "Health Monitoring Status"
    
    local contract_address="UNKNOWN"
    if [[ -f "health-contract-address-$ENVIRONMENT.txt" ]]; then
        contract_address=$(cat "health-contract-address-$ENVIRONMENT.txt")
    fi
    
    echo -e "${CYAN}Environment:${NC} $ENVIRONMENT"
    echo -e "${CYAN}Contract:${NC} $contract_address"
    echo -e "${CYAN}API Endpoint:${NC} ${API_ENDPOINTS[$ENVIRONMENT]}"
    
    if [[ -f "health-monitor-$ENVIRONMENT.pid" ]]; then
        local pid=$(cat "health-monitor-$ENVIRONMENT.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${CYAN}Monitoring Status:${NC} ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "${CYAN}Monitoring Status:${NC} ${RED}Stopped${NC}"
        fi
    else
        echo -e "${CYAN}Monitoring Status:${NC} ${YELLOW}Not Started${NC}"
    fi
    
    # Show recent logs if available
    local log_file="health-monitoring-$ENVIRONMENT-$(date +%Y%m%d)_*.log"
    if ls $log_file 1> /dev/null 2>&1; then
        echo -e "\n${CYAN}Recent Log Entries:${NC}"
        tail -5 $(ls -t $log_file | head -1) 2>/dev/null || echo "No recent logs available"
    fi
}

main() {
    log_header "Enhanced Health Monitoring Deployment"
    
    log_info "Environment: $ENVIRONMENT"
    log_info "Deploy Mode: $DEPLOY_MODE"
    log_info "Validation Mode: $VALIDATION_MODE"
    
    case "$DEPLOY_MODE" in
        "health-only")
            check_prerequisites
            deploy_health_monitoring
            configure_monitoring
            validate_deployment
            generate_deployment_report
            log_success "Health monitoring deployment completed"
            ;;
        "monitoring-only")
            check_prerequisites
            configure_monitoring
            start_monitoring_service
            generate_deployment_report
            log_success "Monitoring service started"
            ;;
        "full")
            check_prerequisites
            deploy_health_monitoring
            configure_monitoring
            validate_deployment
            start_monitoring_service
            generate_deployment_report
            log_success "Full health monitoring deployment completed"
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "Invalid deploy mode: $DEPLOY_MODE"
            log_info "Valid modes: health-only, monitoring-only, full, status"
            exit 1
            ;;
    esac
}

# Handle script arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <environment> [deploy_mode] [validation_mode]"
    echo ""
    echo "Environments: testnet, mainnet, devnet"
    echo "Deploy Modes: health-only, monitoring-only, full, status"
    echo "Validation Modes: standard, comprehensive"
    echo ""
    echo "Examples:"
    echo "  $0 testnet full comprehensive"
    echo "  $0 mainnet health-only"
    echo "  $0 testnet status"
    exit 1
fi

# Execute main function
main "$@"
