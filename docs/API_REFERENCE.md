# ECMP Testing - API/Script Reference

## Table of Contents
1. [Overview](#overview)
2. [Main Scripts](#main-scripts)
3. [Helper Scripts](#helper-scripts)
4. [Configuration Files](#configuration-files)
5. [Environment Variables](#environment-variables)
6. [Return Codes](#return-codes)
7. [Error Handling](#error-handling)
8. [Examples](#examples)

---

## Overview

This document provides a complete reference for all scripts in the ECMP testing framework, including command-line options, parameters, environment variables, configuration file formats, return codes, and error handling.

**Script Categories:**
- **Main Scripts**: Core functionality for deployment, configuration, testing, and reporting
- **Helper Scripts**: Utility functions for common tasks
- **Configuration Files**: YAML and text configuration files

---

## Main Scripts

### deploy_topology.sh

**Purpose:** Deploy the ECMP network topology using Containerlab

**Location:** `scripts/deploy_topology.sh`

**Usage:**
```bash
./scripts/deploy_topology.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-v` | `--verbose` | Enable verbose output | false |
| `-s` | `--skip-checks` | Skip pre-deployment checks | false |
| `-c` | `--cleanup` | Cleanup existing topology | false |
| `-n` | `--no-verify` | Skip deployment verification | false |

**Examples:**

```bash
# Deploy topology
./scripts/deploy_topology.sh

# Deploy with verbose output
./scripts/deploy_topology.sh --verbose

# Cleanup existing topology
./scripts/deploy_topology.sh --cleanup

# Deploy without verification
./scripts/deploy_topology.sh --no-verify
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Prerequisites not met |
| 3 | Deployment failed |
| 4 | Verification failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_TOPOLOGY_FILE` | Path to topology file | `topology/clab-ecmp-test.yml` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- Containerlab
- Bash 4.0+

**Reference:** https://containerlab.dev/cmd/deploy/

---

### configure_ecmp.sh

**Purpose:** Configure ECMP routing on all routers

**Location:** `scripts/configure_ecmp.sh`

**Usage:**
```bash
./scripts/configure_ecmp.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-v` | `--verbose` | Enable verbose output | false |
| `-s` | `--skip-verify` | Skip configuration verification | false |
| `-r` | `--router N` | Configure only router N (1-6) | all |
| `-S` | `--status` | Show ECMP status only | false |

**Examples:**

```bash
# Configure ECMP on all routers
./scripts/configure_ecmp.sh

# Configure with verbose output
./scripts/configure_ecmp.sh --verbose

# Configure only router 1
./scripts/configure_ecmp.sh --router 1

# Show ECMP status only
./scripts/configure_ecmp.sh --status
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Container not found |
| 3 | FRR not available |
| 4 | Configuration failed |
| 5 | Verification failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_HASH_POLICY` | ECMP hash policy (0, 1, 2) | 1 |
| `ECMP_ROUTE_METRIC` | Route metric | 100 |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- FRRouting
- Bash 4.0+

**Reference:** https://docs.frrouting.org/en/latest/ecmp.html

---

### run_test.sh

**Purpose:** Orchestrate complete test execution

**Location:** `scripts/run_test.sh`

**Usage:**
```bash
./scripts/run_test.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-c` | `--config FILE` | Path to traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `-s` | `--scenario NAME` | Test scenario to execute | `basic_distribution` |
| `-d` | `--duration SECONDS` | Test duration in seconds | 60 |
| `-n` | `--count NUM` | Number of packets per source | 1000 |
| `-o` | `--output DIR` | Output directory for test results | `results` |
| `--no-cleanup` | Skip cleanup after test completion | false |
| `--preserve-captures` | Preserve capture files | false |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Run test with default configuration
./scripts/run_test.sh

# Run with specific scenario
./scripts/run_test.sh --scenario high_volume

# Run with custom duration and packet count
./scripts/run_test.sh --duration 120 --count 5000

# Run with custom output directory
./scripts/run_test.sh --output /tmp/ecmp-results

# Run without cleanup
./scripts/run_test.sh --no-cleanup
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration file not found |
| 3 | Capture failed |
| 4 | Traffic generation failed |
| 5 | Analysis failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CONFIG_FILE` | Traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `ECMP_OUTPUT_DIR` | Output directory | `results` |
| `ECMP_CAPTURE_DIR` | Capture directory | `results/captures` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- tcpdump
- hping3
- Bash 4.0+

---

### generate_traffic.sh

**Purpose:** Generate test traffic from source hosts

**Location:** `scripts/generate_traffic.sh`

**Usage:**
```bash
./scripts/generate_traffic.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-c` | `--config FILE` | Path to traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `-s` | `--scenario NAME` | Test scenario to execute | `basic_distribution` |
| `-d` | `--duration SECONDS` | Test duration in seconds | 60 |
| `-n` | `--count NUM` | Number of packets per source | 1000 |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Generate traffic with default configuration
./scripts/generate_traffic.sh

# Generate with specific scenario
./scripts/generate_traffic.sh --scenario high_volume

# Generate with custom duration and packet count
./scripts/generate_traffic.sh --duration 120 --count 5000
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration file not found |
| 3 | Container not found |
| 4 | Traffic generation failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CONFIG_FILE` | Traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `ECMP_DESTINATION_IP` | Destination IP address | `192.168.100.10` |
| `ECMP_SOURCE_HOSTS` | Source host names | `h1 h2 h3 h4` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- hping3
- Bash 4.0+

**Reference:** https://linux.die.net/man/8/hping3

---

### capture_traffic.sh

**Purpose:** Capture traffic on ECMP paths using tcpdump

**Location:** `scripts/capture_traffic.sh`

**Usage:**
```bash
./scripts/capture_traffic.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-c` | `--config FILE` | Path to traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `-d` | `--duration SECONDS` | Capture duration in seconds | 60 |
| `-o` | `--output DIR` | Output directory for capture files | `results/captures` |
| `-f` | `--filter FILTER` | BPF filter for packet capture | `icmp or tcp or udp` |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Capture traffic with default configuration
./scripts/capture_traffic.sh

# Capture with custom duration
./scripts/capture_traffic.sh --duration 120

# Capture with custom output directory
./scripts/capture_traffic.sh --output /tmp/captures

# Capture with custom filter
./scripts/capture_traffic.sh --filter "icmp"
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration file not found |
| 3 | Container not found |
| 4 | tcpdump not available |
| 5 | Capture failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CONFIG_FILE` | Traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `ECMP_CAPTURE_DIR` | Capture directory | `results/captures` |
| `ECMP_CAPTURE_FILTER` | BPF filter | `icmp or tcp or udp` |
| `ECMP_CAPTURE_ROUTERS` | Routers to capture on | `r2 r3 r4 r5` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- tcpdump
- Bash 4.0+

**Reference:** https://www.tcpdump.org/manpages/tcpdump.1.html

---

### analyze_results.sh

**Purpose:** Analyze captured traffic and calculate distribution metrics

**Location:** `scripts/analyze_results.sh`

**Usage:**
```bash
./scripts/analyze_results.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-i` | `--input DIR` | Input directory with capture files | `results/captures` |
| `-o` | `--output DIR` | Output directory for analysis results | `results/analysis` |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Analyze results with default configuration
./scripts/analyze_results.sh

# Analyze with specific input directory
./scripts/analyze_results.sh --input results/captures/

# Analyze with custom output directory
./scripts/analyze_results.sh --output /tmp/analysis
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Input directory not found |
| 3 | No capture files found |
| 4 | Analysis failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CAPTURE_DIR` | Capture directory | `results/captures` |
| `ECMP_ANALYSIS_DIR` | Analysis directory | `results/analysis` |
| `ECMP_NUM_PATHS` | Number of ECMP paths | 4 |
| `ECMP_CONFIDENCE_LEVEL` | Statistical confidence level | 0.95 |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- tcpdump
- Python 3.8+
- Bash 4.0+

---

### generate_allure_report.sh

**Purpose:** Generate Allure test reports

**Location:** `scripts/generate_allure_report.sh`

**Usage:**
```bash
./scripts/generate_allure_report.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-i` | `--input DIR` | Input directory with analysis results | `results/analysis` |
| `-o` | `--output DIR` | Output directory for Allure report | `results/allure-results` |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Generate report with default configuration
./scripts/generate_allure_report.sh

# Generate with specific input directory
./scripts/generate_allure_report.sh --input results/analysis/

# Generate with custom output directory
./scripts/generate_allure_report.sh --output /tmp/allure-results
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Input directory not found |
| 3 | Allure not available |
| 4 | Report generation failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_ANALYSIS_DIR` | Analysis directory | `results/analysis` |
| `ALLURE_RESULTS_DIR` | Allure results directory | `results/allure-results` |
| `ALLURE_REPORT_DIR` | Allure report directory | `results/allure-report` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Allure 2.20+
- Python 3.8+
- Bash 4.0+

**Reference:** https://docs.qameta.io/allure/

---

### validate_implementation.sh

**Purpose:** Validate ECMP implementation

**Location:** `scripts/validate_implementation.sh`

**Usage:**
```bash
./scripts/validate_implementation.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Validate implementation
./scripts/validate_implementation.sh

# Validate with verbose output
./scripts/validate_implementation.sh --verbose
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Validation failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_LOG_DIR` | Log directory | `logs` |

**Dependencies:**
- Docker
- FRRouting
- Bash 4.0+

---

## Helper Scripts

### helpers/wait_for_container.sh

**Purpose:** Wait for containers to be ready and running

**Location:** `scripts/helpers/wait_for_container.sh`

**Usage:**
```bash
./scripts/helpers/wait_for_container.sh [options] [container...]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-t` | `--timeout SECONDS` | Maximum time to wait | 60 |
| `-i` | `--interval SECONDS` | Check interval | 1 |
| `-c` | `--check-connectivity` | Verify network connectivity | false |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Wait for specific containers
./scripts/helpers/wait_for_container.sh clab-ecmp-test-h1 clab-ecmp-test-h2

# Wait with custom timeout
./scripts/helpers/wait_for_container.sh --timeout 120 clab-ecmp-test-r1

# Wait with connectivity check
./scripts/helpers/wait_for_container.sh --check-connectivity clab-ecmp-test-*

# Wait for all containers
./scripts/helpers/wait_for_container.sh clab-ecmp-test-*
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Timeout |
| 3 | Container not found |
| 4 | Connectivity check failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `WAIT_TIMEOUT` | Default timeout | 60 |
| `WAIT_INTERVAL` | Default check interval | 1 |

---

### helpers/check_connectivity.sh

**Purpose:** Verify network connectivity between containers

**Location:** `scripts/helpers/check_connectivity.sh`

**Usage:**
```bash
./scripts/helpers/check_connectivity.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-s` | `--source CONTAINER` | Source container name | - |
| `-d` | `--destination IP` | Destination IP address | - |
| `-p` | `--port PORT` | Destination port (for TCP/UDP) | - |
| `-t` | `--type TYPE` | Test type: ping, tcp, udp | ping |
| `-c` | `--count NUM` | Number of packets to send | 3 |
| `-v` | `--verbose` | Enable verbose output | false |
| `--all` | Check all connectivity paths in topology | false |

**Examples:**

```bash
# Check connectivity from h1 to destination
./scripts/helpers/check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10

# Check TCP connectivity
./scripts/helpers/check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10 --port 80 --type tcp

# Check all connectivity paths
./scripts/helpers/check_connectivity.sh --all

# Check with custom packet count
./scripts/helpers/check_connectivity.sh --source clab-ecmp-test-h1 --destination 192.168.100.10 --count 10
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Container not found |
| 3 | Connectivity failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `PING_COUNT` | Default ping count | 3 |
| `PING_TIMEOUT` | Ping timeout (seconds) | 1 |

---

### helpers/cleanup_captures.sh

**Purpose:** Clean up old capture files and temporary data

**Location:** `scripts/helpers/cleanup_captures.sh`

**Usage:**
```bash
./scripts/helpers/cleanup_captures.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-d` | `--directory DIR` | Directory to clean | `results/captures` |
| `-a` | `--age DAYS` | Remove files older than N days | 7 |
| `-s` | `--size MB` | Remove files larger than N MB | - |
| `-p` | `--pattern PATTERN` | Remove files matching pattern | `*.pcap` |
| `-n` | `--dry-run` | Show what would be removed without actually removing | false |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Clean up captures older than 7 days
./scripts/helpers/cleanup_captures.sh

# Clean up captures older than 30 days
./scripts/helpers/cleanup_captures.sh --age 30

# Clean up captures matching pattern
./scripts/helpers/cleanup_captures.sh --pattern "test_*.pcap"

# Dry run to preview changes
./scripts/helpers/cleanup_captures.sh --age 30 --dry-run

# Clean up large files
./scripts/helpers/cleanup_captures.sh --size 100
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Directory not found |
| 3 | No files to remove |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `CLEANUP_AGE` | Default age threshold (days) | 7 |
| `CLEANUP_PATTERN` | Default file pattern | `*.pcap` |

---

### helpers/generate_report.sh

**Purpose:** Generate test reports

**Location:** `scripts/helpers/generate_report.sh`

**Usage:**
```bash
./scripts/helpers/generate_report.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-i` | `--input DIR` | Input directory with analysis results | `results/analysis` |
| `-o` | `--output DIR` | Output directory for report | `results/reports` |
| `-f` | `--format FORMAT` | Report format: html, json, txt | html |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Generate HTML report
./scripts/helpers/generate_report.sh

# Generate JSON report
./scripts/helpers/generate_report.sh --format json

# Generate with custom directories
./scripts/helpers/generate_report.sh --input results/analysis/ --output /tmp/reports
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Input directory not found |
| 3 | Report generation failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_ANALYSIS_DIR` | Analysis directory | `results/analysis` |
| `ECMP_REPORT_DIR` | Report directory | `results/reports` |
| `REPORT_FORMAT` | Report format | `html` |

---

### helpers/statistical_analysis.sh

**Purpose:** Perform statistical analysis on test results

**Location:** `scripts/helpers/statistical_analysis.sh`

**Usage:**
```bash
./scripts/helpers/statistical_analysis.sh [options]
```

**Options:**

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-i` | `--input DIR` | Input directory with analysis results | `results/analysis` |
| `-o` | `--output DIR` | Output directory for statistical results | `results/analysis` |
| `-v` | `--verbose` | Enable verbose output | false |

**Examples:**

```bash
# Perform statistical analysis
./scripts/helpers/statistical_analysis.sh

# Analyze with custom directories
./scripts/helpers/statistical_analysis.sh --input results/analysis/ --output /tmp/analysis
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Input directory not found |
| 3 | Analysis failed |

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_ANALYSIS_DIR` | Analysis directory | `results/analysis` |
| `ECMP_CONFIDENCE_LEVEL` | Statistical confidence level | 0.95 |
| `ECMP_SIGNIFICANCE_LEVEL` | Statistical significance level | 0.05 |

---

## Configuration Files

### traffic_config.yaml

**Purpose:** Traffic configuration for test scenarios

**Location:** `configs/traffic/traffic_config.yaml`

**Format:** YAML

**Structure:**

```yaml
test:
  name: "ECMP Hash Test"
  description: "Test ECMP hash distribution with Source IP only"
  duration: 60
  iterations: 1
  output_dir: "results"

traffic_generation:
  destination:
    ip: "192.168.100.10"
    port: 80
    protocol: "icmp"
  
  sources:
    - name: "h1"
      ip: "10.0.1.10"
      count: 1000
    - name: "h2"
      ip: "10.0.1.11"
      count: 1000
    - name: "h3"
      ip: "10.0.1.12"
      count: 1000
    - name: "h4"
      ip: "10.0.1.13"
      count: 1000
  
  tools:
    hping3:
      enabled: true
      interval: 1000
      mode: "icmp"
    ping:
      enabled: false
      count: 1000

traffic_capture:
  duration: 60
  buffer_size: 4096
  filter: "icmp or tcp or udp"
  
  paths:
    - name: "path1"
      router: "r2"
      interface: "eth1"
    - name: "path2"
      router: "r3"
      interface: "eth1"
    - name: "path3"
      router: "r4"
      interface: "eth1"
    - name: "path4"
      router: "r5"
      interface: "eth1"

expected_distribution:
  num_paths: 4
  expected_percentage: 25.0
  tolerance: 5.0
  statistical_thresholds:
    chi_square_critical: 7.815
    p_value_threshold: 0.05
    entropy_threshold: 1.8

test_scenarios:
  basic_distribution:
    name: "Basic Distribution Test"
    description: "Validate basic ECMP distribution"
    duration: 60
    sources:
      - name: "h1"
        count: 1000
      - name: "h2"
        count: 1000
      - name: "h3"
        count: 1000
      - name: "h4"
        count: 1000
  
  high_volume:
    name: "High Volume Test"
    description: "Test scalability with high volume"
    duration: 300
    sources:
      - name: "h1"
        count: 10000
      - name: "h2"
        count: 10000
      - name: "h3"
        count: 10000
      - name: "h4"
        count: 10000
  
  low_volume:
    name: "Low Volume Test"
    description: "Quick validation with low volume"
    duration: 30
    sources:
      - name: "h1"
        count: 100
      - name: "h2"
        count: 100
      - name: "h3"
        count: 100
      - name: "h4"
        count: 100
```

**Key Sections:**

1. **test**: General test configuration
2. **traffic_generation**: Traffic generation settings
3. **traffic_capture**: Traffic capture settings
4. **expected_distribution**: Expected distribution parameters
5. **test_scenarios**: Predefined test scenarios

---

### allure_config.yaml

**Purpose:** Allure report configuration

**Location:** `configs/allure/allure_config.yaml`

**Format:** YAML

**Structure:**

```yaml
allure:
  results:
    directory: "results/allure-results"
  
  report:
    directory: "results/allure-report"
  
  plugins:
    - name: "custom-logo"
      enabled: true
    - name: "behaviors"
      enabled: true
    - name: "packages"
      enabled: true
    - name: "severity"
      enabled: true
    - name: "history"
      enabled: true
    - name: "trends"
      enabled: true
    - name: "screen-diff"
      enabled: false

  categories:
    - name: "Ignored tests"
      matchedStatuses: ["skipped"]
    - name: "Infrastructure problems"
      matchedStatuses: ["broken", "failed"]
      messageRegex: ".*Connection refused.*"
    - name: "Outdated tests"
      matchedStatuses: ["broken"]
      traceRegex: ".*FileNotFoundError.*"
    - name: "Product defects"
      matchedStatuses: ["failed"]
    - name: "Test defects"
      matchedStatuses: ["broken"]

  labels:
    - name: "severity"
      values: ["blocker", "critical", "normal", "minor", "trivial"]
    - name: "layer"
      values: ["unit", "integration", "system", "acceptance"]
    - name: "host"
      values: ["local", "ci"]
    - name: "thread"
      values: ["main", "worker"]
```

---

## Environment Variables

### Global Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_PROJECT_DIR` | Project root directory | Current directory |
| `ECMP_TOPOLOGY_FILE` | Topology file path | `topology/clab-ecmp-test.yml` |
| `ECMP_CONFIG_FILE` | Traffic configuration file | `configs/traffic/traffic_config.yaml` |
| `ECMP_OUTPUT_DIR` | Output directory | `results` |
| `ECMP_LOG_DIR` | Log directory | `logs` |

### Directory Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CAPTURE_DIR` | Capture directory | `results/captures` |
| `ECMP_ANALYSIS_DIR` | Analysis directory | `results/analysis` |
| `ECMP_REPORT_DIR` | Report directory | `results/reports` |
| `ECMP_ARCHIVE_DIR` | Archive directory | `results/archives` |

### Network Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_DESTINATION_IP` | Destination IP address | `192.168.100.10` |
| `ECMP_DESTINATION_PORT` | Destination port | 80 |
| `ECMP_SOURCE_HOSTS` | Source host names | `h1 h2 h3 h4` |
| `ECMP_NUM_PATHS` | Number of ECMP paths | 4 |

### ECMP Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_HASH_POLICY` | ECMP hash policy (0, 1, 2) | 1 |
| `ECMP_ROUTE_METRIC` | Route metric | 100 |
| `ECMP_OSPF_AREA` | OSPF area ID | `0.0.0.0` |

### Statistical Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ECMP_CONFIDENCE_LEVEL` | Statistical confidence level | 0.95 |
| `ECMP_SIGNIFICANCE_LEVEL` | Statistical significance level | 0.05 |
| `ECMP_ENTROPY_THRESHOLD` | Entropy threshold | 1.8 |

### Allure Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ALLURE_RESULTS_DIR` | Allure results directory | `results/allure-results` |
| `ALLURE_REPORT_DIR` | Allure report directory | `results/allure-report` |

---

## Return Codes

### Standard Return Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | General error | Check logs |
| 2 | Configuration error | Check configuration |
| 3 | Dependency error | Install dependencies |
| 4 | Execution error | Retry or investigate |

### Script-Specific Return Codes

#### deploy_topology.sh

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | General error | Check logs |
| 2 | Prerequisites not met | Install Docker/Containerlab |
| 3 | Deployment failed | Check topology file |
| 4 | Verification failed | Check container status |

#### configure_ecmp.sh

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | General error | Check logs |
| 2 | Container not found | Deploy topology |
| 3 | FRR not available | Install FRR |
| 4 | Configuration failed | Check FRR configuration |
| 5 | Verification failed | Check ECMP routes |

#### run_test.sh

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | General error | Check logs |
| 2 | Configuration file not found | Check config file |
| 3 | Capture failed | Check tcpdump |
| 4 | Traffic generation failed | Check hping3 |
| 5 | Analysis failed | Check analysis script |

---

## Error Handling

### Common Error Messages

#### Error: Container not found

**Message:** `Error: Container 'clab-ecmp-test-r1' not found`

**Cause:** Container not running or not deployed

**Solution:**
```bash
# Check container status
docker ps | grep clab-ecmp-test

# Deploy topology
./scripts/deploy_topology.sh
```

#### Error: FRR not available

**Message:** `Error: vtysh: command not found`

**Cause:** FRRouting not installed in container

**Solution:**
```bash
# Install FRR in container
docker exec clab-ecmp-test-r1 apt-get update
docker exec clab-ecmp-test-r1 apt-get install -y frr

# Restart FRR
docker exec clab-ecmp-test-r1 service frr restart
```

#### Error: tcpdump not available

**Message:** `Error: tcpdump: command not found`

**Cause:** tcpdump not installed in container

**Solution:**
```bash
# Install tcpdump in container
docker exec clab-ecmp-test-r2 apt-get install -y tcpdump
```

#### Error: Configuration file not found

**Message:** `Error: Configuration file 'configs/traffic/traffic_config.yaml' not found`

**Cause:** Configuration file missing

**Solution:**
```bash
# Check file exists
ls -la configs/traffic/traffic_config.yaml

# Create configuration file
cp configs/traffic/traffic_config.yaml.example configs/traffic/traffic_config.yaml
```

### Error Handling Best Practices

1. **Check Logs First**
   ```bash
   # Check relevant log file
   cat logs/deploy_topology.log
   cat logs/configure_ecmp.log
   cat logs/test_execution.log
   ```

2. **Use Verbose Mode**
   ```bash
   # Run with verbose output
   ./scripts/deploy_topology.sh --verbose
   ```

3. **Verify Prerequisites**
   ```bash
   # Check all prerequisites
   docker --version
   clab version
   vtysh --version
   tcpdump --version
   hping3 --version
   allure --version
   ```

4. **Check Container Status**
   ```bash
   # Check all containers
   docker ps | grep clab-ecmp-test
   ```

5. **Verify Configuration**
   ```bash
   # Check ECMP configuration
   ./scripts/configure_ecmp.sh --status
   ```

---

## Examples

### Example 1: Complete Test Workflow

```bash
#!/bin/bash

# Deploy topology
./scripts/deploy_topology.sh

# Wait for containers
./scripts/helpers/wait_for_container.sh clab-ecmp-test-*

# Configure ECMP
./scripts/configure_ecmp.sh

# Verify configuration
./scripts/configure_ecmp.sh --status

# Run test
./scripts/run_test.sh --scenario high_volume

# Analyze results
./scripts/analyze_results.sh

# Generate report
./scripts/generate_allure_report.sh

# View report
allure open results/allure-results

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Example 2: Custom Test Scenario

```bash
#!/bin/bash

# Set custom parameters
export ECMP_DURATION=180
export ECMP_PACKET_COUNT=2500
export ECMP_OUTPUT_DIR=/tmp/ecmp-results

# Deploy and configure
./scripts/deploy_topology.sh && ./scripts/configure_ecmp.sh

# Run custom test
./scripts/run_test.sh --duration $ECMP_DURATION --count $ECMP_PACKET_COUNT --output $ECMP_OUTPUT_DIR

# Analyze and report
./scripts/analyze_results.sh --input $ECMP_OUTPUT_DIR/captures --output $ECMP_OUTPUT_DIR/analysis
./scripts/generate_allure_report.sh --input $ECMP_OUTPUT_DIR/analysis --output $ECMP_OUTPUT_DIR/allure-results

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Example 3: CI/CD Integration

```yaml
name: ECMP Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        curl -fsSL https://get.docker.com | sh
        curl -sL https://containerlab.dev/setup.sh | bash
        sudo apt-get update
        sudo apt-get install -y frr tcpdump hping3
    
    - name: Deploy topology
      run: ./scripts/deploy_topology.sh
    
    - name: Configure ECMP
      run: ./scripts/configure_ecmp.sh
    
    - name: Run test
      run: ./scripts/run_test.sh --scenario basic_distribution
    
    - name: Analyze results
      run: ./scripts/analyze_results.sh
    
    - name: Generate report
      run: ./scripts/generate_allure_report.sh
    
    - name: Upload results
      uses: actions/upload-artifact@v3
      with:
        name: ecmp-results
        path: results/
    
    - name: Cleanup
      if: always()
      run: clab destroy -t topology/clab-ecmp-test.yml
```

### Example 4: Manual Testing

```bash
#!/bin/bash

# Deploy topology
./scripts/deploy_topology.sh

# Configure ECMP
./scripts/configure_ecmp.sh

# Start captures manually
docker exec -d clab-ecmp-test-r2 tcpdump -i eth1 -w /tmp/path1.pcap
docker exec -d clab-ecmp-test-r3 tcpdump -i eth1 -w /tmp/path2.pcap
docker exec -d clab-ecmp-test-r4 tcpdump -i eth1 -w /tmp/path3.pcap
docker exec -d clab-ecmp-test-r5 tcpdump -i eth1 -w /tmp/path4.pcap

# Generate traffic manually
docker exec clab-ecmp-test-h1 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h2 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h3 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h4 hping3 -c 1000 -i u1000 192.168.100.10

# Stop captures
docker exec clab-ecmp-test-r2 pkill tcpdump
docker exec clab-ecmp-test-r3 pkill tcpdump
docker exec clab-ecmp-test-r4 pkill tcpdump
docker exec clab-ecmp-test-r5 pkill tcpdump

# Copy capture files
docker cp clab-ecmp-test-r2:/tmp/path1.pcap results/captures/
docker cp clab-ecmp-test-r3:/tmp/path2.pcap results/captures/
docker cp clab-ecmp-test-r4:/tmp/path3.pcap results/captures/
docker cp clab-ecmp-test-r5:/tmp/path4.pcap results/captures/

# Analyze results
./scripts/analyze_results.sh

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

---

**Document Version:** 1.0  
**Last Updated:** 2024-03-05  
**Maintainer:** ECMP Testing Team
