FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    # Сеть
    iproute2 iputils-ping dnsutils curl wget mtr-tiny net-tools netcat-openbsd \
    tcpdump iperf3 nmap conntrack iptables \
    # Система и ядро
    kmod procps util-linux strace \
    # Удобство
    vim-tiny ca-certificates \
    man-db manpages less nano \

ENTRYPOINT ["/bin/bash"]
