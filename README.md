# ECMP Hash Testing - Minimal Static Topology

## Overview

This project implements a minimal static topology for testing ECMP (Equal-Cost Multi-Path) routing with hash-based path selection using Source IP addresses. The solution uses Linux network namespaces and bash scripts to create a complete testing environment without requiring virtualization software like QEMU/KVM.

## Architecture

### Network Topology

```
Source1 (192.168.1.10) ──┐
                           ├── Router (192.168.1.1/192.168.10.1) ──┬── Path 1 (192.168.2.0/24) ──┐
Source2 (192.168.10.10) ──┘                              └── Path 2 (192.168.3.0/24) ──┼── Dest (192.168.4.10)
```

### Components

1. **Source1** (namespace: `source1`): 192.168.1.10/24 on veth_s1_r
2. **Source2** (namespace: `source2`): 192.168.10.10/24 on veth_s2_r
3. **Router** (namespace: `router`):
   - 192.168.1.1/24 on veth_r_s1
   - 192.168.10.1/24 on veth_r_s2
   - 192.168.2.1/24 on veth_r_d1 (Path 1)
   - 192.168.3.1/24 on veth_r_d2 (Path 2)
4. **Destination** (namespace: `dest`):
   - 192.168.2.2/24 on veth_d1_r
   - 192.168.3.2/24 on veth_d2_r
   - 192.168.4.10/32 on lo (destination IP)

### ECMP Configuration

The router uses static ECMP routing with the following command:

```bash
ip route add 192.168.4.0/24 \
    nexthop via 192.168.2.2 dev veth_r_d1 weight 1 \
    nexthop via 192.168.3.2 dev veth_r_d2 weight 1
```

This creates two equal-cost paths to the destination network, allowing the Linux kernel to distribute traffic based on a hash algorithm.

## Design Decisions

### 1. Network Namespaces vs QEMU/KVM

**Decision:** Use Linux network namespaces instead of QEMU/KVM virtual machines.

**Rationale:**
- **Simplicity:** Network namespaces provide complete network isolation without the overhead of full virtualization
- **Performance:** Minimal resource usage compared to VMs
- **Native Linux:** Leverages built-in Linux networking capabilities
- **Portability:** Works on any Linux system without additional software

**Authoritative Sources:**
- [Linux Network Namespaces Documentation](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)
- [ip-netns(8) - Linux manual page](https://man7.org/linux/man-pages/man8/ip-netns.8.html)

### 2. Static ECMP Routing

**Decision:** Use static ECMP routes with `ip route` command instead of dynamic routing protocols.

**Rationale:**
- **Minimalism:** No need for complex routing daemons (FRR, Quagga, etc.)
- **Predictability:** Static routes provide deterministic behavior for testing
- **Simplicity:** Easy to configure and verify
- **Testing Focus:** Allows focus on ECMP hash behavior rather than routing protocol dynamics

**Authoritative Sources:**
- [ip-route(8) - Linux manual page](https://man7.org/linux/man-pages/man8/ip-route.8.html)
- [Linux ECMP Implementation](https://www.kernel.org/doc/Documentation/networking/multipath.txt)

### 3. Traffic Generation (ICMP and TCP)

**Decision:** Use dedicated scripts [`capture_traffic.sh`](capture_traffic.sh), [`generate_traffic.sh`](generate_traffic.sh), and [`analyze_results.sh`](analyze_results.sh) for comprehensive traffic testing.

**Rationale:**
- **Separation of Concerns:** Capture, generation, and analysis are handled by specialized scripts
- **Simultaneous Capture:** [`capture_traffic.sh`](capture_traffic.sh) captures traffic on both ECMP paths in parallel
- **Multi-Protocol Traffic:** [`generate_traffic.sh`](generate_traffic.sh) generates both ICMP (ping) and TCP (HTTP) traffic
- **HTTP Server Integration:** Automatically starts an HTTP server on the destination for TCP testing
- **Advanced Analysis:** [`analyze_results.sh`](analyze_results.sh) provides detailed L3 consistency, byte distribution, and protocol alignment analysis
- **Controlled Testing:** Easy to specify packet count, interval, and TCP session count
- **Comprehensive Testing:** Tests ECMP hash with both protocol types (ICMP without ports, TCP with ports) to verify L3 source IP consistency

**Authoritative Sources:**
- [ping(8) - Linux manual page](https://man7.org/linux/man-pages/man8/ping.8.html)
- [curl(1) - Linux manual page](https://man7.org/linux/man-pages/man1/curl.1.html)
- [python3 -m http.server](https://docs.python.org/3/library/http.server.html)

### 4. Traffic Capture with tcpdump

**Decision:** Use `tcpdump` for packet capture on router interfaces.

**Rationale:**
- **Standard Tool:** Widely available and well-documented
- **PCAP Format:** Industry-standard format for packet captures
- **Filtering:** Built-in support for BPF filters (e.g., `icmp`)
- **Integration:** Works seamlessly with analysis tools like tshark

**Authoritative Sources:**
- [tcpdump(8) - Linux manual page](https://man7.org/linux/man-pages/man8/tcpdump.8.html)
- [PCAP File Format](https://wiki.wireshark.org/Development/LibpcapFileFormat)

### 5. Hash Algorithm Selection

**Decision:** Rely on Linux kernel's default ECMP hash algorithm.

**Rationale:**
- **Kernel Implementation:** Linux kernel implements RFC-compliant ECMP hashing
- **Source IP Hashing:** By default, Linux uses a hash based on source IP, destination IP, and other fields
- **Testing Focus:** The goal is to verify ECMP behavior, not to implement custom hash algorithms
- **RFC Compliance:** Linux implementation follows RFC 2991 and RFC 2992 guidelines

**Authoritative Sources:**
- [RFC 2991: Multipath Issues in Unicast and Multicast Next-Hop Selection](https://tools.ietf.org/html/rfc2991)
- [RFC 2992: Analysis of an Equal-Cost Multi-Path Algorithm](https://tools.ietf.org/html/rfc2992)
- [Linux Kernel Multipath Routing](https://www.kernel.org/doc/Documentation/networking/multipath.txt)

## Implementation Details

### ECMP Hash Behavior in Linux

The Linux kernel uses a hash-based algorithm to select among multiple equal-cost paths. The hash is computed based on:

1. **Source IP address** (primary factor for this test)
2. **Destination IP address**
3. **Transport layer ports** (if available)
4. **Protocol type**

The hash result is used to select one of the available paths, ensuring that packets from the same flow (same source IP) consistently use the same path.

**Note:** ICMP packets (ping) do not have transport layer ports, so the hash is computed based on source IP, destination IP, and protocol type only. TCP packets include source and destination ports in the hash calculation, providing more granular flow identification.

### Verification Method

The test verifies ECMP correctness by:

1. **Consistency:** Each source IP should consistently use the same path
2. **Distribution:** Different source IPs should be distributed across different paths
3. **No Splitting:** A single source IP should not appear in both paths

## Usage

### Prerequisites

- Linux operating system with kernel 3.0+ (for network namespace support)
- Root/sudo privileges
- Required tools: `ip`, `tcpdump`, `tshark`, `ping`, `bc`, `make`

### Quick Start with Makefile

```bash
# Run complete test cycle (setup, capture, generate, analyze)
make test

# Or run individual steps
make setup          # Setup topology
make capture        # Start traffic capture (background)
make generate       # Generate test traffic
make analyze        # Analyze results
make cleanup        # Remove topology
```

### Quick Start (Manual)

```bash
# 1. Setup the topology
sudo ./setup_topology.sh

# 2. Start traffic capture (runs for 30 seconds, captures both paths simultaneously)
sudo ./capture_traffic.sh

# 3. Generate traffic from both sources (ICMP + TCP)
sudo ./generate_traffic.sh

# 4. Analyze results (L3 consistency, byte distribution, protocol alignment)
sudo ./analyze_results.sh

# 5. Cleanup when done
sudo ./cleanup.sh
```

### Step-by-Step Guide

#### 1. Setup Topology

```bash
sudo ./setup_topology.sh
```

This creates:
- 4 network namespaces (source1, source2, router, dest)
- 5 veth pairs for connectivity
- Static routes including ECMP configuration

#### 2. Verify Connectivity

```bash
# Test from source1
sudo ip netns exec source1 ping -c 3 192.168.4.10

# Test from source2
sudo ip netns exec source2 ping -c 3 192.168.4.10
```

#### 3. Capture Traffic

```bash
# Start capture (runs for 30 seconds by default)
sudo ./capture_traffic.sh
```

This script:
- Captures traffic on both ECMP paths simultaneously using parallel tcpdump processes
- Filters for both ICMP and TCP protocols
- Saves captures as PCAP files in the `results/` directory
- Displays process IDs for monitoring

#### 4. Generate Traffic

```bash
# Generate 100 ICMP packets and 10 TCP sessions from each source
sudo ./generate_traffic.sh
```

This script:
- Starts an HTTP server on the destination (192.168.4.10:80)
- Generates ICMP traffic using ping (100 packets per source)
- Generates TCP traffic using curl (10 HTTP sessions per source)
- Saves detailed logs to `results/source1_report.log` and `results/source2_report.log`
- Automatically cleans up the HTTP server after generation

#### 5. Analyze Results

```bash
sudo ./analyze_results.sh
```

This script:
- Analyzes PCAP files from both ECMP paths
- Provides packet and byte distribution statistics
- Validates L3 source IP consistency (verifies both ICMP and TCP from same IP use same path)
- Checks protocol alignment for each source IP
- Verifies ECMP hash correctness and path diversity
- Provides detailed analysis output with traffic deviation metrics

#### 6. Cleanup

```bash
sudo ./cleanup.sh
```

Removes all namespaces and veth pairs.

## Results Interpretation

### Expected Behavior

When ECMP hash is working correctly:

1. **Source 192.168.1.10** should appear in only one path (either Path 1 or Path 2)
2. **Source 192.168.10.10** should appear in only one path (either Path 1 or Path 2)
3. **Different sources** should be distributed across different paths (ideally one per path)
4. **Both ICMP and TCP** from the same source IP should use the same path (L3 consistency)

### Success Criteria

- ✓ Each source IP is consistently routed to a single path
- ✓ Different source IPs use different paths
- ✓ No source IP appears in both paths
- ✓ Traffic is roughly balanced between paths (50/50 distribution ideal)
- ✓ Both ICMP and TCP protocols from the same source IP use the same path
- ✓ Load deviation between paths is within acceptable range (typically < 20%)

### Troubleshooting

**If a source appears in both paths:**
- Check ECMP route configuration: `sudo ip netns exec router ip route show`
- Verify IP forwarding is enabled: `sudo ip netns exec router sysctl net.ipv4.ip_forward`
- Check for route flapping or network instability

**If traffic is not balanced:**
- This is expected behavior with only 2 source IPs
- ECMP hash may route both sources to the same path
- Add more source IPs for better distribution testing

## Testing Standards Compliance

This implementation follows the testing methodology outlined in:

- **ISO/IEC/IEEE 29119-3**: Software and systems engineering — Software testing — Part 3: Test documentation
- **RFC 2991**: Multipath Issues in Unicast and Multicast Next-Hop Selection
- **RFC 2992**: Analysis of an Equal-Cost Multi-Path Algorithm
- **RFC 2544**: Benchmarking Methodology for Network Interconnect Devices
- **RFC 2330**: Framework for IP Performance Metrics

## Limitations

1. **Static Topology**: This implementation uses static routes. For dynamic routing, consider using FRR (Free Range Routing).
2. **Hash Algorithm**: Relies on Linux kernel's default ECMP hash. Custom hash algorithms require kernel modifications.
3. **Scale**: Minimal topology with 2 source IPs. For comprehensive testing, use more sources.
4. **Resilient Hashing**: Not tested in this implementation (as noted in requirements).
5. **Symmetric Hashing**: Not tested in this implementation (as noted in requirements).

## References

### RFC Standards
- [RFC 2991](https://tools.ietf.org/html/rfc2991): Multipath Issues in Unicast and Multicast Next-Hop Selection
- [RFC 2992](https://tools.ietf.org/html/rfc2992): Analysis of an Equal-Cost Multi-Path Algorithm
- [RFC 2544](https://tools.ietf.org/html/rfc2544): Benchmarking Methodology for Network Interconnect Devices
- [RFC 2330](https://tools.ietf.org/html/rfc2330): Framework for IP Performance Metrics

### Linux Documentation
- [Network Namespaces](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)
- [ip-route(8)](https://man7.org/linux/man-pages/man8/ip-route.8.html)
- [ip-netns(8)](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
- [Multipath Routing](https://www.kernel.org/doc/Documentation/networking/multipath.txt)

### Testing Standards
- [ISO/IEC/IEEE 29119-3](https://www.iso.org/standard/65174.html): Software and systems engineering — Software testing — Part 3: Test documentation
- [IEEE 829](https://standards.ieee.org/standard/829-2008.html): Standard for Software and System Test Documentation

## License

This project is provided as-is for educational and testing purposes.

## Contributing

Contributions are welcome! Please ensure any changes maintain the minimal, bash-based approach and update documentation accordingly.
