# ECMP Testing CI/CD Documentation

This document provides comprehensive documentation for the ECMP Testing CI/CD pipeline implemented with GitHub Actions.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Workflow Triggers](#workflow-triggers)
- [Workflow Jobs](#workflow-jobs)
- [Triggering Workflows](#triggering-workflows)
- [Artifacts and Reports](#artifacts-and-reports)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [References](#references)

## Overview

The ECMP Testing CI/CD pipeline automates the complete testing workflow for ECMP hash distribution validation, including:

1. **Environment Setup**: Installation of all required dependencies
2. **Topology Deployment**: Deployment of Containerlab network topology
3. **ECMP Configuration**: Configuration of FRRouting with ECMP
4. **Test Execution**: Traffic generation and packet capture
5. **Results Analysis**: Statistical analysis of packet distribution
6. **Report Generation**: Allure report generation with test results
7. **Artifact Upload**: Upload of all test artifacts and reports

### Key Features

- ✅ **Automated Testing**: Complete automation of ECMP testing workflow
- ✅ **Multiple Triggers**: Manual, scheduled, push, and pull request triggers
- ✅ **Configurable Scenarios**: Support for multiple test scenarios
- ✅ **Comprehensive Reporting**: Allure reports with detailed test results
- ✅ **Artifact Retention**: Configurable retention policies for artifacts
- ✅ **Error Handling**: Robust error handling and logging
- ✅ **Caching**: Dependency caching for faster builds
- ✅ **Parallel Execution**: Parallel job execution for efficiency

## Architecture

### Workflow Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECMP Testing CI/CD Pipeline                   │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │  Setup  │          │ Deploy  │          │Configure│
   │   Job   │─────────▶│   Job   │─────────▶│   Job   │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
                        ┌─────────┐
                        │  Test   │
                        │   Job   │
                        └─────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
              ┌─────────┐         ┌─────────┐
              │ Analyze │         │ Report  │
              │   Job   │         │   Job   │
              └─────────┘         └─────────┘
                    │                   │
                    └─────────┬─────────┘
                              │
                              ▼
                        ┌─────────┐
                        │ Upload  │
                        │   Job   │
                        └─────────┘
                              │
                              ▼
                        ┌─────────┐
                        │ Notify  │
                        │   Job   │
                        └─────────┘
```

### Job Dependencies

- **setup**: No dependencies (runs first)
- **deploy**: Depends on `setup`
- **configure**: Depends on `deploy`
- **test**: Depends on `configure`
- **analyze**: Depends on `test`
- **report**: Depends on `analyze`
- **upload**: Depends on `report` and `analyze`
- **notify**: Depends on `upload` (runs always)

## Workflow Triggers

### 1. Manual Workflow Dispatch

Trigger the workflow manually from the GitHub Actions UI with configurable parameters:

**Location**: Actions tab → ECMP Testing CI/CD → Run workflow

**Parameters**:
- `test_scenario`: Test scenario to execute (default: `basic_distribution`)
  - `basic_distribution`: Test with all source hosts
  - `single_source`: Test with single source host
  - `high_volume`: Test with high traffic volume
  - `burst_traffic`: Test with burst traffic pattern
- `test_duration`: Test duration in seconds (default: `60`)
- `packet_count`: Number of packets per source (default: `1000`)
- `cleanup_after_test`: Cleanup topology after test (default: `true`)
- `generate_allure_report`: Generate Allure report (default: `true`)
- `debug_mode`: Enable debug mode (default: `false`)

**Example**:
```bash
# Via GitHub CLI
gh workflow run ecmp-test.yml \
  -f test_scenario=basic_distribution \
  -f test_duration=60 \
  -f packet_count=1000 \
  -f debug_mode=true
```

### 2. Scheduled Runs

The workflow runs daily at 00:00 UTC:

```yaml
schedule:
  - cron: '0 0 * * *'
```

To modify the schedule, edit the `.github/workflows/ecmp-test.yml` file.

### 3. Push to Main Branch

The workflow triggers on push to `main` or `develop` branches when relevant files change:

```yaml
push:
  branches:
    - main
    - develop
  paths:
    - 'scripts/**'
    - 'configs/**'
    - 'topology/**'
    - '.github/workflows/ecmp-test.yml'
```

### 4. Pull Requests

The workflow triggers on pull requests to `main` or `develop` branches:

```yaml
pull_request:
  branches:
    - main
    - develop
  paths:
    - 'scripts/**'
    - 'configs/**'
    - 'topology/**'
    - '.github/workflows/ecmp-test.yml'
```

## Workflow Jobs

### 1. Setup Job

**Purpose**: Install dependencies and prepare the environment

**Steps**:
1. Checkout repository
2. Set up Python 3.11
3. Install Python dependencies (scipy, numpy, pandas, etc.)
4. Install Containerlab
5. Install FRRouting
6. Install network tools (tcpdump, hping3, etc.)
7. Install Allure
8. Create required directories
9. Verify Docker installation
10. Verify all dependencies
11. Cache dependencies

**Artifacts**:
- `setup-artifacts`: Setup logs

**Duration**: ~5-10 minutes

### 2. Deploy Job

**Purpose**: Deploy the Containerlab topology

**Steps**:
1. Checkout repository
2. Download setup artifacts
3. Set up Python
4. Install Containerlab
5. Validate topology file
6. Deploy Containerlab topology
7. Verify deployment
8. Display topology status

**Artifacts**:
- `deployment-artifacts`: Deployment logs

**Duration**: ~5-10 minutes

### 3. Configure Job

**Purpose**: Apply ECMP configuration to routers

**Steps**:
1. Checkout repository
2. Download deployment artifacts
3. Set up Python
4. Install Containerlab
5. Configure ECMP on routers
6. Verify ECMP configuration

**Artifacts**:
- `configuration-artifacts`: Configuration logs

**Duration**: ~2-5 minutes

### 4. Test Job

**Purpose**: Run traffic generation and capture

**Steps**:
1. Checkout repository
2. Download configuration artifacts
3. Set up Python
4. Install Python dependencies
5. Install network tools
6. Install Containerlab
7. Create test directories
8. Start traffic captures
9. Generate test traffic
10. Verify capture files

**Artifacts**:
- `test-artifacts`: Capture files and test logs

**Duration**: ~2-5 minutes

### 5. Analyze Job

**Purpose**: Analyze test results and generate reports

**Steps**:
1. Checkout repository
2. Download test artifacts
3. Set up Python
4. Install Python dependencies
5. Install analysis tools
6. Create analysis directories
7. Analyze test results
8. Display analysis results

**Artifacts**:
- `analysis-artifacts`: Analysis results and reports

**Duration**: ~2-5 minutes

### 6. Report Job

**Purpose**: Generate Allure report

**Steps**:
1. Checkout repository
2. Download analysis artifacts
3. Set up Python
4. Install Python dependencies
5. Install Allure
6. Install jq
7. Create report directories
8. Generate Allure report
9. Display report summary

**Artifacts**:
- `allure-report`: Allure HTML report and results

**Duration**: ~1-2 minutes

### 7. Upload Job

**Purpose**: Upload artifacts and reports

**Steps**:
1. Checkout repository
2. Download all artifacts
3. Create archive
4. Upload complete archive
5. Generate test summary
6. Cleanup topology (if enabled)
7. Final status check

**Artifacts**:
- `ecmp-test-complete-archive`: Complete test archive

**Duration**: ~2-5 minutes

### 8. Notify Job

**Purpose**: Send notifications (optional)

**Steps**:
1. Check workflow status
2. Create status badge (optional)

**Duration**: ~1 minute

## Triggering Workflows

### Manual Trigger via GitHub UI

1. Navigate to the **Actions** tab
2. Select **ECMP Testing CI/CD** workflow
3. Click **Run workflow**
4. Select branch
5. Configure parameters
6. Click **Run workflow**

### Manual Trigger via GitHub CLI

```bash
# List workflows
gh workflow list

# Run workflow with default parameters
gh workflow run ecmp-test.yml

# Run workflow with custom parameters
gh workflow run ecmp-test.yml \
  -f test_scenario=basic_distribution \
  -f test_duration=120 \
  -f packet_count=2000 \
  -f debug_mode=true

# View workflow runs
gh run list --workflow=ecmp-test.yml

# View specific run
gh run view <run-id>

# Watch workflow run in real-time
gh run watch <run-id>
```

### Scheduled Runs

The workflow runs automatically daily at 00:00 UTC. To modify the schedule:

1. Edit `.github/workflows/ecmp-test.yml`
2. Find the `schedule` section
3. Modify the cron expression
4. Commit and push changes

**Cron Expression Format**: `minute hour day month day-of-week`

Examples:
- `0 0 * * *`: Daily at 00:00 UTC
- `0 */6 * * *`: Every 6 hours
- `0 0 * * 1`: Weekly on Monday at 00:00 UTC
- `0 0 1 * *`: Monthly on the 1st at 00:00 UTC

### Push and Pull Request Triggers

The workflow automatically triggers on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

Only triggers when relevant files change:
- `scripts/**`
- `configs/**`
- `topology/**`
- `.github/workflows/ecmp-test.yml`

## Artifacts and Reports

### Artifact Types

1. **Setup Artifacts** (1 day retention)
   - Setup logs

2. **Deployment Artifacts** (7 days retention)
   - Deployment logs

3. **Configuration Artifacts** (7 days retention)
   - Configuration logs

4. **Test Artifacts** (7 days retention)
   - Capture files (.pcap)
   - Capture logs
   - Traffic logs

5. **Analysis Artifacts** (30 days retention)
   - Analysis results
   - Statistical reports
   - Analysis logs

6. **Allure Report** (30 days retention)
   - Allure HTML report
   - Allure results
   - Report logs

7. **Complete Archive** (90 days retention)
   - Complete test archive (.tar.gz)

### Downloading Artifacts

**Via GitHub UI**:
1. Navigate to the workflow run
2. Scroll to **Artifacts** section
3. Click on the artifact name to download

**Via GitHub CLI**:
```bash
# List artifacts for a run
gh run view <run-id> --log

# Download all artifacts
gh run download <run-id>

# Download specific artifact
gh run download <run-id> -n <artifact-name>
```

### Allure Report

The Allure report provides a comprehensive view of test results including:

- **Test Overview**: Summary of test execution
- **Test Suites**: Organized test suites
- **Test Cases**: Detailed test case results
- **Statistics**: Pass/fail statistics
- **Trends**: Historical test trends
- **Categories**: Categorized test failures
- **Timeline**: Test execution timeline
- **Environment**: Test environment information

**Viewing the Report**:
1. Download the `allure-report` artifact
2. Extract the archive
3. Open `index.html` in a web browser

**Alternative: Serve Report Locally**:
```bash
# Install Allure
brew install allure  # macOS
# or
apt-get install allure  # Linux

# Serve the report
allure open results/allure-report
```

## Configuration

### CI Configuration File

The CI configuration is defined in `.github/config/ci_config.yaml`:

```yaml
ci_cd:
  enabled: true
  fail_fast: true
  debug: false
  max_runtime_minutes: 60

test:
  default_scenario: "basic_distribution"
  default_duration: 60
  default_packet_count: 1000

thresholds:
  min_packets_per_path: 100
  max_variance_percent: 15
  chi_square_significance: 0.05

timeouts:
  deploy_topology: 300
  configure_ecmp: 180
  capture_traffic: 120
  generate_traffic: 180
  analyze_results: 120
  generate_report: 60

artifacts:
  retention_days:
    setup: 1
    deployment: 7
    configuration: 7
    test: 7
    analysis: 30
    report: 30
    complete_archive: 90
```

### Environment Variables

The workflow uses the following environment variables:

```yaml
env:
  TEST_ID: ${{ github.run_number }}-${{ github.sha }}
  TEST_NAME: 'ECMP Hash Distribution Test'
  TEST_SUITE: 'ECMP Hash Testing Suite'
  RESULTS_DIR: ${{ github.workspace }}/results
  CAPTURES_DIR: ${{ github.workspace }}/results/captures
  ANALYSIS_DIR: ${{ github.workspace }}/results/analysis
  REPORTS_DIR: ${{ github.workspace }}/results/reports
  ALLURE_RESULTS_DIR: ${{ github.workspace }}/results/allure-results
  ALLURE_REPORT_DIR: ${{ github.workspace }}/results/allure-report
  LOGS_DIR: ${{ github.workspace }}/logs
  MIN_PACKETS_PER_PATH: 100
  MAX_VARIANCE_PERCENT: 15
  CHI_SQUARE_SIGNIFICANCE: 0.05
  TOPOLOGY_FILE: ${{ github.workspace }}/topology/clab-ecmp-test.yml
  TRAFFIC_CONFIG: ${{ github.workspace }}/configs/traffic/traffic_config.yaml
```

### Secrets

The workflow can use GitHub Secrets for sensitive information:

- `SLACK_WEBHOOK_URL`: Slack webhook URL for notifications
- `EMAIL_SMTP_SERVER`: SMTP server for email notifications
- `EMAIL_SMTP_PORT`: SMTP port for email notifications
- `EMAIL_USERNAME`: Email username for notifications
- `EMAIL_PASSWORD`: Email password for notifications

**Adding Secrets**:
1. Navigate to repository **Settings**
2. Click **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add secret name and value
5. Click **Add secret**

## Troubleshooting

### Common Issues

#### 1. Workflow Fails at Setup Job

**Symptoms**: Setup job fails with dependency installation errors

**Solutions**:
- Check if all required dependencies are available
- Verify network connectivity to package repositories
- Check for version conflicts in dependencies
- Review setup logs in artifacts

**Debug Steps**:
```bash
# Check workflow logs
gh run view <run-id> --log

# Download setup artifacts
gh run download <run-id> -n setup-artifacts

# Review setup logs
cat logs/setup.log
```

#### 2. Topology Deployment Fails

**Symptoms**: Deploy job fails with topology deployment errors

**Solutions**:
- Verify topology file syntax (YAML)
- Check if Containerlab is installed correctly
- Verify Docker daemon is running
- Check for port conflicts
- Review deployment logs in artifacts

**Debug Steps**:
```bash
# Validate topology file locally
yq eval '.' topology/clab-ecmp-test.yml

# Check Containerlab installation
clab version

# Check Docker status
docker ps
docker info
```

#### 3. ECMP Configuration Fails

**Symptoms**: Configure job fails with configuration errors

**Solutions**:
- Verify FRRouting is installed correctly
- Check if containers are running
- Verify FRR daemons are ready
- Review configuration logs in artifacts

**Debug Steps**:
```bash
# Check FRRouting status
docker exec clab-ecmp-test-r1 vtysh -c "show version"

# Check ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Check kernel ECMP configuration
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy
```

#### 4. Traffic Generation Fails

**Symptoms**: Test job fails with traffic generation errors

**Solutions**:
- Verify hping3 is installed
- Check if containers are running
- Verify network connectivity
- Check for firewall rules
- Review traffic logs in artifacts

**Debug Steps**:
```bash
# Check hping3 installation
hping3 --version

# Test connectivity
docker exec clab-ecmp-test-h1 ping -c 1 192.168.100.10

# Check container status
docker ps --filter "name=clab-ecmp-test-h"
```

#### 5. Analysis Fails

**Symptoms**: Analyze job fails with analysis errors

**Solutions**:
- Verify Python dependencies are installed
- Check if capture files exist
- Verify capture files are valid
- Review analysis logs in artifacts

**Debug Steps**:
```bash
# Check Python dependencies
python3 -c "import scipy; print(scipy.__version__)"

# Check capture files
ls -lh results/captures/

# Validate capture files
tcpdump -r results/captures/*.pcap -c 10
```

#### 6. Report Generation Fails

**Symptoms**: Report job fails with report generation errors

**Solutions**:
- Verify Allure is installed
- Check if analysis results exist
- Verify Allure results directory
- Review report logs in artifacts

**Debug Steps**:
```bash
# Check Allure installation
allure --version

# Check analysis results
ls -lh results/analysis/

# Generate report manually
allure generate results/allure-results --clean -o results/allure-report
```

### Getting Help

If you encounter issues not covered here:

1. **Check Workflow Logs**: Review the workflow logs for detailed error messages
2. **Download Artifacts**: Download and review all artifacts for additional context
3. **Check Documentation**: Review the project documentation in `docs/`
4. **Open an Issue**: Create an issue with detailed information about the problem

**Issue Template**:
```markdown
## Problem Description
[Describe the problem]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happened]

## Workflow Run
- Workflow: ECMP Testing CI/CD
- Run ID: [run-id]
- Branch: [branch-name]
- Commit: [commit-sha]

## Logs
[Paste relevant logs here]

## Environment
- OS: [operating system]
- Python Version: [python version]
- Containerlab Version: [containerlab version]
```

## Best Practices

### 1. Workflow Optimization

- **Use Caching**: Enable caching for dependencies to speed up builds
- **Parallel Execution**: Configure parallel job execution for faster runs
- **Artifact Retention**: Set appropriate retention policies to save storage
- **Timeout Configuration**: Configure appropriate timeouts for each job

### 2. Test Configuration

- **Start Small**: Begin with the `smoke_test` scenario for quick validation
- **Incremental Testing**: Progressively test more complex scenarios
- **Parameter Tuning**: Adjust test parameters based on results
- **Threshold Validation**: Validate thresholds match your requirements

### 3. Monitoring and Alerts

- **Review Results**: Regularly review test results and reports
- **Set Up Notifications**: Configure notifications for failed runs
- **Track Trends**: Monitor test trends over time
- **Investigate Failures**: Promptly investigate and fix failures

### 4. Maintenance

- **Update Dependencies**: Regularly update dependencies for security and performance
- **Review Logs**: Periodically review logs for optimization opportunities
- **Clean Up Artifacts**: Clean up old artifacts to save storage
- **Update Documentation**: Keep documentation up to date

### 5. Security

- **Use Secrets**: Store sensitive information in GitHub Secrets
- **Limit Permissions**: Use minimal required permissions
- **Scan for Vulnerabilities**: Enable security scanning
- **Review Changes**: Review and test changes before merging

## References

### Official Documentation

- **GitHub Actions**: https://docs.github.com/en/actions
- **Containerlab**: https://containerlab.dev/
- **FRRouting**: https://docs.frrouting.org/
- **Allure**: https://docs.qameta.io/allure/
- **Docker**: https://docs.docker.com/

### Project Documentation

- **Architecture**: [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- **API Reference**: [`docs/API_REFERENCE.md`](../docs/API_REFERENCE.md)
- **Launch Instructions**: [`docs/LAUNCH_INSTRUCTION.md`](../docs/LAUNCH_INSTRUCTION.md)
- **Quick Start**: [`docs/QUICK_START.md`](../docs/QUICK_START.md)
- **Test Plan**: [`docs/TEST_PLAN.md`](../docs/TEST_PLAN.md)

### Standards and Best Practices

- **RFC 2544**: Benchmarking Methodology for Network Interconnect Devices
- **RFC 2330**: Framework for IP Performance Metrics
- **RFC 2992**: Analysis of an Equal-Cost Multi-Path Algorithm
- **ISO/IEC/IEEE 29119-3**: Software testing documentation

### Tools and Utilities

- **GitHub CLI**: https://cli.github.com/
- **jq**: https://stedolan.github.io/jq/
- **yq**: https://mikefarah.gitbook.io/yq/
- **tcpdump**: https://www.tcpdump.org/
- **hping3**: http://www.hping.org/

---

**Last Updated**: 2026-03-05

**Maintained By**: ECMP Testing Framework Team

**For questions or issues**, please open an issue on GitHub.
