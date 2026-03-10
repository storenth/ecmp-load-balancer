# ECMP Testing - Launch Instruction

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [System Requirements](#system-requirements)
4. [Installation Guide](#installation-guide)
5. [Topology Deployment](#topology-deployment)
6. [ECMP Configuration](#ecmp-configuration)
7. [Test Execution](#test-execution)
8. [CI/CD Integration](#cicd-integration)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)
11. [References](#references)

---

## Overview

This document provides comprehensive instructions for launching and executing the ECMP (Equal-Cost Multi-Path) hash testing framework. The framework tests ECMP routing behavior using a hash algorithm based on Source IP address only.

**Key Components:**
- Containerlab for network topology emulation
- FRRouting for ECMP configuration
- tcpdump for traffic capture
- Allure for test reporting
- Automated scripts for end-to-end testing

**Reference Documents:**
- [Architecture Design](../ARCHITECTURE.md)
- [Quick Start Guide](QUICK_START.md)
- [Verification Instruction](VERIFICATION_INSTRUCTION.md)

---

## Prerequisites

### Software Requirements

| Software | Minimum Version | Recommended Version | Purpose |
|----------|----------------|---------------------|---------|
| Docker | 20.10+ | 24.0+ | Container runtime |
| Containerlab | 0.40+ | 0.50+ | Network topology emulation |
| FRRouting | 8.0+ | 8.5+ | Routing protocol suite |
| tcpdump | 4.9+ | 4.99+ | Packet capture |
| hping3 | 3.0+ | 3.2+ | Traffic generation |
| Allure | 2.20+ | 2.24+ | Test reporting |
| Bash | 4.0+ | 5.0+ | Script execution |
| Python | 3.8+ | 3.11+ | Analysis scripts |

### Operating System Support

- **Linux**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+
- **macOS**: 11.0+ (Big Sur) or later
- **Windows**: WSL2 with Ubuntu 20.04+

### Network Requirements

- Minimum 4GB RAM available for containers
- 10GB free disk space
- Network connectivity for downloading container images
- No firewall restrictions on Docker bridge network (172.17.0.0/16)

---

## System Requirements

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 16 GB |
| Disk Space | 20 GB | 50 GB |
| Network | 1 Gbps | 10 Gbps |

### Software Dependencies

#### Docker Installation

**Linux (Ubuntu/Debian):**
```bash
# Update package index
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop
open /Applications/Docker.app

# Verify installation
docker --version
```

**Reference:** https://docs.docker.com/engine/install/

#### Containerlab Installation

**Linux/macOS:**
```bash
# Install Containerlab
curl -sL https://containerlab.dev/setup.sh | bash

# Verify installation
clab version
```

**Reference:** https://containerlab.dev/install/

#### FRRouting Installation

**Linux (Ubuntu/Debian):**
```bash
# Add FRRouting repository
sudo apt-get install -y curl gnupg2
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
echo "deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable" | sudo tee -a /etc/apt/sources.list.d/frr.list

# Install FRRouting
sudo apt-get update
sudo apt-get install -y frr

# Verify installation
vtysh --version
```

**macOS:**
```bash
# Install via Homebrew
brew install frr

# Verify installation
vtysh --version
```

**Reference:** https://docs.frrouting.org/en/latest/setup.html

#### tcpdump Installation

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install -y tcpdump
```

**macOS:**
```bash
# Already installed on macOS
tcpdump --version
```

**Reference:** https://www.tcpdump.org/

#### hping3 Installation

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install -y hping3
```

**macOS:**
```bash
brew install hping
```

**Reference:** https://linux.die.net/man/8/hping3

#### Allure Installation

**Linux/macOS:**
```bash
# Download Allure
wget https://github.com/allure-framework/allure2/releases/download/2.24.1/allure-2.24.1.tgz
tar -zxvf allure-2.24.1.tgz

# Add to PATH
sudo mv allure-2.24.1 /opt/allure
sudo ln -s /opt/allure/bin/allure /usr/local/bin/allure

# Verify installation
allure --version
```

**Reference:** https://docs.qameta.io/allure/

---

## Installation Guide

### Step 1: Clone Repository

```bash
# Clone the repository
git clone <repository-url>
cd ecmp

# Verify structure
ls -la
```

### Step 2: Verify Dependencies

```bash
# Check all required tools
docker --version
clab version
vtysh --version
tcpdump --version
hping3 --version
allure --version
python3 --version
```

### Step 3: Prepare Environment

```bash
# Create necessary directories
mkdir -p results/{captures,reports,analysis,archives}
mkdir -p logs

# Set permissions
chmod +x scripts/*.sh
chmod +x scripts/helpers/*.sh
```

### Step 4: Validate Configuration

```bash
# Check topology file
cat topology/clab-ecmp-test.yml

# Check traffic configuration
cat configs/traffic/traffic_config.yaml

# Check FRR configurations
ls -la configs/frr/
```

---

## Topology Deployment

### Deployment Overview

The ECMP topology consists of:
- 4 source hosts (h1-h4)
- 6 routers (r1-r6)
- 1 destination host (d1)
- 4 ECMP paths between edge and destination

### Step-by-Step Deployment

#### 1. Deploy Topology

```bash
# Navigate to project directory
cd /path/to/ecmp

# Deploy topology
./scripts/deploy_topology.sh

# Or with verbose output
./scripts/deploy_topology.sh --verbose
```

**Expected Output:**
```
[INFO] Starting ECMP topology deployment...
[INFO] Checking prerequisites...
[INFO] Docker is running
[INFO] Containerlab is installed
[INFO] Cleaning up existing topology...
[INFO] Deploying topology...
[INFO] Topology deployed successfully
[INFO] Verifying deployment...
[INFO] All containers are running
[SUCCESS] Topology deployment completed
```

#### 2. Verify Container Status

```bash
# Check all containers
docker ps | grep clab-ecmp-test

# Expected output:
# clab-ecmp-test-h1   Up
# clab-ecmp-test-h2   Up
# clab-ecmp-test-h3   Up
# clab-ecmp-test-h4   Up
# clab-ecmp-test-r1   Up
# clab-ecmp-test-r2   Up
# clab-ecmp-test-r3   Up
# clab-ecmp-test-r4   Up
# clab-ecmp-test-r5   Up
# clab-ecmp-test-r6   Up
# clab-ecmp-test-d1   Up
```

#### 3. Check Network Connectivity

```bash
# Wait for containers to be ready
./scripts/helpers/wait_for_container.sh clab-ecmp-test-*

# Check connectivity
./scripts/helpers/check_connectivity.sh --all
```

#### 4. Verify Interface Configuration

```bash
# Check edge router interfaces
docker exec clab-ecmp-test-r1 ip addr show

# Check core router interfaces
docker exec clab-ecmp-test-r2 ip addr show
docker exec clab-ecmp-test-r3 ip addr show
docker exec clab-ecmp-test-r4 ip addr show
docker exec clab-ecmp-test-r5 ip addr show
```

### Deployment Options

```bash
# Skip pre-deployment checks
./scripts/deploy_topology.sh --skip-checks

# Skip post-deployment verification
./scripts/deploy_topology.sh --no-verify

# Cleanup existing topology only
./scripts/deploy_topology.sh --cleanup
```

### Troubleshooting Deployment

**Issue: Container startup failures**
```bash
# Check container logs
docker logs clab-ecmp-test-r1

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
```

**Issue: Network connectivity issues**
```bash
# Check Docker network
docker network ls
docker network inspect clab

# Verify IP addressing
docker exec clab-ecmp-test-r1 ip route
```

**Reference:** https://containerlab.dev/manual/

---

## ECMP Configuration

### Configuration Overview

ECMP configuration involves:
1. Configuring FRRouting on all routers
2. Setting up equal-cost static routes
3. Configuring kernel ECMP hash policy (Source IP only)
4. Verifying ECMP path distribution

### Step-by-Step Configuration

#### 1. Configure ECMP on All Routers

```bash
# Configure ECMP on all routers
./scripts/configure_ecmp.sh

# Or with verbose output
./scripts/configure_ecmp.sh --verbose
```

**Expected Output:**
```
[INFO] Starting ECMP configuration...
[INFO] Configuring edge router (r1)...
[INFO] Configuring core router (r2)...
[INFO] Configuring core router (r3)...
[INFO] Configuring core router (r4)...
[INFO] Configuring core router (r5)...
[INFO] Configuring destination router (r6)...
[INFO] Configuring kernel ECMP hash policy...
[INFO] Verifying ECMP configuration...
[SUCCESS] ECMP configuration completed
```

#### 2. Verify ECMP Routes

```bash
# Check ECMP routes on edge router
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Expected output:
# *> 192.168.100.0/24, 4 paths, 4 known
# *   via 10.0.2.2, eth1, weight 1, 100
# *   via 10.0.3.2, eth2, weight 1, 100
# *   via 10.0.4.2, eth3, weight 1, 100
# *   via 10.0.5.2, eth4, weight 1, 100
```

#### 3. Verify Kernel ECMP Hash Policy

```bash
# Check ECMP hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Expected output:
# net.ipv4.fib_multipath_hash_policy = 1
```

**Hash Policy Values:**
- `0`: Layer 3 (Source IP, Destination IP)
- `1`: Layer 3 (Source IP only) ← **This is our configuration**
- `2`: Layer 4 (Source IP, Destination IP, Source Port, Destination Port)

#### 4. Verify OSPF Configuration

```bash
# Check OSPF neighbors
docker exec clab-ecmp-test-r1 vtysh -c "show ip ospf neighbor"

# Check OSPF routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip ospf route"
```

### Configuration Options

```bash
# Configure specific router only
./scripts/configure_ecmp.sh --router 1

# Skip verification
./scripts/configure_ecmp.sh --skip-verify

# Show ECMP status only
./scripts/configure_ecmp.sh --status
```

### Manual Configuration (Advanced)

If you need to manually configure ECMP:

```bash
# Access edge router
docker exec -it clab-ecmp-test-r1 vtysh

# Configure ECMP routes
configure terminal
ip route 192.168.100.0/24 10.0.2.2 100
ip route 192.168.100.0/24 10.0.3.2 100
ip route 192.168.100.0/24 10.0.4.2 100
ip route 192.168.100.0/24 10.0.5.2 100
exit

# Configure kernel hash policy
docker exec clab-ecmp-test-r1 sysctl -w net.ipv4.fib_multipath_hash_policy=1
docker exec clab-ecmp-test-r1 sysctl -w net.ipv4.fib_multipath_use_permanent_addr=1
```

**Reference:** https://docs.frrouting.org/en/latest/ecmp.html

---

## Test Execution

### Test Execution Overview

The test execution involves:
1. Starting traffic captures on all ECMP paths
2. Generating test traffic from source hosts
3. Stopping captures
4. Analyzing results
5. Generating reports

### Step-by-Step Test Execution

#### 1. Run Complete Test

```bash
# Run test with default configuration
./scripts/run_test.sh

# Run with specific scenario
./scripts/run_test.sh --scenario high_volume

# Run with custom duration
./scripts/run_test.sh --duration 120

# Run with custom packet count
./scripts/run_test.sh --count 5000
```

**Expected Output:**
```
[INFO] Starting ECMP test execution...
[INFO] Starting traffic captures on all paths...
[INFO] Capture started on path 1 (r2)
[INFO] Capture started on path 2 (r3)
[INFO] Capture started on path 3 (r4)
[INFO] Capture started on path 4 (r5)
[INFO] Generating test traffic...
[INFO] Traffic generation from h1: 1000 packets
[INFO] Traffic generation from h2: 1000 packets
[INFO] Traffic generation from h3: 1000 packets
[INFO] Traffic generation from h4: 1000 packets
[INFO] Stopping traffic captures...
[INFO] Organizing captured data...
[SUCCESS] Test execution completed
[INFO] Results saved to: results/ecmp-test-20240305-143022-basic/
```

#### 2. Analyze Results

```bash
# Analyze captured traffic
./scripts/analyze_results.sh

# Or with specific results directory
./scripts/analyze_results.sh --input results/ecmp-test-20240305-143022-basic/
```

**Expected Output:**
```
[INFO] Analyzing ECMP test results...
[INFO] Parsing capture files...
[INFO] Path 1: 250 packets (25.0%)
[INFO] Path 2: 250 packets (25.0%)
[INFO] Path 3: 250 packets (25.0%)
[INFO] Path 4: 250 packets (25.0%)
[INFO] Calculating statistical metrics...
[INFO] Chi-square test: p-value = 0.95
[INFO] Distribution is uniform (p > 0.05)
[SUCCESS] Analysis completed
```

#### 3. Generate Allure Report

```bash
# Generate Allure report
./scripts/generate_allure_report.sh

# Or with specific results directory
./scripts/generate_allure_report.sh --input results/ecmp-test-20240305-143022-basic/

# Open report in browser
allure open results/allure-results
```

**Expected Output:**
```
[INFO] Generating Allure report...
[INFO] Parsing test results...
[INFO] Generating statistical analysis...
[INFO] Creating visualizations...
[SUCCESS] Report generated
[INFO] Open report: allure open results/allure-results
```

### Test Scenarios

The framework supports multiple test scenarios defined in [`configs/traffic/traffic_config.yaml`](../configs/traffic/traffic_config.yaml):

#### Basic Distribution Test
```bash
./scripts/run_test.sh --scenario basic_distribution
```
- 1000 packets per source host
- 60 second duration
- Validates uniform distribution

#### High Volume Test
```bash
./scripts/run_test.sh --scenario high_volume
```
- 10000 packets per source host
- 300 second duration
- Tests scalability

#### Low Volume Test
```bash
./scripts/run_test.sh --scenario low_volume
```
- 100 packets per source host
- 30 second duration
- Quick validation

#### Custom Test
```bash
./scripts/run_test.sh --duration 180 --count 2500
```
- Custom duration and packet count
- Flexible testing

### Test Execution Options

```bash
# Preserve capture files
./scripts/run_test.sh --preserve-captures

# Skip cleanup
./scripts/run_test.sh --no-cleanup

# Custom output directory
./scripts/run_test.sh --output /tmp/ecmp-results

# Verbose output
./scripts/run_test.sh --verbose
```

### Manual Test Execution (Advanced)

If you need to manually execute tests:

#### 1. Start Captures

```bash
# Start capture on all paths
./scripts/capture_traffic.sh --duration 120

# Or start captures manually
docker exec -d clab-ecmp-test-r2 tcpdump -i eth1 -w /tmp/path1.pcap
docker exec -d clab-ecmp-test-r3 tcpdump -i eth1 -w /tmp/path2.pcap
docker exec -d clab-ecmp-test-r4 tcpdump -i eth1 -w /tmp/path3.pcap
docker exec -d clab-ecmp-test-r5 tcpdump -i eth1 -w /tmp/path4.pcap
```

#### 2. Generate Traffic

```bash
# Generate traffic from all hosts
./scripts/generate_traffic.sh --duration 120 --count 1000

# Or generate traffic manually
docker exec clab-ecmp-test-h1 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h2 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h3 hping3 -c 1000 -i u1000 192.168.100.10
docker exec clab-ecmp-test-h4 hping3 -c 1000 -i u1000 192.168.100.10
```

#### 3. Stop Captures

```bash
# Stop captures
pkill -f "tcpdump.*clab-ecmp-test"

# Or stop manually
docker exec clab-ecmp-test-r2 pkill tcpdump
docker exec clab-ecmp-test-r3 pkill tcpdump
docker exec clab-ecmp-test-r4 pkill tcpdump
docker exec clab-ecmp-test-r5 pkill tcpdump
```

#### 4. Copy Capture Files

```bash
# Copy capture files from containers
docker cp clab-ecmp-test-r2:/tmp/path1.pcap results/captures/
docker cp clab-ecmp-test-r3:/tmp/path2.pcap results/captures/
docker cp clab-ecmp-test-r4:/tmp/path3.pcap results/captures/
docker cp clab-ecmp-test-r5:/tmp/path4.pcap results/captures/
```

---

## CI/CD Integration

### GitHub Actions Workflow

Create `.github/workflows/ecmp-test.yml`:

```yaml
name: ECMP Hash Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        curl -sL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        curl -sL https://containerlab.dev/setup.sh | bash
        sudo apt-get update
        sudo apt-get install -y frr tcpdump hping3
    
    - name: Deploy topology
      run: ./scripts/deploy_topology.sh
    
    - name: Wait for containers
      run: ./scripts/helpers/wait_for_container.sh clab-ecmp-test-*
    
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
        name: ecmp-test-results
        path: results/
    
    - name: Cleanup
      if: always()
      run: clab destroy -t topology/clab-ecmp-test.yml
```

### GitLab CI/CD Pipeline

Create `.gitlab-ci.yml`:

```yaml
stages:
  - deploy
  - test
  - report
  - cleanup

variables:
  DOCKER_DRIVER: overlay2

deploy:
  stage: deploy
  script:
    - ./scripts/deploy_topology.sh
    - ./scripts/helpers/wait_for_container.sh clab-ecmp-test-*
    - ./scripts/configure_ecmp.sh
  artifacts:
    paths:
      - logs/

test:
  stage: test
  dependencies:
    - deploy
  script:
    - ./scripts/run_test.sh --scenario basic_distribution
    - ./scripts/analyze_results.sh
  artifacts:
    paths:
      - results/
    reports:
      junit: results/allure-results/*.xml

report:
  stage: report
  dependencies:
    - test
  script:
    - ./scripts/generate_allure_report.sh
  artifacts:
    paths:
      - results/reports/
    reports:
      allure: results/allure-results

cleanup:
  stage: cleanup
  dependencies:
    - report
  script:
    - clab destroy -t topology/clab-ecmp-test.yml
  when: always
```

### Jenkins Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Deploy') {
            steps {
                sh './scripts/deploy_topology.sh'
                sh './scripts/helpers/wait_for_container.sh clab-ecmp-test-*'
                sh './scripts/configure_ecmp.sh'
            }
        }
        
        stage('Test') {
            steps {
                sh './scripts/run_test.sh --scenario basic_distribution'
                sh './scripts/analyze_results.sh'
            }
        }
        
        stage('Report') {
            steps {
                sh './scripts/generate_allure_report.sh'
                allure includeProperties: false, jdk: '', results: [[path: 'results/allure-results']]
            }
        }
    }
    
    post {
        always {
            sh 'clab destroy -t topology/clab-ecmp-test.yml'
            archiveArtifacts artifacts: 'results/**/*', allowEmptyArchive: true
        }
    }
}
```

### CI/CD Best Practices

1. **Use container images**: Pin specific versions for reproducibility
2. **Parallel execution**: Run multiple test scenarios in parallel
3. **Artifact retention**: Keep test results for trend analysis
4. **Notification**: Send alerts on test failures
5. **Resource cleanup**: Always clean up resources after tests

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Containerlab Deployment Fails

**Symptoms:**
```
Error: failed to create container: network not found
```

**Solutions:**
```bash
# Check Docker networks
docker network ls

# Clean up orphaned networks
docker network prune

# Restart Docker
sudo systemctl restart docker

# Re-deploy topology
./scripts/deploy_topology.sh --cleanup
./scripts/deploy_topology.sh
```

#### Issue 2: FRRouting Configuration Fails

**Symptoms:**
```
Error: vtysh: command not found
```

**Solutions:**
```bash
# Check FRR installation
docker exec clab-ecmp-test-r1 which vtysh

# Install FRR in container
docker exec clab-ecmp-test-r1 apt-get update
docker exec clab-ecmp-test-r1 apt-get install -y frr

# Restart FRR daemon
docker exec clab-ecmp-test-r1 service frr restart
```

#### Issue 3: No Packets Captured

**Symptoms:**
```
[INFO] Path 1: 0 packets (0.0%)
```

**Solutions:**
```bash
# Check tcpdump installation
docker exec clab-ecmp-test-r2 which tcpdump

# Install tcpdump in container
docker exec clab-ecmp-test-r2 apt-get install -y tcpdump

# Check interface names
docker exec clab-ecmp-test-r2 ip addr show

# Verify capture filter
docker exec clab-ecmp-test-r2 tcpdump -i eth1 -c 10
```

#### Issue 4: Traffic Generation Fails

**Symptoms:**
```
Error: hping3: command not found
```

**Solutions:**
```bash
# Check hping3 installation
docker exec clab-ecmp-test-h1 which hping3

# Install hping3 in container
docker exec clab-ecmp-test-h1 apt-get install -y hping3

# Test connectivity
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10
```

#### Issue 5: Uneven Distribution

**Symptoms:**
```
[INFO] Path 1: 400 packets (40.0%)
[INFO] Path 2: 200 packets (20.0%)
[INFO] Path 3: 200 packets (20.0%)
[INFO] Path 4: 200 packets (20.0%)
```

**Solutions:**
```bash
# Verify ECMP hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Reset to Source IP only
docker exec clab-ecmp-test-r1 sysctl -w net.ipv4.fib_multipath_hash_policy=1

# Verify ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Check route metrics
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24 detail"
```

#### Issue 6: Allure Report Generation Fails

**Symptoms:**
```
Error: allure: command not found
```

**Solutions:**
```bash
# Install Allure
wget https://github.com/allure-framework/allure2/releases/download/2.24.1/allure-2.24.1.tgz
tar -zxvf allure-2.24.1.tgz
sudo mv allure-2.24.1 /opt/allure
sudo ln -s /opt/allure/bin/allure /usr/local/bin/allure

# Verify installation
allure --version
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Deploy with verbose output
./scripts/deploy_topology.sh --verbose

# Configure with verbose output
./scripts/configure_ecmp.sh --verbose

# Run test with verbose output
./scripts/run_test.sh --verbose

# Analyze with verbose output
./scripts/analyze_results.sh --verbose
```

### Log Files

Check log files for detailed error information:

```bash
# Deployment logs
cat logs/deploy_topology.log

# Configuration logs
cat logs/configure_ecmp.log

# Test execution logs
cat logs/test_execution.log

# Traffic generation logs
cat logs/traffic_generation.log

# Capture logs
cat logs/capture_traffic.log
```

### Getting Help

If you encounter issues not covered here:

1. Check the [Architecture Design](../ARCHITECTURE.md) for system overview
2. Review the [Verification Instruction](VERIFICATION_INSTRUCTION.md) for validation steps
3. Consult the [API Reference](API_REFERENCE.md) for script details
4. Check official documentation:
   - [Containerlab](https://containerlab.dev/)
   - [FRRouting](https://docs.frrouting.org/)
   - [tcpdump](https://www.tcpdump.org/)
   - [Allure](https://docs.qameta.io/allure/)

---

## Best Practices

### Deployment Best Practices

1. **Always verify prerequisites** before deployment
2. **Use version-pinned container images** for reproducibility
3. **Monitor resource usage** during deployment
4. **Clean up old topologies** before new deployments
5. **Document custom configurations** for future reference

### Configuration Best Practices

1. **Use configuration templates** for consistency
2. **Validate configurations** before applying
3. **Document changes** with version control
4. **Test configurations** in isolation first
5. **Backup working configurations** before modifications

### Testing Best Practices

1. **Start with basic scenarios** before complex ones
2. **Use appropriate packet counts** for statistical significance
3. **Monitor disk space** for capture files
4. **Clean up old results** regularly
5. **Review logs** after each test execution

### CI/CD Best Practices

1. **Use container images** for consistent environments
2. **Parallelize test execution** where possible
3. **Archive test results** for trend analysis
4. **Implement proper cleanup** after tests
5. **Set up notifications** for test failures

### Security Best Practices

1. **Isolate test networks** from production
2. **Use minimal container images** to reduce attack surface
3. **Rotate credentials** regularly
4. **Audit access logs** periodically
5. **Keep dependencies updated** for security patches

---

## References

### Official Documentation

- **Containerlab**: https://containerlab.dev/
- **FRRouting**: https://docs.frrouting.org/
- **tcpdump**: https://www.tcpdump.org/
- **Allure**: https://docs.qameta.io/allure/
- **hping3**: https://linux.die.net/man/8/hping3

### Standards and RFCs

- **RFC 2992**: Analysis of an Equal-Cost Multi-Path Algorithm
  - https://tools.ietf.org/html/rfc2992
- **RFC 791**: Internet Protocol
  - https://tools.ietf.org/html/rfc791
- **RFC 2544**: Benchmarking Methodology for Network Interconnect Devices
  - https://tools.ietf.org/html/rfc2544
- **ISO/IEC/IEEE 29119-3**: Software testing documentation
  - https://www.iso.org/standard/65274.html
- **IEEE 829**: Standard for Software Test Documentation
  - https://standards.ieee.org/standard/829-2008.html

### Project Documentation

- [Architecture Design](../ARCHITECTURE.md)
- [Quick Start Guide](QUICK_START.md)
- [Verification Instruction](VERIFICATION_INSTRUCTION.md)
- [Test Plan](TEST_PLAN.md)
- [Test Report Template](TEST_REPORT_TEMPLATE.md)
- [API Reference](API_REFERENCE.md)

### Community Resources

- **Containerlab GitHub**: https://github.com/srl-labs/containerlab
- **FRRouting GitHub**: https://github.com/FRRouting/frr
- **Allure GitHub**: https://github.com/allure-framework/allure2

---

## Appendix

### A. Complete Workflow Example

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
./scripts/run_test.sh --scenario high_volume

# 6. Analyze results
./scripts/analyze_results.sh

# 7. Generate report
./scripts/generate_allure_report.sh

# 8. View report
allure open results/allure-results

# 9. Cleanup
clab destroy -t topology/clab-ecmp-test.yml
```

### B. Environment Variables

```bash
# Set custom output directory
export ECMP_OUTPUT_DIR=/tmp/ecmp-results

# Set custom log directory
export ECMP_LOG_DIR=/tmp/ecmp-logs

# Set custom capture directory
export ECMP_CAPTURE_DIR=/tmp/ecmp-captures

# Set Allure results directory
export ALLURE_RESULTS_DIR=results/allure-results
```

### C. Quick Reference Commands

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

---

**Document Version:** 1.0  
**Last Updated:** 2024-03-05  
**Maintainer:** ECMP Testing Team
