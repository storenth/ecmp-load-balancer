#!/bin/bash

# ECMP Testing - Traffic Generation Script
set -e

# Configuration (Должно совпадать с именами из скрипта топологии)
NS_DEST="dest"
DEST_IP="192.168.4.10"
PACKET_COUNT=100
PACKET_INTERVAL=0.1
TCP_SESSIONS=10 # Сколько раз дернуть curl для статистики

# Create results directory
mkdir -p results

# 1. ЗАПУСК СЕРВЕРА (Перед генерацией)
echo "Starting HTTP Server on Destination ($DEST_IP)..."
# Запускаем сервер в фоне внутри неймспейса dest
ip netns exec $NS_DEST python3 -m http.server 80 --bind $DEST_IP > /dev/null 2>&1 &
SERVER_PID=$!

# Даем серверу время "прогреться"
sleep 2 

echo "Starting traffic generation..."
echo "Destination IP: $DEST_IP"

# Function to generate traffic from a source
generate_from_source() {
    local source_ns=$1
    local source_ip=$2
    local output_file=$3
    
    echo "--- Generating traffic from $source_ns ($source_ip) ---"
    
    # 1. ICMP (Ping)
    echo "Running ICMP test..."
    ip netns exec $source_ns ping -c $PACKET_COUNT -i $PACKET_INTERVAL $DEST_IP > "$output_file" 2>&1
    
    # 2. TCP (Curl) - делаем несколько запросов для накопления данных в pcap
    echo "Running TCP (HTTP) sessions..." >> "$output_file"
    for i in $(seq 1 $TCP_SESSIONS); do
        ip netns exec $source_ns curl -s --connect-timeout 2 http://${DEST_IP}:80 >> "$output_file" 2>&1 || echo "Session $i failed" >> "$output_file"
    done

    echo "Done for $source_ns."
}

# 2. ГЕНЕРАЦИЯ ТРАФИКА
generate_from_source "source1" "192.168.1.10" "results/source1_report.log"
generate_from_source "source2" "192.168.10.12" "results/source2_report.log"

# 3. ОЧИСТКА (После генерации)
echo "Cleaning up server..."
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "Traffic generation complete! Check results/ directory."
