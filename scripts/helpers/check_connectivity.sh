#!/bin/bash
#
# Check Connectivity Script
#
# This script verifies network connectivity between containers in the ECMP topology.
# It tests reachability between source hosts, routers, and destination.
#
# Reference: RFC 791 (Internet Protocol), RFC 792 (ICMP)
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
#
# Usage:
#   ./check_connectivity.sh [options]
#
# Options:
#   -s, --source CONTAINER Source container name
#   -d, --destination IP    Destination IP address
#   -p, --port PORT         Destination port (for TCP/UDP)
#   -t, --type TYPE         Test type: ping, tcp, udp (default: ping)
#   -c, --count NUM         Number of packets to send (default: 3)
#   -v, --verbose           Enable verbose output
#   -h, --help              Show this help message
#
# Examples:
#   ./check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10
#   ./check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10 --port 80 --type tcp
#   ./check_connectivity.sh --all  # Check all connectivity paths

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default configuration
SOURCE=""
DESTINATION=""
PORT=""
TYPE="ping"
COUNT=3
VERBOSE=false
CHECK_ALL=false

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/check_connectivity.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

# Print usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Verify network connectivity between containers.

Options:
  -s, --source CONTAINER Source container name
  -d, --destination IP    Destination IP address
  -p, --port PORT         Destination port (for TCP/UDP)
  -t, --type TYPE         Test type: ping, tcp, udp (default: ping)
  -c, --count NUM         Number of packets to send (default: 3)
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message
  --all                   Check all connectivity paths in topology

Examples:
  $(basename "$0") --source clab-ecmp-test-h1 --destination 192.168.100.10
  $(basename "$0") --source clab-ecmp-test-h1 --destination 192.168.100.10 --port 80 --type tcp
  $(basename "$0") --all

EOF
}

# Log message with timestamp
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log to file
    echo "[${timestamp}] [${level^^}] ${message}" >> "$LOG_FILE"
    
    # Log to console based on level and verbosity
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "error" ]] || [[ "$level" == "warn" ]]; then
        case "$level" in
            error)
                echo -e "${RED}[ERROR]${NC} ${message}" >&2
                ;;
            warn)
                echo -e "${YELLOW}[WARN]${NC} ${message}" >&2
                ;;
            info)
                echo -e "${GREEN}[INFO]${NC} ${message}"
                ;;
            debug)
                echo -e "${BLUE}[DEBUG]${NC} ${message}"
                ;;
        esac
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE="$2"
                shift 2
                ;;
            -d|--destination)
                DESTINATION="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -t|--type)
                TYPE="$2"
                shift 2
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --all)
                CHECK_ALL=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if container is running
is_container_running() {
    local container="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Perform ping test
test_ping() {
    local source="$1"
    local destination="$2"
    local count="${3:-3}"
    
    log info "Testing ping from $source to $destination (${count} packets)"
    
    if ! is_container_running "$source"; then
        log error "Source container is not running: $source"
        return 1
    fi
    
    # Execute ping in container
    local ping_output
    if ping_output=$(docker exec "$source" ping -c "$count" -W 2 "$destination" 2>&1); then
        local packet_loss
        packet_loss=$(echo "$ping_output" | grep "packet loss" | awk '{print $6}' | tr -d '%')
        
        if [[ "$packet_loss" == "0" ]]; then
            log info "Ping test successful: 0% packet loss"
            return 0
        else
            log warn "Ping test completed with ${packet_loss}% packet loss"
            return 1
        fi
    else
        log error "Ping test failed"
        return 1
    fi
}

# Perform TCP connectivity test
test_tcp() {
    local source="$1"
    local destination="$2"
    local port="$3"
    
    log info "Testing TCP connectivity from $source to ${destination}:${port}"
    
    if ! is_container_running "$source"; then
        log error "Source container is not running: $source"
        return 1
    fi
    
    # Try to connect using nc (netcat) or timeout with bash
    if docker exec "$source" which nc &> /dev/null; then
        # Use netcat
        if docker exec "$source" nc -z -w 2 "$destination" "$port" 2>&1; then
            log info "TCP connection successful to ${destination}:${port}"
            return 0
        else
            log error "TCP connection failed to ${destination}:${port}"
            return 1
        fi
    else
        # Use timeout with bash
        if docker exec "$source" timeout 2 bash -c "echo > /dev/tcp/${destination}/${port}" 2>&1; then
            log info "TCP connection successful to ${destination}:${port}"
            return 0
        else
            log error "TCP connection failed to ${destination}:${port}"
            return 1
        fi
    fi
}

# Perform UDP connectivity test
test_udp() {
    local source="$1"
    local destination="$2"
    local port="$3"
    
    log info "Testing UDP connectivity from $source to ${destination}:${port}"
    
    if ! is_container_running "$source"; then
        log error "Source container is not running: $source"
        return 1
    fi
    
    # UDP is connectionless, so we can only test if we can send packets
    # Use nc (netcat) in UDP mode
    if docker exec "$source" which nc &> /dev/null; then
        if docker exec "$source" nc -u -z -w 2 "$destination" "$port" 2>&1; then
            log info "UDP test completed to ${destination}:${port}"
            return 0
        else
            log warn "UDP test inconclusive to ${destination}:${port} (UDP is connectionless)"
            return 0
        fi
    else
        log warn "Cannot test UDP connectivity (nc not available)"
        return 0
    fi
}

# Check all connectivity paths in the topology
check_all_connectivity() {
    log info "Checking all connectivity paths in ECMP topology"
    
    local success_count=0
    local failure_count=0
    
    # Define test paths
    declare -a test_paths=(
        "clab-ecmp-test-h1:192.168.100.10"
        "clab-ecmp-test-h2:192.168.100.10"
        "clab-ecmp-test-h3:192.168.100.10"
        "clab-ecmp-test-h4:192.168.100.10"
    )
    
    for path in "${test_paths[@]}"; do
        local source="${path%%:*}"
        local destination="${path##*:}"
        
        log info "Testing path: $source -> $destination"
        
        if test_ping "$source" "$destination" "$COUNT"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    log info "Connectivity check completed"
    log info "Successful paths: $success_count, Failed paths: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Print connectivity summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Connectivity Check Summary"
    echo "=========================================="
    if [[ "$CHECK_ALL" == true ]]; then
        echo "Mode: All paths"
    else
        echo "Source: $SOURCE"
        echo "Destination: $DESTINATION"
        echo "Type: $TYPE"
        if [[ -n "$PORT" ]]; then
            echo "Port: $PORT"
        fi
    fi
    echo "=========================================="
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Print summary
    print_summary
    
    # Check all connectivity paths
    if [[ "$CHECK_ALL" == true ]]; then
        if check_all_connectivity; then
            log info "All connectivity paths are working"
            exit 0
        else
            log error "Some connectivity paths are failing"
            exit 1
        fi
    fi
    
    # Validate required parameters
    if [[ -z "$SOURCE" ]] || [[ -z "$DESTINATION" ]]; then
        log error "Source and destination are required (unless using --all)"
        usage
        exit 1
    fi
    
    # Perform connectivity test based on type
    case "$TYPE" in
        ping)
            if test_ping "$SOURCE" "$DESTINATION" "$COUNT"; then
                log info "Connectivity test passed"
                exit 0
            else
                log error "Connectivity test failed"
                exit 1
            fi
            ;;
        tcp)
            if [[ -z "$PORT" ]]; then
                log error "Port is required for TCP test"
                exit 1
            fi
            if test_tcp "$SOURCE" "$DESTINATION" "$PORT"; then
                log info "Connectivity test passed"
                exit 0
            else
                log error "Connectivity test failed"
                exit 1
            fi
            ;;
        udp)
            if [[ -z "$PORT" ]]; then
                log error "Port is required for UDP test"
                exit 1
            fi
            if test_udp "$SOURCE" "$DESTINATION" "$PORT"; then
                log info "Connectivity test passed"
                exit 0
            else
                log error "Connectivity test failed"
                exit 1
            fi
            ;;
        *)
            log error "Unknown test type: $TYPE"
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
