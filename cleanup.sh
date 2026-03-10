#!/bin/bash

# ECMP Testing - Cleanup Script
# Removes all network namespaces and veth pairs created during testing

set -e

echo "Cleaning up ECMP test topology..."

# Delete network namespaces
echo "Removing network namespaces..."
ip netns delete source1 2>/dev/null || echo "source1 namespace not found"
ip netns delete source2 2>/dev/null || echo "source2 namespace not found"
ip netns delete router 2>/dev/null || echo "router namespace not found"
ip netns delete dest 2>/dev/null || echo "dest namespace not found"

# Delete veth pairs
echo "Removing veth pairs..."
ip link delete veth_s1_r 2>/dev/null || echo "veth_s1_r not found"
ip link delete veth_s2_r 2>/dev/null || echo "veth_s2_r not found"
ip link delete veth_r_d1 2>/dev/null || echo "veth_r_d1 not found"
ip link delete veth_r_d2 2>/dev/null || echo "veth_r_d2 not found"

echo ""
echo "Cleanup complete!"
echo "All network namespaces and veth pairs have been removed."
