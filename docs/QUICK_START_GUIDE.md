# Quick Start Guide

Welcome to the ECMP Testing Framework! This guide will help you get started quickly and easily, even if you're new to ECMP testing.

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Your First Test](#your-first-test)
4. [Understanding the Results](#understanding-the-results)
5. [Quick Start Commands](#quick-start-commands)
6. [Configuration Modes](#configuration-modes)
7. [Common Use Cases](#common-use-cases)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

## Introduction

### What is ECMP?

ECMP (Equal-Cost Multi-Path) is a routing technique that allows traffic to be distributed across multiple paths with equal cost. This guide helps you test and validate ECMP hash distribution.

### What This Framework Does

The ECMP Testing Framework:
- Deploys a network topology with multiple ECMP paths
- Generates test traffic from different source IPs
- Captures traffic on each path
- Analyzes the distribution to verify hash behavior
- Generates comprehensive reports

### Why Quick Start Mode?

Quick Start mode is designed for beginners:
- **Simple**: One command to run complete tests
- **Fast**: Get results in minutes
- **Clear**: Easy-to-understand output
- **No Configuration**: Sensible defaults built-in

## Prerequisites

### Required Software

Before you begin, ensure you have the following installed:

1. **Docker** - Required for Containerlab
   ```bash
   docker --version
   # Should show Docker version 20.10 or higher
   ```

2. **Containerlab** - Network topology deployment tool
   ```bash
   clab version
   # Should show Containerlab version
   ```
   
   Install from: https://containerlab.dev/install/

3. **Bash** - Command shell
   ```bash
   bash --version
   # Should show Bash version 4.0 or higher
   ```

4. **Make** - Build automation tool (optional but recommended)
   ```bash
   make --version
   # Should show Make version 4.0 or higher
   ```

5. **Python 3.9+** - For Python-based tools
   ```bash
   python3 --version
   # Should show Python 3.9 or higher
   ```

### Quick Installation Check

Run this command to verify all prerequisites:

```bash
make check-deps
```

If any dependencies are missing, the command will tell you what to install.

## Your First Test

### Step 1: Run Your First Test

The simplest way to get started is to run:

```bash
make quick-test
```

This single command will:
1. ✅ Check all dependencies
2. ✅ Deploy the network topology
3. ✅ Configure ECMP on all routers
4. ✅ Generate test traffic
5. ✅ Capture traffic on all paths
6. ✅ Analyze the results
7. ✅ Generate reports

### Step 2: Wait for Completion

The test will take approximately 2-3 minutes to complete. You'll see progress messages like:

```
========================================
  Quick Start Test
========================================

ℹ Running quick test with simplified configuration
ℹ Configuration: config/quick_start.yaml

========================================
  Checking Dependencies
========================================

✓ All dependencies satisfied

========================================
  Deploying ECMP Topology
========================================

ℹ Deploying topology from: topology/clab-ecmp-test.yml
✓ Topology deployed successfully

========================================
  Configuring ECMP
========================================

ℹ Configuring ECMP on all routers
✓ ECMP configured successfully

========================================
  Running Traffic Test
========================================

ℹ Running test with scenario: basic_distribution
✓ Traffic test completed successfully

========================================
  Analyzing Test Results
========================================

ℹ Analyzing results from: results/captures
✓ Analysis completed successfully

========================================
  Generating Reports
========================================

ℹ Generating Allure report
✓ Reports generated successfully

========================================
  Quick Start Test Completed
========================================

✓ Quick Start test completed successfully

Results available in: results
Allure report: results/allure-report/index.html
To view the report, run: make open-report
```

### Step 3: View the Results

Open the Allure report in your browser:

```bash
make open-report
```

This will open an interactive HTML report showing:
- Test execution summary
- Traffic distribution across paths
- Statistical analysis results
- Pass/fail criteria

## Understanding the Results

### What You'll See

The Allure report shows:

1. **Test Summary**
   - Overall test status (PASSED/FAILED)
   - Test duration
   - Number of packets analyzed

2. **Traffic Distribution**
   - Bar chart showing packets per path
   - Percentage distribution
   - Deviation from ideal (25% per path for 4-path topology)

3. **Statistical Analysis**
   - Chi-square test result
   - Confidence level
   - Pass/fail criteria

4. **Detailed Results**
   - Packet counts per path
   - Source IP distribution
   - Path utilization

### What is a Good Result?

For a 4-path ECMP topology with Source IP hashing:

- **Ideal Distribution**: 25% of traffic on each path
- **Acceptable Range**: 22.5% - 27.5% (±10% tolerance)
- **Good Result**: All paths within acceptable range
- **Excellent Result**: All paths within ±5% of ideal

### Example Output

```
Path Distribution:
  Path 1 (R2): 25.2% (2520 packets) ✓
  Path 2 (R3): 24.8% (2480 packets) ✓
  Path 3 (R4): 25.1% (2510 packets) ✓
  Path 4 (R5): 24.9% (2490 packets) ✓

Statistical Analysis:
  Chi-square test: PASSED
  Confidence level: 95%
  Deviation from ideal: ±0.2%

Overall Result: PASSED
```

## Quick Start Commands

### Primary Commands

```bash
# Run complete test (recommended for first-time users)
make quick-test

# Deploy topology only
make quick-deploy

# Generate reports from existing results
make quick-report

# Show Quick Start help
make quick-help
```

### Utility Commands

```bash
# View test results in browser
make open-report

# Check topology status
make status

# View recent logs
make logs

# Clean up everything
make clean
```

### Command Examples

#### Example 1: First Test Run

```bash
# Run your first test
make quick-test

# View results
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

#### Example 4: Check Status

```bash
# See what's running
make status

# View logs
make logs
```

#### Example 5: Clean Up

```bash
# Remove topology and results
make clean

# Run fresh test
make quick-test
```

## Configuration Modes

The framework provides three configuration modes to match your needs:

### Quick Start Mode (Simple)

**Configuration File**: [`config/quick_start.yaml`](../config/quick_start.yaml)

**Best For**:
- First-time users
- Quick validation tests
- Learning ECMP concepts
- Getting familiar with the framework

**Features**:
- Minimal configuration (only essential parameters)
- Sensible defaults for all values
- Clear, easy-to-understand output
- One-command execution

**Configuration Size**: ~2-3KB

**Example**:
```bash
make quick-test
```

### Standard Mode (Balanced)

**Configuration File**: [`config/standard.yaml`](../config/standard.yaml)

**Best For**:
- Typical testing scenarios
- Development and testing
- Most production use cases
- Users familiar with ECMP testing

**Features**:
- Moderate complexity with most common features
- Good balance of simplicity and functionality
- Multiple test scenarios
- Comprehensive reporting

**Configuration Size**: ~8-10KB

**Example**:
```bash
make test CONFIG=config/standard.yaml
```

### Advanced Mode (Full-Featured)

**Configuration File**: [`config/advanced.yaml`](../config/advanced.yaml)

**Best For**:
- Production testing
- Compliance requirements
- Custom test scenarios
- Power users

**Features**:
- All features enabled
- Advanced statistical analysis
- Multiple report formats
- Extensive customization options

**Configuration Size**: ~25KB

**Example**:
```bash
make test CONFIG=config/advanced.yaml
```

### Mode Comparison

| Feature | Quick Start | Standard | Advanced |
|----------|-------------|-----------|-----------|
| Configuration Size | 2-3KB | 8-10KB | 25KB |
| Test Scenarios | 1 | 3 | 10 |
| Statistical Tests | Basic | Standard | Advanced |
| Report Formats | 2 | 3 | 5 |
| Customization | Minimal | Moderate | Extensive |
| Learning Curve | Low | Medium | High |
| Setup Time | 1 minute | 5 minutes | 15+ minutes |

### When to Switch Modes

**Start with Quick Start if**:
- You're new to ECMP testing
- You want quick results
- You're learning the framework
- You need simple validation

**Switch to Standard if**:
- You need multiple test scenarios
- You want more statistical analysis
- You're testing in development
- You need moderate customization

**Switch to Advanced if**:
- You're testing in production
- You need compliance reporting
- You have custom requirements
- You need extensive analysis

## Common Use Cases

### Use Case 1: Quick Validation

**Scenario**: You want to quickly validate ECMP is working.

**Solution**: Use Quick Start mode

```bash
make quick-test
make open-report
```

**Time**: 2-3 minutes

### Use Case 2: Development Testing

**Scenario**: You're developing and need to test frequently.

**Solution**: Use Standard mode with quick iterations

```bash
# Deploy once
make quick-deploy

# Run multiple tests
make test CONFIG=config/standard.yaml
make test CONFIG=config/standard.yaml
make test CONFIG=config/standard.yaml

# Clean up when done
make clean
```

**Time**: 5-10 minutes per test

### Use Case 3: Production Validation

**Scenario**: You need to validate ECMP before production deployment.

**Solution**: Use Advanced mode with comprehensive testing

```bash
make test CONFIG=config/advanced.yaml
make open-report
```

**Time**: 15-20 minutes

### Use Case 4: Regression Testing

**Scenario**: You want to compare results over time.

**Solution**: Use Standard mode with trend analysis

```bash
# Run test
make test CONFIG=config/standard.yaml

# Archive results
mkdir -p results/archives/$(date +%Y%m%d)
cp -r results/* results/archives/$(date +%Y%m%d)/

# Compare with previous runs
make report CONFIG=config/standard.yaml
```

### Use Case 5: Custom Topology

**Scenario**: You want to test with 2 or 3 paths instead of 4.

**Solution**: Generate custom topology and use Quick Start

```bash
# Generate 2-path topology
make render-topology N=2

# Deploy and test
make deploy TOPOLOGY=topology/clab-ecmp-2paths.yml
make quick-test
```

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Docker Not Running

**Symptom**: Error message "Docker daemon not running"

**Solution**:
```bash
# Start Docker
sudo systemctl start docker  # Linux
open -a Docker            # macOS

# Verify
docker ps
```

#### Issue 2: Containerlab Not Installed

**Symptom**: Error message "clab: command not found"

**Solution**:
```bash
# Install Containerlab
curl -sL https://containerlab.dev/install.sh | sudo -E bash

# Verify
clab version
```

#### Issue 3: Port Already in Use

**Symptom**: Error message "port is already allocated"

**Solution**:
```bash
# Clean up existing topology
make clean

# Try again
make quick-test
```

#### Issue 4: Insufficient Permissions

**Symptom**: Error message "permission denied"

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in
# Or run with sudo (not recommended)
sudo make quick-test
```

#### Issue 5: Test Fails with "No Packets Captured"

**Symptom**: Analysis shows 0 packets on all paths

**Solution**:
```bash
# Check topology status
make status

# Verify ECMP configuration
docker exec clab-ecmp-test-r1 vtysh -c "show ip route"

# Test connectivity
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10

# Re-run test
make quick-test
```

#### Issue 6: Uneven Distribution

**Symptom**: Traffic is heavily skewed to one or two paths

**Solution**:
```bash
# Check ECMP configuration
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Verify hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Should return: net.ipv4.fib_multipath_hash_policy = 1

# If not, reconfigure
make configure
```

#### Issue 7: Report Won't Open

**Symptom**: `make open-report` doesn't open browser

**Solution**:
```bash
# Manually open report
open results/allure-report/index.html  # macOS
xdg-open results/allure-report/index.html  # Linux

# Or view in browser
# Navigate to: file:///path/to/ecmp/results/allure-report/index.html
```

### Getting Help

If you encounter issues:

1. **Check Logs**:
   ```bash
   make logs
   ```

2. **Check Status**:
   ```bash
   make status
   ```

3. **Get Help**:
   ```bash
   make quick-help
   make help
   ```

4. **Review Documentation**:
   - [`README.md`](../README.md) - Full documentation
   - [`ARCHITECTURE.md`](../ARCHITECTURE.md) - System architecture
   - [`docs/QWEN_COMPARISON.md`](QWEN_COMPARISON.md) - Comparison with QWEN

5. **Check GitHub Issues**:
   - Search for similar issues
   - Create a new issue if needed

## Next Steps

### After Your First Test

Congratulations! You've successfully run your first ECMP test. Here's what to do next:

#### 1. Explore the Results

- Review the Allure report in detail
- Check the traffic distribution charts
- Understand the statistical analysis
- Verify pass/fail criteria

#### 2. Try Different Configurations

```bash
# Test with Standard mode
make test CONFIG=config/standard.yaml

# Test with Advanced mode
make test CONFIG=config/advanced.yaml
```

#### 3. Experiment with Topologies

```bash
# Generate 2-path topology
make render-topology N=2
make deploy TOPOLOGY=topology/clab-ecmp-2paths.yml
make quick-test

# Generate 3-path topology
make render-topology N=3
make deploy TOPOLOGY=topology/clab-ecmp-3paths.yml
make quick-test
```

#### 4. Customize Test Parameters

Edit [`config/quick_start.yaml`](../config/quick_start.yaml):

```yaml
# Change test duration
test:
  duration_sec: 120  # Increase to 2 minutes

# Change number of packets
traffic:
  packets_per_src: 2000  # Increase for better statistics

# Change hash policy
ecmp:
  hash_policy: "src-dst-ip"  # Use source and destination IP
```

#### 5. Learn More

Read the comprehensive documentation:

- [`README.md`](../README.md) - Complete framework documentation
- [`ARCHITECTURE.md`](../ARCHITECTURE.md) - System architecture
- [`docs/CI_CD.md`](CI_CD.md) - CI/CD integration
- [`docs/API_REFERENCE.md`](API_REFERENCE.md) - API documentation
- [`docs/TEST_PLAN.md`](TEST_PLAN.md) - Detailed test plan

#### 6. Integrate with CI/CD

Set up automated testing with GitHub Actions:

- Review [`.github/workflows/`](../.github/workflows/)
- Customize workflows for your needs
- Enable scheduled testing
- Monitor test results

#### 7. Contribute

Found a bug or have a feature request?

- Check [`CONTRIBUTING.md`](../CONTRIBUTING.md) (if available)
- Create an issue on GitHub
- Submit a pull request

### Progressive Learning Path

1. **Beginner** (You are here)
   - ✅ Run Quick Start test
   - ✅ Understand basic results
   - ✅ Learn ECMP concepts

2. **Intermediate**
   - ⏳ Use Standard mode
   - ⏳ Customize configurations
   - ⏳ Test different topologies

3. **Advanced**
   - ⏳ Use Advanced mode
   - ⏳ Implement custom scenarios
   - ⏳ Integrate with CI/CD

4. **Expert**
   - ⏳ Contribute to framework
   - ⏳ Extend functionality
   - ⏳ Share knowledge

## Summary

You've learned:

- ✅ How to run your first ECMP test
- ✅ How to understand test results
- ✅ Quick Start commands and usage
- ✅ Different configuration modes
- ✅ Common use cases
- ✅ Troubleshooting tips
- ✅ Next steps for learning

### Key Takeaways

1. **Quick Start is Simple**: One command to get results
2. **Results are Clear**: Easy-to-understand reports
3. **Progressive Disclosure**: Start simple, add complexity as needed
4. **Good Documentation**: Comprehensive guides and references
5. **Community Support**: GitHub issues and discussions

### Quick Reference

```bash
# Run test
make quick-test

# View results
make open-report

# Get help
make quick-help

# Clean up
make clean
```

### Need More Help?

- **Quick Start Help**: `make quick-help`
- **Full Help**: `make help`
- **Documentation**: [`README.md`](../README.md)
- **Issues**: GitHub Issues

---

**Happy Testing! 🚀**

For questions or feedback, please open an issue on GitHub.
