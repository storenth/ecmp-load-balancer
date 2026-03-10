#!/usr/bin/env python3
"""
ECMP Traffic Generator - Python Implementation

This script generates traffic for ECMP hash distribution testing. It supports
multiple traffic generation tools (hping3, scapy) and provides flexible
configuration for varying source IP addresses while maintaining constant
destination parameters.

Features:
- Command-line interface with argparse
- Configuration loading from YAML
- Support for hping3 and scapy traffic generation
- Varying source IP addresses
- Constant destination IP, ports, and protocol
- Configurable traffic patterns
- Progress reporting
- Traffic validation
- Comprehensive error handling and logging

Author: ECMP Testing Framework
Version: 1.0.0
"""

import argparse
import sys
import subprocess
import time
import signal
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import threading

# Import local utilities
from utils import (
    load_config,
    setup_logging,
    ensure_directory,
    parse_ip_range,
    validate_ip_address,
    validate_port,
    validate_positive,
    get_timestamp,
    get_test_id,
    validate_config,
    ProgressReporter,
    handle_errors,
    retry
)


# =============================================================================
# Traffic Generation Classes
# =============================================================================

class TrafficGenerator:
    """Base class for traffic generators."""
    
    def __init__(
        self,
        config: Dict[str, Any],
        logger: Any
    ):
        """
        Initialize traffic generator.
        
        Args:
            config: Configuration dictionary
            logger: Logger instance
        """
        self.config = config
        self.logger = logger
        self.traffic_config = config.get('traffic', {})
        self.topology_config = config.get('topology', {})
        
        # Traffic parameters
        self.src_ip_range = self.traffic_config.get('src_ip_range', '10.0.1.10-10.0.1.13')
        self.dst_ip = self.traffic_config.get('destination_ip', '10.0.10.10')
        self.dst_port = self.traffic_config.get('destination_port', 80)
        self.src_port = self.traffic_config.get('source_port', 0)
        self.protocol = self.traffic_config.get('protocol', 'tcp')
        self.packets_per_src = self.traffic_config.get('packets_per_src', 1000)
        self.interval_ms = self.traffic_config.get('interval_ms', 10)
        self.duration_sec = self.traffic_config.get('duration_sec', 60)
        self.packet_size = self.traffic_config.get('packet_size_bytes', 100)
        self.ttl = self.traffic_config.get('ttl', 64)
        
        # Parse source IPs
        self.source_ips = parse_ip_range(self.src_ip_range)
        
        # Traffic generation process
        self.process: Optional[subprocess.Popen] = None
        self.stop_event = threading.Event()
    
    def validate_parameters(self) -> bool:
        """
        Validate traffic generation parameters.
        
        Returns:
            True if all parameters are valid
            
        Raises:
            ValueError: If any parameter is invalid
        """
        validate_ip_address(self.dst_ip)
        validate_port(self.dst_port)
        validate_positive(self.packets_per_src, "packets_per_src")
        validate_positive(self.interval_ms, "interval_ms")
        validate_positive(self.duration_sec, "duration_sec")
        validate_positive(self.packet_size, "packet_size")
        
        if not self.source_ips:
            raise ValueError(f"No source IPs found in range: {self.src_ip_range}")
        
        for ip in self.source_ips:
            validate_ip_address(ip)
        
        self.logger.info(f"Validated {len(self.source_ips)} source IPs")
        return True
    
    def generate_traffic(self) -> Dict[str, Any]:
        """
        Generate traffic (to be implemented by subclasses).
        
        Returns:
            Dictionary containing generation results
        """
        raise NotImplementedError("Subclasses must implement generate_traffic()")
    
    def stop(self) -> None:
        """Stop traffic generation."""
        self.stop_event.set()
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()


class Hping3Generator(TrafficGenerator):
    """Traffic generator using hping3."""
    
    def __init__(self, config: Dict[str, Any], logger: Any):
        """
        Initialize hping3 traffic generator.
        
        Args:
            config: Configuration dictionary
            logger: Logger instance
        """
        super().__init__(config, logger)
        
        # hping3 specific parameters
        hping3_config = self.traffic_config.get('tool', {}).get('hping3', {})
        self.flags = hping3_config.get('flags', 'S')
        self.flood = hping3_config.get('flood', False)
    
    def generate_traffic(self) -> Dict[str, Any]:
        """
        Generate traffic using hping3.
        
        Returns:
            Dictionary containing generation results
        """
        self.logger.info("Starting hping3 traffic generation")
        
        results = {
            'tool': 'hping3',
            'start_time': get_timestamp(),
            'source_ips': self.source_ips,
            'packets_sent': 0,
            'errors': []
        }
        
        try:
            # Validate parameters
            self.validate_parameters()
            
            # Calculate total packets
            total_packets = len(self.source_ips) * self.packets_per_src
            self.logger.info(f"Generating {total_packets} packets from {len(self.source_ips)} source IPs")
            
            # Generate traffic from each source IP
            for src_ip in self.source_ips:
                if self.stop_event.is_set():
                    self.logger.warning("Traffic generation stopped by user")
                    break
                
                self.logger.info(f"Generating traffic from {src_ip}")
                
                # Build hping3 command
                cmd = self._build_hping3_command(src_ip)
                
                # Execute hping3
                try:
                    self.process = subprocess.Popen(
                        cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True
                    )
                    
                    # Wait for completion or timeout
                    try:
                        stdout, stderr = self.process.communicate(
                            timeout=self.duration_sec + 10
                        )
                        
                        if self.process.returncode != 0:
                            error_msg = f"hping3 failed with return code {self.process.returncode}"
                            if stderr:
                                error_msg += f": {stderr}"
                            results['errors'].append(error_msg)
                            self.logger.error(error_msg)
                        else:
                            # Parse output for packet count
                            packets_sent = self._parse_hping3_output(stdout)
                            results['packets_sent'] += packets_sent
                            self.logger.info(f"Sent {packets_sent} packets from {src_ip}")
                    
                    except subprocess.TimeoutExpired:
                        self.process.kill()
                        self.process.wait()
                        self.logger.warning(f"hping3 from {src_ip} timed out")
                        results['errors'].append(f"hping3 from {src_ip} timed out")
                
                except Exception as e:
                    error_msg = f"Failed to generate traffic from {src_ip}: {str(e)}"
                    results['errors'].append(error_msg)
                    self.logger.error(error_msg)
            
            results['end_time'] = get_timestamp()
            results['success'] = len(results['errors']) == 0
            
            self.logger.info(f"Traffic generation complete: {results['packets_sent']} packets sent")
            return results
        
        except Exception as e:
            self.logger.error(f"Traffic generation failed: {str(e)}", exc_info=True)
            results['success'] = False
            results['errors'].append(str(e))
            results['end_time'] = get_timestamp()
            return results
    
    def _build_hping3_command(self, src_ip: str) -> List[str]:
        """
        Build hping3 command for given source IP.
        
        Args:
            src_ip: Source IP address
            
        Returns:
            List of command arguments
        """
        cmd = [
            'hping3',
            '-c', str(self.packets_per_src),
            '-i', f'{self.interval_ms}ms',
            '-s', str(self.src_port) if self.src_port > 0 else '++',
            '-p', str(self.dst_port),
            '--ttl', str(self.ttl),
            '-a', src_ip,  # Spoof source IP
            self.dst_ip
        ]
        
        # Add protocol-specific flags
        if self.protocol == 'tcp':
            cmd.extend(['--tcp', '--tcpflags', self.flags])
        elif self.protocol == 'udp':
            cmd.append('--udp')
        elif self.protocol == 'icmp':
            cmd.append('--icmp')
        
        # Add flood mode if enabled
        if self.flood:
            cmd.append('-f')
        
        return cmd
    
    def _parse_hping3_output(self, output: str) -> int:
        """
        Parse hping3 output to extract packet count.
        
        Args:
            output: hping3 stdout
            
        Returns:
            Number of packets sent
        """
        # hping3 output format varies, try to extract packet count
        # Look for patterns like "100 packets transmitted"
        import re
        
        match = re.search(r'(\d+)\s+packets\s+transmitted', output)
        if match:
            return int(match.group(1))
        
        # Fallback: count lines
        return len(output.strip().split('\n')) if output.strip() else 0


class ScapyGenerator(TrafficGenerator):
    """Traffic generator using scapy."""
    
    def __init__(self, config: Dict[str, Any], logger: Any):
        """
        Initialize scapy traffic generator.
        
        Args:
            config: Configuration dictionary
            logger: Logger instance
        """
        super().__init__(config, logger)
        
        # Check if scapy is available
        try:
            from scapy.all import IP, TCP, UDP, ICMP, send
            self.IP = IP
            self.TCP = TCP
            self.UDP = UDP
            self.ICMP = ICMP
            self.send = send
            self.scapy_available = True
        except ImportError:
            self.logger.warning("scapy not available, falling back to hping3")
            self.scapy_available = False
    
    def generate_traffic(self) -> Dict[str, Any]:
        """
        Generate traffic using scapy.
        
        Returns:
            Dictionary containing generation results
        """
        if not self.scapy_available:
            self.logger.error("scapy is not available")
            return {
                'tool': 'scapy',
                'success': False,
                'errors': ['scapy not available'],
                'packets_sent': 0
            }
        
        self.logger.info("Starting scapy traffic generation")
        
        results = {
            'tool': 'scapy',
            'start_time': get_timestamp(),
            'source_ips': self.source_ips,
            'packets_sent': 0,
            'errors': []
        }
        
        try:
            # Validate parameters
            self.validate_parameters()
            
            # Calculate total packets
            total_packets = len(self.source_ips) * self.packets_per_src
            self.logger.info(f"Generating {total_packets} packets from {len(self.source_ips)} source IPs")
            
            # Generate traffic from each source IP
            for src_ip in self.source_ips:
                if self.stop_event.is_set():
                    self.logger.warning("Traffic generation stopped by user")
                    break
                
                self.logger.info(f"Generating traffic from {src_ip}")
                
                try:
                    # Build packet based on protocol
                    packets = self._build_packets(src_ip)
                    
                    # Send packets
                    sent_count = self.send(packets, verbose=0)
                    results['packets_sent'] += sent_count
                    
                    self.logger.info(f"Sent {sent_count} packets from {src_ip}")
                    
                    # Add delay between source IPs
                    time.sleep(self.interval_ms / 1000.0)
                
                except Exception as e:
                    error_msg = f"Failed to generate traffic from {src_ip}: {str(e)}"
                    results['errors'].append(error_msg)
                    self.logger.error(error_msg)
            
            results['end_time'] = get_timestamp()
            results['success'] = len(results['errors']) == 0
            
            self.logger.info(f"Traffic generation complete: {results['packets_sent']} packets sent")
            return results
        
        except Exception as e:
            self.logger.error(f"Traffic generation failed: {str(e)}", exc_info=True)
            results['success'] = False
            results['errors'].append(str(e))
            results['end_time'] = get_timestamp()
            return results
    
    def _build_packets(self, src_ip: str):
        """
        Build scapy packets for given source IP.
        
        Args:
            src_ip: Source IP address
            
        Returns:
            Scapy packet object
        """
        # Build IP layer
        ip_layer = self.IP(src=src_ip, dst=self.dst_ip, ttl=self.ttl)
        
        # Build transport layer based on protocol
        if self.protocol == 'tcp':
            transport_layer = self.TCP(
                sport=self.src_port if self.src_port > 0 else None,
                dport=self.dst_port,
                flags='S'  # SYN packet
            )
        elif self.protocol == 'udp':
            transport_layer = self.UDP(
                sport=self.src_port if self.src_port > 0 else None,
                dport=self.dst_port
            )
        elif self.protocol == 'icmp':
            transport_layer = self.ICMP()
        else:
            raise ValueError(f"Unsupported protocol: {self.protocol}")
        
        # Build packet
        packet = ip_layer / transport_layer
        
        # Create packet list
        packets = [packet] * self.packets_per_src
        
        return packets


# =============================================================================
# Traffic Generation Functions
# =============================================================================

def create_traffic_generator(
    config: Dict[str, Any],
    logger: Any,
    tool: Optional[str] = None
) -> TrafficGenerator:
    """
    Create appropriate traffic generator based on configuration.
    
    Args:
        config: Configuration dictionary
        logger: Logger instance
        tool: Tool to use (optional, uses config if not specified)
        
    Returns:
        TrafficGenerator instance
        
    Raises:
        ValueError: If tool is not supported
    """
    if tool is None:
        tool = config.get('traffic', {}).get('tool', {}).get('name', 'hping3')
    
    if tool == 'hping3':
        return Hping3Generator(config, logger)
    elif tool == 'scapy':
        return ScapyGenerator(config, logger)
    else:
        raise ValueError(f"Unsupported traffic generation tool: {tool}")


def validate_traffic_generation(
    results: Dict[str, Any],
    expected_packets: int
) -> Dict[str, Any]:
    """
    Validate traffic generation results.
    
    Args:
        results: Traffic generation results
        expected_packets: Expected number of packets
        
    Returns:
        Dictionary containing validation results
    """
    packets_sent = results.get('packets_sent', 0)
    errors = results.get('errors', [])
    
    # Calculate success rate
    success_rate = (packets_sent / expected_packets * 100) if expected_packets > 0 else 0
    
    # Determine if validation passed
    passed = (
        len(errors) == 0 and
        packets_sent >= expected_packets * 0.95  # Allow 5% tolerance
    )
    
    return {
        'passed': passed,
        'expected_packets': expected_packets,
        'actual_packets': packets_sent,
        'success_rate': float(success_rate),
        'errors': errors,
        'interpretation': (
            f"PASS: Sent {packets_sent}/{expected_packets} packets ({success_rate:.1f}%)"
            if passed
            else f"FAIL: Sent {packets_sent}/{expected_packets} packets ({success_rate:.1f}%)"
        )
    }


# =============================================================================
# Main Function
# =============================================================================

def main():
    """Main entry point for traffic generator script."""
    parser = argparse.ArgumentParser(
        description='ECMP Traffic Generator - Generate Traffic for ECMP Hash Testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate traffic with default configuration
  %(prog)s
  
  # Generate traffic with custom test ID
  %(prog)s --test-id 20240101_120000
  
  # Generate traffic using scapy
  %(prog)s --tool scapy
  
  # Generate traffic with custom duration
  %(prog)s --duration 120
  
  # Generate traffic with custom packet count
  %(prog)s --packets-per-src 5000
  
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
        '--tool',
        choices=['hping3', 'scapy'],
        help='Traffic generation tool (default: from config)'
    )
    
    parser.add_argument(
        '--test-id',
        help='Test identifier (default: auto-generated)'
    )
    
    parser.add_argument(
        '--duration',
        type=int,
        help='Test duration in seconds (overrides config)'
    )
    
    parser.add_argument(
        '--packets-per-src',
        type=int,
        help='Packets per source IP (overrides config)'
    )
    
    parser.add_argument(
        '--output-dir',
        default='results/traffic',
        help='Output directory for traffic results (default: results/traffic)'
    )
    
    parser.add_argument(
        '--validate',
        action='store_true',
        help='Validate traffic generation after completion'
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
    logger.info("ECMP Traffic Generator")
    logger.info("=" * 60)
    
    try:
        # Load configuration
        logger.info(f"Loading configuration from: {args.config}")
        config = load_config(args.config)
        
        # Validate configuration
        validate_config(config, ['test', 'topology', 'traffic'])
        logger.info("Configuration loaded and validated")
        
        # Override config with command-line arguments
        if args.duration:
            config['traffic']['duration_sec'] = args.duration
        if args.packets_per_src:
            config['traffic']['packets_per_src'] = args.packets_per_src
        
        # Ensure output directory exists
        output_dir = ensure_directory(args.output_dir)
        
        # Create traffic generator
        generator = create_traffic_generator(config, logger, args.tool)
        
        # Generate traffic
        logger.info("Starting traffic generation")
        results = generator.generate_traffic()
        
        # Save results
        test_id = args.test_id or get_test_id()
        results_file = output_dir / f"{test_id}_traffic.json"
        
        import json
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        logger.info(f"Traffic results saved to: {results_file}")
        
        # Validate if requested
        if args.validate:
            logger.info("Validating traffic generation")
            
            expected_packets = (
                len(generator.source_ips) * generator.packets_per_src
            )
            validation = validate_traffic_generation(results, expected_packets)
            
            logger.info(f"Validation: {validation['interpretation']}")
            
            # Save validation results
            validation_file = output_dir / f"{test_id}_validation.json"
            with open(validation_file, 'w') as f:
                json.dump(validation, f, indent=2)
            
            logger.info(f"Validation results saved to: {validation_file}")
        
        # Print summary
        print("\n" + "=" * 60)
        print("Traffic Generation Summary")
        print("=" * 60)
        print(f"Test ID: {test_id}")
        print(f"Tool: {results['tool']}")
        print(f"Source IPs: {len(results['source_ips'])}")
        print(f"Packets Sent: {results['packets_sent']}")
        print(f"Start Time: {results['start_time']}")
        print(f"End Time: {results['end_time']}")
        
        if results['errors']:
            print(f"\nErrors:")
            for error in results['errors']:
                print(f"  - {error}")
        
        print(f"\nSuccess: {results['success']}")
        print("=" * 60)
        
        logger.info("Traffic generation completed")
        return 0 if results['success'] else 1
        
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
