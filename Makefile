################################################################################
# ECMP Testing Framework - Makefile
#
# This Makefile provides standardized operations for all ECMP testing workflows.
# It integrates with existing bash scripts in the scripts/ directory to provide
# a unified interface for deploying, configuring, testing, and analyzing ECMP
# hash distribution.
#
# Author: ECMP Testing Framework
# Version: 1.0.0
#
# Usage:
#   make <target> [VARIABLE=value]
#
# Examples:
#   make all                    # Run complete test suite
#   make deploy                 # Deploy topology
#   make test                   # Run complete test
#   make clean                  # Destroy topology and cleanup
#   make VERBOSE=1 all          # Run with verbose output
################################################################################

# ============================================================================
# Configuration Variables
# ============================================================================

# Path to traffic configuration file
CONFIG ?= configs/traffic/traffic_config.yaml

# Path to topology file
TOPOLOGY ?= topology/clab-ecmp-test.yml

# Results directory
RESULTS_DIR ?= results

# Enable verbose output (set to 1 for verbose)
VERBOSE ?= 0

# Test scenario
SCENARIO ?= basic_distribution

# Test duration in seconds (overrides config)
DURATION ?=

# Packet count per source (overrides config)
PACKET_COUNT ?=

# ============================================================================
# Internal Variables
# ============================================================================

# Script directory
SCRIPT_DIR := scripts

# Project root (assumed to be current directory)
PROJECT_ROOT := $(shell pwd)

# Log directory
LOG_DIR := $(PROJECT_ROOT)/logs

# Timestamp for test runs
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

# Test ID
TEST_ID := ecmp-test-$(TIMESTAMP)-$(SCENARIO)

# Color codes for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_RED := \033[0;31m
COLOR_GREEN := \033[0;32m
COLOR_YELLOW := \033[1;33m
COLOR_BLUE := \033[0;34m
COLOR_MAGENTA := \033[0;35m
COLOR_CYAN := \033[0;36m

# Verbosity flag for scripts
VERBOSE_FLAG := $(shell [ $(VERBOSE) -eq 1 ] && echo "--verbose" || echo "")

# ============================================================================
# Helper Functions
# ============================================================================

# Print banner
define print_banner
	echo ""
	echo "$(COLOR_CYAN)========================================$(COLOR_RESET)"
	echo "$(COLOR_BOLD)$(COLOR_CYAN)  $(1)$(COLOR_RESET)"
	echo "$(COLOR_CYAN)========================================$(COLOR_RESET)"
	echo ""
endef

# Print success message
define print_success
	echo "$(COLOR_GREEN)✓ $(1)$(COLOR_RESET)"
endef

# Print error message
define print_error
	echo "$(COLOR_RED)✗ $(1)$(COLOR_RESET)" >&2
endef

# Print info message
define print_info
	echo "$(COLOR_BLUE)ℹ $(1)$(COLOR_RESET)"
endef

# Print warning message
define print_warning
	echo "$(COLOR_YELLOW)⚠ $(1)$(COLOR_RESET)"
endef

# Check if command exists
define command_exists
	command -v $(1) >/dev/null 2>&1 || { \
		$(call print_error,"Required command not found: $(1)"); \
		exit 1; \
	}
endef

# ============================================================================
# PHONY Targets
# ============================================================================

.PHONY: all
all: deploy configure test analyze report
	$(call print_banner,"Complete Test Suite Finished")
	$(call print_success,"All operations completed successfully")
	@echo ""
	@echo "Results available in: $(RESULTS_DIR)"
	@echo "Allure report: $(RESULTS_DIR)/allure-report/index.html"
	@echo ""

.PHONY: all-python
all-python: deploy-python configure test analyze-python report-python
	$(call print_banner,"Complete Test Suite Finished (Python)")
	$(call print_success,"All operations completed successfully")
	@echo ""
	@echo "Results available in: $(RESULTS_DIR)"
	@echo "Allure report: $(RESULTS_DIR)/allure-report/index.html"
	@echo ""

.PHONY: deploy
deploy:
	$(call print_banner,"Deploying ECMP Topology")
	@$(MAKE) check-deps
	@$(call print_info,"Deploying topology from: $(TOPOLOGY)")
	@if [ $(VERBOSE) -eq 1 ]; then \
		bash $(SCRIPT_DIR)/deploy_topology.sh --verbose; \
	else \
		bash $(SCRIPT_DIR)/deploy_topology.sh; \
	fi
	$(call print_success,"Topology deployed successfully")
	@echo ""
	@echo "Next steps:"
	@echo "  make configure    # Configure ECMP on routers"
	@echo ""

.PHONY: configure
configure:
	$(call print_banner,"Configuring ECMP")
	@$(MAKE) check-topology
	@$(call print_info,"Configuring ECMP on all routers")
	@if [ $(VERBOSE) -eq 1 ]; then \
		bash $(SCRIPT_DIR)/configure_ecmp.sh --verbose; \
	else \
		bash $(SCRIPT_DIR)/configure_ecmp.sh; \
	fi
	$(call print_success,"ECMP configured successfully")
	@echo ""
	@echo "Next steps:"
	@echo "  make test         # Run traffic test"
	@echo ""

.PHONY: test
test:
	$(call print_banner,"Running Traffic Test")
	@$(MAKE) check-topology
	@$(call print_info,"Running test with scenario: $(SCENARIO)")
	@mkdir -p $(LOG_DIR)
	@if [ -n "$(DURATION)" ]; then \
		if [ $(VERBOSE) -eq 1 ]; then \
			bash $(SCRIPT_DIR)/run_test.sh --scenario $(SCENARIO) --duration $(DURATION) --verbose; \
		else \
			bash $(SCRIPT_DIR)/run_test.sh --scenario $(SCENARIO) --duration $(DURATION); \
		fi \
	else \
		if [ $(VERBOSE) -eq 1 ]; then \
			bash $(SCRIPT_DIR)/run_test.sh --scenario $(SCENARIO) --verbose; \
		else \
			bash $(SCRIPT_DIR)/run_test.sh --scenario $(SCENARIO); \
		fi \
	fi
	$(call print_success,"Traffic test completed successfully")
	@echo ""
	@echo "Next steps:"
	@echo "  make analyze      # Analyze test results"
	@echo ""

.PHONY: analyze
analyze:
	$(call print_banner,"Analyzing Test Results")
	@$(call print_info,"Analyzing results from: $(RESULTS_DIR)/captures")
	@if [ $(VERBOSE) -eq 1 ]; then \
		bash $(SCRIPT_DIR)/analyze_results.sh --verbose; \
	else \
		bash $(SCRIPT_DIR)/analyze_results.sh; \
	fi
	$(call print_success,"Analysis completed successfully")
	@echo ""
	@echo "Analysis results available in: $(RESULTS_DIR)/analysis"
	@echo ""
	@echo "Next steps:"
	@echo "  make report       # Generate reports"
	@echo ""

.PHONY: report
report:
	$(call print_banner,"Generating Reports")
	@$(call print_info,"Generating Allure report")
	@if [ $(VERBOSE) -eq 1 ]; then \
		bash $(SCRIPT_DIR)/generate_allure_report.sh --verbose; \
	else \
		bash $(SCRIPT_DIR)/generate_allure_report.sh; \
	fi
	$(call print_success,"Reports generated successfully")
	@echo ""
	@echo "Allure report: $(RESULTS_DIR)/allure-report/index.html"
	@echo "To view the report, run: make open-report"
	@echo ""

.PHONY: deploy-python
deploy-python:
	$(call print_banner,"Deploying ECMP Topology (Python)")
	@$(call command_exists,python3)
	@python3 -c "import yaml" 2>/dev/null || { \
		$(call print_error,"PyYAML Python module not found. Install with: pip install pyyaml"); \
		exit 1; \
	}
	@$(call print_info,"Deploying topology using Python script")
	@if [ $(VERBOSE) -eq 1 ]; then \
		python3 $(SCRIPT_DIR)/deploy.py --verbose; \
	else \
		python3 $(SCRIPT_DIR)/deploy.py; \
	fi
	$(call print_success,"Topology deployed successfully (Python)")
	@echo ""

.PHONY: traffic-gen-python
traffic-gen-python:
	$(call print_banner,"Generating Traffic (Python)")
	@$(call command_exists,python3)
	@python3 -c "import yaml" 2>/dev/null || { \
		$(call print_error,"PyYAML Python module not found. Install with: pip install pyyaml"); \
		exit 1; \
	}
	@$(call print_info,"Generating traffic using Python script")
	@if [ $(VERBOSE) -eq 1 ]; then \
		python3 $(SCRIPT_DIR)/traffic_gen.py --verbose; \
	else \
		python3 $(SCRIPT_DIR)/traffic_gen.py; \
	fi
	$(call print_success,"Traffic generation completed (Python)")
	@echo ""

.PHONY: analyze-python
analyze-python:
	$(call print_banner,"Analyzing Test Results (Python)")
	@$(call command_exists,python3)
	@python3 -c "import yaml; import numpy; import scipy" 2>/dev/null || { \
		$(call print_error,"Required Python modules not found. Install with: pip install pyyaml numpy scipy"); \
		exit 1; \
	}
	@$(call print_info,"Analyzing results using Python script")
	@if [ $(VERBOSE) -eq 1 ]; then \
		python3 $(SCRIPT_DIR)/analyzer.py --verbose; \
	else \
		python3 $(SCRIPT_DIR)/analyzer.py; \
	fi
	$(call print_success,"Analysis completed successfully (Python)")
	@echo ""

.PHONY: report-python
report-python:
	$(call print_banner,"Generating Reports (Python)")
	@$(call command_exists,python3)
	@python3 -c "import yaml; import matplotlib" 2>/dev/null || { \
		$(call print_error,"Required Python modules not found. Install with: pip install pyyaml matplotlib"); \
		exit 1; \
	}
	@$(call print_info,"Generating reports using Python script")
	@if [ $(VERBOSE) -eq 1 ]; then \
		python3 $(SCRIPT_DIR)/report_gen.py --verbose; \
	else \
		python3 $(SCRIPT_DIR)/report_gen.py; \
	fi
	$(call print_success,"Reports generated successfully (Python)")
	@echo ""

.PHONY: clean
clean:
	$(call print_banner,"Cleaning Up")
	@$(call print_info,"Destroying topology and cleaning results")
	@if [ -f "$(TOPOLOGY)" ]; then \
		if command -v clab >/dev/null 2>&1; then \
			clab destroy -t $(TOPOLOGY) --cleanup 2>/dev/null || true; \
			$(call print_success,"Topology destroyed"); \
		else \
			$(call print_warning,"Containerlab not found, skipping topology destruction"); \
		fi \
	else \
		$(call print_warning,"Topology file not found: $(TOPOLOGY)"); \
	fi
	@rm -rf $(RESULTS_DIR)/* 2>/dev/null || true
	@rm -rf $(LOG_DIR)/* 2>/dev/null || true
	@rm -rf captures/*.pcap 2>/dev/null || true
	$(call print_success,"Cleanup completed")
	@echo ""

.PHONY: render-topology
render-topology:
	$(call print_banner,"Rendering Topology Templates")
	@$(call command_exists,python3)
	@python3 -c "import jinja2" 2>/dev/null || { \
		$(call print_error,"jinja2 Python module not found. Install with: pip install jinja2"); \
		exit 1; \
	}
	@if [ -z "$(N)" ]; then \
		echo "$(COLOR_BLUE)ℹ Rendering topology with 4 ECMP paths (default)$(COLOR_RESET)"; \
		if [ $(VERBOSE) -eq 1 ]; then \
			python3 $(SCRIPT_DIR)/render_topology.py --num-paths 4 --verbose; \
		else \
			python3 $(SCRIPT_DIR)/render_topology.py --num-paths 4; \
		fi \
	else \
		echo "$(COLOR_BLUE)ℹ Rendering topology with $(N) ECMP paths$(COLOR_RESET)"; \
		if [ $(VERBOSE) -eq 1 ]; then \
			python3 $(SCRIPT_DIR)/render_topology.py --num-paths $(N) --verbose; \
		else \
			python3 $(SCRIPT_DIR)/render_topology.py --num-paths $(N); \
		fi \
	fi
	$(call print_success,"Topology templates rendered successfully")
	@echo ""
	@echo "Generated files:"
	@echo "  - topology/clab-ecmp-$(N)-paths.yml (or clab-ecmp-4paths.yml if N not specified)"
	@echo "  - topology/frr/ecmp-router.conf"
	@echo "  - topology/frr/nexthop-*.conf"
	@echo ""
	@echo "Next steps:"
	@echo "  make TOPOLOGY=topology/clab-ecmp-$(N)-paths.yml deploy"
	@echo ""

.PHONY: ci-test
ci-test: all clean
	$(call print_banner,"CI Pipeline Completed")
	$(call print_success,"CI test pipeline finished successfully")
	@echo ""

.PHONY: help
help:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_CYAN)ECMP Testing Framework - Makefile Help$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Quick Start (for beginners):$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)quick-test$(COLOR_RESET)     Run complete test with one command"
	@echo "  $(COLOR_GREEN)quick-deploy$(COLOR_RESET)   Deploy and configure topology"
	@echo "  $(COLOR_GREEN)quick-report$(COLOR_RESET)   Generate reports from results"
	@echo "  $(COLOR_GREEN)quick-help$(COLOR_RESET)     Show Quick Start help"
	@echo ""
	@echo "$(COLOR_BOLD)Standard Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)all$(COLOR_RESET)           Run complete test suite (deploy, configure, test, analyze, report)"
	@echo "  $(COLOR_GREEN)all-python$(COLOR_RESET)    Run complete test suite using Python scripts"
	@echo "  $(COLOR_GREEN)deploy$(COLOR_RESET)        Deploy topology using containerlab (bash)"
	@echo "  $(COLOR_GREEN)deploy-python$(COLOR_RESET) Deploy topology using Python script"
	@echo "  $(COLOR_GREEN)configure$(COLOR_RESET)     Configure ECMP on all routers"
	@echo "  $(COLOR_GREEN)test$(COLOR_RESET)          Run complete traffic test (capture, generate traffic, stop capture)"
	@echo "  $(COLOR_GREEN)analyze$(COLOR_RESET)       Analyze test results and generate statistics (bash)"
	@echo "  $(COLOR_GREEN)analyze-python$(COLOR_RESET) Analyze test results using Python script"
	@echo "  $(COLOR_GREEN)report$(COLOR_RESET)        Generate Allure reports (bash)"
	@echo "  $(COLOR_GREEN)report-python$(COLOR_RESET) Generate reports using Python script"
	@echo "  $(COLOR_GREEN)traffic-gen-python$(COLOR_RESET) Generate traffic using Python script"
	@echo "  $(COLOR_GREEN)clean$(COLOR_RESET)         Destroy topology and cleanup results"
	@echo "  $(COLOR_GREEN)render-topology$(COLOR_RESET) Render topology templates with N ECMP paths"
	@echo "  $(COLOR_GREEN)ci-test$(COLOR_RESET)       Run full CI pipeline (all + clean)"
	@echo "  $(COLOR_GREEN)help$(COLOR_RESET)          Display this help message"
	@echo ""
	@echo "$(COLOR_BOLD)Utility Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_YELLOW)check-deps$(COLOR_RESET)    Check if all required dependencies are installed"
	@echo "  $(COLOR_YELLOW)check-topology$(COLOR_RESET) Check if topology is deployed"
	@echo "  $(COLOR_YELLOW)open-report$(COLOR_RESET)   Open Allure report in browser"
	@echo "  $(COLOR_YELLOW)status$(COLOR_RESET)        Show topology and test status"
	@echo "  $(COLOR_YELLOW)logs$(COLOR_RESET)         Show recent log files"
	@echo ""
	@echo "$(COLOR_BOLD)Variables:$(COLOR_RESET)"
	@echo "  $(COLOR_CYAN)CONFIG$(COLOR_RESET)         Path to traffic configuration file (default: configs/traffic/traffic_config.yaml)"
	@echo "  $(COLOR_CYAN)TOPOLOGY$(COLOR_RESET)       Path to topology file (default: topology/clab-ecmp-test.yml)"
	@echo "  $(COLOR_CYan)RESULTS_DIR$(COLOR_RESET)    Results directory (default: results)"
	@echo "  $(COLOR_CYAN)VERBOSE$(COLOR_RESET)        Enable verbose output (default: 0, set to 1 to enable)"
	@echo "  $(COLOR_CYAN)SCENARIO$(COLOR_RESET)      Test scenario to execute (default: basic_distribution)"
	@echo "  $(COLOR_CYAN)DURATION$(COLOR_RESET)       Test duration in seconds (overrides config)"
	@echo "  $(COLOR_CYan)PACKET_COUNT$(COLOR_RESET)   Number of packets per source (overrides config)"
	@echo ""
	@echo "$(COLOR_BOLD)Examples:$(COLOR_RESET)"
	@echo "  make all"
	@echo "  make deploy"
	@echo "  make test SCENARIO=high_volume"
	@echo "  make test DURATION=120 PACKET_COUNT=5000"
	@echo "  make VERBOSE=1 all"
	@echo "  make clean"
	@echo "  make render-topology N=2"
	@echo "  make render-topology N=3"
	@echo "  make render-topology N=4"
	@echo "  make TOPOLOGY=topology/clab-ecmp-2paths.yml deploy"
	@echo ""

# ============================================================================
# Utility Targets
# ============================================================================

.PHONY: check-deps
check-deps:
	@$(call print_banner,"Checking Dependencies")
	@$(call command_exists,docker)
	@$(call command_exists,clab)
	@$(call command_exists,bash)
	@$(call command_exists,tcpdump)
	@$(call command_exists,hping3)
	@$(call command_exists,jq)
	@$(call command_exists,allure)
	@$(call command_exists,python3)
	@python3 -c "import jinja2" 2>/dev/null || { \
		$(call print_error,"jinja2 Python module not found. Install with: pip install jinja2"); \
		exit 1; \
	}
	@$(call print_success,"All dependencies satisfied")
	@echo ""

.PHONY: check-topology
check-topology:
	@if ! docker ps --format '{{.Names}}' | grep -q "clab-ecmp-test"; then \
		$(call print_error,"ECMP topology is not deployed"); \
		$(call print_info,"Deploy topology first using: make deploy"); \
		exit 1; \
	fi
	$(call print_success,"Topology is deployed")
	@echo ""

.PHONY: open-report
open-report:
	@if [ -f "$(RESULTS_DIR)/allure-report/index.html" ]; then \
		$(call print_info,"Opening Allure report in browser..."); \
		if command -v open >/dev/null 2>&1; then \
			open $(RESULTS_DIR)/allure-report/index.html; \
		elif command -v xdg-open >/dev/null 2>&1; then \
			xdg-open $(RESULTS_DIR)/allure-report/index.html; \
		else \
			$(call print_warning,"Cannot open browser automatically"); \
			$(call print_info,"Open manually: file://$(PWD)/$(RESULTS_DIR)/allure-report/index.html"); \
		fi \
	else \
		$(call print_error,"Allure report not found"); \
		$(call print_info,"Generate report first using: make report"); \
		exit 1; \
	fi

.PHONY: status
status:
	$(call print_banner,"Topology and Test Status")
	@echo ""
	@echo "$(COLOR_BOLD)Container Status:$(COLOR_RESET)"
	@docker ps --filter "name=clab-ecmp-test-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No containers running"
	@echo ""
	@echo "$(COLOR_BOLD)ECMP Routes on Edge Router (R1):$(COLOR_RESET)"
	@docker exec clab-ecmp-test-r1 vtysh -c "show ip route 192.168.100.0/24" 2>/dev/null || echo "Cannot retrieve routes"
	@echo ""
	@echo "$(COLOR_BOLD)Results Directory:$(COLOR_RESET)"
	@ls -lh $(RESULTS_DIR) 2>/dev/null || echo "No results found"
	@echo ""

.PHONY: logs
logs:
	$(call print_banner,"Recent Log Files")
	@echo ""
	@if [ -d "$(LOG_DIR)" ]; then \
		echo "$(COLOR_BOLD)Available log files:$(COLOR_RESET)"; \
		ls -lh $(LOG_DIR) 2>/dev/null || echo "No log files found"; \
		echo ""; \
		if [ -f "$(LOG_DIR)/deploy_topology.log" ]; then \
			echo "$(COLOR_BOLD)=== Deploy Topology Log (last 20 lines) ===$(COLOR_RESET)"; \
			tail -20 $(LOG_DIR)/deploy_topology.log; \
			echo ""; \
		fi; \
		if [ -f "$(LOG_DIR)/configure_ecmp.log" ]; then \
			echo "$(COLOR_BOLD)=== Configure ECMP Log (last 20 lines) ===$(COLOR_RESET)"; \
			tail -20 $(LOG_DIR)/configure_ecmp.log; \
			echo ""; \
		fi; \
		if [ -f "$(LOG_DIR)/test_execution.log" ]; then \
			echo "$(COLOR_BOLD)=== Test Execution Log (last 20 lines) ===$(COLOR_RESET)"; \
			tail -20 $(LOG_DIR)/test_execution.log; \
			echo ""; \
		fi; \
	else \
		$(call print_warning,"Log directory not found: $(LOG_DIR)"); \
	fi

# ============================================================================
# Quick Start Targets
# ============================================================================
# These targets provide simplified one-command workflows for beginners
# They use sensible defaults and hide complexity

# Quick Start configuration file
QUICK_CONFIG := config/quick_start.yaml

.PHONY: quick-test
quick-test:
	$(call print_banner,"Quick Start Test")
	@$(call print_info,"Running quick test with simplified configuration")
	@$(call print_info,"Configuration: $(QUICK_CONFIG)")
	@$(MAKE) check-deps
	@$(MAKE) deploy CONFIG=$(QUICK_CONFIG)
	@$(MAKE) configure CONFIG=$(QUICK_CONFIG)
	@$(MAKE) test CONFIG=$(QUICK_CONFIG) SCENARIO=basic_distribution
	@$(MAKE) analyze CONFIG=$(QUICK_CONFIG)
	@$(MAKE) report CONFIG=$(QUICK_CONFIG)
	$(call print_success,"Quick Start test completed successfully")
	@echo ""
	@echo "Results available in: $(RESULTS_DIR)"
	@echo "Allure report: $(RESULTS_DIR)/allure-report/index.html"
	@echo "To view the report, run: make open-report"
	@echo ""
	@echo "Next steps:"
	@echo "  make open-report    # View the test report"
	@echo "  make quick-help     # Learn more about Quick Start mode"
	@echo "  make help           # See all available commands"
	@echo ""

.PHONY: quick-deploy
quick-deploy:
	$(call print_banner,"Quick Start Deploy")
	@$(call print_info,"Deploying topology with simplified configuration")
	@$(call print_info,"Configuration: $(QUICK_CONFIG)")
	@$(MAKE) check-deps
	@$(MAKE) deploy CONFIG=$(QUICK_CONFIG)
	@$(MAKE) configure CONFIG=$(QUICK_CONFIG)
	$(call print_success,"Topology deployed and configured successfully")
	@echo ""
	@echo "Next steps:"
	@echo "  make quick-test     # Run the complete test"
	@echo "  make quick-report   # Generate reports only"
	@echo ""

.PHONY: quick-report
quick-report:
	$(call print_banner,"Quick Start Report")
	@$(call print_info,"Generating reports with simplified configuration")
	@$(call print_info,"Configuration: $(QUICK_CONFIG)")
	@$(MAKE) analyze CONFIG=$(QUICK_CONFIG)
	@$(MAKE) report CONFIG=$(QUICK_CONFIG)
	$(call print_success,"Reports generated successfully")
	@echo ""
	@echo "Allure report: $(RESULTS_DIR)/allure-report/index.html"
	@echo "To view the report, run: make open-report"
	@echo ""

.PHONY: quick-help
quick-help:
	@echo ""
	@echo "$(COLOR_BOLD)$(COLOR_CYAN)Quick Start Mode - ECMP Testing Framework$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Quick Start provides simplified one-command workflows for beginners.$(COLOR_RESET)"
	@echo "It uses sensible defaults and hides complexity while maintaining full"
	@echo "compatibility with all advanced features."
	@echo ""
	@echo "$(COLOR_BOLD)Quick Start Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make quick-test$(COLOR_RESET)     Run complete test (deploy, configure, test, analyze, report)"
	@echo "  $(COLOR_GREEN)make quick-deploy$(COLOR_RESET)   Deploy and configure topology only"
	@echo "  $(COLOR_GREEN)make quick-report$(COLOR_RESET)   Generate reports from existing results"
	@echo "  $(COLOR_GREEN)make quick-help$(COLOR_RESET)     Show this help message"
	@echo ""
	@echo "$(COLOR_BOLD)Configuration Modes:$(COLOR_RESET)"
	@echo "  $(COLOR_CYAN)Quick Start$(COLOR_RESET)   config/quick_start.yaml   - Minimal config for beginners"
	@echo "  $(COLOR_CYAN)Standard$(COLOR_RESET)      config/standard.yaml      - Balanced config for typical use"
	@echo "  $(COLOR_CYAN)Advanced$(COLOR_RESET)      config/advanced.yaml      - Full-featured config"
	@echo ""
	@echo "$(COLOR_BOLD)Quick Start Workflow:$(COLOR_RESET)"
	@echo "  1. Run: $(COLOR_GREEN)make quick-test$(COLOR_RESET)"
	@echo "  2. View results: $(COLOR_GREEN)make open-report$(COLOR_RESET)"
	@echo "  3. Done! (No configuration needed)"
	@echo ""
	@echo "$(COLOR_BOLD)When to use each mode:$(COLOR_RESET)"
	@echo "  $(COLOR_CYAN)Quick Start$(COLOR_RESET)  - First time users, quick validation, learning"
	@echo "  $(COLOR_CYAN)Standard$(COLOR_RESET)     - Most use cases, balanced features"
	@echo "  $(COLOR_CYAN)Advanced$(COLOR_RESET)     - Production testing, compliance, custom scenarios"
	@echo ""
	@echo "$(COLOR_BOLD)Examples:$(COLOR_RESET)"
	@echo "  make quick-test                    # Run with Quick Start config"
	@echo "  make test CONFIG=config/standard.yaml  # Run with Standard config"
	@echo "  make test CONFIG=config/advanced.yaml  # Run with Advanced config"
	@echo ""
	@echo "$(COLOR_BOLD)Documentation:$(COLOR_RESET)"
	@echo "  docs/QUICK_START_GUIDE.md  - Detailed Quick Start guide"
	@echo "  README.md                  - Full documentation"
	@echo "  docs/QWEN_COMPARISON.md   - Comparison with QWEN's approach"
	@echo ""
	@echo "$(COLOR_BOLD)Getting Help:$(COLOR_RESET)"
	@echo "  make help           - Show all available commands"
	@echo "  make quick-help     - Show this Quick Start help"
	@echo ""

# ============================================================================
# Advanced Targets
# ============================================================================

.PHONY: validate
validate:
	$(call print_banner,"Validating Implementation")
	@$(call print_info,"Running validation checks")
	@if [ -f "$(SCRIPT_DIR)/validate_implementation.sh" ]; then \
		bash $(SCRIPT_DIR)/validate_implementation.sh; \
	else \
		$(call print_warning,"Validation script not found"); \
	fi

.PHONY: show-config
show-config:
	@echo ""
	@echo "$(COLOR_BOLD)Current Configuration:$(COLOR_RESET)"
	@echo "  CONFIG:        $(CONFIG)"
	@echo "  TOPOLOGY:      $(TOPOLOGY)"
	@echo "  RESULTS_DIR:   $(RESULTS_DIR)"
	@echo "  VERBOSE:       $(VERBOSE)"
	@echo "  SCENARIO:      $(SCENARIO)"
	@echo "  DURATION:      $(DURATION)"
	@echo "  PACKET_COUNT:  $(PACKET_COUNT)"
	@echo "  TEST_ID:       $(TEST_ID)"
	@echo ""

# ============================================================================
# File-based Targets
# ============================================================================

# Mark results directory as a file target
$(RESULTS_DIR):
	@mkdir -p $(RESULTS_DIR)/captures
	@mkdir -p $(RESULTS_DIR)/analysis
	@mkdir -p $(RESULTS_DIR)/reports
	@mkdir -p $(RESULTS_DIR)/allure-results
	@mkdir -p $(RESULTS_DIR)/allure-report
	@mkdir -p $(RESULTS_DIR)/archives

# Mark log directory as a file target
$(LOG_DIR):
	@mkdir -p $(LOG_DIR)

# ============================================================================
# Default Target
# ============================================================================

.DEFAULT_GOAL := help
