#!/bin/bash

################################################################################
# Statistical Analysis Helper for ECMP Testing
#
# This script provides statistical analysis functions for ECMP hash distribution
# testing, including chi-square tests, Kolmogorov-Smirnov tests, and distribution
# comparison utilities.
#
# References:
# - Chi-square test: https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.chisquare.html
# - Kolmogorov-Smirnov test: https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.kstest.html
# - Statistical significance: RFC 2330 (Framework for IP Performance Metrics)
# - ECMP analysis: RFC 2992 (Analysis of an Equal-Cost Multi-Path Algorithm)
#
# Author: ECMP Testing Framework
# Version: 1.0.0
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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

# Default statistical thresholds (configurable via environment variables)
CHI_SQUARE_SIGNIFICANCE_LEVEL="${CHI_SQUARE_SIGNIFICANCE_LEVEL:-0.05}"  # 95% confidence
KS_TEST_SIGNIFICANCE_LEVEL="${KS_TEST_SIGNIFICANCE_LEVEL:-0.05}"        # 95% confidence
DISTRIBUTION_VARIANCE_THRESHOLD="${DISTRIBUTION_VARIANCE_THRESHOLD:-0.15}"  # 15% variance allowed
MIN_SAMPLE_SIZE="${MIN_SAMPLE_SIZE:-100}"  # Minimum packets per path for statistical validity

# Statistical test results storage
STATS_RESULTS_DIR="${PROJECT_ROOT}/results/analysis"
mkdir -p "${STATS_RESULTS_DIR}"

################################################################################
# Statistical Analysis Functions
################################################################################

# Calculate mean of a dataset
# Arguments:
#   $1 - Dataset (space-separated numbers)
# Returns:
#   Mean value
calculate_mean() {
    local dataset="$1"
    local sum=0
    local count=0
    
    for value in $dataset; do
        sum=$(echo "$sum + $value" | bc -l)
        ((count++))
    done
    
    if [[ $count -eq 0 ]]; then
        log_error "Cannot calculate mean of empty dataset"
        return 1
    fi
    
    echo "scale=4; $sum / $count" | bc -l
}

# Calculate variance of a dataset
# Arguments:
#   $1 - Dataset (space-separated numbers)
#   $2 - Mean value (optional, will be calculated if not provided)
# Returns:
#   Variance value
calculate_variance() {
    local dataset="$1"
    local mean="${2:-}"
    
    if [[ -z "$mean" ]]; then
        mean=$(calculate_mean "$dataset")
    fi
    
    local sum_squared_diff=0
    local count=0
    
    for value in $dataset; do
        local diff=$(echo "$value - $mean" | bc -l)
        local squared_diff=$(echo "$diff * $diff" | bc -l)
        sum_squared_diff=$(echo "$sum_squared_diff + $squared_diff" | bc -l)
        ((count++))
    done
    
    if [[ $count -eq 0 ]]; then
        log_error "Cannot calculate variance of empty dataset"
        return 1
    fi
    
    # Sample variance (n-1 denominator)
    echo "scale=4; $sum_squared_diff / ($count - 1)" | bc -l
}

# Calculate standard deviation of a dataset
# Arguments:
#   $1 - Dataset (space-separated numbers)
#   $2 - Variance value (optional, will be calculated if not provided)
# Returns:
#   Standard deviation value
calculate_stddev() {
    local dataset="$1"
    local variance="${2:-}"
    
    if [[ -z "$variance" ]]; then
        variance=$(calculate_variance "$dataset")
    fi
    
    echo "scale=4; sqrt($variance)" | bc -l
}

# Calculate coefficient of variation (CV)
# CV = (standard deviation / mean) * 100
# Arguments:
#   $1 - Dataset (space-separated numbers)
# Returns:
#   Coefficient of variation as percentage
calculate_cv() {
    local dataset="$1"
    
    local mean=$(calculate_mean "$dataset")
    local variance=$(calculate_variance "$dataset" "$mean")
    local stddev=$(calculate_stddev "$dataset" "$variance")
    
    if [[ $(echo "$mean == 0" | bc -l) -eq 1 ]]; then
        log_error "Cannot calculate CV with zero mean"
        return 1
    fi
    
    echo "scale=4; ($stddev / $mean) * 100" | bc -l
}

################################################################################
# Chi-Square Test Implementation
################################################################################

# Perform chi-square test for uniform distribution
# Tests whether observed frequencies match expected uniform distribution
#
# Arguments:
#   $1 - Observed frequencies (space-separated counts)
#   $2 - Expected frequencies (space-separated counts, optional)
#       If not provided, assumes uniform distribution
# Returns:
#   Chi-square statistic and p-value (space-separated)
perform_chi_square_test() {
    local observed="$1"
    local expected="${2:-}"
    
    log_debug "Performing chi-square test..."
    log_debug "Observed: $observed"
    
    # Convert to arrays
    local obs_array=($observed)
    local num_obs=${#obs_array[@]}
    
    # Calculate expected frequencies if not provided
    if [[ -z "$expected" ]]; then
        local total=0
        for obs in "${obs_array[@]}"; do
            total=$((total + obs))
        done
        
        if [[ $total -eq 0 ]]; then
            log_error "Total observed count is zero"
            return 1
        fi
        
        local exp_value=$((total / num_obs))
        expected=""
        for ((i=0; i<num_obs; i++)); do
            expected="$expected $exp_value"
        done
        log_debug "Expected (uniform): $expected"
    fi
    
    local exp_array=($expected)
    local num_exp=${#exp_array[@]}
    
    if [[ $num_obs -ne $num_exp ]]; then
        log_error "Observed and expected arrays must have same length"
        return 1
    fi
    
    # Calculate chi-square statistic
    # χ² = Σ((O_i - E_i)² / E_i)
    local chi_square=0
    local degrees_of_freedom=$((num_obs - 1))
    
    for ((i=0; i<num_obs; i++)); do
        local obs=${obs_array[$i]}
        local exp=${exp_array[$i]}
        
        if [[ $exp -eq 0 ]]; then
            log_error "Expected frequency cannot be zero"
            return 1
        fi
        
        local diff=$((obs - exp))
        local diff_sq=$((diff * diff))
        local term=$(echo "scale=6; $diff_sq / $exp" | bc -l)
        chi_square=$(echo "$chi_square + $term" | bc -l)
    done
    
    # Calculate p-value using Python scipy
    local p_value=$(python3 -c "
import scipy.stats as stats
import sys
chi_square = float('$chi_square')
df = $degrees_of_freedom
p_value = 1 - stats.chi2.cdf(chi_square, df)
print(f'{p_value:.6f}')
" 2>/dev/null || echo "0.000000")
    
    log_debug "Chi-square statistic: $chi_square"
    log_debug "Degrees of freedom: $degrees_of_freedom"
    log_debug "P-value: $p_value"
    
    # Determine if result is significant
    local is_significant="false"
    if (( $(echo "$p_value < $CHI_SQUARE_SIGNIFICANCE_LEVEL" | bc -l) )); then
        is_significant="true"
    fi
    
    echo "$chi_square $p_value $is_significant"
}

# Interpret chi-square test results
# Arguments:
#   $1 - Chi-square statistic
#   $2 - P-value
#   $3 - Significance level (optional, uses default if not provided)
# Returns:
#   Interpretation message
interpret_chi_square() {
    local chi_square="$1"
    local p_value="$2"
    local significance="${3:-$CHI_SQUARE_SIGNIFICANCE_LEVEL}"
    
    if (( $(echo "$p_value < $significance" | bc -l) )); then
        echo "FAIL: Distribution is NOT uniform (p=$p_value < $significance, χ²=$chi_square)"
    else
        echo "PASS: Distribution is uniform (p=$p_value >= $significance, χ²=$chi_square)"
    fi
}

################################################################################
# Kolmogorov-Smirnov Test Implementation
################################################################################

# Perform Kolmogorov-Smirnov test for distribution comparison
# Tests whether two samples come from the same distribution
#
# Arguments:
#   $1 - First sample (space-separated values)
#   $2 - Second sample (space-separated values)
# Returns:
#   KS statistic and p-value (space-separated)
perform_ks_test() {
    local sample1="$1"
    local sample2="$2"
    
    log_debug "Performing Kolmogorov-Smirnov test..."
    
    # Create temporary files for Python
    local temp_file1=$(mktemp)
    local temp_file2=$(mktemp)
    
    # Write samples to files
    echo "$sample1" | tr ' ' '\n' > "$temp_file1"
    echo "$sample2" | tr ' ' '\n' > "$temp_file2"
    
    # Perform KS test using Python scipy
    local result=$(python3 -c "
import scipy.stats as stats
import numpy as np

# Read samples
sample1 = np.loadtxt('$temp_file1')
sample2 = np.loadtxt('$temp_file2')

# Perform KS test
ks_statistic, p_value = stats.ks_2samp(sample1, sample2)

print(f'{ks_statistic:.6f} {p_value:.6f}')
" 2>/dev/null || echo "0.000000 0.000000")
    
    # Clean up
    rm -f "$temp_file1" "$temp_file2"
    
    local ks_statistic=$(echo "$result" | awk '{print $1}')
    local p_value=$(echo "$result" | awk '{print $2}')
    
    log_debug "KS statistic: $ks_statistic"
    log_debug "P-value: $p_value"
    
    # Determine if result is significant
    local is_significant="false"
    if (( $(echo "$p_value < $KS_TEST_SIGNIFICANCE_LEVEL" | bc -l) )); then
        is_significant="true"
    fi
    
    echo "$ks_statistic $p_value $is_significant"
}

# Interpret KS test results
# Arguments:
#   $1 - KS statistic
#   $2 - P-value
#   $3 - Significance level (optional, uses default if not provided)
# Returns:
#   Interpretation message
interpret_ks_test() {
    local ks_statistic="$1"
    local p_value="$2"
    local significance="${3:-$KS_TEST_SIGNIFICANCE_LEVEL}"
    
    if (( $(echo "$p_value < $significance" | bc -l) )); then
        echo "FAIL: Distributions are DIFFERENT (p=$p_value < $significance, KS=$ks_statistic)"
    else
        echo "PASS: Distributions are similar (p=$p_value >= $significance, KS=$ks_statistic)"
    fi
}

################################################################################
# Distribution Comparison Utilities
################################################################################

# Calculate path utilization percentages
# Arguments:
#   $1 - Packet counts per path (space-separated)
# Returns:
#   Utilization percentages (space-separated)
calculate_utilization() {
    local counts="$1"
    local total=0
    
    # Calculate total
    for count in $counts; do
        total=$((total + count))
    done
    
    if [[ $total -eq 0 ]]; then
        log_error "Total packet count is zero"
        return 1
    fi
    
    # Calculate percentages
    local percentages=""
    for count in $counts; do
        local pct=$(echo "scale=2; ($count * 100) / $total" | bc -l)
        percentages="$percentages $pct"
    done
    
    echo "$percentages"
}

# Calculate distribution variance from expected uniform
# Arguments:
#   $1 - Packet counts per path (space-separated)
# Returns:
#   Maximum variance percentage from uniform
calculate_distribution_variance() {
    local counts="$1"
    local num_paths=$(echo "$counts" | wc -w | tr -d ' ')
    local total=0
    
    # Calculate total
    for count in $counts; do
        total=$((total + count))
    done
    
    if [[ $total -eq 0 ]]; then
        log_error "Total packet count is zero"
        return 1
    fi
    
    # Expected uniform percentage
    local expected_pct=$(echo "scale=2; 100 / $num_paths" | bc -l)
    
    # Calculate maximum variance
    local max_variance=0
    for count in $counts; do
        local actual_pct=$(echo "scale=2; ($count * 100) / $total" | bc -l)
        local variance=$(echo "scale=2; $actual_pct - $expected_pct" | bc -l)
        variance=${variance#-}  # Absolute value
        if (( $(echo "$variance > $max_variance" | bc -l) )); then
            max_variance=$variance
        fi
    done
    
    echo "$max_variance"
}

# Validate distribution against threshold
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Variance threshold (optional, uses default if not provided)
# Returns:
#   0 if within threshold, 1 if outside threshold
validate_distribution_threshold() {
    local counts="$1"
    local threshold="${2:-$DISTRIBUTION_VARIANCE_THRESHOLD}"
    
    local variance=$(calculate_distribution_variance "$counts")
    
    log_debug "Distribution variance: $variance%"
    log_debug "Threshold: $threshold%"
    
    if (( $(echo "$variance <= $threshold" | bc -l) )); then
        log_debug "Distribution within threshold"
        return 0
    else
        log_debug "Distribution exceeds threshold"
        return 1
    fi
}

################################################################################
# Threshold Validation Functions
################################################################################

# Validate sample size for statistical significance
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Minimum sample size (optional, uses default if not provided)
# Returns:
#   0 if valid, 1 if invalid
validate_sample_size() {
    local counts="$1"
    local min_size="${2:-$MIN_SAMPLE_SIZE}"
    
    for count in $counts; do
        if [[ $count -lt $min_size ]]; then
            log_warn "Sample size $count is below minimum $min_size"
            return 1
        fi
    done
    
    log_debug "Sample size validation passed"
    return 0
}

# Validate all statistical criteria
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Variance threshold (optional)
#   $3 - Minimum sample size (optional)
# Returns:
#   0 if all criteria pass, 1 if any fail
validate_all_criteria() {
    local counts="$1"
    local variance_threshold="${2:-$DISTRIBUTION_VARIANCE_THRESHOLD}"
    local min_sample="${3:-$MIN_SAMPLE_SIZE}"
    
    local all_passed=true
    
    # Validate sample size
    if ! validate_sample_size "$counts" "$min_sample"; then
        all_passed=false
    fi
    
    # Validate distribution threshold
    if ! validate_distribution_threshold "$counts" "$variance_threshold"; then
        all_passed=false
    fi
    
    # Perform chi-square test
    local chi_result=$(perform_chi_square_test "$counts")
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    if (( $(echo "$chi_p < $CHI_SQUARE_SIGNIFICANCE_LEVEL" | bc -l) )); then
        all_passed=false
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Statistical Report Generation
################################################################################

# Generate statistical summary
# Arguments:
#   $1 - Packet counts per path (space-separated)
#   $2 - Output file (optional)
# Returns:
#   Statistical summary text
generate_statistical_summary() {
    local counts="$1"
    local output_file="${2:-}"
    
    local summary=""
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    summary+="========================================\n"
    summary+="ECMP Statistical Analysis Summary\n"
    summary+="========================================\n"
    summary+="Timestamp: $timestamp\n\n"
    
    # Basic statistics
    local mean=$(calculate_mean "$counts")
    local variance=$(calculate_variance "$counts" "$mean")
    local stddev=$(calculate_stddev "$counts" "$variance")
    local cv=$(calculate_cv "$counts")
    
    summary+="Basic Statistics:\n"
    summary+="  Mean: $mean\n"
    summary+="  Variance: $variance\n"
    summary+="  Std Dev: $stddev\n"
    summary+="  Coeff of Variation: $cv%\n\n"
    
    # Distribution analysis
    local utilization=$(calculate_utilization "$counts")
    local dist_variance=$(calculate_distribution_variance "$counts")
    
    summary+="Distribution Analysis:\n"
    summary+="  Path Utilization: $utilization\n"
    summary+="  Max Variance from Uniform: $dist_variance%\n"
    summary+="  Threshold: $DISTRIBUTION_VARIANCE_THRESHOLD%\n\n"
    
    # Chi-square test
    local chi_result=$(perform_chi_square_test "$counts")
    local chi_stat=$(echo "$chi_result" | awk '{print $1}')
    local chi_p=$(echo "$chi_result" | awk '{print $2}')
    local chi_sig=$(echo "$chi_result" | awk '{print $3}')
    
    summary+="Chi-Square Test:\n"
    summary+="  Statistic: $chi_stat\n"
    summary+="  P-value: $chi_p\n"
    summary+="  Significance Level: $CHI_SQUARE_SIGNIFICANCE_LEVEL\n"
    summary+="  Result: $(interpret_chi_square "$chi_stat" "$chi_p")\n\n"
    
    # Threshold validation
    summary+="Threshold Validation:\n"
    if validate_distribution_threshold "$counts"; then
        summary+="  Distribution: PASS (within $DISTRIBUTION_VARIANCE_THRESHOLD% threshold)\n"
    else
        summary+="  Distribution: FAIL (exceeds $DISTRIBUTION_VARIANCE_THRESHOLD% threshold)\n"
    fi
    
    if validate_sample_size "$counts"; then
        summary+="  Sample Size: PASS (>= $MIN_SAMPLE_SIZE packets per path)\n"
    else
        summary+="  Sample Size: FAIL (< $MIN_SAMPLE_SIZE packets per path)\n"
    fi
    
    summary+="\n========================================\n"
    
    # Output to file if specified
    if [[ -n "$output_file" ]]; then
        echo -e "$summary" > "$output_file"
        log_info "Statistical summary written to $output_file"
    fi
    
    echo -e "$summary"
}

################################################################################
# Main Function (for standalone execution)
################################################################################

main() {
    log_info "Statistical Analysis Helper"
    log_info "============================"
    
    # Check dependencies
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required for statistical tests"
        return 1
    fi
    
    if ! python3 -c "import scipy" &> /dev/null; then
        log_error "scipy is required for statistical tests"
        log_info "Install with: pip install scipy"
        return 1
    fi
    
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
