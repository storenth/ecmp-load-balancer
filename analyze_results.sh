#!/bin/bash

# ECMP Testing - Advanced Results Analysis Script
# Analyzes PCAP files for Source IP Hash Consistency, Byte Distribution, and Protocol Alignment

set -e

RESULTS_DIR="results"
S1="192.168.1.10"
S2="192.168.10.10"

echo "======================================================"
echo "📊 ECMP ADVANCED TRAFFIC ANALYSIS"
echo "======================================================"

# 1. Проверка наличия файлов
if [ ! -f "$RESULTS_DIR/path1_capture.pcap" ] || [ ! -f "$RESULTS_DIR/path2_capture.pcap" ]; then
    echo "❌ Error: PCAP files not found in $RESULTS_DIR/"
    exit 1
fi

# Функция для получения статистики по пути
get_path_stats() {
    local pcap=$1
    local packets=$(tshark -r "$pcap" 2>/dev/null | wc -l)
    local bytes=$(tshark -r "$pcap" -T fields -e frame.len 2>/dev/null | awk '{s+=$1} END {print s+0}')
    echo "$packets $bytes"
}

read p1_pkts p1_bytes <<< $(get_path_stats "$RESULTS_DIR/path1_capture.pcap")
read p2_pkts p2_bytes <<< $(get_path_stats "$RESULTS_DIR/path2_capture.pcap")

total_pkts=$((p1_pkts + p2_pkts))
total_bytes=$((p1_bytes + p2_bytes))

# 2. Вывод общего распределения
echo "--- Traffic Distribution ---"
echo "Path 1: $p1_pkts pkts / $p1_bytes bytes"
echo "Path 2: $p2_pkts pkts / $p2_bytes bytes"

if [ $total_bytes -gt 0 ]; then
    deviation=$(echo "scale=2; abs=($p1_bytes - $p2_bytes); if(abs<0) abs=-abs; (abs / $total_bytes) * 100" | bc -l)
    echo "Current Load Deviation: ${deviation}%"
fi

# 3. Валидация L3 Source IP Hashing (Protocol Consistency)
# Это доказывает, что и ICMP, и TCP от одного IP ушли в один путь
validate_l3_consistency() {
    local ip=$1
    echo -e "\n--- Validating L3 Consistency for $ip ---"
    
    # Ищем IP в обоих файлах
    local in_p1=$(tshark -r "$RESULTS_DIR/path1_capture.pcap" -Y "ip.src == $ip" 2>/dev/null | wc -l)
    local in_p2=$(tshark -r "$RESULTS_DIR/path2_capture.pcap" -Y "ip.src == $ip" 2>/dev/null | wc -l)
    
    if [ "$in_p1" -gt 0 ] && [ "$in_p2" -gt 0 ]; then
        echo "❌ FAIL: Source $ip is FLAPPING between paths (Per-packet detected!)"
        return 1
    fi

    local target_pcap=""
    [ "$in_p1" -gt 0 ] && target_pcap="$RESULTS_DIR/path1_capture.pcap"
    [ "$in_p2" -gt 0 ] && target_pcap="$RESULTS_DIR/path2_capture.pcap"

    if [ -z "$target_pcap" ]; then
        echo "⚠️ WARNING: No traffic found for $ip"
    else
        echo "✅ Source $ip is STICKY to $(basename $target_pcap)"
        echo "Protocols detected for this IP:"
        tshark -r "$target_pcap" -Y "ip.src == $ip" -T fields -e _ws.col.Protocol | sort | uniq -c | sed 's/^/  /'
    fi
}

validate_l3_consistency "$S1"
validate_l3_consistency "$S2"

# 4. Проверка распределения разных IP
echo -e "\n--- Path Diversity Check ---"
s1_path=$(tshark -r "$RESULTS_DIR/path1_capture.pcap" -Y "ip.src == $S1" 2>/dev/null | wc -l)
s2_path=$(tshark -r "$RESULTS_DIR/path1_capture.pcap" -Y "ip.src == $S2" 2>/dev/null | wc -l)

if { [ "$s1_path" -gt 0 ] && [ "$s2_path" -eq 0 ]; } || { [ "$s1_path" -eq 0 ] && [ "$s2_path" -gt 0 ]; }; then
    echo "✅ SUCCESS: Different Source IPs are using different ECMP paths."
else
    # При 2-х источниках это может быть нормой (50% шанс коллизии хеша)
    echo "ℹ️ INFO: Both sources mapped to the same path. (Normal for small entropy pool)"
fi

echo -e "\n======================================================"
echo "Analysis Complete."
