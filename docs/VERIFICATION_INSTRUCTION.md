# ECMP Testing - Verification Instruction

## Table of Contents
1. [Overview](#overview)
2. [Topology Verification](#topology-verification)
3. [ECMP Configuration Verification](#ecmp-configuration-verification)
4. [Test Result Interpretation](#test-result-interpretation)
5. [Allure Report Reading](#allure-report-reading)
6. [Statistical Analysis Validation](#statistical-analysis-validation)
7. [Common Failure Scenarios](#common-failure-scenarios)
8. [Troubleshooting Verification Issues](#troubleshooting-verification-issues)
9. [Best Practices](#best-practices)
10. [References](#references)

---

## Overview

This document provides comprehensive instructions for verifying ECMP testing results, interpreting test outputs, and validating statistical analysis. It covers topology verification, ECMP configuration validation, result interpretation, and common failure scenarios.

**Key Verification Areas:**
- Topology deployment and connectivity
- ECMP configuration and routing
- Traffic capture and distribution
- Statistical analysis and test results
- Allure report interpretation

**Reference Documents:**
- [Launch Instruction](LAUNCH_INSTRUCTION.md)
- [Architecture Design](../ARCHITECTURE.md)
- [Test Plan](TEST_PLAN.md)

---

## Topology Verification

### Verification Overview

Topology verification ensures that the ECMP network is correctly deployed and all components are functioning properly.

### Step 1: Container Status Verification

#### Check All Containers

```bash
# List all ECMP test containers
docker ps | grep clab-ecmp-test

# Expected output:
# CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         NAMES
# abc123         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r1
# def456         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r2
# ghi789         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r3
# jkl012         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r4
# mno345         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r5
# pqr678         frrouting/frr  "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-r6
# stu901         alpine         "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-h1
# vwx234         alpine         "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-h2
# yza567         alpine         "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-h3
# bcd890         alpine         "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-h4
# efg123         alpine         "/sbin/init"             2 minutes ago   Up 2 minutes   clab-ecmp-test-d1
```

**Verification Criteria:**
- All 11 containers must be running
- Container status should be "Up"
- No containers should be in "Exited" or "Restarting" state

#### Check Container Health

```bash
# Check container health status
docker inspect --format='{{.State.Health.Status}}' clab-ecmp-test-r1

# Check container restart count
docker inspect --format='{{.RestartCount}}' clab-ecmp-test-r1

# Check container uptime
docker inspect --format='{{.State.StartedAt}}' clab-ecmp-test-r1
```

### Step 2: Network Interface Verification

#### Verify Router Interfaces

```bash
# Check edge router (r1) interfaces
docker exec clab-ecmp-test-r1 ip addr show

# Expected output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
#     inet 127.0.0.1/8 scope host lo
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.1.1/24 brd 10.0.1.255 scope global eth0
# 3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.2.1/24 brd 10.0.2.255 scope global eth1
# 4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.3.1/24 brd 10.0.3.255 scope global eth2
# 5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.4.1/24 brd 10.0.4.255 scope global eth3
# 6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.5.1/24 brd 10.0.5.255 scope global eth4
```

**Verification Criteria:**
- All interfaces should be UP
- IP addresses should match the topology design
- No interface errors or dropped packets

#### Verify Host Interfaces

```bash
# Check source host (h1) interfaces
docker exec clab-ecmp-test-h1 ip addr show

# Expected output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
#     inet 127.0.0.1/8 scope host lo
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.0.1.10/24 brd 10.0.1.255 scope global eth0
```

### Step 3: Network Connectivity Verification

#### Basic Connectivity Tests

```bash
# Test connectivity from source hosts to edge router
docker exec clab-ecmp-test-h1 ping -c 3 10.0.1.1

# Expected output:
# PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
# 64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.123 ms
# 64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.098 ms
# 64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.105 ms
# --- 10.0.1.1 ping statistics ---
# 3 packets transmitted, 3 received, 0% packet loss
```

**Verification Criteria:**
- 0% packet loss
- Consistent latency (< 1ms)
- No timeout errors

#### End-to-End Connectivity

```bash
# Test connectivity from source hosts to destination
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10

# Expected output:
# PING 192.168.100.10 (192.168.100.10) 56(84) bytes of data.
# 64 bytes from 192.168.100.10: icmp_seq=1 ttl=62 time=0.234 ms
# 64 bytes from 192.168.100.10: icmp_seq=2 ttl=62 time=0.198 ms
# 64 bytes from 192.168.100.10: icmp_seq=3 ttl=62 time=0.212 ms
# --- 192.168.100.10 ping statistics ---
# 3 packets transmitted, 3 received, 0% packet loss
```

#### Automated Connectivity Check

```bash
# Run comprehensive connectivity check
./scripts/helpers/check_connectivity.sh --all

# Expected output:
# [INFO] Checking connectivity from h1 to r1... OK
# [INFO] Checking connectivity from h1 to d1... OK
# [INFO] Checking connectivity from h2 to r1... OK
# [INFO] Checking connectivity from h2 to d1... OK
# [INFO] Checking connectivity from h3 to r1... OK
# [INFO] Checking connectivity from h3 to d1... OK
# [INFO] Checking connectivity from h4 to r1... OK
# [INFO] Checking connectivity from h4 to d1... OK
# [SUCCESS] All connectivity checks passed
```

### Step 4: Routing Table Verification

#### Verify Edge Router Routing Table

```bash
# Check edge router (r1) routing table
docker exec clab-ecmp-test-r1 vtysh -c "show ip route"

# Expected output:
# Codes: K - kernel route, C - connected, S - static, R - RIP,
#        O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
#        T - Table, v - VNC, V - VNC-Direct, A - Babel, D - SHARP,
#        F - PBR, f - OpenFabric,
#        > - selected route, * - FIB route, q - queued, r - rejected, b - backup
# 
# S>* 0.0.0.0/0 [200/0] via 10.0.1.254, eth0, weight 1, 00:00:23
# C>* 10.0.1.0/24 is directly connected, eth0, 00:00:23
# C>* 10.0.2.0/24 is directly connected, eth1, 00:00:23
# C>* 10.0.3.0/24 is directly connected, eth2, 00:00:23
# C>* 10.0.4.0/24 is directly connected, eth3, 00:00:23
# C>* 10.0.5.0/24 is directly connected, eth4, 00:00:23
# S>* 192.168.100.0/24 [100/0] via 10.0.2.2, eth1, weight 1, 00:00:23
#  *                         via 10.0.3.2, eth2, weight 1, 00:00:23
#  *                         via 10.0.4.2, eth3, weight 1, 00:00:23
#  *                         via 10.0.5.2, eth4, weight 1, 00:00:23
```

**Verification Criteria:**
- 4 equal-cost routes to 192.168.100.0/24
- All routes have metric 100
- All routes are marked with `*` (FIB route)
- All routes are marked with `>` (selected route)

#### Verify Core Router Routing Tables

```bash
# Check core router (r2) routing table
docker exec clab-ecmp-test-r2 vtysh -c "show ip route"

# Expected output:
# C>* 10.0.2.0/24 is directly connected, eth0, 00:00:23
# C>* 10.0.6.0/24 is directly connected, eth1, 00:00:23
# S>* 10.0.1.0/24 [100/0] via 10.0.2.1, eth0, weight 1, 00:00:23
# S>* 192.168.100.0/24 [100/0] via 10.0.6.2, eth1, weight 1, 00:00:23
```

### Step 5: Network Statistics Verification

#### Check Interface Statistics

```bash
# Check edge router interface statistics
docker exec clab-ecmp-test-r1 ip -s link show

# Expected output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT
#     RX: bytes  packets  errors  dropped overrun mcast
#     0          0        0       0       0       0
#     TX: bytes  packets  errors  dropped carrier collsns
#     0          0        0       0       0       0
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT
#     RX: bytes  packets  errors  dropped overrun mcast
#     1234       15       0       0       0       0
#     TX: bytes  packets  errors  dropped carrier collsns
#     5678       20       0       0       0       0
```

**Verification Criteria:**
- No interface errors
- No dropped packets
- No overruns
- Packets are being transmitted and received

---

## ECMP Configuration Verification

### Verification Overview

ECMP configuration verification ensures that the ECMP routing is correctly configured with the Source IP hash algorithm.

### Step 1: ECMP Route Verification

#### Verify Equal-Cost Routes

```bash
# Check ECMP routes on edge router
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Expected output:
# Routing entry for 192.168.100.0/24
#   Known via "static", distance 100, metric 100, weight 1
#   * 10.0.2.2, via eth1, weight 1, 00:00:23
#   * 10.0.3.2, via eth2, weight 1, 00:00:23
#   * 10.0.4.2, via eth3, weight 1, 00:00:23
#   * 10.0.5.2, via eth4, weight 1, 00:00:23
```

**Verification Criteria:**
- 4 equal-cost routes present
- All routes have same metric (100)
- All routes have same weight (1)
- All routes are marked with `*` (active)

#### Verify Route Details

```bash
# Check detailed route information
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24 detail"

# Expected output:
# Routing entry for 192.168.100.0/24
#   Known via "static", distance 100, metric 100, weight 1
#   Last update 00:00:23 ago
#   * 10.0.2.2, via eth1, weight 1, 00:00:23
#       Last update 00:00:23 ago
#   * 10.0.3.2, via eth2, weight 1, 00:00:23
#       Last update 00:00:23 ago
#   * 10.0.4.2, via eth3, weight 1, 00:00:23
#       Last update 00:00:23 ago
#   * 10.0.5.2, via eth4, weight 1, 00:00:23
#       Last update 00:00:23 ago
```

### Step 2: Kernel ECMP Hash Policy Verification

#### Verify Hash Policy Configuration

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

#### Verify All ECMP Kernel Parameters

```bash
# Check all ECMP-related kernel parameters
docker exec clab-ecmp-test-r1 sysctl -a | grep fib_multipath

# Expected output:
# net.ipv4.fib_multipath_hash_policy = 1
# net.ipv4.fib_multipath_use_permanent_addr = 1
# net.ipv4.fib_multipath_secret_length = 0
```

**Verification Criteria:**
- `fib_multipath_hash_policy = 1` (Source IP only)
- `fib_multipath_use_permanent_addr = 1` (Use permanent address)
- `fib_multipath_secret_length = 0` (No secret)

### Step 3: FRR Daemon Verification

#### Verify FRR Daemons

```bash
# Check FRR daemon status
docker exec clab-ecmp-test-r1 vtysh -c "show daemons"

# Expected output:
# Daemon    PID  Status
# --------  ---  ------
# zebra     123  Running
# ospfd     456  Running
```

**Verification Criteria:**
- zebra daemon is running
- ospfd daemon is running
- No daemon errors

#### Verify FRR Version

```bash
# Check FRR version
docker exec clab-ecmp-test-r1 vtysh -c "show version"

# Expected output:
# FRRouting 8.4_git (MyHost).
# Copyright 1996-2023 FRRouting project
# GNU Zebra 8.4_git
# GNU OSPFd 8.4_git
```

### Step 4: OSPF Configuration Verification

#### Verify OSPF Neighbors

```bash
# Check OSPF neighbors
docker exec clab-ecmp-test-r1 vtysh -c "show ip ospf neighbor"

# Expected output:
# Neighbor ID     Pri State           Dead Time Address         Interface            RXmtL RqstL DBsmL
# 10.0.2.1          1 Full/DR          00:00:39 10.0.2.2        eth1                 0     0     0
# 10.0.3.1          1 Full/DR          00:00:39 10.0.3.2        eth2                 0     0     0
# 10.0.4.1          1 Full/DR          00:00:39 10.0.4.2        eth3                 0     0     0
# 10.0.5.1          1 Full/DR          00:00:39 10.0.5.2        eth4                 0     0     0
```

**Verification Criteria:**
- 4 OSPF neighbors (r2-r5)
- All neighbors in Full state
- All neighbors are DR (Designated Router)

#### Verify OSPF Routes

```bash
# Check OSPF routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip ospf route"

# Expected output:
# ============ OSPF network routing table ============
# N    10.0.1.0/24        [10] area: 0.0.0.0
#                        directly attached to eth0
# N    10.0.2.0/24        [10] area: 0.0.0.0
#                        directly attached to eth1
# N    10.0.3.0/24        [10] area: 0.0.0.0
#                        directly attached to eth2
# N    10.0.4.0/24        [10] area: 0.0.0.0
#                        directly attached to eth3
# N    10.0.5.0/24        [10] area: 0.0.0.0
#                        directly attached to eth4
```

### Step 5: ECMP Status Display

#### Use Status Command

```bash
# Show ECMP status
./scripts/configure_ecmp.sh --status

# Expected output:
# [INFO] ECMP Configuration Status
# [INFO] ========================
# [INFO] Edge Router (r1):
# [INFO]   ECMP Routes: 4
# [INFO]   Hash Policy: Source IP only (1)
# [INFO]   Route Metrics: 100
# [INFO] Core Routers (r2-r5):
# [INFO]   Static Routes: Configured
# [INFO]   OSPF Neighbors: 4
# [INFO] Destination Router (r6):
# [INFO]   ECMP Routes: 4
# [INFO]   Hash Policy: Source IP only (1)
# [SUCCESS] ECMP configuration is valid
```

---

## Test Result Interpretation

### Verification Overview

Test result interpretation involves understanding the output from traffic capture, analysis, and reporting components.

### Step 1: Traffic Capture Verification

#### Verify Capture Files

```bash
# List capture files
ls -lh results/captures/

# Expected output:
# -rw-r--r-- 1 user user 1.2M Mar  5 14:30 ecmp-test_path1_20240305_143022.pcap
# -rw-r--r-- 1 user user 1.2M Mar  5 14:30 ecmp-test_path2_20240305_143022.pcap
# -rw-r--r-- 1 user user 1.2M Mar  5 14:30 ecmp-test_path3_20240305_143022.pcap
# -rw-r--r-- 1 user user 1.2M Mar  5 14:30 ecmp-test_path4_20240305_143022.pcap
```

**Verification Criteria:**
- 4 capture files present (one per path)
- File sizes are similar (indicates even distribution)
- Files are not empty

#### Analyze Capture Files

```bash
# Count packets in each capture file
tcpdump -r results/captures/ecmp-test_path1_20240305_143022.pcap | wc -l
tcpdump -r results/captures/ecmp-test_path2_20240305_143022.pcap | wc -l
tcpdump -r results/captures/ecmp-test_path3_20240305_143022.pcap | wc -l
tcpdump -r results/captures/ecmp-test_path4_20240305_143022.pcap | wc -l

# Expected output:
# 250
# 250
# 250
# 250
```

**Verification Criteria:**
- Each path has approximately equal packet count
- Total packets = 4 × packets per path
- No path has 0 packets

#### View Capture File Details

```bash
# View capture file summary
tcpdump -r results/captures/ecmp-test_path1_20240305_143022.pcap -nn -c 10

# Expected output:
# reading from file results/captures/ecmp-test_path1_20240305_143022.pcap, link-type EN10MB (Ethernet)
# 14:30:22.123456 IP 10.0.1.10 > 192.168.100.10: ICMP echo request, id 1234, seq 1, length 64
# 14:30:22.234567 IP 10.0.1.11 > 192.168.100.10: ICMP echo request, id 1235, seq 1, length 64
# 14:30:22.345678 IP 10.0.1.12 > 192.168.100.10: ICMP echo request, id 1236, seq 1, length 64
# 14:30:22.456789 IP 10.0.1.13 > 192.168.100.10: ICMP echo request, id 1237, seq 1, length 64
# ...
```

### Step 2: Analysis Output Interpretation

#### Understand Analysis Output

```bash
# Run analysis
./scripts/analyze_results.sh

# Expected output:
# [INFO] Analyzing ECMP test results...
# [INFO] Parsing capture files...
# [INFO] Path 1 (r2): 250 packets (25.0%)
# [INFO] Path 2 (r3): 250 packets (25.0%)
# [INFO] Path 3 (r4): 250 packets (25.0%)
# [INFO] Path 4 (r5): 250 packets (25.0%)
# [INFO] Total packets: 1000
# [INFO] Calculating statistical metrics...
# [INFO] Expected per path: 250 packets (25.0%)
# [INFO] Actual per path: 250 packets (25.0%)
# [INFO] Deviation: 0.0%
# [INFO] Chi-square test: χ² = 0.00, df = 3, p-value = 1.00
# [INFO] Distribution is uniform (p > 0.05)
# [INFO] Entropy: 2.00 bits (maximum: 2.00 bits)
# [INFO] Hash quality: Excellent
# [SUCCESS] Analysis completed
```

**Output Interpretation:**

| Metric | Meaning | Good Value |
|--------|---------|------------|
| Packets per path | Number of packets on each ECMP path | ~25% of total |
| Deviation | Deviation from expected distribution | < 5% |
| Chi-square (χ²) | Statistical test for uniformity | Low value |
| p-value | Probability of observing this distribution | > 0.05 |
| Entropy | Measure of randomness | Close to maximum |
| Hash quality | Overall assessment of hash distribution | Excellent/Good |

#### Statistical Test Interpretation

**Chi-Square Test:**
- **Null Hypothesis (H₀)**: Distribution is uniform
- **Alternative Hypothesis (H₁)**: Distribution is not uniform
- **Decision Rule**: Reject H₀ if p-value < 0.05

**Interpretation:**
- p-value > 0.05: Distribution is uniform (pass)
- p-value < 0.05: Distribution is not uniform (fail)

**Example:**
```
Chi-square test: χ² = 0.00, df = 3, p-value = 1.00
```
- χ² = 0.00: Perfect uniformity
- df = 3: Degrees of freedom (4 paths - 1)
- p-value = 1.00: 100% probability of uniform distribution

**Reference:** https://en.wikipedia.org/wiki/Chi-squared_test

### Step 3: Result File Verification

#### Check Analysis Results

```bash
# View analysis results file
cat results/analysis/ecmp-test-20240305-143022-basic/analysis.json

# Expected output:
# {
#   "test_name": "ecmp-test-20240305-143022-basic",
#   "timestamp": "2024-03-05T14:30:22Z",
#   "scenario": "basic_distribution",
#   "total_packets": 1000,
#   "paths": {
#     "path1": {
#       "router": "r2",
#       "packets": 250,
#       "percentage": 25.0
#     },
#     "path2": {
#       "router": "r3",
#       "packets": 250,
#       "percentage": 25.0
#     },
#     "path3": {
#       "router": "r4",
#       "packets": 250,
#       "percentage": 25.0
#     },
#     "path4": {
#       "router": "r5",
#       "packets": 250,
#       "percentage": 25.0
#     }
#   },
#   "statistics": {
#     "expected_per_path": 250,
#     "deviation": 0.0,
#     "chi_square": 0.0,
#     "degrees_of_freedom": 3,
#     "p_value": 1.0,
#     "entropy": 2.0,
#     "max_entropy": 2.0,
#     "hash_quality": "Excellent"
#   },
#   "result": "PASS"
# }
```

#### Check Summary Report

```bash
# View summary report
cat results/reports/ecmp-test-20240305-143022-basic/summary.txt

# Expected output:
# ECMP Test Summary Report
# ========================
# Test Name: ecmp-test-20240305-143022-basic
# Timestamp: 2024-03-05 14:30:22 UTC
# Scenario: basic_distribution
# 
# Traffic Distribution:
#   Path 1 (r2): 250 packets (25.0%)
#   Path 2 (r3): 250 packets (25.0%)
#   Path 3 (r4): 250 packets (25.0%)
#   Path 4 (r5): 250 packets (25.0%)
#   Total: 1000 packets
# 
# Statistical Analysis:
#   Expected per path: 250 packets (25.0%)
#   Deviation: 0.0%
#   Chi-square: 0.00 (df=3)
#   p-value: 1.00
#   Entropy: 2.00 bits (max: 2.00 bits)
#   Hash Quality: Excellent
# 
# Result: PASS
```

---

## Allure Report Reading

### Verification Overview

Allure reports provide comprehensive visualization of test results with detailed metrics and trends.

### Step 1: Generate Allure Report

```bash
# Generate Allure report
./scripts/generate_allure_report.sh

# Expected output:
# [INFO] Generating Allure report...
# [INFO] Parsing test results...
# [INFO] Generating statistical analysis...
# [INFO] Creating visualizations...
# [SUCCESS] Report generated
# [INFO] Open report: allure open results/allure-results
```

### Step 2: Open Allure Report

```bash
# Open report in browser
allure open results/allure-results

# Or serve report on HTTP server
allure serve results/allure-results
```

### Step 3: Navigate Allure Report

#### Dashboard Overview

The Allure dashboard provides:

1. **Test Execution Status**
   - Total tests: Number of test suites executed
   - Passed: Tests that passed
   - Failed: Tests that failed
   - Broken: Tests with errors
   - Skipped: Tests that were skipped

2. **Test Duration**
   - Total time: Overall test execution time
   - Min time: Fastest test
   - Max time: Slowest test
   - Avg time: Average test duration

3. **Test Trends**
   - History of test results over time
   - Pass/fail trends
   - Performance trends

#### Test Suite Details

Click on a test suite to view:

1. **Test Case Details**
   - Test name and description
   - Execution time
   - Test status (passed/failed/broken)
   - Test steps and logs

2. **Parameters**
   - Test scenario
   - Duration
   - Packet count
   - Configuration

3. **Attachments**
   - Capture files
   - Analysis results
   - Statistical reports
   - Screenshots (if applicable)

#### Statistical Analysis Section

The Allure report includes:

1. **Distribution Chart**
   - Bar chart showing packet distribution per path
   - Expected vs actual distribution
   - Deviation from expected

2. **Statistical Metrics**
   - Chi-square test results
   - p-value
   - Entropy
   - Hash quality assessment

3. **Trend Analysis**
   - Historical distribution trends
   - Performance over time
   - Comparison with previous runs

### Step 4: Interpret Allure Report

#### Understanding Test Status

| Status | Meaning | Action |
|--------|---------|--------|
| ✅ Passed | Test passed all criteria | No action needed |
| ❌ Failed | Test failed one or more criteria | Investigate failure |
| ⚠️ Broken | Test encountered an error | Check logs and environment |
| ⏭️ Skipped | Test was not executed | Check test configuration |

#### Understanding Statistical Metrics

**Chi-Square Test:**
- **Low χ² value**: Good uniformity
- **High χ² value**: Poor uniformity
- **p-value > 0.05**: Distribution is uniform
- **p-value < 0.05**: Distribution is not uniform

**Entropy:**
- **Close to maximum**: Good randomness
- **Far from maximum**: Poor randomness
- **Maximum for 4 paths**: 2.00 bits

**Hash Quality:**
- **Excellent**: Perfect or near-perfect distribution
- **Good**: Acceptable distribution with minor deviations
- **Fair**: Distribution with noticeable deviations
- **Poor**: Uneven distribution requiring investigation

#### Understanding Trends

**Pass Rate Trend:**
- **Increasing**: Improving test stability
- **Decreasing**: Potential issues with test or system
- **Stable**: Consistent test behavior

**Performance Trend:**
- **Increasing**: Slower execution (potential issue)
- **Decreasing**: Faster execution (improvement)
- **Stable**: Consistent performance

**Distribution Trend:**
- **Stable**: Consistent hash behavior
- **Variable**: Potential configuration or system issues

### Step 5: Export Allure Report

```bash
# Generate static HTML report
allure generate results/allure-results --clean

# Export report to specific directory
allure generate results/allure-results -o results/allure-report --clean

# Open static report
open results/allure-report/index.html
```

---

## Statistical Analysis Validation

### Verification Overview

Statistical analysis validation ensures that the statistical tests are correctly applied and interpreted.

### Step 1: Validate Chi-Square Test

#### Understand Chi-Square Test

The chi-square test evaluates whether the observed distribution matches the expected uniform distribution.

**Formula:**
```
χ² = Σ (Oᵢ - Eᵢ)² / Eᵢ
```

Where:
- Oᵢ = Observed count for path i
- Eᵢ = Expected count for path i
- Σ = Sum over all paths

**Example Calculation:**
```
Observed: [250, 250, 250, 250]
Expected: [250, 250, 250, 250]

χ² = (250-250)²/250 + (250-250)²/250 + (250-250)²/250 + (250-250)²/250
χ² = 0 + 0 + 0 + 0
χ² = 0.00
```

**Degrees of Freedom:**
```
df = number of paths - 1
df = 4 - 1 = 3
```

**p-value:**
- Use chi-square distribution table or calculator
- For χ² = 0.00, df = 3: p-value = 1.00

**Reference:** https://en.wikipedia.org/wiki/Chi-squared_test

#### Validate Chi-Square Results

```bash
# View chi-square calculation details
cat results/analysis/ecmp-test-20240305-143022-basic/statistics.json

# Expected output:
# {
#   "chi_square": {
#     "value": 0.0,
#     "degrees_of_freedom": 3,
#     "p_value": 1.0,
#     "critical_value": 7.815,
#     "alpha": 0.05,
#     "result": "PASS"
#   }
# }
```

**Verification Criteria:**
- χ² value < critical value (7.815 for α=0.05, df=3)
- p-value > 0.05
- Result = PASS

### Step 2: Validate Entropy Calculation

#### Understand Entropy

Entropy measures the randomness of the distribution.

**Formula:**
```
H = -Σ pᵢ × log₂(pᵢ)
```

Where:
- pᵢ = Probability of path i (packets on path i / total packets)
- log₂ = Base-2 logarithm

**Example Calculation:**
```
Distribution: [250, 250, 250, 250]
Probabilities: [0.25, 0.25, 0.25, 0.25]

H = -0.25 × log₂(0.25) - 0.25 × log₂(0.25) - 0.25 × log₂(0.25) - 0.25 × log₂(0.25)
H = -0.25 × (-2) - 0.25 × (-2) - 0.25 × (-2) - 0.25 × (-2)
H = 0.5 + 0.5 + 0.5 + 0.5
H = 2.00 bits
```

**Maximum Entropy:**
```
H_max = log₂(number of paths)
H_max = log₂(4) = 2.00 bits
```

**Reference:** https://en.wikipedia.org/wiki/Entropy_(information_theory)

#### Validate Entropy Results

```bash
# View entropy calculation details
cat results/analysis/ecmp-test-20240305-143022-basic/entropy.json

# Expected output:
# {
#   "entropy": {
#     "value": 2.0,
#     "max_value": 2.0,
#     "ratio": 1.0,
#     "result": "Excellent"
#   }
# }
```

**Verification Criteria:**
- Entropy close to maximum (≥ 0.9 × max)
- Ratio ≥ 0.9
- Result = Excellent or Good

### Step 3: Validate Distribution Uniformity

#### Understand Uniform Distribution

A uniform distribution means each path receives approximately the same number of packets.

**Expected Distribution:**
```
Expected per path = Total packets / Number of paths
Expected per path = 1000 / 4 = 250 packets
```

**Acceptable Deviation:**
```
Acceptable deviation = ±5% of expected
Acceptable deviation = ±5% × 250 = ±12.5 packets
Acceptable range = 237.5 to 262.5 packets
```

#### Validate Distribution Results

```bash
# View distribution details
cat results/analysis/ecmp-test-20240305-143022-basic/distribution.json

# Expected output:
# {
#   "distribution": {
#     "total_packets": 1000,
#     "number_of_paths": 4,
#     "expected_per_path": 250,
#     "actual_per_path": [250, 250, 250, 250],
#     "deviation": [0.0, 0.0, 0.0, 0.0],
#     "max_deviation": 0.0,
#   "acceptable_deviation": 12.5,
#     "result": "PASS"
#   }
# }
```

**Verification Criteria:**
- All paths within acceptable range
- Max deviation ≤ acceptable deviation
- Result = PASS

### Step 4: Validate Statistical Significance

#### Understand Statistical Significance

Statistical significance determines whether the results are reliable and not due to chance.

**Sample Size Requirements:**
- Minimum: 100 packets per path
- Recommended: 1000 packets per path
- Ideal: 10000 packets per path

**Confidence Level:**
- 95% confidence level (α = 0.05)
- 99% confidence level (α = 0.01)

**Reference:** RFC 2330 - Framework for IP Performance Metrics

#### Validate Sample Size

```bash
# View sample size details
cat results/analysis/ecmp-test-20240305-143022-basic/sample_size.json

# Expected output:
# {
#   "sample_size": {
#     "total_packets": 1000,
#     "packets_per_path": [250, 250, 250, 250],
#     "minimum_required": 100,
#     "recommended": 1000,
#     "result": "PASS"
#   }
# }
```

**Verification Criteria:**
- Packets per path ≥ minimum required
- Packets per path ≥ recommended (optional)
- Result = PASS

---

## Common Failure Scenarios

### Scenario 1: Uneven Distribution

**Symptoms:**
```
[INFO] Path 1: 400 packets (40.0%)
[INFO] Path 2: 200 packets (20.0%)
[INFO] Path 3: 200 packets (20.0%)
[INFO] Path 4: 200 packets (20.0%)
[INFO] Chi-square test: χ² = 200.00, df = 3, p-value = 0.00
[INFO] Distribution is not uniform (p < 0.05)
```

**Possible Causes:**
1. ECMP hash policy not set to Source IP only
2. Route metrics not equal
3. Kernel ECMP configuration incorrect
4. Network interface issues

**Troubleshooting Steps:**
```bash
# 1. Verify ECMP hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# 2. Verify route metrics
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24 detail"

# 3. Reset hash policy
docker exec clab-ecmp-test-r1 sysctl -w net.ipv4.fib_multipath_hash_policy=1

# 4. Reconfigure ECMP
./scripts/configure_ecmp.sh
```

### Scenario 2: No Packets Captured

**Symptoms:**
```
[INFO] Path 1: 0 packets (0.0%)
[INFO] Path 2: 0 packets (0.0%)
[INFO] Path 3: 0 packets (0.0%)
[INFO] Path 4: 0 packets (0.0%)
```

**Possible Causes:**
1. tcpdump not installed in containers
2. Capture filters too restrictive
3. Traffic generation failed
4. Network connectivity issues

**Troubleshooting Steps:**
```bash
# 1. Check tcpdump installation
docker exec clab-ecmp-test-r2 which tcpdump

# 2. Install tcpdump
docker exec clab-ecmp-test-r2 apt-get install -y tcpdump

# 3. Test capture manually
docker exec clab-ecmp-test-r2 tcpdump -i eth1 -c 10

# 4. Verify traffic generation
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10
```

### Scenario 3: All Packets on Single Path

**Symptoms:**
```
[INFO] Path 1: 1000 packets (100.0%)
[INFO] Path 2: 0 packets (0.0%)
[INFO] Path 3: 0 packets (0.0%)
[INFO] Path 4: 0 packets (0.0%)
```

**Possible Causes:**
1. ECMP not configured
2. Only one route active
3. Source IP not varying
4. Hash algorithm not working

**Troubleshooting Steps:**
```bash
# 1. Verify ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# 2. Verify hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# 3. Check source IPs
docker exec clab-ecmp-test-h1 ip addr show

# 4. Reconfigure ECMP
./scripts/configure_ecmp.sh
```

### Scenario 4: High Packet Loss

**Symptoms:**
```
[INFO] Total packets sent: 1000
[INFO] Total packets captured: 800
[INFO] Packet loss: 20.0%
```

**Possible Causes:**
1. Network congestion
2. Buffer overflow
3. Interface errors
4. Capture timing issues

**Troubleshooting Steps:**
```bash
# 1. Check interface statistics
docker exec clab-ecmp-test-r1 ip -s link show

# 2. Check for errors
docker exec clab-ecmp-test-r1 dmesg | grep -i error

# 3. Increase capture buffer
docker exec clab-ecmp-test-r2 tcpdump -i eth1 -B 4096 -w /tmp/capture.pcap

# 4. Reduce traffic rate
./scripts/run_test.sh --duration 60 --count 500
```

### Scenario 5: Statistical Test Failure

**Symptoms:**
```
[INFO] Chi-square test: χ² = 15.00, df = 3, p-value = 0.002
[INFO] Distribution is not uniform (p < 0.05)
```

**Possible Causes:**
1. Small sample size
2. Random variation
3. Configuration issue
4. System instability

**Troubleshooting Steps:**
```bash
# 1. Increase sample size
./scripts/run_test.sh --count 10000

# 2. Run multiple tests
for i in {1..5}; do ./scripts/run_test.sh; done

# 3. Check system stability
docker stats --no-stream

# 4. Review logs
cat logs/test_execution.log
```

---

## Troubleshooting Verification Issues

### General Troubleshooting Approach

1. **Identify the Issue**
   - Review error messages
   - Check logs
   - Examine output

2. **Isolate the Problem**
   - Test individual components
   - Verify configurations
   - Check dependencies

3. **Apply Solution**
   - Follow troubleshooting steps
   - Apply fixes
   - Verify resolution

4. **Document Findings**
   - Record issue and solution
   - Update documentation
   - Share with team

### Verification Checklist

Use this checklist to verify all components:

- [ ] All containers running
- [ ] All interfaces UP
- [ ] Network connectivity working
- [ ] ECMP routes configured
- [ ] Hash policy set to Source IP only
- [ ] Traffic captured on all paths
- [ ] Distribution uniform
- [ ] Statistical tests pass
- [ ] Allure report generated
- [ ] Results documented

### Getting Help

If you encounter issues not covered here:

1. Check the [Launch Instruction](LAUNCH_INSTRUCTION.md) for deployment issues
2. Review the [Architecture Design](../ARCHITECTURE.md) for system overview
3. Consult the [API Reference](API_REFERENCE.md) for script details
4. Check official documentation:
   - [Containerlab](https://containerlab.dev/)
   - [FRRouting](https://docs.frrouting.org/)
   - [tcpdump](https://www.tcpdump.org/)
   - [Allure](https://docs.qameta.io/allure/)

---

## Best Practices

### Verification Best Practices

1. **Verify Before Testing**
   - Always verify topology before running tests
   - Check ECMP configuration
   - Test connectivity

2. **Use Automated Verification**
   - Use helper scripts for verification
   - Automate verification in CI/CD
   - Log verification results

3. **Document Verification Results**
   - Save verification logs
   - Record configuration states
   - Track changes over time

4. **Validate Statistical Results**
   - Understand statistical tests
   - Verify calculations
   - Interpret results correctly

5. **Review Allure Reports**
   - Check test status
   - Review trends
   - Investigate failures

### Interpretation Best Practices

1. **Understand the Context**
   - Consider test scenario
   - Review configuration
   - Check system state

2. **Look for Patterns**
   - Identify trends
   - Spot anomalies
   - Correlate events

3. **Use Multiple Metrics**
   - Don't rely on single metric
   - Combine metrics for insight
   - Cross-validate results

4. **Compare with Baselines**
   - Compare with previous runs
   - Compare with expected values
   - Identify deviations

5. **Investigate Failures**
   - Understand root cause
   - Apply appropriate fix
   - Verify resolution

---

## References

### Statistical References

- **Chi-Square Test**: https://en.wikipedia.org/wiki/Chi-squared_test
- **Entropy**: https://en.wikipedia.org/wiki/Entropy_(information_theory)
- **Statistical Significance**: https://en.wikipedia.org/wiki/Statistical_significance
- **RFC 2330**: Framework for IP Performance Metrics
  - https://tools.ietf.org/html/rfc2330

### Tool References

- **tcpdump**: https://www.tcpdump.org/
- **Allure**: https://docs.qameta.io/allure/
- **FRRouting**: https://docs.frrouting.org/

### Project Documentation

- [Launch Instruction](LAUNCH_INSTRUCTION.md)
- [Architecture Design](../ARCHITECTURE.md)
- [Test Plan](TEST_PLAN.md)
- [Test Report Template](TEST_REPORT_TEMPLATE.md)
- [API Reference](API_REFERENCE.md)

---

## Appendix

### A. Verification Commands Quick Reference

```bash
# Container status
docker ps | grep clab-ecmp-test

# Interface status
docker exec clab-ecmp-test-r1 ip addr show

# Connectivity test
docker exec clab-ecmp-test-h1 ping -c 3 192.168.100.10

# ECMP routes
docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24"

# Hash policy
docker exec clab-ecmp-test-r1 sysctl net.ipv4.fib_multipath_hash_policy

# Capture files
ls -lh results/captures/

# Analysis
./scripts/analyze_results.sh

# Allure report
allure open results/allure-results
```

### B. Statistical Test Interpretation Guide

| Test | Good Result | Bad Result | Action |
|------|-------------|------------|--------|
| Chi-square | p-value > 0.05 | p-value < 0.05 | Investigate distribution |
| Entropy | ≥ 0.9 × max | < 0.9 × max | Check hash quality |
| Distribution | Deviation < 5% | Deviation ≥ 5% | Verify ECMP config |
| Sample size | ≥ 1000 packets | < 1000 packets | Increase sample size |

### C. Common Error Messages and Solutions

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "Container not found" | Container not running | Deploy topology |
| "vtysh: command not found" | FRR not installed | Install FRR |
| "tcpdump: command not found" | tcpdump not installed | Install tcpdump |
| "No packets captured" | Capture failed | Check tcpdump and filters |
| "Distribution not uniform" | ECMP misconfigured | Verify hash policy |

---

**Document Version:** 1.0  
**Last Updated:** 2024-03-05  
**Maintainer:** ECMP Testing Team
