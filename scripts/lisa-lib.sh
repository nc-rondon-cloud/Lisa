#!/bin/bash
# lisa-lib.sh - Shared utility functions for Lisa automation system
# This library provides logging, metrics, and common utilities

# ==============================================================================
# Configuration Defaults
# ==============================================================================
LISA_LOG_LEVEL="${LISA_LOG_LEVEL:-INFO}"
LISA_LOG_DIR="${LISA_LOG_DIR:-logs}"
LISA_LOG_COLORS="${LISA_LOG_COLORS:-true}"
LISA_MODEL="${LISA_MODEL:-claude-opus-4-5-20251101}"

# ==============================================================================
# Log Level Definitions (compatible with bash 3.x)
# ==============================================================================
# Returns numeric value for log level (higher = more severe)
_lisa_level_to_num() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        *)     echo 1 ;;  # Default to INFO
    esac
}

# ==============================================================================
# Color Definitions
# ==============================================================================
if [[ "$LISA_LOG_COLORS" == "true" ]] && [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_DEBUG="\033[36m"    # Cyan
    COLOR_INFO="\033[32m"     # Green
    COLOR_WARN="\033[33m"     # Yellow
    COLOR_ERROR="\033[31m"    # Red
    COLOR_BOLD="\033[1m"
    COLOR_DIM="\033[2m"
else
    COLOR_RESET=""
    COLOR_DEBUG=""
    COLOR_INFO=""
    COLOR_WARN=""
    COLOR_ERROR=""
    COLOR_BOLD=""
    COLOR_DIM=""
fi

# ==============================================================================
# Timestamp Functions
# ==============================================================================

# Get current timestamp in ISO 8601 format
# Usage: timestamp=$(lisa_timestamp)
lisa_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current timestamp in ISO 8601 format with local timezone
# Usage: timestamp=$(lisa_timestamp_local)
lisa_timestamp_local() {
    date +"%Y-%m-%dT%H:%M:%S%z"
}

# Get current date in YYYY-MM-DD format
# Usage: date_str=$(lisa_date)
lisa_date() {
    date +"%Y-%m-%d"
}

# ==============================================================================
# Core Logging Functions
# ==============================================================================

# Internal function to check if a log level should be displayed
# Usage: _lisa_should_log "INFO"
_lisa_should_log() {
    local level="$1"
    local current_level_num
    local message_level_num
    current_level_num=$(_lisa_level_to_num "$LISA_LOG_LEVEL")
    message_level_num=$(_lisa_level_to_num "$level")

    [[ "$message_level_num" -ge "$current_level_num" ]]
}

# Internal function to get color for log level
# Usage: color=$(_lisa_get_color "INFO")
_lisa_get_color() {
    local level="$1"
    case "$level" in
        DEBUG) echo "$COLOR_DEBUG" ;;
        INFO)  echo "$COLOR_INFO" ;;
        WARN)  echo "$COLOR_WARN" ;;
        ERROR) echo "$COLOR_ERROR" ;;
        *)     echo "$COLOR_RESET" ;;
    esac
}

# Core logging function
# Usage: lisa_log "INFO" "This is a message"
lisa_log() {
    local level="$1"
    local message="$2"

    if ! _lisa_should_log "$level"; then
        return 0
    fi

    local timestamp
    timestamp=$(lisa_timestamp_local)
    local color
    color=$(_lisa_get_color "$level")

    # Output to console (stderr)
    printf "%b[%s]%b %b[%-5s]%b %s\n" \
        "$COLOR_DIM" "$timestamp" "$COLOR_RESET" \
        "$color" "$level" "$COLOR_RESET" \
        "$message" >&2

    # Also write to daily log file
    lisa_log_daily "$level" "$message"

    # If error level, also write to error log
    if [[ "$level" == "ERROR" ]]; then
        lisa_log_error_file "$message"
    fi
}

# Convenience logging functions
# Usage: lisa_debug "Debug message"
lisa_debug() {
    lisa_log "DEBUG" "$1"
}

# Usage: lisa_info "Info message"
lisa_info() {
    lisa_log "INFO" "$1"
}

# Usage: lisa_warn "Warning message"
lisa_warn() {
    lisa_log "WARN" "$1"
}

# Usage: lisa_error "Error message"
lisa_error() {
    lisa_log "ERROR" "$1"
}

# ==============================================================================
# File Logging Functions
# ==============================================================================

# Ensure log directory exists and create required log files
# Usage: lisa_init_logs
lisa_init_logs() {
    if [[ ! -d "$LISA_LOG_DIR" ]]; then
        mkdir -p "$LISA_LOG_DIR"
        lisa_debug "Created log directory: $LISA_LOG_DIR"
    fi
}

# Initialize the complete logging system with directory and files
# Usage: lisa_setup_logging
lisa_setup_logging() {
    lisa_init_logs

    local date_str
    date_str=$(lisa_date)
    local daily_log="${LISA_LOG_DIR}/lisa-${date_str}.log"
    local errors_log="${LISA_LOG_DIR}/lisa-errors.log"
    local metrics_log="${LISA_LOG_DIR}/lisa-metrics.log"

    # Touch files to ensure they exist
    touch "$daily_log" "$errors_log" "$metrics_log"

    lisa_debug "Logging system initialized"
    lisa_debug "Daily log: $daily_log"
    lisa_debug "Errors log: $errors_log"
    lisa_debug "Metrics log: $metrics_log"
}

# Get the path to today's daily log file
# Usage: logfile=$(lisa_get_daily_log_path)
lisa_get_daily_log_path() {
    local date_str
    date_str=$(lisa_date)
    echo "${LISA_LOG_DIR}/lisa-${date_str}.log"
}

# Get the path to the errors log file
# Usage: logfile=$(lisa_get_errors_log_path)
lisa_get_errors_log_path() {
    echo "${LISA_LOG_DIR}/lisa-errors.log"
}

# Get the path to the metrics log file
# Usage: logfile=$(lisa_get_metrics_log_path)
lisa_get_metrics_log_path() {
    echo "${LISA_LOG_DIR}/lisa-metrics.log"
}

# Rotate old log files (keeps last N days of daily logs)
# Usage: lisa_rotate_logs [days_to_keep]
lisa_rotate_logs() {
    local days_to_keep="${1:-30}"

    lisa_init_logs

    # Find and remove old daily log files
    local count=0
    while IFS= read -r -d '' logfile; do
        rm -f "$logfile"
        count=$((count + 1))
    done < <(find "$LISA_LOG_DIR" -name "lisa-????-??-??.log" -type f -mtime +"$days_to_keep" -print0 2>/dev/null)

    if [[ $count -gt 0 ]]; then
        lisa_info "Rotated $count old log file(s) (older than $days_to_keep days)"
    fi
}

# Log message to file (always logs regardless of level)
# Usage: lisa_log_to_file "filename.log" "message"
lisa_log_to_file() {
    local filename="$1"
    local message="$2"
    local timestamp
    timestamp=$(lisa_timestamp_local)

    lisa_init_logs
    echo "[$timestamp] $message" >> "${LISA_LOG_DIR}/${filename}"
}

# Log to daily rotating log file
# Usage: lisa_log_daily "INFO" "message"
lisa_log_daily() {
    local level="$1"
    local message="$2"
    local date_str
    date_str=$(lisa_date)
    local filename="lisa-${date_str}.log"

    lisa_log_to_file "$filename" "[$level] $message"
}

# Log error to dedicated error log
# Usage: lisa_log_error_file "Error message" "context info"
lisa_log_error_file() {
    local message="$1"
    local context="${2:-}"
    local timestamp
    timestamp=$(lisa_timestamp_local)

    lisa_init_logs
    {
        echo "================================================================================"
        echo "Timestamp: $timestamp"
        echo "Error: $message"
        if [[ -n "$context" ]]; then
            echo "Context: $context"
        fi
        echo ""
    } >> "${LISA_LOG_DIR}/lisa-errors.log"
}

# ==============================================================================
# JSON Logging Functions (for metrics)
# ==============================================================================

# Escape a string for safe JSON inclusion
# Usage: escaped=$(lisa_json_escape "string with \"quotes\" and \\ backslashes")
lisa_json_escape() {
    local str="$1"
    # Escape backslashes first, then quotes, then control characters
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Build a JSON array from a comma-separated list
# Usage: json_array=$(lisa_json_array "file1.sh,file2.sh,file3.sh")
lisa_json_array() {
    local csv_list="$1"

    if [[ -z "$csv_list" ]]; then
        echo "[]"
        return
    fi

    local result="["
    local first=true
    local remaining="$csv_list"

    while [[ -n "$remaining" ]]; do
        local item
        # Extract item before first comma (or entire string if no comma)
        if [[ "$remaining" == *,* ]]; then
            item="${remaining%%,*}"
            remaining="${remaining#*,}"
        else
            item="$remaining"
            remaining=""
        fi

        # Trim leading/trailing whitespace
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"

        if [[ "$first" == "true" ]]; then
            first=false
        else
            result+=","
        fi
        local escaped
        escaped=$(lisa_json_escape "$item")
        result+="\"${escaped}\""
    done
    result+="]"
    echo "$result"
}

# Log a JSON object to the metrics log
# Usage: lisa_log_json '{"iteration": 1, "status": "success"}'
lisa_log_json() {
    local json_data="$1"

    lisa_init_logs
    echo "$json_data" >> "${LISA_LOG_DIR}/lisa-metrics.log"
}

# Create a structured JSON log entry for an iteration
# Usage: lisa_log_iteration 1 "task_name" 120 "success" "file1.sh,file2.sh"
lisa_log_iteration() {
    local iter_num="$1"
    local task_name="$2"
    local duration_secs="$3"
    local iter_status="$4"
    local files_changed="${5:-}"
    local ts
    ts=$(lisa_timestamp)

    local escaped_task
    escaped_task=$(lisa_json_escape "$task_name")
    local files_array
    files_array=$(lisa_json_array "$files_changed")

    local json_entry
    printf -v json_entry '{"type":"iteration","timestamp":"%s","iteration":%s,"task":"%s","duration_seconds":%s,"status":"%s","files_changed":%s}' \
        "$ts" "$iter_num" "$escaped_task" "$duration_secs" "$iter_status" "$files_array"
    lisa_log_json "$json_entry"
}

# Log session start as structured JSON
# Usage: lisa_log_session_start "session_id" 50 "PRD.md"
lisa_log_session_start() {
    local session_id="$1"
    local total_iterations="$2"
    local prd_file="${3:-PRD.md}"
    local ts
    ts=$(lisa_timestamp)

    local escaped_prd
    escaped_prd=$(lisa_json_escape "$prd_file")

    local json_entry
    printf -v json_entry '{"type":"session_start","timestamp":"%s","session_id":"%s","total_iterations":%s,"prd_file":"%s"}' \
        "$ts" "$session_id" "$total_iterations" "$escaped_prd"
    lisa_log_json "$json_entry"
}

# Log session end as structured JSON
# Usage: lisa_log_session_end "session_id" 50 45 3600 "completed"
lisa_log_session_end() {
    local session_id="$1"
    local total_iterations="$2"
    local successful_iterations="$3"
    local total_duration_secs="$4"
    local session_status="${5:-completed}"
    local ts
    ts=$(lisa_timestamp)

    local success_rate=0
    if [[ "$total_iterations" -gt 0 ]]; then
        success_rate=$((successful_iterations * 100 / total_iterations))
    fi
    local failed_iterations=$((total_iterations - successful_iterations))

    local json_entry
    printf -v json_entry '{"type":"session_end","timestamp":"%s","session_id":"%s","total_iterations":%s,"successful_iterations":%s,"failed_iterations":%s,"total_duration_seconds":%s,"success_rate_percent":%s,"status":"%s"}' \
        "$ts" "$session_id" "$total_iterations" "$successful_iterations" "$failed_iterations" "$total_duration_secs" "$success_rate" "$session_status"
    lisa_log_json "$json_entry"
}

# Log an error as structured JSON
# Usage: lisa_log_error_json "Error message" "iteration" 5 "task_name"
lisa_log_error_json() {
    local error_message="$1"
    local error_context="${2:-unknown}"
    local iteration="${3:-0}"
    local task_name="${4:-}"
    local ts
    ts=$(lisa_timestamp)

    local escaped_message
    escaped_message=$(lisa_json_escape "$error_message")
    local escaped_task
    escaped_task=$(lisa_json_escape "$task_name")

    local json_entry
    printf -v json_entry '{"type":"error","timestamp":"%s","message":"%s","context":"%s","iteration":%s,"task":"%s"}' \
        "$ts" "$escaped_message" "$error_context" "$iteration" "$escaped_task"
    lisa_log_json "$json_entry"
}

# Generate a unique session ID
# Usage: session_id=$(lisa_generate_session_id)
lisa_generate_session_id() {
    local ts
    ts=$(date +"%Y%m%d%H%M%S")
    local random_suffix
    random_suffix=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
    echo "lisa-${ts}-${random_suffix}"
}

# ==============================================================================
# Status File Functions (Real-time Monitoring)
# ==============================================================================

# Default status file path
LISA_STATUS_FILE="${LISA_STATUS_FILE:-.lisa-status.json}"

# Write current status to the status file for real-time monitoring
# Usage: lisa_write_status "running" "session_id" 5 50 "task name"
lisa_write_status() {
    local run_status="$1"
    local session_id="$2"
    local current_iteration="${3:-0}"
    local total_iterations="${4:-0}"
    local current_task="${5:-}"
    local start_time="${6:-}"
    local ts
    ts=$(lisa_timestamp)

    local escaped_task
    escaped_task=$(lisa_json_escape "$current_task")

    local progress_percent=0
    if [[ "$total_iterations" -gt 0 ]] && [[ "$current_iteration" -gt 0 ]]; then
        progress_percent=$(( (current_iteration - 1) * 100 / total_iterations ))
    fi

    local json_status
    printf -v json_status '{"status":"%s","session_id":"%s","current_iteration":%s,"total_iterations":%s,"progress_percent":%s,"current_task":"%s","start_time":"%s","last_updated":"%s"}' \
        "$run_status" "$session_id" "$current_iteration" "$total_iterations" "$progress_percent" "$escaped_task" "$start_time" "$ts"

    echo "$json_status" > "$LISA_STATUS_FILE"
}

# Update status to indicate iteration in progress
# Usage: lisa_status_iteration_start "session_id" 5 50 "task name" "start_time"
lisa_status_iteration_start() {
    local session_id="$1"
    local current_iteration="$2"
    local total_iterations="$3"
    local current_task="${4:-auto}"
    local start_time="${5:-}"
    lisa_write_status "running" "$session_id" "$current_iteration" "$total_iterations" "$current_task" "$start_time"
}

# Update status to indicate iteration completed
# Usage: lisa_status_iteration_complete "session_id" 5 50 "start_time"
lisa_status_iteration_complete() {
    local session_id="$1"
    local current_iteration="$2"
    local total_iterations="$3"
    local start_time="${4:-}"
    lisa_write_status "iteration_complete" "$session_id" "$current_iteration" "$total_iterations" "" "$start_time"
}

# Update status to indicate session completed
# Usage: lisa_status_session_complete "session_id" 50 50
lisa_status_session_complete() {
    local session_id="$1"
    local completed_iterations="$2"
    local total_iterations="$3"
    local ts
    ts=$(lisa_timestamp)

    local json_status
    printf -v json_status '{"status":"completed","session_id":"%s","current_iteration":%s,"total_iterations":%s,"progress_percent":100,"current_task":"","start_time":"","last_updated":"%s"}' \
        "$session_id" "$completed_iterations" "$total_iterations" "$ts"

    echo "$json_status" > "$LISA_STATUS_FILE"
}

# Update status to indicate session idle/stopped
# Usage: lisa_status_idle
lisa_status_idle() {
    local ts
    ts=$(lisa_timestamp)

    local json_status
    printf -v json_status '{"status":"idle","session_id":"","current_iteration":0,"total_iterations":0,"progress_percent":0,"current_task":"","start_time":"","last_updated":"%s"}' "$ts"

    echo "$json_status" > "$LISA_STATUS_FILE"
}

# Read current status from status file
# Usage: status=$(lisa_read_status)
lisa_read_status() {
    if [[ -f "$LISA_STATUS_FILE" ]]; then
        cat "$LISA_STATUS_FILE"
    else
        echo '{"status":"unknown","session_id":"","current_iteration":0,"total_iterations":0,"progress_percent":0,"current_task":"","start_time":"","last_updated":""}'
    fi
}

# Remove status file (cleanup)
# Usage: lisa_clear_status
lisa_clear_status() {
    if [[ -f "$LISA_STATUS_FILE" ]]; then
        rm -f "$LISA_STATUS_FILE"
    fi
}

# ==============================================================================
# Summary Report Functions
# ==============================================================================

# Default summary file path
LISA_SUMMARY_FILE="${LISA_SUMMARY_FILE:-lisa-summary.txt}"

# Generate a summary report at the end of a session
# Usage: lisa_generate_summary "session_id" 50 45 5 3600 "completed" "file1.sh,file2.sh"
lisa_generate_summary() {
    local session_id="$1"
    local total_iterations="$2"
    local successful_iterations="$3"
    local failed_iterations="$4"
    local total_duration_secs="$5"
    local session_status="$6"
    local files_modified="${7:-}"
    local ts
    ts=$(lisa_timestamp_local)

    local formatted_duration
    formatted_duration=$(lisa_format_duration "$total_duration_secs")

    local success_rate=0
    if [[ "$total_iterations" -gt 0 ]]; then
        success_rate=$((successful_iterations * 100 / total_iterations))
    fi

    local avg_time=0
    local avg_formatted="N/A"
    if [[ "$successful_iterations" -gt 0 ]]; then
        avg_time=$((total_duration_secs / successful_iterations))
        avg_formatted=$(lisa_format_duration "$avg_time")
    fi

    # Write the summary report
    {
        echo "================================================================================"
        echo "                         RALPH SESSION SUMMARY REPORT"
        echo "================================================================================"
        echo ""
        echo "Session ID:        $session_id"
        echo "Generated:         $ts"
        echo "Status:            $session_status"
        echo ""
        echo "--------------------------------------------------------------------------------"
        echo "                              ITERATION METRICS"
        echo "--------------------------------------------------------------------------------"
        echo ""
        echo "Total Iterations:       $total_iterations"
        echo "Successful:             $successful_iterations"
        echo "Failed:                 $failed_iterations"
        echo "Success Rate:           ${success_rate}%"
        echo ""
        echo "--------------------------------------------------------------------------------"
        echo "                               TIME METRICS"
        echo "--------------------------------------------------------------------------------"
        echo ""
        echo "Total Duration:         $formatted_duration"
        echo "Average per Iteration:  $avg_formatted"
        echo ""
        echo "--------------------------------------------------------------------------------"
        echo "                            FILES MODIFIED"
        echo "--------------------------------------------------------------------------------"
        echo ""
        if [[ -n "$files_modified" ]]; then
            # Split comma-separated files and list them
            local remaining="$files_modified"
            local file_count=0
            while [[ -n "$remaining" ]]; do
                local item
                if [[ "$remaining" == *,* ]]; then
                    item="${remaining%%,*}"
                    remaining="${remaining#*,}"
                else
                    item="$remaining"
                    remaining=""
                fi
                # Trim whitespace
                item="${item#"${item%%[![:space:]]*}"}"
                item="${item%"${item##*[![:space:]]}"}"
                if [[ -n "$item" ]]; then
                    echo "  - $item"
                    file_count=$((file_count + 1))
                fi
            done
            echo ""
            echo "Total files modified: $file_count"
        else
            echo "  (No files tracked - use git diff to see changes)"
        fi
        echo ""
        echo "================================================================================"
        echo "                              END OF REPORT"
        echo "================================================================================"
    } > "$LISA_SUMMARY_FILE"

    lisa_info "Summary report generated: $LISA_SUMMARY_FILE"
}

# Get list of modified files from git (if in a git repo)
# Usage: modified_files=$(lisa_get_git_modified_files)
lisa_get_git_modified_files() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Get modified, added, and deleted files
        git diff --name-only HEAD 2>/dev/null | tr '\n' ',' | sed 's/,$//'
    else
        echo ""
    fi
}

# Get list of modified files since a given timestamp (from git log)
# Usage: modified_files=$(lisa_get_files_modified_since "2026-01-14T10:00:00Z")
lisa_get_files_modified_since() {
    local since_time="$1"
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git diff --name-only --since="$since_time" HEAD 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//'
    else
        echo ""
    fi
}

# ==============================================================================
# Code Validation Functions
# ==============================================================================

# Default validation log file path
LISA_VALIDATION_LOG="${LISA_VALIDATION_LOG:-${LISA_LOG_DIR}/lisa-validation.log}"

# Get the path to the validation log file
# Usage: logfile=$(lisa_get_validation_log_path)
lisa_get_validation_log_path() {
    echo "${LISA_LOG_DIR}/lisa-validation.log"
}

# Log a validation result entry
# Usage: lisa_log_validation "shellcheck" "lisa-lib.sh" "pass" ""
lisa_log_validation() {
    local tool="$1"
    local file="$2"
    local result="$3"
    local details="${4:-}"
    local ts
    ts=$(lisa_timestamp_local)

    lisa_init_logs
    {
        echo "[$ts] [$tool] $file: $result"
        if [[ -n "$details" ]]; then
            echo "$details" | sed 's/^/    /'
        fi
    } >> "$(lisa_get_validation_log_path)"
}

# Log validation summary as JSON to metrics log
# Usage: lisa_log_validation_json "iteration" 5 3 2 0
lisa_log_validation_json() {
    local context="$1"
    local iteration="$2"
    local total_files="$3"
    local passed="$4"
    local warnings="$5"
    local ts
    ts=$(lisa_timestamp)

    local json_entry
    printf -v json_entry '{"type":"validation","timestamp":"%s","context":"%s","iteration":%s,"total_files":%s,"passed":%s,"warnings":%s}' \
        "$ts" "$context" "$iteration" "$total_files" "$passed" "$warnings"
    lisa_log_json "$json_entry"
}

# Run shellcheck on a single bash file
# Usage: result=$(lisa_shellcheck_file "script.sh")
# Returns: "pass", "warn", or "skip"
lisa_shellcheck_file() {
    local file="$1"
    local output

    # Check if shellcheck is available
    if ! command -v shellcheck &> /dev/null; then
        lisa_debug "shellcheck not installed, skipping validation for $file"
        echo "skip"
        return 0
    fi

    # Run shellcheck and capture output
    output=$(shellcheck -f gcc "$file" 2>&1) || true

    if [[ -z "$output" ]]; then
        lisa_log_validation "shellcheck" "$file" "PASS" ""
        echo "pass"
    else
        lisa_log_validation "shellcheck" "$file" "WARN" "$output"
        echo "warn"
    fi
}

# Run eslint on a single JavaScript/TypeScript file
# Usage: result=$(lisa_eslint_file "script.js")
# Returns: "pass", "warn", or "skip"
lisa_eslint_file() {
    local file="$1"
    local output

    # Check if eslint is available (local or global)
    local eslint_cmd=""
    if [[ -x "./node_modules/.bin/eslint" ]]; then
        eslint_cmd="./node_modules/.bin/eslint"
    elif command -v eslint &> /dev/null; then
        eslint_cmd="eslint"
    else
        lisa_debug "eslint not found, skipping validation for $file"
        echo "skip"
        return 0
    fi

    # Run eslint and capture output
    output=$("$eslint_cmd" --format compact "$file" 2>&1) || true

    if [[ -z "$output" ]] || [[ "$output" == *"0 problems"* ]]; then
        lisa_log_validation "eslint" "$file" "PASS" ""
        echo "pass"
    else
        lisa_log_validation "eslint" "$file" "WARN" "$output"
        echo "warn"
    fi
}

# Run prettier check on a single file
# Usage: result=$(lisa_prettier_file "script.js")
# Returns: "pass", "warn", or "skip"
lisa_prettier_file() {
    local file="$1"
    local output

    # Check if prettier is available (local or global)
    local prettier_cmd=""
    if [[ -x "./node_modules/.bin/prettier" ]]; then
        prettier_cmd="./node_modules/.bin/prettier"
    elif command -v prettier &> /dev/null; then
        prettier_cmd="prettier"
    else
        lisa_debug "prettier not found, skipping validation for $file"
        echo "skip"
        return 0
    fi

    # Run prettier check (--check returns non-zero if formatting needed)
    if "$prettier_cmd" --check "$file" &> /dev/null; then
        lisa_log_validation "prettier" "$file" "PASS" ""
        echo "pass"
    else
        lisa_log_validation "prettier" "$file" "WARN" "File needs formatting"
        echo "warn"
    fi
}

# Validate all modified bash files using shellcheck
# Usage: lisa_validate_bash_files "file1.sh,file2.sh"
# Returns: number of warnings found
lisa_validate_bash_files() {
    local files_csv="$1"
    local warnings=0
    local checked=0
    local skipped=0

    if [[ -z "$files_csv" ]]; then
        echo "0"
        return 0
    fi

    # Check if shellcheck is available before iterating
    if ! command -v shellcheck &> /dev/null; then
        lisa_warn "shellcheck not installed, skipping bash file validation"
        echo "0"
        return 0
    fi

    local remaining="$files_csv"
    while [[ -n "$remaining" ]]; do
        local file
        if [[ "$remaining" == *,* ]]; then
            file="${remaining%%,*}"
            remaining="${remaining#*,}"
        else
            file="$remaining"
            remaining=""
        fi

        # Trim whitespace
        file="${file#"${file%%[![:space:]]*}"}"
        file="${file%"${file##*[![:space:]]}"}"

        # Check if it's a bash file
        if [[ "$file" == *.sh ]] && [[ -f "$file" ]]; then
            checked=$((checked + 1))
            local result
            result=$(lisa_shellcheck_file "$file")
            if [[ "$result" == "warn" ]]; then
                warnings=$((warnings + 1))
            elif [[ "$result" == "skip" ]]; then
                skipped=$((skipped + 1))
            fi
        fi
    done

    if [[ $checked -gt 0 ]]; then
        lisa_debug "Validated $checked bash file(s), $warnings warning(s), $skipped skipped"
    fi
    echo "$warnings"
}

# Validate all modified JavaScript/TypeScript files
# Usage: lisa_validate_js_files "file1.js,file2.ts"
# Returns: number of warnings found
lisa_validate_js_files() {
    local files_csv="$1"
    local warnings=0
    local checked=0

    if [[ -z "$files_csv" ]]; then
        echo "0"
        return 0
    fi

    # Check if eslint or prettier is available
    local has_eslint=false
    local has_prettier=false
    if [[ -x "./node_modules/.bin/eslint" ]] || command -v eslint &> /dev/null; then
        has_eslint=true
    fi
    if [[ -x "./node_modules/.bin/prettier" ]] || command -v prettier &> /dev/null; then
        has_prettier=true
    fi

    if [[ "$has_eslint" == "false" ]] && [[ "$has_prettier" == "false" ]]; then
        lisa_warn "Neither eslint nor prettier installed, skipping JS/TS validation"
        echo "0"
        return 0
    fi

    local remaining="$files_csv"
    while [[ -n "$remaining" ]]; do
        local file
        if [[ "$remaining" == *,* ]]; then
            file="${remaining%%,*}"
            remaining="${remaining#*,}"
        else
            file="$remaining"
            remaining=""
        fi

        # Trim whitespace
        file="${file#"${file%%[![:space:]]*}"}"
        file="${file%"${file##*[![:space:]]}"}"

        # Check if it's a JS/TS file
        if [[ "$file" == *.js ]] || [[ "$file" == *.ts ]] || [[ "$file" == *.jsx ]] || [[ "$file" == *.tsx ]]; then
            if [[ -f "$file" ]]; then
                checked=$((checked + 1))
                local eslint_result prettier_result
                eslint_result=$(lisa_eslint_file "$file")
                prettier_result=$(lisa_prettier_file "$file")
                if [[ "$eslint_result" == "warn" ]] || [[ "$prettier_result" == "warn" ]]; then
                    warnings=$((warnings + 1))
                fi
            fi
        fi
    done

    if [[ $checked -gt 0 ]]; then
        lisa_debug "Validated $checked JS/TS file(s), $warnings warning(s)"
    fi
    echo "$warnings"
}

# Run all code validations on modified files after an iteration
# Usage: lisa_run_validation 5 "file1.sh,file2.js,file3.ts"
# Logs results and returns total warnings (does not fail the iteration)
lisa_run_validation() {
    local iteration="$1"
    local files_csv="$2"
    local total_warnings=0
    local total_files=0
    local bash_warnings=0
    local js_warnings=0
    local ts
    ts=$(lisa_timestamp_local)

    if [[ -z "$files_csv" ]]; then
        lisa_debug "No files to validate for iteration $iteration"
        return 0
    fi

    lisa_init_logs

    # Log validation start
    {
        echo ""
        echo "================================================================================"
        echo "[$ts] Validation for iteration $iteration"
        echo "================================================================================"
    } >> "$(lisa_get_validation_log_path)"

    # Count files by type
    local remaining="$files_csv"
    local bash_count=0
    local js_count=0
    while [[ -n "$remaining" ]]; do
        local file
        if [[ "$remaining" == *,* ]]; then
            file="${remaining%%,*}"
            remaining="${remaining#*,}"
        else
            file="$remaining"
            remaining=""
        fi
        file="${file#"${file%%[![:space:]]*}"}"
        file="${file%"${file##*[![:space:]]}"}"

        if [[ "$file" == *.sh ]]; then
            bash_count=$((bash_count + 1))
        elif [[ "$file" == *.js ]] || [[ "$file" == *.ts ]] || [[ "$file" == *.jsx ]] || [[ "$file" == *.tsx ]]; then
            js_count=$((js_count + 1))
        fi
    done

    total_files=$((bash_count + js_count))

    # Validate bash files
    if [[ $bash_count -gt 0 ]]; then
        lisa_info "Validating $bash_count bash file(s) with shellcheck..."
        bash_warnings=$(lisa_validate_bash_files "$files_csv")
        total_warnings=$((total_warnings + bash_warnings))
    fi

    # Validate JS/TS files
    if [[ $js_count -gt 0 ]]; then
        lisa_info "Validating $js_count JS/TS file(s) with eslint/prettier..."
        js_warnings=$(lisa_validate_js_files "$files_csv")
        total_warnings=$((total_warnings + js_warnings))
    fi

    # Log summary
    local passed_files=$((total_files - total_warnings))
    lisa_log_validation_json "iteration" "$iteration" "$total_files" "$passed_files" "$total_warnings"

    if [[ $total_warnings -gt 0 ]]; then
        lisa_warn "Validation completed: $total_warnings warning(s) in $total_files file(s)"
        lisa_warn "See $(lisa_get_validation_log_path) for details"
    else
        if [[ $total_files -gt 0 ]]; then
            lisa_info "Validation passed: all $total_files file(s) clean"
        fi
    fi

    echo "$total_warnings"
}

# ==============================================================================
# Retry Configuration and Functions
# ==============================================================================

# Default retry configuration
LISA_MAX_RETRIES="${LISA_MAX_RETRIES:-3}"
LISA_RETRY_BASE_DELAY="${LISA_RETRY_BASE_DELAY:-5}"  # Base delay in seconds

# Calculate exponential backoff delay
# Usage: delay=$(lisa_get_backoff_delay 2)  # Returns delay for retry attempt 2
# Formula: base_delay * (2 ^ attempt) with some randomization
lisa_get_backoff_delay() {
    local attempt="$1"
    local base_delay="${LISA_RETRY_BASE_DELAY:-5}"

    # Calculate 2^attempt using bash arithmetic
    local multiplier=1
    local i
    for ((i=0; i<attempt; i++)); do
        multiplier=$((multiplier * 2))
    done

    local delay=$((base_delay * multiplier))

    # Add some jitter (0-25% of delay) to prevent thundering herd
    local jitter=$((delay / 4))
    if [[ $jitter -gt 0 ]]; then
        # Use $RANDOM for jitter (bash built-in)
        jitter=$((RANDOM % jitter))
    fi

    echo $((delay + jitter))
}

# Log a retry attempt
# Usage: lisa_log_retry 5 2 3 "exit code 1" 10
lisa_log_retry() {
    local iteration="$1"
    local attempt="$2"
    local max_retries="$3"
    local reason="$4"
    local delay="$5"
    local ts
    ts=$(lisa_timestamp)

    local escaped_reason
    escaped_reason=$(lisa_json_escape "$reason")

    # Log to daily log
    lisa_log_daily "WARN" "Iteration $iteration: Retry attempt $attempt/$max_retries after failure ($reason), waiting ${delay}s"

    # Log to error file with context
    lisa_log_error_file \
        "Retry scheduled for iteration $iteration" \
        "Attempt: $attempt/$max_retries, Reason: $reason, Backoff delay: ${delay}s"

    # Log as JSON to metrics
    local json_entry
    printf -v json_entry '{"type":"retry","timestamp":"%s","iteration":%s,"attempt":%s,"max_retries":%s,"reason":"%s","backoff_seconds":%s}' \
        "$ts" "$iteration" "$attempt" "$max_retries" "$escaped_reason" "$delay"
    lisa_log_json "$json_entry"
}

# Log when all retries are exhausted
# Usage: lisa_log_retry_exhausted 5 3 "exit code 1"
lisa_log_retry_exhausted() {
    local iteration="$1"
    local max_retries="$2"
    local reason="$3"
    local ts
    ts=$(lisa_timestamp)

    local escaped_reason
    escaped_reason=$(lisa_json_escape "$reason")

    # Log to daily log
    lisa_log_daily "ERROR" "Iteration $iteration: All $max_retries retry attempts exhausted ($reason)"

    # Log to error file
    lisa_log_error_file \
        "All retries exhausted for iteration $iteration" \
        "Max retries: $max_retries, Final failure reason: $reason"

    # Log as JSON
    local json_entry
    printf -v json_entry '{"type":"retry_exhausted","timestamp":"%s","iteration":%s,"max_retries":%s,"reason":"%s"}' \
        "$ts" "$iteration" "$max_retries" "$escaped_reason"
    lisa_log_json "$json_entry"
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Print a separator line
# Usage: lisa_separator
lisa_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "$width" '' | tr ' ' "$char" >&2
}

# Print a header with separators
# Usage: lisa_header "Section Title"
lisa_header() {
    local title="$1"
    lisa_separator "="
    printf "%b%s%b\n" "$COLOR_BOLD" "$title" "$COLOR_RESET" >&2
    lisa_separator "="
}

# Format duration in human readable format
# Usage: formatted=$(lisa_format_duration 3665)
lisa_format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" "$hours" "$minutes" "$secs"
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" "$minutes" "$secs"
    else
        printf "%ds" "$secs"
    fi
}

# ==============================================================================
# Export functions for use in sourcing scripts
# ==============================================================================
export -f lisa_timestamp
export -f lisa_timestamp_local
export -f lisa_date
export -f lisa_log
export -f lisa_debug
export -f lisa_info
export -f lisa_warn
export -f lisa_error
export -f lisa_init_logs
export -f lisa_setup_logging
export -f lisa_get_daily_log_path
export -f lisa_get_errors_log_path
export -f lisa_get_metrics_log_path
export -f lisa_rotate_logs
export -f lisa_log_to_file
export -f lisa_log_daily
export -f lisa_log_error_file
export -f lisa_json_escape
export -f lisa_json_array
export -f lisa_log_json
export -f lisa_log_iteration
export -f lisa_log_session_start
export -f lisa_log_session_end
export -f lisa_log_error_json
export -f lisa_generate_session_id
export -f lisa_separator
export -f lisa_header
export -f lisa_format_duration
export -f lisa_write_status
export -f lisa_status_iteration_start
export -f lisa_status_iteration_complete
export -f lisa_status_session_complete
export -f lisa_status_idle
export -f lisa_read_status
export -f lisa_clear_status
export -f lisa_generate_summary
export -f lisa_get_git_modified_files
export -f lisa_get_files_modified_since
export -f lisa_get_validation_log_path
export -f lisa_log_validation
export -f lisa_log_validation_json
export -f lisa_shellcheck_file
export -f lisa_eslint_file
export -f lisa_prettier_file
export -f lisa_validate_bash_files
export -f lisa_validate_js_files
export -f lisa_run_validation
export -f lisa_get_backoff_delay
export -f lisa_log_retry
export -f lisa_log_retry_exhausted

# ==============================================================================
# State Persistence Functions (for pause/resume and graceful shutdown)
# ==============================================================================

# Default state file path
LISA_STATE_FILE="${LISA_STATE_FILE:-.lisa-state.json}"

# Save current session state to state file
# Usage: lisa_save_state "session_id" 5 50 "completed_iters" "failed_iters" "total_time" "start_time"
lisa_save_state() {
    local session_id="$1"
    local current_iteration="$2"
    local total_iterations="$3"
    local completed_iterations="${4:-0}"
    local failed_iterations="${5:-0}"
    local total_iteration_time="${6:-0}"
    local session_start_time="${7:-}"
    local session_status="${8:-interrupted}"
    local ts
    ts=$(lisa_timestamp)

    local json_state
    printf -v json_state '{"session_id":"%s","current_iteration":%s,"total_iterations":%s,"completed_iterations":%s,"failed_iterations":%s,"total_iteration_time":%s,"session_start_time":"%s","status":"%s","saved_at":"%s"}' \
        "$session_id" "$current_iteration" "$total_iterations" "$completed_iterations" "$failed_iterations" "$total_iteration_time" "$session_start_time" "$session_status" "$ts"

    echo "$json_state" > "$LISA_STATE_FILE"
}

# Read saved state from state file
# Usage: state_json=$(lisa_read_state)
lisa_read_state() {
    if [[ -f "$LISA_STATE_FILE" ]]; then
        cat "$LISA_STATE_FILE"
    else
        echo ""
    fi
}

# Check if a saved state exists and is resumable
# Usage: if lisa_has_resumable_state; then ...
lisa_has_resumable_state() {
    if [[ -f "$LISA_STATE_FILE" ]]; then
        local state_status
        state_status=$(lisa_get_state_field "status")
        [[ "$state_status" == "interrupted" ]]
    else
        return 1
    fi
}

# Get a specific field from the state file using basic string parsing
# Usage: session_id=$(lisa_get_state_field "session_id")
lisa_get_state_field() {
    local field="$1"
    if [[ -f "$LISA_STATE_FILE" ]]; then
        local content
        content=$(cat "$LISA_STATE_FILE")
        # Extract value using pattern matching
        # Handles both string and numeric values
        case "$field" in
            session_id|status|session_start_time|saved_at)
                # String field - extract between quotes
                echo "$content" | sed -n "s/.*\"${field}\":\"\([^\"]*\)\".*/\1/p"
                ;;
            *)
                # Numeric field - extract number
                echo "$content" | sed -n "s/.*\"${field}\":\([0-9]*\).*/\1/p"
                ;;
        esac
    else
        echo ""
    fi
}

# Clear state file (used after successful completion or manual clear)
# Usage: lisa_clear_state
lisa_clear_state() {
    if [[ -f "$LISA_STATE_FILE" ]]; then
        rm -f "$LISA_STATE_FILE"
    fi
}

# Update status file to show interrupted state
# Usage: lisa_status_interrupted "session_id" 5 50 "start_time"
lisa_status_interrupted() {
    local session_id="$1"
    local current_iteration="$2"
    local total_iterations="$3"
    local start_time="${4:-}"
    local ts
    ts=$(lisa_timestamp)

    local progress_percent=0
    if [[ "$total_iterations" -gt 0 ]] && [[ "$current_iteration" -gt 0 ]]; then
        progress_percent=$(( (current_iteration - 1) * 100 / total_iterations ))
    fi

    local json_status
    printf -v json_status '{"status":"interrupted","session_id":"%s","current_iteration":%s,"total_iterations":%s,"progress_percent":%s,"current_task":"","start_time":"%s","last_updated":"%s"}' \
        "$session_id" "$current_iteration" "$total_iterations" "$progress_percent" "$start_time" "$ts"

    echo "$json_status" > "$LISA_STATUS_FILE"
}

# Log session interruption as JSON
# Usage: lisa_log_session_interrupted "session_id" 5 3 120 "SIGINT"
lisa_log_session_interrupted() {
    local session_id="$1"
    local total_iterations="$2"
    local completed_iterations="$3"
    local total_duration_secs="$4"
    local signal="${5:-unknown}"
    local ts
    ts=$(lisa_timestamp)

    local escaped_signal
    escaped_signal=$(lisa_json_escape "$signal")

    local json_entry
    printf -v json_entry '{"type":"session_interrupted","timestamp":"%s","session_id":"%s","total_iterations":%s,"completed_iterations":%s,"total_duration_seconds":%s,"signal":"%s"}' \
        "$ts" "$session_id" "$total_iterations" "$completed_iterations" "$total_duration_secs" "$escaped_signal"
    lisa_log_json "$json_entry"
}

# Export state functions
export -f lisa_save_state
export -f lisa_read_state
export -f lisa_has_resumable_state
export -f lisa_get_state_field
export -f lisa_clear_state
export -f lisa_status_interrupted
export -f lisa_log_session_interrupted

# ==============================================================================
# Context Summarization Functions
# ==============================================================================

# Default configuration for context summarization
LISA_PROGRESS_FILE="${LISA_PROGRESS_FILE:-progress.txt}"
LISA_PROGRESS_ARCHIVE="${LISA_PROGRESS_ARCHIVE:-progress-archive.txt}"
LISA_PROGRESS_MAX_LINES="${LISA_PROGRESS_MAX_LINES:-500}"
LISA_PROGRESS_KEEP_LINES="${LISA_PROGRESS_KEEP_LINES:-100}"

# Get the current line count of a file
# Usage: count=$(lisa_get_line_count "progress.txt")
lisa_get_line_count() {
    local file="$1"
    if [[ -f "$file" ]]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

# Extract task completion entries from progress content
# Usage: tasks=$(lisa_extract_completed_tasks "content")
lisa_extract_completed_tasks() {
    local content="$1"
    local tasks=""
    local in_task=false
    local current_date=""
    local current_task=""

    # Parse line by line using a while loop
    while IFS= read -r line; do
        # Check for date/task header (## YYYY-MM-DD: Task X.X - Description)
        # Using grep for more portable regex matching
        if echo "$line" | grep -qE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}: Task [^ ]+ - .+$'; then
            # Save previous task if exists
            if [[ -n "$current_task" ]]; then
                if [[ -n "$tasks" ]]; then
                    tasks="${tasks}\n"
                fi
                tasks="${tasks}${current_task}"
            fi
            # Extract fields using parameter expansion and sed
            current_date=$(echo "$line" | sed 's/^## \([0-9-]*\):.*/\1/')
            local task_num
            task_num=$(echo "$line" | sed 's/^## [0-9-]*: Task \([^ ]*\) -.*/\1/')
            local task_desc
            task_desc=$(echo "$line" | sed 's/^## [0-9-]*: Task [^ ]* - //')
            current_task="- [${current_date}] Task ${task_num}: ${task_desc}"
            in_task=true
        # Check for **Completed:** marker to confirm task was done
        elif [[ "$in_task" == "true" ]] && echo "$line" | grep -qE '^\*\*Completed:\*\* .+$'; then
            local completed_desc
            completed_desc=$(echo "$line" | sed 's/^\*\*Completed:\*\* //')
            current_task="${current_task} - ${completed_desc}"
        fi
    done <<< "$content"

    # Add last task
    if [[ -n "$current_task" ]]; then
        if [[ -n "$tasks" ]]; then
            tasks="${tasks}\n"
        fi
        tasks="${tasks}${current_task}"
    fi

    echo -e "$tasks"
}

# Generate a summary of older progress entries
# Usage: summary=$(lisa_generate_progress_summary "content")
lisa_generate_progress_summary() {
    local content="$1"
    local ts
    ts=$(lisa_timestamp_local)

    # Count tasks by extracting headers using grep for portability
    local task_count
    task_count=$(echo "$content" | grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}: Task ' || echo "0")

    # Extract task summaries
    local task_list
    task_list=$(lisa_extract_completed_tasks "$content")

    # Build summary
    local summary
    summary="## Progress Summary (Auto-generated: ${ts})

This is an auto-generated summary of ${task_count} completed task(s).
Full history has been archived to: ${LISA_PROGRESS_ARCHIVE}

### Completed Tasks:
${task_list}

---
(End of summary - Recent progress entries follow below)

"
    echo "$summary"
}

# Archive older progress entries and summarize them
# Usage: lisa_summarize_progress ["progress.txt"]
# Returns: 0 if summarized, 1 if not needed, 2 on error
lisa_summarize_progress() {
    local progress_file="${1:-$LISA_PROGRESS_FILE}"
    local archive_file="${LISA_PROGRESS_ARCHIVE}"
    local max_lines="${LISA_PROGRESS_MAX_LINES}"
    local keep_lines="${LISA_PROGRESS_KEEP_LINES}"

    # Check if file exists
    if [[ ! -f "$progress_file" ]]; then
        lisa_debug "Progress file does not exist: $progress_file"
        return 1
    fi

    # Get current line count
    local line_count
    line_count=$(lisa_get_line_count "$progress_file")

    lisa_debug "Progress file has $line_count lines (max: $max_lines)"

    # Check if summarization is needed
    if [[ "$line_count" -le "$max_lines" ]]; then
        lisa_debug "Progress file under threshold, no summarization needed"
        return 1
    fi

    lisa_info "Progress file exceeds $max_lines lines ($line_count), summarizing..."

    # Calculate lines to archive (all except the last keep_lines)
    local archive_lines=$((line_count - keep_lines))

    # Read the entire file content
    local full_content
    full_content=$(cat "$progress_file")

    # Split content into old (to archive) and recent (to keep)
    local old_content
    local recent_content
    old_content=$(head -n "$archive_lines" "$progress_file")
    recent_content=$(tail -n "$keep_lines" "$progress_file")

    # Archive the old content
    local archive_ts
    archive_ts=$(lisa_timestamp_local)
    {
        echo ""
        echo "================================================================================"
        echo "ARCHIVED: ${archive_ts}"
        echo "Lines archived: ${archive_lines}"
        echo "================================================================================"
        echo ""
        echo "$old_content"
    } >> "$archive_file"

    lisa_log_daily "INFO" "Archived $archive_lines lines from progress.txt to $archive_file"

    # Generate summary of old content
    local summary
    summary=$(lisa_generate_progress_summary "$old_content")

    # Write summary + recent content back to progress file
    {
        echo "$summary"
        echo "$recent_content"
    } > "$progress_file"

    local new_line_count
    new_line_count=$(lisa_get_line_count "$progress_file")

    lisa_info "Summarized progress.txt: $line_count -> $new_line_count lines"
    lisa_log_daily "INFO" "Summarized progress.txt: $line_count -> $new_line_count lines (archived: $archive_lines)"

    # Log as JSON
    local json_entry
    json_entry=$(printf '{"type":"context_summarization","timestamp":"%s","original_lines":%s,"archived_lines":%s,"new_lines":%s,"archive_file":"%s"}' \
        "$(lisa_timestamp)" "$line_count" "$archive_lines" "$new_line_count" "$archive_file")
    lisa_log_json "$json_entry"

    return 0
}

# Check if progress file needs summarization (without doing it)
# Usage: if lisa_needs_summarization; then ...
lisa_needs_summarization() {
    local progress_file="${1:-$LISA_PROGRESS_FILE}"
    local max_lines="${LISA_PROGRESS_MAX_LINES}"

    if [[ ! -f "$progress_file" ]]; then
        return 1
    fi

    local line_count
    line_count=$(lisa_get_line_count "$progress_file")

    [[ "$line_count" -gt "$max_lines" ]]
}

# Export context summarization functions
export -f lisa_get_line_count
export -f lisa_extract_completed_tasks
export -f lisa_generate_progress_summary
export -f lisa_summarize_progress
export -f lisa_needs_summarization

# ==============================================================================
# Output Filtering Functions
# ==============================================================================

# Default configuration for output filtering
LISA_FULL_OUTPUT_LOG="${LISA_FULL_OUTPUT_LOG:-${LISA_LOG_DIR}/lisa-full-output.log}"
LISA_FILTER_OUTPUT="${LISA_FILTER_OUTPUT:-true}"

# Verbosity configuration (0=silent, 1=filtered, 2=full)
# Backward compatibility: Honor LISA_FILTER_OUTPUT if set
if [[ -n "${LISA_FILTER_OUTPUT}" ]]; then
    if [[ "${LISA_FILTER_OUTPUT}" == "true" ]]; then
        LISA_VERBOSE="${LISA_VERBOSE:-1}"
    else
        LISA_VERBOSE="${LISA_VERBOSE:-2}"
    fi
fi
# Default to full verbose output (per user preference)
LISA_VERBOSE="${LISA_VERBOSE:-2}"
export LISA_VERBOSE

# Get the path to the full output log file
# Usage: logfile=$(lisa_get_full_output_log_path)
lisa_get_full_output_log_path() {
    echo "${LISA_LOG_DIR}/lisa-full-output.log"
}

# Log full Claude output to file
# Usage: lisa_log_full_output "session_id" 5 "full output content"
lisa_log_full_output() {
    local session_id="$1"
    local iteration="$2"
    local output="$3"
    local ts
    ts=$(lisa_timestamp_local)

    lisa_init_logs

    {
        echo ""
        echo "================================================================================"
        echo "Session: $session_id | Iteration: $iteration | Timestamp: $ts"
        echo "================================================================================"
        echo ""
        echo "$output"
        echo ""
    } >> "$(lisa_get_full_output_log_path)"
}

# Extract key information from Claude output for concise display
# Usage: summary=$(lisa_extract_output_summary "full output")
# Returns: A concise summary of key actions taken
lisa_extract_output_summary() {
    local output="$1"
    local summary=""
    local line_count=0
    local max_summary_lines=15

    # Check for PRD COMPLETE signal
    if echo "$output" | grep -q '<promise>COMPLETE</promise>'; then
        summary="✓ PRD marked as COMPLETE"
        echo "$summary"
        return 0
    fi

    # Extract files created/modified (look for common patterns)
    local files_created=""
    local files_modified=""
    local tests_run=""
    local errors_found=""

    # Look for file operation patterns in output
    # Pattern: "Created file:" or "Writing to:" or similar
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Check for file creation patterns
        if echo "$line" | grep -qiE '(created|wrote|writing|new file|added file|creating).*\.(sh|js|ts|py|md|json|yaml|yml|txt)'; then
            local file_match
            file_match=$(echo "$line" | grep -oE '[a-zA-Z0-9_/-]+\.(sh|js|ts|py|md|json|yaml|yml|txt)' | head -1)
            if [[ -n "$file_match" ]] && [[ ! "$files_created" == *"$file_match"* ]]; then
                if [[ -n "$files_created" ]]; then
                    files_created="${files_created}, ${file_match}"
                else
                    files_created="$file_match"
                fi
            fi
        fi

        # Check for file modification patterns
        if echo "$line" | grep -qiE '(modified|updated|edited|changed|editing).*\.(sh|js|ts|py|md|json|yaml|yml|txt)'; then
            local file_match
            file_match=$(echo "$line" | grep -oE '[a-zA-Z0-9_/-]+\.(sh|js|ts|py|md|json|yaml|yml|txt)' | head -1)
            if [[ -n "$file_match" ]] && [[ ! "$files_modified" == *"$file_match"* ]]; then
                if [[ -n "$files_modified" ]]; then
                    files_modified="${files_modified}, ${file_match}"
                else
                    files_modified="$file_match"
                fi
            fi
        fi

        # Check for test execution patterns
        if echo "$line" | grep -qiE '(running tests|test passed|tests passed|all tests|test.*success|bash -n|shellcheck|syntax check)'; then
            tests_run="yes"
        fi

        # Check for error patterns
        if echo "$line" | grep -qiE '(error:|failed:|failure:|exception:)'; then
            errors_found="yes"
        fi
    done <<< "$output"

    # Build summary output
    local summary_lines=()

    if [[ -n "$files_created" ]]; then
        summary_lines+=("  Files created: $files_created")
    fi

    if [[ -n "$files_modified" ]]; then
        summary_lines+=("  Files modified: $files_modified")
    fi

    if [[ "$tests_run" == "yes" ]]; then
        summary_lines+=("  Tests/validation: executed")
    fi

    if [[ "$errors_found" == "yes" ]]; then
        summary_lines+=("  ⚠ Errors detected in output")
    fi

    # If no specific actions found, provide generic summary
    if [[ ${#summary_lines[@]} -eq 0 ]]; then
        # Try to extract task description from PRD update
        local task_summary
        task_summary=$(echo "$output" | grep -oE 'Task [0-9]+\.[0-9]+[^:]*' | head -1)
        if [[ -n "$task_summary" ]]; then
            summary_lines+=("  Working on: $task_summary")
        else
            summary_lines+=("  Iteration completed (see full log for details)")
        fi
    fi

    # Output the summary
    for line in "${summary_lines[@]}"; do
        echo "$line"
    done
}

# Filter and display output for terminal, log full to file
# Usage: lisa_filter_output "session_id" 5 "full output"
# Displays concise summary to terminal, logs full output to file
lisa_filter_output() {
    local session_id="$1"
    local iteration="$2"
    local output="$3"

    # Always log the full output to file
    lisa_log_full_output "$session_id" "$iteration" "$output"

    # Check if filtering is enabled
    if [[ "$LISA_FILTER_OUTPUT" != "true" ]]; then
        # Filtering disabled, output everything
        echo "$output"
        return 0
    fi

    # Extract and display concise summary
    local summary
    summary=$(lisa_extract_output_summary "$output")

    if [[ -n "$summary" ]]; then
        echo "$summary"
    fi

    # Always indicate where full output can be found
    lisa_debug "Full output logged to: $(lisa_get_full_output_log_path)"
}

# Get output statistics from full output
# Usage: stats=$(lisa_get_output_stats "full output")
# Returns: line count and character count
lisa_get_output_stats() {
    local output="$1"
    local line_count
    local char_count

    line_count=$(echo "$output" | wc -l | tr -d ' ')
    char_count=$(echo "$output" | wc -c | tr -d ' ')

    echo "lines=$line_count chars=$char_count"
}

# Export output filtering functions
export -f lisa_get_full_output_log_path
export -f lisa_log_full_output
export -f lisa_extract_output_summary
export -f lisa_filter_output
export -f lisa_get_output_stats

# ==============================================================================
# Claude CLI Wrapper Functions
# ==============================================================================

# Unified wrapper for Claude CLI invocations
# Handles output streaming, logging, and verbosity control
# Usage: lisa_claude [options] <claude-args>
# Usage: output=$(lisa_claude --capture [options] <claude-args>)
#
# Wrapper Options:
#   --capture           Return output as string (for variable capture)
#   --label "name"      Label for logs (default: "claude")
#
# Verbosity Levels (LISA_VERBOSE):
#   0 = Silent (only errors)
#   1 = Filtered (summaries)
#   2 = Full (default, all output in real-time)
lisa_claude() {
    local capture_mode=false
    local label="claude"
    local claude_args=()

    # Parse wrapper-specific options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --capture)
                capture_mode=true
                shift
                ;;
            --label)
                label="$2"
                shift 2
                ;;
            *)
                # All other arguments pass through to claude
                claude_args+=("$1")
                shift
                ;;
        esac
    done

    # Determine verbosity level (default to 2 = full output)
    local verbose="${LISA_VERBOSE:-2}"

    # Create session ID for logging
    local session_id="${label}_$(date +%s)"
    local log_file
    log_file=$(lisa_get_full_output_log_path)

    # Check if claude command exists
    if ! command -v claude &>/dev/null; then
        lisa_error "claude command not found in PATH"
        return 1
    fi

    # Prepend model flag if LISA_MODEL is set
    if [[ -n "$LISA_MODEL" ]]; then
        claude_args=("--model" "$LISA_MODEL" "${claude_args[@]}")
    fi

    if [[ "$capture_mode" == "true" ]]; then
        # Capture mode: collect output for return value
        local output
        local exit_code

        lisa_debug "Calling claude with ${#claude_args[@]} arguments"

        if [[ "$verbose" -ge 2 ]]; then
            # Verbose: show AND capture
            # Use a temp file to avoid process substitution issues
            local temp_out=$(mktemp)
            claude "${claude_args[@]}" 2>&1 | tee "$temp_out"
            exit_code=${PIPESTATUS[0]}
            output=$(cat "$temp_out")
            rm -f "$temp_out"
        else
            # Not verbose: silent capture
            output=$(claude "${claude_args[@]}" 2>&1)
            exit_code=$?
        fi

        # Check for errors
        if [[ $exit_code -ne 0 ]]; then
            lisa_error "Claude command failed with exit code $exit_code"
            lisa_log_full_output "$session_id" 0 "ERROR: Exit code $exit_code\n$output"
            echo "$output" >&2
            return $exit_code
        fi

        # Check if output is empty
        if [[ -z "$output" || "${#output}" -lt 10 ]]; then
            lisa_warn "Claude returned empty or very short output (${#output} bytes)"
            lisa_debug "Output: '$output'"
        fi

        # Always log to file regardless of verbosity
        lisa_log_full_output "$session_id" 0 "$output"

        # Return the output
        echo "$output"
    else
        # Direct streaming mode: output goes to console based on verbosity
        if [[ "$verbose" -ge 2 ]]; then
            # Full verbose: show everything in real-time
            claude "${claude_args[@]}" 2>&1 | tee -a "$log_file"
            return ${PIPESTATUS[0]}
        elif [[ "$verbose" -eq 1 ]]; then
            # Filtered: collect, show summary, log full
            local output
            output=$(claude "${claude_args[@]}" 2>&1)
            local exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                lisa_error "Claude command failed with exit code $exit_code"
                lisa_log_full_output "$session_id" 0 "ERROR: Exit code $exit_code\n$output"
                echo "$output" >&2
                return $exit_code
            fi

            lisa_log_full_output "$session_id" 0 "$output"

            # Show filtered summary
            lisa_extract_output_summary "$output"
        else
            # Silent: only log to file
            claude "${claude_args[@]}" >> "$log_file" 2>&1
            return $?
        fi
    fi
}

# Parse verbosity flags from command line arguments
# Sets LISA_VERBOSE environment variable based on flags
# Returns remaining non-flag arguments
# Usage: remaining_args=$(lisa_parse_verbose_flags "$@")
lisa_parse_verbose_flags() {
    local remaining_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                export LISA_VERBOSE=2
                shift
                ;;
            -q|--quiet)
                export LISA_VERBOSE=1
                shift
                ;;
            -qq|--very-quiet|--silent)
                export LISA_VERBOSE=0
                shift
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Return remaining args
    echo "${remaining_args[@]}"
}

# Export Claude wrapper functions
export -f lisa_claude
export -f lisa_parse_verbose_flags

# ==============================================================================
# Template Loading Functions (for Prompts)
# ==============================================================================

# Default prompts directory
LISA_PROMPTS_DIR="${LISA_PROMPTS_DIR:-prompts}"

# Load a prompt template and replace variables
# Usage: prompt=$(lisa_load_template "template-name.md" "VAR1=value1" "VAR2=value2")
# Example: prompt=$(lisa_load_template "prd-generation-prompt.md" "USER_DESCRIPTION=$desc")
lisa_load_template() {
    local template_name="$1"
    shift
    local template_path="$LISA_PROMPTS_DIR/$template_name"

    # Check if template exists
    if [[ ! -f "$template_path" ]]; then
        lisa_error "Template not found: $template_path"
        return 1
    fi

    # Load template content
    local template_content
    template_content=$(cat "$template_path")

    # Replace each variable
    for var_assignment in "$@"; do
        # Split VAR=value
        local var_name="${var_assignment%%=*}"
        local var_value="${var_assignment#*=}"

        # Replace {{VAR_NAME}} with value
        template_content="${template_content//\{\{$var_name\}\}/$var_value}"
    done

    echo "$template_content"
}

# Load a template with fallback to inline prompt
# Usage: prompt=$(lisa_load_template_safe "template.md" "fallback prompt" "VAR1=value1")
lisa_load_template_safe() {
    local template_name="$1"
    local fallback_prompt="$2"
    shift 2

    # Try to load template
    local prompt
    if prompt=$(lisa_load_template "$template_name" "$@" 2>/dev/null); then
        echo "$prompt"
    else
        # Use fallback
        lisa_debug "Using fallback prompt for $template_name"
        # Replace variables in fallback too
        for var_assignment in "$@"; do
            local var_name="${var_assignment%%=*}"
            local var_value="${var_assignment#*=}"
            fallback_prompt="${fallback_prompt//\{\{$var_name\}\}/$var_value}"
        done
        echo "$fallback_prompt"
    fi
}

# List available templates
# Usage: lisa_list_templates
lisa_list_templates() {
    if [[ -d "$LISA_PROMPTS_DIR" ]]; then
        ls -1 "$LISA_PROMPTS_DIR"/*.md 2>/dev/null | xargs -n 1 basename
    else
        lisa_warn "Prompts directory not found: $LISA_PROMPTS_DIR"
    fi
}

# Export template functions
export -f lisa_load_template
export -f lisa_load_template_safe
export -f lisa_list_templates
