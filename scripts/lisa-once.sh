#!/bin/bash

# Get script directory, lisa folder, and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Work in project root for git operations
cd "$PROJECT_ROOT"

# Set up logging environment (logs and state files are in lisa folder)
export LISA_LOG_DIR="$LISA_DIR/logs"
export LISA_STATUS_FILE="$LISA_DIR/.lisa-status.json"
export LISA_STATE_FILE="$LISA_DIR/.lisa-state.json"
export LISA_PROMPTS_DIR="$LISA_DIR/prompts"

# Source ralph library for logging
if [[ -f "$SCRIPT_DIR/ralph-lib.sh" ]]; then
    source "$SCRIPT_DIR/ralph-lib.sh"
    lisa_setup_logging
fi

# PRD.md and progress.txt are always inside the lisa folder (not project root)
PRD_FILE="$LISA_DIR/PRD.md"
PROGRESS_FILE="$LISA_DIR/progress.txt"

# Load ralph-once prompt from template
once_prompt=$(lisa_load_template "ralph-once-prompt.md" "PRD_FILE=$PRD_FILE" "PROGRESS_FILE=$PROGRESS_FILE")

IS_SANDBOX=1 claude --model "$LISA_MODEL" --dangerously-skip-permissions "@$PRD_FILE @$PROGRESS_FILE

$once_prompt"