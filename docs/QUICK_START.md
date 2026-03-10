# ECMP Testing - Quick Start Guide

## Overview

This guide provides a fast-track introduction to the ECMP (Equal-Cost Multi-Path) hash testing framework. It covers essential commands and common workflows to get you started quickly.

**For detailed documentation, see:**
- [Launch Instruction](LAUNCH_INSTRUCTION.md) - Complete deployment and execution guide
- [Verification Instruction](VERIFICATION_INSTRUCTION.md) - Result verification guide
- [Test Plan](TEST_PLAN.md) - Comprehensive test plan
- [API Reference](API_REFERENCE.md) - Complete script reference

---

## Prerequisites

Before you begin, ensure you have the following installed:

| Software | Version | Check Command |
|----------|---------|---------------|
| Docker | 20.10+ | `docker --version` |
| Containerlab | 0.40+ | `clab version` |
| FRRouting | 8.0+ | `vtysh --version` |
| tcpdump | 4.9+ | `tcpdump --version` |
| hping3 | 3.0+ | `hping3 --version` |
| Allure | 2.20+ | `allure --version` |

**Quick Installation:**
```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Containerlab
curl -sL https://containerlab.dev/setup.sh | bash

# FRRouting (Ubuntu/Debian)
sudo apt-get install -y frr

# tcpdump and hping3
sudo apt-get install -y tcpdump hping3

# Allure
wget https://github.com/allure-framework/allure2/releases/download/2.24.1/allure-2.24.1.tgz
tar -zxvf allure-2.24.1.tgz
sudo mv allure-2.24.1 /opt/allure
sudo ln -s /opt/allure/bin/allure /usr/local/bin/allure
```

---

## Essential Commands

### 1. Deploy Topology

```bash
# Deploy ECMP topology
./scripts/deploy_topology.sh

# With verbose output
./scripts/deploy_topology.sh --verbose

# Cleanup existing topology
./scripts/deploy_topology.sh --cleanup
```

### 2. Configure ECMP

```bash
# Configure ECMP on all routers
./scripts/configure_ecmp.sh

# Show ECMP status only
./scripts/configure_ecmp.sh --status

# Configure specific router only
./scripts/configure_ecmp.sh --router 1
```

### 3. Run Test

```bash
# Run test with default configuration
./scripts/run_test.sh

# Run with specific scenario
./scripts/run_test.sh --scenario high_volume

# Run with custom duration and packet count
./scripts/run_test.sh --duration 120 --count 5000
```

### 4. Analyze Results

```bash
# Analyze captured traffic
./scripts/analyze_results.sh

# With specific results directory
./scripts/analyze_results.sh --input results/ecmp-test-20240305-143022-basic/
```

### 5. Generate Report

```bash
# Generate Allure report
./scripts/generate_allure_report.sh

# Open report in browser
allure open results/allure-results

# Serve report on HTTP server
allure serve results/allure-results
```

### 6. Cleanup

```bash
# Destroy topology
clab destroy -t topology/clab-ecmp-test.yml

# Clean up old captures
./scripts/helpers/cleanup_captures.sh --age 30
```

---

## Common Workflows

### Workflow 1: Complete Test Execution

```bash
# 1. Deploy topology
./scripts/deploy_topology.sh

# 2. Wait for containers
./scripts/helpers/wait_for_container.sh clab-ecmp-test-*

# 3. Configure ECMP
./scripts/configure_ecmp.sh

# 4. Verify configuration
./scripts/configure_ecmp.sh --status

# 5. Run test
./scripts/run_test.sh --scenario basic_distribution

# 6. Analyze results
./scripts/analyze_results.sh

# 7. Generate report
./scripts/generate_allure_report.sh

# 8. View report
allure open results/allure-results

# 9. Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Workflow 2: Quick Validation

```bash
# Deploy and configure
./scripts/deploy_topology.sh && ./scripts/configure_ecmp.sh

# Run quick test
./scripts/run_test.sh --scenario low_volume

# Check results
./scripts/analyze_results.sh

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Workflow 3: High Volume Testing

```bash
# Deploy and configure
./scripts/deploy_topology.sh && ./scripts/configure_ecmp.sh

# Run high volume test
./scripts/run_test.sh --scenario high_volume

# Analyze and report
./scripts/analyze_results.sh && ./scripts/generate_allure_report.sh

# View report
allure open results/allure-results

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Workflow 4: Manual Testing

```bash
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

## Quick Verification

### Verify Topology Deployment

```bash
# Check all containers are running
docker ps | grep clab-ecmp-test

# Expected: 11 containers running
```

### Verify ECMP Configuration

```bash
# Check ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Expected: 4 equal-cost routes with metric 100

# Check hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Expected: net.ipv4.fib_multipath_hash_policy = 1
```

### Verify Connectivity

```bash
# Test connectivity from source to destination
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10

# Expected: 3 packets transmitted, 3 received, 0% packet loss
```

### Verify Test Results

```bash
# Check capture files
ls -lh results/captures/

# Expected: 4 capture files with similar sizes

# Check analysis results
cat results/analysis/ecmp-test-*/analysis.json

# Expected: Uniform distribution (p > 0.05)
```

---

## Test Scenarios

### Basic Distribution Test

```bash
./scripts/run_test.sh --scenario basic_distribution
```

**Parameters:**
- Packet count: 1000 per source host
- Duration: 60 seconds
- Purpose: Validate basic ECMP distribution

### High Volume Test

```bash
./scripts/run_test.sh --scenario high_volume
```

**Parameters:**
- Packet count: 10000 per source host
- Duration: 300 seconds
- Purpose: Test scalability and statistical significance

### Low Volume Test

```bash
./scripts/run_test.sh --scenario low_volume
```

**Parameters:**
- Packet count: 100 per source host
- Duration: 30 seconds
- Purpose: Quick validation

### Custom Test

```bash
./scripts/run_test.sh --duration 180 --count 2500
```

**Parameters:**
- Custom duration and packet count
- Purpose: Flexible testing

---

## Troubleshooting

### Issue: Containers not starting

```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Containerlab version
clab version

# Re-deploy topology
./scripts/deploy_topology.sh --cleanup
./scripts/deploy_topology.sh
```

### Issue: ECMP not configured

```bash
# Check FRR daemons
docker exec clab-ecmp-test-r1 vtysh -c "show daemons"

# Restart FRR
docker exec clab-ecmp-test-r1 service frr restart

# Reconfigure ECMP
./scripts/configure_ecmp.sh
```

### Issue: No packets captured

```bash
# Check tcpdump installation
docker exec clab-ecmp-test-r2 which tcpdump

# Install tcpdump
docker exec clab-ecmp-test-r2 apt-get install -y tcpdump

# Test capture manually
docker exec clab-ecmp-test-r2 tcpdump -i eth1 -c 10
```

### Issue: Uneven distribution

```bash
# Verify hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Reset to Source IP only
docker exec clab-ecmp-test-r1 sysctl -w net.ipv4.fib_multipath_hash_policy=1

# Reconfigure ECMP
./scripts/configure_ecmp.sh
```

### Issue: Allure report not generating

```bash
# Check Allure installation
allure --version

# Install Allure
wget https://github.com/allure-framework/allure2/releases/download/2.24.1/allure-2.24.1.tgz
tar -zxvf allure-2.24.1.tgz
sudo mv allure-2.24.1 /opt/allure
sudo ln -s /opt/allure/bin/allure /usr/local/bin/allure

# Generate report
./scripts/generate_allure_report.sh
```

---

## Tips and Best Practices

### 1. Always Verify Before Testing

```bash
# Check containers
docker ps | grep clab-ecmp-test

# Check ECMP configuration
./scripts/configure_ecmp.sh --status

# Check connectivity
./scripts/helpers/check_connectivity.sh --all
```

### 2. Use Appropriate Packet Counts

- **Quick validation**: 100 packets per source host
- **Basic testing**: 1000 packets per source host
- **Statistical significance**: 10000 packets per source host

### 3. Monitor Disk Space

```bash
# Check disk usage
df -h

# Clean up old captures
./scripts/helpers/cleanup_captures.sh --age 30
```

### 4. Review Logs

```bash
# Check deployment logs
cat logs/deploy_topology.log

# Check configuration logs
cat logs/configure_ecmp.log

# Check test execution logs
cat logs/test_execution.log
```

### 5. Use Verbose Mode for Debugging

```bash
# Deploy with verbose output
./scripts/deploy_topology.sh --verbose

# Configure with verbose output
./scripts/configure_ecmp.sh --verbose

# Run test with verbose output
./scripts/run_test.sh --verbose
```

---

## Project Structure

```
ecmp/
├── docs/                          # Documentation
│   ├── LAUNCH_INSTRUCTION.md      # Complete deployment guide
│   ├── VERIFICATION_INSTRUCTION.md # Result verification guide
│   ├── TEST_PLAN.md               # Comprehensive test plan
│   ├── TEST_REPORT_TEMPLATE.md   # Test report template
│   ├── QUICK_START.md            # This file
│   └── API_REFERENCE.md          # Complete script reference
├── scripts/                       # Automation scripts
│   ├── deploy_topology.sh        # Deploy topology
│   ├── configure_ecmp.sh         # Configure ECMP
│   ├── run_test.sh               # Run complete test
│   ├── generate_traffic.sh       # Generate traffic
│   ├── capture_traffic.sh        # Capture traffic
│   ├── analyze_results.sh        # Analyze results
│   ├── generate_allure_report.sh # Generate report
│   └── helpers/                  # Helper scripts
│       ├── wait_for_container.sh
│       ├── check_connectivity.sh
│       └── cleanup_captures.sh
├── configs/                       # Configuration files
│   ├── frr/                      # FRRouting configurations
│   ├── hosts/                    # Host configurations
│   └── traffic/                  # Traffic configuration
├── topology/                      # Topology definition
│   └── clab-ecmp-test.yml        # Containerlab topology
├── results/                       # Test results
│   ├── captures/                 # Capture files
│   ├── analysis/                 # Analysis results
│   ├── reports/                  # Generated reports
│   └── archives/                 # Archived results
├── logs/                          # Log files
├── ARCHITECTURE.md               # Architecture design
└── README.md                     # Project overview
```

---

## Next Steps

1. **Read the Launch Instruction** for complete deployment and execution details
2. **Review the Verification Instruction** for result verification guidance
3. **Study the Test Plan** for comprehensive testing approach
4. **Consult the API Reference** for detailed script documentation

---

## Getting Help

If you encounter issues:

1. **Check the logs** in the `logs/` directory
2. **Review the troubleshooting section** in the Launch Instruction
3. **Consult the Verification Instruction** for result interpretation
4. **Check the API Reference** for script details
5. **Review official documentation**:
   - [Containerlab](https://containerlab.dev/)
   - [FRRouting](https://docs.frrouting.org/)
   - [tcpdump](https://www.tcpdump.org/)
   - [Allure](https://docs.qameta.io/allure/)

---

## Quick Reference

### Essential Commands

```bash
# Deploy
./scripts/deploy_topology.sh

# Configure
./scripts/configure_ecmp.sh

# Test
./scripts/run_test.sh

# Analyze
./scripts/analyze_results.sh

# Report
./scripts/generate_allure_report.sh

# Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### Verification Commands

```bash
# Container status
docker ps | grep clab-ecmp-test

# ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Connectivity
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10
```

### Common Options

```bash
# Verbose output
--verbose

# Custom duration
--duration 120

# Custom packet count
--count 5000

# Specific scenario
--scenario high_volume

# Skip verification
--skip-verify

# Show status only
--status
```

---

**Document Version:** 1.0  
**Last Updated:** 2024-03-05  
**Maintainer:** ECMP Testing Team
