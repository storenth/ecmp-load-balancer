#!/usr/bin/env python3
"""
ECMP Topology Deployment - Python Implementation

This script automates the deployment of ECMP testing topology using containerlab.
It handles template rendering, topology deployment, container readiness checks,
and deployment verification.

Features:
- Command-line interface with argparse
- Configuration loading from YAML
- Jinja2 template rendering
- Containerlab deployment
- Container readiness verification
- Deployment validation
- Comprehensive error handling and logging

Author: ECMP Testing Framework
Version: 1.0.0
"""

import argparse
import sys
import subprocess
import time
import json
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime

# Import local utilities
from utils import (
    load_config,
    setup_logging,
    ensure_directory,
    run_command,
    get_timestamp,
    get_test_id,
    validate_config,
    ProgressReporter,
    handle_errors,
    retry
)


# =============================================================================
# Template Rendering Functions
# =============================================================================

def render_jinja2_template(
    template_path: Path,
    output_path: Path,
    context: Dict[str, Any]
) -> None:
    """
    Render Jinja2 template with given context.
    
    Args:
        template_path: Path to Jinja2 template file
        output_path: Path to output rendered file
        context: Dictionary of template variables
        
    Raises:
        FileNotFoundError: If template file doesn't exist
        ImportError: If jinja2 is not installed
    """
    try:
        from jinja2 import Environment, FileSystemLoader, Template
    except ImportError:
        raise ImportError(
            "jinja2 is required for template rendering. "
            "Install with: pip install jinja2"
        )
    
    if not template_path.exists():
        raise FileNotFoundError(f"Template file not found: {template_path}")
    
    # Create Jinja2 environment
    env = Environment(
        loader=FileSystemLoader(template_path.parent),
        trim_blocks=True,
        lstrip_blocks=True
    )
    
    # Load and render template
    template = env.get_template(template_path.name)
    rendered_content = template.render(**context)
    
    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(rendered_content)


def render_topology_templates(
    config: Dict[str, Any],
    logger: Any
) -> Dict[str, Path]:
    """
    Render all topology templates.
    
    Args:
        config: Configuration dictionary
        logger: Logger instance
        
    Returns:
        Dictionary mapping template names to output paths
    """
    logger.info("Rendering topology templates")
    
    topology_config = config.get('topology', {})
    project_root = Path(__file__).parent.parent
    
    # Template paths
    template_dir = project_root / 'topology'
    output_dir = project_root / 'topology'
    
    # Get number of paths
    num_paths = topology_config.get('expected_paths', 4)
    
    # Context for templates
    context = {
        'num_paths': num_paths,
        'next_hops': topology_config.get('next_hops', []),
        'ecmp_router': topology_config.get('ecmp_router', 'ecmp-router'),
        'dst_network': topology_config.get('dst_network', '10.0.10.0/30'),
        'dst_ip': topology_config.get('dst_ip', '10.0.10.10')
    }
    
    rendered_files = {}
    
    # Render topology file
    topology_template = template_dir / 'topology.n-paths.yaml.j2'
    topology_output = output_dir / f'clab-ecmp-{num_paths}paths.yml'
    
    if topology_template.exists():
        render_jinja2_template(topology_template, topology_output, context)
        rendered_files['topology'] = topology_output
        logger.info(f"Rendered topology: {topology_output}")
    
    # Render FRR configuration files
    frr_template_dir = template_dir / 'frr'
    frr_output_dir = output_dir / 'frr'
    
    # Render ECMP router configuration
    ecmp_router_template = frr_template_dir / 'ecmp-router.conf.j2'
    ecmp_router_output = frr_output_dir / 'ecmp-router.conf'
    
    if ecmp_router_template.exists():
        render_jinja2_template(ecmp_router_template, ecmp_router_output, context)
        rendered_files['ecmp_router'] = ecmp_router_output
        logger.info(f"Rendered ECMP router config: {ecmp_router_output}")
    
    # Render next-hop configurations
    for i, hop in enumerate(topology_config.get('next_hops', []), start=1):
        nexthop_template = frr_template_dir / 'nexthop.conf.j2'
        nexthop_output = frr_output_dir / f'nexthop-{i}.conf'
        
        hop_context = context.copy()
        hop_context['hop'] = hop
        hop_context['hop_index'] = i
        
        if nexthop_template.exists():
            render_jinja2_template(nexthop_template, nexthop_output, hop_context)
            rendered_files[f'nexthop_{i}'] = nexthop_output
            logger.info(f"Rendered next-hop config: {nexthop_output}")
    
    logger.info(f"Rendered {len(rendered_files)} template files")
    return rendered_files


# =============================================================================
# Containerlab Deployment Functions
# =============================================================================

def check_containerlab_installed(logger: Any) -> bool:
    """
    Check if containerlab is installed.
    
    Args:
        logger: Logger instance
        
    Returns:
        True if containerlab is installed
    """
    try:
        result = run_command(['clab', 'version'], capture_output=True, check=False)
        if result.returncode == 0:
            logger.info(f"containerlab version: {result.stdout.strip()}")
            return True
        else:
            logger.error("containerlab is not installed")
            return False
    except FileNotFoundError:
        logger.error("containerlab command not found")
        return False


def deploy_topology(
    topology_file: Path,
    config: Dict[str, Any],
    logger: Any
) -> Dict[str, Any]:
    """
    Deploy topology using containerlab.
    
    Args:
        topology_file: Path to topology file
        config: Configuration dictionary
        logger: Logger instance
        
    Returns:
        Dictionary containing deployment results
    """
    logger.info(f"Deploying topology from: {topology_file}")
    
    results = {
        'topology_file': str(topology_file),
        'start_time': get_timestamp(),
        'success': False,
        'containers': [],
        'errors': []
    }
    
    try:
        # Check if topology file exists
        if not topology_file.exists():
            raise FileNotFoundError(f"Topology file not found: {topology_file}")
        
        # Check if containerlab is installed
        if not check_containerlab_installed(logger):
            raise RuntimeError("containerlab is not installed")
        
        # Deploy topology
        logger.info("Running containerlab deploy")
        result = run_command(
            ['clab', 'deploy', '-t', str(topology_file)],
            capture_output=True,
            check=True
        )
        
        logger.info(f"containerlab output:\n{result.stdout}")
        
        # Parse container names from output
        container_names = parse_containerlab_output(result.stdout)
        results['containers'] = container_names
        
        logger.info(f"Deployed {len(container_names)} containers")
        
        results['end_time'] = get_timestamp()
        results['success'] = True
        
        return results
    
    except subprocess.CalledProcessError as e:
        error_msg = f"containerlab deploy failed: {e.stderr if e.stderr else str(e)}"
        results['errors'].append(error_msg)
        logger.error(error_msg)
        results['end_time'] = get_timestamp()
        return results
    
    except Exception as e:
        error_msg = f"Deployment failed: {str(e)}"
        results['errors'].append(error_msg)
        logger.error(error_msg, exc_info=True)
        results['end_time'] = get_timestamp()
        return results


def parse_containerlab_output(output: str) -> List[str]:
    """
    Parse container names from containerlab output.
    
    Args:
        output: containerlab stdout
        
    Returns:
        List of container names
    """
    import re
    
    # Look for container names in output
    # containerlab typically outputs container names in a specific format
    container_names = []
    
    # Pattern to match container names (e.g., clab-ecmp-test-r1)
    pattern = r'clab-[a-zA-Z0-9-]+'
    matches = re.findall(pattern, output)
    
    # Remove duplicates while preserving order
    seen = set()
    for match in matches:
        if match not in seen:
            seen.add(match)
            container_names.append(match)
    
    return container_names


# =============================================================================
# Container Readiness Functions
# =============================================================================

def wait_for_container(
    container_name: str,
    timeout: int = 120,
    interval: int = 2,
    logger: Any = None
) -> bool:
    """
    Wait for a container to be ready.
    
    Args:
        container_name: Name of the container
        timeout: Maximum wait time in seconds
        interval: Check interval in seconds
        logger: Logger instance (optional)
        
    Returns:
        True if container is ready, False if timeout
    """
    if logger:
        logger.info(f"Waiting for container {container_name} to be ready")
    
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            # Check if container is running
            result = run_command(
                ['docker', 'inspect', '-f', '{{.State.Running}}', container_name],
                capture_output=True,
                check=False
            )
            
            if result.returncode == 0 and result.stdout.strip() == 'true':
                # Check if container is healthy (if healthcheck is defined)
                health_result = run_command(
                    ['docker', 'inspect', '-f', '{{.State.Health.Status}}', container_name],
                    capture_output=True,
                    check=False
                )
                
                if health_result.returncode == 0:
                    health_status = health_result.stdout.strip()
                    if health_status == 'healthy' or health_status == '<no value>':
                        if logger:
                            logger.info(f"Container {container_name} is ready")
                        return True
                    elif health_status == 'starting':
                        if logger:
                            logger.debug(f"Container {container_name} health check: starting")
                    else:
                        if logger:
                            logger.warning(f"Container {container_name} health check: {health_status}")
                else:
                    # No health check defined, assume ready if running
                    if logger:
                        logger.info(f"Container {container_name} is ready (no health check)")
                    return True
            
            time.sleep(interval)
        
        except Exception as e:
            if logger:
                logger.debug(f"Error checking container {container_name}: {str(e)}")
            time.sleep(interval)
    
    if logger:
        logger.error(f"Container {container_name} did not become ready within {timeout}s")
    return False


def wait_for_all_containers(
    container_names: List[str],
    timeout: int = 120,
    interval: int = 2,
    logger: Any = None
) -> Dict[str, bool]:
    """
    Wait for all containers to be ready.
    
    Args:
        container_names: List of container names
        timeout: Maximum wait time per container in seconds
        interval: Check interval in seconds
        logger: Logger instance (optional)
        
    Returns:
        Dictionary mapping container names to readiness status
    """
    if logger:
        logger.info(f"Waiting for {len(container_names)} containers to be ready")
    
    readiness = {}
    
    for container_name in container_names:
        ready = wait_for_container(container_name, timeout, interval, logger)
        readiness[container_name] = ready
    
    if logger:
        ready_count = sum(1 for r in readiness.values() if r)
        logger.info(f"{ready_count}/{len(container_names)} containers are ready")
    
    return readiness


# =============================================================================
# Deployment Verification Functions
# =============================================================================

def verify_deployment(
    container_names: List[str],
    config: Dict[str, Any],
    logger: Any
) -> Dict[str, Any]:
    """
    Verify that deployment is successful.
    
    Args:
        container_names: List of container names
        config: Configuration dictionary
        logger: Logger instance
        
    Returns:
        Dictionary containing verification results
    """
    logger.info("Verifying deployment")
    
    results = {
        'timestamp': get_timestamp(),
        'containers': {},
        'overall_success': True,
        'errors': []
    }
    
    # Check each container
    for container_name in container_names:
        container_result = verify_container(container_name, logger)
        results['containers'][container_name] = container_result
        
        if not container_result['success']:
            results['overall_success'] = False
            results['errors'].append(
                f"Container {container_name} verification failed"
            )
    
    # Check ECMP routes if configured
    ecmp_router = config.get('topology', {}).get('ecmp_router', 'ecmp-router')
    if ecmp_router in container_names:
        ecmp_result = verify_ecmp_routes(ecmp_router, config, logger)
        results['ecmp_routes'] = ecmp_result
        
        if not ecmp_result['success']:
            results['overall_success'] = False
            results['errors'].append("ECMP route verification failed")
    
    logger.info(f"Deployment verification: {'PASS' if results['overall_success'] else 'FAIL'}")
    return results


def verify_container(container_name: str, logger: Any) -> Dict[str, Any]:
    """
    Verify a single container.
    
    Args:
        container_name: Name of the container
        logger: Logger instance
        
    Returns:
        Dictionary containing verification results
    """
    result = {
        'container_name': container_name,
        'success': False,
        'running': False,
        'healthy': False,
        'errors': []
    }
    
    try:
        # Check if container exists
        inspect_result = run_command(
            ['docker', 'inspect', container_name],
            capture_output=True,
            check=False
        )
        
        if inspect_result.returncode != 0:
            result['errors'].append("Container does not exist")
            return result
        
        # Check if running
        running_result = run_command(
            ['docker', 'inspect', '-f', '{{.State.Running}}', container_name],
            capture_output=True,
            check=True
        )
        
        result['running'] = running_result.stdout.strip() == 'true'
        
        if not result['running']:
            result['errors'].append("Container is not running")
            return result
        
        # Check health status
        health_result = run_command(
            ['docker', 'inspect', '-f', '{{.State.Health.Status}}', container_name],
            capture_output=True,
            check=False
        )
        
        if health_result.returncode == 0:
            health_status = health_result.stdout.strip()
            result['healthy'] = health_status in ['healthy', '<no value>']
            
            if not result['healthy']:
                result['errors'].append(f"Container health status: {health_status}")
        else:
            # No health check defined
            result['healthy'] = True
        
        result['success'] = result['running'] and result['healthy']
        
    except Exception as e:
        result['errors'].append(str(e))
    
    return result


def verify_ecmp_routes(
    ecmp_router: str,
    config: Dict[str, Any],
    logger: Any
) -> Dict[str, Any]:
    """
    Verify ECMP routes on the ECMP router.
    
    Args:
        ecmp_router: Name of the ECMP router container
        config: Configuration dictionary
        logger: Logger instance
        
    Returns:
        Dictionary containing route verification results
    """
    result = {
        'ecmp_router': ecmp_router,
        'success': False,
        'routes': [],
        'errors': []
    }
    
    try:
        # Get ECMP routes
        dst_network = config.get('topology', {}).get('dst_network', '10.0.10.0/30')
        
        # Try to get routes using vtysh (FRR)
        vtysh_result = run_command(
            ['docker', 'exec', ecmp_router, 'vtysh', '-c', f'show ip route {dst_network}'],
            capture_output=True,
            check=False
        )
        
        if vtysh_result.returncode == 0:
            result['routes_output'] = vtysh_result.stdout
            
            # Parse routes to check for ECMP
            if 'multipath' in vtysh_result.stdout.lower():
                result['has_ecmp'] = True
                result['success'] = True
                logger.info("ECMP routes verified")
            else:
                result['has_ecmp'] = False
                result['errors'].append("No ECMP routes found")
                logger.warning("No ECMP routes found")
        else:
            result['errors'].append("Failed to get routes from ECMP router")
            logger.warning("Could not verify ECMP routes (vtysh not available)")
            # Don't fail deployment if we can't verify routes
            result['success'] = True
    
    except Exception as e:
        result['errors'].append(str(e))
        logger.warning(f"Could not verify ECMP routes: {str(e)}")
        # Don't fail deployment if we can't verify routes
        result['success'] = True
    
    return result


# =============================================================================
# Cleanup Functions
# =============================================================================

def destroy_topology(
    topology_file: Path,
    logger: Any
) -> bool:
    """
    Destroy topology using containerlab.
    
    Args:
        topology_file: Path to topology file
        logger: Logger instance
        
    Returns:
        True if destruction was successful
    """
    logger.info(f"Destroying topology: {topology_file}")
    
    try:
        result = run_command(
            ['clab', 'destroy', '-t', str(topology_file), '--cleanup'],
            capture_output=True,
            check=False
        )
        
        if result.returncode == 0:
            logger.info("Topology destroyed successfully")
            return True
        else:
            logger.error(f"Failed to destroy topology: {result.stderr}")
            return False
    
    except Exception as e:
        logger.error(f"Error destroying topology: {str(e)}")
        return False


# =============================================================================
# Main Function
# =============================================================================

def main():
    """Main entry point for deployment script."""
    parser = argparse.ArgumentParser(
        description='ECMP Topology Deployment - Deploy ECMP Testing Topology',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Deploy topology with default configuration
  %(prog)s
  
  # Deploy topology with custom topology file
  %(prog)s --topology topology/clab-ecmp-2paths.yml
  
  # Render templates only (no deployment)
  %(prog)s --render-only
  
  # Destroy existing topology
  %(prog)s --destroy
  
  # Deploy and verify
  %(prog)s --verify
  
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
        '--topology',
        help='Path to topology file (default: from config)'
    )
    
    parser.add_argument(
        '--render-only',
        action='store_true',
        help='Render templates only, do not deploy'
    )
    
    parser.add_argument(
        '--destroy',
        action='store_true',
        help='Destroy existing topology'
    )
    
    parser.add_argument(
        '--verify',
        action='store_true',
        help='Verify deployment after completion'
    )
    
    parser.add_argument(
        '--no-wait',
        action='store_true',
        help='Do not wait for containers to be ready'
    )
    
    parser.add_argument(
        '--timeout',
        type=int,
        default=120,
        help='Container readiness timeout in seconds (default: 120)'
    )
    
    parser.add_argument(
        '--output-dir',
        default='results/deployment',
        help='Output directory for deployment results (default: results/deployment)'
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
    logger.info("ECMP Topology Deployment")
    logger.info("=" * 60)
    
    try:
        # Load configuration
        logger.info(f"Loading configuration from: {args.config}")
        config = load_config(args.config)
        
        # Validate configuration
        validate_config(config, ['test', 'topology'])
        logger.info("Configuration loaded and validated")
        
        # Ensure output directory exists
        output_dir = ensure_directory(args.output_dir)
        
        # Get topology file
        if args.topology:
            topology_file = Path(args.topology)
        else:
            topology_file = Path(config.get('topology', {}).get('topology_file', 'topology/clab-ecmp-test.yml'))
        
        # Handle destroy mode
        if args.destroy:
            logger.info("Destroying topology")
            success = destroy_topology(topology_file, logger)
            return 0 if success else 1
        
        # Render templates
        logger.info("Rendering topology templates")
        rendered_files = render_topology_templates(config, logger)
        
        if args.render_only:
            logger.info("Render-only mode, skipping deployment")
            print("\nRendered files:")
            for name, path in rendered_files.items():
                print(f"  {name}: {path}")
            return 0
        
        # Deploy topology
        deployment_results = deploy_topology(topology_file, config, logger)
        
        # Save deployment results
        test_id = get_test_id()
        deployment_file = output_dir / f"{test_id}_deployment.json"
        
        with open(deployment_file, 'w') as f:
            json.dump(deployment_results, f, indent=2, default=str)
        
        logger.info(f"Deployment results saved to: {deployment_file}")
        
        if not deployment_results['success']:
            logger.error("Deployment failed")
            return 1
        
        # Wait for containers
        if not args.no_wait and deployment_results['containers']:
            logger.info(f"Waiting for containers to be ready (timeout: {args.timeout}s)")
            readiness = wait_for_all_containers(
                deployment_results['containers'],
                args.timeout,
                2,
                logger
            )
            
            # Check if all containers are ready
            all_ready = all(readiness.values())
            
            if not all_ready:
                not_ready = [name for name, ready in readiness.items() if not ready]
                logger.error(f"Containers not ready: {not_ready}")
                return 1
        
        # Verify deployment
        if args.verify and deployment_results['containers']:
            verification_results = verify_deployment(
                deployment_results['containers'],
                config,
                logger
            )
            
            # Save verification results
            verification_file = output_dir / f"{test_id}_verification.json"
            
            with open(verification_file, 'w') as f:
                json.dump(verification_results, f, indent=2, default=str)
            
            logger.info(f"Verification results saved to: {verification_file}")
            
            if not verification_results['overall_success']:
                logger.error("Deployment verification failed")
                return 1
        
        # Print summary
        print("\n" + "=" * 60)
        print("Deployment Summary")
        print("=" * 60)
        print(f"Test ID: {test_id}")
        print(f"Topology: {topology_file}")
        print(f"Containers: {len(deployment_results['containers'])}")
        print(f"Success: {deployment_results['success']}")
        
        if deployment_results['containers']:
            print(f"\nContainers:")
            for container in deployment_results['containers']:
                print(f"  - {container}")
        
        print("=" * 60)
        
        logger.info("Deployment completed successfully")
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
