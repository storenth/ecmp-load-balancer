#!/usr/bin/env python3
"""
Utility Functions Module for ECMP Testing Framework

This module provides common utility functions used across all Python scripts
in the ECMP testing framework, including configuration loading, logging,
network utilities, statistical helpers, and file I/O operations.

Author: ECMP Testing Framework
Version: 1.0.0
"""

import os
import sys
import yaml
import logging
import json
import subprocess
import shutil
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union
from functools import wraps
from datetime import datetime
import hashlib


# =============================================================================
# Configuration Loading
# =============================================================================

def load_config(config_path: str = "config/test_config.yaml") -> Dict[str, Any]:
    """
    Load configuration from YAML file.
    
    Args:
        config_path: Path to the configuration file (relative to project root)
        
    Returns:
        Dictionary containing configuration data
        
    Raises:
        FileNotFoundError: If configuration file doesn't exist
        yaml.YAMLError: If YAML parsing fails
    """
    # Get project root directory
    project_root = Path(__file__).parent.parent
    config_file = project_root / config_path
    
    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_file}")
    
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
    
    return config


def get_project_root() -> Path:
    """
    Get the project root directory.
    
    Returns:
        Path object pointing to project root
    """
    return Path(__file__).parent.parent


def ensure_directory(path: Union[str, Path]) -> Path:
    """
    Ensure a directory exists, creating it if necessary.
    
    Args:
        path: Directory path to ensure exists
        
    Returns:
        Path object for the directory
    """
    dir_path = Path(path)
    dir_path.mkdir(parents=True, exist_ok=True)
    return dir_path


# =============================================================================
# Logging Setup
# =============================================================================

def setup_logging(
    name: str,
    level: str = "INFO",
    log_file: Optional[str] = None,
    console: bool = True,
    format_string: Optional[str] = None
) -> logging.Logger:
    """
    Set up logging for a module.
    
    Args:
        name: Logger name (typically __name__)
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional path to log file
        console: Whether to output to console
        format_string: Custom format string (optional)
        
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Remove existing handlers
    logger.handlers.clear()
    
    # Default format
    if format_string is None:
        format_string = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    formatter = logging.Formatter(format_string)
    
    # Console handler
    if console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    
    # File handler
    if log_file:
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger


# =============================================================================
# Network Utilities
# =============================================================================

def validate_ip_address(ip: str) -> bool:
    """
    Validate IPv4 address format.
    
    Args:
        ip: IP address string to validate
        
    Returns:
        True if valid IPv4 address, False otherwise
    """
    parts = ip.split('.')
    if len(parts) != 4:
        return False
    
    try:
        return all(0 <= int(part) <= 255 for part in parts)
    except ValueError:
        return False


def validate_port(port: int) -> bool:
    """
    Validate port number.
    
    Args:
        port: Port number to validate
        
    Returns:
        True if valid port (1-65535), False otherwise
    """
    return 1 <= port <= 65535


def parse_ip_range(ip_range: str) -> List[str]:
    """
    Parse IP range string into list of IP addresses.
    
    Supports formats:
    - "192.168.1.10-192.168.1.50" (range)
    - "192.168.1.10/32" (single IP)
    - "192.168.1.10" (single IP)
    
    Args:
        ip_range: IP range string
        
    Returns:
        List of IP addresses
        
    Raises:
        ValueError: If IP range format is invalid
    """
    if '-' in ip_range:
        # Range format: start-end
        start_ip, end_ip = ip_range.split('-')
        start_parts = list(map(int, start_ip.split('.')))
        end_parts = list(map(int, end_ip.split('.')))
        
        ips = []
        current = start_parts.copy()
        
        while current <= end_parts:
            ips.append('.'.join(map(str, current)))
            # Increment IP
            for i in range(3, -1, -1):
                current[i] += 1
                if current[i] <= 255:
                    break
                current[i] = 0
        
        return ips
    
    elif '/' in ip_range:
        # CIDR notation (simplified - only supports /32 for single IP)
        ip, prefix = ip_range.split('/')
        if prefix == '32':
            return [ip]
        else:
            raise ValueError(f"Only /32 prefix supported, got /{prefix}")
    
    else:
        # Single IP
        if validate_ip_address(ip_range):
            return [ip_range]
        else:
            raise ValueError(f"Invalid IP address: {ip_range}")


def run_command(
    command: List[str],
    cwd: Optional[str] = None,
    capture_output: bool = True,
    check: bool = True,
    timeout: Optional[int] = None
) -> subprocess.CompletedProcess:
    """
    Run a shell command with proper error handling.
    
    Args:
        command: Command as list of strings
        cwd: Working directory (optional)
        capture_output: Whether to capture stdout/stderr
        check: Whether to raise exception on non-zero exit code
        timeout: Timeout in seconds (optional)
        
    Returns:
        CompletedProcess object
        
    Raises:
        subprocess.TimeoutExpired: If command times out
        subprocess.CalledProcessError: If command fails and check=True
    """
    logger = logging.getLogger(__name__)
    
    logger.debug(f"Running command: {' '.join(command)}")
    
    result = subprocess.run(
        command,
        cwd=cwd,
        capture_output=capture_output,
        text=True,
        check=check,
        timeout=timeout
    )
    
    if capture_output and result.stdout:
        logger.debug(f"Command output: {result.stdout[:200]}")
    
    return result


# =============================================================================
# Statistical Helper Functions
# =============================================================================

def calculate_mean(data: List[float]) -> float:
    """
    Calculate arithmetic mean of a dataset.
    
    Args:
        data: List of numeric values
        
    Returns:
        Mean value
        
    Raises:
        ValueError: If data is empty
    """
    if not data:
        raise ValueError("Cannot calculate mean of empty dataset")
    
    return sum(data) / len(data)


def calculate_variance(data: List[float], mean: Optional[float] = None) -> float:
    """
    Calculate variance of a dataset.
    
    Args:
        data: List of numeric values
        mean: Pre-calculated mean (optional, will be calculated if not provided)
        
    Returns:
        Variance value
        
    Raises:
        ValueError: If data is empty
    """
    if not data:
        raise ValueError("Cannot calculate variance of empty dataset")
    
    if mean is None:
        mean = calculate_mean(data)
    
    squared_diffs = [(x - mean) ** 2 for x in data]
    return sum(squared_diffs) / len(data)


def calculate_stddev(data: List[float], variance: Optional[float] = None) -> float:
    """
    Calculate standard deviation of a dataset.
    
    Args:
        data: List of numeric values
        variance: Pre-calculated variance (optional)
        
    Returns:
        Standard deviation value
    """
    if variance is None:
        variance = calculate_variance(data)
    
    return variance ** 0.5


def calculate_cv(data: List[float]) -> float:
    """
    Calculate coefficient of variation (CV).
    
    CV = (standard deviation / mean) * 100
    
    Args:
        data: List of numeric values
        
    Returns:
        Coefficient of variation as percentage
        
    Raises:
        ValueError: If mean is zero
    """
    mean = calculate_mean(data)
    if mean == 0:
        raise ValueError("Cannot calculate CV with zero mean")
    
    stddev = calculate_stddev(data)
    return (stddev / mean) * 100


def calculate_percentages(counts: List[int]) -> List[float]:
    """
    Calculate percentages from counts.
    
    Args:
        counts: List of integer counts
        
    Returns:
        List of percentages (sums to 100)
        
    Raises:
        ValueError: If total is zero
    """
    total = sum(counts)
    if total == 0:
        raise ValueError("Cannot calculate percentages with zero total")
    
    return [(count / total) * 100 for count in counts]


def calculate_distribution_variance(counts: List[int]) -> float:
    """
    Calculate maximum variance from uniform distribution.
    
    Args:
        counts: List of packet counts per path
        
    Returns:
        Maximum variance percentage from uniform distribution
    """
    num_paths = len(counts)
    total = sum(counts)
    
    if total == 0:
        raise ValueError("Cannot calculate distribution variance with zero total")
    
    expected_pct = 100.0 / num_paths
    actual_pcts = calculate_percentages(counts)
    
    max_variance = max(abs(pct - expected_pct) for pct in actual_pcts)
    return max_variance


# =============================================================================
# File I/O Utilities
# =============================================================================

def read_json(file_path: Union[str, Path]) -> Dict[str, Any]:
    """
    Read JSON file.
    
    Args:
        file_path: Path to JSON file
        
    Returns:
        Dictionary containing JSON data
        
    Raises:
        FileNotFoundError: If file doesn't exist
        json.JSONDecodeError: If JSON parsing fails
    """
    with open(file_path, 'r') as f:
        return json.load(f)


def write_json(data: Dict[str, Any], file_path: Union[str, Path], indent: int = 2) -> None:
    """
    Write data to JSON file.
    
    Args:
        data: Dictionary to write
        file_path: Path to output file
        indent: JSON indentation level
    """
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=indent, default=str)


def read_text_file(file_path: Union[str, Path]) -> str:
    """
    Read text file content.
    
    Args:
        file_path: Path to text file
        
    Returns:
        File content as string
        
    Raises:
        FileNotFoundError: If file doesn't exist
    """
    with open(file_path, 'r') as f:
        return f.read()


def write_text_file(content: str, file_path: Union[str, Path]) -> None:
    """
    Write content to text file.
    
    Args:
        content: String content to write
        file_path: Path to output file
    """
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(file_path, 'w') as f:
        f.write(content)


def append_text_file(content: str, file_path: Union[str, Path]) -> None:
    """
    Append content to text file.
    
    Args:
        content: String content to append
        file_path: Path to file
    """
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(file_path, 'a') as f:
        f.write(content)


def get_file_hash(file_path: Union[str, Path], algorithm: str = 'md5') -> str:
    """
    Calculate hash of a file.
    
    Args:
        file_path: Path to file
        algorithm: Hash algorithm (md5, sha1, sha256)
        
    Returns:
        Hexadecimal hash string
    """
    hash_func = hashlib.new(algorithm)
    
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            hash_func.update(chunk)
    
    return hash_func.hexdigest()


def find_files(
    directory: Union[str, Path],
    pattern: str,
    recursive: bool = True
) -> List[Path]:
    """
    Find files matching a pattern.
    
    Args:
        directory: Directory to search
        pattern: Glob pattern to match
        recursive: Whether to search recursively
        
    Returns:
        List of matching file paths
    """
    directory = Path(directory)
    
    if recursive:
        return list(directory.rglob(pattern))
    else:
        return list(directory.glob(pattern))


# =============================================================================
# Error Handling Decorators
# =============================================================================

def handle_errors(
    default_return: Any = None,
    log_errors: bool = True,
    reraise: bool = False
):
    """
    Decorator for handling errors in functions.
    
    Args:
        default_return: Value to return on error (optional)
        log_errors: Whether to log errors
        reraise: Whether to re-raise the exception
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            logger = logging.getLogger(func.__module__)
            
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if log_errors:
                    logger.error(f"Error in {func.__name__}: {str(e)}")
                
                if reraise:
                    raise
                
                return default_return
        
        return wrapper
    return decorator


def retry(
    max_attempts: int = 3,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: Tuple = (Exception,)
):
    """
    Decorator for retrying functions on failure.
    
    Args:
        max_attempts: Maximum number of retry attempts
        delay: Initial delay between retries in seconds
        backoff: Multiplier for delay after each retry
        exceptions: Tuple of exceptions to catch and retry
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            logger = logging.getLogger(func.__module__)
            current_delay = delay
            
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts - 1:
                        logger.error(
                            f"Function {func.__name__} failed after {max_attempts} attempts: {str(e)}"
                        )
                        raise
                    
                    logger.warning(
                        f"Attempt {attempt + 1}/{max_attempts} failed for {func.__name__}: {str(e)}. "
                        f"Retrying in {current_delay}s..."
                    )
                    import time
                    time.sleep(current_delay)
                    current_delay *= backoff
        
        return wrapper
    return decorator


# =============================================================================
# Time Utilities
# =============================================================================

def get_timestamp() -> str:
    """
    Get current timestamp in ISO 8601 format.
    
    Returns:
        Timestamp string
    """
    return datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')


def get_test_id() -> str:
    """
    Generate a unique test ID.
    
    Returns:
        Test ID string (format: YYYYMMDD_HHMMSS)
    """
    return datetime.utcnow().strftime('%Y%m%d_%H%M%S')


def parse_duration(duration_str: str) -> int:
    """
    Parse duration string to seconds.
    
    Supports formats:
    - "60" (seconds)
    - "1m" (minutes)
    - "1h" (hours)
    
    Args:
        duration_str: Duration string
        
    Returns:
        Duration in seconds
        
    Raises:
        ValueError: If format is invalid
    """
    duration_str = duration_str.strip().lower()
    
    if duration_str.isdigit():
        return int(duration_str)
    
    if duration_str.endswith('s'):
        return int(duration_str[:-1])
    elif duration_str.endswith('m'):
        return int(duration_str[:-1]) * 60
    elif duration_str.endswith('h'):
        return int(duration_str[:-1]) * 3600
    else:
        raise ValueError(f"Invalid duration format: {duration_str}")


# =============================================================================
# Validation Utilities
# =============================================================================

def validate_config(config: Dict[str, Any], required_keys: List[str]) -> bool:
    """
    Validate that configuration contains required keys.
    
    Args:
        config: Configuration dictionary
        required_keys: List of required key paths (e.g., ['test.name', 'topology.dst_ip'])
        
    Returns:
        True if all required keys are present
        
    Raises:
        ValueError: If any required key is missing
    """
    missing_keys = []
    
    for key_path in required_keys:
        keys = key_path.split('.')
        current = config
        
        try:
            for key in keys:
                current = current[key]
        except (KeyError, TypeError):
            missing_keys.append(key_path)
    
    if missing_keys:
        raise ValueError(f"Missing required configuration keys: {', '.join(missing_keys)}")
    
    return True


def validate_percentage(value: float, name: str = "value") -> bool:
    """
    Validate that a value is a valid percentage (0-100).
    
    Args:
        value: Value to validate
        name: Name of the value for error messages
        
    Returns:
        True if valid
        
    Raises:
        ValueError: If value is not in valid range
    """
    if not 0 <= value <= 100:
        raise ValueError(f"{name} must be between 0 and 100, got {value}")
    
    return True


def validate_positive(value: Union[int, float], name: str = "value") -> bool:
    """
    Validate that a value is positive.
    
    Args:
        value: Value to validate
        name: Name of the value for error messages
        
    Returns:
        True if valid
        
    Raises:
        ValueError: If value is not positive
    """
    if value <= 0:
        raise ValueError(f"{name} must be positive, got {value}")
    
    return True


# =============================================================================
# Progress Reporting
# =============================================================================

class ProgressReporter:
    """Simple progress reporter for long-running operations."""
    
    def __init__(self, total: int, description: str = "Progress"):
        """
        Initialize progress reporter.
        
        Args:
            total: Total number of items to process
            description: Description of the operation
        """
        self.total = total
        self.current = 0
        self.description = description
        self.logger = logging.getLogger(__name__)
        self.last_reported = 0
    
    def update(self, increment: int = 1) -> None:
        """
        Update progress.
        
        Args:
            increment: Number of items completed
        """
        self.current += increment
        
        # Report at 0%, 25%, 50%, 75%, 100%
        percentage = (self.current / self.total) * 100
        thresholds = [0, 25, 50, 75, 100]
        
        for threshold in thresholds:
            if self.last_reported < threshold <= percentage:
                self.logger.info(f"{self.description}: {percentage:.0f}% ({self.current}/{self.total})")
                self.last_reported = threshold
    
    def complete(self) -> None:
        """Mark progress as complete."""
        self.current = self.total
        self.logger.info(f"{self.description}: 100% ({self.current}/{self.total}) - Complete")


# =============================================================================
# Main (for testing)
# =============================================================================

if __name__ == "__main__":
    # Test basic functionality
    logger = setup_logging(__name__, level="DEBUG")
    logger.info("Testing utils.py module")
    
    # Test config loading
    try:
        config = load_config()
        logger.info(f"Loaded config: {config['test']['name']}")
    except Exception as e:
        logger.warning(f"Could not load config: {e}")
    
    # Test statistical functions
    data = [10, 20, 30, 40, 50]
    logger.info(f"Mean: {calculate_mean(data)}")
    logger.info(f"Variance: {calculate_variance(data)}")
    logger.info(f"StdDev: {calculate_stddev(data)}")
    logger.info(f"CV: {calculate_cv(data)}")
    
    # Test IP parsing
    try:
        ips = parse_ip_range("192.168.1.10-192.168.1.12")
        logger.info(f"Parsed IPs: {ips}")
    except Exception as e:
        logger.warning(f"Could not parse IP range: {e}")
    
    logger.info("Utils module tests completed")
