# ECMP Hash Testing - Implementation

![CI/CD](https://github.com/storenth/ecmp/workflows/ECMP%20Testing%20CI/CD/badge.svg)
![Scheduled Tests](https://github.com/storenth/ecmp/workflows/Scheduled%20ECMP%20Testing/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)
![ISO 29119-3](https://img.shields.io/badge/ISO%2029119--3-Compliant-green.svg)

This project implements a 4-path ECMP (Equal-Cost Multi-Path) topology for testing hash algorithms based on Source IP address only.

## Quick Start

Get started with ECMP testing in just one command:

```bash
# Run complete test with Quick Start mode
make quick-test
```

That's it! The Quick Start mode handles everything automatically:
- ✅ Deploys the topology
- ✅ Configures ECMP
- ✅ Runs traffic tests
- ✅ Analyzes results
- ✅ Generates reports

### Three Configuration Modes

The framework provides three configuration modes to match your needs:

| Mode | Configuration | Use Case | Complexity |
|------|-------------|-----------|------------|
| **Quick Start** | `config/quick_start.yaml` | First-time users, quick validation, learning | ⭐ Simple |
| **Standard** | `config/standard.yaml` | Most use cases, balanced features | ⭐⭐ Moderate |
| **Advanced** | `config/advanced.yaml` | Production testing, compliance, custom scenarios | ⭐⭐⭐ Complex |

#### Quick Start Mode (Recommended for Beginners)

**Perfect for:**
- First-time users
- Quick validation tests
- Learning ECMP concepts
- Getting familiar with the framework

**Features:**
- One-command execution: `make quick-test`
- Minimal configuration (only essential parameters)
- Sensible defaults for all values
- Clear, easy-to-understand output

**Commands:**
```bash
make quick-test      # Run complete test
make quick-deploy    # Deploy topology only
make quick-report    # Generate reports only
make quick-help      # Show Quick Start help
```

**Configuration:** [`config/quick_start.yaml`](config/quick_start.yaml) (~2-3KB)

#### Standard Mode (Balanced)

**Perfect for:**
- Typical testing scenarios
- Development and testing
- Most production use cases
- Users familiar with ECMP testing

**Features:**
- Moderate complexity with most common features
- Good balance of simplicity and functionality
- Multiple test scenarios
- Comprehensive reporting

**Commands:**
```bash
make test CONFIG=config/standard.yaml
```

**Configuration:** [`config/standard.yaml`](config/standard.yaml) (~8-10KB)

#### Advanced Mode (Full-Featured)

**Perfect for:**
- Production testing
- Compliance requirements
- Custom test scenarios
- Power users

**Features:**
- All features enabled
- Advanced statistical analysis
- Multiple report formats
- Extensive customization options

**Commands:**
```bash
make test CONFIG=config/advanced.yaml
```

**Configuration:** [`config/advanced.yaml`](config/advanced.yaml) (~25KB)

### Progressive Disclosure

Start simple and progress to advanced features as needed:

1. **Beginner**: Use Quick Start mode to learn the basics
2. **Intermediate**: Switch to Standard mode for more features
3. **Advanced**: Use Advanced mode for production and compliance

### Quick Start Examples

#### Example 1: First Test Run

```bash
# Run your first test
make quick-test

# View the results
make open-report
```

#### Example 2: Deploy and Test Separately

```bash
# Deploy topology
make quick-deploy

# Run tests later
make quick-test
```

#### Example 3: Generate Reports Only

```bash
# If you already have test results
make quick-report
```

#### Example 4: Switch to Standard Mode

```bash
# Use Standard configuration
make test CONFIG=config/standard.yaml
```

#### Example 5: Use Advanced Features

```bash
# Use Advanced configuration for production testing
make test CONFIG=config/advanced.yaml
```

### Getting Help

```bash
# Show Quick Start help
make quick-help

# Show all available commands
make help
```

### Documentation

- **Quick Start Guide**: [`docs/QUICK_START_GUIDE.md`](docs/QUICK_START_GUIDE.md) - Detailed beginner guide
- **QWEN Comparison**: [`docs/QWEN_COMPARISON.md`](docs/QWEN_COMPARISON.md) - Comparison with QWEN's approach
- **Full Documentation**: Continue reading this README for complete documentation

## Overview

The implementation provides a complete Containerlab topology with FRRouting configuration for ECMP testing. It includes automated deployment scripts, configuration templates, and comprehensive documentation.

## Architecture

Based on [`ARCHITECTURE.md`](ARCHITECTURE.md), the topology consists of:

- **Source Network**: 4 hosts (h1-h4) with IPs 10.0.1.10-13/24
- **Edge Router (R1)**: Implements ECMP with 4 equal-cost paths
- **Core Routers (R2-R5)**: 4 routers providing equal-cost paths
- **Destination Router (R6)**: Connects to all core routers
- **Destination Host (d1)**: IP 192.168.100.10/24

## Project Structure

```
ecmp/
├── Makefile                        # Standardized operations and automation
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Docker image for testing
├── .yamllint                       # YAML linting configuration
├── topology/
│   ├── clab-ecmp-test.yml          # Containerlab topology definition (4-path)
│   ├── clab-ecmp-2paths.yml        # 2-path topology variant
│   ├── clab-ecmp-3paths.yml        # 3-path topology variant
│   ├── clab-ecmp-4paths.yml        # 4-path topology variant
│   ├── topology.n-paths.yaml.j2    # Jinja2 template for N-path topologies
│   ├── frr/                        # FRRouting configuration templates
│   │   ├── ecmp-router.conf.j2     # Jinja2 template for ECMP router
│   │   ├── nexthop.conf.j2         # Jinja2 template for nexthop config
│   │   └── sysctl.d/               # Kernel parameter configurations
│   └── README.md                   # Topology documentation
├── scripts/
│   ├── deploy_topology.sh          # Topology deployment script
│   ├── configure_ecmp.sh           # ECMP configuration script
│   ├── run_test.sh                 # Test execution script
│   ├── generate_traffic.sh         # Traffic generation script
│   ├── capture_traffic.sh          # Traffic capture script
│   ├── analyze_results.sh          # Results analysis script
│   ├── generate_allure_report.sh   # Allure report generation
│   ├── validate_implementation.sh  # Implementation validation
│   ├── render_topology.py          # Jinja2 topology renderer
│   ├── analyzer.py                 # Statistical analysis tool
│   ├── traffic_gen.py              # Python traffic generator
│   ├── deploy.py                   # Python deployment tool
│   ├── report_gen.py               # Report generation tool
│   ├── utils.py                    # Utility functions
│   ├── README.md                   # Scripts documentation
│   └── helpers/                    # Helper scripts
│       ├── check_connectivity.sh
│       ├── cleanup_captures.sh
│       ├── generate_report.sh
│       ├── statistical_analysis.sh
│       └── wait_for_container.sh
├── configs/
│   ├── frr/                        # FRRouting configurations
│   │   ├── r1/                     # Edge router (ECMP)
│   │   ├── r2/                     # Core router 1
│   │   ├── r3/                     # Core router 2
│   │   ├── r4/                     # Core router 3
│   │   ├── r5/                     # Core router 4
│   │   └── r6/                     # Destination router
│   ├── hosts/                      # Host configurations
│   │   ├── h1.sh, h2.sh, h3.sh, h4.sh  # Source hosts
│   │   └── d1.sh                   # Destination host
│   ├── traffic/                    # Traffic configuration
│   │   └── traffic_config.yaml     # Traffic generation config
│   └── allure/                      # Allure reporting config
│       └── allure_config.yaml      # Allure configuration
├── config/
│   └── test_config.yaml            # Master test configuration
├── .github/
│   ├── workflows/                  # GitHub Actions workflows
│   │   ├── test.yml                # Main testing workflow
│   │   ├── report.yml              # Report generation workflow
│   │   └── scheduled.yml           # Scheduled testing workflow
│   ├── dependabot.yml              # Dependency updates
│   ├── ISSUE_TEMPLATE/             # Issue templates
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md    # PR template
├── docs/
│   ├── API_REFERENCE.md            # API documentation
│   ├── CI_CD.md                    # CI/CD documentation
│   ├── LAUNCH_INSTRUCTION.md       # Launch instructions
│   ├── QUICK_START.md              # Quick start guide
│   ├── TEST_PLAN.md                # Test plan
│   ├── TEST_REPORT_TEMPLATE.md     # Test report template
│   ├── VERIFICATION_INSTRUCTION.md  # Verification instructions
│   └── iso29119-3/                 # ISO 29119-3 compliance docs
│       ├── README.md               # ISO 29119-3 overview
│       ├── test_plan.md            # ISO test plan
│       ├── test_design_spec.md     # Test design specification
│       └── test_report_template.md # Test report template
├── results/
│   ├── allure-results/             # Allure test results
│   ├── analysis/                   # Analysis results
│   ├── archives/                   # Archived results
│   ├── captures/                   # Traffic captures
│   └── reports/                    # Generated reports
├── logs/                           # Log files (created at runtime)
├── ARCHITECTURE.md                 # Architecture design document
└── README.md                       # This file
```

## Quick Start

### Prerequisites

- Docker (required for Containerlab)
- Containerlab (install from https://containerlab.dev/install/)
- Bash shell
- Python 3.9+ (for Python-based tools)
- Make (optional, for Makefile automation)

### Installation

1. **Clone the repository:**
    ```bash
    git clone https://github.com/storenth/ecmp.git
    cd ecmp
    ```

2. **Install Python dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

### Quick Start Options

#### Option 1: Makefile-Based Quick Start (Recommended)

The Makefile provides a standardized interface for all operations:

```bash
# Deploy and configure the 4-path topology
make deploy

# Run a complete test with traffic generation
make test

# Generate and view reports
make report

# Clean up everything
make clean
```

#### Option 2: Python-Based Quick Start

Use Python scripts for more flexibility:

```bash
# Deploy topology using Python
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml

# Generate traffic
python scripts/traffic_gen.py --config config/test_config.yaml

# Analyze results
python scripts/analyzer.py --results results/captures/
```

#### Option 3: Bash Script Quick Start

Traditional bash script approach:

```bash
# Deploy the topology
./scripts/deploy_topology.sh

# Configure ECMP
./scripts/configure_ecmp.sh

# Verify ECMP configuration
./scripts/configure_ecmp.sh -S
```

### Dynamic Topology Generation

Generate topologies with different path counts using Jinja2 templates:

```bash
# Generate 2-path topology
make topology PATHS=2

# Generate 3-path topology
make topology PATHS=3

# Generate 4-path topology
make topology PATHS=4

# Or use the Python script directly
python scripts/render_topology.py --paths 3 --output topology/clab-ecmp-3paths.yml
```

### Cleanup

To destroy the topology:

```bash
# Using Makefile
make destroy

# Or using Containerlab directly
clab destroy -t topology/clab-ecmp-test.yml
```

## New Features

This project has been significantly enhanced with the following new features:

### Makefile Automation
- **Standardized Operations**: Unified interface for deployment, testing, and cleanup
- **Target-Based Workflow**: Easy-to-use targets for common operations
- **Configuration Management**: Centralized configuration through Makefile variables
- **Error Handling**: Robust error handling and validation
- **Cross-Platform Support**: Works on Linux, macOS, and Windows (with WSL)

### Dynamic Topology Generation
- **Jinja2 Templates**: Template-based topology generation for flexibility
- **Variable Path Counts**: Generate topologies with 2, 3, 4, or more paths
- **Automatic Configuration**: FRR configs generated dynamically based on path count
- **IP Addressing Scheme**: Consistent IP addressing across all topologies
- **Template Reusability**: Single template for multiple topology variants

### Master Configuration File
- **Centralized Configuration**: [`config/test_config.yaml`](config/test_config.yaml) as single source of truth
- **Environment-Specific Settings**: Support for different test environments
- **Parameterized Testing**: Easy configuration of test parameters
- **Validation**: Built-in configuration validation
- **Documentation**: Inline documentation for all configuration options

### Python-Based Analysis Tools
- **Statistical Analysis**: [`scripts/analyzer.py`](scripts/analyzer.py) for comprehensive statistical analysis
- **Traffic Generation**: [`scripts/traffic_gen.py`](scripts/traffic_gen.py) for flexible traffic generation
- **Deployment Automation**: [`scripts/deploy.py`](scripts/deploy.py) for Python-based deployment
- **Report Generation**: [`scripts/report_gen.py`](scripts/report_gen.py) for multi-format reports
- **Utility Functions**: [`scripts/utils.py`](scripts/utils.py) for common operations

### GitHub Actions CI/CD
- **Automated Testing**: Continuous integration with comprehensive test suites
- **Multiple Workflows**: Separate workflows for testing, reporting, and scheduled runs
- **Matrix Strategy**: Test multiple configurations in parallel
- **Artifact Management**: Automatic storage of test results and reports
- **Dependency Updates**: Dependabot integration for dependency management

### ISO 29119-3 Compliance
- **Standardized Documentation**: Complete ISO 29119-3 compliant documentation
- **Test Planning**: Structured test plans following ISO standards
- **Test Design**: Detailed test design specifications
- **Test Reporting**: Standardized test report templates
- **Process Improvement**: Continuous improvement based on ISO guidelines

### Enhanced Scripting
- **Bash Scripts**: Robust bash scripts with comprehensive error handling
- **Python Scripts**: Modern Python scripts with type hints and documentation
- **Helper Scripts**: Modular helper scripts for common operations
- **Logging**: Comprehensive logging across all scripts
- **Validation**: Input validation and error checking

### Reporting and Visualization
- **Allure Reports**: Interactive HTML reports with detailed test results
- **ISO Reports**: ISO 29119-3 compliant test reports
- **JSON Reports**: Machine-readable JSON reports for automation
- **Statistical Analysis**: Detailed statistical analysis with visualizations
- **Trend Analysis**: Historical trend analysis for test results

## Using the Makefile

The Makefile provides a standardized interface for all project operations. It simplifies common tasks and ensures consistency across different environments.

### Overview of Makefile Targets

```bash
# Show all available targets
make help

# Deployment targets
make deploy              # Deploy and configure the topology
make destroy             # Destroy the topology
make redeploy            # Redeploy the topology

# Testing targets
make test                # Run complete test suite
make test-quick          # Run quick tests
make test-full           # Run full test suite with all configurations

# Topology targets
make topology            # Generate topology from Jinja2 template
make topology-2paths     # Generate 2-path topology
make topology-3paths     # Generate 3-path topology
make topology-4paths     # Generate 4-path topology

# Traffic targets
make traffic             # Generate test traffic
make traffic-capture     # Capture traffic on ECMP paths
make traffic-analyze     # Analyze captured traffic

# Analysis targets
make analyze             # Analyze test results
make stats               # Generate statistical analysis
make validate            # Validate implementation

# Reporting targets
make report              # Generate all reports
make report-allure       # Generate Allure report
make report-iso          # Generate ISO 29119-3 report
make report-json         # Generate JSON report

# Utility targets
make clean               # Clean up temporary files
make clean-all           # Clean up everything including results
make install             # Install dependencies
make lint                # Run linting tools
make format              # Format code
```

### Common Usage Examples

#### Basic Deployment and Testing

```bash
# Deploy the topology
make deploy

# Run tests
make test

# Generate reports
make report

# Clean up
make clean
```

#### Testing Different Topologies

```bash
# Test 2-path topology
make topology PATHS=2
make deploy TOPOLOGY=topology/clab-ecmp-2paths.yml
make test

# Test 3-path topology
make topology PATHS=3
make deploy TOPOLOGY=topology/clab-ecmp-3paths.yml
make test

# Test 4-path topology
make topology PATHS=4
make deploy TOPOLOGY=topology/clab-ecmp-4paths.yml
make test
```

#### Traffic Analysis

```bash
# Generate traffic
make traffic

# Capture traffic
make traffic-capture

# Analyze results
make traffic-analyze

# Generate statistical analysis
make stats
```

### Bash vs Python Script Workflows

The project supports both Bash and Python scripts for different use cases:

**Bash Scripts:**
- Best for: Simple operations, CI/CD pipelines, quick tasks
- Examples: [`scripts/deploy_topology.sh`](scripts/deploy_topology.sh), [`scripts/configure_ecmp.sh`](scripts/configure_ecmp.sh)
- Advantages: Fast, lightweight, no dependencies
- Use when: You need quick, simple operations

**Python Scripts:**
- Best for: Complex operations, data analysis, flexible configuration
- Examples: [`scripts/analyzer.py`](scripts/analyzer.py), [`scripts/traffic_gen.py`](scripts/traffic_gen.py)
- Advantages: Powerful, extensible, rich libraries
- Use when: You need complex logic or data processing

**Makefile Integration:**
- The Makefile provides a unified interface to both Bash and Python scripts
- Choose the appropriate tool based on your needs
- Both approaches are fully supported and documented

### Configuration Options

The Makefile supports various configuration options through variables:

```bash
# Topology configuration
TOPOLOGY=topology/clab-ecmp-4paths.yml    # Topology file to use
PATHS=4                                   # Number of ECMP paths

# Test configuration
CONFIG=config/test_config.yaml            # Test configuration file
TEST_TYPE=full                            # Test type (quick, full, custom)

# Reporting configuration
REPORT_FORMAT=allure                       # Report format (allure, iso, json)
REPORT_DIR=results/reports                 # Report output directory

# Verbosity
VERBOSE=1                                  # Enable verbose output
```

## Dynamic Topology Generation

The project uses Jinja2 templates to dynamically generate network topologies with different numbers of ECMP paths. This approach provides flexibility and reduces configuration duplication.

### Overview of Jinja2 Templates

The topology generation system uses two main Jinja2 templates:

1. **[`topology/topology.n-paths.yaml.j2`](topology/topology.n-paths.yaml.j2)**: Main topology template
   - Generates Containerlab topology definitions
   - Creates nodes, links, and configurations
   - Supports variable path counts

2. **[`topology/frr/ecmp-router.conf.j2`](topology/frr/ecmp-router.conf.j2)**: FRR configuration template
   - Generates FRRouting configurations
   - Creates ECMP routes based on path count
   - Configures OSPF and static routes

3. **[`topology/frr/nexthop.conf.j2`](topology/frr/nexthop.conf.j2)**: Nexthop configuration template
   - Generates nexthop configurations
   - Creates interface-specific settings
   - Configures routing parameters

### How to Render Topologies with Different Path Counts

#### Using the Makefile

```bash
# Generate 2-path topology
make topology PATHS=2

# Generate 3-path topology
make topology PATHS=3

# Generate 4-path topology
make topology PATHS=4

# Generate custom path count
make topology PATHS=5
```

#### Using Python Script

```bash
# Generate topology with specific path count
python scripts/render_topology.py --paths 3 --output topology/clab-ecmp-3paths.yml

# Generate topology with custom output
python scripts/render_topology.py --paths 2 --output my-topology.yml

# Generate topology with verbose output
python scripts/render_topology.py --paths 4 --verbose
```

### Examples

#### 2-Path Topology

```bash
# Generate 2-path topology
make topology PATHS=2

# Deploy 2-path topology
make deploy TOPOLOGY=topology/clab-ecmp-2paths.yml

# Run tests on 2-path topology
make test
```

**Characteristics:**
- 2 source hosts (h1, h2)
- 1 edge router (R1) with 2 ECMP paths
- 2 core routers (R2, R3)
- 1 destination router (R4)
- 1 destination host (d1)

#### 3-Path Topology

```bash
# Generate 3-path topology
make topology PATHS=3

# Deploy 3-path topology
make deploy TOPOLOGY=topology/clab-ecmp-3paths.yml

# Run tests on 3-path topology
make test
```

**Characteristics:**
- 3 source hosts (h1, h2, h3)
- 1 edge router (R1) with 3 ECMP paths
- 3 core routers (R2, R3, R4)
- 1 destination router (R5)
- 1 destination host (d1)

#### 4-Path Topology

```bash
# Generate 4-path topology
make topology PATHS=4

# Deploy 4-path topology
make deploy TOPOLOGY=topology/clab-ecmp-4paths.yml

# Run tests on 4-path topology
make test
```

**Characteristics:**
- 4 source hosts (h1, h2, h3, h4)
- 1 edge router (R1) with 4 ECMP paths
- 4 core routers (R2, R3, R4, R5)
- 1 destination router (R6)
- 1 destination host (d1)

### IP Addressing Scheme

The dynamic topology generation uses a consistent IP addressing scheme:

| Network | Purpose | IP Range | Gateway |
|---------|---------|----------|---------|
| 10.0.1.0/24 | Source Network | 10.0.1.0-10.0.1.255 | 10.0.1.1 |
| 10.0.2.0/24 | ECMP Path 1 | 10.0.2.0-10.0.2.255 | 10.0.2.1 |
| 10.0.3.0/24 | ECMP Path 2 | 10.0.3.0-10.0.3.255 | 10.0.3.1 |
| 10.0.4.0/24 | ECMP Path 3 | 10.0.4.0-10.0.4.255 | 10.0.4.1 |
| 10.0.5.0/24 | ECMP Path 4 | 10.0.5.0-10.0.5.255 | 10.0.5.1 |
| 10.0.6.0/24 | Core-Dest Link 1 | 10.0.6.0-10.0.6.255 | - |
| 10.0.7.0/24 | Core-Dest Link 2 | 10.0.7.0-10.0.7.255 | - |
| 10.0.8.0/24 | Core-Dest Link 3 | 10.0.8.0-10.0.8.255 | - |
| 10.0.9.0/24 | Core-Dest Link 4 | 10.0.9.0-10.0.9.255 | - |
| 192.168.100.0/24 | Destination Network | 192.168.100.0-192.168.100.255 | 192.168.100.1 |

The IP addressing scheme automatically scales based on the number of paths:
- Source hosts: 10.0.1.10-10.0.1.(10+N-1) where N is the number of paths
- ECMP paths: 10.0.(2+N-1).0/24 for each path
- Core-Dest links: 10.0.(6+N-1).0/24 for each link

## Configuration Management

The project uses a centralized configuration system to manage test parameters, topology settings, and environment-specific configurations.

### Overview of config/test_config.yaml

The [`config/test_config.yaml`](config/test_config.yaml) file serves as the master configuration file for the entire project. It contains all configurable parameters in a single, well-documented location.

**Key Benefits:**
- Single source of truth for all configuration
- Easy to modify without touching code
- Version-controlled configuration changes
- Validation and error checking
- Environment-specific overrides

### Configuration Sections

The configuration file is organized into the following sections:

#### 1. Topology Configuration

```yaml
topology:
  name: "ecmp-test"
  paths: 4
  source_hosts: 4
  destination_hosts: 1
  base_network: "10.0.0.0/8"
```

#### 2. Test Configuration

```yaml
test:
  name: "ECMP Hash Testing"
  description: "Test ECMP hash algorithm with Source IP only"
  duration: 300  # seconds
  iterations: 1000
  traffic_type: "icmp"
```

#### 3. Traffic Configuration

```yaml
traffic:
  generator: "ping"
  packet_size: 64
  rate: 100  # packets per second
  sources:
    - "10.0.1.10"
    - "10.0.1.11"
    - "10.0.1.12"
    - "10.0.1.13"
  destination: "192.168.100.10"
```

#### 4. Analysis Configuration

```yaml
analysis:
  statistical_tests:
    - "chi_square"
    - "kolmogorov_smirnov"
    - "anderson_darling"
  confidence_level: 0.95
  significance_level: 0.05
```

#### 5. Reporting Configuration

```yaml
reporting:
  formats:
    - "allure"
    - "iso"
    - "json"
  output_dir: "results/reports"
  include_plots: true
  include_statistics: true
```

### How to Customize Tests

#### Modify Test Parameters

Edit [`config/test_config.yaml`](config/test_config.yaml) to change test parameters:

```yaml
# Change test duration
test:
  duration: 600  # Increase to 10 minutes

# Change traffic rate
traffic:
  rate: 200  # Increase to 200 packets per second

# Change statistical tests
analysis:
  statistical_tests:
    - "chi_square"
    - "shapiro_wilk"  # Add new test
```

#### Change Topology

```yaml
# Change number of paths
topology:
  paths: 3  # Use 3-path topology

# Change number of source hosts
topology:
  source_hosts: 2  # Use only 2 source hosts
```

#### Customize Traffic Patterns

```yaml
# Add custom source IPs
traffic:
  sources:
    - "10.0.1.10"
    - "10.0.1.20"  # Custom IP
    - "10.0.1.30"  # Custom IP

# Change traffic type
traffic:
  traffic_type: "udp"  # Use UDP instead of ICMP
```

### Environment-Specific Overrides

You can create environment-specific configuration files:

```bash
# Create development configuration
cp config/test_config.yaml config/test_config_dev.yaml

# Create production configuration
cp config/test_config.yaml config/test_config_prod.yaml

# Use specific configuration
make test CONFIG=config/test_config_dev.yaml
```

### Configuration Validation

The configuration file is validated before use:

```bash
# Validate configuration
python scripts/utils.py --validate-config config/test_config.yaml

# Show configuration
python scripts/utils.py --show-config config/test_config.yaml
```

## Python Scripts

The project includes several Python scripts that provide advanced functionality for testing, analysis, and reporting. These scripts offer more flexibility and power than the Bash scripts.

### Overview of Python Scripts

#### [`scripts/analyzer.py`](scripts/analyzer.py)
Statistical analysis tool for ECMP test results.

**Features:**
- Chi-square test for uniformity
- Kolmogorov-Smirnov test
- Anderson-Darling test
- Shapiro-Wilk test for normality
- Descriptive statistics
- Visualizations and plots

**Usage:**
```bash
# Analyze captured traffic
python scripts/analyzer.py --results results/captures/

# Analyze with specific tests
python scripts/analyzer.py --results results/captures/ --tests chi_square,ks_test

# Generate plots
python scripts/analyzer.py --results results/captures/ --plot

# Save analysis to file
python scripts/analyzer.py --results results/captures/ --output results/analysis/analysis.json
```

#### [`scripts/traffic_gen.py`](scripts/traffic_gen.py)
Flexible traffic generation tool.

**Features:**
- Multiple traffic types (ICMP, UDP, TCP)
- Configurable packet rates and sizes
- Custom source and destination IPs
- Traffic pattern generation
- Real-time statistics

**Usage:**
```bash
# Generate ICMP traffic
python scripts/traffic_gen.py --type icmp --rate 100 --duration 300

# Generate UDP traffic
python scripts/traffic_gen.py --type udp --rate 200 --duration 600

# Use configuration file
python scripts/traffic_gen.py --config config/test_config.yaml

# Custom source IPs
python scripts/traffic_gen.py --sources 10.0.1.10,10.0.1.11 --destination 192.168.100.10
```

#### [`scripts/deploy.py`](scripts/deploy.py)
Python-based deployment tool.

**Features:**
- Topology deployment
- Configuration management
- Health checks
- Error handling
- Logging

**Usage:**
```bash
# Deploy topology
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml

# Deploy with configuration
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml --config config/test_config.yaml

# Skip verification
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml --skip-verify

# Verbose output
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml --verbose
```

#### [`scripts/report_gen.py`](scripts/report_gen.py)
Multi-format report generation tool.

**Features:**
- Allure report generation
- ISO 29119-3 report generation
- JSON report generation
- HTML report generation
- Custom report templates

**Usage:**
```bash
# Generate Allure report
python scripts/report_gen.py --format allure --results results/allure-results/

# Generate ISO report
python scripts/report_gen.py --format iso --results results/analysis/

# Generate JSON report
python scripts/report_gen.py --format json --results results/analysis/

# Generate all reports
python scripts/report_gen.py --format all --results results/analysis/

# Custom output directory
python scripts/report_gen.py --format all --results results/analysis/ --output results/reports/
```

#### [`scripts/utils.py`](scripts/utils.py)
Utility functions for common operations.

**Features:**
- Configuration validation
- File operations
- Logging setup
- Error handling
- Helper functions

**Usage:**
```bash
# Validate configuration
python scripts/utils.py --validate-config config/test_config.yaml

# Show configuration
python scripts/utils.py --show-config config/test_config.yaml

# Check topology
python scripts/utils.py --check-topology topology/clab-ecmp-4paths.yml

# Show help
python scripts/utils.py --help
```

### When to Use Python vs Bash Scripts

**Use Python Scripts When:**
- You need complex data analysis
- You require flexible configuration
- You want to generate visualizations
- You need to process large datasets
- You prefer modern, maintainable code

**Use Bash Scripts When:**
- You need quick, simple operations
- You're working in a CI/CD pipeline
- You want minimal dependencies
- You need fast execution
- You prefer traditional shell scripting

### Installation of Dependencies

Python scripts require the following dependencies:

```bash
# Install all dependencies
pip install -r requirements.txt

# Or install specific packages
pip install pyyaml jinja2 numpy scipy matplotlib pandas allure-python
```

**Key Dependencies:**
- `pyyaml`: YAML configuration parsing
- `jinja2`: Template rendering
- `numpy`: Numerical computing
- `scipy`: Statistical analysis
- `matplotlib`: Plotting and visualization
- `pandas`: Data manipulation
- `allure-python`: Allure report generation

### Usage Examples

#### Complete Test Workflow

```bash
# Deploy topology
python scripts/deploy.py --topology topology/clab-ecmp-4paths.yml

# Generate traffic
python scripts/traffic_gen.py --config config/test_config.yaml

# Analyze results
python scripts/analyzer.py --results results/captures/ --plot

# Generate reports
python scripts/report_gen.py --format all --results results/analysis/
```

#### Statistical Analysis

```bash
# Run all statistical tests
python scripts/analyzer.py --results results/captures/ --tests all

# Generate visualizations
python scripts/analyzer.py --results results/captures/ --plot --output results/analysis/plots/

# Save analysis results
python scripts/analyzer.py --results results/captures/ --output results/analysis/analysis.json
```

#### Custom Traffic Generation

```bash
# Generate custom traffic pattern
python scripts/traffic_gen.py \
  --type udp \
  --rate 150 \
  --duration 500 \
  --sources 10.0.1.10,10.0.1.11,10.0.1.12 \
  --destination 192.168.100.10 \
  --packet-size 128
```

## CI/CD with GitHub Actions

The project uses GitHub Actions for continuous integration, continuous deployment, and automated testing. The CI/CD pipeline ensures code quality, validates configurations, runs comprehensive tests, and generates detailed reports.

### Overview of Workflows

The project includes three main GitHub Actions workflows:

#### 1. [`test.yml`](.github/workflows/test.yml) - Main Testing Workflow

**Purpose:** Run comprehensive tests on every push and pull request.

**Triggers:**
- Push to `main` branch
- Pull requests to `main` branch
- Manual workflow dispatch

**Jobs:**
- **Lint**: Run linting tools (flake8, black, yamllint, shellcheck)
- **Validate**: Validate YAML configurations
- **Deploy**: Deploy topology and verify
- **Test**: Run test suite with matrix strategy
- **Report**: Generate test reports

**Matrix Strategy:**
- Path counts: 2, 3, 4
- Hash policies: L3, L4
- Test types: quick, full

**Artifacts:**
- Test results
- Traffic captures
- Analysis results
- Generated reports

#### 2. [`report.yml`](.github/workflows/report.yml) - Report Generation Workflow

**Purpose:** Generate reports from existing test results.

**Triggers:**
- Manual workflow dispatch
- Completion of test workflow

**Jobs:**
- **Allure Report**: Generate Allure HTML report
- **ISO Report**: Generate ISO 29119-3 compliant report
- **JSON Report**: Generate JSON report for automation
- **Upload**: Upload reports as artifacts

**Artifacts:**
- Allure HTML report
- ISO 29119-3 report
- JSON report
- Statistical analysis

#### 3. [`scheduled.yml`](.github/workflows/scheduled.yml) - Scheduled Testing Workflow

**Purpose:** Run scheduled tests for trend analysis and regression detection.

**Triggers:**
- Daily schedule (UTC 00:00)
- Manual workflow dispatch

**Jobs:**
- **Deploy**: Deploy topology
- **Test**: Run comprehensive tests
- **Analyze**: Perform statistical analysis
- **Trend**: Compare with historical results
- **Report**: Generate trend reports

**Artifacts:**
- Test results
- Trend analysis
- Comparison reports
- Historical data

### Workflow Triggers

#### Automatic Triggers

```yaml
# On push to main
on:
  push:
    branches: [ main ]

# On pull request to main
on:
  pull_request:
    branches: [ main ]

# Scheduled runs
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight UTC
```

#### Manual Triggers

```yaml
# Manual workflow dispatch
on:
  workflow_dispatch:
    inputs:
      topology:
        description: 'Topology to test'
        required: true
        default: '4paths'
      test_type:
        description: 'Test type'
        required: true
        default: 'full'
```

### Job Descriptions

#### Lint Job

```yaml
lint:
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: pip install -r requirements.txt
    
    - name: Run flake8
      run: flake8 scripts/*.py
    
    - name: Run black
      run: black --check scripts/*.py
    
    - name: Run yamllint
      run: yamllint config/ topology/
    
    - name: Run shellcheck
      run: shellcheck scripts/*.sh
```

#### Test Job

```yaml
test:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      paths: [2, 3, 4]
      hash_policy: [L3, L4]
      test_type: [quick, full]
  steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: pip install -r requirements.txt
    
    - name: Generate topology
      run: make topology PATHS=${{ matrix.paths }}
    
    - name: Deploy topology
      run: make deploy TOPOLOGY=topology/clab-ecmp-${{ matrix.paths }}paths.yml
    
    - name: Run tests
      run: make test CONFIG=config/test_config.yaml
    
    - name: Upload results
      uses: actions/upload-artifact@v3
      with:
        name: test-results-${{ matrix.paths }}paths-${{ matrix.hash_policy }}
        path: results/
```

### Artifacts and Reports

#### Artifact Storage

All workflows generate and store artifacts:

```yaml
- name: Upload test results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: results/
    retention-days: 30
```

#### Report Types

1. **Allure Reports**: Interactive HTML reports
   - Location: `results/reports/allure/`
   - Format: HTML
   - Features: Test history, trends, screenshots

2. **ISO Reports**: ISO 29119-3 compliant reports
   - Location: `results/reports/iso/`
   - Format: Markdown/PDF
   - Features: Standardized format, compliance

3. **JSON Reports**: Machine-readable reports
   - Location: `results/reports/json/`
   - Format: JSON
   - Features: Automation, integration

4. **Trend Reports**: Historical trend analysis
   - Location: `results/reports/trends/`
   - Format: HTML/JSON
   - Features: Historical comparison, regression detection

### How to Use Workflows

#### Trigger Workflows Manually

1. Go to the Actions tab in GitHub
2. Select the workflow you want to run
3. Click "Run workflow"
4. Configure parameters (if applicable)
5. Click "Run workflow"

#### Download Artifacts

1. Go to the Actions tab in GitHub
2. Select a workflow run
3. Scroll to the Artifacts section
4. Click on the artifact name to download

#### View Reports

1. Download the Allure report artifact
2. Extract the archive
3. Open `index.html` in a web browser
4. Navigate through the interactive report

#### Configure Workflows

Edit workflow files in [`.github/workflows/`](.github/workflows/):

```yaml
# Change schedule
schedule:
  - cron: '0 6 * * *'  # Daily at 6 AM UTC

# Change matrix strategy
matrix:
  paths: [2, 3, 4, 5]  # Add 5-path topology

# Change retention
retention-days: 60  # Keep artifacts for 60 days
```

### Best Practices

1. **Use Matrix Strategy**: Test multiple configurations in parallel
2. **Cache Dependencies**: Speed up workflow execution
3. **Upload Artifacts**: Store results for later analysis
4. **Use Secrets**: Store sensitive information securely
5. **Monitor Workflows**: Regularly check workflow status
6. **Update Dependencies**: Keep dependencies up to date

## ISO 29119-3 Compliance

The project includes comprehensive ISO 29119-3 compliant documentation for software testing. ISO 29119-3 is an international standard that provides guidelines for test documentation.

### Overview of ISO 29119-3 Documentation

The ISO 29119-3 documentation is located in the [`docs/iso29119-3/`](docs/iso29119-3/) directory and includes:

1. **Test Plan**: [`test_plan.md`](docs/iso29119-3/test_plan.md)
2. **Test Design Specification**: [`test_design_spec.md`](docs/iso29119-3/test_design_spec.md)
3. **Test Report Template**: [`test_report_template.md`](docs/iso29119-3/test_report_template.md)
4. **Overview**: [`README.md`](docs/iso29119-3/README.md)

### Document Structure

#### Test Plan ([`test_plan.md`](docs/iso29119-3/test_plan.md))

The test plan defines the overall approach to testing:

**Sections:**
- Test Plan Identifier
- Introduction
- Test Items
- Features to be Tested
- Features Not to be Tested
- Approach
- Pass/Fail Criteria
- Suspension Criteria and Resumption Requirements
- Test Deliverables
- Remaining Test Tasks
- Environmental Needs
- Staffing and Training Needs
- Responsibilities
- Schedule
- Risks and Contingencies
- Approvals

**Key Content:**
- Scope of testing
- Test objectives
- Test strategy
- Resource requirements
- Timeline and milestones

#### Test Design Specification ([`test_design_spec.md`](docs/iso29119-3/test_design_spec.md))

The test design specification details individual test cases:

**Sections:**
- Test Design Specification Identifier
- Features to be Tested
- Approach Refinements
- Test Identification
- Features to be Tested
- Approach Refinements
- Test Identification
- Test Cases

**Key Content:**
- Detailed test cases
- Test procedures
- Expected results
- Test data requirements
- Test environment setup

#### Test Report Template ([`test_report_template.md`](docs/iso29119-3/test_report_template.md))

The test report template provides a standardized format for test results:

**Sections:**
- Test Report Identifier
- Summary
- Variances
- Comprehensiveness Assessment
- Summary of Results
- Evaluation
- Summary of Activities
- Approvals

**Key Content:**
- Test execution summary
- Test results
- Defects found
- Recommendations
- Sign-off

### How to Use the Documents

#### Before Testing

1. **Review the Test Plan**
   ```bash
   # Read the test plan
   cat docs/iso29119-3/test_plan.md
   ```

2. **Understand Test Scope**
   - Identify features to be tested
   - Review test approach
   - Understand pass/fail criteria

3. **Prepare Test Environment**
   - Set up required resources
   - Configure test tools
   - Prepare test data

#### During Testing

1. **Follow Test Design Specification**
   ```bash
   # Read test design specification
   cat docs/iso29119-3/test_design_spec.md
   ```

2. **Execute Test Cases**
   - Follow test procedures
   - Record test results
   - Document deviations

3. **Track Progress**
   - Update test status
   - Log issues found
   - Monitor test metrics

#### After Testing

1. **Generate Test Report**
   ```bash
   # Generate ISO 29119-3 compliant report
   make report-iso
   ```

2. **Review Results**
   - Analyze test results
   - Identify trends
   - Document findings

3. **Update Documentation**
   - Update test plan if needed
   - Document lessons learned
   - Archive test artifacts

### Benefits of Compliance

#### Standardization

- **Consistent Format**: All test documentation follows the same structure
- **Clear Communication**: Standardized terminology and format
- **Easy Review**: Familiar structure for reviewers

#### Quality Assurance

- **Comprehensive Coverage**: Ensures all aspects are considered
- **Traceability**: Links between requirements, tests, and results
- **Audit Trail**: Complete record of testing activities

#### Process Improvement

- **Best Practices**: Follows industry best practices
- **Continuous Improvement**: Framework for process improvement
- **Knowledge Transfer**: Easy to hand over to new team members

#### Compliance

- **Industry Standards**: Meets international standards
- **Regulatory Requirements**: Supports regulatory compliance
- **Customer Confidence**: Demonstrates commitment to quality

### Integration with CI/CD

The ISO 29119-3 documentation is integrated with the CI/CD pipeline:

```yaml
# Generate ISO report in CI/CD
- name: Generate ISO Report
  run: make report-iso

- name: Upload ISO Report
  uses: actions/upload-artifact@v3
  with:
    name: iso-report
    path: results/reports/iso/
```

### Customization

You can customize the ISO 29119-3 documents for your specific needs:

1. **Update Test Plan**
   - Modify test scope
   - Adjust test approach
   - Update resource requirements

2. **Extend Test Design**
   - Add new test cases
   - Modify existing procedures
   - Update expected results

3. **Customize Report Template**
   - Add custom sections
   - Modify report format
   - Include additional metrics

## CI/CD

This project uses GitHub Actions for automated testing, reporting, and deployment. The CI/CD pipeline ensures code quality, validates configurations, runs comprehensive tests, and generates detailed reports.

### Workflows

- **ECMP Testing CI/CD**: Main testing workflow that runs on push, pull requests, and scheduled execution
- **Generate Reports**: Manual workflow for generating reports from existing test results
- **Scheduled ECMP Testing**: Daily scheduled testing with trend analysis

### Features

- Automated linting and validation (flake8, black, yamllint, shellcheck)
- Topology deployment and verification
- Comprehensive test execution with matrix strategy (2, 3, 4 paths; L3, L4 hash policies)
- Multiple report formats (Allure, ISO 29119-3, JSON, HTML)
- Automated cleanup and resource management
- Trend analysis for historical test results
- Dependency updates via Dependabot

### Documentation

See [`docs/CI_CD.md`](docs/CI_CD.md) for detailed CI/CD documentation including workflow descriptions, troubleshooting, and best practices.

## Implementation Details

### 1. Containerlab Topology ([`topology/clab-ecmp-test.yml`](topology/clab-ecmp-test.yml))

Defines the complete network topology with:
- 11 nodes (4 source hosts, 6 routers, 1 destination host)
- FRRouting container image for routers
- Alpine Linux for hosts
- Network interfaces and connections
- Startup commands for each router

**Key Features:**
- Declarative YAML topology definition
- Automatic interface configuration
- FRR daemon startup
- IP forwarding enabled on all routers

**Reference:** https://containerlab.dev/manual/

### 2. Topology Deployment Script ([`scripts/deploy_topology.sh`](scripts/deploy_topology.sh))

Automated deployment script with:
- Pre-deployment checks (Containerlab, Docker, topology validation)
- Existing topology cleanup
- Deployment with error handling
- Post-deployment verification
- Status display

**Key Features:**
- Comprehensive error handling and logging
- Color-coded output for better readability
- Support for CI/CD automation
- Network connectivity verification
- Container status checking

**Options:**
- `-h, --help`: Show help message
- `-v, --verbose`: Enable verbose output
- `-s, --skip-checks`: Skip pre-deployment checks
- `-c, --cleanup`: Cleanup existing topology
- `-n, --no-verify`: Skip deployment verification

**Reference:** https://containerlab.dev/cmd/deploy/

### 3. ECMP Configuration Script ([`scripts/configure_ecmp.sh`](scripts/configure_ecmp.sh))

Configures FRRouting on all routers for ECMP:
- Edge router (R1): 4 equal-cost static routes
- Core routers (R2-R5): Static routing
- Destination router (R6): Multi-path routing
- Kernel ECMP hash configuration (Source IP only)

**Key Features:**
- Automatic FRR daemon readiness detection
- OSPF configuration for dynamic routing
- Static routes for ECMP paths
- Kernel ECMP hash policy configuration
- Configuration verification
- Status display

**ECMP Configuration:**
- 4 equal-cost routes with metric 100
- Hash algorithm: Source IP only (`net.ipv4.fib_multipath_hash_policy=1`)
- OSPF for network discovery
- Static routes for deterministic path selection

**Options:**
- `-h, --help`: Show help message
- `-v, --verbose`: Enable verbose output
- `-s, --skip-verify`: Skip configuration verification
- `-r, --router N`: Configure only router N (1-6)
- `-S, --status`: Show ECMP status only

**Reference:** https://docs.frrouting.org/

### 4. FRR Configuration Templates ([`configs/frr/`](configs/frr/))

Base configuration templates for each router type:

**Edge Router (R1):**
- 4 interfaces for ECMP paths
- 4 equal-cost static routes to destination
- OSPF configuration
- Passive interface on source network

**Core Routers (R2-R5):**
- 2 interfaces (edge and destination)
- Static routes for path forwarding
- OSPF configuration

**Destination Router (R6):**
- 4 interfaces to core routers
- 1 interface to destination network
- 4 equal-cost routes to source network
- OSPF configuration

**Each router includes:**
- `frr.conf`: Main FRR configuration
- `daemons`: Daemon configuration (zebra, ospfd)
- `vtysh.conf`: vtysh shell configuration

**Reference:** https://docs.frrouting.org/en/latest/daemons.html

### 5. Host Configurations ([`configs/hosts/`](configs/hosts/))

Network configuration scripts for hosts:
- IP address assignment
- Default route configuration
- Interface setup

## IP Addressing Scheme

| Network | Purpose | IP Range | Gateway |
|---------|---------|----------|---------|
| 10.0.1.0/24 | Source Network | 10.0.1.0-10.0.1.255 | 10.0.1.1 |
| 10.0.2.0/24 | ECMP Path 1 | 10.0.2.0-10.0.2.255 | 10.0.2.1 |
| 10.0.3.0/24 | ECMP Path 2 | 10.0.3.0-10.0.3.255 | 10.0.3.1 |
| 10.0.4.0/24 | ECMP Path 3 | 10.0.4.0-10.0.4.255 | 10.0.4.1 |
| 10.0.5.0/24 | ECMP Path 4 | 10.0.5.0-10.0.5.255 | 10.0.5.1 |
| 10.0.6.0/24 | Core-Dest Link 1 | 10.0.6.0-10.0.6.255 | - |
| 10.0.7.0/24 | Core-Dest Link 2 | 10.0.7.0-10.0.7.255 | - |
| 10.0.8.0/24 | Core-Dest Link 3 | 10.0.8.0-10.0.8.255 | - |
| 10.0.9.0/24 | Core-Dest Link 4 | 10.0.9.0-10.0.9.255 | - |
| 192.168.100.0/24 | Destination Network | 192.168.100.0-192.168.100.255 | 192.168.100.1 |

## ECMP Configuration Details

### Edge Router (R1) ECMP Routes

```
ip route 192.168.100.0/24 10.0.2.2 100  # Path 1 via R2
ip route 192.168.100.0/24 10.0.3.2 100  # Path 2 via R3
ip route 192.168.100.0/24 10.0.4.2 100  # Path 3 via R4
ip route 192.168.100.0/24 10.0.5.2 100  # Path 4 via R5
```

All routes have equal metric (100), enabling ECMP.

### Kernel ECMP Hash Configuration

```bash
net.ipv4.fib_multipath_hash_policy=1  # Source IP only
net.ipv4.fib_multipath_use_permanent_addr=1
```

This configures the Linux kernel to use Source IP address only for ECMP hash calculation.

## Verification

### Check ECMP Routes

```bash
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"
```

### Check Kernel ECMP Configuration

```bash
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy
```

### Test Connectivity

```bash
# From source host to destination
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10

# From edge router to destination
docker exec clab-ecmp-test-r1 ping -c 3 192.168.100.10
```

## Logging

All scripts create log files in the `logs/` directory:
- `deploy_topology.log`: Deployment script logs
- `configure_ecmp.log`: ECMP configuration logs

Logs include timestamps and color-coded output for debugging.

## Best Practices

### Reproducibility
- All configurations are version-controlled
- Container images are pinned to specific versions
- Scripts are idempotent where possible

### Error Handling
- Comprehensive error checking in all scripts
- Graceful failure with informative messages
- Log files for troubleshooting

### Documentation
- Inline comments in all configuration files
- References to authoritative documentation
- Clear usage instructions

### Security
- Network isolation for testing
- No exposed ports to external networks
- Minimal container images

## Troubleshooting

### Topology Deployment Fails

1. Check Docker is running: `docker ps`
2. Check Containerlab installation: `clab version`
3. Review logs: `cat logs/deploy_topology.log`

### ECMP Configuration Fails

1. Verify topology is deployed: `docker ps | grep clab-ecmp-test`
2. Check FRR daemons: `docker exec clab-ecmp-test-r1 vtysh -c "show version"`
3. Review logs: `cat logs/configure_ecmp.log`

### Connectivity Issues

1. Check interface status: `docker exec clab-ecmp-test-r1 ip addr show`
2. Verify routing table: `docker exec clab-ecmp-test-r1 vtysh -c "show ip route"`
3. Test basic connectivity: `docker exec clab-ecmp-test-r1 ping -c 1 10.0.2.2`

## References

### Containerlab
- Official Documentation: https://containerlab.dev/
- GitHub Repository: https://github.com/srl-labs/containerlab
- Deployment Guide: https://containerlab.dev/cmd/deploy/

### FRRouting
- Official Documentation: https://docs.frrouting.org/
- ECMP Configuration: https://docs.frrouting.org/en/latest/ecmp.html
- Daemon Configuration: https://docs.frrouting.org/en/latest/daemons.html

### Linux Networking
- ECMP Hash Policies: https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt
- IP Forwarding: https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.kernel.rpf.html

### Standards
- RFC 2992: Analysis of an Equal-Cost Multi-Path Algorithm
- RFC 791: Internet Protocol
- RFC 2328: OSPF Version 2
- ISO/IEC 29119-3: Software and Systems Engineering — Software Testing — Part 3: Test Documentation

### GitHub Actions
- Official Documentation: https://docs.github.com/en/actions
- Workflow Syntax: https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions
- Marketplace: https://github.com/marketplace?type=actions

### Jinja2
- Official Documentation: https://jinja.palletsprojects.com/
- Template Designer Documentation: https://jinja.palletsprojects.com/templates/
- GitHub Repository: https://github.com/pallets/jinja

### Python Statistical Libraries
- NumPy: https://numpy.org/doc/
- SciPy: https://docs.scipy.org/doc/scipy/
- Pandas: https://pandas.pydata.org/docs/
- Matplotlib: https://matplotlib.org/stable/contents.html

### Allure Reporting
- Official Documentation: https://docs.qameta.io/allure/
- GitHub Repository: https://github.com/allure-framework/allure2
- Python Adapter: https://github.com/allure-framework/allure-python

### Additional Documentation
- Project Architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- CI/CD Documentation: [`docs/CI_CD.md`](docs/CI_CD.md)
- Quick Start Guide: [`docs/QUICK_START.md`](docs/QUICK_START.md)
- Launch Instructions: [`docs/LAUNCH_INSTRUCTION.md`](docs/LAUNCH_INSTRUCTION.md)
- Verification Instructions: [`docs/VERIFICATION_INSTRUCTION.md`](docs/VERIFICATION_INSTRUCTION.md)
- API Reference: [`docs/API_REFERENCE.md`](docs/API_REFERENCE.md)
- ISO 29119-3 Documentation: [`docs/iso29119-3/README.md`](docs/iso29119-3/README.md)

## Next Steps

After deploying and configuring the topology:

1. **Start Traffic Capture**: Implement tcpdump capture on ECMP paths
   ```bash
   make traffic-capture
   ```

2. **Generate Test Traffic**: Create traffic with varying Source IPs
   ```bash
   make traffic
   # Or use Python script
   python scripts/traffic_gen.py --config config/test_config.yaml
   ```

3. **Analyze Results**: Parse captures and verify hash distribution
   ```bash
   make analyze
   # Or use Python script
   python scripts/analyzer.py --results results/captures/
   ```

4. **Generate Reports**: Use Allure for test result visualization
   ```bash
   make report
   # Or generate specific reports
   make report-allure
   make report-iso
   make report-json
   ```

5. **Explore New Features**:
   - Try dynamic topology generation with different path counts
   - Use the Makefile for standardized operations
   - Experiment with Python-based analysis tools
   - Review ISO 29119-3 compliant documentation
   - Set up GitHub Actions for automated testing

6. **Additional Documentation**:
   - See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the complete testing framework design
   - See [`docs/CI_CD.md`](docs/CI_CD.md) for detailed CI/CD documentation
   - See [`docs/QUICK_START.md`](docs/QUICK_START.md) for detailed quick start guide
   - See [`docs/iso29119-3/README.md`](docs/iso29119-3/README.md) for ISO 29119-3 documentation
   - See [`scripts/README.md`](scripts/README.md) for scripts documentation
   - See [`topology/README.md`](topology/README.md) for topology documentation

7. **CI/CD Integration**:
   - Set up GitHub Actions for automated testing
   - Configure workflow triggers and schedules
   - Review test results and reports
   - Monitor trends and regressions

8. **Customization**:
   - Modify [`config/test_config.yaml`](config/test_config.yaml) for custom test parameters
   - Create custom Jinja2 templates for specialized topologies
   - Extend Python scripts for additional analysis
   - Add new test cases to the test suite

## License

This implementation follows the architecture design specified in [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Contributing

When making changes:
1. Update this README with any new features
2. Maintain consistency with the architecture design
3. Test all scripts after modifications
4. Update documentation references as needed
