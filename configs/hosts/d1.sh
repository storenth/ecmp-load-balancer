#!/bin/sh
#
# Network configuration for Destination Host (d1)
# Destination network host with IP 192.168.100.10/24
#

# Configure network interface
ip addr add 192.168.100.10/24 dev eth0
ip link set eth0 up

# Set default route via destination router
ip route add default via 192.168.100.1

echo "Destination Host (d1) configured with IP 192.168.100.10/24"
