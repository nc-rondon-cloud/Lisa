#!/bin/bash
# generate-implementation-prd.sh - Auto-generate Code PRD from ML results
#
# This script calls Claude with the PRD generation prompt to analyze the
# codebase and create specific implementation tasks for integrating the
# best ML model found during experimentation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Source library
source "$SCRIPT_DIR/lisa-lib.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}📝 Generating Implementation PRD${NC}"
echo "=========================================="
echo ""

# Check if BEST_MODEL.json exists
BEST_MODEL_FILE="$LISA_DIR/BEST_MODEL.json"
if [[ ! -f "$BEST_MODEL_FILE" ]]; then
    echo -e "${RED}✗ BEST_MODEL.json not found${NC}"
    echo ""
    echo "Expected: $BEST_MODEL_FILE"
    echo ""
    echo "Run ML mode first to find the best model, then run:"
    echo "  ./scripts/write-best-model-info.sh"
    echo ""
    exit 1
fi

# Check if prompt template exists
PROMPT_TEMPLATE="$LISA_DIR/prompts/prd-code-generation-prompt.md"
if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
    echo -e "${RED}✗ PRD generation prompt template not found${NC}"
    echo "Expected: $PROMPT_TEMPLATE"
    exit 1
fi

# Read BEST_MODEL.json content
echo "Loading best model information..."
BEST_MODEL_CONTENT=$(cat "$BEST_MODEL_FILE")

# Extract key values for display
MODEL_TYPE=$(echo "$BEST_MODEL_CONTENT" | grep -o '"model_type"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
RUN_ID=$(echo "$BEST_MODEL_CONTENT" | grep -o '"run_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

echo "  Model Type: $MODEL_TYPE"
echo "  Run ID: ${RUN_ID:0:8}..."
echo ""

# Load and prepare prompt template
echo "Preparing prompt for Claude..."
PROMPT_CONTENT=$(cat "$PROMPT_TEMPLATE")

# Replace template variables
PROMPT_CONTENT="${PROMPT_CONTENT//\{\{BEST_MODEL_CONTENT\}\}/$BEST_MODEL_CONTENT}"
PROMPT_CONTENT="${PROMPT_CONTENT//\{\{PROJECT_ROOT\}\}/$PROJECT_ROOT}"
PROMPT_CONTENT="${PROMPT_CONTENT//\{\{LISA_DIR\}\}/$LISA_DIR}"

# Create temporary prompt file
TEMP_PROMPT="/tmp/lisa-prd-prompt-$$.md"
echo "$PROMPT_CONTENT" > "$TEMP_PROMPT"

echo "Calling Claude to analyze codebase and generate PRD..."
echo "This may take 1-2 minutes as Claude analyzes the project structure..."
echo ""

# Change to project root so Claude has proper context
cd "$PROJECT_ROOT"

# Call Claude with the prompt
# Note: This assumes Claude CLI is available and configured
if ! command -v claude &> /dev/null; then
    echo -e "${RED}✗ Claude CLI not found${NC}"
    echo ""
    echo "The 'claude' command is not available. Please ensure Claude CLI is installed."
    echo ""
    rm -f "$TEMP_PROMPT"
    exit 1
fi

# Create output file for Claude's response
CLAUDE_OUTPUT="/tmp/lisa-prd-output-$$.txt"

# Call Claude (redirect stderr to capture any errors)
claude --model "claude-sonnet-4-5-20250929" --max-tokens 16000 < "$TEMP_PROMPT" > "$CLAUDE_OUTPUT" 2>&1
CLAUDE_EXIT=$?

# Clean up temp prompt
rm -f "$TEMP_PROMPT"

if [[ $CLAUDE_EXIT -ne 0 ]]; then
    echo -e "${RED}✗ Claude command failed${NC}"
    echo ""
    echo "Output:"
    cat "$CLAUDE_OUTPUT"
    rm -f "$CLAUDE_OUTPUT"
    exit 1
fi

# Extract PRD from Claude's output
# Look for content between # PRD_START and # PRD_END markers
if grep -q "PRD_GENERATED" "$CLAUDE_OUTPUT"; then
    echo -e "${GREEN}✓ Claude generated PRD successfully${NC}"
    echo ""

    # Extract the PRD content
    sed -n '/# PRD_START/,/# PRD_END/p' "$CLAUDE_OUTPUT" | \
        sed '1d;$d' > "$LISA_DIR/PRD.md"

    # Check if PRD was extracted
    if [[ -f "$LISA_DIR/PRD.md" ]] && [[ -s "$LISA_DIR/PRD.md" ]]; then
        echo -e "${GREEN}✓ Implementation PRD generated${NC}"
        echo ""
        echo "Location: $LISA_DIR/PRD.md"
        echo ""

        # Count tasks in PRD
        TASK_COUNT=$(grep -c "^### Task [0-9]" "$LISA_DIR/PRD.md" || echo "0")
        echo "Summary:"
        echo "  • Implementation tasks: $TASK_COUNT"
        echo "  • Based on model: $MODEL_TYPE"
        echo "  • MLflow run: ${RUN_ID:0:8}..."
        echo ""

        # Show preview of first task
        echo "Preview (first 25 lines):"
        echo "---"
        head -25 "$LISA_DIR/PRD.md"
        echo "---"
        echo "(see $LISA_DIR/PRD.md for complete PRD)"
        echo ""

        # Save Claude's full analysis for reference
        ANALYSIS_FILE="$LISA_DIR/lisas_diary/codebase-analysis-$(date +%Y%m%d-%H%M%S).txt"
        mkdir -p "$LISA_DIR/lisas_diary"
        cp "$CLAUDE_OUTPUT" "$ANALYSIS_FILE"
        echo "Full analysis saved: $ANALYSIS_FILE"
        echo ""

        # Clean up
        rm -f "$CLAUDE_OUTPUT"

        echo -e "${GREEN}✓ Ready for Code mode integration${NC}"
        echo ""
        echo "Next step: Run Code mode to implement the tasks"
        echo "  ./scripts/lisa-afk.sh [iterations]"
        echo ""

        exit 0
    else
        echo -e "${RED}✗ Failed to extract PRD from Claude's output${NC}"
        echo ""
        echo "Claude's response did not contain expected PRD markers."
        echo "Full output saved to: $CLAUDE_OUTPUT"
        echo ""
        exit 1
    fi
else
    echo -e "${RED}✗ Claude did not generate PRD${NC}"
    echo ""
    echo "Claude's response did not contain the <promise>PRD_GENERATED</promise> marker."
    echo ""
    echo "Output preview:"
    head -50 "$CLAUDE_OUTPUT"
    echo ""
    echo "Full output saved to: $CLAUDE_OUTPUT"
    echo ""
    exit 1
fi
