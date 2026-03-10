# =============================================================================
# CI/CD Docker Image for ECMP Testing
# =============================================================================
# This Dockerfile creates a production-ready CI/CD environment with all
# required dependencies pre-installed for ECMP hash testing.
#
# Reference: https://docs.docker.com/engine/reference/builder/
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
# Best Practices: Dockerfile Best Practices
#
# Base Image: Ubuntu 22.04 LTS
# Purpose: CI/CD environment for automated ECMP testing
#
# Included Dependencies:
#   - Containerlab: Network topology deployment
#   - FRRouting: Routing protocol suite
#   - tcpdump: Packet capture and analysis
#   - hping3: Traffic generation
#   - Allure: Test reporting
#   - Python 3.11: Scripting and analysis
#   - scipy/numpy: Statistical analysis
#   - jq/yq: JSON/YAML processing
#   - bc: Calculator for statistical operations
# =============================================================================

# Use Ubuntu 22.04 LTS as base image
FROM ubuntu:22.04

# Metadata
LABEL maintainer="ECMP Testing Framework"
LABEL description="CI/CD environment for ECMP hash testing"
LABEL version="1.0.0"
LABEL org.opencontainers.image.title="ECMP Testing CI/CD"
LABEL org.opencontainers.image.description="Production-ready CI/CD environment for ECMP testing"
LABEL org.opencontainers.image.version="1.0.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Set working directory
WORKDIR /workspace

# =============================================================================
# System Dependencies Installation
# =============================================================================

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic utilities
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    vim \
    nano \
    less \
    tree \
    htop \
    net-tools \
    iproute2 \
    iputils-ping \
    traceroute \
    netcat-openbsd \
    # Network tools
    tcpdump \
    hping3 \
    nmap \
    wireshark-common \
    # Development tools
    build-essential \
    cmake \
    make \
    gcc \
    g++ \
    # Data processing
    jq \
    bc \
    # Python dependencies
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    # Java for Allure
    openjdk-11-jdk \
    # FRRouting dependencies
    libreadline-dev \
    libjson-c-dev \
    libyang2 \
    # Other utilities
    unzip \
    zip \
    tar \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Containerlab Installation
# =============================================================================

# Install Containerlab
# Reference: https://containerlab.dev/install/
RUN curl -sL https://containerlab.dev/install.sh | bash -s -- -v 0.50.0

# Verify Containerlab installation
RUN clab version

# =============================================================================
# FRRouting Installation
# =============================================================================

# Install FRRouting
# Reference: https://docs.frrouting.org/
RUN echo "deb https://deb.frrouting.org/frr/$(lsb_release -s -c) frr-stable" > /etc/apt/sources.list.d/frr.list && \
    curl -s https://deb.frrouting.org/frr/$(lsb_release -s -c)/gpg.key | apt-key add - && \
    apt-get update && \
    apt-get install -y frr frr-pythontools && \
    rm -rf /var/lib/apt/lists/*

# Verify FRRouting installation
RUN vtysh -c "show version"

# =============================================================================
# Python Dependencies Installation
# =============================================================================

# Upgrade pip and install Python packages
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install scientific computing packages
RUN pip3 install --no-cache-dir \
    scipy==1.11.4 \
    numpy==1.26.2 \
    pandas==2.1.4 \
    matplotlib==3.8.2 \
    seaborn==0.13.0

# Install YAML/JSON processing
RUN pip3 install --no-cache-dir \
    pyyaml==6.0.1 \
    jsonschema==4.20.0

# Install testing utilities
RUN pip3 install --no-cache-dir \
    pytest==7.4.3 \
    pytest-cov==4.1.0 \
    allure-pytest==2.13.2

# Install yq (YAML processor)
RUN wget https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Verify Python installations
RUN python3 --version && \
    pip3 list | grep -E "(scipy|numpy|pandas|matplotlib|seaborn|pyyaml)"

# =============================================================================
# Allure Installation
# =============================================================================

# Install Allure Commandline
# Reference: https://docs.qameta.io/allure/
RUN wget https://github.com/allure-framework/allure2/releases/download/2.24.0/allure-2.24.0.tgz && \
    tar -zxvf allure-2.24.0.tgz -C /opt/ && \
    rm allure-2.24.0.tgz && \
    ln -s /opt/allure-2.24.0/bin/allure /usr/local/bin/allure

# Verify Allure installation
RUN allure --version

# =============================================================================
# Docker Configuration
# =============================================================================

# Install Docker CLI
# Reference: https://docs.docker.com/engine/install/ubuntu/
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Verify Docker CLI installation
RUN docker --version

# =============================================================================
# Workspace Setup
# =============================================================================

# Create workspace directories
RUN mkdir -p /workspace/results/captures && \
    mkdir -p /workspace/results/analysis && \
    mkdir -p /workspace/results/reports && \
    mkdir -p /workspace/results/allure-results && \
    mkdir -p /workspace/results/allure-report && \
    mkdir -p /workspace/results/archives && \
    mkdir -p /workspace/logs && \
    mkdir -p /workspace/scripts && \
    mkdir -p /workspace/configs && \
    mkdir -p /workspace/topology

# Set permissions
RUN chmod -R 755 /workspace

# =============================================================================
# Configuration Files
# =============================================================================

# Create environment configuration
RUN cat > /etc/environment << 'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LANG=C.UTF-8
LC_ALL=C.UTF-8
TZ=UTC
DEBIAN_FRONTEND=noninteractive
EOF

# Create bash configuration for better usability
RUN cat > /root/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups

# Append to the history file, don't overwrite it
shopt -s histappend

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Enable color support for ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# ECMP Testing aliases
alias clab-deploy='clab deploy -t topology/clab-ecmp-test.yml'
alias clab-destroy='clab destroy -t topology/clab-ecmp-test.yml --cleanup'
alias ecmp-test='bash scripts/run_test.sh'
alias ecmp-analyze='bash scripts/analyze_results.sh'
alias ecmp-report='bash scripts/generate_allure_report.sh'

# Display system information on login
if [ -f /etc/ecmp-version ]; then
    cat /etc/ecmp-version
fi
EOF

# Create version information file
RUN cat > /etc/ecmp-version << 'EOF'
ECMP Testing CI/CD Environment
Version: 1.0.0
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Installed Tools:
- Containerlab: $(clab version 2>&1 | head -1)
- FRRouting: $(vtysh -c "show version" 2>&1 | head -1)
- Python: $(python3 --version)
- Allure: $(allure --version)
- tcpdump: $(tcpdump --version | head -1)
- hping3: $(hping3 --version 2>&1 | head -1)
- jq: $(jq --version)
- yq: $(yq --version)

For more information, see: https://github.com/your-org/ecmp-testing
EOF

# =============================================================================
# Health Check
# =============================================================================

# Add health check to verify container is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 --version && \
        clab version && \
        allure --version || exit 1

# =============================================================================
# Entrypoint
# =============================================================================

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "ECMP Testing CI/CD Environment"
echo "=========================================="
echo "Version: 1.0.0"
echo "Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""
echo "Installed Tools:"
echo "  - Containerlab: $(clab version 2>&1 | head -1)"
echo "  - FRRouting: $(vtysh -c "show version" 2>&1 | head -1)"
echo "  - Python: $(python3 --version)"
echo "  - Allure: $(allure --version)"
echo "  - tcpdump: $(tcpdump --version | head -1)"
echo "  - hping3: $(hping3 --version 2>&1 | head -1)"
echo "  - jq: $(jq --version)"
echo "  - yq: $(yq --version)"
echo ""
echo "Python Packages:"
echo "  - scipy: $(python3 -c 'import scipy; print(scipy.__version__)')"
echo "  - numpy: $(python3 -c 'import numpy; print(numpy.__version__)')"
echo "  - pandas: $(python3 -c 'import pandas; print(pandas.__version__)')"
echo "  - matplotlib: $(python3 -c 'import matplotlib; print(matplotlib.__version__)'"
echo "=========================================="
echo ""

# Execute the command passed to the container
exec "$@"
EOF

RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# =============================================================================
# Build Arguments
# =============================================================================

# Allow customization of build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${VERSION}"

# =============================================================================
# Final Cleanup
# =============================================================================

# Clean up temporary files
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/*

# =============================================================================
# Documentation
# =============================================================================

# Add README in the image
RUN cat > /README.md << 'EOF'
# ECMP Testing CI/CD Docker Image

This Docker image provides a complete CI/CD environment for ECMP hash testing.

## Quick Start

```bash
# Run the container
docker run -it --rm \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  ecmp-testing:latest

# Inside the container, run tests
cd /workspace
bash scripts/run_test.sh
```

## Available Tools

- **Containerlab**: Network topology deployment
- **FRRouting**: Routing protocol suite
- **tcpdump**: Packet capture and analysis
- **hping3**: Traffic generation
- **Allure**: Test reporting
- **Python 3.11**: Scripting and analysis
- **scipy/numpy**: Statistical analysis
- **jq/yq**: JSON/YAML processing

## Aliases

- `clab-deploy`: Deploy Containerlab topology
- `clab-destroy`: Destroy Containerlab topology
- `ecmp-test`: Run ECMP test
- `ecmp-analyze`: Analyze test results
- `ecmp-report`: Generate Allure report

## Documentation

For more information, see:
- https://docs.github.com/en/actions
- https://containerlab.dev/
- https://docs.frrouting.org/
- https://docs.qameta.io/allure/

## Support

For issues and questions, please open an issue on GitHub.
EOF

# =============================================================================
# End of Dockerfile
# =============================================================================
