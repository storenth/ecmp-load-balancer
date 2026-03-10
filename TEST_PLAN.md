# ECMP Hash Testing - Test Plan

**Document Version:** 1.0  
**Date:** 2026-03-10  
**Standard:** ISO/IEC/IEEE 29119-3  
**Project:** ECMP Hash Testing Methodology

---

## 1. Introduction

### 1.1 Purpose

This test plan defines the methodology for verifying the correct operation of ECMP (Equal-Cost Multi-Path) routing with hash-based path selection using Source IP addresses. The plan ensures systematic testing according to ISO/IEC/IEEE 29119-3 standards.

### 1.2 Scope

This test plan covers:
- Static ECMP topology setup using Linux network namespaces
- Traffic generation from multiple source IPs
- Traffic capture on ECMP paths
- Analysis of hash-based path distribution
- Verification of RFC 2991 and RFC 2992 compliance

### 1.3 References

- **ISO/IEC/IEEE 29119-3**: Software and systems engineering — Software testing — Part 3: Test documentation
- **RFC 2991**: Multipath Issues in Unicast and Multicast Next-Hop Selection
- **RFC 2992**: Analysis of an Equal-Cost Multi-Path Algorithm
- **RFC 2544**: Benchmarking Methodology for Network Interconnect Devices
- **RFC 2330**: Framework for IP Performance Metrics

---

## 2. Test Items

### 2.1 System Under Test (SUT)

**Component:** Linux Kernel ECMP Routing Implementation  
**Version:** Linux Kernel 3.0+  
**Feature:** Static ECMP routing with hash-based path selection

### 2.2 Test Environment

**Hardware:** Any Linux system with network namespace support  
**Software:**
- Linux Kernel 3.0+
- iproute2 (ip command)
- tcpdump
- tshark
- ping
- bc

**Network Topology:**
```
Source1 (192.168.1.10) ──┐
                           ├── Router (192.168.1.1/192.168.10.1) ──┬── Path 1 (192.168.2.0/24) ──┐
Source2 (192.168.10.10) ──┘                              └── Path 2 (192.168.3.0/24) ──┼── Dest (192.168.4.10)
```

---

## 3. Test Strategy

### 3.1 Test Approach

**Method:** Black-box testing with traffic capture and analysis  
**Type:** Functional testing  
**Level:** System testing  

### 3.2 Test Types

1. **Functional Testing**: Verify ECMP routes traffic correctly
2. **Consistency Testing**: Verify hash consistency for same source IP
3. **Distribution Testing**: Verify traffic distribution across paths
4. **Compliance Testing**: Verify RFC 2991/2992 compliance

### 3.3 Test Coverage

- ECMP route configuration
- Hash-based path selection
- Source IP consistency
- Traffic distribution
- Packet forwarding correctness

---

## 4. Test Deliverables

### 4.1 Test Scripts

1. [`setup_topology.sh`](setup_topology.sh) - Topology setup script
2. [`generate_traffic.sh`](generate_traffic.sh) - Traffic generation script
3. [`capture_traffic.sh`](capture_traffic.sh) - Traffic capture script
4. [`analyze_results.sh`](analyze_results.sh) - Results analysis script
5. [`cleanup.sh`](cleanup.sh) - Cleanup script

### 4.2 Test Artifacts

1. PCAP capture files (path1_capture.pcap, path2_capture.pcap)
2. Traffic logs (source1_ping.log, source2_ping.log)
3. Analysis results (path1_sources.txt, path2_sources.txt)
4. Test execution report

---

## 5. Test Cases

### 5.1 TC-001: Topology Setup Verification

**Objective:** Verify network topology is correctly configured

**Preconditions:**
- Linux system with root privileges
- All required tools installed

**Test Steps:**
1. Execute `sudo ./setup_topology.sh`
2. Verify namespaces exist: `ip netns list`
3. Verify interfaces in router namespace: `ip netns exec router ip addr show`
4. Verify ECMP route: `ip netns exec router ip route show`

**Expected Results:**
- Namespaces: source1, source2, router, dest exist
- Router has interfaces: veth_r_s1, veth_r_s2, veth_r_d1, veth_r_d2
- ECMP route to 192.168.4.0/24 with 2 nexthops exists

**Priority:** High

---

### 5.2 TC-002: Basic Connectivity Test

**Objective:** Verify end-to-end connectivity

**Preconditions:**
- Topology setup complete (TC-001 passed)

**Test Steps:**
1. Ping from source1 to destination: `ip netns exec source1 ping -c 3 192.168.4.10`
2. Ping from source2 to destination: `ip netns exec source2 ping -c 3 192.168.4.10`

**Expected Results:**
- All pings succeed (0% packet loss)
- Round-trip times are reasonable (< 10ms)

**Priority:** High

---

### 5.3 TC-003: ECMP Hash Consistency Test

**Objective:** Verify same source IP consistently uses same path

**Preconditions:**
- Topology setup complete
- Connectivity verified (TC-002 passed)

**Test Steps:**
1. Start traffic capture: `sudo ./capture_traffic.sh`
2. Generate traffic: `sudo ./generate_traffic.sh`
3. Wait for capture to complete
4. Analyze results: `sudo ./analyze_results.sh`

**Expected Results:**
- Source 192.168.1.10 appears in only one path
- Source 192.168.10.10 appears in only one path
- No source IP appears in both paths

**Priority:** Critical

**Success Criteria:**
- Each source IP has 0 occurrences in one path
- Each source IP has > 0 occurrences in the other path

---

### 5.4 TC-004: ECMP Traffic Distribution Test

**Objective:** Verify traffic is distributed across ECMP paths

**Preconditions:**
- Topology setup complete
- Connectivity verified (TC-002 passed)

**Test Steps:**
1. Start traffic capture: `sudo ./capture_traffic.sh`
2. Generate traffic: `sudo ./generate_traffic.sh`
3. Wait for capture to complete
4. Analyze results: `sudo ./analyze_results.sh`

**Expected Results:**
- Different source IPs use different paths
- Traffic is distributed across both paths
- No single path receives all traffic

**Priority:** High

**Success Criteria:**
- At least one source IP uses Path 1
- At least one source IP uses Path 2
- Both paths have > 0 packets

---

### 5.5 TC-005: ECMP Route Configuration Test

**Objective:** Verify ECMP route is correctly configured with nexthop syntax

**Preconditions:**
- Topology setup complete

**Test Steps:**
1. Check ECMP route: `ip netns exec router ip route show 192.168.4.0/24`
2. Verify nexthop syntax
3. Verify weight configuration

**Expected Results:**
- Route shows 2 nexthops
- Both nexthops have weight 1
- Syntax matches: `nexthop via <IP> dev <interface> weight <value>`

**Priority:** High

---

### 5.6 TC-006: Packet Forwarding Correctness Test

**Objective:** Verify packets are correctly forwarded to destination

**Preconditions:**
- Topology setup complete
- Traffic captured

**Test Steps:**
1. Analyze path1 capture: `tshark -r results/path1_capture.pcap -T fields -e ip.src -e ip.dst`
2. Analyze path2 capture: `tshark -r results/path2_capture.pcap -T fields -e ip.src -e ip.dst`
3. Verify destination IP is correct

**Expected Results:**
- All packets have destination IP 192.168.4.10
- Source IPs are 192.168.1.10 or 192.168.10.10
- No packets with incorrect destination

**Priority:** High

---

## 6. Test Metrics

### 6.1 Quantitative Metrics

1. **Packet Loss Rate**: Should be 0%
2. **Path Consistency**: 100% (same source always uses same path)
3. **Distribution Balance**: Ideal 50/50, acceptable 40/60 to 60/40
4. **Hash Collision Rate**: Should be 0% (no source in both paths)

### 6.2 Qualitative Metrics

1. **RFC Compliance**: Adherence to RFC 2991 and RFC 2992
2. **Implementation Correctness**: Proper ECMP behavior
3. **Stability**: Consistent behavior across multiple test runs

---

## 7. Test Execution Schedule

### 7.1 Test Sequence

1. **Setup Phase**: Execute TC-001 (Topology Setup)
2. **Verification Phase**: Execute TC-002 (Connectivity)
3. **Functional Testing**: Execute TC-003, TC-004, TC-005, TC-006
4. **Analysis Phase**: Review results and metrics
5. **Cleanup Phase**: Execute cleanup script

### 7.2 Estimated Duration

- Setup: 1 minute
- Connectivity test: 1 minute
- Traffic generation: 30 seconds
- Traffic capture: 30 seconds
- Analysis: 1 minute
- **Total**: ~3-4 minutes per test run

---

## 8. Test Environment Setup

### 8.1 Prerequisites

```bash
# Check kernel version (must be 3.0+)
uname -r

# Check required tools
which ip tcpdump tshark ping bc

# Install missing tools if needed (Ubuntu/Debian)
sudo apt-get install iproute2 tcpdump tshark iputils-ping bc
```

### 8.2 Environment Verification

```bash
# Verify network namespace support
ip netns help

# Verify ECMP support
ip route help | grep -i multipath
```

---

## 9. Risk Assessment

### 9.1 Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Insufficient privileges | Low | High | Run with sudo |
| Missing tools | Low | Medium | Check prerequisites |
| Kernel doesn't support ECMP | Low | High | Verify kernel version |
| Network namespace conflicts | Low | Medium | Cleanup before setup |
| Hash collision (both sources same path) | Medium | Low | Acceptable behavior |

### 9.2 Contingency Plans

- If ECMP not supported: Document limitation and skip test
- If hash collision occurs: Add more source IPs for testing
- If tools missing: Provide installation instructions

---

## 10. Exit Criteria

### 10.1 Test Completion Criteria

All test cases must meet the following criteria:

1. **TC-001**: Topology setup successful
2. **TC-002**: 0% packet loss in connectivity test
3. **TC-003**: 100% path consistency (no source in both paths)
4. **TC-004**: Traffic distributed across both paths
5. **TC-005**: ECMP route correctly configured
6. **TC-006**: All packets forwarded to correct destination

### 10.2 Success Criteria

- All critical test cases pass
- At least 80% of high priority test cases pass
- No blocking issues identified
- RFC compliance verified

---

## 11. Test Reporting

### 11.1 Test Execution Report

The test execution report shall include:

1. Test environment details
2. Test case execution results
3. Metrics and measurements
4. Deviations from expected results
5. Analysis and conclusions
6. Recommendations

### 11.2 Test Summary

A summary report shall be provided to project management including:

- Overall test status (Pass/Fail)
- Key findings
- RFC compliance assessment
- Recommendations for production deployment

---

## 12. Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Test Lead | | | |
| Technical Lead | | | |
| Project Manager | | | |

---

## Appendix A: Test Data

### A.1 IP Addressing Scheme

| Component | Namespace | IP Address | Interface |
|-----------|-----------|------------|-----------|
| Source1 | source1 | 192.168.1.10/24 | veth_s1_r |
| Source2 | source2 | 192.168.10.10/24 | veth_s2_r |
| Router | router | 192.168.1.1/24 | veth_r_s1 |
| Router | router | 192.168.10.1/24 | veth_r_s2 |
| Router | router | 192.168.2.1/24 | veth_r_d1 (Path 1) |
| Router | router | 192.168.3.1/24 | veth_r_d2 (Path 2) |
| Dest | dest | 192.168.2.2/24 | veth_d1_r |
| Dest | dest | 192.168.3.2/24 | veth_d2_r |
| Dest | dest | 192.168.4.10/32 | lo (destination IP) |

### A.2 ECMP Route Configuration

```bash
ip route add 192.168.4.0/24 \
    nexthop via 192.168.2.2 dev veth_r_d1 weight 1 \
    nexthop via 192.168.3.2 dev veth_r_d2 weight 1
```

---

## Appendix B: Glossary

- **ECMP**: Equal-Cost Multi-Path routing
- **Hash**: Algorithm for path selection based on packet fields
- **Nexthop**: Next hop in routing path
- **Namespace**: Linux network isolation mechanism
- **PCAP**: Packet capture format
- **RFC**: Request for Comments (Internet standards)

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-10 | Initial | Initial test plan creation |
