#!/bin/bash
#
# Traffic Generation Script for ECMP Hash Testing
#
# This script generates test traffic from source hosts (h1-h4) to destination (d1)
# with controlled Source IP addresses while keeping other parameters constant.
#
# Reference: https://linux.die.net/man/8/hping3
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
# Best Practices: RFC 2544 benchmarking methodology
#
# Usage:
#   ./generate_traffic.sh [options]
#
# Options:
#   -c, --config FILE      Path to traffic configuration file (default: configs/traffic/traffic_config.yaml)
#   -s, --scenario NAME    Test scenario to execute (default: basic_distribution)
#   -d, --duration SECONDS Test duration in seconds (overrides config)
#   -n, --count NUM        Number of packets per source (overrides config)
#   -v, --verbose          Enable verbose output
#   -h, --help             Show this help message
#
# Examples:
#   ./generate_traffic.sh
#   ./generate_traffic.sh --scenario high_volume
#   ./generate_traffic.sh --duration 120 --count 5000

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/configs/traffic/traffic_config.yaml"
SCENARIO="basic_distribution"
VERBOSE=false
DRY_RUN=false

# Traffic parameters (will be loaded from config)
DESTINATION_IP=""
DESTINATION_PORT=""
PROTOCOL=""
PACKET_COUNT=1000
INTERVAL=10
PACKET_SIZE=100
TTL=64
TCP_FLAGS="S"
SOURCE_PORT=0

# Source hosts
declare -A SOURCE_HOSTS
declare -a ENABLED_SOURCES

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/traffic_generation.log"
LOG_LEVEL="info"

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

Generate test traffic for ECMP hash testing with controlled Source IP addresses.

Options:
  -c, --config FILE      Path to traffic configuration file
                         (default: configs/traffic/traffic_config.yaml)
  -s, --scenario NAME    Test scenario to execute
                         (default: basic_distribution)
  -d, --duration SECONDS Test duration in seconds (overrides config)
  -n, --count NUM        Number of packets per source (overrides config)
  -v, --verbose          Enable verbose output
  -h, --help             Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --scenario high_volume
  $(basename "$0") --duration 120 --count 5000

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
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -s|--scenario)
                SCENARIO="$2"
                shift 2
                ;;
            -d|--duration)
                DURATION_OVERRIDE="$2"
                shift 2
                ;;
            -n|--count)
                PACKET_COUNT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
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

# Check if required tools are available
check_dependencies() {
    log info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for docker (required for containerlab)
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check for hping3 (primary traffic generation tool)
    if ! command -v hping3 &> /dev/null; then
        missing_deps+=("hping3")
    fi
    
    # Check for ping (fallback tool)
    if ! command -v ping &> /dev/null; then
        missing_deps+=("ping")
    fi
    
    # Check for yq (YAML parser)
    if ! command -v yq &> /dev/null; then
        log warn "yq not found. YAML parsing will use basic grep/sed."
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log error "Missing required dependencies: ${missing_deps[*]}"
        log error "Please install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker)
                    log error "  - docker: https://docs.docker.com/get-docker/"
                    ;;
                hping3)
                    log error "  - hping3: apt-get install hping3 (Debian/Ubuntu) or yum install hping3 (RHEL/CentOS)"
                    ;;
                ping)
                    log error "  - ping: Usually included with iputils package"
                    ;;
            esac
        done
        return 1
    fi
    
    log info "All dependencies satisfied"
    return 0
}

# Load configuration from YAML file
load_configuration() {
    log info "Loading configuration from: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Parse configuration using grep/sed (fallback if yq not available)
    # Destination configuration
    DESTINATION_IP=$(grep -A 5 "^destination:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
    DESTINATION_PORT=$(grep -A 5 "^destination:" "$CONFIG_FILE" | grep "port:" | awk '{print $2}')
    PROTOCOL=$(grep -A 5 "^destination:" "$CONFIG_FILE" | grep "protocol:" | awk '{print $2}' | tr -d '"')
    
    # Traffic parameters
    if [[ -z "${PACKET_COUNT_OVERRIDE:-}" ]]; then
        PACKET_COUNT=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "count:" | awk '{print $2}')
    fi
    INTERVAL=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "interval:" | awk '{print $2}')
    PACKET_SIZE=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "size:" | awk '{print $2}')
    TTL=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "ttl:" | awk '{print $2}')
    TCP_FLAGS=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "flags:" | awk '{print $2}' | tr -d '"')
    SOURCE_PORT=$(grep -A 3 "^hping3:" "$CONFIG_FILE" | grep "source_port:" | awk '{print $2}')
    
    # Load source hosts
    local in_sources=false
    local current_name=""
    local current_ip=""
    local current_container=""
    local current_enabled=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^sources: ]]; then
            in_sources=true
            continue
        fi
        
        if [[ "$in_sources" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]]; then
                current_name=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*ip: ]]; then
                current_ip=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*container: ]]; then
                current_container=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*enabled: ]]; then
                current_enabled=$(echo "$line" | awk '{print $2}')
                
                # Add to arrays if enabled
                if [[ "$current_enabled" == "true" ]]; then
                    SOURCE_HOSTS["$current_name"]="$current_ip:$current_container"
                    ENABLED_SOURCES+=("$current_name")
                fi
                
                # Reset for next host
                current_name=""
                current_ip=""
                current_container=""
                current_enabled=false
            elif [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            elif [[ "$line" =~ ^[[:alpha:]] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                # End of sources section
                in_sources=false
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Load scenario configuration
    local in_scenarios=false
    local in_target_scenario=false
    local scenario_sources=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^scenarios: ]]; then
            in_scenarios=true
            continue
        fi
        
        if [[ "$in_scenarios" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"?${SCENARIO}\"? ]]; then
                in_target_scenario=true
            elif [[ "$in_target_scenario" == true ]]; then
                if [[ "$line" =~ ^[[:space:]]*sources: ]]; then
                    scenario_sources=$(echo "$line" | sed 's/sources: //' | tr -d '[]"' | tr ',' ' ')
                elif [[ "$line" =~ ^[[:space:]]*duration: ]]; then
                    if [[ -z "${DURATION_OVERRIDE:-}" ]]; then
                        DURATION=$(echo "$line" | awk '{print $2}')
                    fi
                elif [[ "$line" =~ ^[[:space:]]*packet_count: ]]; then
                    if [[ -z "${PACKET_COUNT_OVERRIDE:-}" ]]; then
                        PACKET_COUNT=$(echo "$line" | awk '{print $2}')
                    fi
                elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] && [[ ! "$line" =~ ${SCENARIO} ]]; then
                    in_target_scenario=false
                fi
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Override enabled sources with scenario sources
    if [[ -n "$scenario_sources" ]]; then
        ENABLED_SOURCES=()
        for source in $scenario_sources; do
            ENABLED_SOURCES+=("$source")
        done
    fi
    
    # Set defaults if not found in config
    DESTINATION_IP="${DESTINATION_IP:-192.168.100.10}"
    DESTINATION_PORT="${DESTINATION_PORT:-80}"
    PROTOCOL="${PROTOCOL:-tcp}"
    PACKET_COUNT="${PACKET_COUNT:-1000}"
    INTERVAL="${INTERVAL:-10}"
    PACKET_SIZE="${PACKET_SIZE:-100}"
    TTL="${TTL:-64}"
    TCP_FLAGS="${TCP_FLAGS:-S}"
    DURATION="${DURATION:-60}"
    
    log info "Configuration loaded successfully"
    log debug "Destination: ${DESTINATION_IP}:${DESTINATION_PORT} (${PROTOCOL})"
    log debug "Packet count: ${PACKET_COUNT}, Interval: ${INTERVAL}ms"
    log debug "Enabled sources: ${ENABLED_SOURCES[*]}"
    
    return 0
}

# Check if container is running
check_container_running() {
    local container="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Wait for container to be ready
wait_for_container() {
    local container="$1"
    local timeout="${2:-30}"
    local count=0
    
    log info "Waiting for container $container to be ready..."
    
    while [[ $count -lt $timeout ]]; do
        if check_container_running "$container"; then
            log info "Container $container is ready"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log error "Container $container did not become ready within ${timeout}s"
    return 1
}

# Check network connectivity
check_connectivity() {
    local source_container="$1"
    local destination_ip="$2"
    
    log debug "Checking connectivity from $source_container to $destination_ip"
    
    if docker exec "$source_container" ping -c 1 -W 2 "$destination_ip" &> /dev/null; then
        log debug "Connectivity OK: $source_container -> $destination_ip"
        return 0
    else
        log warn "Connectivity failed: $source_container -> $destination_ip"
        return 1
    fi
}

# Generate traffic using hping3
generate_traffic_hping3() {
    local source_name="$1"
    local source_ip="$2"
    local source_container="$3"
    
    log info "Generating traffic from $source_name ($source_ip) to $DESTINATION_IP:$DESTINATION_PORT"
    
    # Check if container is running
    if ! check_container_running "$source_container"; then
        log error "Container $source_container is not running"
        return 1
    fi
    
    # Check connectivity
    if ! check_connectivity "$source_container" "$DESTINATION_IP"; then
        log error "No connectivity from $source_container to $DESTINATION_IP"
        return 1
    fi
    
    # Build hping3 command
    local hping3_cmd="hping3"
    hping3_cmd+=" -c ${PACKET_COUNT}"
    hping3_cmd+=" -i ${INTERVAL}"
    hping3_cmd+=" -s ${SOURCE_PORT}"
    hping3_cmd+=" -p ${DESTINATION_PORT}"
    hping3_cmd+=" --${TCP_FLAGS}"
    hping3_cmd+=" --ttl ${TTL}"
    hping3_cmd+=" -d ${PACKET_SIZE}"
    hping3_cmd+=" ${DESTINATION_IP}"
    
    log debug "Executing: $hping3_cmd"
    
    # Execute hping3 in container
    if docker exec "$source_container" $hping3_cmd >> "$LOG_FILE" 2>&1; then
        log info "Traffic generation completed from $source_name"
        return 0
    else
        log error "Traffic generation failed from $source_name"
        return 1
    fi
}

# Generate traffic using ping (fallback)
generate_traffic_ping() {
    local source_name="$1"
    local source_ip="$2"
    local source_container="$3"
    
    log info "Generating ICMP traffic from $source_name ($source_ip) to $DESTINATION_IP"
    
    # Check if container is running
    if ! check_container_running "$source_container"; then
        log error "Container $source_container is not running"
        return 1
    fi
    
    # Check connectivity
    if ! check_connectivity "$source_container" "$DESTINATION_IP"; then
        log error "No connectivity from $source_container to $DESTINATION_IP"
        return 1
    fi
    
    # Build ping command
    local ping_cmd="ping"
    ping_cmd+=" -c ${PACKET_COUNT}"
    ping_cmd+=" -i 0.01"
    ping_cmd+=" -s ${PACKET_SIZE}"
    ping_cmd+=" -t ${TTL}"
    ping_cmd+=" ${DESTINATION_IP}"
    
    log debug "Executing: $ping_cmd"
    
    # Execute ping in container
    if docker exec "$source_container" $ping_cmd >> "$LOG_FILE" 2>&1; then
        log info "Traffic generation completed from $source_name"
        return 0
    else
        log error "Traffic generation failed from $source_name"
        return 1
    fi
}

# Generate traffic from all enabled sources
generate_all_traffic() {
    log info "Starting traffic generation for scenario: $SCENARIO"
    log info "Total packets to generate: $((PACKET_COUNT * ${#ENABLED_SOURCES[@]}))"
    
    local success_count=0
    local failure_count=0
    
    for source_name in "${ENABLED_SOURCES[@]}"; do
        local source_info="${SOURCE_HOSTS[$source_name]}"
        local source_ip="${source_info%%:*}"
        local source_container="${source_info##*:}"
        
        log info "Processing source: $source_name ($source_ip)"
        
        # Wait for container to be ready
        if ! wait_for_container "$source_container" 30; then
            log error "Skipping $source_name: container not ready"
            ((failure_count++))
            continue
        fi
        
        # Generate traffic based on protocol
        if [[ "$PROTOCOL" == "tcp" ]] && command -v hping3 &> /dev/null; then
            if generate_traffic_hping3 "$source_name" "$source_ip" "$source_container"; then
                ((success_count++))
            else
                ((failure_count++))
            fi
        else
            log warn "Using ping instead of hping3 (protocol: $PROTOCOL)"
            if generate_traffic_ping "$source_name" "$source_ip" "$source_container"; then
                ((success_count++))
            else
                ((failure_count++))
            fi
        fi
    done
    
    log info "Traffic generation completed"
    log info "Successful sources: $success_count, Failed sources: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        log warn "Some sources failed to generate traffic"
        return 1
    fi
    
    return 0
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Traffic Generation Summary"
    echo "=========================================="
    echo "Scenario: $SCENARIO"
    echo "Destination: ${DESTINATION_IP}:${DESTINATION_PORT} (${PROTOCOL})"
    echo "Packet count per source: $PACKET_COUNT"
    echo "Total packets: $((PACKET_COUNT * ${#ENABLED_SOURCES[@]}))"
    echo "Sources: ${ENABLED_SOURCES[*]}"
    echo "Log file: $LOG_FILE"
    echo "=========================================="
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Load configuration
    if ! load_configuration; then
        exit 1
    fi
    
    # Print summary
    print_summary
    
    # Generate traffic
    if generate_all_traffic; then
        log info "Traffic generation completed successfully"
        exit 0
    else
        log error "Traffic generation completed with errors"
        exit 1
    fi
}

# Execute main function
main "$@"
