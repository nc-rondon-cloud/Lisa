#!/bin/bash
set -e

# LISA Visualization Generation Script
# Generates comprehensive visualizations for model and data

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
VIZ_TYPE="${2:-all}"  # all, eda, training, evaluation

echo -e "${CYAN}📈 LISA Visualization Generation${NC}"
echo "==========================================="
echo "Experiment: $EXPERIMENT_ID"
echo "Type: $VIZ_TYPE"
echo ""

# Activate Python environment
if [[ -d "$LISA_DIR/.venv-lisa-ml" ]]; then
    source "$LISA_DIR/.venv-lisa-ml/bin/activate"
else
    echo -e "${RED}❌ Python environment not found${NC}"
    exit 1
fi

# Load visualization prompt
VIZ_PROMPT="$LISA_DIR/prompts/lisa-visualization-prompt.md"

if [[ ! -f "$VIZ_PROMPT" ]]; then
    echo -e "${RED}❌ Visualization prompt not found: $VIZ_PROMPT${NC}"
    exit 1
fi

# Build context
CONTEXT_PROMPT="$(cat <<EOF
You are LISA generating visualizations for ML analysis.

Experiment ID: $EXPERIMENT_ID
Visualization Type: $VIZ_TYPE

Files to read:
1. lisa_config.yaml - Paths and settings
2. $VIZ_PROMPT - Visualization instructions

Task depends on type:

If VIZ_TYPE = eda:
- Generate EDA visualizations (distributions, correlations, target distribution)
- Save to: lisa/lisas_laboratory/plots/eda/

If VIZ_TYPE = training:
- Generate training curves (loss/metric over epochs)
- Load from TrainingMonitor history
- Save to: lisa/lisas_laboratory/plots/training/

If VIZ_TYPE = evaluation or all:
- Load model and test data
- Generate performance visualizations:
  * Classification: confusion matrix, ROC curves, precision-recall
  * Regression: actual vs predicted, residuals
- Generate feature importance plot
- Save to: lisa/lisas_laboratory/plots/evaluation/

Use the Visualizer class from lisa.visualizer for consistent, high-quality plots.

All plots should:
- Have clear titles and labels
- Use appropriate color schemes
- Be saved at 150 DPI
- Include grid for readability
- Be properly closed to free memory

Document generated plots in lisas_diary/.

Output: <promise>VISUALIZATIONS_COMPLETE:{num_plots}</promise>
EOF
)"

echo -e "${CYAN}Generating visualizations...${NC}\n"

echo -e "${DIM}Running Claude for visualization generation...${NC}"
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

# Count generated plots
PLOT_DIR="$LISA_DIR/lisas_laboratory/plots"
NUM_PLOTS=$(find "$PLOT_DIR" -name "*.png" -mmin -10 | wc -l | tr -d ' ')

echo -e "\n${GREEN}✓ Generated $NUM_PLOTS visualizations${NC}"
echo "Location: $PLOT_DIR"

exit 0
