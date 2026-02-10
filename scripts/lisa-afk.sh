#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

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

# Create logs directory if it doesn't exist
mkdir -p "$LISA_LOG_DIR"

# AFK-specific log file
AFK_LOG="$LISA_LOG_DIR/lisa-afk.log"

# Source lisa library for logging
if [[ -f "$SCRIPT_DIR/lisa-lib.sh" ]]; then
    source "$SCRIPT_DIR/lisa-lib.sh"
    lisa_setup_logging
fi

# PRD.md and progress.txt are always inside the lisa folder (not project root)
PRD_FILE="$LISA_DIR/PRD.md"
PROGRESS_FILE="$LISA_DIR/progress.txt"
AFK_PROMPT="$LISA_DIR/prompts/lisa-afk-prompt.md"

# Max iterations (default to 1000 if not provided - safety limit)
MAX_ITERATIONS=${1:-1000}

if [[ "$MAX_ITERATIONS" -le 0 ]]; then
  echo "Usage: $0 [max_iterations]"
  echo "  max_iterations: Maximum number of iterations (default: 1000, use 0 for unlimited)"
  exit 1
fi

# Log startup info
echo "" >> "$AFK_LOG"
echo "========================================" >> "$AFK_LOG"
echo "AFK Session Started: $(date)" >> "$AFK_LOG"
echo "========================================" >> "$AFK_LOG"

echo -e "${CYAN}Lisa AFK Mode - Autonomous Execution${NC}"
echo "========================================"
echo -e "${YELLOW}Will run until all PRD tasks complete (max: $MAX_ITERATIONS iterations)${NC}"
echo ""

# Debug: Show paths and verify files exist
echo -e "${DIM}Configuration:${NC}"
echo -e "  Working directory: ${CYAN}$(pwd)${NC}"
echo -e "  LISA_DIR:         ${CYAN}$LISA_DIR${NC}"
echo -e "  PROJECT_ROOT:      ${CYAN}$PROJECT_ROOT${NC}"
echo ""

echo -e "${DIM}Input files:${NC}"

# Check PRD file
if [[ -f "$PRD_FILE" ]]; then
    prd_lines=$(wc -l < "$PRD_FILE")
    echo -e "  PRD_FILE:     ${GREEN}EXISTS${NC} ($prd_lines lines) - $PRD_FILE"
else
    echo -e "  PRD_FILE:     ${RED}MISSING${NC} - $PRD_FILE"
    echo "ERROR: PRD file not found!" >> "$AFK_LOG"
    exit 1
fi

# Check progress file
if [[ -f "$PROGRESS_FILE" ]]; then
    progress_lines=$(wc -l < "$PROGRESS_FILE")
    echo -e "  PROGRESS:     ${GREEN}EXISTS${NC} ($progress_lines lines) - $PROGRESS_FILE"
else
    echo -e "  PROGRESS:     ${YELLOW}MISSING${NC} (will be created) - $PROGRESS_FILE"
    echo "# Progress Log" > "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
fi

# Check prompt file
if [[ -f "$AFK_PROMPT" ]]; then
    prompt_lines=$(wc -l < "$AFK_PROMPT")
    echo -e "  AFK_PROMPT:   ${GREEN}EXISTS${NC} ($prompt_lines lines) - $AFK_PROMPT"
    echo "" >> "$AFK_LOG"
    echo "Prompt file contents:" >> "$AFK_LOG"
    cat "$AFK_PROMPT" >> "$AFK_LOG"
    echo "" >> "$AFK_LOG"
else
    echo -e "  AFK_PROMPT:   ${RED}MISSING${NC} - $AFK_PROMPT"
    echo "ERROR: AFK prompt file not found!" >> "$AFK_LOG"
    exit 1
fi

echo ""
echo -e "${DIM}Log file: $AFK_LOG${NC}"
echo ""

# Check for ML Mode
ML_CONFIG="$PROJECT_ROOT/lisa_config.yaml"
if [[ -f "$ML_CONFIG" ]]; then
    echo "========================================"
    echo -e "${CYAN}📊 ML Mode Detected${NC}"
    echo "========================================"
    echo ""
    echo -e "${GREEN}✓ Found lisa_config.yaml${NC}"
    echo "  Switching to ML experimentation workflow"
    echo ""

    # Log ML mode activation
    echo "ML Mode activated at $(date)" >> "$AFK_LOG"

    # Run ML experiment cycles
    MAX_EXPERIMENTS=$1
    experiment_count=0

    while [[ $experiment_count -lt $MAX_EXPERIMENTS ]]; do
        echo -e "\n${YELLOW}=== ML Experiment Cycle $((experiment_count + 1))/$MAX_EXPERIMENTS ===${NC}\n"

        # Run complete experiment cycle
        set +e
        bash "$SCRIPT_DIR/lisa-experiment.sh" all
        EXPERIMENT_EXIT_CODE=$?
        set -e

        echo -e "${CYAN}DEBUG: lisa-experiment.sh exited with code: $EXPERIMENT_EXIT_CODE${NC}"

        if [[ $EXPERIMENT_EXIT_CODE -eq 0 ]]; then
            # Continue with next experiment
            experiment_count=$((experiment_count + 1))
        elif [[ $EXPERIMENT_EXIT_CODE -eq 10 ]]; then
            # STOP - Target achieved or resource limit
            echo -e "\n${GREEN}🎉 Stopping criteria met - experimentation complete!${NC}"
            echo "ML Mode completed successfully at $(date)" >> "$AFK_LOG"
            echo -e "\n${CYAN}Check lisas_diary/ for final analysis and lisas_laboratory/ for results${NC}"

            # Return exit code 10 to indicate target was achieved
            # This is important for hybrid mode to know the reason for stopping
            exit 10
        elif [[ $EXPERIMENT_EXIT_CODE -eq 11 ]]; then
            # Strategy change recommended - continue with adjusted approach
            echo -e "\n${YELLOW}⚠ Strategy change detected - will adjust approach${NC}"
            echo -e "${CYAN}Lisa will automatically explore alternative approaches in next iteration${NC}"
            experiment_count=$((experiment_count + 1))

            # Log strategy change
            echo "Strategy change at experiment $experiment_count ($(date))" >> "$AFK_LOG"
        else
            # Real failure
            echo -e "${RED}❌ Experiment cycle failed with code $EXPERIMENT_EXIT_CODE${NC}"
            exit 1
        fi

        # Brief pause between experiments
        if [[ $experiment_count -lt $MAX_EXPERIMENTS ]]; then
            echo -e "\n${DIM}Pausing 5 seconds before next experiment...${NC}"
            sleep 5
        fi
    done

    echo -e "\n${CYAN}Completed $experiment_count ML experiment cycles${NC}"
    exit 0
fi

# Code Mode - Continue until COMPLETE or max iterations
echo "========================================"
echo -e "${CYAN}💻 Code Mode${NC}"
echo "========================================"
echo ""

i=1
while [[ $i -le $MAX_ITERATIONS ]]; do
  echo -e "${YELLOW}Iteration $i/$MAX_ITERATIONS${NC}"
  echo "----------------------------------------"

  # Log iteration start
  echo "" >> "$AFK_LOG"
  echo "--- Iteration $i/$MAX_ITERATIONS started at $(date) ---" >> "$AFK_LOG"

  # Read file contents
  prd_content=$(cat "$PRD_FILE")
  progress_content=$(cat "$PROGRESS_FILE")
  prompt_content=$(cat "$AFK_PROMPT")

  # Build the full prompt
  full_prompt="$prompt_content"

  # Show the command being run
  echo -e "${DIM}Running: claude --model $LISA_MODEL --dangerously-skip-permissions \"\$full_prompt\"${NC}"
  echo "Command: claude --model $LISA_MODEL --dangerously-skip-permissions \"\$full_prompt\"" >> "$AFK_LOG"
  echo "Full prompt content:" >> "$AFK_LOG"
  echo "$full_prompt" >> "$AFK_LOG"

  # Call claude with combined prompt - pass as direct string like gen-prd.sh
  # Capture both stdout and stderr, and track exit code
  set +e
  result=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$full_prompt" 2>&1)
  exit_code=$?
  set -e

  # Log results
  result_length=${#result}
  echo "Exit code: $exit_code" >> "$AFK_LOG"
  echo "Result length: $result_length chars" >> "$AFK_LOG"
  echo "Result (first 2000 chars):" >> "$AFK_LOG"
  echo "${result:0:2000}" >> "$AFK_LOG"
  echo "" >> "$AFK_LOG"

  # Show summary
  echo ""
  echo -e "  Exit code:     ${exit_code}"
  echo -e "  Output length: ${result_length} chars"

  if [[ $exit_code -ne 0 ]]; then
    echo -e "  ${RED}Claude exited with error code $exit_code${NC}"
    echo ""
    echo -e "${DIM}First 500 chars of output:${NC}"
    echo "${result:0:500}"
    echo ""
  fi

  # Check for empty result
  if [[ -z "$result" ]] || [[ $result_length -lt 50 ]]; then
    echo -e "  ${RED}WARNING: Result is empty or very short!${NC}"
    echo "  This may indicate the prompt was not processed correctly."
    echo ""
    echo -e "${DIM}Full output:${NC}"
    echo "$result"
    echo ""
  fi

  # Check for completion marker
  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo ""
    echo -e "${GREEN}✓ All PRD tasks complete after $i iterations!${NC}"
    echo "PRD marked COMPLETE at $(date)" >> "$AFK_LOG"
    echo ""
    echo -e "${CYAN}Lisa has finished all tasks. Check the PRD for completed work.${NC}"
    exit 0
  fi

  echo -e "  ${GREEN}Iteration $i complete${NC}"
  echo "--- Iteration $i completed at $(date) ---" >> "$AFK_LOG"
  echo ""

  # Increment counter
  i=$((i + 1))
done

echo ""
echo -e "${YELLOW}⚠ Reached maximum iterations ($MAX_ITERATIONS) without completing all tasks.${NC}"
echo "Check $PRD_FILE to see remaining tasks."
echo "Check $AFK_LOG for detailed logs."
echo ""
echo "To continue, run: $0 $MAX_ITERATIONS"
echo ""