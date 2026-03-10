# ECMP Hash Testing - Quick Start Guide

## Prerequisites

Ensure you have the following installed on your Linux system:

```bash
# Check kernel version (must be 3.0+)
uname -r

# Install required tools (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y iproute2 tcpdump tshark iputils-ping bc
```

## Quick Start (5 Minutes)

### Option 1: Using Makefile (Recommended)

```bash
# Run complete test cycle
make test

# Or verify connectivity only
make verify
```

### Option 2: Manual Steps

#### Step 1: Setup Topology

```bash
sudo ./setup_topology.sh
```

Expected output:
```
Creating network namespaces...
Creating veth pairs...
Configuring interfaces...
Configuring ECMP routes on router...

Topology setup complete!

  Network topology:
  Source1 (192.168.1.10) --> Router (192.168.1.1)
  Source2 (192.168.10.10) --> Router (192.168.10.1)
  Router --> Dest via two ECMP paths:
    Path 1: 192.168.2.1 --> 192.168.2.2
    Path 2: 192.168.3.1 --> 192.168.3.2
  Destination: 192.168.4.10
```

### Step 2: Verify Connectivity

```bash
# Test from source1
sudo ip netns exec source1 ping -c 3 192.168.4.10

# Test from source2
sudo ip netns exec source2 ping -c 3 192.168.4.10
```

Expected output: All pings succeed with 0% packet loss.

### Step 3: Capture Traffic

```bash
# Start capture (runs for 30 seconds, captures both paths simultaneously)
sudo ./capture_traffic.sh
```

This script:
- Captures traffic on both ECMP paths in parallel
- Filters for both ICMP and TCP protocols
- Saves captures to `results/path1_capture.pcap` and `results/path2_capture.pcap`

### Step 4: Generate Traffic

```bash
# Generate 100 ICMP packets and 10 TCP sessions from each source
sudo ./generate_traffic.sh
```

This script:
- Starts an HTTP server on the destination (192.168.4.10:80)
- Generates ICMP traffic using ping (100 packets per source)
- Generates TCP traffic using curl (10 HTTP sessions per source)
- Saves logs to `results/source1_report.log` and `results/source2_report.log`

### Step 5: Analyze Results

```bash
sudo ./analyze_results.sh
```

Expected output:
```
======================================================
📊 ECMP ADVANCED TRAFFIC ANALYSIS
======================================================
--- Traffic Distribution ---
Path 1: 210 pkts / 25200 bytes
Path 2: 210 pkts / 25200 bytes
Current Load Deviation: 0.00%

--- Validating L3 Consistency for 192.168.1.10 ---
✅ Source 192.168.1.10 is STICKY to path1_capture.pcap
Protocols detected for this IP:
    100 ICMP
    10 TCP

--- Validating L3 Consistency for 192.168.10.10 ---
✅ Source 192.168.10.10 is STICKY to path2_capture.pcap
Protocols detected for this IP:
    100 ICMP
    10 TCP

--- Path Diversity Check ---
✅ SUCCESS: Different Source IPs are using different ECMP paths.

======================================================
Analysis Complete.
```

### Step 6: Cleanup

```bash
sudo ./cleanup.sh
```

## Troubleshooting

### Issue: "Operation not permitted"

**Solution:** Run all commands with `sudo`

### Issue: "Network namespace not found"

**Solution:** Run `sudo ./cleanup.sh` first, then `sudo ./setup_topology.sh`

### Issue: "tcpdump: command not found"

**Solution:** Install tcpdump: `sudo apt-get install tcpdump`

### Issue: "tshark: command not found"

**Solution:** Install tshark: `sudo apt-get install tshark`

### Issue: Both sources use the same path

**Explanation:** This is expected behavior with only 2 source IPs. The ECMP hash may route both to the same path. Add more source IPs for better distribution.

## What's Happening?

1. **Topology Setup**: Creates 4 network namespaces (source1, source2, router, dest) connected via veth pairs
2. **ECMP Configuration**: Router has 2 equal-cost paths to destination network
3. **Simultaneous Capture**: [`capture_traffic.sh`](capture_traffic.sh) captures traffic on both ECMP paths in parallel
4. **Multi-Protocol Generation**: [`generate_traffic.sh`](generate_traffic.sh) generates both ICMP (ping) and TCP (HTTP) traffic
5. **Hash-Based Routing**: Linux kernel uses hash of source IP to select path
6. **L3 Consistency**: Both ICMP and TCP from the same source IP use the same path
7. **Advanced Analysis**: [`analyze_results.sh`](analyze_results.sh) validates L3 consistency, byte distribution, and protocol alignment

## Next Steps

- Read [`README.md`](README.md) for detailed documentation
- Review [`TEST_PLAN.md`](TEST_PLAN.md) for comprehensive test plan
- Use [`TEST_REPORT_TEMPLATE.md`](TEST_REPORT_TEMPLATE.md) to document results
- Modify [`generate_traffic.sh`](generate_traffic.sh) to test with more source IPs

## Key Files

| File | Purpose |
|------|---------|
| [`Makefile`](Makefile) | Convenient interface for all operations |
| [`setup_topology.sh`](setup_topology.sh) | Creates network topology |
| [`capture_traffic.sh`](capture_traffic.sh) | Captures traffic on both ECMP paths simultaneously (ICMP + TCP) |
| [`generate_traffic.sh`](generate_traffic.sh) | Generates ICMP and TCP traffic from both sources |
| [`analyze_results.sh`](analyze_results.sh) | Analyzes L3 consistency, byte distribution, and protocol alignment |
| [`cleanup.sh`](cleanup.sh) | Removes topology |

## Expected Results

When ECMP hash is working correctly:

✓ Each source IP consistently uses the same path
✓ Different source IPs use different paths
✓ No source IP appears in both paths
✓ Traffic is distributed across both paths
✓ Both ICMP and TCP from the same source IP use the same path (L3 consistency)
✓ Load deviation between paths is within acceptable range

## References

- [RFC 2991](https://tools.ietf.org/html/rfc2991): Multipath Issues in Unicast and Multicast Next-Hop Selection
- [RFC 2992](https://tools.ietf.org/html/rfc2992): Analysis of an Equal-Cost Multi-Path Algorithm
- [Linux Multipath Routing](https://www.kernel.org/doc/Documentation/networking/multipath.txt)
