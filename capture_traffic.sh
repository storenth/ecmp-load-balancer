#!/bin/bash

# ECMP Testing - Traffic Capture Script (SIMULTANEOUS)
set -e

# Configuration
CAPTURE_DURATION=30
RESULTS_DIR="results"

# Create results directory
mkdir -p $RESULTS_DIR

echo "Starting SIMULTANEOUS traffic capture on ECMP router interfaces..."

# 1. Запускаем дампы ПАРАЛЛЕЛЬНО
# Добавлен фильтр 'tcp or icmp', чтобы поймать и пинги, и curl
echo "Capturing on veth_r_d1..."
ip netns exec router tcpdump -ni veth_r_d1 -w "$RESULTS_DIR/path1_capture.pcap" tcp or icmp &
PID1=$!

echo "Capturing on veth_r_d2..."
ip netns exec router tcpdump -ni veth_r_d2 -w "$RESULTS_DIR/path2_capture.pcap" tcp or icmp &
PID2=$!

echo "Captures started (PIDs: $PID1, $PID2). Waiting for $CAPTURE_DURATION seconds..."
echo "NOW RUN YOUR GENERATION SCRIPT!"

# 2. Ожидание
sleep $CAPTURE_DURATION

# 3. Остановка обоих процессов
echo "Stopping captures..."
kill $PID1 $PID2 2>/dev/null || true
wait $PID1 $PID2 2>/dev/null || true

echo ""
echo "Traffic capture complete! Files saved in $RESULTS_DIR/"

# 4. Обновленные подсказки для анализа
echo "To analyze the captures (including TCP):"
echo "  tshark -r $RESULTS_DIR/path1_capture.pcap -Y 'ip.src == 192.168.1.10 or ip.src == 192.168.10.12' -T fields -e ip.src -e _ws.col.Protocol"
