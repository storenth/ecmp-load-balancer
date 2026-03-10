#!/bin/bash

################################################################################
# Allure Integration Script for ECMP Testing
#
# This script generates Allure-compatible test results, creates test cases,
# includes metadata and parameters, attaches analysis results as artifacts,
# and generates Allure HTML reports with trend analysis.
#
# References:
# - Allure documentation: https://docs.qameta.io/allure/
# - Allure test results format: https://docs.qameta.io/allure/#_test_result_file
# - Allure report generation: https://docs.qameta.io/allure-report/
# - Test categorization: ISO/IEC/IEEE 29119-3 (Software testing documentation)
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
ALLURE_RESULTS_DIR="${PROJECT_ROOT}/results/allure-results"
ALLURE_REPORT_DIR="${PROJECT_ROOT}/results/allure-report"
ANALYSIS_DIR="${PROJECT_ROOT}/results/analysis"
REPORTS_DIR="${PROJECT_ROOT}/results/reports"
CAPTURES_DIR="${PROJECT_ROOT}/results/captures"
CONFIG_DIR="${PROJECT_ROOT}/configs/allure"

# Create directories if they don't exist
mkdir -p "${ALLURE_RESULTS_DIR}"
mkdir -p "${ALLURE_REPORT_DIR}"
mkdir -p "${ANALYSIS_DIR}"
mkdir -p "${REPORTS_DIR}"
mkdir -p "${CAPTURES_DIR}"

# Test configuration
TEST_ID="${TEST_ID:-$(date +%Y%m%d_%H%M%S)}"
TEST_NAME="${TEST_NAME:-ECMP Hash Distribution Test}"
TEST_SUITE="${TEST_SUITE:-ECMP Hash Testing Suite}"
TEST_SCENARIO="${TEST_SCENARIO:-Source IP-based ECMP Hash}"

# Allure configuration
ALLURE_CONFIG="${CONFIG_DIR}/allure_config.yaml"

# ECMP path configuration
ECMP_PATHS=("r1" "r2" "r3" "r4")
NUM_PATHS=${#ECMP_PATHS[@]}

# Test severity and labels
DEFAULT_SEVERITY="${DEFAULT_SEVERITY:-critical}"
DEFAULT_EPIC="${DEFAULT_EPIC:-ECMP Testing}"
DEFAULT_FEATURE="${DEFAULT_FEATURE:-Hash Distribution}"
DEFAULT_STORY="${DEFAULT_STORY:-Source IP Hash Algorithm}"

################################################################################
# Functions
################################################################################

# Display usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate Allure-compatible test results and reports for ECMP testing.

OPTIONS:
    -h, --help              Display this help message
    -r, --results DIR       Allure results directory (default: results/allure-results)
    -o, --output DIR        Allure report output directory (default: results/allure-report)
    -a, --analysis DIR      Analysis results directory (default: results/analysis)
    -t, --test-id ID        Test identifier (default: YYYYMMDD_HHMMSS)
    -n, --test-name NAME     Test name (default: "ECMP Hash Distribution Test")
    -s, --suite NAME        Test suite name (default: "ECMP Hash Testing Suite")
    -d, --debug             Enable debug logging
    -v, --verbose           Enable verbose output
    --open                  Open report in browser after generation
    --clean                 Clean previous results before generating
    --trend                 Generate trend analysis across multiple runs

EXAMPLES:
    # Generate Allure report from analysis results
    $(basename "$0")

    # Generate with custom test ID and name
    $(basename "$0") -t 20240101_120000 -n "Production ECMP Test"

    # Generate and open report in browser
    $(basename "$0") --open

    # Generate with trend analysis
    $(basename "$0") --trend

ENVIRONMENT VARIABLES:
    DEFAULT_SEVERITY        Default test severity (default: critical)
    DEFAULT_EPIC            Default epic label (default: ECMP Testing)
    DEFAULT_FEATURE         Default feature label (default: Hash Distribution)
    DEFAULT_STORY           Default story label (default: Source IP Hash Algorithm)

REQUIREMENTS:
    - allure-commandline: Install with: brew install allure (macOS) or apt-get install allure (Linux)
    - jq: Install with: brew install jq (macOS) or apt-get install jq (Linux)

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
            -r|--results)
                ALLURE_RESULTS_DIR="$2"
                shift 2
                ;;
            -o|--output)
                ALLURE_REPORT_DIR="$2"
                shift 2
                ;;
            -a|--analysis)
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
            -s|--suite)
                TEST_SUITE="$2"
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
            --open)
                OPEN_REPORT=1
                shift
                ;;
            --clean)
                CLEAN_RESULTS=1
                shift
                ;;
            --trend)
                GENERATE_TREND=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v allure &> /dev/null; then
        missing_deps+=("allure-commandline")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            log_error "  - $dep"
        done
        log_info ""
        log_info "Install missing dependencies:"
        log_info "  macOS: brew install ${missing_deps[*]}"
        log_info "  Linux: apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    log_info "All dependencies satisfied"
    return 0
}

# Clean previous results
clean_results() {
    log_info "Cleaning previous Allure results..."
    
    if [[ -d "${ALLURE_RESULTS_DIR}" ]]; then
        rm -rf "${ALLURE_RESULTS_DIR:?}"/*
        log_info "Allure results directory cleaned"
    fi
    
    if [[ -d "${ALLURE_REPORT_DIR}" ]]; then
        rm -rf "${ALLURE_REPORT_DIR:?}"/*
        log_info "Allure report directory cleaned"
    fi
}

# Generate Allure test result UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        # Fallback: generate a pseudo-UUID
        echo "$(date +%s%N)-$(shuf -i 1000-9999 -n 1)"
    fi
}

# Create Allure test result file
# Arguments:
#   $1 - Test UUID
#   $2 - Test name
#   $3 - Test status (passed, failed, broken, skipped, unknown)
#   $4 - Test duration in milliseconds
#   $5 - Test description (optional)
#   $6 - Test severity (optional)
#   $7 - Test parameters (optional, JSON array)
#   $8 - Test steps (optional, JSON array)
#   $9 - Test attachments (optional, JSON array)
create_allure_result() {
    local uuid="$1"
    local name="$2"
    local status="$3"
    local duration="$4"
    local description="${5:-}"
    local severity="${6:-$DEFAULT_SEVERITY}"
    local parameters="${7:-[]}"
    local steps="${8:-[]}"
    local attachments="${9:-[]}"
    
    local result_file="${ALLURE_RESULTS_DIR}/${uuid}-result.json"
    local container_file="${ALLURE_RESULTS_DIR}/${uuid}-container.json"
    
    # Generate timestamp
    local start_time=$(date +%s)000
    local stop_time=$((start_time + duration))
    
    # Create test result JSON
    local result_json=$(cat << EOF
{
  "uuid": "${uuid}",
  "name": "${name}",
  "fullName": "${TEST_SUITE}.${name}",
  "status": "${status}",
  "statusDetails": {
    "known": false,
    "muted": false,
    "flaky": false
  },
  "start": ${start_time},
  "stop": ${stop_time},
  "labels": [
    {
      "name": "suite",
      "value": "${TEST_SUITE}"
    },
    {
      "name": "testClass",
      "value": "${TEST_SUITE}"
    },
    {
      "name": "testMethod",
      "value": "${name}"
    },
    {
      "name": "package",
      "value": "ecmp.testing"
    },
    {
      "name": "epic",
      "value": "${DEFAULT_EPIC}"
    },
    {
      "name": "feature",
      "value": "${DEFAULT_FEATURE}"
    },
    {
      "name": "story",
      "value": "${DEFAULT_STORY}"
    },
    {
      "name": "severity",
      "value": "${severity}"
    },
    {
      "name": "framework",
      "value": "ECMP Testing Framework"
    },
    {
      "name": "language",
      "value": "bash"
    }
  ],
  "parameters": ${parameters},
  "steps": ${steps},
  "attachments": ${attachments}
}
EOF
)
    
    # Add description if provided
    if [[ -n "$description" ]]; then
        result_json=$(echo "$result_json" | jq --arg desc "$description" '. + {description: $desc}')
    fi
    
    # Write result file
    echo "$result_json" > "$result_file"
    log_debug "Created test result: $result_file"
    
    # Create container file
    local container_json=$(cat << EOF
{
  "uuid": "${uuid}",
  "name": "${TEST_SUITE}",
  "start": ${start_time},
  "stop": ${stop_time},
  "children": ["${uuid}"],
  "befores": [],
  "afters": []
}
EOF
)
    
    echo "$container_json" > "$container_file"
    log_debug "Created container: $container_file"
}

# Create Allure environment file
create_environment_file() {
    local env_file="${ALLURE_RESULTS_DIR}/environment.properties"
    
    cat > "$env_file" << EOF
Test.ID=${TEST_ID}
Test.Name=${TEST_NAME}
Test.Scenario=${TEST_SCENARIO}
Test.Suite=${TEST_SUITE}
Test.Environment=Containerlab
Routing.Platform=FRRouting
Hash.Algorithm=Source IP
Number.of.Paths=${NUM_PATHS}
Significance.Level=${CHI_SQUARE_SIGNIFICANCE_LEVEL:-0.05}
Variance.Threshold=${MAX_VARIANCE_PERCENT:-15}%
Minimum.Packets=${MIN_PACKETS_PER_PATH:-100}
Execution.Timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
Execution.User=$(whoami)
Execution.Host=$(hostname)
Execution.OS=$(uname -s)
Execution.OS.Version=$(uname -r)
Execution.Architecture=$(uname -m)
EOF
    
    log_debug "Created environment file: $env_file"
}

# Create Allure categories file
create_categories_file() {
    local categories_file="${ALLURE_RESULTS_DIR}/categories.json"
    
    cat > "$categories_file" << EOF
[
  {
    "name": "Critical Tests",
    "matchedStatuses": ["failed"],
    "message": "Critical test failure - ECMP hash distribution is not uniform"
  },
  {
    "name": "Statistical Tests",
    "matchedStatuses": ["failed"],
    "message": "Statistical test failure - distribution does not meet criteria"
  },
  {
    "name": "Performance Tests",
    "matchedStatuses": ["failed"],
    "message": "Performance test failure - packet distribution variance exceeds threshold"
  },
  {
    "name": "Integration Tests",
    "matchedStatuses": ["failed"],
    "message": "Integration test failure - ECMP path configuration issue"
  }
]
EOF
    
    log_debug "Created categories file: $categories_file"
}

# Generate test case for packet distribution
generate_distribution_test_case() {
    local packet_counts="$1"
    local test_uuid=$(generate_uuid)
    
    log_info "Generating distribution test case..."
    
    # Calculate statistics
    local total=0
    for count in $packet_counts; do
        total=$((total + count))
    done
    
    local dist_variance=$(calculate_distribution_variance "$packet_counts")
    local chi_result=$(perform_chi_square_test "$packet_counts")
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    local chi_sig=$(echo "$chi_result" | awk '{print $3}')
    
    # Determine test status
    local status="passed"
    if [[ "$chi_sig" == "true" ]] || (( $(echo "$dist_variance > ${MAX_VARIANCE_PERCENT:-15}" | bc -l) )); then
        status="failed"
    fi
    
    # Build parameters
    local parameters=$(jq -n \
        --arg total "$total" \
        --arg variance "$dist_variance" \
        --arg chi_p "$chi_p" \
        --arg paths "$NUM_PATHS" \
        '[
            {"name": "Total Packets", "value": $total},
            {"name": "Distribution Variance", "value": ($variance + "%")},
            {"name": "Chi-Square P-Value", "value": $chi_p},
            {"name": "Number of Paths", "value": $paths}
        ]')
    
    # Build steps
    local steps=$(jq -n '[
        {"name": "Extract packet counts from captures", "status": "passed", "start": 0, "stop": 100},
        {"name": "Calculate distribution statistics", "status": "passed", "start": 100, "stop": 200},
        {"name": "Perform chi-square test", "status": "passed", "start": 200, "stop": 300},
        {"name": "Validate distribution threshold", "status": "'$status'", "start": 300, "stop": 400}
    ]')
    
    # Build attachments
    local attachments=$(jq -n '[]')
    
    # Add analysis report as attachment if exists
    local analysis_file="${ANALYSIS_DIR}/${TEST_ID}_statistics.txt"
    if [[ -f "$analysis_file" ]]; then
        local attachment_uuid=$(generate_uuid)
        cp "$analysis_file" "${ALLURE_RESULTS_DIR}/${attachment_uuid}-attachment.txt"
        attachments=$(echo "$attachments" | jq --arg uuid "$attachment_uuid" --arg name "statistics.txt" '. + [{
            "name": $name,
            "source": ($uuid + "-attachment.txt"),
            "type": "text/plain"
        }]')
    fi
    
    # Create test result
    create_allure_result \
        "$test_uuid" \
        "Packet Distribution Test" \
        "$status" \
        400 \
        "Validates that ECMP hash algorithm distributes packets uniformly across all paths" \
        "critical" \
        "$parameters" \
        "$steps" \
        "$attachments"
    
    log_info "Distribution test case generated: $status"
}

# Generate test case for statistical tests
generate_statistical_test_case() {
    local packet_counts="$1"
    local test_uuid=$(generate_uuid)
    
    log_info "Generating statistical test case..."
    
    # Perform statistical tests
    local chi_result=$(perform_chi_square_test "$packet_counts")
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    local chi_sig=$(echo "$chi_result" | awk '{print $3}')
    
    local mean=$(calculate_mean "$packet_counts")
    local variance=$(calculate_variance "$packet_counts" "$mean")
    local stddev=$(calculate_stddev "$packet_counts" "$variance")
    local cv=$(calculate_cv "$packet_counts")
    
    # Determine test status
    local status="passed"
    if [[ "$chi_sig" == "true" ]]; then
        status="failed"
    fi
    
    # Build parameters
    local parameters=$(jq -n \
        --arg mean "$mean" \
        --arg variance "$variance" \
        --arg stddev "$stddev" \
        --arg cv "$cv" \
        --arg chi_p "$chi_p" \
        '[
            {"name": "Mean", "value": $mean},
            {"name": "Variance", "value": $variance},
            {"name": "Standard Deviation", "value": $stddev},
            {"name": "Coefficient of Variation", "value": ($cv + "%")},
            {"name": "Chi-Square P-Value", "value": $chi_p}
        ]')
    
    # Build steps
    local steps=$(jq -n '[
        {"name": "Calculate mean", "status": "passed", "start": 0, "stop": 100},
        {"name": "Calculate variance", "status": "passed", "start": 100, "stop": 200},
        {"name": "Calculate standard deviation", "status": "passed", "start": 200, "stop": 300},
        {"name": "Perform chi-square test", "status": "'$status'", "start": 300, "stop": 400}
    ]')
    
    # Create test result
    create_allure_result \
        "$test_uuid" \
        "Statistical Analysis Test" \
        "$status" \
        400 \
        "Performs statistical tests to validate ECMP hash distribution uniformity" \
        "critical" \
        "$parameters" \
        "$steps"
    
    log_info "Statistical test case generated: $status"
}

# Generate test case for path utilization
generate_utilization_test_case() {
    local packet_counts="$1"
    local test_uuid=$(generate_uuid)
    
    log_info "Generating utilization test case..."
    
    # Calculate utilization
    local utilization=$(calculate_utilization "$packet_counts")
    local utilization_array=($utilization)
    
    # Determine test status
    local status="passed"
    local max_variance=0
    for pct in "${utilization_array[@]}"; do
        local variance=$(echo "scale=2; $pct - 25" | bc -l)
        variance=${variance#-}  # Absolute value
        if (( $(echo "$variance > $max_variance" | bc -l) )); then
            max_variance=$variance
        fi
    done
    
    if (( $(echo "$max_variance > ${MAX_VARIANCE_PERCENT:-15}" | bc -l) )); then
        status="failed"
    fi
    
    # Build parameters
    local params_json="["
    local first=true
    for i in "${!utilization_array[@]}"; do
        local path=${ECMP_PATHS[$i]}
        local pct=${utilization_array[$i]}
        if [[ "$first" == "true" ]]; then
            first=false
        else
            params_json+=","
        fi
        params_json+=$(jq -n --arg path "$path" --arg pct "$pct" '{"name": ($path + " Utilization"), "value": ($pct + "%")}')
    done
    params_json+="]"
    
    # Build steps
    local steps=$(jq -n '[
        {"name": "Calculate path utilization", "status": "passed", "start": 0, "stop": 100},
        {"name": "Validate utilization thresholds", "status": "'$status'", "start": 100, "stop": 200}
    ]')
    
    # Create test result
    create_allure_result \
        "$test_uuid" \
        "Path Utilization Test" \
        "$status" \
        200 \
        "Validates that all ECMP paths are utilized within acceptable variance" \
        "major" \
        "$params_json" \
        "$steps"
    
    log_info "Utilization test case generated: $status"
}

# Generate test case for sample size validation
generate_sample_size_test_case() {
    local packet_counts="$1"
    local test_uuid=$(generate_uuid)
    
    log_info "Generating sample size test case..."
    
    # Validate sample size
    local status="passed"
    local min_count=$(echo "$packet_counts" | tr ' ' '\n' | sort -n | head -1)
    
    if [[ $min_count -lt ${MIN_PACKETS_PER_PATH:-100} ]]; then
        status="failed"
    fi
    
    # Build parameters
    local parameters=$(jq -n \
        --arg min_count "$min_count" \
        --arg required "${MIN_PACKETS_PER_PATH:-100}" \
        '[
            {"name": "Minimum Packets per Path", "value": $min_count},
            {"name": "Required Minimum", "value": $required}
        ]')
    
    # Build steps
    local steps=$(jq -n '[
        {"name": "Extract packet counts", "status": "passed", "start": 0, "stop": 100},
        {"name": "Validate minimum sample size", "status": "'$status'", "start": 100, "stop": 200}
    ]')
    
    # Create test result
    create_allure_result \
        "$test_uuid" \
        "Sample Size Validation Test" \
        "$status" \
        200 \
        "Validates that sufficient packets were captured for statistical significance" \
        "normal" \
        "$parameters" \
        "$steps"
    
    log_info "Sample size test case generated: $status"
}

# Generate Allure report
generate_allure_report() {
    log_info "Generating Allure HTML report..."
    
    # Generate report using allure command
    allure generate "${ALLURE_RESULTS_DIR}" --clean -o "${ALLURE_REPORT_DIR}"
    
    if [[ $? -eq 0 ]]; then
        log_info "Allure report generated successfully"
        log_info "Report location: ${ALLURE_REPORT_DIR}/index.html"
    else
        log_error "Failed to generate Allure report"
        return 1
    fi
}

# Open report in browser
open_report() {
    log_info "Opening report in browser..."
    
    local report_file="${ALLURE_REPORT_DIR}/index.html"
    
    if [[ ! -f "$report_file" ]]; then
        log_error "Report file not found: $report_file"
        return 1
    fi
    
    # Detect OS and open appropriately
    case "$(uname -s)" in
        Darwin*)  # macOS
            open "$report_file"
            ;;
        Linux*)
            if command -v xdg-open &> /dev/null; then
                xdg-open "$report_file"
            else
                log_warn "xdg-open not available, cannot open browser automatically"
                log_info "Open manually: file://$report_file"
            fi
            ;;
        *)
            log_warn "Unsupported OS for automatic browser opening"
            log_info "Open manually: file://$report_file"
            ;;
    esac
}

# Generate trend analysis
generate_trend_analysis() {
    log_info "Generating trend analysis..."
    
    # Find all test result directories
    local test_dirs=()
    for dir in "${ANALYSIS_DIR}"/*_counts.txt; do
        if [[ -f "$dir" ]]; then
            local test_id=$(basename "$dir" _counts.txt)
            test_dirs+=("$test_id")
        fi
    done
    
    if [[ ${#test_dirs[@]} -lt 2 ]]; then
        log_warn "Insufficient test runs for trend analysis (need at least 2)"
        return 0
    fi
    
    log_info "Found ${#test_dirs[@]} test runs for trend analysis"
    
    # Generate comparison report
    local comparison_file="${REPORTS_DIR}/trend_analysis_${TEST_ID}.txt"
    generate_comparison_report "${test_dirs[*]}" "$comparison_file"
    
    log_info "Trend analysis generated: $comparison_file"
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "========================================"
    log_info "Allure Report Generator"
    log_info "========================================"
    log_info "Test ID: $TEST_ID"
    log_info "Test Name: $TEST_NAME"
    log_info "Test Suite: $TEST_SUITE"
    log_info ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    log_info ""
    
    # Clean previous results if requested
    if [[ "${CLEAN_RESULTS:-0}" == "1" ]]; then
        clean_results
        log_info ""
    fi
    
    # Load packet counts from analysis
    local counts_file="${ANALYSIS_DIR}/${TEST_ID}_counts.txt"
    if [[ ! -f "$counts_file" ]]; then
        log_error "Analysis results not found: $counts_file"
        log_info "Run analyze_results.sh first to generate analysis data"
        return 1
    fi
    
    local packet_counts=$(cat "$counts_file")
    log_info "Loaded packet counts: $packet_counts"
    log_info ""
    
    # Create Allure configuration files
    log_info "Creating Allure configuration files..."
    create_environment_file
    create_categories_file
    log_info ""
    
    # Generate test cases
    log_info "Generating test cases..."
    generate_distribution_test_case "$packet_counts"
    generate_statistical_test_case "$packet_counts"
    generate_utilization_test_case "$packet_counts"
    generate_sample_size_test_case "$packet_counts"
    log_info ""
    
    # Generate trend analysis if requested
    if [[ "${GENERATE_TREND:-0}" == "1" ]]; then
        generate_trend_analysis
        log_info ""
    fi
    
    # Generate Allure report
    if ! generate_allure_report; then
        return 1
    fi
    
    log_info ""
    
    # Open report if requested
    if [[ "${OPEN_REPORT:-0}" == "1" ]]; then
        open_report
    fi
    
    log_info ""
    log_info "========================================"
    log_info "Allure Report Generation Complete"
    log_info "========================================"
    log_info "Results saved to:"
    log_info "  - Allure Results: ${ALLURE_RESULTS_DIR}"
    log_info "  - Allure Report: ${ALLURE_REPORT_DIR}/index.html"
    log_info ""
    
    return 0
}

# Execute main function
main "$@"
