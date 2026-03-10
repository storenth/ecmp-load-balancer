#!/bin/bash
#
# Cleanup Captures Script
#
# This script cleans up old capture files and temporary data from ECMP testing.
# It can remove capture files based on age, size, or specific patterns.
#
# Reference: Best practices for data management
# Architecture: ARCHITECTURE.md - Testing Framework Architecture
#
# Usage:
#   ./cleanup_captures.sh [options]
#
# Options:
#   -d, --directory DIR     Directory to clean (default: ../captures)
#   -a, --age DAYS          Remove files older than N days (default: 7)
#   -s, --size MB           Remove files larger than N MB
#   -p, --pattern PATTERN   Remove files matching pattern (default: *.pcap)
#   -n, --dry-run           Show what would be removed without actually removing
#   -v, --verbose           Enable verbose output
#   -h, --help              Show this help message
#
# Examples:
#   ./cleanup_captures.sh
#   ./cleanup_captures.sh --age 30
#   ./cleanup_captures.sh --pattern "test_*.pcap" --dry-run
#   ./cleanup_captures.sh --size 100

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default configuration
DIRECTORY="${PROJECT_ROOT}/captures"
AGE_DAYS=7
SIZE_MB=""
PATTERN="*.pcap"
DRY_RUN=false
VERBOSE=false

# Statistics
FILES_REMOVED=0
SPACE_FREED=0

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/cleanup_captures.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

# Print usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Clean up old capture files and temporary data from ECMP testing.

Options:
  -d, --directory DIR     Directory to clean (default: ../captures)
  -a, --age DAYS          Remove files older than N days (default: 7)
  -s, --size MB           Remove files larger than N MB
  -p, --pattern PATTERN   Remove files matching pattern (default: *.pcap)
  -n, --dry-run           Show what would be removed without actually removing
  -v, --verbose           Enable verbose output
  -h, --help              Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --age 30
  $(basename "$0") --pattern "test_*.pcap" --dry-run
  $(basename "$0") --size 100

EOF
}

# Log message with timestamp
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log to file
    echo "[${timestamp}] [${level^^}] ${message}" >> "$LOG_FILE"
    
    # Log to console based on level and verbosity
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "error" ]] || [[ "$level" == "warn" ]]; then
        case "$level" in
            error)
                echo -e "${RED}[ERROR]${NC} ${message}" >&2
                ;;
            warn)
                echo -e "${YELLOW}[WARN]${NC} ${message}" >&2
                ;;
            info)
                echo -e "${GREEN}[INFO]${NC} ${message}"
                ;;
            debug)
                echo -e "${BLUE}[DEBUG]${NC} ${message}"
                ;;
        esac
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--directory)
                DIRECTORY="$2"
                shift 2
                ;;
            -a|--age)
                AGE_DAYS="$2"
                shift 2
                ;;
            -s|--size)
                SIZE_MB="$2"
                shift 2
                ;;
            -p|--pattern)
                PATTERN="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if file should be removed based on age
should_remove_by_age() {
    local file="$1"
    local max_age_days="$2"
    
    # Get file modification time in seconds
    local file_mtime
    file_mtime=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null)
    
    # Get current time in seconds
    local current_time
    current_time=$(date +%s)
    
    # Calculate age in days
    local age_days
    age_days=$(( (current_time - file_mtime) / 86400 ))
    
    if [[ $age_days -ge $max_age_days ]]; then
        log debug "File $file is $age_days days old (threshold: $max_age_days days)"
        return 0
    else
        log debug "File $file is $age_days days old (threshold: $max_age_days days) - skipping"
        return 1
    fi
}

# Check if file should be removed based on size
should_remove_by_size() {
    local file="$1"
    local max_size_mb="$2"
    
    # Get file size in bytes
    local file_size_bytes
    file_size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    # Convert to MB
    local file_size_mb
    file_size_mb=$((file_size_bytes / 1024 / 1024))
    
    if [[ $file_size_mb -ge $max_size_mb ]]; then
        log debug "File $file is ${file_size_mb}MB (threshold: ${max_size_mb}MB)"
        return 0
    else
        log debug "File $file is ${file_size_mb}MB (threshold: ${max_size_mb}MB) - skipping"
        return 1
    fi
}

# Remove a single file
remove_file() {
    local file="$1"
    local reason="$2"
    
    # Get file size
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [[ "$DRY_RUN" == true ]]; then
        log info "[DRY RUN] Would remove: $file (${file_size} bytes) - $reason"
        ((FILES_REMOVED++))
        ((SPACE_FREED += file_size))
        return 0
    fi
    
    # Actually remove the file
    if rm -f "$file"; then
        log info "Removed: $file (${file_size} bytes) - $reason"
        ((FILES_REMOVED++))
        ((SPACE_FREED += file_size))
        return 0
    else
        log error "Failed to remove: $file"
        return 1
    fi
}

# Clean up directory
cleanup_directory() {
    local directory="$1"
    
    log info "Cleaning directory: $directory"
    
    # Check if directory exists
    if [[ ! -d "$directory" ]]; then
        log warn "Directory does not exist: $directory"
        return 0
    fi
    
    # Find files matching pattern
    local files
    files=$(find "$directory" -type f -name "$PATTERN" 2>/dev/null || true)
    
    if [[ -z "$files" ]]; then
        log info "No files found matching pattern: $PATTERN"
        return 0
    fi
    
    local file_count=0
    while IFS= read -r file; do
        ((file_count++))
        
        local remove=false
        local reason=""
        
        # Check age
        if [[ $AGE_DAYS -gt 0 ]]; then
            if should_remove_by_age "$file" "$AGE_DAYS"; then
                remove=true
                reason="older than ${AGE_DAYS} days"
            fi
        fi
        
        # Check size
        if [[ -n "$SIZE_MB" ]] && [[ $SIZE_MB -gt 0 ]]; then
            if should_remove_by_size "$file" "$SIZE_MB"; then
                remove=true
                if [[ -n "$reason" ]]; then
                    reason+=", larger than ${SIZE_MB}MB"
                else
                    reason="larger than ${SIZE_MB}MB"
                fi
            fi
        fi
        
        # If no criteria specified, remove all matching files
        if [[ $AGE_DAYS -eq 0 ]] && [[ -z "$SIZE_MB" ]]; then
            remove=true
            reason="matches pattern"
        fi
        
        # Remove file if criteria met
        if [[ "$remove" == true ]]; then
            remove_file "$file" "$reason"
        fi
    done <<< "$files"
    
    log info "Processed $file_count file(s)"
}

# Clean up log files
cleanup_logs() {
    local log_dir="${PROJECT_ROOT}/logs"
    
    log info "Cleaning log files older than ${AGE_DAYS} days"
    
    if [[ ! -d "$log_dir" ]]; then
        return 0
    fi
    
    # Find and remove old log files
    local old_logs
    old_logs=$(find "$log_dir" -type f -name "*.log" -mtime +$AGE_DAYS 2>/dev/null || true)
    
    if [[ -n "$old_logs" ]]; then
        while IFS= read -r log_file; do
            if [[ "$DRY_RUN" == true ]]; then
                log info "[DRY RUN] Would remove log: $log_file"
            else
                if rm -f "$log_file"; then
                    log info "Removed log: $log_file"
                fi
            fi
        done <<< "$old_logs"
    fi
}

# Print cleanup summary
print_summary() {
    local space_freed_mb
    space_freed_mb=$((SPACE_FREED / 1024 / 1024))
    
    echo ""
    echo "=========================================="
    echo "Cleanup Summary"
    echo "=========================================="
    echo "Directory: $DIRECTORY"
    echo "Pattern: $PATTERN"
    echo "Age threshold: ${AGE_DAYS} days"
    if [[ -n "$SIZE_MB" ]]; then
        echo "Size threshold: ${SIZE_MB}MB"
    fi
    echo "Dry run: $DRY_RUN"
    echo "------------------------------------------"
    echo "Files removed: $FILES_REMOVED"
    echo "Space freed: ${space_freed_mb}MB"
    echo "=========================================="
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Print summary
    print_summary
    
    # Clean up capture directory
    cleanup_directory "$DIRECTORY"
    
    # Clean up log files
    cleanup_logs
    
    # Final summary
    if [[ "$DRY_RUN" == true ]]; then
        log info "Dry run completed. No files were actually removed."
    else
        log info "Cleanup completed successfully"
    fi
    
    exit 0
}

# Execute main function
main "$@"
