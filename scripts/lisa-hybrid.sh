#!/bin/bash
# lisa-hybrid.sh - Hybrid ML→Code orchestrator
#
# This script implements the automatic ML→Code flow:
# 1. Run ML mode to find best model (with specified iterations)
# 2. Extract best model information from MLflow
# 3. Generate implementation PRD for Code mode
# 4. Run Code mode to integrate the model (with specified iterations)
#
# Usage: ./lisa-hybrid.sh --ml-iterations N --code-iterations N

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Source library
source "$SCRIPT_DIR/lisa-lib.sh"
lisa_setup_logging

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Default values
ML_ITERATIONS=20
CODE_ITERATIONS=50
SKIP_ML=false
SKIP_CODE=false

# Usage function
show_usage() {
    cat <<EOF
${BOLD}LISA Hybrid Mode: ML→Code${NC}

Automatically find the best ML model and integrate it into your code.

${BOLD}Usage:${NC}
  $(basename "$0") [OPTIONS]

${BOLD}Options:${NC}
  --ml-iterations N      Max ML experiment iterations (default: 20)
  --code-iterations N    Max Code implementation iterations (default: 50)
  --skip-ml             Skip ML phase (use existing BEST_MODEL.json)
  --skip-code           Skip Code phase (only run ML and generate PRD)
  --help, -h            Show this help

${BOLD}Examples:${NC}
  # Full hybrid flow with custom iterations
  ./scripts/lisa-hybrid.sh --ml-iterations 30 --code-iterations 100

  # Only generate PRD from existing ML results
  ./scripts/lisa-hybrid.sh --skip-ml --skip-code

  # Run ML phase only
  ./scripts/lisa-hybrid.sh --ml-iterations 25 --skip-code

${BOLD}Workflow:${NC}
  Phase 1: ML Optimization
    • Run experiments to find best model
    • Track metrics in MLflow
    • Stop when target metric achieved or max iterations reached

  Phase 2: Model Extraction
    • Query MLflow for best performing run
    • Extract model metadata and hyperparameters
    • Create BEST_MODEL.json for Code mode

  Phase 3: PRD Generation
    • Analyze existing codebase structure
    • Generate specific implementation tasks
    • Create PRD.md for Code mode

  Phase 4: Code Integration
    • Load PRD and implement tasks
    • Integrate model into existing code
    • Add tests and documentation
    • Complete when all tasks done or max iterations reached

${BOLD}Requirements:${NC}
  • lisa_config.yaml must exist for ML mode
  • Claude CLI must be available for PRD generation
  • Existing codebase to integrate model into

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ml-iterations)
            ML_ITERATIONS="$2"
            shift 2
            ;;
        --code-iterations)
            CODE_ITERATIONS="$2"
            shift 2
            ;;
        --skip-ml)
            SKIP_ML=true
            shift
            ;;
        --skip-code)
            SKIP_CODE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# Header
clear
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║    LISA Hybrid Mode: ML→Code Integration   ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Automatic flow from ML experimentation to code integration${NC}"
echo ""
lisa_separator "="

# Configuration summary
echo ""
echo -e "${BOLD}Configuration:${NC}"
echo "  Phase 1 - ML Optimization: $ML_ITERATIONS max iterations"
echo "  Phase 2 - Code Integration: $CODE_ITERATIONS max iterations"
if [[ "$SKIP_ML" == "true" ]]; then
    echo -e "  ${YELLOW}⚠ Skipping ML phase (using existing results)${NC}"
fi
if [[ "$SKIP_CODE" == "true" ]]; then
    echo -e "  ${YELLOW}⚠ Skipping Code phase (stopping after PRD generation)${NC}"
fi
echo ""
lisa_separator "="

# ============================================================================
# PHASE 1: ML MODE - FIND BEST MODEL
# ============================================================================

if [[ "$SKIP_ML" == "false" ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}Phase 1: ML Optimization${NC}"
    lisa_separator "-"
    echo ""

    # Check for ML config
    ML_CONFIG="$PROJECT_ROOT/lisa_config.yaml"
    if [[ ! -f "$ML_CONFIG" ]]; then
        echo -e "${RED}✗ ML configuration not found${NC}"
        echo ""
        echo "Expected: $ML_CONFIG"
        echo ""
        echo "ML mode requires a configuration file to define:"
        echo "  • Data paths"
        echo "  • Target column"
        echo "  • Models to try"
        echo "  • Stopping criteria"
        echo ""
        echo "Please create lisa_config.yaml before running hybrid mode."
        exit 1
    fi

    lisa_info "Starting ML Mode to find best model..."
    echo "  Configuration: $ML_CONFIG"
    echo "  Max iterations: $ML_ITERATIONS"
    echo ""

    # Set environment for hybrid mode
    export LISA_HYBRID_MODE="true"
    export LISA_ML_MAX_ITERATIONS="$ML_ITERATIONS"

    # Run ML mode
    cd "$PROJECT_ROOT"
    echo -e "${CYAN}Running ML experiments...${NC}"
    echo ""

    "$SCRIPT_DIR/lisa-afk.sh" "$ML_ITERATIONS"
    ML_EXIT_CODE=$?

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}ML Mode Exit Code: $ML_EXIT_CODE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Check ML results
    if [[ $ML_EXIT_CODE -eq 10 ]]; then
        echo -e "${GREEN}${BOLD}✓ ML Phase Complete - Target metric achieved!${NC}"
        echo -e "${DIM}Proceeding to model extraction and code integration...${NC}"
        echo ""
    elif [[ $ML_EXIT_CODE -eq 0 ]]; then
        echo -e "${YELLOW}⚠ ML Phase Complete - Max iterations reached${NC}"
        echo -e "${DIM}Proceeding with best model found so far...${NC}"
        echo ""
    else
        echo -e "${RED}✗ ML Phase Error (exit code: $ML_EXIT_CODE)${NC}"
        echo ""

        # Provide specific guidance based on exit code
        if [[ $ML_EXIT_CODE -eq 1 ]]; then
            echo "Common causes for exit code 1:"
            echo "  • Missing PRD file ($LISA_DIR/PRD.md)"
            echo "  • Missing prompt files"
            echo "  • Experiment execution failure"
            echo "  • Data loading error"
        elif [[ $ML_EXIT_CODE -eq 11 ]]; then
            echo "Exit code 11: Strategy change recommended"
            echo "This is not fatal - continuing..."
            ML_EXIT_CODE=0  # Treat as success
        else
            echo "Unexpected exit code: $ML_EXIT_CODE"
        fi

        echo ""
        echo "Check for details:"
        echo "  • Diary: $LISA_DIR/lisas_diary/"
        echo "  • Config: $ML_CONFIG"
        echo ""

        # For exit code 1, abort immediately (critical failure)
        if [[ $ML_EXIT_CODE -eq 1 ]]; then
            echo -e "${RED}Critical error - cannot continue${NC}"
            exit $ML_EXIT_CODE
        fi

        echo -e "${YELLOW}Attempting to continue with existing results...${NC}"
        echo ""
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping ML Phase - using existing results${NC}"
    echo ""
fi

lisa_separator "="

# ============================================================================
# PHASE 1.5: EXTRACT BEST MODEL INFO
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}Phase 2: Model Information Extraction${NC}"
lisa_separator "-"
echo ""

lisa_info "Extracting best model information from MLflow..."
echo ""

"$SCRIPT_DIR/write-best-model-info.sh"
EXTRACT_EXIT=$?

if [[ $EXTRACT_EXIT -ne 0 ]]; then
    echo ""
    echo -e "${RED}✗ Failed to extract best model information${NC}"
    echo ""
    echo "Possible issues:"
    echo "  • No experiments in MLflow"
    echo "  • MLflow database corrupted"
    echo "  • Virtual environment issues"
    echo ""
    echo "Try running ML mode manually to diagnose:"
    echo "  ./scripts/lisa-afk.sh 5"
    echo ""
    exit 1
fi

# Show best model summary
if [[ -f "$LISA_DIR/BEST_MODEL.json" ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}Best Model Summary:${NC}"
    echo ""

    # Pretty print key info using Python
    export BEST_MODEL_PATH="$LISA_DIR/BEST_MODEL.json"
    python3 <<'EOF'
import json
import sys
import os

try:
    best_model_path = os.environ.get('BEST_MODEL_PATH', 'lisa/BEST_MODEL.json')
    with open(best_model_path) as f:
        model = json.load(f)

    print(f"  Model Type: {model.get('model_type', 'unknown')}")
    print(f"  Task: {model.get('task_type', 'unknown')}")

    metrics = model.get('metrics', {})
    metric_name = metrics.get('primary_metric', 'unknown')
    metric_value = metrics.get('primary_value', 0)
    print(f"  {metric_name}: {metric_value:.4f}")

    if metrics.get('train_score'):
        print(f"  Train Score: {metrics['train_score']:.4f}")
    if metrics.get('val_score'):
        print(f"  Val Score: {metrics['val_score']:.4f}")

    print(f"\n  MLflow Run: {model.get('run_id', 'unknown')[:8]}...")

    hyperparams = model.get('hyperparameters', {})
    print(f"  Hyperparameters: {len(hyperparams)} configured")

except Exception as e:
    print(f"Error reading model info: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    echo ""
fi

lisa_separator "="

# ============================================================================
# PHASE 1.6: GENERATE IMPLEMENTATION PRD
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}Phase 3: Implementation PRD Generation${NC}"
lisa_separator "-"
echo ""

lisa_info "Analyzing codebase and generating implementation plan..."
echo ""

"$SCRIPT_DIR/generate-implementation-prd.sh"
PRD_EXIT=$?

if [[ $PRD_EXIT -ne 0 ]]; then
    echo ""
    echo -e "${RED}✗ Failed to generate implementation PRD${NC}"
    echo ""
    echo "Possible issues:"
    echo "  • Claude CLI not available"
    echo "  • BEST_MODEL.json missing or invalid"
    echo "  • Codebase analysis failed"
    echo ""
    echo "Check the error messages above for details."
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}✓ Implementation PRD Generated${NC}"
echo ""
echo "PRD location: $LISA_DIR/PRD.md"
echo ""

# If skipping code phase, stop here
if [[ "$SKIP_CODE" == "true" ]]; then
    lisa_separator "="
    echo ""
    echo -e "${GREEN}${BOLD}✓ Hybrid Mode Complete (PRD Generated)${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review PRD: $LISA_DIR/PRD.md"
    echo "  2. Run Code mode manually if needed:"
    echo "     ./scripts/lisa-afk.sh $CODE_ITERATIONS"
    echo ""
    exit 0
fi

# Reset progress file for Code mode
echo "# Progress Log - ML Model Integration" > "$LISA_DIR/progress.txt"
echo "" >> "$LISA_DIR/progress.txt"
echo "Started: $(date)" >> "$LISA_DIR/progress.txt"
echo "" >> "$LISA_DIR/progress.txt"

lisa_separator "="

# ============================================================================
# PHASE 2: CODE MODE - INTEGRATE MODEL
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}Phase 4: Code Integration${NC}"
lisa_separator "-"
echo ""

lisa_info "Starting Code Mode to integrate model into codebase..."
echo "  Max iterations: $CODE_ITERATIONS"
echo "  PRD: $LISA_DIR/PRD.md"
echo ""

# Temporarily hide ML config to trigger Code mode
# (lisa-afk.sh detects mode based on config presence)
if [[ -f "$ML_CONFIG" ]]; then
    mv "$ML_CONFIG" "$ML_CONFIG.hybrid-backup"
    RESTORE_CONFIG=true
else
    RESTORE_CONFIG=false
fi

# Set environment for Code mode
export LISA_HYBRID_MODE="true"
export LISA_CODE_MAX_ITERATIONS="$CODE_ITERATIONS"
export LISA_FROM_HYBRID="true"

echo -e "${CYAN}Running Code mode integration...${NC}"
echo ""

"$SCRIPT_DIR/lisa-afk.sh" "$CODE_ITERATIONS"
CODE_EXIT=$?

# Restore ML config
if [[ "$RESTORE_CONFIG" == "true" ]]; then
    mv "$ML_CONFIG.hybrid-backup" "$ML_CONFIG"
fi

echo ""
lisa_info "Code Mode completed with exit code: $CODE_EXIT"

lisa_separator "="

# ============================================================================
# PHASE 3: SUMMARY
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          Hybrid Mode Complete               ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Load model info for summary
if [[ -f "$LISA_DIR/BEST_MODEL.json" ]]; then
    MODEL_INFO=$(python3 -c "import json; m=json.load(open('$LISA_DIR/BEST_MODEL.json')); print(f\"{m.get('model_type','unknown')} | {m.get('metrics',{}).get('primary_metric','metric')}={m.get('metrics',{}).get('primary_value',0):.4f}\")")
else
    MODEL_INFO="unknown"
fi

if [[ $CODE_EXIT -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ Success: Model Integration Complete${NC}"
    echo ""
    echo "Summary:"
    echo "  ✓ ML Phase: Best model found ($MODEL_INFO)"
    echo "  ✓ Code Phase: Integration implemented"
    echo ""
    echo "What was done:"
    echo "  • Model loaded from MLflow"
    echo "  • Integration code written"
    echo "  • Tests added (if applicable)"
    echo "  • Documentation updated"
    echo ""
    echo "Next steps:"
    echo "  1. Review integrated code"
    echo "  2. Run tests to verify functionality"
    echo "  3. Test with real data"
    echo "  4. Deploy if ready"
elif [[ $CODE_EXIT -eq 1 ]]; then
    echo -e "${YELLOW}⚠ Partial Success: Integration Incomplete${NC}"
    echo ""
    echo "Summary:"
    echo "  ✓ ML Phase: Best model found ($MODEL_INFO)"
    echo "  ⚠ Code Phase: Some tasks incomplete"
    echo ""
    echo "What was done:"
    echo "  • PRD generated with implementation tasks"
    echo "  • Some integration code written"
    echo ""
    echo "Next steps:"
    echo "  1. Review PRD.md for remaining tasks"
    echo "  2. Check progress.txt for what was completed"
    echo "  3. Run Code mode again to continue:"
    echo "     ./scripts/lisa-once.sh"
    echo "  4. Or review and implement remaining tasks manually"
else
    echo -e "${RED}✗ Code Integration Failed${NC}"
    echo ""
    echo "Summary:"
    echo "  ✓ ML Phase: Best model found ($MODEL_INFO)"
    echo "  ✗ Code Phase: Integration failed (exit: $CODE_EXIT)"
    echo ""
    echo "Next steps:"
    echo "  1. Check logs: $LISA_DIR/logs/"
    echo "  2. Review PRD: $LISA_DIR/PRD.md"
    echo "  3. Debug and retry Code mode"
fi

echo ""
echo "Files generated:"
echo "  • Model info: $LISA_DIR/BEST_MODEL.json"
echo "  • Implementation PRD: $LISA_DIR/PRD.md"
echo "  • Progress log: $LISA_DIR/progress.txt"
echo "  • ML diary: $LISA_DIR/lisas_diary/"
if [[ -f "$LISA_DIR/lisas_laboratory/plots/evaluation/confusion_matrix.png" ]]; then
    echo "  • Evaluation plots: $LISA_DIR/lisas_laboratory/plots/evaluation/"
fi

echo ""
lisa_separator "="
echo ""

exit $CODE_EXIT
