# ECMP Testing Scripts

This directory contains scripts for traffic generation, capture, and test execution for ECMP hash testing.

## Overview

The scripts implement the traffic generation and capture components specified in the ARCHITECTURE.md design. They support both manual execution and CI/CD automation.

## Scripts

### Main Scripts

#### [`generate_traffic.sh`](generate_traffic.sh)
Generates test traffic from source hosts (h1-h4) to destination (d1) with controlled Source IP addresses.

**Features:**
- Varies Source IP addresses while keeping other parameters constant
- Supports hping3 and ping for traffic generation
- Configurable traffic volume and duration
- Logging and progress reporting
- Multiple test scenarios

**Usage:**
```bash
./generate_traffic.sh [options]
```

**Options:**
- `-c, --config FILE` - Path to traffic configuration file
- `-s, --scenario NAME` - Test scenario to execute
- `-d, --duration SECONDS` - Test duration in seconds
- `-n, --count NUM` - Number of packets per source
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
./generate_traffic.sh
./generate_traffic.sh --scenario high_volume
./generate_traffic.sh --duration 120 --count 5000
```

**Reference:** https://linux.die.net/man/8/hping3

---

#### [`capture_traffic.sh`](capture_traffic.sh)
Captures traffic on each ECMP path using tcpdump at monitoring points on core routers (r2-r5).

**Features:**
- Parallel capture on multiple ECMP paths
- Configurable capture filters (BPF syntax)
- Automatic tcpdump installation in containers
- Capture file organization with timestamps
- Capture verification and validation

**Usage:**
```bash
./capture_traffic.sh [options]
```

**Options:**
- `-c, --config FILE` - Path to traffic configuration file
- `-d, --duration SECONDS` - Capture duration in seconds
- `-o, --output DIR` - Output directory for capture files
- `-f, --filter FILTER` - BPF filter for packet capture
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
./capture_traffic.sh
./capture_traffic.sh --duration 120
./capture_traffic.sh --output /tmp/captures
```

**Reference:** https://www.tcpdump.org/manpages/tcpdump.1.html

---

#### [`run_test.sh`](run_test.sh)
Orchestrates the complete test execution including traffic capture, generation, and data organization.

**Features:**
- Starts traffic captures on all paths
- Generates traffic from source hosts
- Stops captures after test completion
- Organizes captured data for analysis
- Error handling and cleanup
- Configurable test parameters

**Usage:**
```bash
./run_test.sh [options]
```

**Options:**
- `-c, --config FILE` - Path to traffic configuration file
- `-s, --scenario NAME` - Test scenario to execute
- `-d, --duration SECONDS` - Test duration in seconds
- `-n, --count NUM` - Number of packets per source
- `-o, --output DIR` - Output directory for test results
- `--no-cleanup` - Skip cleanup after test completion
- `--preserve-captures` - Preserve capture files
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
./run_test.sh
./run_test.sh --scenario high_volume
./run_test.sh --duration 120 --count 5000
```

---

### Helper Scripts

#### [`helpers/wait_for_container.sh`](helpers/wait_for_container.sh)
Waits for one or more containers to be ready and running.

**Features:**
- Checks if containers are running
- Optionally verifies network connectivity
- Supports wildcard container names
- Configurable timeout and interval

**Usage:**
```bash
./helpers/wait_for_container.sh [options] [container...]
```

**Options:**
- `-t, --timeout SECONDS` - Maximum time to wait (default: 60)
- `-i, --interval SECONDS` - Check interval (default: 1)
- `-c, --check-connectivity` - Verify network connectivity
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
./helpers/wait_for_container.sh clab-ecmp-test-h1 clab-ecmp-test-h2
./helpers/wait_for_container.sh --timeout 120 --check-connectivity clab-ecmp-test-r1
./helpers/wait_for_container.sh clab-ecmp-test-*
```

---

#### [`helpers/check_connectivity.sh`](helpers/check_connectivity.sh)
Verifies network connectivity between containers in the ECMP topology.

**Features:**
- Tests reachability between source hosts, routers, and destination
- Supports ping, TCP, and UDP connectivity tests
- Can check all connectivity paths in topology
- Detailed logging and reporting

**Usage:**
```bash
./helpers/check_connectivity.sh [options]
```

**Options:**
- `-s, --source CONTAINER` - Source container name
- `-d, --destination IP` - Destination IP address
- `-p, --port PORT` - Destination port (for TCP/UDP)
- `-t, --type TYPE` - Test type: ping, tcp, udp (default: ping)
- `-c, --count NUM` - Number of packets to send (default: 3)
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message
- `--all` - Check all connectivity paths in topology

**Examples:**
```bash
./helpers/check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10
./helpers/check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10 --port 80 --type tcp
./helpers/check_connectivity.sh --all
```

**Reference:** RFC 791 (Internet Protocol), RFC 792 (ICMP)

---

#### [`helpers/cleanup_captures.sh`](helpers/cleanup_captures.sh)
Cleans up old capture files and temporary data from ECMP testing.

**Features:**
- Removes capture files based on age, size, or pattern
- Dry-run mode to preview changes
- Configurable cleanup criteria
- Statistics on space freed

**Usage:**
```bash
./helpers/cleanup_captures.sh [options]
```

**Options:**
- `-d, --directory DIR` - Directory to clean (default: ../captures)
- `-a, --age DAYS` - Remove files older than N days (default: 7)
- `-s, --size MB` - Remove files larger than N MB
- `-p, --pattern PATTERN` - Remove files matching pattern (default: *.pcap)
- `-n, --dry-run` - Show what would be removed without actually removing
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

**Examples:**
```bash
./helpers/cleanup_captures.sh
./helpers/cleanup_captures.sh --age 30
./helpers/cleanup_captures.sh --pattern "test_*.pcap" --dry-run
./helpers/cleanup_captures.sh --size 100
```

---

## Configuration

### Traffic Configuration File

The main configuration file is [`../configs/traffic/traffic_config.yaml`](../configs/traffic/traffic_config.yaml).

**Key Sections:**

1. **Test Configuration**
   - Test name and description
   - Duration and iterations
   - Output directory

2. **Traffic Generation**
   - Destination IP, port, and protocol
   - Source hosts configuration
   - Tool parameters (hping3, ping)

3. **Traffic Capture**
   - Capture duration and buffer size
   - BPF filter for packet capture
   - Capture paths and interfaces

4. **Expected Distribution**
   - Number of ECMP paths
   - Expected percentage per path
   - Tolerance and statistical thresholds

5. **Test Scenarios**
   - Predefined test scenarios
   - Source hosts and packet counts
   - Duration and parameters

---

## Usage Workflow

### 1. Deploy Topology

First, deploy the ECMP topology using Containerlab:

```bash
cd ..
./scripts/deploy_topology.sh
```

### 2. Verify Connectivity

Check that all containers are running and connectivity is working:

```bash
./scripts/helpers/wait_for_container.sh clab-ecmp-test-*
./scripts/helpers/check_connectivity.sh --all
```

### 3. Run Test

Execute a complete test:

```bash
./scripts/run_test.sh
```

Or run with specific parameters:

```bash
./scripts/run_test.sh --scenario high_volume --duration 120
```

### 4. Analyze Results

Results are stored in the `results/` directory with the following structure:

```
results/
└── ecmp-test-YYYYMMDD-HHMMSS-scenario/
    ├── captures/
    │   ├── ecmp-test_path1_YYYYMMDD_HHMMSS.pcap
    │   ├── ecmp-test_path2_YYYYMMDD_HHMMSS.pcap
    │   ├── ecmp-test_path3_YYYYMMDD_HHMMSS.pcap
    │   └── ecmp-test_path4_YYYYMMDD_HHMMSS.pcap
    ├── logs/
    │   ├── test_execution.log
    │   ├── traffic_generation.log
    │   └── capture_traffic.log
    └── metadata/
        ├── test_info.json
        └── capture_summary.txt
```

### 5. Cleanup

Clean up old capture files:

```bash
./scripts/helpers/cleanup_captures.sh --age 30
```

---

## CI/CD Integration

All scripts support CI/CD environments:

1. **Non-interactive mode**: Scripts run without user prompts
2. **Exit codes**: Proper exit codes for success/failure
3. **Logging**: Comprehensive logging to files
4. **Error handling**: Graceful error handling and cleanup

**Example CI/CD workflow:**

```yaml
- name: Deploy ECMP topology
  run: ./scripts/deploy_topology.sh

- name: Wait for containers
  run: ./scripts/helpers/wait_for_container.sh clab-ecmp-test-*

- name: Check connectivity
  run: ./scripts/helpers/check_connectivity.sh --all

- name: Run ECMP test
  run: ./scripts/run_test.sh --scenario basic_distribution

- name: Analyze results
  run: ./scripts/analyze_results.sh
```

---

## Best Practices

1. **Always verify connectivity** before running tests
2. **Use appropriate packet counts** for statistical significance
3. **Monitor disk space** for capture files
4. **Clean up old captures** regularly
5. **Review logs** for troubleshooting
6. **Use verbose mode** for debugging

---

## Troubleshooting

### Common Issues

**Issue: Containers not ready**
```bash
# Wait longer for containers
./scripts/helpers/wait_for_container.sh --timeout 120 clab-ecmp-test-*
```

**Issue: Connectivity failures**
```bash
# Check all connectivity paths
./scripts/helpers/check_connectivity.sh --all --verbose
```

**Issue: No packets captured**
```bash
# Verify tcpdump is installed in containers
docker exec clab-ecmp-test-r2 which tcpdump
```

**Issue: Disk space full**
```bash
# Clean up old captures
./scripts/helpers/cleanup_captures.sh --age 1
```

---

## References

- **Architecture**: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- **Topology**: [`../topology/clab-ecmp-test.yml`](../topology/clab-ecmp-test.yml)
- **Configuration**: [`../configs/traffic/traffic_config.yaml`](../configs/traffic/traffic_config.yaml)
- **hping3**: https://linux.die.net/man/8/hping3
- **tcpdump**: https://www.tcpdump.org/manpages/tcpdump.1.html
- **RFC 2544**: Benchmarking Methodology
- **RFC 791**: Internet Protocol
- **RFC 792**: Internet Control Message Protocol

---

## License

See [`../LICENSE`](../LICENSE) for license information.
