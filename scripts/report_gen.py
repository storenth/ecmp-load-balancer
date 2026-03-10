#!/usr/bin/env python3
"""
ECMP Report Generator - Python Implementation

This script generates comprehensive test reports for ECMP hash distribution testing.
It supports multiple report formats including Allure, ISO 29119-3 compliant reports,
JSON reports, and includes graphs and visualizations.

Features:
- Command-line interface with argparse
- Load analysis results from JSON files
- Generate Allure-compatible reports
- Generate ISO 29119-3 compliant reports
- Generate JSON reports
- Generate graphs and visualizations (matplotlib)
- Support trend analysis across multiple test runs
- Comprehensive error handling and logging

Author: ECMP Testing Framework
Version: 1.0.0
"""

import argparse
import sys
import json
import os
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
from collections import defaultdict

# Import local utilities
from utils import (
    load_config,
    setup_logging,
    ensure_directory,
    read_json,
    write_json,
    get_timestamp,
    get_test_id,
    validate_config,
    ProgressReporter,
    handle_errors
)

# Try to import matplotlib for graph generation
try:
    import matplotlib
    matplotlib.use('Agg')  # Use non-interactive backend
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False


# =============================================================================
# Allure Report Generation
# =============================================================================

def generate_allure_report(
    analysis_results: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Path:
    """
    Generate Allure-compatible report.
    
    Args:
        analysis_results: Analysis results dictionary
        output_dir: Output directory for reports
        logger: Logger instance
        
    Returns:
        Path to generated Allure results file
    """
    logger.info("Generating Allure report")
    
    # Create Allure results directory
    allure_results_dir = output_dir / 'allure-results'
    ensure_directory(allure_results_dir)
    
    # Create Allure test case result
    test_id = analysis_results.get('test_id', 'unknown')
    allure_result = {
        'name': f"ECMP Hash Distribution Test - {test_id}",
        'status': 'passed' if analysis_results.get('validation', {}).get('summary', {}).get('overall_passed', False) else 'failed',
        'statusDetails': {
            'message': 'ECMP hash distribution test completed',
            'trace': ''
        },
        'start': int(datetime.strptime(analysis_results.get('timestamp', ''), '%Y-%m-%d %H:%M:%S UTC').timestamp() * 1000),
        'stop': int(datetime.utcnow().timestamp() * 1000),
        'steps': [],
        'parameters': [],
        'labels': [
            {'name': 'suite', 'value': 'ECMP Testing'},
            {'name': 'testId', 'value': test_id}
        ],
        'attachments': []
    }
    
    # Add test steps
    steps = [
        {
            'name': 'Parse PCAP captures',
            'status': 'passed',
            'start': allure_result['start'],
            'stop': allure_result['stop']
        },
        {
            'name': 'Calculate distribution statistics',
            'status': 'passed',
            'start': allure_result['start'],
            'stop': allure_result['stop']
        },
        {
            'name': 'Perform statistical tests',
            'status': 'passed',
            'start': allure_result['start'],
            'stop': allure_result['stop']
        },
        {
            'name': 'Validate test criteria',
            'status': 'passed' if analysis_results.get('validation', {}).get('summary', {}).get('overall_passed', False) else 'failed',
            'start': allure_result['start'],
            'stop': allure_result['stop']
        }
    ]
    
    allure_result['steps'] = steps
    
    # Add parameters
    packet_counts = analysis_results.get('packet_counts', {})
    for path, count in packet_counts.items():
        allure_result['parameters'].append({
            'name': f'Packets on {path}',
            'value': str(count)
        })
    
    # Add statistics as parameters
    stats = analysis_results.get('statistics', {})
    allure_result['parameters'].extend([
        {'name': 'Total Packets', 'value': str(stats.get('total', 0))},
        {'name': 'Mean', 'value': f"{stats.get('mean', 0):.2f}"},
        {'name': 'Std Dev', 'value': f"{stats.get('stddev', 0):.2f}"},
        {'name': 'CV', 'value': f"{stats.get('coefficient_of_variation', 0):.2f}%"}
    ])
    
    # Write Allure result file
    allure_file = allure_results_dir / f"{test_id}-result.json"
    with open(allure_file, 'w') as f:
        json.dump(allure_result, f, indent=2)
    
    logger.info(f"Allure result saved to: {allure_file}")
    return allure_file


# =============================================================================
# ISO 29119-3 Report Generation
# =============================================================================

def generate_iso29119_report(
    analysis_results: Dict[str, Any],
    config: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Path:
    """
    Generate ISO 29119-3 compliant test report.
    
    Args:
        analysis_results: Analysis results dictionary
        config: Configuration dictionary
        output_dir: Output directory for reports
        logger: Logger instance
        
    Returns:
        Path to generated ISO 29119-3 report file
    """
    logger.info("Generating ISO 29119-3 compliant report")
    
    test_id = analysis_results.get('test_id', 'unknown')
    report_file = output_dir / f"{test_id}_iso29119_report.txt"
    
    # Build report content
    report_lines = []
    
    # Header
    report_lines.append("=" * 80)
    report_lines.append("ISO 29119-3 COMPLIANT TEST REPORT")
    report_lines.append("=" * 80)
    report_lines.append("")
    
    # Test Identification
    report_lines.append("1. TEST IDENTIFICATION")
    report_lines.append("-" * 80)
    report_lines.append(f"Test ID: {test_id}")
    report_lines.append(f"Test Name: {config.get('test', {}).get('name', 'ECMP Hash Validation Test')}")
    report_lines.append(f"Test Description: {config.get('test', {}).get('description', '')}")
    report_lines.append(f"Test Version: {config.get('test', {}).get('version', '1.0.0')}")
    report_lines.append(f"Test Date: {analysis_results.get('timestamp', '')}")
    report_lines.append("")
    
    # Test Environment
    report_lines.append("2. TEST ENVIRONMENT")
    report_lines.append("-" * 80)
    report_lines.append(f"Topology: {config.get('topology', {}).get('topology_file', 'N/A')}")
    report_lines.append(f"ECMP Router: {config.get('topology', {}).get('ecmp_router', 'N/A')}")
    report_lines.append(f"Number of Paths: {config.get('topology', {}).get('expected_paths', 0)}")
    report_lines.append("")
    
    # Test Configuration
    report_lines.append("3. TEST CONFIGURATION")
    report_lines.append("-" * 80)
    traffic_config = config.get('traffic', {})
    report_lines.append(f"Protocol: {traffic_config.get('protocol', 'N/A')}")
    report_lines.append(f"Source IP Range: {traffic_config.get('src_ip_range', 'N/A')}")
    report_lines.append(f"Destination IP: {traffic_config.get('destination_ip', 'N/A')}")
    report_lines.append(f"Destination Port: {traffic_config.get('destination_port', 'N/A')}")
    report_lines.append(f"Packets per Source: {traffic_config.get('packets_per_src', 'N/A')}")
    report_lines.append(f"Test Duration: {traffic_config.get('duration_sec', 'N/A')} seconds")
    report_lines.append("")
    
    # Test Results
    report_lines.append("4. TEST RESULTS")
    report_lines.append("-" * 80)
    
    packet_counts = analysis_results.get('packet_counts', {})
    report_lines.append("Packet Distribution:")
    for path, count in packet_counts.items():
        report_lines.append(f"  {path}: {count} packets")
    
    stats = analysis_results.get('statistics', {})
    report_lines.append("")
    report_lines.append("Statistical Analysis:")
    report_lines.append(f"  Total Packets: {stats.get('total', 0)}")
    report_lines.append(f"  Mean: {stats.get('mean', 0):.2f}")
    report_lines.append(f"  Variance: {stats.get('variance', 0):.2f}")
    report_lines.append(f"  Standard Deviation: {stats.get('stddev', 0):.2f}")
    report_lines.append(f"  Coefficient of Variation: {stats.get('coefficient_of_variation', 0):.2f}%")
    report_lines.append("")
    
    # Statistical Tests
    report_lines.append("5. STATISTICAL TESTS")
    report_lines.append("-" * 80)
    
    stat_tests = analysis_results.get('statistical_tests', {})
    
    # Chi-square test
    chi_square = stat_tests.get('chi_square', {})
    report_lines.append("Chi-Square Test:")
    report_lines.append(f"  Statistic: {chi_square.get('statistic', 0):.4f}")
    report_lines.append(f"  P-value: {chi_square.get('p_value', 0):.6f}")
    report_lines.append(f"  Significance Level: {chi_square.get('significance_level', 0):.2f}")
    report_lines.append(f"  Result: {chi_square.get('interpretation', 'N/A')}")
    report_lines.append("")
    
    # Entropy analysis
    entropy = stat_tests.get('entropy', {})
    report_lines.append("Entropy Analysis:")
    report_lines.append(f"  Entropy: {entropy.get('entropy', 0):.4f} bits")
    report_lines.append(f"  Maximum Entropy: {entropy.get('max_entropy', 0):.4f} bits")
    report_lines.append(f"  Normalized Entropy: {entropy.get('normalized_entropy', 0):.4f}")
    report_lines.append("")
    
    # Test Criteria Validation
    report_lines.append("6. TEST CRITERIA VALIDATION")
    report_lines.append("-" * 80)
    
    validation = analysis_results.get('validation', {})
    
    # Sample size
    sample_size = validation.get('sample_size', {})
    report_lines.append(f"Sample Size Validation:")
    report_lines.append(f"  Minimum Required: {sample_size.get('min_packets', 0)} packets")
    report_lines.append(f"  Result: {sample_size.get('interpretation', 'N/A')}")
    report_lines.append("")
    
    # Distribution
    distribution = validation.get('distribution', {})
    report_lines.append(f"Distribution Validation:")
    report_lines.append(f"  Maximum Allowed Variance: {distribution.get('max_variance', 0)}%")
    report_lines.append(f"  Actual Variance: {distribution.get('actual_variance', 0):.2f}%")
    report_lines.append(f"  Result: {distribution.get('interpretation', 'N/A')}")
    report_lines.append("")
    
    # Chi-square
    chi_square_val = validation.get('chi_square', {})
    report_lines.append(f"Chi-Square Validation:")
    report_lines.append(f"  Result: {chi_square_val.get('interpretation', 'N/A')}")
    report_lines.append("")
    
    # Overall result
    summary = validation.get('summary', {})
    report_lines.append("Overall Result:")
    report_lines.append(f"  Criteria Passed: {summary.get('passed', 0)}/{summary.get('total', 0)}")
    report_lines.append(f"  Pass Rate: {summary.get('pass_rate', 0):.1f}%")
    report_lines.append(f"  Test Status: {'PASS' if summary.get('overall_passed', False) else 'FAIL'}")
    report_lines.append("")
    
    # Conclusions
    report_lines.append("7. CONCLUSIONS")
    report_lines.append("-" * 80)
    
    if summary.get('overall_passed', False):
        report_lines.append("The ECMP hash distribution test PASSED all validation criteria.")
        report_lines.append("The hash algorithm is distributing traffic uniformly across all ECMP paths.")
    else:
        report_lines.append("The ECMP hash distribution test FAILED one or more validation criteria.")
        report_lines.append("The hash algorithm may not be distributing traffic uniformly.")
    
    report_lines.append("")
    
    # Recommendations
    report_lines.append("8. RECOMMENDATIONS")
    report_lines.append("-" * 80)
    
    if summary.get('overall_passed', False):
        report_lines.append("- The ECMP configuration is working as expected.")
        report_lines.append("- Continue monitoring hash distribution in production.")
        report_lines.append("- Consider testing with different traffic patterns.")
    else:
        report_lines.append("- Review ECMP hash policy configuration.")
        report_lines.append("- Check for network issues affecting path selection.")
        report_lines.append("- Consider adjusting hash algorithm parameters.")
        report_lines.append("- Re-run test with different traffic patterns.")
    
    report_lines.append("")
    
    # Footer
    report_lines.append("=" * 80)
    report_lines.append("END OF REPORT")
    report_lines.append("=" * 80)
    
    # Write report
    with open(report_file, 'w') as f:
        f.write('\n'.join(report_lines))
    
    logger.info(f"ISO 29119-3 report saved to: {report_file}")
    return report_file


# =============================================================================
# JSON Report Generation
# =============================================================================

def generate_json_report(
    analysis_results: Dict[str, Any],
    config: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Path:
    """
    Generate JSON report.
    
    Args:
        analysis_results: Analysis results dictionary
        config: Configuration dictionary
        output_dir: Output directory for reports
        logger: Logger instance
        
    Returns:
        Path to generated JSON report file
    """
    logger.info("Generating JSON report")
    
    test_id = analysis_results.get('test_id', 'unknown')
    report_file = output_dir / f"{test_id}_report.json"
    
    # Build comprehensive report
    report = {
        'metadata': {
            'test_id': test_id,
            'test_name': config.get('test', {}).get('name', 'ECMP Hash Validation Test'),
            'test_version': config.get('test', {}).get('version', '1.0.0'),
            'timestamp': analysis_results.get('timestamp', ''),
            'report_generated': get_timestamp()
        },
        'configuration': {
            'topology': config.get('topology', {}),
            'traffic': config.get('traffic', {}),
            'ecmp': config.get('ecmp', {}),
            'analysis': config.get('analysis', {})
        },
        'results': analysis_results,
        'summary': {
            'overall_status': 'PASS' if analysis_results.get('validation', {}).get('summary', {}).get('overall_passed', False) else 'FAIL',
            'total_packets': analysis_results.get('statistics', {}).get('total', 0),
            'num_paths': analysis_results.get('statistics', {}).get('num_paths', 0),
            'pass_rate': analysis_results.get('validation', {}).get('summary', {}).get('pass_rate', 0)
        }
    }
    
    # Write report
    write_json(report, report_file)
    
    logger.info(f"JSON report saved to: {report_file}")
    return report_file


# =============================================================================
# Graph Generation
# =============================================================================

def generate_distribution_graph(
    analysis_results: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Optional[Path]:
    """
    Generate packet distribution graph.
    
    Args:
        analysis_results: Analysis results dictionary
        output_dir: Output directory for graphs
        logger: Logger instance
        
    Returns:
        Path to generated graph file, or None if matplotlib not available
    """
    if not MATPLOTLIB_AVAILABLE:
        logger.warning("matplotlib not available, skipping graph generation")
        return None
    
    logger.info("Generating distribution graph")
    
    test_id = analysis_results.get('test_id', 'unknown')
    graph_file = output_dir / f"{test_id}_distribution.png"
    
    # Get packet counts
    packet_counts = analysis_results.get('packet_counts', {})
    paths = list(packet_counts.keys())
    counts = list(packet_counts.values())
    
    # Create figure
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Create bar chart
    bars = ax.bar(paths, counts, color='steelblue', edgecolor='black')
    
    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{int(height)}',
                ha='center', va='bottom')
    
    # Set labels and title
    ax.set_xlabel('ECMP Path', fontsize=12)
    ax.set_ylabel('Packet Count', fontsize=12)
    ax.set_title(f'Packet Distribution Across ECMP Paths\nTest ID: {test_id}', fontsize=14)
    
    # Add grid
    ax.grid(axis='y', alpha=0.3)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save figure
    plt.savefig(graph_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    logger.info(f"Distribution graph saved to: {graph_file}")
    return graph_file


def generate_percentage_graph(
    analysis_results: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Optional[Path]:
    """
    Generate percentage distribution graph.
    
    Args:
        analysis_results: Analysis results dictionary
        output_dir: Output directory for graphs
        logger: Logger instance
        
    Returns:
        Path to generated graph file, or None if matplotlib not available
    """
    if not MATPLOTLIB_AVAILABLE:
        logger.warning("matplotlib not available, skipping graph generation")
        return None
    
    logger.info("Generating percentage graph")
    
    test_id = analysis_results.get('test_id', 'unknown')
    graph_file = output_dir / f"{test_id}_percentage.png"
    
    # Get percentages
    stats = analysis_results.get('statistics', {})
    percentages = stats.get('percentages', [])
    paths = list(analysis_results.get('packet_counts', {}).keys())
    
    # Create figure
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Create bar chart
    bars = ax.bar(paths, percentages, color='coral', edgecolor='black')
    
    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}%',
                ha='center', va='bottom')
    
    # Add ideal uniform line
    num_paths = len(paths)
    ideal_pct = 100.0 / num_paths
    ax.axhline(y=ideal_pct, color='red', linestyle='--', 
                label=f'Ideal Uniform ({ideal_pct:.1f}%)')
    
    # Set labels and title
    ax.set_xlabel('ECMP Path', fontsize=12)
    ax.set_ylabel('Percentage (%)', fontsize=12)
    ax.set_title(f'Percentage Distribution Across ECMP Paths\nTest ID: {test_id}', fontsize=14)
    ax.legend()
    
    # Add grid
    ax.grid(axis='y', alpha=0.3)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save figure
    plt.savefig(graph_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    logger.info(f"Percentage graph saved to: {graph_file}")
    return graph_file


def generate_timeline_graph(
    comparison_results: Dict[str, Any],
    output_dir: Path,
    logger: Any
) -> Optional[Path]:
    """
    Generate timeline graph for trend analysis.
    
    Args:
        comparison_results: Comparison results dictionary
        output_dir: Output directory for graphs
        logger: Logger instance
        
    Returns:
        Path to generated graph file, or None if matplotlib not available
    """
    if not MATPLOTLIB_AVAILABLE:
        logger.warning("matplotlib not available, skipping graph generation")
        return None
    
    logger.info("Generating timeline graph")
    
    graph_file = output_dir / "trend_timeline.png"
    
    # Extract data from comparison results
    runs = comparison_results.get('runs', [])
    
    if len(runs) < 2:
        logger.warning("Need at least 2 test runs for trend analysis")
        return None
    
    # Extract pass rates over time
    test_ids = []
    pass_rates = []
    cv_values = []
    
    for run in runs:
        if 'validation' in run and 'summary' in run['validation']:
            test_ids.append(run.get('test_id', 'unknown'))
            pass_rates.append(run['validation']['summary'].get('pass_rate', 0))
            cv_values.append(run.get('statistics', {}).get('coefficient_of_variation', 0))
    
    if len(test_ids) < 2:
        logger.warning("Not enough valid test runs for trend analysis")
        return None
    
    # Create figure with two subplots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
    
    # Pass rate trend
    ax1.plot(range(len(test_ids)), pass_rates, marker='o', linewidth=2, markersize=8)
    ax1.set_xlabel('Test Run', fontsize=12)
    ax1.set_ylabel('Pass Rate (%)', fontsize=12)
    ax1.set_title('Pass Rate Trend Over Time', fontsize=14)
    ax1.grid(True, alpha=0.3)
    ax1.set_xticks(range(len(test_ids)))
    ax1.set_xticklabels([tid[-8:] for tid in test_ids], rotation=45)
    
    # CV trend
    ax2.plot(range(len(test_ids)), cv_values, marker='s', linewidth=2, markersize=8, color='orange')
    ax2.set_xlabel('Test Run', fontsize=12)
    ax2.set_ylabel('Coefficient of Variation (%)', fontsize=12)
    ax2.set_title('Distribution Variance Trend Over Time', fontsize=14)
    ax2.grid(True, alpha=0.3)
    ax2.set_xticks(range(len(test_ids)))
    ax2.set_xticklabels([tid[-8:] for tid in test_ids], rotation=45)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save figure
    plt.savefig(graph_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    logger.info(f"Timeline graph saved to: {graph_file}")
    return graph_file


# =============================================================================
# Trend Analysis
# =============================================================================

def perform_trend_analysis(
    test_ids: List[str],
    analysis_dir: Path,
    logger: Any
) -> Dict[str, Any]:
    """
    Perform trend analysis across multiple test runs.
    
    Args:
        test_ids: List of test IDs to analyze
        analysis_dir: Directory containing analysis results
        logger: Logger instance
        
    Returns:
        Dictionary containing trend analysis results
    """
    logger.info(f"Performing trend analysis for {len(test_ids)} test runs")
    
    trend_results = {
        'test_ids': test_ids,
        'timestamp': get_timestamp(),
        'runs': [],
        'trends': {}
    }
    
    # Load each test run
    for test_id in test_ids:
        result_file = analysis_dir / f"{test_id}_analysis.json"
        
        if result_file.exists():
            results = read_json(result_file)
            trend_results['runs'].append(results)
        else:
            logger.warning(f"Analysis file not found: {result_file}")
    
    if len(trend_results['runs']) < 2:
        logger.warning("Need at least 2 test runs for trend analysis")
        return trend_results
    
    # Extract metrics over time
    pass_rates = []
    cv_values = []
    entropies = []
    
    for run in trend_results['runs']:
        if 'validation' in run and 'summary' in run['validation']:
            pass_rates.append(run['validation']['summary'].get('pass_rate', 0))
            cv_values.append(run.get('statistics', {}).get('coefficient_of_variation', 0))
            entropies.append(
                run.get('statistical_tests', {})
                .get('entropy', {})
                .get('normalized_entropy', 0)
            )
    
    # Calculate trends
    if len(pass_rates) >= 2:
        trend_results['trends']['pass_rate'] = {
            'values': pass_rates,
            'mean': sum(pass_rates) / len(pass_rates),
            'min': min(pass_rates),
            'max': max(pass_rates),
            'trend': 'improving' if pass_rates[-1] > pass_rates[0] else 'declining'
        }
    
    if len(cv_values) >= 2:
        trend_results['trends']['cv'] = {
            'values': cv_values,
            'mean': sum(cv_values) / len(cv_values),
            'min': min(cv_values),
            'max': max(cv_values),
            'trend': 'improving' if cv_values[-1] < cv_values[0] else 'declining'
        }
    
    if len(entropies) >= 2:
        trend_results['trends']['entropy'] = {
            'values': entropies,
            'mean': sum(entropies) / len(entropies),
            'min': min(entropies),
            'max': max(entropies),
            'trend': 'improving' if entropies[-1] > entropies[0] else 'declining'
        }
    
    logger.info("Trend analysis completed")
    return trend_results


# =============================================================================
# Main Function
# =============================================================================

def main():
    """Main entry point for report generator script."""
    parser = argparse.ArgumentParser(
        description='ECMP Report Generator - Generate Test Reports',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate all report formats for a single test
  %(prog)s --test-id 20240101_120000
  
  # Generate specific report format
  %(prog)s --test-id 20240101_120000 --format json
  
  # Generate trend analysis
  %(prog)s --trend 20240101_120000 20240101_130000 20240101_140000
  
  # Generate graphs only
  %(prog)s --test-id 20240101_120000 --graphs-only
  
  # Enable verbose logging
  %(prog)s --test-id 20240101_120000 --verbose
        """
    )
    
    parser.add_argument(
        '--config',
        default='config/test_config.yaml',
        help='Path to configuration file (default: config/test_config.yaml)'
    )
    
    parser.add_argument(
        '--analysis-dir',
        default='results/analysis',
        help='Directory containing analysis results (default: results/analysis)'
    )
    
    parser.add_argument(
        '--output-dir',
        default='results/reports',
        help='Output directory for reports (default: results/reports)'
    )
    
    parser.add_argument(
        '--test-id',
        help='Test ID to generate report for'
    )
    
    parser.add_argument(
        '--trend',
        nargs='+',
        help='Generate trend analysis for multiple test IDs'
    )
    
    parser.add_argument(
        '--format',
        choices=['all', 'allure', 'iso29119', 'json'],
        default='all',
        help='Report format to generate (default: all)'
    )
    
    parser.add_argument(
        '--graphs-only',
        action='store_true',
        help='Generate graphs only (no text reports)'
    )
    
    parser.add_argument(
        '--no-graphs',
        action='store_true',
        help='Skip graph generation'
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
    logger.info("ECMP Report Generator")
    logger.info("=" * 60)
    
    try:
        # Load configuration
        logger.info(f"Loading configuration from: {args.config}")
        config = load_config(args.config)
        
        # Validate configuration
        validate_config(config, ['test', 'topology', 'traffic', 'analysis'])
        logger.info("Configuration loaded and validated")
        
        # Ensure output directory exists
        output_dir = ensure_directory(args.output_dir)
        graphs_dir = ensure_directory(output_dir / 'graphs')
        
        # Handle trend analysis
        if args.trend:
            logger.info(f"Generating trend analysis for: {args.trend}")
            
            analysis_dir = Path(args.analysis_dir)
            trend_results = perform_trend_analysis(args.trend, analysis_dir, logger)
            
            # Save trend results
            trend_file = output_dir / f"trend_analysis_{get_test_id()}.json"
            write_json(trend_results, trend_file)
            logger.info(f"Trend analysis saved to: {trend_file}")
            
            # Generate timeline graph
            if not args.no_graphs and MATPLOTLIB_AVAILABLE:
                generate_timeline_graph(trend_results, graphs_dir, logger)
            
            # Print summary
            print("\n" + "=" * 60)
            print("Trend Analysis Summary")
            print("=" * 60)
            print(f"Test Runs: {len(trend_results['runs'])}")
            
            if 'pass_rate' in trend_results['trends']:
                pr_trend = trend_results['trends']['pass_rate']
                print(f"\nPass Rate Trend:")
                print(f"  Mean: {pr_trend['mean']:.1f}%")
                print(f"  Range: {pr_trend['min']:.1f}% - {pr_trend['max']:.1f}%")
                print(f"  Trend: {pr_trend['trend']}")
            
            if 'cv' in trend_results['trends']:
                cv_trend = trend_results['trends']['cv']
                print(f"\nCV Trend:")
                print(f"  Mean: {cv_trend['mean']:.2f}%")
                print(f"  Range: {cv_trend['min']:.2f}% - {cv_trend['max']:.2f}%")
                print(f"  Trend: {cv_trend['trend']}")
            
            print("=" * 60)
            
            return 0
        
        # Generate report for single test
        if not args.test_id:
            logger.error("--test-id is required for single test report generation")
            return 1
        
        logger.info(f"Generating report for test: {args.test_id}")
        
        # Load analysis results
        analysis_dir = Path(args.analysis_dir)
        analysis_file = analysis_dir / f"{args.test_id}_analysis.json"
        
        if not analysis_file.exists():
            logger.error(f"Analysis file not found: {analysis_file}")
            return 1
        
        analysis_results = read_json(analysis_file)
        logger.info("Analysis results loaded")
        
        # Generate graphs
        if not args.no_graphs and not args.graphs_only:
            logger.info("Generating graphs")
            generate_distribution_graph(analysis_results, graphs_dir, logger)
            generate_percentage_graph(analysis_results, graphs_dir, logger)
        
        # Generate reports
        if not args.graphs_only:
            if args.format in ['all', 'allure']:
                generate_allure_report(analysis_results, output_dir, logger)
            
            if args.format in ['all', 'iso29119']:
                generate_iso29119_report(analysis_results, config, output_dir, logger)
            
            if args.format in ['all', 'json']:
                generate_json_report(analysis_results, config, output_dir, logger)
        
        # Print summary
        print("\n" + "=" * 60)
        print("Report Generation Summary")
        print("=" * 60)
        print(f"Test ID: {args.test_id}")
        print(f"Output Directory: {output_dir}")
        
        if not args.graphs_only:
            print(f"Report Formats: {args.format}")
        
        if not args.no_graphs and MATPLOTLIB_AVAILABLE:
            print(f"Graphs Generated: Yes")
        elif not args.no_graphs:
            print(f"Graphs Generated: No (matplotlib not available)")
        
        validation = analysis_results.get('validation', {}).get('summary', {})
        print(f"\nTest Status: {'PASS' if validation.get('overall_passed', False) else 'FAIL'}")
        print(f"Pass Rate: {validation.get('pass_rate', 0):.1f}%")
        print("=" * 60)
        
        logger.info("Report generation completed successfully")
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
