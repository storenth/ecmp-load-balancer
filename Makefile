# ECMP Hash Testing - Makefile
# Convenient interface for running ECMP hash tests

.PHONY: help setup capture generate analyze cleanup test verify clean-all

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)ECMP Hash Testing - Available Commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make test          # Run complete test cycle"
	@echo "  make verify        # Setup and verify connectivity only"
	@echo ""

setup: ## Setup network topology
	@echo "$(BLUE)Setting up ECMP topology...$(NC)"
	@sudo ./setup_topology.sh
	@echo "$(GREEN)✓ Topology setup complete$(NC)"

capture: ## Start traffic capture (run in background)
	@echo "$(BLUE)Starting traffic capture...$(NC)"
	@sudo ./capture_traffic.sh &
	@echo "$(GREEN)✓ Traffic capture started in background$(NC)"

generate: ## Generate test traffic from both sources
	@echo "$(BLUE)Generating test traffic...$(NC)"
	@sudo ./generate_traffic.sh
	@echo "$(GREEN)✓ Traffic generation complete$(NC)"

analyze: ## Analyze ECMP hash distribution
	@echo "$(BLUE)Analyzing ECMP hash distribution...$(NC)"
	@sudo ./analyze_results.sh
	@echo "$(GREEN)✓ Analysis complete$(NC)"

cleanup: ## Remove network topology
	@echo "$(BLUE)Cleaning up ECMP topology...$(NC)"
	@sudo ./cleanup.sh
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

test: setup capture generate analyze ## Run complete test cycle
	@echo "$(GREEN)✓ Complete test cycle finished$(NC)"
	@echo ""
	@echo "$(YELLOW)Results saved in results/ directory$(NC)"

verify: setup ## Setup topology and verify connectivity
	@echo "$(BLUE)Verifying connectivity...$(NC)"
	@echo ""
	@echo "Testing from Source1 (192.168.1.10):"
	@sudo ip netns exec source1 ping -c 3 192.168.4.10
	@echo ""
	@echo "Testing from Source2 (192.168.10.10):"
	@sudo ip netns exec source2 ping -c 3 192.168.4.10
	@echo ""
	@echo "$(GREEN)✓ Connectivity verification complete$(NC)"

clean-all: cleanup ## Cleanup and remove results
	@echo "$(BLUE)Removing results directory...$(NC)"
	@rm -rf results/
	@echo "$(GREEN)✓ All cleaned up$(NC)"

show-routes: ## Show ECMP routes on router
	@echo "$(BLUE)ECMP routes on router:$(NC)"
	@sudo ip netns exec router ip route show 192.168.4.0/24

show-interfaces: ## Show all interfaces in all namespaces
	@echo "$(BLUE)Interfaces in all namespaces:$(NC)"
	@echo ""
	@echo "$(YELLOW)Source1:$(NC)"
	@sudo ip netns exec source1 ip addr show
	@echo ""
	@echo "$(YELLOW)Source2:$(NC)"
	@sudo ip netns exec source2 ip addr show
	@echo ""
	@echo "$(YELLOW)Router:$(NC)"
	@sudo ip netns exec router ip addr show
	@echo ""
	@echo "$(YELLOW)Dest:$(NC)"
	@sudo ip netns exec dest ip addr show

show-namespaces: ## List all network namespaces
	@echo "$(BLUE)Network namespaces:$(NC)"
	@ip netns list

ping-source1: ## Ping from source1 to destination
	@echo "$(BLUE)Pinging from Source1 to Destination...$(NC)"
	@sudo ip netns exec source1 ping -c 5 192.168.4.10

ping-source2: ## Ping from source2 to destination
	@echo "$(BLUE)Pinging from Source2 to Destination...$(NC)"
	@sudo ip netns exec source2 ping -c 5 192.168.4.10

check-captures: ## Show captured packets count
	@echo "$(BLUE)Captured packets:$(NC)"
	@if [ -f results/path1_capture.pcap ]; then \
		echo "Path 1: $$(tshark -r results/path1_capture.pcap 2>/dev/null | wc -l) packets"; \
	else \
		echo "Path 1: No capture file"; \
	fi
	@if [ -f results/path2_capture.pcap ]; then \
		echo "Path 2: $$(tshark -r results/path2_capture.pcap 2>/dev/null | wc -l) packets"; \
	else \
		echo "Path 2: No capture file"; \
	fi

view-results: ## View analysis results
	@echo "$(BLUE)Analysis results:$(NC)"
	@if [ -f results/path1_sources.txt ]; then \
		echo ""; \
		echo "$(YELLOW)Path 1 source IPs:$(NC)"; \
		cat results/path1_sources.txt; \
	fi
	@if [ -f results/path2_sources.txt ]; then \
		echo ""; \
		echo "$(YELLOW)Path 2 source IPs:$(NC)"; \
		cat results/path2_sources.txt; \
	fi
