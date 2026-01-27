#!/usr/bin/env bash
# =============================================================================
# Error Handling Pattern Examples
# =============================================================================
# This file provides error handling patterns for bash scripting.
# Reference these patterns when implementing error handling in new code.
# =============================================================================

# -----------------------------------------------------------------------------
# Pattern 1: Basic Error Checking with Return Codes
# -----------------------------------------------------------------------------
# Always check return codes of commands that can fail

basic_error_check() {
    local file="$1"

    # Method 1: Check return code explicitly
    if ! cp "$file" "${file}.bak"; then
        echo "Error: Failed to copy file" >&2
        return 1
    fi

    # Method 2: Use || for inline error handling
    rm -f "${file}.tmp" || {
        echo "Error: Failed to remove temp file" >&2
        return 1
    }

    # Method 3: Chain commands that must all succeed
    mkdir -p ./output && \
    cp "$file" ./output/ && \
    echo "File copied successfully" || {
        echo "Error: Copy operation failed" >&2
        return 1
    }

    return 0
}

# -----------------------------------------------------------------------------
# Pattern 2: Validate Inputs Early (Fail Fast)
# -----------------------------------------------------------------------------
# Check all inputs at the start of a function before doing any work

validate_inputs_example() {
    local input_file="$1"
    local output_dir="$2"
    local mode="$3"

    # Validate required parameters exist
    if [[ -z "$input_file" ]]; then
        echo "Error: input_file parameter is required" >&2
        return 1
    fi

    if [[ -z "$output_dir" ]]; then
        echo "Error: output_dir parameter is required" >&2
        return 1
    fi

    # Validate file exists and is readable
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file does not exist: ${input_file}" >&2
        return 1
    fi

    if [[ ! -r "$input_file" ]]; then
        echo "Error: Input file is not readable: ${input_file}" >&2
        return 1
    fi

    # Validate directory is writable (or can be created)
    if [[ -d "$output_dir" && ! -w "$output_dir" ]]; then
        echo "Error: Output directory is not writable: ${output_dir}" >&2
        return 1
    fi

    # Validate enum-style parameter
    if [[ -n "$mode" && ! "$mode" =~ ^(fast|slow|auto)$ ]]; then
        echo "Error: Invalid mode '${mode}'. Must be: fast, slow, or auto" >&2
        return 1
    fi

    # All validations passed, proceed with work
    echo "All inputs validated successfully"
    return 0
}

# -----------------------------------------------------------------------------
# Pattern 3: Cleanup on Error (Trap)
# -----------------------------------------------------------------------------
# Use trap to ensure cleanup happens even when errors occur

cleanup_on_error_example() {
    local temp_dir=""

    # Create cleanup function
    cleanup() {
        local exit_code=$?
        if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
            rm -rf "$temp_dir"
            echo "Cleaned up temp directory"
        fi
        return $exit_code
    }

    # Set trap for cleanup on exit (normal or error)
    trap cleanup EXIT

    # Create temporary directory
    temp_dir=$(mktemp -d) || {
        echo "Error: Failed to create temp directory" >&2
        return 1
    }

    # Do work that might fail
    echo "Working in ${temp_dir}..."

    # If this fails, cleanup still runs due to trap
    some_risky_operation || return 1

    # Cleanup runs automatically on exit
    return 0
}

# -----------------------------------------------------------------------------
# Pattern 4: Retry with Exponential Backoff
# -----------------------------------------------------------------------------
# Retry failed operations with increasing delays

retry_with_backoff() {
    local max_attempts="${1:-3}"
    local base_delay="${2:-1}"
    shift 2
    local cmd=("$@")

    local attempt=1
    local delay=$base_delay

    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt ${attempt}/${max_attempts}: ${cmd[*]}"

        if "${cmd[@]}"; then
            echo "Command succeeded on attempt ${attempt}"
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            echo "Attempt ${attempt} failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi

        ((attempt++))
    done

    echo "Error: Command failed after ${max_attempts} attempts" >&2
    return 1
}

# Usage example:
# retry_with_backoff 3 2 curl -f "https://example.com/api"

# -----------------------------------------------------------------------------
# Pattern 5: Error Logging with Context
# -----------------------------------------------------------------------------
# Log errors with full context for debugging

log_error_with_context() {
    local error_msg="$1"
    local error_code="${2:-1}"
    local function_name="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]:-0}"

    # Log to stderr with context
    {
        echo "================== ERROR =================="
        echo "Time:     $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Function: ${function_name}"
        echo "Line:     ${line_number}"
        echo "Code:     ${error_code}"
        echo "Message:  ${error_msg}"
        echo "==========================================="
    } >&2

    # Optionally log to file
    if [[ -n "${ERROR_LOG_FILE:-}" ]]; then
        {
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ERROR in ${function_name}:${line_number} - ${error_msg}"
        } >> "$ERROR_LOG_FILE"
    fi

    return "$error_code"
}

# Usage in functions:
example_with_error_logging() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error_with_context "File not found: ${file}" 2
        return 2
    fi

    if ! process_file "$file"; then
        log_error_with_context "Failed to process file: ${file}" 3
        return 3
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Pattern 6: Graceful Degradation
# -----------------------------------------------------------------------------
# Fall back to alternative methods when primary method fails

graceful_degradation_example() {
    local url="$1"
    local output_file="$2"

    echo "Downloading: ${url}"

    # Try curl first
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$url" -o "$output_file" 2>/dev/null; then
            echo "Downloaded successfully with curl"
            return 0
        fi
        echo "Warning: curl download failed, trying wget..."
    fi

    # Fall back to wget
    if command -v wget >/dev/null 2>&1; then
        if wget -q "$url" -O "$output_file" 2>/dev/null; then
            echo "Downloaded successfully with wget"
            return 0
        fi
        echo "Warning: wget download failed..."
    fi

    # Last resort: check if file already exists locally
    local local_cache="./cache/$(basename "$url")"
    if [[ -f "$local_cache" ]]; then
        echo "Using cached version"
        cp "$local_cache" "$output_file"
        return 0
    fi

    echo "Error: All download methods failed" >&2
    return 1
}

# -----------------------------------------------------------------------------
# Pattern 7: Safe Command Substitution
# -----------------------------------------------------------------------------
# Handle errors in command substitution properly

safe_command_substitution() {
    local result
    local exit_code

    # Method 1: Capture both output and exit code
    result=$(some_command 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Command failed with code ${exit_code}" >&2
        echo "Output: ${result}" >&2
        return 1
    fi

    # Method 2: Use process substitution for streaming
    local line
    while IFS= read -r line; do
        echo "Processing: ${line}"
    done < <(some_command 2>&1) || {
        echo "Error: Stream processing failed" >&2
        return 1
    }

    return 0
}

# -----------------------------------------------------------------------------
# Pattern 8: Error Accumulation
# -----------------------------------------------------------------------------
# Collect multiple errors instead of failing on first

accumulate_errors_example() {
    local files=("$@")
    local errors=()
    local success_count=0

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            errors+=("File not found: ${file}")
            continue
        fi

        if ! process_file "$file"; then
            errors+=("Failed to process: ${file}")
            continue
        fi

        ((success_count++))
    done

    # Report results
    echo "Processed ${success_count}/${#files[@]} files successfully"

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo ""
        echo "Errors encountered:"
        for error in "${errors[@]}"; do
            echo "  - ${error}"
        done
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Helper function placeholder (for examples above)
# -----------------------------------------------------------------------------
some_command() {
    echo "output"
    return 0
}

some_risky_operation() {
    return 0
}

process_file() {
    return 0
}
