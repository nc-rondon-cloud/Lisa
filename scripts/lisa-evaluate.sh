#!/bin/bash
set -e

# LISA Model Evaluation Script
# Evaluates trained model and compares with previous experiments

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
EXPERIMENT_ID="${1:-latest}"

echo -e "${CYAN}📊 LISA Model Evaluation${NC}"
echo "==========================================="
echo "Experiment: $EXPERIMENT_ID"
echo ""

# Activate Python environment
if [[ -d "$LISA_DIR/.venv-lisa-ml" ]]; then
    source "$LISA_DIR/.venv-lisa-ml/bin/activate"
else
    echo -e "${RED}❌ Python environment not found${NC}"
    exit 1
fi

# Load evaluation prompt
EVAL_PROMPT="$LISA_DIR/prompts/lisa-evaluation-prompt.md"

if [[ ! -f "$EVAL_PROMPT" ]]; then
    echo -e "${RED}❌ Evaluation prompt not found: $EVAL_PROMPT${NC}"
    exit 1
fi

# Build context
CONTEXT_PROMPT="$(cat <<EOF
You are LISA performing comprehensive model evaluation.

Experiment ID: $EXPERIMENT_ID

Files to read:
1. lisa_config.yaml - Configuration (target metrics, paths)
2. lisa/PRD.md - Project objectives
3. $EVAL_PROMPT - Evaluation instructions

Your task:
1. Get the MLflow run ID for experiment $EXPERIMENT_ID
2. Load the trained model from MLflow
3. Load test dataset
4. Generate predictions
5. Calculate comprehensive metrics (accuracy, f1, precision, recall, ROC-AUC)
6. Generate detailed classification report
7. Compare with previous best model
8. Perform error analysis (which examples misclassified?)
9. Generate evaluation plots (confusion matrix, etc.)
10. Make recommendation: DEPLOY | CONTINUE | TRY_DIFFERENT_APPROACH
11. Document in lisas_diary/

Recommendation logic:
- If score >= target: DEPLOY
- If score > previous best and close to target (<5% gap): CONTINUE with fine-tuning
- If score > previous best: CONTINUE
- If no improvement: TRY_DIFFERENT_APPROACH

Output: <promise>EVALUATION_COMPLETE:${EXPERIMENT_ID}:{recommendation}:{score}</promise>
EOF
)"

echo -e "${CYAN}Evaluating model...${NC}\n"

echo -e "${DIM}Running Claude for model evaluation...${NC}"
set +e
result=$(claude --model "$LISA_MODEL" --dangerously-skip-permissions "$CONTEXT_PROMPT" 2>&1)
exit_code=$?
set -e

# Log results
result_length=${#result}
echo ""
echo -e "  Exit code: ${exit_code}, Output length: ${result_length} chars"

if [[ $exit_code -ne 0 ]]; then
    echo -e "${RED}❌ Claude exited with error code $exit_code${NC}"
    echo -e "${DIM}First 500 chars of output:${NC}"
    echo "${result:0:500}"
    exit 1
fi

# Check for completion in output first, then in diary files
echo -e "\n${GREEN}✓ Evaluation completed${NC}"

# Check output for recommendation
if [[ "$result" == *"EVALUATION_COMPLETE:${EXPERIMENT_ID}:DEPLOY"* ]] || [[ "$result" == *"<promise>EVALUATION_COMPLETE:${EXPERIMENT_ID}:DEPLOY"* ]]; then
    echo -e "${GREEN}🎉 Recommendation: DEPLOY - Target achieved!${NC}"
    exit 0
elif [[ "$result" == *"EVALUATION_COMPLETE:${EXPERIMENT_ID}:CONTINUE"* ]] || [[ "$result" == *"<promise>EVALUATION_COMPLETE:${EXPERIMENT_ID}:CONTINUE"* ]]; then
    echo -e "${CYAN}→ Recommendation: CONTINUE experimenting${NC}"
    exit 0
elif [[ "$result" == *"EVALUATION_COMPLETE:${EXPERIMENT_ID}:TRY_DIFFERENT_APPROACH"* ]] || [[ "$result" == *"<promise>EVALUATION_COMPLETE:${EXPERIMENT_ID}:TRY_DIFFERENT_APPROACH"* ]]; then
    echo -e "${YELLOW}⚠ Recommendation: Try different approach${NC}"
    exit 0
fi

# Fallback: check diary files
EVAL_ENTRY=$(ls -t "$LISA_DIR/lisas_diary"/evaluation_*.md 2>/dev/null | head -1)

if [[ -f "$EVAL_ENTRY" ]]; then
    # Extract recommendation from file
    if grep -q "DEPLOY" "$EVAL_ENTRY" 2>/dev/null; then
        echo -e "${GREEN}🎉 Recommendation: DEPLOY - Target achieved! (from diary)${NC}"
        exit 0
    elif grep -q "CONTINUE" "$EVAL_ENTRY" 2>/dev/null; then
        echo -e "${CYAN}→ Recommendation: CONTINUE experimenting (from diary)${NC}"
        exit 0
    elif grep -q "TRY_DIFFERENT_APPROACH" "$EVAL_ENTRY" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Recommendation: Try different approach (from diary)${NC}"
        exit 0
    fi
fi

# Default to CONTINUE if no clear recommendation
echo -e "${CYAN}→ Recommendation: CONTINUE experimenting (default)${NC}"
exit 0
