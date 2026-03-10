#!/bin/bash
#
# Implementation Validation Script
#
# This script validates the syntax and structure of all implementation files.
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
total_checks=0
passed_checks=0
failed_checks=0

# Function to print test result
print_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    total_checks=$((total_checks + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        passed_checks=$((passed_checks + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        failed_checks=$((failed_checks + 1))
    fi
}

echo "=========================================="
echo "  Implementation Validation"
echo "=========================================="
echo ""

# Check if required files exist
echo "Checking file existence..."

files=(
    "topology/clab-ecmp-test.yml"
    "scripts/deploy_topology.sh"
    "scripts/configure_ecmp.sh"
    "configs/frr/r1/frr.conf"
    "configs/frr/r1/daemons"
    "configs/frr/r1/vtysh.conf"
    "configs/frr/r2/frr.conf"
    "configs/frr/r2/daemons"
    "configs/frr/r2/vtysh.conf"
    "configs/frr/r3/frr.conf"
    "configs/frr/r3/daemons"
    "configs/frr/r3/vtysh.conf"
    "configs/frr/r4/frr.conf"
    "configs/frr/r4/daemons"
    "configs/frr/r4/vtysh.conf"
    "configs/frr/r5/frr.conf"
    "configs/frr/r5/daemons"
    "configs/frr/r5/vtysh.conf"
    "configs/frr/r6/frr.conf"
    "configs/frr/r6/daemons"
    "configs/frr/r6/vtysh.conf"
    "configs/hosts/h1.sh"
    "configs/hosts/h2.sh"
    "configs/hosts/h3.sh"
    "configs/hosts/h4.sh"
    "configs/hosts/d1.sh"
)

for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        print_result "File exists: $file" "PASS"
    else
        print_result "File exists: $file" "FAIL" "File not found"
    fi
done

echo ""
echo "Checking script executability..."

scripts=(
    "scripts/deploy_topology.sh"
    "scripts/configure_ecmp.sh"
    "configs/hosts/h1.sh"
    "configs/hosts/h2.sh"
    "configs/hosts/h3.sh"
    "configs/hosts/h4.sh"
    "configs/hosts/d1.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        print_result "Script executable: $script" "PASS"
    else
        print_result "Script executable: $script" "FAIL" "Not executable"
    fi
done

echo ""
echo "Checking shell script syntax..."

for script in "${scripts[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        print_result "Shell syntax: $script" "PASS"
    else
        print_result "Shell syntax: $script" "FAIL" "Syntax error"
    fi
done

echo ""
echo "Checking YAML syntax..."

yaml_files=(
    "topology/clab-ecmp-test.yml"
)

for yaml_file in "${yaml_files[@]}"; do
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            print_result "YAML syntax: $yaml_file" "PASS"
        else
            print_result "YAML syntax: $yaml_file" "FAIL" "Invalid YAML"
        fi
    else
        print_result "YAML syntax: $yaml_file" "WARN" "Python3 not available for validation"
    fi
done

echo ""
echo "Checking FRR configuration syntax..."

frr_configs=(
    "configs/frr/r1/frr.conf"
    "configs/frr/r2/frr.conf"
    "configs/frr/r3/frr.conf"
    "configs/frr/r4/frr.conf"
    "configs/frr/r5/frr.conf"
    "configs/frr/r6/frr.conf"
)

for config in "${frr_configs[@]}"; do
    # Basic checks for FRR config
    if grep -q "frr version" "$config" && grep -q "hostname" "$config"; then
        print_result "FRR config structure: $config" "PASS"
    else
        print_result "FRR config structure: $config" "FAIL" "Missing required directives"
    fi
done

echo ""
echo "Checking daemon configuration..."

daemon_files=(
    "configs/frr/r1/daemons"
    "configs/frr/r2/daemons"
    "configs/frr/r3/daemons"
    "configs/frr/r4/daemons"
    "configs/frr/r5/daemons"
    "configs/frr/r6/daemons"
)

for daemon_file in "${daemon_files[@]}"; do
    if grep -q "zebra=yes" "$daemon_file" && grep -q "ospfd=yes" "$daemon_file"; then
        print_result "Daemon config: $daemon_file" "PASS"
    else
        print_result "Daemon config: $daemon_file" "FAIL" "Missing required daemons"
    fi
done

echo ""
echo "Checking topology YAML structure..."

topology_file="topology/clab-ecmp-test.yml"

# Check for required sections
required_sections=("name:" "topology:" "nodes:" "links:")
for section in "${required_sections[@]}"; do
    if grep -q "^${section}" "$topology_file" || grep -q "  ${section}" "$topology_file"; then
        print_result "Topology section: $section" "PASS"
    else
        print_result "Topology section: $section" "FAIL" "Section not found"
    fi
done

# Check for required nodes (with 4-space indentation)
required_nodes=("h1:" "h2:" "h3:" "h4:" "r1:" "r2:" "r3:" "r4:" "r5:" "r6:" "d1:")
for node in "${required_nodes[@]}"; do
    if grep -q "^    ${node}" "$topology_file"; then
        print_result "Topology node: $node" "PASS"
    else
        print_result "Topology node: $node" "FAIL" "Node not found"
    fi
done

echo ""
echo "=========================================="
echo "  Validation Summary"
echo "=========================================="
echo "Total checks: $total_checks"
echo -e "${GREEN}Passed: $passed_checks${NC}"
if [[ $failed_checks -gt 0 ]]; then
    echo -e "${RED}Failed: $failed_checks${NC}"
else
    echo -e "${GREEN}Failed: $failed_checks${NC}"
fi
echo ""

if [[ $failed_checks -eq 0 ]]; then
    echo -e "${GREEN}All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some validation checks failed. Please review the output above.${NC}"
    exit 1
fi
