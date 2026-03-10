#!/usr/bin/env python3
"""
Render Jinja2 templates for dynamic ECMP topology generation.

This script generates Containerlab topology files and FRR configurations
for testing with different numbers of ECMP paths.

Usage:
    python scripts/render_topology.py --num-paths 4
    python scripts/render_topology.py --num-paths 2 --output topology/clab-ecmp-2paths.yml
    python scripts/render_topology.py --num-paths 3 --verbose

Reference: ARCHITECTURE.md
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, Any

try:
    from jinja2 import Environment, FileSystemLoader, TemplateError
except ImportError:
    print("Error: jinja2 is not installed. Install it with: pip install jinja2")
    sys.exit(1)


def validate_num_paths(num_paths: int) -> bool:
    """
    Validate the number of ECMP paths.
    
    Args:
        num_paths: Number of ECMP paths to validate
        
    Returns:
        True if valid, False otherwise
    """
    if num_paths < 1:
        print(f"Error: num_paths must be at least 1, got {num_paths}")
        return False
    if num_paths > 16:
        print(f"Warning: num_paths={num_paths} is unusually large. Consider using a smaller value.")
    return True


def render_template(env: Environment, template_name: str, context: Dict[str, Any], 
                    output_path: str, verbose: bool = False) -> bool:
    """
    Render a Jinja2 template and save to file.
    
    Args:
        env: Jinja2 environment
        template_name: Name of the template file
        context: Dictionary of variables for template rendering
        output_path: Path where rendered file should be saved
        verbose: Enable verbose output
        
    Returns:
        True if successful, False otherwise
    """
    try:
        template = env.get_template(template_name)
        rendered = template.render(**context)
        
        # Create output directory if it doesn't exist
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        
        # Write rendered content to file
        with open(output_path, 'w') as f:
            f.write(rendered)
        
        if verbose:
            print(f"✓ Rendered {template_name} -> {output_path}")
        
        return True
        
    except TemplateError as e:
        print(f"Error rendering template {template_name}: {e}")
        return False
    except IOError as e:
        print(f"Error writing to {output_path}: {e}")
        return False


def render_topology(num_paths: int, output_dir: str = None, verbose: bool = False) -> bool:
    """
    Render all templates for the specified number of ECMP paths.
    
    Args:
        num_paths: Number of ECMP paths
        output_dir: Directory for output files (default: topology/)
        verbose: Enable verbose output
        
    Returns:
        True if all templates rendered successfully, False otherwise
    """
    # Set default output directory
    if output_dir is None:
        output_dir = "topology"
    
    # Setup Jinja2 environment
    template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "topology")
    env = Environment(loader=FileSystemLoader(template_dir))
    
    # Context variables for templates
    context = {
        'num_paths': num_paths
    }
    
    if verbose:
        print(f"\nRendering topology with {num_paths} ECMP paths...")
        print(f"Template directory: {template_dir}")
        print(f"Output directory: {output_dir}\n")
    
    success = True
    
    # Render main topology file
    topology_output = os.path.join(output_dir, f"clab-ecmp-{num_paths}paths.yml")
    if not render_template(env, "topology.n-paths.yaml.j2", context, topology_output, verbose):
        success = False
    
    # Render edge router FRR configuration
    frr_output = os.path.join(output_dir, "frr", "ecmp-router.conf")
    if not render_template(env, "frr/ecmp-router.conf.j2", context, frr_output, verbose):
        success = False
    
    # Render next-hop router configurations
    for i in range(1, num_paths + 1):
        nexthop_context = {
            'num_paths': num_paths,
            'path_num': i,
            'router_num': i + 1
        }
        nexthop_output = os.path.join(output_dir, "frr", f"nexthop-{i}.conf")
        if not render_template(env, "frr/nexthop.conf.j2", nexthop_context, nexthop_output, verbose):
            success = False
    
    if success and verbose:
        print(f"\n✓ Successfully rendered topology with {num_paths} ECMP paths")
        print(f"  - Topology file: {topology_output}")
        print(f"  - Edge router config: {frr_output}")
        print(f"  - Next-hop configs: {num_paths} files in {os.path.join(output_dir, 'frr')}")
    
    return success


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Render Jinja2 templates for dynamic ECMP topology generation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Render topology with 4 ECMP paths (default)
  %(prog)s --num-paths 4
  
  # Render topology with 2 ECMP paths
  %(prog)s --num-paths 2
  
  # Render topology with 3 ECMP paths and verbose output
  %(prog)s --num-paths 3 --verbose
  
  # Render topology with custom output directory
  %(prog)s --num-paths 4 --output-dir custom/topology
  
  # Render topology with custom topology file name
  %(prog)s --num-paths 2 --topology-output my-topology.yml
        """
    )
    
    parser.add_argument(
        '--num-paths', '-n',
        type=int,
        required=True,
        help='Number of ECMP paths (default: 4)'
    )
    
    parser.add_argument(
        '--output-dir', '-o',
        type=str,
        default='topology',
        help='Output directory for rendered files (default: topology)'
    )
    
    parser.add_argument(
        '--topology-output',
        type=str,
        default=None,
        help='Custom name for topology file (default: clab-ecmp-{N}paths.yml)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    args = parser.parse_args()
    
    # Validate num_paths
    if not validate_num_paths(args.num_paths):
        sys.exit(1)
    
    # Render topology
    success = render_topology(
        num_paths=args.num_paths,
        output_dir=args.output_dir,
        verbose=args.verbose
    )
    
    if success:
        sys.exit(0)
    else:
        print("\nError: Failed to render one or more templates")
        sys.exit(1)


if __name__ == '__main__':
    main()
