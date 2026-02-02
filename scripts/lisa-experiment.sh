#!/bin/bash
set -e

# LISA ML Experiment Orchestrator
# Executes complete ML experiment cycle: design -> train -> evaluate -> visualize -> stopping decision

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source library
source "$SCRIPT_DIR/lisa-lib.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
PHASE="${1:-all}"  # all, design, train, evaluate, visualize, stopping
EXPERIMENT_ID="${2:-}"

echo -e "${CYAN}🤖 LISA ML Experiment Orchestrator${NC}"
echo "==========================================="
echo ""

# Activate Python environment
if [[ -d "$LISA_DIR/.venv-lisa-ml" ]]; then
    source "$LISA_DIR/.venv-lisa-ml/bin/activate"
else
    echo -e "${RED}❌ Python environment not found: $LISA_DIR/.venv-lisa-ml${NC}"
    echo "Run lisa-start.sh --mode=ml first to set up environment"
    exit 1
fi

# Check if this is first experiment (EDA needed)
DIARY_DIR="$LISA_DIR/lisas_diary"
EDA_DONE=false

if ls "$DIARY_DIR"/eda_*.md 1> /dev/null 2>&1; then
    EDA_DONE=true
    echo -e "${GREEN}✓ EDA already completed${NC}"
else
    echo -e "${YELLOW}⚠ No EDA found - will perform EDA first${NC}"
fi

# Function: Run EDA
run_eda() {
    echo -e "\n${CYAN}=== Phase 1: Exploratory Data Analysis ===${NC}\n"

    # Load EDA prompt
    EDA_PROMPT="$LISA_DIR/prompts/lisa-eda-prompt.md"

    if [[ ! -f "$EDA_PROMPT" ]]; then
        echo -e "${RED}❌ EDA prompt not found: $EDA_PROMPT${NC}"
        return 1
    fi

    # Build context
    CONTEXT_PROMPT="$(cat <<'EOF'
You are LISA performing Exploratory Data Analysis.

Read the following files:
1. lisa/PRD.md - Project requirements and objectives
2. lisa_config.yaml - Configuration
3. Prompt file in prompts/ - EDA instructions

Then perform comprehensive EDA following the prompt instructions.

Key steps:
1. Discover datasets in data/ directory
2. Select most appropriate dataset
3. Load and profile data
4. Analyze quality, correlations, outliers
5. Generate visualizations
6. Document insights and recommendations in lisas_diary/

Output <promise>EDA_COMPLETE</promise> when finished.
EOF
)"

    # Execute with Claude
    echo -e "${DIM}Running Claude for EDA...${NC}"
    set +e
    result=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$CONTEXT_PROMPT" 2>&1)
    exit_code=$?
    set -e

    # Log results
    result_length=${#result}
    echo -e "  Exit code: ${exit_code}, Output length: ${result_length} chars"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ Claude exited with error code $exit_code${NC}"
        echo -e "${DIM}First 500 chars of output:${NC}"
        echo "${result:0:500}"
        return 1
    fi

    # Check for completion signal in output first, then in files
    if [[ "$result" == *"EDA_COMPLETE"* ]] || grep -q "EDA_COMPLETE" "$DIARY_DIR"/*.md 2>/dev/null; then
        echo -e "\n${GREEN}✓ EDA completed successfully${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠ EDA may not have completed - check lisas_diary/${NC}"
        echo -e "${DIM}Looking for <promise>EDA_COMPLETE</promise> in output or diary files${NC}"
        return 1
    fi
}

# Function: Design experiment
# Sets global EXPERIMENT_ID variable with the designed experiment ID
design_experiment() {
    echo -e "\n${CYAN}=== Phase 2: Experiment Design === [$(date +%H:%M:%S)]${NC}\n"

    DESIGN_PROMPT="$LISA_DIR/prompts/lisa-experiment-design-prompt.md"

    if [[ ! -f "$DESIGN_PROMPT" ]]; then
        echo -e "${RED}❌ Design prompt not found: $DESIGN_PROMPT${NC}"
        return 1
    fi

    # Count previous experiments
    NUM_EXPERIMENTS=$(ls "$LISA_DIR/lisas_laboratory/experiments/"*.json 2>/dev/null | wc -l | tr -d ' ')
    NEXT_EXP_ID=$(printf "exp_%03d" $((NUM_EXPERIMENTS + 1)))

    echo "Designing experiment: $NEXT_EXP_ID"
    echo "Previous experiments: $NUM_EXPERIMENTS"
    echo ""

    CONTEXT_PROMPT="You are LISA designing the next ML experiment.

Experiment ID: $NEXT_EXP_ID

Read the following:
1. lisa/lisas_diary/eda_*.md - Latest EDA report
2. lisa_config.yaml - Configuration and stopping criteria
3. lisa/PRD.md - Target metrics
4. Prompt file in prompts/ - Experiment design instructions

Analyze MLflow experiment history to see what has been tried.

Then design the next experiment following the prompt instructions.

Key outputs:
1. Save experiment config to: lisa/lisas_laboratory/experiments/${NEXT_EXP_ID}_config.json
2. Document reasoning in lisas_diary/
3. Output <promise>EXPERIMENT_DESIGNED:${NEXT_EXP_ID}</promise>

Be strategic: choose model and hyperparameters that maximize chance of improvement."

    echo -e "${DIM}Running Claude for experiment design...${NC}"
    set +e
    result=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$CONTEXT_PROMPT" 2>&1)
    exit_code=$?
    set -e

    # Log results
    result_length=${#result}
    echo -e "  Exit code: ${exit_code}, Output length: ${result_length} chars"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ Claude exited with error code $exit_code${NC}"
        echo -e "${DIM}First 500 chars of output:${NC}"
        echo "${result:0:500}"
        return 1
    fi

    # Check for experiment config or completion marker in output
    EXP_CONFIG="$LISA_DIR/lisas_laboratory/experiments/${NEXT_EXP_ID}_config.json"

    if [[ -f "$EXP_CONFIG" ]] || [[ "$result" == *"EXPERIMENT_DESIGNED:${NEXT_EXP_ID}"* ]]; then
        echo -e "\n${GREEN}✓ Experiment designed: $NEXT_EXP_ID${NC}"

        # If config file exists, set global and return success
        if [[ -f "$EXP_CONFIG" ]]; then
            EXPERIMENT_ID="$NEXT_EXP_ID"
            return 0
        else
            # Claude may still be writing the file, wait briefly
            sleep 2
            if [[ -f "$EXP_CONFIG" ]]; then
                EXPERIMENT_ID="$NEXT_EXP_ID"
                return 0
            else
                echo -e "${YELLOW}⚠ Design completed but config file not found yet${NC}"
                EXPERIMENT_ID="$NEXT_EXP_ID"  # Still set the ID
                return 0
            fi
        fi
    else
        echo -e "\n${RED}❌ Experiment config not found: $EXP_CONFIG${NC}"
        echo -e "${DIM}Looking for config file or <promise>EXPERIMENT_DESIGNED:${NEXT_EXP_ID}</promise>${NC}"
        EXPERIMENT_ID=""  # Clear on failure
        return 1
    fi
}

# Function: Train model
train_model() {
    local exp_id="$1"

    echo -e "\n${CYAN}=== Phase 3: Model Training ===${NC}\n"

    if [[ -z "$exp_id" ]]; then
        echo -e "${RED}❌ No experiment ID provided${NC}"
        return 1
    fi

    # Use dedicated training script
    bash "$SCRIPT_DIR/lisa-train.sh" "$exp_id"
    return $?
}

# Function: Evaluate model
evaluate_model() {
    local exp_id="$1"

    echo -e "\n${CYAN}=== Phase 4: Model Evaluation ===${NC}\n"

    if [[ -z "$exp_id" ]]; then
        echo -e "${RED}❌ No experiment ID provided${NC}"
        return 1
    fi

    # Use dedicated evaluation script
    bash "$SCRIPT_DIR/lisa-evaluate.sh" "$exp_id"
    return $?
}

# Function: Generate visualizations
generate_visualizations() {
    local exp_id="$1"

    echo -e "\n${CYAN}=== Phase 5: Visualization Generation ===${NC}\n"

    if [[ -z "$exp_id" ]]; then
        echo -e "${RED}❌ No experiment ID provided${NC}"
        return 1
    fi

    # Use dedicated visualization script
    bash "$SCRIPT_DIR/lisa-visualize.sh" "$exp_id"
    return $?
}

# Function: Evaluate stopping criteria
evaluate_stopping() {
    echo -e "\n${CYAN}=== Phase 6: Stopping Criteria Evaluation ===${NC}\n"

    STOPPING_PROMPT="$LISA_DIR/prompts/lisa-stopping-criteria-prompt.md"

    if [[ ! -f "$STOPPING_PROMPT" ]]; then
        echo -e "${RED}❌ Stopping prompt not found: $STOPPING_PROMPT${NC}"
        return 1
    fi

    CONTEXT_PROMPT="You are LISA evaluating whether to stop experimentation.

Read:
1. lisa_config.yaml - Stopping criteria configuration
2. lisa/PRD.md - Target metrics
3. All entries in lisas_diary/
4. Prompt file in prompts/ - Stopping evaluation instructions

Query MLflow for all experiment results.

Evaluate all stopping criteria:
- Performance threshold
- Improvement rate
- Convergence
- Resource limits

Make decision: STOP, CONTINUE, or CHANGE_STRATEGY

Document decision in lisas_diary/ with detailed reasoning.

Output: <promise>STOPPING_DECISION:{decision}:{best_score}:{recommendation}</promise>"

    echo -e "${DIM}Running Claude for stopping criteria evaluation...${NC}"
    set +e
    result=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$CONTEXT_PROMPT" 2>&1)
    exit_code=$?
    set -e

    # Log results
    result_length=${#result}
    echo -e "  Exit code: ${exit_code}, Output length: ${result_length} chars"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ Claude exited with error code $exit_code${NC}"
        echo -e "${DIM}First 500 chars of output:${NC}"
        echo "${result:0:500}"
        return 1
    fi

    # Parse decision from output first, then from diary files
    echo -e "\n${GREEN}✓ Stopping criteria evaluated${NC}"

    # Check output for decision markers
    if [[ "$result" == *"STOPPING_DECISION:STOP"* ]] || [[ "$result" == *"<promise>STOPPING_DECISION:STOP"* ]]; then
        echo -e "\n${YELLOW}Decision: STOP experimentation${NC}"
        return 10  # Special exit code for STOP
    elif [[ "$result" == *"STOPPING_DECISION:CHANGE_STRATEGY"* ]] || [[ "$result" == *"<promise>STOPPING_DECISION:CHANGE_STRATEGY"* ]]; then
        echo -e "\n${YELLOW}Decision: CHANGE STRATEGY${NC}"
        return 11  # Special exit code for strategy change
    elif [[ "$result" == *"STOPPING_DECISION:CONTINUE"* ]] || [[ "$result" == *"<promise>STOPPING_DECISION:CONTINUE"* ]]; then
        echo -e "\n${GREEN}Decision: CONTINUE${NC}"
        return 0
    fi

    # Fallback: check diary files
    LATEST_STOPPING=$(ls -t "$DIARY_DIR"/stopping_decision_*.md 2>/dev/null | head -1)

    if [[ -f "$LATEST_STOPPING" ]]; then
        # Try to extract decision from file
        if grep -q "STOP" "$LATEST_STOPPING"; then
            echo -e "\n${YELLOW}Decision: STOP experimentation (from diary)${NC}"
            return 10
        elif grep -q "CHANGE_STRATEGY" "$LATEST_STOPPING"; then
            echo -e "\n${YELLOW}Decision: CHANGE STRATEGY (from diary)${NC}"
            return 11
        else
            echo -e "\n${GREEN}Decision: CONTINUE (from diary)${NC}"
            return 0
        fi
    else
        # Default to CONTINUE if no clear decision found
        echo -e "\n${GREEN}Decision: CONTINUE (default - no clear signal found)${NC}"
        return 0
    fi
}

# Main execution flow
main() {
    # Create necessary directories
    mkdir -p "$LISA_DIR/lisas_diary"
    mkdir -p "$LISA_DIR/lisas_laboratory/experiments"
    mkdir -p "$LISA_DIR/lisas_laboratory/models"
    mkdir -p "$LISA_DIR/lisas_laboratory/plots"

    case "$PHASE" in
        eda)
            run_eda
            ;;

        design)
            if [[ "$EDA_DONE" = false ]]; then
                run_eda || exit 1
            fi
            design_experiment
            if [[ -n "$EXPERIMENT_ID" ]]; then
                echo "Designed: $EXPERIMENT_ID"
            fi
            ;;

        train)
            if [[ -z "$EXPERIMENT_ID" ]]; then
                echo -e "${RED}❌ Experiment ID required for train phase${NC}"
                echo "Usage: lisa-experiment.sh train <experiment_id>"
                exit 1
            fi
            train_model "$EXPERIMENT_ID"
            ;;

        evaluate)
            if [[ -z "$EXPERIMENT_ID" ]]; then
                echo -e "${RED}❌ Experiment ID required for evaluate phase${NC}"
                exit 1
            fi
            evaluate_model "$EXPERIMENT_ID"
            ;;

        visualize)
            if [[ -z "$EXPERIMENT_ID" ]]; then
                echo -e "${RED}❌ Experiment ID required for visualize phase${NC}"
                exit 1
            fi
            generate_visualizations "$EXPERIMENT_ID"
            ;;

        stopping)
            evaluate_stopping
            exit $?
            ;;

        all)
            # Complete experiment cycle
            echo -e "${CYAN}Running complete experiment cycle${NC}\n"

            # 1. EDA (if needed)
            if [[ "$EDA_DONE" = false ]]; then
                run_eda || exit 1
            fi

            # 2. Design experiment
            echo -e "${CYAN}DEBUG: Before design_experiment, EXPERIMENT_ID='$EXPERIMENT_ID'${NC}"
            design_experiment
            echo -e "${CYAN}DEBUG: After design_experiment, EXPERIMENT_ID='$EXPERIMENT_ID'${NC}"

            # design_experiment sets EXPERIMENT_ID global variable
            if [[ -z "$EXPERIMENT_ID" ]]; then
                echo -e "${RED}❌ Failed to design experiment (EXPERIMENT_ID is empty)${NC}"
                exit 1
            fi

            echo -e "${GREEN}✓ Using experiment: $EXPERIMENT_ID${NC}"

            # 3. Train
            echo -e "${CYAN}DEBUG: Calling train_model with EXPERIMENT_ID='$EXPERIMENT_ID'${NC}"
            if ! train_model "$EXPERIMENT_ID"; then
                echo -e "${RED}❌ Training failed${NC}"
                exit 1
            fi

            # 4. Evaluate
            if ! evaluate_model "$EXPERIMENT_ID"; then
                echo -e "${RED}❌ Evaluation failed${NC}"
                exit 1
            fi

            # 5. Visualize
            generate_visualizations "$EXPERIMENT_ID"

            # 6. Stopping criteria
            set +e  # Temporarily disable exit-on-error to capture special exit codes
            evaluate_stopping
            STOP_CODE=$?
            set -e  # Re-enable exit-on-error

            if [[ $STOP_CODE -eq 10 ]]; then
                echo -e "\n${GREEN}🎉 Experimentation complete! Target achieved.${NC}"
                exit 10  # Propagate STOP code to lisa-afk.sh
            elif [[ $STOP_CODE -eq 11 ]]; then
                echo -e "\n${YELLOW}⚠ Strategy change recommended${NC}"
                exit 11  # Return special code for strategy change
            else
                echo -e "\n${CYAN}Continue with next experiment${NC}"
                exit 0
            fi
            ;;

        *)
            echo -e "${RED}Unknown phase: $PHASE${NC}"
            echo ""
            echo "Usage: lisa-experiment.sh <phase> [experiment_id]"
            echo ""
            echo "Phases:"
            echo "  all        - Run complete cycle (default)"
            echo "  eda        - Run EDA only"
            echo "  design     - Design next experiment"
            echo "  train      - Train model (requires experiment_id)"
            echo "  evaluate   - Evaluate model (requires experiment_id)"
            echo "  visualize  - Generate visualizations (requires experiment_id)"
            echo "  stopping   - Evaluate stopping criteria"
            echo ""
            exit 1
            ;;
    esac
}

# Execute
main
