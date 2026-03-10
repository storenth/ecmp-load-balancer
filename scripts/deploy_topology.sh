#!/bin/bash
#
# Containerlab Topology Deployment Script
#
# This script deploys the ECMP testing topology using Containerlab.
# It includes error handling, validation, and status feedback.
#
# Reference: https://containerlab.dev/cmd/deploy/
# Architecture: ARCHITECTURE.md

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOPOLOGY_FILE="${PROJECT_ROOT}/topology/clab-ecmp-test.yml"
LOG_FILE="${PROJECT_ROOT}/logs/deploy_topology.log"
CONTAINERLAB_VERSION="0.50.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Error handling function
error_exit() {
    log "ERROR" "${RED}$1${NC}"
    exit 1
}

# Success message function
success_msg() {
    log "SUCCESS" "${GREEN}$1${NC}"
}

# Info message function
info_msg() {
    log "INFO" "${BLUE}$1${NC}"
}

# Warning message function
warn_msg() {
    log "WARNING" "${YELLOW}$1${NC}"
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "${LOG_FILE}")"

# Function to check if Containerlab is installed
check_containerlab() {
    info_msg "Checking Containerlab installation..."
    
    if ! command -v clab &> /dev/null; then
        error_exit "Containerlab is not installed. Please install it from https://containerlab.dev/install/"
    fi
    
    local version=$(clab version 2>/dev/null | grep -oP 'version: \K[0-9.]+' || echo "unknown")
    info_msg "Containerlab version: ${version}"
    
    success_msg "Containerlab is installed"
}

# Function to check if Docker is running
check_docker() {
    info_msg "Checking Docker daemon..."
    
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running. Please start Docker."
    fi
    
    success_msg "Docker daemon is running"
}

# Function to validate topology file
validate_topology() {
    info_msg "Validating topology file: ${TOPOLOGY_FILE}"
    
    if [[ ! -f "${TOPOLOGY_FILE}" ]]; then
        error_exit "Topology file not found: ${TOPOLOGY_FILE}"
    fi
    
    # Check if YAML is valid (basic syntax check)
    if ! command -v yamllint &> /dev/null; then
        warn_msg "yamllint not installed, skipping YAML syntax validation"
    else
        if ! yamllint "${TOPOLOGY_FILE}" &> /dev/null; then
            error_exit "Topology file has YAML syntax errors"
        fi
    fi
    
    success_msg "Topology file is valid"
}

# Function to check if topology is already deployed
check_existing_topology() {
    info_msg "Checking for existing topology..."
    
    if docker ps -a --format '{{.Names}}' | grep -q '^clab-ecmp-test-'; then
        warn_msg "Existing topology found. Cleaning up..."
        
        # Destroy existing topology
        if ! clab destroy -t "${TOPOLOGY_FILE}" --cleanup >> "${LOG_FILE}" 2>&1; then
            error_exit "Failed to destroy existing topology"
        fi
        
        success_msg "Existing topology cleaned up"
    else
        info_msg "No existing topology found"
    fi
}

# Function to deploy topology
deploy_topology() {
    info_msg "Deploying ECMP topology..."
    
    # Deploy the topology
    if ! clab deploy -t "${TOPOLOGY_FILE}" --reconfigure >> "${LOG_FILE}" 2>&1; then
        error_exit "Failed to deploy topology. Check ${LOG_FILE} for details"
    fi
    
    success_msg "Topology deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    info_msg "Verifying deployment..."
    
    # Check if all containers are running
    local expected_containers=("h1" "h2" "h3" "h4" "r1" "r2" "r3" "r4" "r5" "r6" "d1")
    local running_containers=$(docker ps --format '{{.Names}}' | grep '^clab-ecmp-test-' | sed 's/^clab-ecmp-test-//')
    
    for container in "${expected_containers[@]}"; do
        if ! echo "${running_containers}" | grep -q "^${container}$"; then
            error_exit "Container ${container} is not running"
        fi
    done
    
    success_msg "All containers are running"
    
    # Check network connectivity
    info_msg "Checking network connectivity..."
    
    # Test connectivity from source hosts to edge router
    for i in {1..4}; do
        if ! docker exec "clab-ecmp-test-h${i}" ping -c 1 -W 2 10.0.1.1 &> /dev/null; then
            warn_msg "Host h${i} cannot reach edge router (10.0.1.1)"
        fi
    done
    
    # Test connectivity from edge router to core routers
    for i in {2..5}; do
        local core_ip="10.0.$((i+1)).2"
        if ! docker exec "clab-ecmp-test-r1" ping -c 1 -W 2 "${core_ip}" &> /dev/null; then
            warn_msg "Edge router cannot reach core router r${i} (${core_ip})"
        fi
    done
    
    success_msg "Network connectivity verified"
}

# Function to display topology status
display_status() {
    info_msg "Topology Status:"
    echo ""
    echo "Running Containers:"
    docker ps --filter "name=clab-ecmp-test-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    info_msg "Network Interfaces:"
    docker exec clab-ecmp-test-r1 ip addr show 2>/dev/null || warn_msg "Could not retrieve interface information"
    echo ""
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy the ECMP testing topology using Containerlab.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -s, --skip-checks   Skip pre-deployment checks (not recommended)
    -c, --cleanup       Cleanup existing topology before deployment
    -n, --no-verify     Skip deployment verification

EXAMPLES:
    $0                  Deploy topology with all checks
    $0 -v               Deploy with verbose output
    $0 -c               Cleanup and redeploy topology

EOF
}

# Main function
main() {
    local skip_checks=false
    local cleanup_only=false
    local verify=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -s|--skip-checks)
                skip_checks=true
                shift
                ;;
            -c|--cleanup)
                cleanup_only=true
                shift
                ;;
            -n|--no-verify)
                verify=false
                shift
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
    
    # Print banner
    echo ""
    echo "=========================================="
    echo "  ECMP Topology Deployment Script"
    echo "=========================================="
    echo ""
    
    # Pre-deployment checks
    if [[ "${skip_checks}" == false ]]; then
        check_containerlab
        check_docker
        validate_topology
    fi
    
    # Cleanup existing topology if requested
    if [[ "${cleanup_only}" == true ]]; then
        check_existing_topology
        success_msg "Cleanup complete. Exiting."
        exit 0
    fi
    
    # Check for and cleanup existing topology
    check_existing_topology
    
    # Deploy topology
    deploy_topology
    
    # Verify deployment
    if [[ "${verify}" == true ]]; then
        verify_deployment
    fi
    
    # Display status
    display_status
    
    # Success message
    echo ""
    success_msg "ECMP topology deployed successfully!"
    echo ""
    info_msg "Next steps:"
    echo "  1. Configure ECMP: ./scripts/configure_ecmp.sh"
    echo "  2. Start traffic capture: ./scripts/capture/start_capture.sh"
    echo "  3. Generate test traffic: ./scripts/traffic/generate_traffic.py"
    echo "  4. Analyze results: ./scripts/analysis/ecmp-analyzer.py"
    echo ""
    info_msg "To destroy the topology: clab destroy -t ${TOPOLOGY_FILE}"
    echo ""
}

# Run main function
main "$@"
