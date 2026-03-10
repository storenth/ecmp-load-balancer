#!/bin/bash
#
# ECMP Configuration Script for FRRouting
#
# This script configures FRRouting on all routers to implement ECMP with
# Source IP-based hash algorithm for path selection.
#
# Reference: https://docs.frrouting.org/
# Architecture: ARCHITECTURE.md

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/configs/frr"
LOG_FILE="${PROJECT_ROOT}/logs/configure_ecmp.log"

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

# Function to check if topology is deployed
check_topology() {
    info_msg "Checking if topology is deployed..."
    
    if ! docker ps --format '{{.Names}}' | grep -q '^clab-ecmp-test-r1$'; then
        error_exit "Topology is not deployed. Please run ./scripts/deploy_topology.sh first"
    fi
    
    success_msg "Topology is deployed"
}

# Function to wait for FRR daemons to be ready
wait_for_frr() {
    local container="$1"
    local max_attempts=30
    local attempt=0
    
    info_msg "Waiting for FRR daemons in ${container}..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if docker exec "${container}" vtysh -c "show version" &> /dev/null; then
            success_msg "FRR daemons ready in ${container}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    error_exit "FRR daemons not ready in ${container} after ${max_attempts} seconds"
}

# Function to configure edge router (R1) with ECMP
configure_edge_router() {
    info_msg "Configuring edge router (R1) with ECMP..."
    
    local container="clab-ecmp-test-r1"
    
    # Wait for FRR to be ready
    wait_for_frr "${container}"
    
    # Configure FRR using vtysh commands
    docker exec "${container}" vtysh << 'EOF' >> "${LOG_FILE}" 2>&1
configure terminal
!
! Enable OSPF daemon
router ospf
  ospf router-id 10.0.1.1
  network 10.0.1.0/24 area 0
  network 10.0.2.0/24 area 0
  network 10.0.3.0/24 area 0
  network 10.0.4.0/24 area 0
  network 10.0.5.0/24 area 0
  passive-interface eth0
  max-metric router-lsa
!
! Configure static routes for ECMP
ip route 192.168.100.0/24 10.0.2.2 100
ip route 192.168.100.0/24 10.0.3.2 100
ip route 192.168.100.0/24 10.0.4.2 100
ip route 192.168.100.0/24 10.0.5.2 100
!
! Configure ECMP hash algorithm (Source IP only)
! Note: FRRouting uses Linux kernel's ECMP implementation
! The hash algorithm is configured via sysctl
!
line vty
!
end
EOF
    
    # Configure kernel ECMP hash parameters
    docker exec "${container}" sysctl -w net.ipv4.fib_multipath_hash_policy=1 >> "${LOG_FILE}" 2>&1
    docker exec "${container}" sysctl -w net.ipv4.fib_multipath_use_permanent_addr=1 >> "${LOG_FILE}" 2>&1
    
    success_msg "Edge router (R1) configured with ECMP"
}

# Function to configure core routers
configure_core_router() {
    local router_num="$1"
    local container="clab-ecmp-test-r${router_num}"
    local router_id="10.0.$((router_num + 1)).1"
    local source_net="10.0.$((router_num + 1)).0/24"
    local dest_net="10.0.$((router_num + 5)).0/24"
    
    info_msg "Configuring core router (R${router_num})..."
    
    # Wait for FRR to be ready
    wait_for_frr "${container}"
    
    # Configure FRR using vtysh commands
    docker exec "${container}" vtysh << EOF >> "${LOG_FILE}" 2>&1
configure terminal
!
! Enable OSPF daemon
router ospf
  ospf router-id ${router_id}
  network ${source_net} area 0
  network ${dest_net} area 0
!
! Configure static routes
ip route 10.0.1.0/24 10.0.$((router_num + 1)).1
ip route 192.168.100.0/24 10.0.$((router_num + 5)).2
!
line vty
!
end
EOF
    
    success_msg "Core router (R${router_num}) configured"
}

# Function to configure destination router (R6)
configure_destination_router() {
    info_msg "Configuring destination router (R6)..."
    
    local container="clab-ecmp-test-r6"
    
    # Wait for FRR to be ready
    wait_for_frr "${container}"
    
    # Configure FRR using vtysh commands
    docker exec "${container}" vtysh << 'EOF' >> "${LOG_FILE}" 2>&1
configure terminal
!
! Enable OSPF daemon
router ospf
  ospf router-id 192.168.100.1
  network 10.0.6.0/24 area 0
  network 10.0.7.0/24 area 0
  network 10.0.8.0/24 area 0
  network 10.0.9.0/24 area 0
  network 192.168.100.0/24 area 0
  passive-interface eth4
!
! Configure static routes
ip route 10.0.1.0/24 10.0.6.1
ip route 10.0.1.0/24 10.0.7.1
ip route 10.0.1.0/24 10.0.8.1
ip route 10.0.1.0/24 10.0.9.1
!
line vty
!
end
EOF
    
    success_msg "Destination router (R6) configured"
}

# Function to verify ECMP configuration
verify_ecmp() {
    info_msg "Verifying ECMP configuration..."
    
    local container="clab-ecmp-test-r1"
    
    # Check if ECMP routes are present
    info_msg "Checking ECMP routes on edge router..."
    local ecmp_routes=$(docker exec "${container}" vtysh -c "show ip route 192.168.100.0/24" | grep -c "10.0.[2-5].2" || true)
    
    if [[ ${ecmp_routes} -ne 4 ]]; then
        error_exit "Expected 4 ECMP routes, found ${ecmp_routes}"
    fi
    
    success_msg "Found 4 ECMP routes"
    
    # Display ECMP routes
    info_msg "ECMP Routes:"
    docker exec "${container}" vtysh -c "show ip route 192.168.100.0/24" | tee -a "${LOG_FILE}"
    
    # Check kernel ECMP hash configuration
    info_msg "Checking kernel ECMP hash configuration..."
    local hash_policy=$(docker exec "${container}" sysctl -n net.ipv4.fib_multipath_hash_policy)
    
    if [[ ${hash_policy} -ne 1 ]]; then
        warn_msg "ECMP hash policy is ${hash_policy}, expected 1 (Source IP)"
    else
        success_msg "ECMP hash policy set to 1 (Source IP)"
    fi
    
    # Verify connectivity to destination
    info_msg "Verifying connectivity to destination network..."
    if docker exec "${container}" ping -c 1 -W 2 192.168.100.10 &> /dev/null; then
        success_msg "Connectivity to destination verified"
    else
        warn_msg "Cannot reach destination host (192.168.100.10)"
    fi
}

# Function to display ECMP status
display_status() {
    info_msg "ECMP Configuration Status:"
    echo ""
    
    local container="clab-ecmp-test-r1"
    
    echo "=== Edge Router (R1) Routing Table ==="
    docker exec "${container}" vtysh -c "show ip route" | grep -A 10 "192.168.100.0/24" || true
    echo ""
    
    echo "=== Kernel ECMP Configuration ==="
    docker exec "${container}" sysctl net.ipv4.fib_multipath_hash_policy
    docker exec "${container}" sysctl net.ipv4.fib_multipath_use_permanent_addr
    echo ""
    
    echo "=== OSPF Neighbors ==="
    docker exec "${container}" vtysh -c "show ip ospf neighbor" || true
    echo ""
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configure ECMP on the deployed topology using FRRouting.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -s, --skip-verify   Skip configuration verification
    -r, --router N      Configure only router N (1-6)
    -S, --status        Show ECMP status only

EXAMPLES:
    $0                  Configure all routers
    $0 -v               Configure with verbose output
    $0 -r 1             Configure only edge router (R1)
    $0 -S               Show ECMP status

EOF
}

# Main function
main() {
    local skip_verify=false
    local specific_router=""
    local status_only=false
    
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
            -s|--skip-verify)
                skip_verify=true
                shift
                ;;
            -r|--router)
                specific_router="$2"
                shift 2
                ;;
            -S|--status)
                status_only=true
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
    echo "  ECMP Configuration Script"
    echo "=========================================="
    echo ""
    
    # Check if topology is deployed
    check_topology
    
    # Show status only if requested
    if [[ "${status_only}" == true ]]; then
        display_status
        exit 0
    fi
    
    # Configure routers
    if [[ -n "${specific_router}" ]]; then
        case "${specific_router}" in
            1)
                configure_edge_router
                ;;
            2|3|4|5)
                configure_core_router "${specific_router}"
                ;;
            6)
                configure_destination_router
                ;;
            *)
                error_exit "Invalid router number: ${specific_router}. Must be 1-6"
                ;;
        esac
    else
        # Configure all routers
        configure_edge_router
        configure_core_router 2
        configure_core_router 3
        configure_core_router 4
        configure_core_router 5
        configure_destination_router
    fi
    
    # Verify configuration
    if [[ "${skip_verify}" == false ]]; then
        verify_ecmp
    fi
    
    # Display status
    display_status
    
    # Success message
    echo ""
    success_msg "ECMP configuration completed successfully!"
    echo ""
    info_msg "Next steps:"
    echo "  1. Start traffic capture: ./scripts/capture/start_capture.sh"
    echo "  2. Generate test traffic: ./scripts/traffic/generate_traffic.py"
    echo "  3. Analyze results: ./scripts/analysis/ecmp-analyzer.py"
    echo ""
}

# Run main function
main "$@"
