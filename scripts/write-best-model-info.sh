#!/bin/bash
# write-best-model-info.sh - Extract best model from MLflow and create info file
#
# This script queries MLflow for the best run based on the primary metric
# and creates a structured JSON file with all necessary model information
# for Code mode integration.

set -e

# Get script directory, lisa folder, and project root
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
echo -e "${CYAN}📊 Extracting Best Model Information${NC}"
echo "=========================================="
echo ""

# Check if virtual environment exists
VENV_PATH="$LISA_DIR/.venv-lisa-ml"
if [[ ! -d "$VENV_PATH" ]]; then
    echo -e "${RED}✗ ML virtual environment not found${NC}"
    echo "Expected: $VENV_PATH"
    exit 1
fi

# Activate Python environment
echo "Activating ML environment..."
source "$VENV_PATH/bin/activate"

# Check if MLflow tracking URI is accessible
if [[ ! -d "$LISA_DIR/mlruns" ]]; then
    echo -e "${RED}✗ MLflow tracking directory not found${NC}"
    echo "Expected: $LISA_DIR/mlruns"
    echo "Run ML mode first to create experiments."
    exit 1
fi

# Change to project root to ensure config access
cd "$PROJECT_ROOT"

# Query MLflow for best run using Python
echo "Querying MLflow for best model..."
python3 <<'EOF'
import sys
import json
from pathlib import Path

try:
    # Import Lisa modules
    sys.path.insert(0, str(Path(__file__).parent.parent / 'lisa'))
    from lisa.mlflow_manager import MLflowManager
    from lisa.config import Config

    # Load configuration
    config = Config()

    # Initialize MLflow manager
    mlflow_mgr = MLflowManager(config)

    # Get primary metric from stopping criteria
    metric_config = config.get('stopping_criteria.performance', {})
    metric_name = metric_config.get('metric', 'f1_score')
    target_value = metric_config.get('target', 0.9)

    # Determine if higher is better based on metric name
    # Most metrics: higher is better (accuracy, f1, precision, recall, roc_auc)
    # Loss metrics: lower is better (log_loss, mse, mae, rmse)
    lower_is_better_metrics = ['log_loss', 'logloss', 'mse', 'mae', 'rmse', 'loss', 'error']
    mode = 'min' if metric_name.lower() in lower_is_better_metrics else 'max'

    print(f"  Primary metric: {metric_name}")
    print(f"  Optimization: {'minimize' if mode == 'min' else 'maximize'}")
    print(f"  Target value: {target_value}")
    print("")

    # Get best run
    best_run = mlflow_mgr.get_best_run(metric_name, mode=mode)

    if not best_run:
        print("✗ No runs found in MLflow")
        print("  Make sure ML mode has completed at least one experiment.")
        sys.exit(1)

    # Extract run information
    run_id = best_run.info.run_id
    experiment_id = best_run.info.experiment_id

    # Get parameters
    params = best_run.data.params
    model_type = params.get('model_type', 'unknown')
    task_type = params.get('task_type', 'classification')

    # Get all metrics
    metrics = best_run.data.metrics
    primary_metric_value = metrics.get(metric_name, metrics.get(f'val_{metric_name}', 0.0))

    # Extract train and val scores
    train_score = None
    val_score = None

    # Try different metric name patterns
    for key in metrics.keys():
        if 'train' in key.lower() and metric_name in key.lower():
            train_score = metrics[key]
        if 'val' in key.lower() and metric_name in key.lower():
            val_score = metrics[key]

    # Fallback to primary metric if val_score not found
    if val_score is None:
        val_score = primary_metric_value

    # Get hyperparameters (exclude metadata)
    excluded_params = ['model_type', 'task_type', 'train_score', 'val_score', 'random_seed']
    hyperparameters = {
        k: v for k, v in params.items()
        if k not in excluded_params
    }

    # Build model info structure
    model_info = {
        'status': 'ready_for_integration',
        'run_id': run_id,
        'experiment_id': experiment_id,
        'model_type': model_type,
        'task_type': task_type,
        'metrics': {
            'primary_metric': metric_name,
            'primary_value': float(primary_metric_value),
            'target_value': float(target_value),
            'train_score': float(train_score) if train_score else None,
            'val_score': float(val_score) if val_score else None,
            'all_metrics': {k: float(v) for k, v in metrics.items()}
        },
        'hyperparameters': hyperparameters,
        'paths': {
            'model_artifact': f'runs:/{run_id}/model',
            'model_file': 'lisa/lisas_laboratory/models/best_model.pkl',
            'plots': 'lisa/lisas_laboratory/plots/evaluation/',
            'mlflow_ui': f'http://127.0.0.1:5000/#/experiments/{experiment_id}/runs/{run_id}'
        },
        'timestamp': int(best_run.info.end_time / 1000) if best_run.info.end_time else None,
        'next_action': 'INTEGRATE_INTO_CODE'
    }

    # Write to file
    output_path = Path('lisa/BEST_MODEL.json')
    with open(output_path, 'w') as f:
        json.dump(model_info, f, indent=2)

    # Print summary
    print(f"✓ Best model info written to {output_path}")
    print("")
    print("Summary:")
    print(f"  Run ID: {run_id[:8]}...")
    print(f"  Model: {model_type}")
    print(f"  Task: {task_type}")
    print(f"  {metric_name}: {primary_metric_value:.4f}")
    if train_score:
        print(f"  Train score: {train_score:.4f}")
    if val_score:
        print(f"  Val score: {val_score:.4f}")
    print("")
    print(f"Hyperparameters ({len(hyperparameters)} total):")
    for k, v in list(hyperparameters.items())[:5]:
        print(f"  {k}: {v}")
    if len(hyperparameters) > 5:
        print(f"  ... and {len(hyperparameters) - 5} more")

    sys.exit(0)

except Exception as e:
    print(f"✗ Error extracting best model info: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

PYTHON_EXIT_CODE=$?

# Deactivate virtual environment
deactivate

echo ""

if [[ $PYTHON_EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✓ Best model information extracted successfully${NC}"
    echo ""

    # Show file location
    echo "Model info file: $LISA_DIR/BEST_MODEL.json"
    echo "Next step: Generate implementation PRD"
    echo ""

    exit 0
else
    echo -e "${RED}✗ Failed to extract best model information${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Ensure ML mode has completed at least one experiment"
    echo "  2. Check that MLflow tracking is working: ls $LISA_DIR/mlruns"
    echo "  3. Review ML logs for errors"
    echo ""

    exit 1
fi
