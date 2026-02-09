#!/bin/bash
set -e

# Default mode
MODE="code"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --help|-h)
            echo "Usage: lisa-start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode=MODE       Operation mode: code (default) or ml (machine learning)"
            echo "  -v, --verbose     Show full Claude output (default)"
            echo "  -q, --quiet       Show filtered summaries only"
            echo "  -qq, --silent     Silent mode, only errors"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Modes:"
            echo "  code              General software development (default)"
            echo "  ml                Machine Learning / Data Science"
            echo ""
            echo "Examples:"
            echo "  lisa-start.sh --mode=code"
            echo "  lisa-start.sh --mode=ml"
            echo ""
            exit 0
            ;;
        --mode=*)
            MODE="${arg#*=}"
            ;;
        --mode)
            shift
            MODE="$1"
            ;;
        -v|--verbose)
            export LISA_VERBOSE=2
            ;;
        -q|--quiet)
            export LISA_VERBOSE=1
            ;;
        -qq|--silent|--very-quiet)
            export LISA_VERBOSE=0
            ;;
        *)
            ;;
    esac
done

# Validate mode
if [[ "$MODE" != "code" && "$MODE" != "ml" ]]; then
    echo "❌ Invalid mode: $MODE"
    echo "Valid modes are: code, ml"
    echo ""
    echo "Run 'lisa-start.sh --help' for usage information"
    exit 1
fi

# Export mode for child scripts
export LISA_MODE="$MODE"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Work in project root for git operations, but reference lisa files
cd "$PROJECT_ROOT"

# Set up logging environment
export LISA_LOG_DIR="$SCRIPT_DIR/logs"
export LISA_STATUS_FILE="$SCRIPT_DIR/.lisa-status.json"
export LISA_STATE_FILE="$SCRIPT_DIR/.lisa-state.json"
export LISA_PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
export LISA_PROMPTS_DIR="$SCRIPT_DIR/prompts"

# Source lisa library for logging
if [[ -f "$SCRIPT_DIR/scripts/lisa-lib.sh" ]]; then
    source "$SCRIPT_DIR/scripts/lisa-lib.sh"
    lisa_setup_logging
fi

# PRD.md and progress.txt are always inside the lisa folder (not project root)
PRD_FILE="$SCRIPT_DIR/PRD.md"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Colors for better UX
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}🤖 LISA - Learning Intelligent Software Agent${NC}"
echo "==========================================="
echo -e "${CYAN}Mode: ${MODE}${NC}"
echo ""

# ML Mode: Additional setup and checks
if [[ "$MODE" == "ml" ]]; then
    echo -e "${YELLOW}📊 ML Mode Setup${NC}"
    echo ""

    # Check for lisa_config.yaml
    CONFIG_FILE="$PROJECT_ROOT/lisa_config.yaml"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}⚠ ML mode requires lisa_config.yaml${NC}"
        echo ""
        echo "Creating default lisa_config.yaml..."

        cat > "$CONFIG_FILE" <<'EOF'
project:
  name: "ml-project"
  base_dir: "."

paths:
  data: "data/"
  diary: "lisa/lisas_diary"
  laboratory: "lisa/lisas_laboratory"

mlflow:
  tracking_uri: "file:./lisa/mlruns"
  experiment_name: "default-experiment"

stopping_criteria:
  performance:
    enabled: true
    metric: "f1_score"
    threshold: 0.90
  improvement:
    enabled: true
    min_improvement_percent: 1.0
    window_size: 5
  convergence:
    enabled: true
    max_variance: 0.01
    window_size: 10
  resources:
    enabled: true
    max_experiments: 50
    max_time_hours: 24

data_science:
  large_dataset_threshold_mb: 500
  chunk_size_rows: 10000
  max_features_for_viz: 20
  random_seed: 42
EOF

        echo -e "${GREEN}✓ Created default lisa_config.yaml${NC}"
        echo "  Please review and customize it for your ML project"
        echo ""
    fi

    # Check for Python environment
    VENV_DIR="$SCRIPT_DIR/.venv-lisa-ml"
    if [[ ! -d "$VENV_DIR" ]]; then
        echo -e "${YELLOW}Setting up Python environment for ML mode...${NC}"
        echo ""

        # Check if Python 3 is available
        if ! command -v python3 &> /dev/null; then
            echo -e "${RED}❌ Python 3 not found${NC}"
            echo "ML mode requires Python 3.8 or higher"
            echo "Please install Python 3 and try again"
            exit 1
        fi

        # Create virtual environment
        python3 -m venv "$VENV_DIR"
        echo -e "${GREEN}✓ Created Python virtual environment${NC}"
        echo ""

        # Install dependencies
        echo "Installing ML dependencies..."
        source "$VENV_DIR/bin/activate"

        # Create requirements if doesn't exist
        REQUIREMENTS_FILE="$SCRIPT_DIR/requirements-lisa.txt"
        if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
            cat > "$REQUIREMENTS_FILE" <<'EOF'
# Core ML Libraries
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
matplotlib>=3.7.0
seaborn>=0.12.0

# ML Frameworks
xgboost>=2.0.0
lightgbm>=4.0.0

# Experiment Tracking
mlflow>=2.8.0

# Hyperparameter Optimization
optuna>=3.4.0

# Data Handling
pyyaml>=6.0
python-dateutil>=2.8.0

# Visualization
plotly>=5.17.0

# Progress bars
tqdm>=4.66.0
EOF
        fi

        pip install --quiet -r "$REQUIREMENTS_FILE"
        deactivate

        echo -e "${GREEN}✓ ML dependencies installed${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Python environment found${NC}"
        echo ""
    fi

    # Create ML directory structure if doesn't exist
    mkdir -p "$SCRIPT_DIR/lisas_diary"
    mkdir -p "$SCRIPT_DIR/lisas_laboratory/models"
    mkdir -p "$SCRIPT_DIR/lisas_laboratory/plots"
    mkdir -p "$SCRIPT_DIR/lisas_laboratory/artifacts"
    mkdir -p "$SCRIPT_DIR/mlruns"

    echo -e "${GREEN}✓ ML mode setup complete${NC}"
    echo ""
fi

# Check for context files
CONTEXT_DIR="$PROJECT_ROOT/context"
MISSING_FILES=()

[[ ! -f "$CONTEXT_DIR/ARCHITECTURE.md" ]] && MISSING_FILES+=("ARCHITECTURE.md")
[[ ! -f "$CONTEXT_DIR/BUSINESS_RULES.md" ]] && MISSING_FILES+=("BUSINESS_RULES.md")
[[ ! -f "$CONTEXT_DIR/GENERAL.md" ]] && MISSING_FILES+=("GENERAL.md")
[[ ! -f "$CONTEXT_DIR/CLAUDE.md" ]] && MISSING_FILES+=("CLAUDE.md")

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo -e "${YELLOW}📖 Context Documentation${NC}"
    echo ""
    if [[ ${#MISSING_FILES[@]} -eq 4 ]]; then
        echo "No context documentation found in $CONTEXT_DIR"
    else
        echo "Some context files are missing in $CONTEXT_DIR:"
        for file in "${MISSING_FILES[@]}"; do
            echo "  • $file"
        done
    fi
    echo ""
    echo "Context files help Lisa understand your codebase better by providing:"
    echo "  • Architecture overview and system structure"
    echo "  • Business rules and domain logic"
    echo "  • General project information and setup"
    echo ""
    echo "Would you like to generate the missing context files now?"
    echo "  [y] Yes, generate context files (recommended)"
    echo "  [n] No, skip for now"
    echo ""
    read -p "Your choice [y]: " generate_context
    generate_context=${generate_context:-y}

    case $generate_context in
        [Yy]* )
            echo ""
            echo -e "${CYAN}Generating context documentation...${NC}"
            echo ""
            if [[ -x "$SCRIPT_DIR/scripts/lisa-prestart.sh" ]]; then
                "$SCRIPT_DIR/scripts/lisa-prestart.sh"
                echo ""
                echo -e "${GREEN}✓ Context files generated successfully!${NC}"
                echo ""
            else
                echo -e "${YELLOW}⚠ Warning: scripts/lisa-prestart.sh not found or not executable${NC}"
                echo "Continuing without context files..."
                echo ""
            fi
            ;;
        * )
            echo ""
            echo "Skipping context generation. You can generate it later by running:"
            echo "  $SCRIPT_DIR/scripts/lisa-prestart.sh"
            echo ""
            ;;
    esac
else
    echo -e "${GREEN}✓ All context documentation files found${NC}"
    echo "  Location: $CONTEXT_DIR"
    echo ""
fi

# Step 1: Get brief description from user
echo -e "${YELLOW}Step 1: What do you want to build?${NC}"
echo ""
echo "Choose input method:"
echo "  [1] Type/paste directly (press Ctrl+D when done)"
echo "  [2] Open in editor (\$EDITOR)"
echo "  [3] Improve existing PRD"
echo "  [4] Skip PRD generation (use existing PRD.md)"
echo ""
read -p "Your choice [1]: " input_choice
input_choice=${input_choice:-1}

description=""
SKIP_PRD=false

case $input_choice in
    2)
        # Use editor
        TEMP_FILE=$(mktemp)
        ${EDITOR:-vim} "$TEMP_FILE"
        description=$(cat "$TEMP_FILE")
        rm -f "$TEMP_FILE"
        ;;
    3)
        # Improve existing PRD
        if [[ ! -f "$PRD_FILE" ]]; then
            echo -e "${YELLOW}⚠ No existing PRD found at: $PRD_FILE${NC}"
            echo ""
            echo "Please run lisa-start.sh first to create an initial PRD."
            exit 1
        fi

        echo ""
        echo -e "${CYAN}📝 Current PRD:${NC}"
        echo "==========================================="
        cat "$PRD_FILE"
        echo ""
        echo "==========================================="
        echo ""
        echo -e "${YELLOW}What improvements or changes do you want to make?${NC}"
        echo ""
        echo "Choose input method:"
        echo "  [1] Type/paste directly (press Ctrl+D when done)"
        echo "  [2] Open in editor (\$EDITOR)"
        echo ""
        read -p "Your choice [1]: " improvement_choice
        improvement_choice=${improvement_choice:-1}

        improvements=""
        case $improvement_choice in
            2)
                TEMP_FILE=$(mktemp)
                ${EDITOR:-vim} "$TEMP_FILE"
                improvements=$(cat "$TEMP_FILE")
                rm -f "$TEMP_FILE"
                ;;
            *)
                echo ""
                echo "Enter your improvements (paste is OK, press Ctrl+D on new line when done):"
                echo "---"
                improvements=$(cat)
                echo "---"
                ;;
        esac

        if [[ -z "$improvements" ]]; then
            echo "No improvements provided. Exiting."
            exit 1
        fi

        # Read existing PRD content
        existing_prd=$(cat "$PRD_FILE")

        # Create description that includes both the existing PRD and requested improvements
        description="EXISTING PRD:
$existing_prd

REQUESTED IMPROVEMENTS:
$improvements"
        ;;
    4)
        # Skip PRD generation and use existing
        if [[ ! -f "$PRD_FILE" ]]; then
            echo -e "${YELLOW}⚠ No existing PRD found at: $PRD_FILE${NC}"
            echo ""
            read -p "Continue without a PRD? [y/N]: " continue_without_prd
            case $continue_without_prd in
                [Yy]* )
                    echo "Creating minimal PRD..."
                    # Create minimal PRD
                    echo "# PRD - No specific requirements provided" > "$PRD_FILE"
                    echo "" >> "$PRD_FILE"
                    echo "Started without PRD generation on $(date)" >> "$PRD_FILE"
                    ;;
                * )
                    echo "Please create a PRD.md file in the lisa directory first."
                    exit 1
                    ;;
            esac
        fi

        echo ""
        echo -e "${GREEN}✓ Using existing PRD file:${NC}"
        echo "  $PRD_FILE"
        echo ""
        echo -e "${CYAN}Current PRD:${NC}"
        echo "==========================================="
        cat "$PRD_FILE"
        echo ""
        echo "==========================================="
        echo ""
        read -p "Press Enter to continue with this PRD..."

        # Set SKIP_PRD to skip the rest of PRD generation
        SKIP_PRD=true
        ;;
    *)
        # Direct input with Ctrl+D to finish
        echo ""
        echo "Enter your description (paste is OK, press Ctrl+D on new line when done):"
        echo "---"
        description=$(cat)
        echo "---"
        ;;
esac

if [[ -z "$description" ]] && [[ "$SKIP_PRD" != "true" ]]; then
    echo "No description provided. Exiting."
    exit 1
fi

if [[ "$SKIP_PRD" != "true" ]]; then
    echo ""
    echo -e "${CYAN}📝 Your description:${NC}"
    echo "$description"
    echo ""

    # Step 2: AI improves the prompt into a full PRD
    echo -e "${YELLOW}Step 2: Generating detailed PRD...${NC}"
    echo ""

    # Load PRD generation prompt from template
    prd_prompt=$(lisa_load_template "prd-generation-prompt.md" "USER_DESCRIPTION=$description")

    lisa_info "Generating PRD from your description..."
    claude --model "$LISA_MODEL" -p --dangerously-skip-permissions "$prd_prompt" > "$PRD_FILE" 2>&1

    echo -e "${GREEN}✓ PRD generated!${NC}"
    echo ""

    # Step 3: Show PRD for validation
    echo -e "${YELLOW}Step 3: Review the generated PRD${NC}"
    echo "==========================================="
    cat "$PRD_FILE"
    echo ""
    echo "==========================================="
    echo ""

    # Step 4: Ask for validation
    while true; do
        echo -e "${YELLOW}Options:${NC}"
        echo "  [y] Approve and start Lisa"
        echo "  [e] Edit PRD manually (opens in \$EDITOR)"
        echo "  [r] Regenerate with more details"
        echo "  [n] Cancel"
        echo ""
        read -p "Your choice: " choice

        case $choice in
            [Yy]* )
                echo ""
                echo -e "${GREEN}✓ PRD approved!${NC}"
                break
                ;;
            [Ee]* )
                ${EDITOR:-vim} "$PRD_FILE"
                echo ""
                echo -e "${CYAN}Updated PRD:${NC}"
                cat "$PRD_FILE"
                echo ""
                ;;
            [Rr]* )
                echo ""
                echo "Add more details or clarifications (press Ctrl+D when done):"
                echo "---"
                extra=$(cat)
                echo "---"
                description+=$'\n'"Additional details: "$extra
                echo -e "${YELLOW}Regenerating PRD...${NC}"

                # Load PRD generation prompt from template (reuse same template)
                prd_prompt=$(lisa_load_template "prd-generation-prompt.md" "USER_DESCRIPTION=$description")

                lisa_info "Regenerating PRD with additional details..."
                claude --model "$LISA_MODEL" -p --dangerously-skip-permissions "$prd_prompt" > "$PRD_FILE" 2>&1
                echo ""
                cat "$PRD_FILE"
                echo ""
                ;;
            [Nn]* )
                echo "Cancelled."
                exit 0
                ;;
            * )
                echo "Please answer y, e, r, or n."
                ;;
        esac
    done
fi  # End of PRD generation conditional

# Initialize progress file
echo "# Progress Log" > "$PROGRESS_FILE"
echo "" >> "$PROGRESS_FILE"
echo "Started: $(date)" >> "$PROGRESS_FILE"
echo "" >> "$PROGRESS_FILE"

# Step 5: Ask how to run Lisa
echo ""
echo -e "${YELLOW}How should Lisa work?${NC}"
echo "  [1] Babysitting mode (one task, then stop)"
echo "  [2] AFK mode (specify iterations)"
echo "  [3] Reset Lisa (clear all project data)"
echo ""
read -p "Your choice: " mode

case $mode in
    3 )
        echo ""
        echo -e "${YELLOW}⚠ Reset Lisa${NC}"
        echo "This will clear all project data and return to a clean state."
        echo ""
        read -p "Continue with reset? [y/N]: " reset_confirm
        case $reset_confirm in
            [Yy]*)
                "$SCRIPT_DIR/scripts/lisa-reset.sh"
                exit $?
                ;;
            *)
                echo "Reset cancelled."
                exit 0
                ;;
        esac
        ;;
    1 )
        echo ""
        echo -e "${CYAN}🚀 Starting Lisa (babysitting mode)...${NC}"
        echo ""
        "$SCRIPT_DIR/scripts/lisa-once.sh"
        ;;
    2 )
        read -p "How many iterations? " iterations
        echo ""
        read -p "Open oversight monitor in new terminal? [Y/n]: " open_monitor
        open_monitor=${open_monitor:-Y}
        echo ""

        echo -e "${CYAN}🚀 Starting Lisa (AFK mode, $iterations iterations)...${NC}"

        MONITOR_STARTED=false

        if [[ "$open_monitor" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}🔍 Opening oversight monitor in new terminal window...${NC}"
            echo ""

            # Start monitor in a new terminal window
            # Detect platform and open accordingly
            if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - use osascript to open new Terminal window
            echo "Opening new macOS Terminal window for monitor..."

            # Get project name from PROJECT_ROOT
            PROJECT_NAME=$(basename "$PROJECT_ROOT")

            # The terminal will stay open even if monitor exits
            osascript <<EOF >/dev/null 2>&1
tell application "Terminal"
    do script "cd '$PROJECT_ROOT' && clear && echo '═══════════════════════════════════════════════' && echo '🔍 RALPH OVERSIGHT MONITOR - $PROJECT_NAME' && echo '═══════════════════════════════════════════════' && echo '' && export LISA_PROJECT_NAME='$PROJECT_NAME' && '$SCRIPT_DIR/scripts/lisa-monitor.sh' || (echo ''; echo 'ERROR: Monitor failed to start'; echo 'Press any key to close'; read -n 1)"
    activate
end tell
EOF

            # Give Terminal.app time to open and come to foreground
            sleep 1

            echo ""
            echo "✓ Monitor terminal opened!"
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  📺 LOOK FOR THE NEW TERMINAL.APP WINDOW!            ║${NC}"
            echo -e "${GREEN}║                                                        ║${NC}"
            echo -e "${GREEN}║  A separate Terminal window should have opened with    ║${NC}"
            echo -e "${GREEN}║  the Lisa Monitor. Check your other windows/spaces.   ║${NC}"
            echo -e "${GREEN}║                                                        ║${NC}"
            echo -e "${GREEN}║  If you don't see it, press Cmd+Tab to find it.       ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
            echo ""
            read -p "Press Enter when you see the monitor window..."
            MONITOR_STARTED=true
        elif command -v gnome-terminal &> /dev/null; then
            # Linux with gnome-terminal
            gnome-terminal -- bash -c "cd '$PROJECT_ROOT' && '$SCRIPT_DIR/scripts/lisa-monitor.sh'; exec bash"
            echo "✓ Monitor terminal opened"
            MONITOR_STARTED=true
        elif command -v xterm &> /dev/null; then
            # Fallback to xterm
            xterm -e "cd '$PROJECT_ROOT' && '$SCRIPT_DIR/scripts/lisa-monitor.sh'" &
            echo "✓ Monitor terminal opened"
            MONITOR_STARTED=true
        else
            # Fallback: run in background of current terminal
            echo -e "${YELLOW}⚠ Could not detect terminal emulator. Running monitor in background.${NC}"
            "$SCRIPT_DIR/scripts/lisa-monitor.sh" &
            MONITOR_PID=$!
            echo "Monitor started in background (PID: $MONITOR_PID)"
            MONITOR_STARTED=true
        fi

            echo ""
            if [[ "$MONITOR_STARTED" == "true" ]]; then
                echo -e "${GREEN}You can now see Lisa's progress in this terminal${NC}"
                echo -e "${GREEN}and oversight monitoring in the other terminal.${NC}"
            else
                echo -e "${GREEN}You can now see Lisa's progress in this terminal.${NC}"
            fi
            echo ""
        fi

        # Run lisa-afk (this blocks until completion)
        "$SCRIPT_DIR/scripts/lisa-afk.sh" "$iterations"

        # After lisa-afk completes, stop the monitor
        echo ""
        echo -e "${YELLOW}Lisa AFK completed!${NC}"
        echo ""

        # Kill monitor gracefully (only if it was started)
        if [[ "$MONITOR_STARTED" == "true" ]]; then
            if [[ -f "$PROJECT_ROOT/.lisa-monitor.pid" ]]; then
                MONITOR_PID=$(cat "$PROJECT_ROOT/.lisa-monitor.pid")
                if kill -0 "$MONITOR_PID" 2>/dev/null; then
                    echo "Stopping oversight monitor..."
                    kill -TERM "$MONITOR_PID" 2>/dev/null || true
                    sleep 2
                    # Force kill if still running
                    if kill -0 "$MONITOR_PID" 2>/dev/null; then
                        kill -9 "$MONITOR_PID" 2>/dev/null || true
                    fi
                    echo -e "${GREEN}✓ Monitor stopped${NC}"
                else
                    echo -e "${YELLOW}Monitor already stopped${NC}"
                fi
            else
                echo -e "${YELLOW}Monitor PID file not found (monitor may have already stopped)${NC}"
            fi
        fi
        ;;
    * )
        echo "Invalid choice. You can run $SCRIPT_DIR/scripts/lisa-once.sh or $SCRIPT_DIR/scripts/lisa-afk.sh manually."
        exit 0
        ;;
esac

# Step 6: Run code review and fixes
echo ""
echo -e "${CYAN}🔍 Step 6: Code Review & Quality Check${NC}"
echo "==========================================="
echo ""

REVIEW_LOG="$SCRIPT_DIR/review-results.txt"
FIX_LOG="$SCRIPT_DIR/fix-results.txt"
MAX_FIX_ITERATIONS=3

# Ensure logs directory exists
mkdir -p "$SCRIPT_DIR/logs"

echo "Running comprehensive code review..."
echo "Review log will be saved to: $REVIEW_LOG"
echo "Fix log will be saved to: $FIX_LOG"
echo ""

# Get all modified/created files
modified_files=$(git diff --name-only HEAD 2>/dev/null || echo "")
staged_files=$(git diff --name-only --cached 2>/dev/null || echo "")
untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")

all_files="$modified_files $staged_files $untracked_files"

# Debug: Show what files were found
echo "Debug: Checking for files to review..."
echo "  Modified files: ${modified_files:-none}"
echo "  Staged files: ${staged_files:-none}"
echo "  Untracked files: ${untracked_files:-none}"
echo ""

if [[ -z "$all_files" ]]; then
    echo -e "${YELLOW}⚠ No new or modified files found to review.${NC}"
    echo ""
    echo "This is normal if:"
    echo "  1. Lisa already committed all changes during AFK mode"
    echo "  2. No changes were made to the codebase"
    echo ""
    echo "To review committed changes, you can use:"
    echo "  git log -1 --stat"
    echo "  git diff HEAD~1"
    echo ""
else
    # Build file list for Claude
    file_refs="@$PRD_FILE @$PROGRESS_FILE"
    file_count=0
    for file in $all_files; do
        if [[ -f "$file" ]] && [[ "$file" != "$REVIEW_LOG" ]] && [[ "$file" != "$FIX_LOG" ]]; then
            file_refs="$file_refs @$file"
            file_count=$((file_count + 1))
        fi
    done

    echo "Found $file_count files to review"
    echo "Files will be passed to Claude with PRD and Progress files"
    echo ""

    # Run review-and-fix loop
    for ((fix_iter=1; fix_iter<=MAX_FIX_ITERATIONS; fix_iter++)); do
        echo -e "${YELLOW}Review iteration $fix_iter/$MAX_FIX_ITERATIONS${NC}"
        echo ""

        # Run code review
        # Load code review prompt from template
        review_prompt=$(lisa_load_template "code-review-prompt.md" "PRD_FILE=$PRD_FILE" "PROGRESS_FILE=$PROGRESS_FILE")

        if [[ -z "$review_prompt" ]]; then
            echo -e "${RED}✗ Failed to load review prompt template${NC}"
            echo "Skipping code review step."
            break
        fi

        echo "Running Claude code review..."
        review_output=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$file_refs

$review_prompt" 2>&1)

        review_exit_code=$?

        if [[ $review_exit_code -ne 0 ]]; then
            echo -e "${RED}✗ Code review command failed (exit code: $review_exit_code)${NC}"
            echo "Error output:"
            echo "$review_output" | head -20
            echo ""
            echo "Skipping code review step."
            break
        fi

        if [[ -z "$review_output" ]]; then
            echo -e "${YELLOW}⚠ Code review returned no output${NC}"
            echo "Skipping code review step."
            break
        fi

        # Save review output
        echo "$review_output" > "$REVIEW_LOG"

        # Check if no issues found
        if echo "$review_output" | grep -q "<promise>NO_ISSUES</promise>"; then
            echo -e "${GREEN}✓ Code review passed! No issues found.${NC}"
            break
        fi

        echo "Issues found. Review summary:"
        echo "----------------------------------------"
        echo "$review_output" | head -30
        echo "----------------------------------------"
        echo ""
        echo "Full review saved to: $REVIEW_LOG"
        echo ""

        # Auto-fix issues
        echo -e "${CYAN}Applying fixes automatically...${NC}"
        echo ""

        # Load fix prompt from template
        fix_prompt=$(lisa_load_template "fix-prompt.md" "REVIEW_LOG=$REVIEW_LOG")

        if [[ -z "$fix_prompt" ]]; then
            echo -e "${RED}✗ Failed to load fix prompt template${NC}"
            echo "Skipping auto-fix step."
            break
        fi

        echo "Running Claude auto-fix..."
        fix_output=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$file_refs @$REVIEW_LOG

$fix_prompt" 2>&1)

        fix_exit_code=$?

        if [[ $fix_exit_code -ne 0 ]]; then
            echo -e "${RED}✗ Auto-fix command failed (exit code: $fix_exit_code)${NC}"
            echo "Error output:"
            echo "$fix_output" | head -20
            echo ""
            echo "Skipping auto-fix step."
            break
        fi

        if [[ -z "$fix_output" ]]; then
            echo -e "${YELLOW}⚠ Auto-fix returned no output${NC}"
            echo "Skipping auto-fix step."
            break
        fi

        echo "$fix_output" > "$FIX_LOG"
        echo "Fix summary:"
        echo "----------------------------------------"
        echo "$fix_output" | head -20
        echo "----------------------------------------"
        echo ""
        echo "Full fix log saved to: $FIX_LOG"
        echo ""

        # Check if fixes are complete
        if echo "$fix_output" | grep -q "<promise>FIXES_COMPLETE</promise>"; then
            echo -e "${GREEN}✓ All fixes applied successfully!${NC}"
            # Continue to next review iteration to verify
        fi

        # If this is the last iteration, warn
        if [[ $fix_iter -eq $MAX_FIX_ITERATIONS ]]; then
            echo -e "${YELLOW}⚠ Reached maximum fix iterations ($MAX_FIX_ITERATIONS)${NC}"
            echo "Some issues may still remain. Review manually if needed."
        fi

        echo ""
    done
fi

# Step 7: Run validation checks
echo ""
echo -e "${CYAN}🧪 Step 7: Running Validation Checks${NC}"
echo "==========================================="
echo ""

validation_passed=true

# Run shellcheck if available
if command -v shellcheck &> /dev/null; then
    echo "Running shellcheck on bash scripts..."
    shellcheck_errors=0
    for file in *.sh; do
        if [[ -f "$file" ]]; then
            if shellcheck "$file" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $file"
            else
                echo -e "  ${RED}✗${NC} $file"
                shellcheck_errors=$((shellcheck_errors + 1))
                validation_passed=false
            fi
        fi
    done
    if [[ $shellcheck_errors -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $shellcheck_errors shellcheck error(s) found${NC}"
    fi
    echo ""
fi

# Syntax check for common file types
echo "Running syntax checks..."
for file in $all_files; do
    if [[ -f "$file" ]]; then
        case "$file" in
            *.sh)
                if bash -n "$file" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} $file (bash syntax)"
                else
                    echo -e "  ${RED}✗${NC} $file (bash syntax error)"
                    validation_passed=false
                fi
                ;;
            *.py)
                if command -v python3 &> /dev/null; then
                    if python3 -m py_compile "$file" 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} $file (python syntax)"
                    else
                        echo -e "  ${RED}✗${NC} $file (python syntax error)"
                        validation_passed=false
                    fi
                fi
                ;;
            *.js)
                if command -v node &> /dev/null; then
                    if node --check "$file" 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} $file (javascript syntax)"
                    else
                        echo -e "  ${RED}✗${NC} $file (javascript syntax error)"
                        validation_passed=false
                    fi
                fi
                ;;
        esac
    fi
done
echo ""

# Step 8: Final summary
echo ""
echo -e "${CYAN}📊 Final Summary${NC}"
echo "==========================================="
echo ""

if [[ "$validation_passed" == "true" ]]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
else
    echo -e "${YELLOW}⚠ Some validation checks failed. Review the output above.${NC}"
fi

echo ""
echo "Files created/modified:"
git status --short 2>/dev/null || ls -lt | head -10
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Review the implementation:"
echo "     cat lisa/PRD.md"
echo "     cat lisa/progress.txt"
echo ""
echo "  2. Review code changes:"
echo "     git diff"
echo ""
echo "  3. Test your implementation manually"
echo ""
echo "  4. Review the code review results:"
echo "     cat lisa/review-results.txt"
echo ""
echo "  5. When satisfied, commit your changes:"
echo "     git add ."
echo "     git commit -m 'feat: implement [your feature]'"
echo ""
echo -e "${GREEN}✓ Lisa workflow complete!${NC}"
echo ""
