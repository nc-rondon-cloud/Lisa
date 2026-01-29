#!/usr/bin/env bash
# =============================================================================
# Bash Function Template Examples
# =============================================================================
# This file provides well-structured function examples for bash scripting.
# Reference these patterns when writing new bash functions.
# =============================================================================

# -----------------------------------------------------------------------------
# Example 1: Simple Function with Validation
# -----------------------------------------------------------------------------
# Purpose: Demonstrate basic function structure with input validation
# Usage: greet_user "John"
# Returns: 0 on success, 1 on error
# -----------------------------------------------------------------------------
greet_user() {
    local name="$1"

    # Validate input
    if [[ -z "$name" ]]; then
        echo "Error: Name is required" >&2
        return 1
    fi

    echo "Hello, ${name}!"
    return 0
}

# -----------------------------------------------------------------------------
# Example 2: Function with Multiple Parameters
# -----------------------------------------------------------------------------
# Purpose: Process a file with options
# Usage: process_file "/path/to/file" "output_dir" [verbose]
# Arguments:
#   $1 - input_file (required): Path to input file
#   $2 - output_dir (required): Directory for output
#   $3 - verbose (optional): Set to "true" for verbose output
# Returns: 0 on success, 1 on error
# -----------------------------------------------------------------------------
process_file() {
    local input_file="$1"
    local output_dir="$2"
    local verbose="${3:-false}"

    # Validate required parameters
    if [[ -z "$input_file" ]]; then
        echo "Error: input_file is required" >&2
        return 1
    fi

    if [[ -z "$output_dir" ]]; then
        echo "Error: output_dir is required" >&2
        return 1
    fi

    # Check file exists
    if [[ ! -f "$input_file" ]]; then
        echo "Error: File not found: ${input_file}" >&2
        return 1
    fi

    # Create output directory if needed
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            echo "Error: Failed to create directory: ${output_dir}" >&2
            return 1
        }
    fi

    # Process the file
    if [[ "$verbose" == "true" ]]; then
        echo "Processing: ${input_file}"
        echo "Output to: ${output_dir}"
    fi

    # ... actual processing logic here ...

    return 0
}

# -----------------------------------------------------------------------------
# Example 3: Function Returning a Value
# -----------------------------------------------------------------------------
# Purpose: Calculate and return a result via stdout
# Usage: result=$(calculate_sum 5 10)
# Arguments:
#   $1 - num1 (required): First number
#   $2 - num2 (required): Second number
# Output: Sum of the two numbers (stdout)
# Returns: 0 on success, 1 on error
# -----------------------------------------------------------------------------
calculate_sum() {
    local num1="$1"
    local num2="$2"

    # Validate inputs are numbers
    if ! [[ "$num1" =~ ^-?[0-9]+$ ]]; then
        echo "Error: First argument must be a number" >&2
        return 1
    fi

    if ! [[ "$num2" =~ ^-?[0-9]+$ ]]; then
        echo "Error: Second argument must be a number" >&2
        return 1
    fi

    # Calculate and output result
    echo $((num1 + num2))
    return 0
}

# -----------------------------------------------------------------------------
# Example 4: Function with Logging Integration
# -----------------------------------------------------------------------------
# Purpose: Demonstrate function with integrated logging
# Usage: backup_file "/path/to/file"
# Requires: lisa-lib.sh to be sourced for logging functions
# Returns: 0 on success, 1 on error
# -----------------------------------------------------------------------------
backup_file() {
    local file_path="$1"
    local backup_dir="${2:-./backups}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Validate input
    if [[ -z "$file_path" ]]; then
        lisa_error "backup_file: file_path is required"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        lisa_error "backup_file: File not found: ${file_path}"
        return 1
    fi

    # Create backup directory
    if [[ ! -d "$backup_dir" ]]; then
        lisa_debug "Creating backup directory: ${backup_dir}"
        mkdir -p "$backup_dir" || {
            lisa_error "backup_file: Failed to create backup directory"
            return 1
        }
    fi

    # Perform backup
    local filename
    filename=$(basename "$file_path")
    local backup_path="${backup_dir}/${filename}.${timestamp}.bak"

    lisa_info "Backing up ${file_path} to ${backup_path}"

    if cp "$file_path" "$backup_path"; then
        lisa_info "Backup successful: ${backup_path}"
        echo "$backup_path"
        return 0
    else
        lisa_error "Backup failed for ${file_path}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Example 5: Function with Array Parameter
# -----------------------------------------------------------------------------
# Purpose: Process multiple items passed as arguments
# Usage: process_items "item1" "item2" "item3"
# Arguments: Variable number of items to process
# Returns: 0 on success, 1 if no items provided
# -----------------------------------------------------------------------------
process_items() {
    local items=("$@")

    # Validate we have items
    if [[ ${#items[@]} -eq 0 ]]; then
        echo "Error: At least one item is required" >&2
        return 1
    fi

    echo "Processing ${#items[@]} items..."

    local i=1
    for item in "${items[@]}"; do
        echo "  [${i}/${#items[@]}] Processing: ${item}"
        # ... process each item ...
        ((i++))
    done

    echo "Done processing all items"
    return 0
}

# -----------------------------------------------------------------------------
# Example 6: Function with Default Values
# -----------------------------------------------------------------------------
# Purpose: Show how to handle optional parameters with defaults
# Usage: create_config [config_dir] [config_name] [overwrite]
# Arguments:
#   $1 - config_dir (optional): Directory for config, default: ./config
#   $2 - config_name (optional): Config filename, default: settings.conf
#   $3 - overwrite (optional): Overwrite existing, default: false
# Returns: 0 on success, 1 on error
# -----------------------------------------------------------------------------
create_config() {
    local config_dir="${1:-./config}"
    local config_name="${2:-settings.conf}"
    local overwrite="${3:-false}"

    local config_path="${config_dir}/${config_name}"

    # Check if config already exists
    if [[ -f "$config_path" && "$overwrite" != "true" ]]; then
        echo "Config already exists: ${config_path}" >&2
        echo "Use overwrite=true to replace" >&2
        return 1
    fi

    # Ensure directory exists
    mkdir -p "$config_dir" || return 1

    # Create config file
    cat > "$config_path" << 'EOF'
# Configuration File
# Generated automatically

[general]
debug=false
verbose=true

[paths]
log_dir=./logs
data_dir=./data
EOF

    echo "Created config: ${config_path}"
    return 0
}
