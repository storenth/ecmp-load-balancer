#!/bin/bash
#
# Traffic Capture Script for ECMP Hash Testing
#
# This script captures traffic on each ECMP path using tcpdump at monitoring
# points on core routers (r2-r5) for traffic analysis.
#
# Reference: https://www.tcpdump.org/manpages/tcpdump.1.html
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
# Best Practices: RFC 791 (Internet Protocol), RFC 792 (ICMP)
#
# Usage:
#   ./capture_traffic.sh [options]
#
# Options:
#   -c, --config FILE      Path to traffic configuration file (default: configs/traffic/traffic_config.yaml)
#   -d, --duration SECONDS Capture duration in seconds (overrides config)
#   -o, --output DIR       Output directory for capture files (overrides config)
#   -f, --filter FILTER    BPF filter for packet capture (overrides config)
#   -v, --verbose          Enable verbose output
#   -h, --help             Show this help message
#
# Examples:
#   ./capture_traffic.sh
#   ./capture_traffic.sh --duration 120
#   ./capture_traffic.sh --output /tmp/captures

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/configs/traffic/traffic_config.yaml"
VERBOSE=false
DRY_RUN=false

# Capture parameters (will be loaded from config)
CAPTURE_DURATION=70
BUFFER_SIZE=100
CAPTURE_FILTER=""
OUTPUT_DIR="${PROJECT_ROOT}/captures"
FILE_PATTERN="{test_name}_{path_name}_{timestamp}.pcap"

# Capture paths
declare -A CAPTURE_PATHS
declare -a ENABLED_PATHS

# Process tracking
declare -A CAPTURE_PIDS
declare -a CAPTURE_FILES

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/capture_traffic.log"
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

Capture traffic on ECMP paths using tcpdump for analysis.

Options:
  -c, --config FILE      Path to traffic configuration file
                         (default: configs/traffic/traffic_config.yaml)
  -d, --duration SECONDS Capture duration in seconds (overrides config)
  -o, --output DIR       Output directory for capture files (overrides config)
  -f, --filter FILTER    BPF filter for packet capture (overrides config)
  -v, --verbose          Enable verbose output
  -h, --help             Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --duration 120
  $(basename "$0") --output /tmp/captures

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
            -d|--duration)
                CAPTURE_DURATION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--filter)
                CAPTURE_FILTER="$2"
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
    
    # Check for tcpdump (required for packet capture)
    if ! command -v tcpdump &> /dev/null; then
        missing_deps+=("tcpdump")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log error "Missing required dependencies: ${missing_deps[*]}"
        log error "Please install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker)
                    log error "  - docker: https://docs.docker.com/get-docker/"
                    ;;
                tcpdump)
                    log error "  - tcpdump: apt-get install tcpdump (Debian/Ubuntu) or yum install tcpdump (RHEL/CentOS)"
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
    
    # Parse configuration using grep/sed
    # Capture parameters
    if [[ -z "${CAPTURE_DURATION_OVERRIDE:-}" ]]; then
        CAPTURE_DURATION=$(grep -A 10 "^capture:" "$CONFIG_FILE" | grep "duration:" | awk '{print $2}')
    fi
    BUFFER_SIZE=$(grep -A 10 "^capture:" "$CONFIG_FILE" | grep "buffer_size:" | awk '{print $2}')
    
    # Capture filter
    if [[ -z "${CAPTURE_FILTER_OVERRIDE:-}" ]]; then
        CAPTURE_FILTER=$(grep -A 10 "^capture:" "$CONFIG_FILE" | grep "filter:" | awk -F': ' '{print $2}' | tr -d '"')
    fi
    
    # Output directory
    if [[ -z "${OUTPUT_DIR_OVERRIDE:-}" ]]; then
        OUTPUT_DIR=$(grep -A 10 "^capture:" "$CONFIG_FILE" | grep "output_dir:" | awk '{print $2}' | tr -d '"')
    fi
    
    # File pattern
    FILE_PATTERN=$(grep -A 10 "^capture:" "$CONFIG_FILE" | grep "file_pattern:" | awk '{print $2}' | tr -d '"')
    
    # Load capture paths
    local in_paths=false
    local current_name=""
    local current_router=""
    local current_container=""
    local current_interface=""
    local current_description=""
    local current_enabled=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^paths: ]]; then
            in_paths=true
            continue
        fi
        
        if [[ "$in_paths" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]]; then
                current_name=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*router: ]]; then
                current_router=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*container: ]]; then
                current_container=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*interface: ]]; then
                current_interface=$(echo "$line" | awk '{print $2}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*description: ]]; then
                current_description=$(echo "$line" | awk '{for(i=2;i<=NF;i++) printf $i" "; print ""}' | tr -d '"')
            elif [[ "$line" =~ ^[[:space:]]*enabled: ]]; then
                current_enabled=$(echo "$line" | awk '{print $2}')
                
                # Add to arrays if enabled
                if [[ "$current_enabled" == "true" ]]; then
                    CAPTURE_PATHS["$current_name"]="${current_router}:${current_container}:${current_interface}:${current_description}"
                    ENABLED_PATHS+=("$current_name")
                fi
                
                # Reset for next path
                current_name=""
                current_router=""
                current_container=""
                current_interface=""
                current_description=""
                current_enabled=false
            elif [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            elif [[ "$line" =~ ^[[:alpha:]] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                # End of paths section
                in_paths=false
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Set defaults if not found in config
    CAPTURE_DURATION="${CAPTURE_DURATION:-70}"
    BUFFER_SIZE="${BUFFER_SIZE:-100}"
    CAPTURE_FILTER="${CAPTURE_FILTER:-host 192.168.100.10 and (tcp port 80 or icmp)}"
    OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/captures}"
    FILE_PATTERN="${FILE_PATTERN:-{test_name}_{path_name}_{timestamp}.pcap}"
    
    log info "Configuration loaded successfully"
    log debug "Capture duration: ${CAPTURE_DURATION}s"
    log debug "Capture filter: ${CAPTURE_FILTER}"
    log debug "Output directory: ${OUTPUT_DIR}"
    log debug "Enabled paths: ${ENABLED_PATHS[*]}"
    
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

# Check if tcpdump is available in container
check_tcpdump_in_container() {
    local container="$1"
    
    if docker exec "$container" which tcpdump &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install tcpdump in container if not available
install_tcpdump_in_container() {
    local container="$1"
    
    log info "Installing tcpdump in container $container..."
    
    # Try to install based on container OS
    if docker exec "$container" apk --version &> /dev/null; then
        # Alpine Linux
        docker exec "$container" apk add --no-cache tcpdump >> "$LOG_FILE" 2>&1
    elif docker exec "$container" apt-get --version &> /dev/null; then
        # Debian/Ubuntu
        docker exec "$container" apt-get update -qq >> "$LOG_FILE" 2>&1
        docker exec "$container" apt-get install -y tcpdump >> "$LOG_FILE" 2>&1
    elif docker exec "$container" yum --version &> /dev/null; then
        # RHEL/CentOS
        docker exec "$container" yum install -y tcpdump >> "$LOG_FILE" 2>&1
    else
        log error "Unable to install tcpdump in container $container (unknown OS)"
        return 1
    fi
    
    # Verify installation
    if check_tcpdump_in_container "$container"; then
        log info "tcpdump installed successfully in $container"
        return 0
    else
        log error "Failed to install tcpdump in container $container"
        return 1
    fi
}

# Generate capture filename
generate_capture_filename() {
    local path_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    
    local filename="${FILE_PATTERN}"
    filename="${filename//\{test_name\}/ecmp-test}"
    filename="${filename//\{path_name\}/${path_name}}"
    filename="${filename//\{timestamp\}/${timestamp}}"
    
    echo "${OUTPUT_DIR}/${filename}"
}

# Start tcpdump capture on a specific path
start_capture() {
    local path_name="$1"
    local path_info="${CAPTURE_PATHS[$path_name]}"
    local router="${path_info%%:*}"
    local rest="${path_info#*:}"
    local container="${rest%%:*}"
    local rest="${rest#*:}"
    local interface="${rest%%:*}"
    local description="${rest#*:}"
    
    log info "Starting capture on $path_name ($description)"
    log debug "Container: $container, Interface: $interface"
    
    # Check if container is running
    if ! check_container_running "$container"; then
        log error "Container $container is not running"
        return 1
    fi
    
    # Wait for container to be ready
    if ! wait_for_container "$container" 30; then
        log error "Failed to wait for container $container"
        return 1
    fi
    
    # Check/install tcpdump in container
    if ! check_tcpdump_in_container "$container"; then
        log warn "tcpdump not found in $container, attempting to install..."
        if ! install_tcpdump_in_container "$container"; then
            log error "Cannot start capture without tcpdump in $container"
            return 1
        fi
    fi
    
    # Generate capture filename
    local capture_file
    capture_file=$(generate_capture_filename "$path_name")
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Build tcpdump command
    # Reference: https://www.tcpdump.org/manpages/tcpdump.1.html
    local tcpdump_cmd="tcpdump"
    tcpdump_cmd+=" -i ${interface}"
    tcpdump_cmd+=" -w ${capture_file}"
    tcpdump_cmd+=" -B ${BUFFER_SIZE}"
    tcpdump_cmd+=" '${CAPTURE_FILTER}'"
    
    log debug "Executing: $tcpdump_cmd"
    
    # Start tcpdump in background
    if [[ "$DRY_RUN" == true ]]; then
        log info "[DRY RUN] Would start capture on $path_name"
        CAPTURE_FILES+=("$capture_file")
        return 0
    fi
    
    # Execute tcpdump in container in background
    docker exec -d "$container" sh -c "$tcpdump_cmd" >> "$LOG_FILE" 2>&1
    local capture_pid=$?
    
    if [[ $capture_pid -eq 0 ]]; then
        # Get the actual tcpdump PID in the container
        local actual_pid
        actual_pid=$(docker exec "$container" pgrep tcpdump | tail -1)
        
        CAPTURE_PIDS["$path_name"]="${container}:${actual_pid}"
        CAPTURE_FILES+=("$capture_file")
        
        log info "Capture started on $path_name (PID: $actual_pid, File: $capture_file)"
        return 0
    else
        log error "Failed to start capture on $path_name"
        return 1
    fi
}

# Start captures on all enabled paths
start_all_captures() {
    log info "Starting traffic captures on all ECMP paths"
    
    local success_count=0
    local failure_count=0
    
    for path_name in "${ENABLED_PATHS[@]}"; do
        if start_capture "$path_name"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    log info "Capture startup completed"
    log info "Successful captures: $success_count, Failed captures: $failure_count"
    
    if [[ $failure_count -gt 0 ]]; then
        log warn "Some captures failed to start"
        return 1
    fi
    
    return 0
}

# Stop tcpdump capture on a specific path
stop_capture() {
    local path_name="$1"
    local pid_info="${CAPTURE_PIDS[$path_name]:-}"
    
    if [[ -z "$pid_info" ]]; then
        log warn "No capture PID found for $path_name"
        return 0
    fi
    
    local container="${pid_info%%:*}"
    local pid="${pid_info##*:}"
    
    log info "Stopping capture on $path_name (PID: $pid)"
    
    if [[ "$DRY_RUN" == true ]]; then
        log info "[DRY RUN] Would stop capture on $path_name"
        return 0
    fi
    
    # Kill tcpdump process in container
    if docker exec "$container" kill -SIGTERM "$pid" >> "$LOG_FILE" 2>&1; then
        log info "Capture stopped on $path_name"
        return 0
    else
        log error "Failed to stop capture on $path_name"
        return 1
    fi
}

# Stop all captures
stop_all_captures() {
    log info "Stopping all traffic captures"
    
    local success_count=0
    local failure_count=0
    
    for path_name in "${!CAPTURE_PIDS[@]}"; do
        if stop_capture "$path_name"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    log info "Capture stop completed"
    log info "Successful stops: $success_count, Failed stops: $failure_count"
    
    return 0
}

# Wait for captures to complete
wait_for_captures() {
    local duration="${1:-$CAPTURE_DURATION}"
    
    log info "Waiting for captures to complete (${duration}s)..."
    
    local remaining=$duration
    while [[ $remaining -gt 0 ]]; do
        if [[ $((remaining % 10)) -eq 0 ]] || [[ $remaining -le 5 ]]; then
            log info "Capture time remaining: ${remaining}s"
        fi
        sleep 1
        ((remaining--))
    done
    
    log info "Capture duration completed"
}

# Verify capture files
verify_captures() {
    log info "Verifying capture files..."
    
    local valid_count=0
    local invalid_count=0
    
    for capture_file in "${CAPTURE_FILES[@]}"; do
        if [[ -f "$capture_file" ]]; then
            local file_size
            file_size=$(stat -f%z "$capture_file" 2>/dev/null || stat -c%s "$capture_file" 2>/dev/null)
            
            if [[ $file_size -gt 0 ]]; then
                log info "Valid capture file: $capture_file (${file_size} bytes)"
                ((valid_count++))
            else
                log warn "Empty capture file: $capture_file"
                ((invalid_count++))
            fi
        else
            log error "Capture file not found: $capture_file"
            ((invalid_count++))
        fi
    done
    
    log info "Capture verification completed"
    log info "Valid files: $valid_count, Invalid files: $invalid_count"
    
    if [[ $invalid_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Traffic Capture Summary"
    echo "=========================================="
    echo "Capture duration: ${CAPTURE_DURATION}s"
    echo "Capture filter: ${CAPTURE_FILTER}"
    echo "Output directory: ${OUTPUT_DIR}"
    echo "Enabled paths: ${ENABLED_PATHS[*]}"
    echo "Capture files: ${#CAPTURE_FILES[@]}"
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
    
    # Start all captures
    if ! start_all_captures; then
        log error "Failed to start all captures"
        exit 1
    fi
    
    # Wait for captures to complete
    wait_for_captures
    
    # Stop all captures
    stop_all_captures
    
    # Verify capture files
    if verify_captures; then
        log info "Traffic capture completed successfully"
        exit 0
    else
        log error "Traffic capture completed with errors"
        exit 1
    fi
}

# Execute main function
main "$@"
