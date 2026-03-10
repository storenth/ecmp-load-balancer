#!/bin/bash

################################################################################
# Report Generation Helper for ECMP Testing
#
# This script generates human-readable test reports with summary tables, charts,
# pass/fail criteria, and recommendations based on ECMP test results.
#
# References:
# - Report formatting: ISO/IEC/IEEE 29119-3 (Software testing documentation)
# - Test documentation: IEEE 829 (Standard for Software Test Documentation)
# - ECMP analysis: RFC 2992 (Analysis of an Equal-Cost Multi-Path Algorithm)
#
# Author: ECMP Testing Framework
# Version: 1.0.0
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source statistical analysis helper
source "${SCRIPT_DIR}/statistical_analysis.sh"

# Source logging utilities if available
if [[ -f "${SCRIPT_DIR}/logging.sh" ]]; then
    source "${SCRIPT_DIR}/logging.sh"
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

# Report directories
REPORTS_DIR="${PROJECT_ROOT}/results/reports"
ANALYSIS_DIR="${PROJECT_ROOT}/results/analysis"
mkdir -p "${REPORTS_DIR}"
mkdir -p "${ANALYSIS_DIR}"

# Report templates
REPORT_TEMPLATE="${PROJECT_ROOT}/configs/templates/report_template.md"

# Pass/Fail criteria
PASS_THRESHOLD="${PASS_THRESHOLD:-0.85}"  # 85% of criteria must pass
MIN_PACKETS_PER_PATH="${MIN_PACKETS_PER_PATH:-100}"
MAX_VARIANCE_PERCENT="${MAX_VARIANCE_PERCENT:-15}"

################################################################################
# Report Generation Functions
################################################################################

# Generate ASCII chart for path utilization
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Path names (space-separated, optional)
# Returns:
#   ASCII chart
generate_ascii_chart() {
    local counts="$1"
    local path_names="${2:-Path1 Path2 Path3 Path4}"
    
    local counts_array=($counts)
    local names_array=($path_names)
    local max_count=0
    
    # Find maximum count for scaling
    for count in "${counts_array[@]}"; do
        if [[ $count -gt $max_count ]]; then
            max_count=$count
        fi
    done
    
    if [[ $max_count -eq 0 ]]; then
        echo "No data to display"
        return
    fi
    
    local chart=""
    chart+="\n"
    chart+="Path Utilization Chart\n"
    chart+="======================\n\n"
    
    # Generate bars
    for i in "${!counts_array[@]}"; do
        local count=${counts_array[$i]}
        local name=${names_array[$i]:-"Path$((i+1))"}
        local bar_length=$(( (count * 50) / max_count ))
        local bar=""
        
        for ((j=0; j<bar_length; j++)); do
            bar+="█"
        done
        
        local pct=$(echo "scale=1; ($count * 100) / $max_count" | bc -l)
        chart+=$(printf "%-10s | %-50s %6d (%5.1f%%)\n" "$name" "$bar" "$count" "$pct")
    done
    
    chart+="\n"
    echo -e "$chart"
}

# Generate summary table for test results
# Arguments:
#   $1 - Test name
#   $2 - Packet counts per path (space-separated)
#   $3 - Path names (space-separated, optional)
# Returns:
#   Summary table
generate_summary_table() {
    local test_name="$1"
    local counts="$2"
    local path_names="${3:-Path1 Path2 Path3 Path4}"
    
    local counts_array=($counts)
    local names_array=($path_names)
    local total=0
    
    # Calculate total
    for count in "${counts_array[@]}"; do
        total=$((total + count))
    done
    
    local table=""
    table+="\n"
    table+="Test Summary: $test_name\n"
    table+="========================================\n\n"
    table+=$(printf "%-15s %10s %12s\n" "Path" "Packets" "Percentage")
    table+="----------------------------------------\n"
    
    for i in "${!counts_array[@]}"; do
        local count=${counts_array[$i]}
        local name=${names_array[$i]:-"Path$((i+1))"}
        local pct=$(echo "scale=2; ($count * 100) / $total" | bc -l)
        table+=$(printf "%-15s %10d %11.2f%%\n" "$name" "$count" "$pct")
    done
    
    table+="----------------------------------------\n"
    table+=$(printf "%-15s %10d %12s\n" "Total" "$total" "100.00%")
    table+="\n"
    
    echo -e "$table"
}

# Generate pass/fail criteria section
# Arguments:
#   $1 - Packet counts per path (space-separated)
# Returns:
#   Pass/fail criteria section
generate_pass_fail_criteria() {
    local counts="$1"
    
    local section=""
    section+="\n"
    section+="Pass/Fail Criteria\n"
    section+="===================\n\n"
    
    local criteria_passed=0
    local criteria_total=0
    
    # Criterion 1: Minimum packets per path
    ((criteria_total++))
    section+="1. Minimum Packets per Path (>= $MIN_PACKETS_PER_PATH)\n"
    if validate_sample_size "$counts" "$MIN_PACKETS_PER_PATH"; then
        section+="   Status: PASS\n"
        ((criteria_passed++))
    else
        section+="   Status: FAIL\n"
    fi
    section+="\n"
    
    # Criterion 2: Distribution variance threshold
    ((criteria_total++))
    section+="2. Distribution Variance (<= $MAX_VARIANCE_PERCENT%)\n"
    local variance=$(calculate_distribution_variance "$counts")
    section+="   Actual Variance: ${variance}%\n"
    if validate_distribution_threshold "$counts" "$MAX_VARIANCE_PERCENT"; then
        section+="   Status: PASS\n"
        ((criteria_passed++))
    else
        section+="   Status: FAIL\n"
    fi
    section+="\n"
    
    # Criterion 3: Chi-square test
    ((criteria_total++))
    section+="3. Chi-Square Test (p >= $CHI_SQUARE_SIGNIFICANCE_LEVEL)\n"
    local chi_result=$(perform_chi_square_test "$counts")
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    section+="   P-value: $chi_p\n"
    if (( $(echo "$chi_p >= $CHI_SQUARE_SIGNIFICANCE_LEVEL" | bc -l) )); then
        section+="   Status: PASS\n"
        ((criteria_passed++))
    else
        section+="   Status: FAIL\n"
    fi
    section+="\n"
    
    # Overall result
    local pass_rate=$(echo "scale=2; ($criteria_passed * 100) / $criteria_total" | bc -l)
    section+="Overall Result: "
    if (( $(echo "$pass_rate >= $PASS_THRESHOLD" | bc -l) )); then
        section+="PASS ($criteria_passed/$criteria_total criteria, ${pass_rate}%)\n"
    else
        section+="FAIL ($criteria_passed/$criteria_total criteria, ${pass_rate}%)\n"
    fi
    section+="\n"
    
    echo -e "$section"
}

# Generate recommendations based on results
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Test scenario (optional)
# Returns:
#   Recommendations section
generate_recommendations() {
    local counts="$1"
    local scenario="${2:-ECMP Hash Distribution Test}"
    
    local section=""
    section+="\n"
    section+="Recommendations\n"
    section+="===============\n\n"
    
    local recommendations=()
    
    # Check sample size
    local min_count=$(echo "$counts" | tr ' ' '\n' | sort -n | head -1)
    if [[ $min_count -lt $MIN_PACKETS_PER_PATH ]]; then
        recommendations+=("• Increase traffic volume to ensure at least $MIN_PACKETS_PER_PATH packets per path for statistical significance")
    fi
    
    # Check distribution variance
    local variance=$(calculate_distribution_variance "$counts")
    if (( $(echo "$variance > $MAX_VARIANCE_PERCENT" | bc -l) )); then
        recommendations+=("• Distribution variance (${variance}%) exceeds threshold (${MAX_VARIANCE_PERCENT}%) - investigate hash algorithm configuration")
        recommendations+=("• Verify ECMP paths have equal metrics and are properly configured")
        recommendations+=("• Check for asymmetric routing or path preference issues")
    fi
    
    # Check chi-square test
    local chi_result=$(perform_chi_square_test "$counts")
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    if (( $(echo "$chi_p < $CHI_SQUARE_SIGNIFICANCE_LEVEL" | bc -l) )); then
        recommendations+=("• Chi-square test indicates non-uniform distribution (p=$chi_p)")
        recommendations+=("• Review hash algorithm configuration - ensure Source IP only is being used")
        recommendations+=("• Verify no additional hash fields (destination IP, ports) are influencing path selection")
    fi
    
    # Check for path imbalance
    local counts_array=($counts)
    local max_count=0
    local min_count=999999
    for count in "${counts_array[@]}"; do
        if [[ $count -gt $max_count ]]; then
            max_count=$count
        fi
        if [[ $count -lt $min_count ]]; then
            min_count=$count
        fi
    done
    
    local imbalance_ratio=$(echo "scale=2; $max_count / $min_count" | bc -l)
    if (( $(echo "$imbalance_ratio > 1.5" | bc -l) )); then
        recommendations+=("• Significant path imbalance detected (ratio: ${imbalance_ratio}:1)")
        recommendations+=("• Investigate potential hash collisions or algorithm bias")
    fi
    
    # Add positive recommendations if all tests pass
    if validate_all_criteria "$counts"; then
        recommendations+=("✓ All criteria passed - ECMP hash distribution is functioning correctly")
        recommendations+=("✓ Source IP-based hash algorithm is working as expected")
        recommendations+=("✓ Continue monitoring in production to ensure consistent behavior")
    fi
    
    if [[ ${#recommendations[@]} -eq 0 ]]; then
        section+="No specific recommendations - test results are within acceptable parameters.\n"
    else
        for rec in "${recommendations[@]}"; do
            section+="$rec\n"
        done
    fi
    
    section+="\n"
    echo -e "$section"
}

# Generate detailed test report
# Arguments:
#   $1 - Test name
#   $2 - Packet counts per path (space-separated)
#   $3 - Path names (space-separated, optional)
#   $4 - Output file (optional)
#   $5 - Test scenario (optional)
# Returns:
#   Full test report
generate_test_report() {
    local test_name="$1"
    local counts="$2"
    local path_names="${3:-Path1 Path2 Path3 Path4}"
    local output_file="${4:-}"
    local scenario="${5:-ECMP Hash Distribution Test}"
    
    local report=""
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    local test_id=$(date +%Y%m%d_%H%M%S)
    
    # Report header
    report+="========================================\n"
    report+="ECMP Test Report\n"
    report+="========================================\n\n"
    report+="Test ID: $test_id\n"
    report+="Test Name: $test_name\n"
    report+="Scenario: $scenario\n"
    report+="Timestamp: $timestamp\n"
    report+="Project: ECMP Hash Testing Framework\n\n"
    
    # Summary table
    report+="$(generate_summary_table "$test_name" "$counts" "$path_names")"
    
    # ASCII chart
    report+="$(generate_ascii_chart "$counts" "$path_names")"
    
    # Statistical summary
    report+="$(generate_statistical_summary "$counts")"
    
    # Pass/fail criteria
    report+="$(generate_pass_fail_criteria "$counts")"
    
    # Recommendations
    report+="$(generate_recommendations "$counts" "$scenario")"
    
    # Report footer
    report+="========================================\n"
    report+="End of Report\n"
    report+="========================================\n"
    
    # Output to file if specified
    if [[ -n "$output_file" ]]; then
        echo -e "$report" > "$output_file"
        log_info "Test report written to $output_file"
    fi
    
    echo -e "$report"
}

# Generate comparison report for multiple test runs
# Arguments:
#   $1 - Test run IDs (space-separated)
#   $2 - Output file (optional)
# Returns:
#   Comparison report
generate_comparison_report() {
    local test_ids="$1"
    local output_file="${2:-}"
    
    local report=""
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    report+="========================================\n"
    report+="ECMP Test Comparison Report\n"
    report+="========================================\n\n"
    report+="Timestamp: $timestamp\n\n"
    
    report+="Test Runs Compared:\n"
    for test_id in $test_ids; do
        report+="  - $test_id\n"
    done
    report+="\n"
    
    # Load data from each test run
    local all_counts=()
    for test_id in $test_ids; do
        local data_file="${ANALYSIS_DIR}/${test_id}_counts.txt"
        if [[ -f "$data_file" ]]; then
            local counts=$(cat "$data_file")
            all_counts+=("$counts")
        fi
    done
    
    if [[ ${#all_counts[@]} -eq 0 ]]; then
        report+="No test data found for comparison.\n"
    else
        report+="Comparison Table:\n"
        report+=$(printf "%-20s" "Test ID")
        for ((i=1; i<=4; i++)); do
            report+=$(printf " %10s" "Path$i")
        done
        report+="\n"
        report+="$(printf '%.0s-' {1..65})\n"
        
        local idx=0
        for test_id in $test_ids; do
            if [[ $idx -lt ${#all_counts[@]} ]]; then
                local counts="${all_counts[$idx]}"
                report+=$(printf "%-20s" "$test_id")
                for count in $counts; do
                    report+=$(printf " %10d" "$count")
                done
                report+="\n"
            fi
            ((idx++))
        done
        report+="\n"
        
        # Perform KS test between consecutive runs
        report+="Kolmogorov-Smirnov Test Results:\n"
        report+="(Testing if distributions are similar)\n\n"
        
        for ((i=0; i<${#all_counts[@]}-1; i++)); do
            local counts1="${all_counts[$i]}"
            local counts2="${all_counts[$i+1]}"
            local ks_result=$(perform_ks_test "$counts1" "$counts2")
            local ks_stat=$(echo "$ks_result" | awk '{print $1}')
            local ks_p=$(echo "$ks_result" | awk '{print $2}')
            
            report+="Run $((i+1)) vs Run $((i+2)):\n"
            report+="  KS Statistic: $ks_stat\n"
            report+="  P-value: $ks_p\n"
            report+="  $(interpret_ks_test "$ks_stat" "$ks_p")\n\n"
        done
    fi
    
    report+="========================================\n"
    report+="End of Comparison Report\n"
    report+="========================================\n"
    
    # Output to file if specified
    if [[ -n "$output_file" ]]; then
        echo -e "$report" > "$output_file"
        log_info "Comparison report written to $output_file"
    fi
    
    echo -e "$report"
}

# Generate JSON report for programmatic consumption
# Arguments:
#   $1 - Test name
#   $2 - Packet counts per path (space-separated)
#   $3 - Path names (space-separated, optional)
#   $4 - Output file (optional)
# Returns:
#   JSON report
generate_json_report() {
    local test_name="$1"
    local counts="$2"
    local path_names="${3:-Path1 Path2 Path3 Path4}"
    local output_file="${4:-}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local test_id=$(date +%Y%m%d_%H%M%S)
    
    local counts_array=($counts)
    local names_array=($path_names)
    local total=0
    
    for count in "${counts_array[@]}"; do
        total=$((total + count))
    done
    
    # Calculate statistics
    local mean=$(calculate_mean "$counts")
    local variance=$(calculate_variance "$counts" "$mean")
    local stddev=$(calculate_stddev "$counts" "$variance")
    local cv=$(calculate_cv "$counts")
    local dist_variance=$(calculate_distribution_variance "$counts")
    
    # Chi-square test
    local chi_result=$(perform_chi_square_test "$counts")
    local chi_stat=$(echo "$chi_result" | awk '{print $1}')
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    local chi_sig=$(echo "$chi_result" | awk '{print $3}')
    
    # Build JSON
    local json="{"
    json+="\"test_id\": \"$test_id\","
    json+="\"test_name\": \"$test_name\","
    json+="\"timestamp\": \"$timestamp\","
    json+="\"total_packets\": $total,"
    json+="\"statistics\": {"
    json+="\"mean\": $mean,"
    json+="\"variance\": $variance,"
    json+="\"stddev\": $stddev,"
    json+="\"coefficient_of_variation\": $cv"
    json+="},"
    json+="\"paths\": ["
    
    for i in "${!counts_array[@]}"; do
        local count=${counts_array[$i]}
        local name=${names_array[$i]:-"Path$((i+1))"}
        local pct=$(echo "scale=2; ($count * 100) / $total" | bc -l)
        
        json+="{"
        json+="\"name\": \"$name\","
        json+="\"packets\": $count,"
        json+="\"percentage\": $pct"
        json+="}"
        
        if [[ $i -lt $((${#counts_array[@]} - 1)) ]]; then
            json+=","
        fi
    done
    
    json+="],"
    json+="\"distribution_variance\": $dist_variance,"
    json+="\"chi_square_test\": {"
    json+="\"statistic\": $chi_stat,"
    json+="\"p_value\": $chi_p,"
    json+="\"significant\": $chi_sig"
    json+="},"
    json+="\"criteria\": {"
    json+="\"min_packets_per_path\": $MIN_PACKETS_PER_PATH,"
    json+="\"max_variance_percent\": $MAX_VARIANCE_PERCENT,"
    json+="\"chi_square_significance\": $CHI_SQUARE_SIGNIFICANCE_LEVEL"
    json+="}"
    json+="}"
    
    # Output to file if specified
    if [[ -n "$output_file" ]]; then
        echo "$json" > "$output_file"
        log_info "JSON report written to $output_file"
    fi
    
    echo "$json"
}

################################################################################
# Main Function (for standalone execution)
################################################################################

main() {
    log_info "Report Generation Helper"
    log_info "========================="
    
    # Check dependencies
    if ! command -v bc &> /dev/null; then
        log_error "bc is required for calculations"
        return 1
    fi
    
    log_info "All dependencies satisfied"
    return 0
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
