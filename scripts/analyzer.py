#!/usr/bin/env python3
"""
ECMP Results Analyzer - Python Implementation

This script provides comprehensive statistical analysis of ECMP hash distribution
test results. It parses PCAP capture files, extracts packet counts per path,
calculates distribution statistics, performs statistical tests, and generates
detailed analysis reports.

Features:
- Command-line interface with argparse
- Configuration loading from YAML
- PCAP file parsing using tcpdump
- Statistical tests: Chi-square, Kolmogorov-Smirnov, Entropy
- Distribution statistics: mean, variance, std dev, CV
- Threshold validation
- JSON output generation
- Multiple test run comparison
- Comprehensive error handling and logging

Author: ECMP Testing Framework
Version: 1.0.0
"""

import argparse
import sys
import json
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import numpy as np
from scipy import stats

# Import local utilities
from utils import (
    load_config,
    setup_logging,
    ensure_directory,
    calculate_mean,
    calculate_variance,
    calculate_stddev,
    calculate_cv,
    calculate_percentages,
    calculate_distribution_variance,
    write_json,
    read_json,
    get_timestamp,
    get_test_id,
    validate_config,
    validate_percentage,
    validate_positive,
    ProgressReporter,
    handle_errors
)


# =============================================================================
# PCAP Parsing Functions
# =============================================================================

def parse_pcap_file(
    pcap_path: Path,
    traffic_filter: str = "ip and not icmp"
) -> int:
    """
    Parse PCAP file and extract packet count.
    
    Args:
        pcap_path: Path to PCAP file
        traffic_filter: tcpdump filter expression
        
    Returns:
        Number of packets matching the filter
        
    Raises:
        FileNotFoundError: If PCAP file doesn't exist
        subprocess.CalledProcessError: If tcpdump fails
    """
    if not pcap_path.exists():
        raise FileNotFoundError(f"PCAP file not found: {pcap_path}")
    
    # Run tcpdump to count packets
    result = subprocess.run(
        ['tcpdump', '-r', str(pcap_path), '-n', traffic_filter],
        capture_output=True,
        text=True,
        check=True
    )
    
    # Count lines (each line is a packet)
    packet_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
    
    return packet_count


def extract_packet_info(
    pcap_path: Path,
    traffic_filter: str = "ip and not icmp"
) -> List[Dict[str, str]]:
    """
    Extract detailed packet information from PCAP file.
    
    Args:
        pcap_path: Path to PCAP file
        traffic_filter: tcpdump filter expression
        
    Returns:
        List of packet information dictionaries
        
    Raises:
        FileNotFoundError: If PCAP file doesn't exist
        subprocess.CalledProcessError: If tcpdump fails
    """
    if not pcap_path.exists():
        raise FileNotFoundError(f"PCAP file not found: {pcap_path}")
    
    # Run tcpdump with timestamp and detailed output
    result = subprocess.run(
        ['tcpdump', '-r', str(pcap_path), '-n', '-tt', traffic_filter],
        capture_output=True,
        text=True,
        check=True
    )
    
    packets = []
    
    for line in result.stdout.strip().split('\n'):
        if not line:
            continue
        
        # Parse tcpdump output
        # Format: timestamp src_ip.port > dst_ip.port: protocol info
        parts = line.split()
        
        if len(parts) >= 5:
            packet = {
                'timestamp': parts[0],
                'src_ip': parts[1].split('.')[0:4],
                'dst_ip': parts[3].split('.')[0:4],
                'protocol': parts[-1]
            }
            packets.append(packet)
    
    return packets


def parse_all_captures(
    captures_dir: Path,
    ecmp_paths: List[str],
    traffic_filter: str = "ip and not icmp"
) -> Dict[str, int]:
    """
    Parse all PCAP capture files and extract packet counts per path.
    
    Args:
        captures_dir: Directory containing capture files
        ecmp_paths: List of ECMP path names
        traffic_filter: tcpdump filter expression
        
    Returns:
        Dictionary mapping path names to packet counts
        
    Raises:
        FileNotFoundError: If any capture file is missing
    """
    packet_counts = {}
    
    for path in ecmp_paths:
        pcap_file = captures_dir / f"{path}_capture.pcap"
        packet_count = parse_pcap_file(pcap_file, traffic_filter)
        packet_counts[path] = packet_count
    
    return packet_counts


# =============================================================================
# Statistical Analysis Functions
# =============================================================================

def perform_chi_square_test(
    observed: List[int],
    expected: Optional[List[float]] = None,
    significance_level: float = 0.05
) -> Dict[str, Any]:
    """
    Perform chi-square test for uniform distribution.
    
    Tests whether observed frequencies match expected uniform distribution.
    
    Args:
        observed: List of observed frequencies
        expected: List of expected frequencies (optional, assumes uniform if None)
        significance_level: Significance level for the test
        
    Returns:
        Dictionary containing test results
    """
    # Calculate expected frequencies if not provided
    if expected is None:
        total = sum(observed)
        expected = [total / len(observed)] * len(observed)
    
    # Perform chi-square test
    chi2_stat, p_value = stats.chisquare(f_obs=observed, f_exp=expected)
    
    # Determine if result is significant
    is_significant = p_value < significance_level
    
    return {
        'statistic': float(chi2_stat),
        'p_value': float(p_value),
        'significance_level': significance_level,
        'is_significant': is_significant,
        'degrees_of_freedom': len(observed) - 1,
        'expected': expected,
        'interpretation': (
            "FAIL: Distribution is NOT uniform" if is_significant
            else "PASS: Distribution is uniform"
        )
    }


def perform_ks_test(
    sample1: List[float],
    sample2: List[float],
    significance_level: float = 0.05
) -> Dict[str, Any]:
    """
    Perform Kolmogorov-Smirnov test for distribution comparison.
    
    Tests whether two samples come from the same distribution.
    
    Args:
        sample1: First sample
        sample2: Second sample
        significance_level: Significance level for the test
        
    Returns:
        Dictionary containing test results
    """
    # Perform KS test
    ks_statistic, p_value = stats.ks_2samp(sample1, sample2)
    
    # Determine if result is significant
    is_significant = p_value < significance_level
    
    return {
        'statistic': float(ks_statistic),
        'p_value': float(p_value),
        'significance_level': significance_level,
        'is_significant': is_significant,
        'interpretation': (
            "FAIL: Distributions are DIFFERENT" if is_significant
            else "PASS: Distributions are similar"
        )
    }


def calculate_entropy(probabilities: List[float]) -> float:
    """
    Calculate Shannon entropy of a probability distribution.
    
    Args:
        probabilities: List of probabilities (must sum to 1)
        
    Returns:
        Entropy value in bits
    """
    # Filter out zero probabilities
    probs = [p for p in probabilities if p > 0]
    
    # Calculate entropy
    entropy = -sum(p * np.log2(p) for p in probs)
    
    return float(entropy)


def calculate_max_entropy(num_categories: int) -> float:
    """
    Calculate maximum possible entropy for given number of categories.
    
    Args:
        num_categories: Number of categories
        
    Returns:
        Maximum entropy value
    """
    return np.log2(num_categories)


def perform_entropy_analysis(
    counts: List[int]
) -> Dict[str, Any]:
    """
    Perform entropy analysis on packet distribution.
    
    Args:
        counts: List of packet counts per path
        
    Returns:
        Dictionary containing entropy analysis results
    """
    total = sum(counts)
    probabilities = [count / total for count in counts]
    
    # Calculate entropy
    entropy = calculate_entropy(probabilities)
    max_entropy = calculate_max_entropy(len(counts))
    normalized_entropy = entropy / max_entropy if max_entropy > 0 else 0
    
    return {
        'entropy': float(entropy),
        'max_entropy': float(max_entropy),
        'normalized_entropy': float(normalized_entropy),
        'probabilities': probabilities,
        'interpretation': (
            f"Entropy: {entropy:.4f} bits (max: {max_entropy:.4f} bits, "
            f"normalized: {normalized_entropy:.4f})"
        )
    }


def calculate_distribution_statistics(
    counts: List[int]
) -> Dict[str, Any]:
    """
    Calculate comprehensive distribution statistics.
    
    Args:
        counts: List of packet counts per path
        
    Returns:
        Dictionary containing all statistics
    """
    # Convert to float for calculations
    data = [float(c) for c in counts]
    
    # Basic statistics
    mean = calculate_mean(data)
    variance = calculate_variance(data, mean)
    stddev = calculate_stddev(data, variance)
    cv = calculate_cv(data)
    
    # Distribution analysis
    percentages = calculate_percentages(counts)
    dist_variance = calculate_distribution_variance(counts)
    
    return {
        'counts': counts,
        'total': sum(counts),
        'mean': float(mean),
        'variance': float(variance),
        'stddev': float(stddev),
        'coefficient_of_variation': float(cv),
        'percentages': [float(p) for p in percentages],
        'distribution_variance': float(dist_variance),
        'num_paths': len(counts)
    }


# =============================================================================
# Validation Functions
# =============================================================================

def validate_sample_size(
    counts: List[int],
    min_packets: int
) -> Dict[str, Any]:
    """
    Validate that sample size meets minimum requirements.
    
    Args:
        counts: List of packet counts per path
        min_packets: Minimum packets required per path
        
    Returns:
        Dictionary containing validation results
    """
    insufficient_paths = [
        i for i, count in enumerate(counts) if count < min_packets
    ]
    
    passed = len(insufficient_paths) == 0
    
    return {
        'passed': passed,
        'min_packets': min_packets,
        'insufficient_paths': insufficient_paths,
        'interpretation': (
            f"PASS: All paths have >= {min_packets} packets" if passed
            else f"FAIL: Paths {insufficient_paths} have < {min_packets} packets"
        )
    }


def validate_distribution_threshold(
    counts: List[int],
    max_variance: float
) -> Dict[str, Any]:
    """
    Validate that distribution variance is within threshold.
    
    Args:
        counts: List of packet counts per path
        max_variance: Maximum allowed variance percentage
        
    Returns:
        Dictionary containing validation results
    """
    dist_variance = calculate_distribution_variance(counts)
    passed = dist_variance <= max_variance
    
    return {
        'passed': passed,
        'max_variance': max_variance,
        'actual_variance': float(dist_variance),
        'interpretation': (
            f"PASS: Distribution variance {dist_variance:.2f}% <= {max_variance}%"
            if passed
            else f"FAIL: Distribution variance {dist_variance:.2f}% > {max_variance}%"
        )
    }


def validate_all_criteria(
    counts: List[int],
    config: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Validate all test criteria against configuration thresholds.
    
    Args:
        counts: List of packet counts per path
        config: Configuration dictionary
        
    Returns:
        Dictionary containing all validation results
    """
    analysis_config = config.get('analysis', {})
    ecmp_config = config.get('ecmp', {})
    
    # Get thresholds from config
    min_packets = analysis_config.get('min_packets', 1000)
    max_variance = ecmp_config.get('tolerance_percent', 10.0)
    chi_square_significance = analysis_config.get('confidence_level', 0.95)
    
    # Perform validations
    sample_size_validation = validate_sample_size(counts, min_packets)
    distribution_validation = validate_distribution_threshold(counts, max_variance)
    
    # Perform chi-square test
    chi_square_result = perform_chi_square_test(
        counts,
        significance_level=1 - chi_square_significance
    )
    
    # Count passed criteria
    passed_count = sum([
        sample_size_validation['passed'],
        distribution_validation['passed'],
        not chi_square_result['is_significant']
    ])
    total_count = 3
    pass_rate = (passed_count / total_count) * 100
    
    return {
        'sample_size': sample_size_validation,
        'distribution': distribution_validation,
        'chi_square': chi_square_result,
        'summary': {
            'passed': passed_count,
            'total': total_count,
            'pass_rate': float(pass_rate),
            'overall_passed': passed_count == total_count
        }
    }


# =============================================================================
# Analysis Functions
# =============================================================================

def analyze_test_run(
    captures_dir: Path,
    ecmp_paths: List[str],
    config: Dict[str, Any],
    test_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Perform complete analysis of a single test run.
    
    Args:
        captures_dir: Directory containing capture files
        ecmp_paths: List of ECMP path names
        config: Configuration dictionary
        test_id: Test identifier (optional, will be generated if not provided)
        
    Returns:
        Dictionary containing complete analysis results
    """
    if test_id is None:
        test_id = get_test_id()
    
    # Get traffic filter from config
    traffic_filter = config.get('traffic', {}).get('filter', 'ip and not icmp')
    
    # Parse captures
    packet_counts = parse_all_captures(captures_dir, ecmp_paths, traffic_filter)
    counts = [packet_counts[path] for path in ecmp_paths]
    
    # Calculate statistics
    statistics = calculate_distribution_statistics(counts)
    
    # Perform statistical tests
    chi_square_result = perform_chi_square_test(counts)
    entropy_result = perform_entropy_analysis(counts)
    
    # Validate criteria
    validation = validate_all_criteria(counts, config)
    
    # Build results
    results = {
        'test_id': test_id,
        'timestamp': get_timestamp(),
        'packet_counts': packet_counts,
        'statistics': statistics,
        'statistical_tests': {
            'chi_square': chi_square_result,
            'entropy': entropy_result
        },
        'validation': validation,
        'config': {
            'ecmp_paths': ecmp_paths,
            'traffic_filter': traffic_filter
        }
    }
    
    return results


def compare_test_runs(
    test_ids: List[str],
    analysis_dir: Path
) -> Dict[str, Any]:
    """
    Compare multiple test runs.
    
    Args:
        test_ids: List of test IDs to compare
        analysis_dir: Directory containing analysis results
        
    Returns:
        Dictionary containing comparison results
    """
    comparison_results = {
        'test_ids': test_ids,
        'timestamp': get_timestamp(),
        'runs': []
    }
    
    # Load each test run
    for test_id in test_ids:
        result_file = analysis_dir / f"{test_id}_analysis.json"
        
        if result_file.exists():
            results = read_json(result_file)
            comparison_results['runs'].append(results)
        else:
            comparison_results['runs'].append({
                'test_id': test_id,
                'error': f"Analysis file not found: {result_file}"
            })
    
    # Perform KS tests between runs
    if len(comparison_results['runs']) >= 2:
        ks_tests = []
        
        for i in range(len(comparison_results['runs']) - 1):
            for j in range(i + 1, len(comparison_results['runs'])):
                run1 = comparison_results['runs'][i]
                run2 = comparison_results['runs'][j]
                
                if 'statistics' in run1 and 'statistics' in run2:
                    counts1 = run1['statistics']['counts']
                    counts2 = run2['statistics']['counts']
                    
                    ks_result = perform_ks_test(counts1, counts2)
                    ks_tests.append({
                        'run1': run1['test_id'],
                        'run2': run2['test_id'],
                        'ks_test': ks_result
                    })
        
        comparison_results['ks_tests'] = ks_tests
    
    return comparison_results


# =============================================================================
# Main Function
# =============================================================================

def main():
    """Main entry point for the analyzer script."""
    parser = argparse.ArgumentParser(
        description='ECMP Results Analyzer - Statistical Analysis of ECMP Hash Distribution',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze captures from default directory
  %(prog)s
  
  # Analyze with custom test ID
  %(prog)s --test-id 20240101_120000
  
  # Analyze with custom captures directory
  %(prog)s --captures-dir results/captures
  
  # Compare multiple test runs
  %(prog)s --compare 20240101_120000 20240101_130000 20240101_140000
  
  # Generate JSON output only
  %(prog)s --json-only
  
  # Enable verbose logging
  %(prog)s --verbose
        """
    )
    
    parser.add_argument(
        '--config',
        default='config/test_config.yaml',
        help='Path to configuration file (default: config/test_config.yaml)'
    )
    
    parser.add_argument(
        '--captures-dir',
        default='results/captures',
        help='Directory containing capture files (default: results/captures)'
    )
    
    parser.add_argument(
        '--output-dir',
        default='results/analysis',
        help='Output directory for analysis results (default: results/analysis)'
    )
    
    parser.add_argument(
        '--test-id',
        help='Test identifier (default: auto-generated)'
    )
    
    parser.add_argument(
        '--compare',
        nargs='+',
        help='Compare multiple test runs (space-separated test IDs)'
    )
    
    parser.add_argument(
        '--json-only',
        action='store_true',
        help='Generate JSON output only (no console output)'
    )
    
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug logging'
    )
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = 'DEBUG' if args.debug else ('INFO' if args.verbose else 'WARNING')
    logger = setup_logging(__name__, level=log_level)
    
    logger.info("=" * 60)
    logger.info("ECMP Results Analyzer")
    logger.info("=" * 60)
    
    try:
        # Load configuration
        logger.info(f"Loading configuration from: {args.config}")
        config = load_config(args.config)
        
        # Validate configuration
        validate_config(config, ['test', 'topology', 'traffic', 'analysis'])
        logger.info("Configuration loaded and validated")
        
        # Get ECMP paths from config
        ecmp_paths = [hop['name'] for hop in config['topology']['next_hops']]
        logger.info(f"ECMP paths: {ecmp_paths}")
        
        # Ensure output directory exists
        output_dir = ensure_directory(args.output_dir)
        
        # Handle comparison mode
        if args.compare:
            logger.info(f"Comparing test runs: {args.compare}")
            comparison = compare_test_runs(args.compare, output_dir)
            
            # Save comparison results
            comparison_file = output_dir / f"comparison_{get_test_id()}.json"
            write_json(comparison, comparison_file)
            logger.info(f"Comparison results saved to: {comparison_file}")
            
            if not args.json_only:
                print("\nComparison Results:")
                print(json.dumps(comparison, indent=2))
            
            return 0
        
        # Analyze single test run
        captures_dir = Path(args.captures_dir)
        
        if not captures_dir.exists():
            logger.error(f"Captures directory not found: {captures_dir}")
            return 1
        
        logger.info(f"Analyzing captures from: {captures_dir}")
        
        # Perform analysis
        results = analyze_test_run(
            captures_dir,
            ecmp_paths,
            config,
            args.test_id
        )
        
        # Save results to JSON
        results_file = output_dir / f"{results['test_id']}_analysis.json"
        write_json(results, results_file)
        logger.info(f"Analysis results saved to: {results_file}")
        
        # Print summary
        if not args.json_only:
            print("\n" + "=" * 60)
            print("Analysis Summary")
            print("=" * 60)
            print(f"Test ID: {results['test_id']}")
            print(f"Timestamp: {results['timestamp']}")
            print(f"\nPacket Counts:")
            for path, count in results['packet_counts'].items():
                print(f"  {path}: {count}")
            print(f"\nTotal Packets: {results['statistics']['total']}")
            print(f"Mean: {results['statistics']['mean']:.2f}")
            print(f"Std Dev: {results['statistics']['stddev']:.2f}")
            print(f"CV: {results['statistics']['coefficient_of_variation']:.2f}%")
            print(f"\nChi-Square Test:")
            print(f"  Statistic: {results['statistical_tests']['chi_square']['statistic']:.4f}")
            print(f"  P-value: {results['statistical_tests']['chi_square']['p_value']:.6f}")
            print(f"  {results['statistical_tests']['chi_square']['interpretation']}")
            print(f"\nEntropy Analysis:")
            print(f"  {results['statistical_tests']['entropy']['interpretation']}")
            print(f"\nValidation:")
            print(f"  Passed: {results['validation']['summary']['passed']}/{results['validation']['summary']['total']}")
            print(f"  Pass Rate: {results['validation']['summary']['pass_rate']:.1f}%")
            print(f"  Overall: {'PASS' if results['validation']['summary']['overall_passed'] else 'FAIL'}")
            print("=" * 60)
        
        logger.info("Analysis completed successfully")
        return 0
        
    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        return 1
    except ValueError as e:
        logger.error(f"Validation error: {e}")
        return 1
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
