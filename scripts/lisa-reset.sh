#!/bin/bash
# lisa-reset.sh - Reset Lisa to clean state
# Clears all project artifacts and state while preserving Lisa installation

set -e

# ==============================================================================
# Path Setup
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Work in project root
cd "$PROJECT_ROOT"

# Set up logging environment
export LISA_LOG_DIR="$LISA_DIR/logs"
export LISA_STATUS_FILE="$LISA_DIR/.lisa-status.json"
export LISA_STATE_FILE="$LISA_DIR/.lisa-state.json"

# Source lisa library
if [[ -f "$SCRIPT_DIR/lisa-lib.sh" ]]; then
    source "$SCRIPT_DIR/lisa-lib.sh"
    lisa_setup_logging
fi

# ==============================================================================
# Colors
# ==============================================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# Global Variables
# ==============================================================================
BACKUP_MODE=false
FORCE_MODE=false
KEEP_CONFIG=false
KEEP_CONTEXT=false
DRY_RUN=false
BACKUP_DIR=""

# ==============================================================================
# Functions
# ==============================================================================

show_help() {
    cat << EOF
Usage: lisa-reset.sh [OPTIONS]

Reset Lisa to clean state by removing all project artifacts and state.

Options:
  --backup, -b         Create backup before deletion
  --force, -f          Skip confirmation prompt
  --keep-config        Preserve lisa_config.yaml
  --keep-context       Preserve context/ directory
  --dry-run            Show what would be deleted without deleting
  --help, -h           Show this help message

Examples:
  lisa-reset.sh                    # Interactive reset with confirmation
  lisa-reset.sh --backup           # Create backup before reset
  lisa-reset.sh --force            # Reset without confirmation
  lisa-reset.sh --keep-config      # Reset but keep ML configuration
  lisa-reset.sh --dry-run          # Preview what will be deleted

Warning: This will delete all project progress, logs, and ML artifacts.
EOF
}

check_running_processes() {
    local any_running=false

    lisa_info "Checking for running Lisa processes..."

    # Check for monitor process
    if [[ -f "$LISA_DIR/.lisa-monitor.pid" ]]; then
        local MONITOR_PID
        MONITOR_PID=$(cat "$LISA_DIR/.lisa-monitor.pid")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            lisa_warn "Monitor process is running (PID: $MONITOR_PID)"
            any_running=true
        fi
    fi

    # Check status file for running sessions
    if [[ -f "$LISA_STATUS_FILE" ]]; then
        local status
        status=$(cat "$LISA_STATUS_FILE" 2>/dev/null || echo "")
        if echo "$status" | grep -q '"status":"running"'; then
            lisa_warn "Lisa appears to be running (check .lisa-status.json)"
            any_running=true
        fi
    fi

    if [[ "$any_running" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

stop_running_processes() {
    lisa_info "Stopping running Lisa processes..."

    # Stop monitor if running
    if [[ -f "$LISA_DIR/.lisa-monitor.pid" ]]; then
        local MONITOR_PID
        MONITOR_PID=$(cat "$LISA_DIR/.lisa-monitor.pid")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            lisa_info "Stopping monitor process (PID: $MONITOR_PID)..."
            kill -TERM "$MONITOR_PID" 2>/dev/null || true

            # Wait for graceful shutdown
            for i in {1..5}; do
                if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
                    lisa_info "Monitor stopped gracefully"
                    break
                fi
                sleep 1
            done

            # Force kill if still running
            if kill -0 "$MONITOR_PID" 2>/dev/null; then
                lisa_warn "Force stopping monitor..."
                kill -9 "$MONITOR_PID" 2>/dev/null || true
            fi
        fi
    fi

    lisa_info "All processes stopped"
}

create_backup() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="$LISA_DIR/backups/backup_$timestamp"

    lisa_info "Creating backup at: $backup_dir"
    mkdir -p "$backup_dir"

    local backup_count=0

    # Define files to backup
    local FILES_TO_DELETE=(
        ".lisa-status.json"
        ".lisa-state.json"
        ".lisa-monitor.pid"
        "PRD.md"
        "progress.txt"
        "progress-archive.txt"
        "review-results.txt"
        "fix-results.txt"
        "prd-review.txt"
        "lisa-summary.txt"
    )

    # Define directories to backup
    local DIRS_TO_DELETE=(
        "logs"
        "lisas_diary"
        "lisas_laboratory"
        "mlruns"
    )

    # Backup files
    for item in "${FILES_TO_DELETE[@]}"; do
        local full_path="$LISA_DIR/$item"
        if [[ -e "$full_path" ]]; then
            cp "$full_path" "$backup_dir/" 2>/dev/null || true
            backup_count=$((backup_count + 1))
        fi
    done

    # Backup directories
    for item in "${DIRS_TO_DELETE[@]}"; do
        local full_path="$LISA_DIR/$item"
        if [[ -d "$full_path" ]]; then
            cp -r "$full_path" "$backup_dir/" 2>/dev/null || true
            backup_count=$((backup_count + 1))
        fi
    done

    # Backup context if configured
    if [[ "$KEEP_CONTEXT" == "false" ]] && [[ -d "$PROJECT_ROOT/context" ]]; then
        mkdir -p "$backup_dir/project_context"
        cp -r "$PROJECT_ROOT/context" "$backup_dir/project_context/" 2>/dev/null || true
        backup_count=$((backup_count + 1))
    fi

    # Backup lisa_config.yaml if configured
    if [[ "$KEEP_CONFIG" == "false" ]] && [[ -f "$PROJECT_ROOT/lisa_config.yaml" ]]; then
        cp "$PROJECT_ROOT/lisa_config.yaml" "$backup_dir/" 2>/dev/null || true
        backup_count=$((backup_count + 1))
    fi

    lisa_info "Backed up $backup_count items to: $backup_dir"
    echo "$backup_dir"
}

show_deletion_preview() {
    lisa_header "Files and Directories to be Deleted"

    echo -e "${CYAN}State and Tracking Files:${NC}"
    for file in ".lisa-status.json" ".lisa-state.json" ".lisa-monitor.pid"; do
        [[ -f "$LISA_DIR/$file" ]] && echo "  • $file"
    done

    echo ""
    echo -e "${CYAN}Project Documentation:${NC}"
    for file in "PRD.md" "progress.txt" "progress-archive.txt"; do
        [[ -f "$LISA_DIR/$file" ]] && echo "  • $file"
    done

    echo ""
    echo -e "${CYAN}Review and Result Files:${NC}"
    for file in "review-results.txt" "fix-results.txt" "prd-review.txt" "lisa-summary.txt"; do
        [[ -f "$LISA_DIR/$file" ]] && echo "  • $file"
    done

    echo ""
    echo -e "${CYAN}Directories:${NC}"
    [[ -d "$LISA_DIR/logs" ]] && echo "  • logs/ (all log files)"
    [[ -d "$LISA_DIR/lisas_diary" ]] && echo "  • lisas_diary/ (ML documentation)"
    [[ -d "$LISA_DIR/lisas_laboratory" ]] && echo "  • lisas_laboratory/ (ML artifacts)"
    [[ -d "$LISA_DIR/mlruns" ]] && echo "  • mlruns/ (MLflow tracking)"

    if [[ "$KEEP_CONTEXT" == "false" ]]; then
        echo ""
        echo -e "${CYAN}Project Files (Optional):${NC}"
        [[ -d "$PROJECT_ROOT/context" ]] && echo "  • context/ (will be deleted)"
    fi

    if [[ "$KEEP_CONFIG" == "false" ]]; then
        [[ -f "$PROJECT_ROOT/lisa_config.yaml" ]] && echo "  • lisa_config.yaml (will be deleted)"
    fi

    echo ""
    echo -e "${GREEN}Files to be Preserved:${NC}"
    echo "  • All scripts in scripts/"
    echo "  • All prompts in prompts/"
    echo "  • All templates in templates/"
    echo "  • Python modules in python/lisa/"
    echo "  • GUIDELINES.md, requirements-lisa.txt"
    echo "  • lisa_config.yaml.template"
    echo "  • .gitignore"

    if [[ "$KEEP_CONFIG" == "true" ]]; then
        echo "  • lisa_config.yaml (--keep-config)"
    fi

    if [[ "$KEEP_CONTEXT" == "true" ]]; then
        echo "  • context/ directory (--keep-context)"
    fi

    echo ""
}

perform_deletion() {
    local deleted_count=0
    local failed_count=0

    lisa_info "Starting deletion process..."

    # Define files to delete
    local FILES_TO_DELETE=(
        ".lisa-status.json"
        ".lisa-state.json"
        ".lisa-monitor.pid"
        "PRD.md"
        "progress.txt"
        "progress-archive.txt"
        "review-results.txt"
        "fix-results.txt"
        "prd-review.txt"
        "lisa-summary.txt"
    )

    # Define directories to delete
    local DIRS_TO_DELETE=(
        "logs"
        "lisas_diary"
        "lisas_laboratory"
        "mlruns"
    )

    # Delete individual files
    for file in "${FILES_TO_DELETE[@]}"; do
        local full_path="$LISA_DIR/$file"
        if [[ -f "$full_path" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                lisa_info "[DRY RUN] Would delete: $file"
                deleted_count=$((deleted_count + 1))
            else
                if rm -f "$full_path" 2>/dev/null; then
                    lisa_info "Deleted: $file"
                    deleted_count=$((deleted_count + 1))
                else
                    lisa_error "Failed to delete: $file"
                    failed_count=$((failed_count + 1))
                fi
            fi
        fi
    done

    # Delete directories
    for dir in "${DIRS_TO_DELETE[@]}"; do
        local full_path="$LISA_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                local item_count
                item_count=$(find "$full_path" -type f 2>/dev/null | wc -l | tr -d ' ')
                lisa_info "[DRY RUN] Would delete: $dir/ ($item_count files)"
                deleted_count=$((deleted_count + 1))
            else
                if rm -rf "$full_path" 2>/dev/null; then
                    lisa_info "Deleted: $dir/"
                    deleted_count=$((deleted_count + 1))
                else
                    lisa_error "Failed to delete: $dir/"
                    failed_count=$((failed_count + 1))
                fi
            fi
        fi
    done

    # Delete context directory if configured
    if [[ "$KEEP_CONTEXT" == "false" ]] && [[ -d "$PROJECT_ROOT/context" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            lisa_info "[DRY RUN] Would delete: context/ directory"
            deleted_count=$((deleted_count + 1))
        else
            if rm -rf "$PROJECT_ROOT/context" 2>/dev/null; then
                lisa_info "Deleted: context/ directory"
                deleted_count=$((deleted_count + 1))
            else
                lisa_error "Failed to delete: context/ directory"
                failed_count=$((failed_count + 1))
            fi
        fi
    fi

    # Delete lisa_config.yaml if configured
    if [[ "$KEEP_CONFIG" == "false" ]] && [[ -f "$PROJECT_ROOT/lisa_config.yaml" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            lisa_info "[DRY RUN] Would delete: lisa_config.yaml"
            deleted_count=$((deleted_count + 1))
        else
            if rm -f "$PROJECT_ROOT/lisa_config.yaml" 2>/dev/null; then
                lisa_info "Deleted: lisa_config.yaml"
                deleted_count=$((deleted_count + 1))
            else
                lisa_error "Failed to delete: lisa_config.yaml"
                failed_count=$((failed_count + 1))
            fi
        fi
    fi

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        lisa_info "DRY RUN: Would delete $deleted_count items"
    else
        lisa_info "Successfully deleted $deleted_count items"
        if [[ $failed_count -gt 0 ]]; then
            lisa_warn "Failed to delete $failed_count items"
        fi
    fi

    return $failed_count
}

recreate_essential_files() {
    if [[ "$DRY_RUN" == "true" ]]; then
        lisa_info "[DRY RUN] Would recreate essential files"
        return 0
    fi

    lisa_info "Recreating essential files..."

    # Recreate empty PRD.md
    if [[ ! -f "$LISA_DIR/PRD.md" ]]; then
        touch "$LISA_DIR/PRD.md"
        lisa_info "Created: PRD.md"
    fi

    # Recreate empty progress.txt
    if [[ ! -f "$LISA_DIR/progress.txt" ]]; then
        touch "$LISA_DIR/progress.txt"
        lisa_info "Created: progress.txt"
    fi

    # Recreate logs directory
    if [[ ! -d "$LISA_DIR/logs" ]]; then
        mkdir -p "$LISA_DIR/logs"
        lisa_info "Created: logs/"
    fi

    # Recreate ML directories
    mkdir -p "$LISA_DIR/lisas_diary"
    mkdir -p "$LISA_DIR/lisas_laboratory/models"
    mkdir -p "$LISA_DIR/lisas_laboratory/plots/eda"
    mkdir -p "$LISA_DIR/lisas_laboratory/plots/training"
    mkdir -p "$LISA_DIR/lisas_laboratory/plots/evaluation"
    mkdir -p "$LISA_DIR/lisas_laboratory/experiments"
    mkdir -p "$LISA_DIR/lisas_laboratory/artifacts"
    mkdir -p "$LISA_DIR/mlruns"

    lisa_info "ML directory structure recreated"
}

cleanup_trap() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        lisa_error "Reset interrupted or failed (exit code: $exit_code)"
        lisa_error "Some files may have been partially deleted"

        if [[ "$BACKUP_MODE" == "true" ]] && [[ -n "$BACKUP_DIR" ]]; then
            echo ""
            echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"
            echo "You can restore from backup if needed"
        fi
    fi
}

# ==============================================================================
# Main Function
# ==============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup|-b)
                BACKUP_MODE=true
                shift
                ;;
            --force|-f)
                FORCE_MODE=true
                shift
                ;;
            --keep-config)
                KEEP_CONFIG=true
                shift
                ;;
            --keep-context)
                KEEP_CONTEXT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run with --help for usage"
                exit 1
                ;;
        esac
    done

    # Set trap for cleanup
    trap cleanup_trap EXIT

    echo -e "${CYAN}🔄 LISA Reset Utility${NC}"
    echo "==========================================="
    echo ""

    # Check for running processes
    if check_running_processes; then
        echo ""
        if [[ "$FORCE_MODE" == "true" ]]; then
            lisa_warn "Processes detected but --force specified"
            stop_running_processes
        else
            echo -e "${YELLOW}Warning: Lisa processes are running${NC}"
            echo ""
            read -p "Stop running processes and continue? [y/N]: " stop_confirm
            case $stop_confirm in
                [Yy]*)
                    stop_running_processes
                    ;;
                *)
                    echo "Cancelled."
                    exit 0
                    ;;
            esac
        fi
    else
        lisa_info "No running Lisa processes detected"
    fi

    echo ""

    # Show what will be deleted
    show_deletion_preview

    # Confirmation (unless --force or --dry-run)
    if [[ "$FORCE_MODE" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        echo -e "${RED}WARNING: This will permanently delete all listed files and directories!${NC}"
        echo ""

        if [[ "$BACKUP_MODE" == "false" ]]; then
            echo -e "${YELLOW}Tip: Use --backup to create a backup before deletion${NC}"
            echo ""
        fi

        read -p "Are you sure you want to reset Lisa? Type 'yes' to confirm: " confirmation

        if [[ "$confirmation" != "yes" ]]; then
            echo "Reset cancelled."
            exit 0
        fi
    fi

    echo ""

    # Create backup if requested
    if [[ "$BACKUP_MODE" == "true" ]] && [[ "$DRY_RUN" == "false" ]]; then
        BACKUP_DIR=$(create_backup)
        echo ""
    fi

    # Perform deletion
    perform_deletion
    local delete_result=$?

    echo ""

    # Recreate essential files
    if [[ "$DRY_RUN" == "false" ]]; then
        recreate_essential_files
    fi

    echo ""
    lisa_separator "="

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}Dry run complete - no files were deleted${NC}"
        echo "Run without --dry-run to perform actual reset"
    elif [[ $delete_result -eq 0 ]]; then
        echo -e "${GREEN}✓ Lisa reset complete!${NC}"
        echo ""
        echo "Lisa is now in a clean state, as if install.sh had just been run."
        echo ""
        echo "Next steps:"
        echo "  1. Run ./lisa-start.sh to begin a new project"
        echo "  2. Or manually create PRD.md to define your requirements"

        if [[ "$KEEP_CONTEXT" == "false" ]]; then
            echo "  3. Run ./scripts/lisa-prestart.sh to regenerate context files (if needed)"
        fi

        if [[ "$BACKUP_MODE" == "true" ]]; then
            echo ""
            echo "Backup saved at: $BACKUP_DIR"
        fi
    else
        echo -e "${YELLOW}⚠ Reset completed with some errors${NC}"
        echo "Some files may not have been deleted. Check the output above."
    fi

    lisa_separator "="
    echo ""
}

# Execute main function
main "$@"
