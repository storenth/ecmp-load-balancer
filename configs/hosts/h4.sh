#!/bin/sh
#
# Network configuration for Host 4 (h4)
# Source network host with IP 10.0.1.13/24
#

# Configure network interface
ip addr add 10.0.1.13/24 dev eth0
ip link set eth0 up

# Set default route via edge router
ip route add default via 10.0.1.1

echo "Host 4 (h4) configured with IP 10.0.1.13/24"
