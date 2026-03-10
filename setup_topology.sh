#!/bin/bash

# ECMP Testing - Minimal Static Topology Setup
# This script creates a minimal topology for testing ECMP routing with hash based on Source IP

set -e

# Network namespaces for isolation
NS_SOURCE1="source1"
NS_SOURCE2="source2"
NS_ROUTER="router"
NS_DEST="dest"

# Clean up function
cleanup() {
    echo "Cleaning up existing namespaces..."
    ip netns delete $NS_SOURCE1 2>/dev/null || true
    ip netns delete $NS_SOURCE2 2>/dev/null || true
    ip netns delete $NS_ROUTER 2>/dev/null || true
    ip netns delete $NS_DEST 2>/dev/null || true
    
    # Delete veth pairs
    ip link delete veth_s1_r 2>/dev/null || true
    ip link delete veth_s2_r 2>/dev/null || true
    ip link delete veth_r_d1 2>/dev/null || true
    ip link delete veth_r_d2 2>/dev/null || true
}

# Cleanup existing setup
cleanup

echo "Creating network namespaces..."
ip netns add $NS_SOURCE1
ip netns add $NS_SOURCE2
ip netns add $NS_ROUTER
ip netns add $NS_DEST

echo "Creating veth pairs..."
# Source1 to Router
ip link add veth_s1_r type veth peer name veth_r_s1
ip link set veth_s1_r netns $NS_SOURCE1
ip link set veth_r_s1 netns $NS_ROUTER

# Source2 to Router
ip link add veth_s2_r type veth peer name veth_r_s2
ip link set veth_s2_r netns $NS_SOURCE2
ip link set veth_r_s2 netns $NS_ROUTER

# Router to Dest1
ip link add veth_r_d1 type veth peer name veth_d1_r
ip link set veth_r_d1 netns $NS_ROUTER
ip link set veth_d1_r netns $NS_DEST

# Router to Dest2
ip link add veth_r_d2 type veth peer name veth_d2_r
ip link set veth_r_d2 netns $NS_ROUTER
ip link set veth_d2_r netns $NS_DEST

echo "Configuring interfaces..."

# Configure Source1
ip netns exec $NS_SOURCE1 ip addr add 192.168.1.10/24 dev veth_s1_r
ip netns exec $NS_SOURCE1 ip link set dev veth_s1_r up
ip netns exec $NS_SOURCE1 ip link set dev lo up
ip netns exec $NS_SOURCE1 ip route add default via 192.168.1.1

# Configure Source2
ip netns exec $NS_SOURCE2 ip addr add 192.168.10.10/24 dev veth_s2_r
ip netns exec $NS_SOURCE2 ip link set dev veth_s2_r up
ip netns exec $NS_SOURCE2 ip link set dev lo up
ip netns exec $NS_SOURCE2 ip route add default via 192.168.10.1

# Configure Router
ip netns exec $NS_ROUTER ip addr add 192.168.1.1/24 dev veth_r_s1
ip netns exec $NS_ROUTER ip link set dev veth_r_s1 up

ip netns exec $NS_ROUTER ip addr add 192.168.10.1/24 dev veth_r_s2
ip netns exec $NS_ROUTER ip link set dev veth_r_s2 up

ip netns exec $NS_ROUTER ip addr add 192.168.2.1/24 dev veth_r_d1
ip netns exec $NS_ROUTER ip link set dev veth_r_d1 up

ip netns exec $NS_ROUTER ip addr add 192.168.3.1/24 dev veth_r_d2
ip netns exec $NS_ROUTER ip link set dev veth_r_d2 up

ip netns exec $NS_ROUTER ip link set dev lo up

# Enable IP forwarding on router
ip netns exec $NS_ROUTER sysctl -w net.ipv4.ip_forward=1

# Disable reverse path filtering to prevent ECMP packet drops
ip netns exec $NS_ROUTER sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec $NS_ROUTER sysctl -w net.ipv4.conf.default.rp_filter=0

# Configure ECMP routes on router
echo "Configuring ECMP routes on router..."
ip netns exec $NS_ROUTER ip route add 192.168.4.0/24 \
    nexthop via 192.168.2.2 dev veth_r_d1 weight 1 \
    nexthop via 192.168.3.2 dev veth_r_d2 weight 1

# Configure Dest
ip netns exec $NS_DEST ip addr add 192.168.2.2/24 dev veth_d1_r
ip netns exec $NS_DEST ip link set dev veth_d1_r up

ip netns exec $NS_DEST ip addr add 192.168.3.2/24 dev veth_d2_r
ip netns exec $NS_DEST ip link set dev veth_d2_r up

# Add destination IP on loopback interface
ip netns exec $NS_DEST ip addr add 192.168.4.10/32 dev lo
ip netns exec $NS_DEST ip link set dev lo up

# Add routes back to source networks
ip netns exec $NS_DEST ip route add 192.168.1.0/24 via 192.168.2.1 dev veth_d1_r
ip netns exec $NS_DEST ip route add 192.168.10.0/24 via 192.168.2.1 dev veth_d1_r
ip netns exec $NS_DEST ip route add 192.168.1.0/24 via 192.168.3.1 dev veth_d2_r
ip netns exec $NS_DEST ip route add 192.168.10.0/24 via 192.168.3.1 dev veth_d2_r

echo ""
echo "Topology setup complete!"
echo ""
echo "Network topology:"
echo "  Source1 (192.168.1.10) --> Router (192.168.1.1)"
echo "  Source2 (192.168.10.10) --> Router (192.168.10.1)"
echo "  Router --> Dest via two ECMP paths:"
echo "    Path 1: 192.168.2.1 --> 192.168.2.2"
echo "    Path 2: 192.168.3.1 --> 192.168.3.2"
echo "  Destination: 192.168.4.10"
echo ""
echo "To verify connectivity:"
echo "  ip netns exec source1 ping -c 3 192.168.4.10"
echo "  ip netns exec source2 ping -c 3 192.168.4.10"
