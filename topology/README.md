# Dynamic Topology Generation with Jinja2 Templates

This directory contains Jinja2 templates for generating ECMP topologies with variable numbers of paths.

## Overview

The dynamic topology generation system allows you to create Containerlab topologies with any number of ECMP paths (2, 3, 4, or more) without manually editing configuration files. This is particularly useful for testing ECMP hash distribution across different path counts.

## Files

### Templates

- **`topology.n-paths.yaml.j2`** - Main Containerlab topology template
  - Generates edge router with N interfaces for ECMP paths
  - Generates N next-hop routers
  - Generates appropriate network links
  - Uses IP addressing scheme: 10.0.1.0/24 for source, 10.0.2.0/24 to 10.0.N+1.0/24 for paths, 192.168.100.0/24 for destination

- **`frr/ecmp-router.conf.j2`** - FRR configuration template for edge router
  - Generates interface configurations for N paths
  - Generates N equal-cost static routes to destination network
  - Configures BGP with maximum-paths set to N
  - Configures zebra with ECMP hash policy (src-ip)

- **`frr/nexthop.conf.j2`** - FRR configuration template for next-hop routers
  - Basic FRR configuration for each next-hop router
  - Static route back to traffic generator
  - BGP configuration for advertising destination network

- **`frr/sysctl.d/hash-policy.conf`** - Kernel ECMP hash configuration
  - Sets net.ipv4.fib_multipath_hash_policy=1 (Layer 4 hashing)
  - Includes additional kernel tuning for ECMP performance

### Generated Files

When you render templates, the following files are generated:

- `topology/clab-ecmp-Npaths.yml` - Containerlab topology file
- `topology/frr/ecmp-router.conf` - Edge router FRR configuration
- `topology/frr/nexthop-1.conf` to `topology/frr/nexthop-N.conf` - Next-hop router configurations

## Usage

### Using the Python Script Directly

```bash
# Render topology with 2 ECMP paths
python3 scripts/render_topology.py --num-paths 2

# Render topology with 3 ECMP paths and verbose output
python3 scripts/render_topology.py --num-paths 3 --verbose

# Render topology with 4 ECMP paths
python3 scripts/render_topology.py --num-paths 4

# Render topology with custom output directory
python3 scripts/render_topology.py --num-paths 2 --output-dir custom/topology
```

### Using Make

```bash
# Render topology with 2 ECMP paths
make render-topology N=2

# Render topology with 3 ECMP paths
make render-topology N=3

# Render topology with 4 ECMP paths (default)
make render-topology N=4

# Render with verbose output
make render-topology N=2 VERBOSE=1
```

### Deploying Generated Topology

After rendering, deploy the topology using Containerlab:

```bash
# Deploy 2-path topology
make TOPOLOGY=topology/clab-ecmp-2paths.yml deploy

# Deploy 3-path topology
make TOPOLOGY=topology/clab-ecmp-3paths.yml deploy

# Deploy 4-path topology
make TOPOLOGY=topology/clab-ecmp-4paths.yml deploy
```

Or using clab directly:

```bash
clab deploy -t topology/clab-ecmp-2paths.yml
```

## IP Addressing Scheme

The generated topologies use the following IP addressing scheme:

| Network | Purpose | Example (N=4) |
|----------|---------|-----------------|
| 10.0.1.0/24 | Source network (hosts to edge router) | 10.0.1.1/24 (R1), 10.0.1.10-13/24 (h1-h4) |
| 10.0.2.0/24 | ECMP Path 1 (R1 to R2) | 10.0.2.1/24 (R1), 10.0.2.2/24 (R2) |
| 10.0.3.0/24 | ECMP Path 2 (R1 to R3) | 10.0.3.1/24 (R1), 10.0.3.2/24 (R3) |
| 10.0.4.0/24 | ECMP Path 3 (R1 to R4) | 10.0.4.1/24 (R1), 10.0.4.2/24 (R4) |
| 10.0.5.0/24 | ECMP Path 4 (R1 to R5) | 10.0.5.1/24 (R1), 10.0.5.2/24 (R5) |
| 10.0.6.0/24 to 10.0.9.0/24 | Core to destination links | 10.0.6.1/24 (R2), 10.0.6.2/24 (R6), etc. |
| 192.168.100.0/24 | Destination network | 192.168.100.1/24 (R6), 192.168.100.10/24 (d1) |

For N paths, the addressing scales as follows:
- Path i uses 10.0.(i+1).0/24 for the R1 to R(i+1) link
- Core to destination links use 10.0.(N+i+1).0/24

## ECMP Configuration

### Edge Router (R1)

The edge router is configured with:
- **N equal-cost static routes** to 192.168.100.0/24 with metric 100
- **BGP maximum-paths** set to N
- **Zebra hash policy** set to src-ip for consistent flow hashing
- **OSPF** advertising all path networks

### Next-Hop Routers (R2 to R(N+1))

Each next-hop router is configured with:
- Static route back to source network (10.0.1.0/24)
- Static route to destination network (192.168.100.0/24)
- BGP advertising the destination network

### Kernel Configuration

The hash policy configuration includes:
- `net.ipv4.fib_multipath_hash_policy=1` - Layer 4 hashing (src/dst IP and ports)
- `net.ipv4.fib_multipath=1` - Enable ECMP support
- Additional TCP/IP tuning for better performance

## Testing Scenarios

### 2-Path ECMP

```bash
make render-topology N=2
make TOPOLOGY=topology/clab-ecmp-2paths.yml deploy
make configure
make test
```

### 3-Path ECMP

```bash
make render-topology N=3
make TOPOLOGY=topology/clab-ecmp-3paths.yml deploy
make configure
make test
```

### 4-Path ECMP

```bash
make render-topology N=4
make TOPOLOGY=topology/clab-ecmp-4paths.yml deploy
make configure
make test
```

### Custom Path Count

```bash
make render-topology N=6
make TOPOLOGY=topology/clab-ecmp-6paths.yml deploy
make configure
make test
```

## Validation

After deployment, verify ECMP is working:

```bash
# Check ECMP routes on edge router
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Check BGP neighbors
docker exec clab-ecmp-test-r1 vtysh -c "show ip bgp summary"

# Check kernel hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy
```

## Troubleshooting

### Template Rendering Errors

If you encounter errors during template rendering:

1. Ensure Jinja2 is installed: `pip install jinja2`
2. Check that num_paths is a positive integer (>= 1)
3. Verify template files exist in the topology directory

### Deployment Issues

If the topology fails to deploy:

1. Check that Containerlab is installed: `clab version`
2. Verify Docker is running: `docker ps`
3. Check for port conflicts: `docker ps -a`
4. Review Containerlab logs: `clab deploy -t topology/clab-ecmp-Npaths.yml --debug`

### ECMP Not Working

If traffic is not distributed across paths:

1. Verify static routes are installed: `docker exec clab-ecmp-test-r1 vtysh -c "show ip route"`
2. Check BGP maximum-paths: `docker exec clab-ecmp-test-r1 vtysh -c "show running-config | include maximum-paths"`
3. Verify hash policy: `docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy`
4. Check kernel ECMP support: `docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath`

## Architecture Reference

For more details on the ECMP testing framework architecture, see:
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall system architecture
- [docs/QUICK_START.md](../docs/QUICK_START.md) - Quick start guide
- [docs/TEST_PLAN.md](../docs/TEST_PLAN.md) - Testing procedures

## Contributing

When modifying templates:

1. Maintain backward compatibility with existing scripts
2. Follow the existing IP addressing scheme
3. Update this README with any new features
4. Test with multiple path counts (2, 3, 4, 6, 8)
5. Ensure generated configurations are valid FRR syntax

## License

This template system is part of the ECMP Testing Framework.
