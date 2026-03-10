#!/bin/bash
#
# Test Execution Script for ECMP Hash Testing
#
# This script orchestrates the complete test execution including:
# - Starting traffic captures on all paths
# - Generating traffic from source hosts
# - Stopping captures after test completion
# - Organizing captured data for analysis
#
# Reference: ARCHITECTURE.md - Testing Framework Architecture
# Best Practices: RFC 2544 benchmarking methodology
#
# Usage:
#   ./run_test.sh [options]
#
# Options:
#   -c, --config FILE      Path to traffic configuration file (default: configs/traffic/traffic_config.yaml)
#   -s, --scenario NAME    Test scenario to execute (default: basic_distribution)
#   -d, --duration SECONDS Test duration in seconds (overrides config)
#   -n, --count NUM        Number of packets per source (overrides config)
#   -o, --output DIR       Output directory for test results (overrides config)
#   --no-cleanup           Skip cleanup after test completion
#   --preserve-captures    Preserve capture files (default: true)
#   -v, --verbose          Enable verbose output
#   -h, --help             Show this help message
#
# Examples:
#   ./run_test.sh
#   ./run_test.sh --scenario high_volume
#   ./run_test.sh --duration 120 --count 5000

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/configs/traffic/traffic_config.yaml"
SCENARIO="basic_distribution"
VERBOSE=false
CLEANUP=true
PRESERVE_CAPTURES=true

# Test parameters
TEST_DURATION=""
PACKET_COUNT=""
OUTPUT_DIR="${PROJECT_ROOT}/results"

# Script paths
CAPTURE_SCRIPT="${SCRIPT_DIR}/capture_traffic.sh"
TRAFFIC_SCRIPT="${SCRIPT_DIR}/generate_traffic.sh"
HELPER_DIR="${SCRIPT_DIR}/helpers"

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/test_execution.log"
TEST_ID=""
TEST_START_TIME=""
TEST_END_TIME=""

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

Orchestrate complete ECMP hash test execution.

Options:
  -c, --config FILE      Path to traffic configuration file
                         (default: configs/traffic/traffic_config.yaml)
  -s, --scenario NAME    Test scenario to execute
                         (default: basic_distribution)
  -d, --duration SECONDS Test duration in seconds (overrides config)
  -n, --count NUM        Number of packets per source (overrides config)
  -o, --output DIR       Output directory for test results (overrides config)
  --no-cleanup           Skip cleanup after test completion
  --preserve-captures    Preserve capture files (default: true)
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
                TEST_DURATION="$2"
                shift 2
                ;;
            -n|--count)
                PACKET_COUNT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --preserve-captures)
                PRESERVE_CAPTURES=true
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
            *)
                log error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if required scripts are available
check_dependencies() {
    log info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for capture script
    if [[ ! -f "$CAPTURE_SCRIPT" ]]; then
        missing_deps+=("capture_traffic.sh")
    fi
    
    # Check for traffic generation script
    if [[ ! -f "$TRAFFIC_SCRIPT" ]]; then
        missing_deps+=("generate_traffic.sh")
    fi
    
    # Check for helper scripts
    if [[ -d "$HELPER_DIR" ]]; then
        if [[ ! -f "${HELPER_DIR}/wait_for_container.sh" ]]; then
            log warn "wait_for_container.sh not found in helpers directory"
        fi
        if [[ ! -f "${HELPER_DIR}/check_connectivity.sh" ]]; then
            log warn "check_connectivity.sh not found in helpers directory"
        fi
        if [[ ! -f "${HELPER_DIR}/cleanup_captures.sh" ]]; then
            log warn "cleanup_captures.sh not found in helpers directory"
        fi
    else
        log warn "Helper scripts directory not found: $HELPER_DIR"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log error "Missing required scripts: ${missing_deps[*]}"
        return 1
    fi
    
    log info "All dependencies satisfied"
    return 0
}

# Generate unique test ID
generate_test_id() {
    TEST_ID="ecmp-test-$(date '+%Y%m%d-%H%M%S')-${SCENARIO}"
    log info "Test ID: $TEST_ID"
}

# Create test output directory
create_test_directory() {
    local test_dir="${OUTPUT_DIR}/${TEST_ID}"
    
    log info "Creating test directory: $test_dir"
    
    mkdir -p "$test_dir"
    mkdir -p "${test_dir}/captures"
    mkdir -p "${test_dir}/logs"
    mkdir -p "${test_dir}/metadata"
    
    # Create test metadata file
    local metadata_file="${test_dir}/metadata/test_info.json"
    cat > "$metadata_file" << EOF
{
  "test_id": "$TEST_ID",
  "scenario": "$SCENARIO",
  "start_time": "$TEST_START_TIME",
  "config_file": "$CONFIG_FILE",
  "capture_script": "$CAPTURE_SCRIPT",
  "traffic_script": "$TRAFFIC_SCRIPT"
}
EOF
    
    log info "Test directory created successfully"
}

# Check if topology is deployed
check_topology() {
    log info "Checking if ECMP topology is deployed..."
    
    # Check for containerlab topology
    if docker ps --format '{{.Names}}' | grep -q "clab-ecmp-test"; then
        log info "ECMP topology is deployed"
        return 0
    else
        log error "ECMP topology is not deployed"
        log error "Please deploy the topology first using: ./scripts/deploy_topology.sh"
        return 1
    fi
}

# Wait for all containers to be ready
wait_for_topology() {
    log info "Waiting for all containers to be ready..."
    
    local containers=(
        "clab-ecmp-test-h1"
        "clab-ecmp-test-h2"
        "clab-ecmp-test-h3"
        "clab-ecmp-test-h4"
        "clab-ecmp-test-r1"
        "clab-ecmp-test-r2"
        "clab-ecmp-test-r3"
        "clab-ecmp-test-r4"
        "clab-ecmp-test-r5"
        "clab-ecmp-test-r6"
        "clab-ecmp-test-d1"
    )
    
    local ready_count=0
    local timeout=60
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        ready_count=0
        for container in "${containers[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                ((ready_count++))
            fi
        done
        
        if [[ $ready_count -eq ${#containers[@]} ]]; then
            log info "All containers are ready (${ready_count}/${#containers[@]})"
            return 0
        fi
        
        if [[ $((count % 10)) -eq 0 ]]; then
            log info "Waiting for containers: ${ready_count}/${#containers[@]} ready"
        fi
        
        sleep 1
        ((count++))
    done
    
    log error "Timeout waiting for containers to be ready"
    return 1
}

# Start traffic captures
start_captures() {
    log info "Starting traffic captures..."
    
    local capture_args=(
        "--config" "$CONFIG_FILE"
    )
    
    if [[ -n "$TEST_DURATION" ]]; then
        capture_args+=("--duration" "$TEST_DURATION")
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        capture_args+=("--verbose")
    fi
    
    # Execute capture script
    if bash "$CAPTURE_SCRIPT" "${capture_args[@]}"; then
        log info "Traffic captures started successfully"
        return 0
    else
        log error "Failed to start traffic captures"
        return 1
    fi
}

# Generate traffic
generate_traffic() {
    log info "Generating test traffic..."
    
    local traffic_args=(
        "--config" "$CONFIG_FILE"
        "--scenario" "$SCENARIO"
    )
    
    if [[ -n "$TEST_DURATION" ]]; then
        traffic_args+=("--duration" "$TEST_DURATION")
    fi
    
    if [[ -n "$PACKET_COUNT" ]]; then
        traffic_args+=("--count" "$PACKET_COUNT")
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        traffic_args+=("--verbose")
    fi
    
    # Execute traffic generation script
    if bash "$TRAFFIC_SCRIPT" "${traffic_args[@]}"; then
        log info "Traffic generation completed successfully"
        return 0
    else
        log error "Traffic generation failed"
        return 1
    fi
}

# Organize captured data
organize_captures() {
    log info "Organizing captured data..."
    
    local test_dir="${OUTPUT_DIR}/${TEST_ID}"
    local captures_dir="${PROJECT_ROOT}/captures"
    
    if [[ ! -d "$captures_dir" ]]; then
        log warn "No captures directory found: $captures_dir"
        return 0
    fi
    
    # Move capture files to test directory
    if [[ -d "${test_dir}/captures" ]]; then
        if ls "$captures_dir"/*.pcap 1> /dev/null 2>&1; then
            mv "$captures_dir"/*.pcap "${test_dir}/captures/" 2>/dev/null || true
            log info "Moved capture files to test directory"
        else
            log warn "No capture files found in $captures_dir"
        fi
    fi
    
    # Copy log files to test directory
    if [[ -d "${test_dir}/logs" ]]; then
        cp "$LOG_FILE" "${test_dir}/logs/" 2>/dev/null || true
        cp "${PROJECT_ROOT}/logs/traffic_generation.log" "${test_dir}/logs/" 2>/dev/null || true
        cp "${PROJECT_ROOT}/logs/capture_traffic.log" "${test_dir}/logs/" 2>/dev/null || true
        log info "Copied log files to test directory"
    fi
    
    # Generate capture summary
    local summary_file="${test_dir}/metadata/capture_summary.txt"
    {
        echo "Capture Summary"
        echo "==============="
        echo "Test ID: $TEST_ID"
        echo "Scenario: $SCENARIO"
        echo "Start Time: $TEST_START_TIME"
        echo "End Time: $TEST_END_TIME"
        echo ""
        echo "Capture Files:"
        if [[ -d "${test_dir}/captures" ]]; then
            ls -lh "${test_dir}/captures/"/*.pcap 2>/dev/null || echo "No capture files"
        fi
    } > "$summary_file"
    
    log info "Captured data organized successfully"
}

# Cleanup temporary files
cleanup() {
    if [[ "$CLEANUP" == false ]]; then
        log info "Skipping cleanup (--no-cleanup specified)"
        return 0
    fi
    
    log info "Performing cleanup..."
    
    # Stop any running tcpdump processes
    local containers
    containers=$(docker ps --format '{{.Names}}' | grep "clab-ecmp-test-r[2-5]" || true)
    
    for container in $containers; do
        if docker exec "$container" pgrep tcpdump &> /dev/null; then
            log info "Stopping tcpdump in $container"
            docker exec "$container" pkill tcpdump >> "$LOG_FILE" 2>&1 || true
        fi
    done
    
    # Clean up temporary files if not preserving captures
    if [[ "$PRESERVE_CAPTURES" == false ]]; then
        log info "Removing temporary capture files"
        rm -rf "${PROJECT_ROOT}/captures"/*.pcap 2>/dev/null || true
    fi
    
    log info "Cleanup completed"
}

# Print test summary
print_summary() {
    local test_dir="${OUTPUT_DIR}/${TEST_ID}"
    local duration
    duration=$((TEST_END_TIME - TEST_START_TIME))
    
    echo ""
    echo "=========================================="
    echo "ECMP Hash Test Summary"
    echo "=========================================="
    echo "Test ID: $TEST_ID"
    echo "Scenario: $SCENARIO"
    echo "Start Time: $(date -r "$TEST_START_TIME" '+%Y-%m-%d %H:%M:%S')"
    echo "End Time: $(date -r "$TEST_END_TIME" '+%Y-%m-%d %H:%M:%S')"
    echo "Duration: ${duration}s"
    echo "Test Directory: $test_dir"
    echo "Log File: $LOG_FILE"
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
    
    # Generate test ID
    generate_test_id
    
    # Record start time
    TEST_START_TIME=$(date +%s)
    
    # Create test directory
    create_test_directory
    
    # Check if topology is deployed
    if ! check_topology; then
        exit 1
    fi
    
    # Wait for topology to be ready
    if ! wait_for_topology; then
        exit 1
    fi
    
    # Start traffic captures
    if ! start_captures; then
        cleanup
        exit 1
    fi
    
    # Generate traffic
    if ! generate_traffic; then
        cleanup
        exit 1
    fi
    
    # Record end time
    TEST_END_TIME=$(date +%s)
    
    # Organize captured data
    organize_captures
    
    # Cleanup
    cleanup
    
    # Print summary
    print_summary
    
    log info "Test execution completed successfully"
    exit 0
}

# Execute main function
main "$@"
