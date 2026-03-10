#!/bin/bash
#
# Wait for Container Script
#
# This script waits for one or more containers to be ready and running.
# It checks if containers are running and optionally verifies connectivity.
#
# Reference: Docker CLI documentation
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
#
# Usage:
#   ./wait_for_container.sh [options] [container...]
#
# Options:
#   -t, --timeout SECONDS  Maximum time to wait (default: 60)
#   -i, --interval SECONDS Check interval (default: 1)
#   -c, --check-connectivity Verify network connectivity
#   -v, --verbose          Enable verbose output
#   -h, --help             Show this help message
#
# Examples:
#   ./wait_for_container.sh clab-ecmp-test-h1 clab-ecmp-test-h2
#   ./wait_for_container.sh --timeout 120 --check-connectivity clab-ecmp-test-r1
#   ./wait_for_container.sh clab-ecmp-test-*

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default configuration
TIMEOUT=60
INTERVAL=1
CHECK_CONNECTIVITY=false
VERBOSE=false

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/wait_for_container.log"

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
Usage: $(basename "$0") [options] [container...]

Wait for containers to be ready and running.

Options:
  -t, --timeout SECONDS  Maximum time to wait (default: 60)
  -i, --interval SECONDS Check interval (default: 1)
  -c, --check-connectivity Verify network connectivity
  -v, --verbose          Enable verbose output
  -h, --help             Show this help message

Arguments:
  container              Container name(s) to wait for (supports wildcards)

Examples:
  $(basename "$0") clab-ecmp-test-h1 clab-ecmp-test-h2
  $(basename "$0") --timeout 120 --check-connectivity clab-ecmp-test-r1
  $(basename "$0") clab-ecmp-test-*

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
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -c|--check-connectivity)
                CHECK_CONNECTIVITY=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # Container names
                CONTAINERS+=("$1")
                shift
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

# Check if container exists
container_exists() {
    local container="$1"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Get container status
get_container_status() {
    local container="$1"
    docker ps -a --filter "name=^${container}$" --format '{{.Status}}'
}

# Check container connectivity
check_container_connectivity() {
    local container="$1"
    
    log debug "Checking connectivity for $container"
    
    # Try to execute a simple command in the container
    if docker exec "$container" sh -c "echo 'connectivity test'" &> /dev/null; then
        log debug "Connectivity OK for $container"
        return 0
    else
        log debug "Connectivity failed for $container"
        return 1
    fi
}

# Wait for a single container
wait_for_single_container() {
    local container="$1"
    local timeout="${2:-$TIMEOUT}"
    local interval="${3:-$INTERVAL}"
    
    log info "Waiting for container: $container (timeout: ${timeout}s)"
    
    # Check if container exists
    if ! container_exists "$container"; then
        log error "Container does not exist: $container"
        return 1
    fi
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        # Check if container is running
        if is_container_running "$container"; then
            log info "Container $container is running"
            
            # Check connectivity if requested
            if [[ "$CHECK_CONNECTIVITY" == true ]]; then
                if check_container_connectivity "$container"; then
                    log info "Container $container is ready"
                    return 0
                else
                    log debug "Container $container is running but not yet ready"
                fi
            else
                log info "Container $container is ready"
                return 0
            fi
        else
            local status
            status=$(get_container_status "$container")
            log debug "Container $container status: $status"
        fi
        
        sleep "$interval"
        ((count++))
    done
    
    log error "Container $container did not become ready within ${timeout}s"
    return 1
}

# Wait for multiple containers
wait_for_multiple_containers() {
    local containers=("$@")
    local total=${#containers[@]}
    local ready=0
    local failed=0
    
    log info "Waiting for $total container(s)..."
    
    for container in "${containers[@]}"; do
        if wait_for_single_container "$container"; then
            ((ready++))
        else
            ((failed++))
        fi
    done
    
    log info "Container wait completed: $ready ready, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Expand wildcard container names
expand_container_names() {
    local expanded=()
    
    for pattern in "${CONTAINERS[@]}"; do
        # Check if pattern contains wildcard
        if [[ "$pattern" == *"*"* ]] || [[ "$pattern" == *"?"* ]]; then
            # Expand wildcard
            local matches
            matches=$(docker ps -a --format '{{.Names}}' | grep "^${pattern}$" || true)
            
            if [[ -n "$matches" ]]; then
                while IFS= read -r match; do
                    expanded+=("$match")
                done <<< "$matches"
            else
                log warn "No containers found matching pattern: $pattern"
            fi
        else
            # No wildcard, use as-is
            expanded+=("$pattern")
        fi
    done
    
    # Update CONTAINERS array
    CONTAINERS=("${expanded[@]}")
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if containers were specified
    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        log error "No containers specified"
        usage
        exit 1
    fi
    
    # Expand wildcard container names
    expand_container_names
    
    # Check if any containers to wait for
    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        log error "No containers found to wait for"
        exit 1
    fi
    
    log info "Waiting for ${#CONTAINERS[@]} container(s): ${CONTAINERS[*]}"
    
    # Wait for containers
    if wait_for_multiple_containers "${CONTAINERS[@]}"; then
        log info "All containers are ready"
        exit 0
    else
        log error "Some containers failed to become ready"
        exit 1
    fi
}

# Execute main function
main "$@"
