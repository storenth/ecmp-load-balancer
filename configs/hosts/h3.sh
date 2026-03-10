#!/bin/sh
#
# Network configuration for Host 3 (h3)
# Source network host with IP 10.0.1.12/24
#

# Configure network interface
ip addr add 10.0.1.12/24 dev eth0
ip link set eth0 up

# Set default route via edge router
ip route add default via 10.0.1.1

echo "Host 3 (h3) configured with IP 10.0.1.12/24"
