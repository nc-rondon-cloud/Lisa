#!/bin/bash
set -e

# LISA Model Training Script
# Executes model training with monitoring

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
EXPERIMENT_ID="${1:-}"

if [[ -z "$EXPERIMENT_ID" ]]; then
    echo -e "${RED}❌ Experiment ID required${NC}"
    echo "Usage: lisa-train.sh <experiment_id>"
    exit 1
fi

echo -e "${CYAN}🚂 LISA Model Training${NC}"
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

# Check experiment config exists
EXP_CONFIG="$LISA_DIR/lisas_laboratory/experiments/${EXPERIMENT_ID}_config.json"

if [[ ! -f "$EXP_CONFIG" ]]; then
    echo -e "${RED}❌ Experiment config not found: $EXP_CONFIG${NC}"
    echo "Run experiment design first"
    exit 1
fi

echo -e "${GREEN}✓ Experiment config found${NC}"
echo ""

# Load training prompt
TRAINING_PROMPT="$LISA_DIR/prompts/lisa-training-prompt.md"

if [[ ! -f "$TRAINING_PROMPT" ]]; then
    echo -e "${RED}❌ Training prompt not found: $TRAINING_PROMPT${NC}"
    exit 1
fi

# Build context for Claude
CONTEXT_PROMPT="$(cat <<EOF
You are LISA executing model training.

Experiment ID: $EXPERIMENT_ID

Files to read:
1. lisa/lisas_laboratory/experiments/${EXPERIMENT_ID}_config.json - Experiment configuration
2. lisa/PRD.md - Data location and target variable
3. lisa_config.yaml - General configuration
4. $TRAINING_PROMPT - Training instructions

Your task:
1. Load experiment configuration
2. Load and preprocess data according to config
3. Create train/val/test splits
4. Start MLflow run
5. Train model with specified hyperparameters
6. Monitor training (detect NaN, overfitting, convergence)
7. Evaluate on test set
8. Extract feature importance (if available)
9. Save model checkpoint
10. Log everything to MLflow
11. Generate training curves plot
12. Document in lisas_diary/

Handle errors gracefully:
- If NaN/Inf detected, document and suggest fixes
- If out of memory, document and suggest reducing complexity
- If training too slow, document timing issues

Output: <promise>TRAINING_COMPLETE:${EXPERIMENT_ID}:{metric}:{score}</promise>

Example: <promise>TRAINING_COMPLETE:exp_001:f1_score:0.8542</promise>
EOF
)"

# Execute training with Claude
echo -e "${CYAN}Starting training...${NC}\n"

echo "$CONTEXT_PROMPT" | claude

# Check for completion
TRAINING_ENTRY=$(ls -t "$LISA_DIR/lisas_diary"/training_*${EXPERIMENT_ID}*.md 2>/dev/null | head -1)

if [[ -f "$TRAINING_ENTRY" ]]; then
    echo -e "\n${GREEN}✓ Training completed${NC}"

    # Try to extract metrics from diary
    if grep -q "success: true" "$TRAINING_ENTRY" 2>/dev/null; then
        echo -e "${GREEN}✓ Training successful${NC}"

        # Extract score if possible
        SCORE=$(grep -oP 'f1_score.*:\s*\K[0-9.]+' "$TRAINING_ENTRY" 2>/dev/null | head -1)
        if [[ -n "$SCORE" ]]; then
            echo "Score: $SCORE"
        fi

        exit 0
    else
        echo -e "${YELLOW}⚠ Training completed but check for issues${NC}"
        exit 0
    fi
else
    echo -e "\n${YELLOW}⚠ Training entry not found in diary${NC}"
    exit 1
fi
