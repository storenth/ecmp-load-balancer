#!/bin/bash

################################################################################
# Results Analyzer for ECMP Testing
#
# This script parses tcpdump capture files from all ECMP paths, extracts packet
# counts, computes distribution statistics, performs statistical tests, and
# generates detailed analysis reports.
#
# References:
# - tcpdump/libpcap: https://www.tcpdump.org/
# - Statistical tests: https://docs.scipy.org/doc/scipy/reference/stats.html
# - ECMP analysis: RFC 2992 (Analysis of an Equal-Cost Multi-Path Algorithm)
# - Statistical significance: RFC 2330 (Framework for IP Performance Metrics)
#
# Author: ECMP Testing Framework
# Version: 1.0.0
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source helper scripts
source "${SCRIPT_DIR}/helpers/statistical_analysis.sh"
source "${SCRIPT_DIR}/helpers/generate_report.sh"

# Source logging utilities if available
if [[ -f "${SCRIPT_DIR}/helpers/logging.sh" ]]; then
    source "${SCRIPT_DIR}/helpers/logging.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*"; }
fi

################################################################################
# Configuration
################################################################################

# Directory configuration
CAPTURES_DIR="${PROJECT_ROOT}/results/captures"
ANALYSIS_DIR="${PROJECT_ROOT}/results/analysis"
REPORTS_DIR="${PROJECT_ROOT}/results/reports"
ALLURE_RESULTS_DIR="${PROJECT_ROOT}/results/allure-results"

# Create directories if they don't exist
mkdir -p "${CAPTURES_DIR}"
mkdir -p "${ANALYSIS_DIR}"
mkdir -p "${REPORTS_DIR}"
mkdir -p "${ALLURE_RESULTS_DIR}"

# ECMP path configuration
ECMP_PATHS=("r1" "r2" "r3" "r4")
NUM_PATHS=${#ECMP_PATHS[@]}

# Test configuration
TEST_ID="${TEST_ID:-$(date +%Y%m%d_%H%M%S)}"
TEST_NAME="${TEST_NAME:-ECMP Hash Distribution Test}"
TEST_SCENARIO="${TEST_SCENARIO:-Source IP-based ECMP Hash}"

# Traffic filter (adjust based on your test traffic)
TRAFFIC_FILTER="${TRAFFIC_FILTER:-ip and not icmp}"

# Analysis thresholds
MIN_PACKETS_PER_PATH="${MIN_PACKETS_PER_PATH:-100}"
MAX_VARIANCE_PERCENT="${MAX_VARIANCE_PERCENT:-15}"
CHI_SQUARE_SIGNIFICANCE="${CHI_SQUARE_SIGNIFICANCE:-0.05}"

################################################################################
# Functions
################################################################################

# Display usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Analyze ECMP test results from tcpdump captures and generate statistical reports.

OPTIONS:
    -h, --help              Display this help message
    -c, --captures DIR      Directory containing capture files (default: results/captures)
    -o, --output DIR        Output directory for analysis results (default: results/analysis)
    -t, --test-id ID        Test identifier (default: YYYYMMDD_HHMMSS)
    -n, --test-name NAME     Test name (default: "ECMP Hash Distribution Test")
    -s, --scenario SCENARIO  Test scenario description
    -d, --debug              Enable debug logging
    -v, --verbose            Enable verbose output
    --json                  Generate JSON report in addition to text report
    --compare IDS           Compare multiple test runs (space-separated IDs)

EXAMPLES:
    # Analyze captures from default directory
    $(basename "$0")

    # Analyze with custom test ID and name
    $(basename "$0") -t 20240101_120000 -n "Production ECMP Test"

    # Generate JSON report
    $(basename "$0") --json

    # Compare multiple test runs
    $(basename "$0") --compare "20240101_120000 20240101_130000 20240101_140000"

ENVIRONMENT VARIABLES:
    MIN_PACKETS_PER_PATH    Minimum packets per path for statistical validity (default: 100)
    MAX_VARIANCE_PERCENT    Maximum allowed variance from uniform distribution (default: 15)
    CHI_SQUARE_SIGNIFICANCE Chi-square test significance level (default: 0.05)
    TRAFFIC_FILTER          tcpdump filter for traffic analysis (default: "ip and not icmp")

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--captures)
                CAPTURES_DIR="$2"
                shift 2
                ;;
            -o|--output)
                ANALYSIS_DIR="$2"
                shift 2
                ;;
            -t|--test-id)
                TEST_ID="$2"
                shift 2
                ;;
            -n|--test-name)
                TEST_NAME="$2"
                shift 2
                ;;
            -s|--scenario)
                TEST_SCENARIO="$2"
                shift 2
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --json)
                GENERATE_JSON=1
                shift
                ;;
            --compare)
                COMPARE_MODE=1
                COMPARE_IDS="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate capture files exist
validate_captures() {
    log_info "Validating capture files..."
    
    local missing_captures=()
    
    for path in "${ECMP_PATHS[@]}"; do
        local capture_file="${CAPTURES_DIR}/${path}_capture.pcap"
        if [[ ! -f "$capture_file" ]]; then
            missing_captures+=("$capture_file")
        fi
    done
    
    if [[ ${#missing_captures[@]} -gt 0 ]]; then
        log_error "Missing capture files:"
        for file in "${missing_captures[@]}"; do
            log_error "  - $file"
        done
        return 1
    fi
    
    log_info "All capture files found"
    return 0
}

# Extract packet count from a capture file
# Arguments:
#   $1 - Path name
# Returns:
#   Packet count
extract_packet_count() {
    local path_name="$1"
    local capture_file="${CAPTURES_DIR}/${path_name}_capture.pcap"
    
    log_debug "Extracting packet count from $capture_file"
    
    # Use tcpdump to count packets matching the filter
    local packet_count
    packet_count=$(tcpdump -r "$capture_file" -n "$TRAFFIC_FILTER" 2>/dev/null | wc -l)
    
    log_debug "Path $path_name: $packet_count packets"
    echo "$packet_count"
}

# Extract detailed packet information from capture file
# Arguments:
#   $1 - Path name
# Returns:
#   Packet information (source IPs, timestamps, etc.)
extract_packet_info() {
    local path_name="$1"
    local capture_file="${CAPTURES_DIR}/${path_name}_capture.pcap"
    local output_file="${ANALYSIS_DIR}/${TEST_ID}_${path_name}_packets.txt"
    
    log_debug "Extracting packet information from $capture_file"
    
    # Extract packet details: timestamp, source IP, destination IP, protocol
    tcpdump -r "$capture_file" -n -tt "$TRAFFIC_FILTER" 2>/dev/null | \
        awk '{
            # Parse tcpdump output
            timestamp = $1
            src_ip = $3
            dst_ip = $5
            protocol = $NF
            
            # Clean up IPs (remove port numbers)
            gsub(/\.[0-9]+$/, "", src_ip)
            gsub(/\.[0-9]+$/, "", dst_ip)
            
            print timestamp, src_ip, dst_ip, protocol
        }' > "$output_file"
    
    log_debug "Packet information written to $output_file"
}

# Analyze packet distribution across paths
analyze_distribution() {
    log_info "Analyzing packet distribution across ECMP paths..."
    
    local packet_counts=()
    local total_packets=0
    
    # Extract packet counts from all paths
    for path in "${ECMP_PATHS[@]}"; do
        local count=$(extract_packet_count "$path")
        packet_counts+=("$count")
        total_packets=$((total_packets + count))
        
        # Extract detailed packet information
        extract_packet_info "$path"
    done
    
    # Save packet counts to file
    local counts_file="${ANALYSIS_DIR}/${TEST_ID}_counts.txt"
    echo "${packet_counts[@]}" > "$counts_file"
    log_info "Packet counts saved to $counts_file"
    
    # Log distribution
    log_info "Total packets captured: $total_packets"
    log_info "Packet distribution:"
    for i in "${!ECMP_PATHS[@]}"; do
        local count=${packet_counts[$i]}
        local path=${ECMP_PATHS[$i]}
        local pct=$(echo "scale=2; ($count * 100) / $total_packets" | bc -l)
        log_info "  $path: $count packets (${pct}%)"
    done
    
    # Return packet counts as space-separated string
    echo "${packet_counts[@]}"
}

# Perform statistical analysis
perform_statistical_analysis() {
    local packet_counts="$1"
    
    log_info "Performing statistical analysis..."
    
    # Calculate basic statistics
    local mean=$(calculate_mean "$packet_counts")
    local variance=$(calculate_variance "$packet_counts" "$mean")
    local stddev=$(calculate_stddev "$packet_counts" "$variance")
    local cv=$(calculate_cv "$packet_counts")
    
    log_info "Basic Statistics:"
    log_info "  Mean: $mean"
    log_info "  Variance: $variance"
    log_info "  Standard Deviation: $stddev"
    log_info "  Coefficient of Variation: ${cv}%"
    
    # Calculate distribution variance
    local dist_variance=$(calculate_distribution_variance "$packet_counts")
    log_info "Distribution variance from uniform: ${dist_variance}%"
    
    # Perform chi-square test
    log_info "Performing chi-square test..."
    local chi_result=$(perform_chi_square_test "$packet_counts")
    local chi_stat=$(echo "$chi_result" | awk '{print $1}')
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    local chi_sig=$(echo "$chi_result" | awk '{print $3}')
    
    log_info "Chi-square test results:"
    log_info "  Statistic: $chi_stat"
    log_info "  P-value: $chi_p"
    log_info "  Significant: $chi_sig"
    log_info "  $(interpret_chi_square "$chi_stat" "$chi_p")"
    
    # Validate criteria
    log_info "Validating test criteria..."
    
    local criteria_passed=0
    local criteria_total=3
    
    # Criterion 1: Minimum packets per path
    if validate_sample_size "$packet_counts" "$MIN_PACKETS_PER_PATH"; then
        log_info "  ✓ Minimum packets per path: PASS"
        ((criteria_passed++))
    else
        log_warn "  ✗ Minimum packets per path: FAIL"
    fi
    
    # Criterion 2: Distribution variance
    if validate_distribution_threshold "$packet_counts" "$MAX_VARIANCE_PERCENT"; then
        log_info "  ✓ Distribution variance: PASS"
        ((criteria_passed++))
    else
        log_warn "  ✗ Distribution variance: FAIL"
    fi
    
    # Criterion 3: Chi-square test
    if [[ "$chi_sig" == "false" ]]; then
        log_info "  ✓ Chi-square test: PASS"
        ((criteria_passed++))
    else
        log_warn "  ✗ Chi-square test: FAIL"
    fi
    
    # Overall result
    local pass_rate=$(echo "scale=2; ($criteria_passed * 100) / $criteria_total" | bc -l)
    log_info "Overall result: $criteria_passed/$criteria_total criteria passed (${pass_rate}%)"
    
    # Save statistical results to file
    local stats_file="${ANALYSIS_DIR}/${TEST_ID}_statistics.txt"
    {
        echo "Test ID: $TEST_ID"
        echo "Test Name: $TEST_NAME"
        echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        echo "Packet Counts: $packet_counts"
        echo ""
        echo "Basic Statistics:"
        echo "  Mean: $mean"
        echo "  Variance: $variance"
        echo "  Standard Deviation: $stddev"
        echo "  Coefficient of Variation: ${cv}%"
        echo ""
        echo "Distribution Analysis:"
        echo "  Variance from Uniform: ${dist_variance}%"
        echo ""
        echo "Chi-Square Test:"
        echo "  Statistic: $chi_stat"
        echo "  P-value: $chi_p"
        echo "  Significant: $chi_sig"
        echo ""
        echo "Criteria Validation:"
        echo "  Passed: $criteria_passed/$criteria_total"
        echo "  Pass Rate: ${pass_rate}%"
    } > "$stats_file"
    
    log_info "Statistical results saved to $stats_file"
}

# Generate analysis report
generate_analysis_report() {
    local packet_counts="$1"
    
    log_info "Generating analysis report..."
    
    # Generate path names
    local path_names=""
    for path in "${ECMP_PATHS[@]}"; do
        path_names="$path_names $path"
    done
    
    # Generate text report
    local report_file="${REPORTS_DIR}/${TEST_ID}_report.txt"
    generate_test_report "$TEST_NAME" "$packet_counts" "$path_names" "$report_file" "$TEST_SCENARIO"
    
    # Generate JSON report if requested
    if [[ "${GENERATE_JSON:-0}" == "1" ]]; then
        local json_file="${REPORTS_DIR}/${TEST_ID}_report.json"
        generate_json_report "$TEST_NAME" "$packet_counts" "$path_names" "$json_file"
    fi
    
    log_info "Analysis report generation complete"
}

# Compare multiple test runs
compare_test_runs() {
    local test_ids="$1"
    
    log_info "Comparing test runs: $test_ids"
    
    local comparison_file="${REPORTS_DIR}/comparison_${TEST_ID}.txt"
    generate_comparison_report "$test_ids" "$comparison_file"
    
    log_info "Comparison report generated: $comparison_file"
}

# Archive test results
archive_results() {
    log_info "Archiving test results..."
    
    local archive_dir="${PROJECT_ROOT}/results/archives/${TEST_ID}"
    mkdir -p "$archive_dir"
    
    # Copy analysis results
    cp -r "${ANALYSIS_DIR}/${TEST_ID}"* "$archive_dir/" 2>/dev/null || true
    cp -r "${REPORTS_DIR}/${TEST_ID}"* "$archive_dir/" 2>/dev/null || true
    
    # Create archive summary
    {
        echo "Test Archive: $TEST_ID"
        echo "Test Name: $TEST_NAME"
        echo "Scenario: $TEST_SCENARIO"
        echo "Archived: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        echo "Contents:"
        ls -la "$archive_dir"
    } > "${archive_dir}/archive_info.txt"
    
    log_info "Results archived to $archive_dir"
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "========================================"
    log_info "ECMP Results Analyzer"
    log_info "========================================"
    log_info "Test ID: $TEST_ID"
    log_info "Test Name: $TEST_NAME"
    log_info "Scenario: $TEST_SCENARIO"
    log_info ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check dependencies
    log_info "Checking dependencies..."
    
    if ! command -v tcpdump &> /dev/null; then
        log_error "tcpdump is required but not installed"
        return 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required for calculations"
        return 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required for statistical tests"
        return 1
    fi
    
    if ! python3 -c "import scipy" &> /dev/null; then
        log_error "scipy is required for statistical tests"
        log_info "Install with: pip install scipy"
        return 1
    fi
    
    log_info "All dependencies satisfied"
    log_info ""
    
    # Handle comparison mode
    if [[ "${COMPARE_MODE:-0}" == "1" ]]; then
        compare_test_runs "$COMPARE_IDS"
        return 0
    fi
    
    # Validate capture files
    if ! validate_captures; then
        log_error "Capture file validation failed"
        return 1
    fi
    
    log_info ""
    
    # Analyze packet distribution
    local packet_counts
    packet_counts=$(analyze_distribution)
    
    log_info ""
    
    # Perform statistical analysis
    perform_statistical_analysis "$packet_counts"
    
    log_info ""
    
    # Generate analysis report
    generate_analysis_report "$packet_counts"
    
    log_info ""
    
    # Archive results
    archive_results
    
    log_info ""
    log_info "========================================"
    log_info "Analysis Complete"
    log_info "========================================"
    log_info "Results saved to:"
    log_info "  - Analysis: ${ANALYSIS_DIR}/${TEST_ID}_*"
    log_info "  - Reports: ${REPORTS_DIR}/${TEST_ID}_*"
    log_info "  - Archive: ${PROJECT_ROOT}/results/archives/${TEST_ID}/"
    log_info ""
    
    return 0
}

# Execute main function
main "$@"
