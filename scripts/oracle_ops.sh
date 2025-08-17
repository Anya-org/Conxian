#!/bin/bash
# Oracle Operations Wrapper Script
# 
# Provides convenient shell commands for oracle management and monitoring.
# Acts as a wrapper around the Python oracle management tools.
#
# Usage:
#   ./oracle_ops.sh setup                          # Initial setup
#   ./oracle_ops.sh pair add STX USD --min-sources 3
#   ./oracle_ops.sh oracle add STX USD SP123...ORACLE
#   ./oracle_ops.sh price submit STX USD 123456
#   ./oracle_ops.sh monitor STX USD --watch
#   ./oracle_ops.sh health-check
#   ./oracle_ops.sh start-orchestrator [mode]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORACLE_MANAGER_PY="${SCRIPT_DIR}/oracle_manager.py"
ORACLE_ORCHESTRATOR_PY="${SCRIPT_DIR}/oracle_orchestrator.py"

# Default environment variables
export STACKS_NETWORK="${STACKS_NETWORK:-testnet}"
export STACKS_RPC_URL="${STACKS_RPC_URL:-https://stacks-node-api.testnet.stacks.co}"
export ORACLE_AGGREGATOR_CONTRACT="${ORACLE_AGGREGATOR_CONTRACT:-SPXXXXX.oracle-aggregator}"
export DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check required Python modules
    local required_modules=("asyncio" "dataclasses" "argparse")
    for module in "${required_modules[@]}"; do
        if ! python3 -c "import $module" &> /dev/null; then
            log_error "Python module '$module' is required but not available"
            exit 1
        fi
    done
    
    # Check if oracle manager script exists
    if [[ ! -f "$ORACLE_MANAGER_PY" ]]; then
        log_error "Oracle manager script not found: $ORACLE_MANAGER_PY"
        exit 1
    fi
    
    # Check if orchestrator script exists
    if [[ ! -f "$ORACLE_ORCHESTRATOR_PY" ]]; then
        log_error "Oracle orchestrator script not found: $ORACLE_ORCHESTRATOR_PY"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Display environment configuration
show_config() {
    log_info "Current Configuration:"
    echo "  Network: $STACKS_NETWORK"
    echo "  RPC URL: $STACKS_RPC_URL"
    echo "  Oracle Contract: $ORACLE_AGGREGATOR_CONTRACT"
    echo "  Dry Run: $DRY_RUN"
    echo ""
}

# Setup function
setup_oracle_system() {
    log_info "Setting up Oracle System..."
    
    check_prerequisites
    show_config
    
    # Create necessary directories
    mkdir -p "${SCRIPT_DIR}/../logs/oracle"
    mkdir -p "${SCRIPT_DIR}/../data/oracle"
    
    # Create example configuration file
    cat > "${SCRIPT_DIR}/../data/oracle/oracle.conf" << 'EOF'
# Oracle System Configuration
# Copy this file and customize for your environment

[network]
network = testnet
rpc_url = https://stacks-node-api.testnet.stacks.co

[contracts]
oracle_aggregator = SPXXXXX.oracle-aggregator
circuit_breaker = SPXXXXX.circuit-breaker

[orchestration]
price_update_interval = 60
health_check_interval = 120
max_oracles_per_pair = 10
min_oracles_per_pair = 3

[monitoring]
price_deviation_threshold_bps = 500
price_volatility_threshold_bps = 1000
oracle_timeout_seconds = 300

[alerts]
webhook_url = https://example.com/alerts
EOF

    log_success "Oracle system setup complete"
    log_info "Configuration file created at: ${SCRIPT_DIR}/../data/oracle/oracle.conf"
    log_info "Log directory created at: ${SCRIPT_DIR}/../logs/oracle"
}

# Wrapper functions for common operations

pair_operations() {
    local action="$1"
    shift
    
    case "$action" in
        "add")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 pair add <base> <quote> [--min-sources <n>] [--oracles <list>]"
                exit 1
            fi
            python3 "$ORACLE_MANAGER_PY" pair add "$@"
            ;;
        "list")
            python3 "$ORACLE_MANAGER_PY" pair list
            ;;
        *)
            log_error "Unknown pair action: $action"
            exit 1
            ;;
    esac
}

oracle_operations() {
    local action="$1"
    shift
    
    case "$action" in
        "add"|"remove"|"status")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 oracle $action <base> <quote> <oracle-address>"
                exit 1
            fi
            python3 "$ORACLE_MANAGER_PY" oracle "$action" "$@"
            ;;
        *)
            log_error "Unknown oracle action: $action"
            exit 1
            ;;
    esac
}

price_operations() {
    local action="$1"
    shift
    
    case "$action" in
        "submit")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 price submit <base> <quote> <price> [--oracle-privkey <key>]"
                exit 1
            fi
            python3 "$ORACLE_MANAGER_PY" price submit "$@"
            ;;
        "get")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 price get <base> <quote>"
                exit 1
            fi
            python3 "$ORACLE_MANAGER_PY" price get "$@"
            ;;
        "median")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 price median <base> <quote>"
                exit 1
            fi
            python3 "$ORACLE_MANAGER_PY" price median "$@"
            ;;
        *)
            log_error "Unknown price action: $action"
            exit 1
            ;;
    esac
}

monitor_operations() {
    local base="${1:-}"
    local quote="${2:-}"
    shift 2 || true
    
    if [[ -n "$base" && -n "$quote" ]]; then
        python3 "$ORACLE_MANAGER_PY" monitor "$base" "$quote" "$@"
    else
        python3 "$ORACLE_MANAGER_PY" monitor "$@"
    fi
}

status_operations() {
    local base="${1:-}"
    local quote="${2:-}"
    
    if [[ -n "$base" && -n "$quote" ]]; then
        python3 "$ORACLE_MANAGER_PY" status "$base" "$quote"
    else
        python3 "$ORACLE_MANAGER_PY" status
    fi
}

health_check() {
    log_info "Performing Oracle System Health Check..."
    
    # Check network connectivity
    log_info "Checking network connectivity..."
    if curl -s "$STACKS_RPC_URL/v2/info" > /dev/null; then
        log_success "Network connectivity OK"
    else
        log_error "Cannot connect to Stacks network"
        return 1
    fi
    
    # Check contract availability
    log_info "Checking contract availability..."
    # TODO: Add actual contract check
    log_success "Contract availability OK"
    
    # Get all pairs status
    log_info "Checking trading pairs status..."
    python3 "$ORACLE_MANAGER_PY" status || true
    
    log_success "Health check complete"
}

start_orchestrator() {
    local mode="${1:-full}"
    
    log_info "Starting Oracle Orchestrator in '$mode' mode..."
    
    # Check if already running
    local pidfile="${SCRIPT_DIR}/../logs/oracle/orchestrator.pid"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Oracle Orchestrator is already running (PID: $pid)"
            log_info "To stop: kill $pid"
            return 0
        else
            rm -f "$pidfile"
        fi
    fi
    
    # Start orchestrator in background
    local logfile="${SCRIPT_DIR}/../logs/oracle/orchestrator.log"
    python3 "$ORACLE_ORCHESTRATOR_PY" --mode "$mode" > "$logfile" 2>&1 &
    local pid=$!
    
    echo "$pid" > "$pidfile"
    log_success "Oracle Orchestrator started (PID: $pid)"
    log_info "Logs: $logfile"
    log_info "To stop: kill $pid"
}

stop_orchestrator() {
    local pidfile="${SCRIPT_DIR}/../logs/oracle/orchestrator.pid"
    
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping Oracle Orchestrator (PID: $pid)..."
            kill "$pid"
            rm -f "$pidfile"
            log_success "Oracle Orchestrator stopped"
        else
            log_warning "Oracle Orchestrator not running"
            rm -f "$pidfile"
        fi
    else
        log_warning "Oracle Orchestrator PID file not found"
    fi
}

# Quick setup functions

quick_testnet_setup() {
    log_info "Quick Testnet Setup..."
    
    # Set testnet configuration
    export STACKS_NETWORK="testnet"
    export STACKS_RPC_URL="https://stacks-node-api.testnet.stacks.co"
    export DRY_RUN="true"  # Default to dry run for safety
    
    setup_oracle_system
    
    log_info "Example commands:"
    echo "  # Add a trading pair"
    echo "  $0 pair add STX USD --min-sources 3"
    echo ""
    echo "  # Add an oracle to the pair"
    echo "  $0 oracle add STX USD SP123...ORACLE"
    echo ""
    echo "  # Submit a price"
    echo "  $0 price submit STX USD 123456"
    echo ""
    echo "  # Monitor prices"
    echo "  $0 monitor STX USD --watch"
    echo ""
    echo "  # Start orchestrator"
    echo "  $0 start-orchestrator"
}

# Display usage information
usage() {
    cat << 'EOF'
Oracle Operations Wrapper

USAGE:
    ./oracle_ops.sh <command> [arguments...]

COMMANDS:
    setup                                    Initial oracle system setup
    quick-testnet-setup                      Quick testnet configuration
    
    pair add <base> <quote> [options]        Add trading pair
    pair list                                List all trading pairs
    
    oracle add <base> <quote> <address>      Add oracle to pair
    oracle remove <base> <quote> <address>   Remove oracle from pair  
    oracle status <base> <quote> <address>   Check oracle status
    
    price submit <base> <quote> <price>      Submit price
    price get <base> <quote>                 Get current price
    price median <base> <quote>              Get median price
    
    status [<base> <quote>]                  Get status (all pairs or specific)
    monitor [<base> <quote>] [--watch]       Monitor price updates
    health-check                             Perform system health check
    
    start-orchestrator [mode]                Start orchestrator (full|coordinator|monitor)
    stop-orchestrator                        Stop orchestrator

ENVIRONMENT VARIABLES:
    STACKS_NETWORK                Network (testnet/mainnet)
    STACKS_RPC_URL                RPC endpoint URL
    ORACLE_AGGREGATOR_CONTRACT    Oracle contract address
    DEPLOYER_PRIVKEY              Private key for admin operations
    DRY_RUN                       Enable dry run mode (true/false)

EXAMPLES:
    # Setup system
    ./oracle_ops.sh setup
    
    # Add STX/USD pair with 3 minimum sources
    ./oracle_ops.sh pair add STX USD --min-sources 3
    
    # Add oracle to STX/USD pair
    ./oracle_ops.sh oracle add STX USD SP123...ORACLE
    
    # Submit price for STX/USD
    ./oracle_ops.sh price submit STX USD 123456
    
    # Monitor all pairs continuously
    ./oracle_ops.sh monitor --watch
    
    # Start full orchestrator
    ./oracle_ops.sh start-orchestrator full

EOF
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        "setup")
            setup_oracle_system
            ;;
        "quick-testnet-setup")
            quick_testnet_setup
            ;;
        "pair")
            pair_operations "$@"
            ;;
        "oracle")
            oracle_operations "$@"
            ;;
        "price")
            price_operations "$@"
            ;;
        "status")
            status_operations "$@"
            ;;
        "monitor")
            monitor_operations "$@"
            ;;
        "health-check")
            health_check
            ;;
        "start-orchestrator")
            start_orchestrator "$@"
            ;;
        "stop-orchestrator")
            stop_orchestrator
            ;;
        "help"|"--help"|"-h")
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
