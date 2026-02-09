#!/bin/bash
# create-template-prd.sh - Create template-based PRD from BEST_MODEL.json
#
# This is a fallback for when Claude CLI is not available.
# Creates a basic PRD that Code mode can refine and implement.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$LISA_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get BEST_MODEL file path from argument or use default
BEST_MODEL_FILE="${1:-$LISA_DIR/BEST_MODEL.json}"

if [[ ! -f "$BEST_MODEL_FILE" ]]; then
    echo -e "${RED}✗ BEST_MODEL.json not found: $BEST_MODEL_FILE${NC}"
    exit 1
fi

echo "Creating template PRD from $BEST_MODEL_FILE..."

# Read model info using Python
MODEL_INFO=$(python3 <<'EOF'
import json
import sys

try:
    with open(sys.argv[1]) as f:
        model = json.load(f)

    print(f"MODEL_TYPE={model.get('model_type', 'unknown')}")
    print(f"TASK_TYPE={model.get('task_type', 'classification')}")
    print(f"RUN_ID={model.get('run_id', 'unknown')}")

    metrics = model.get('metrics', {})
    print(f"METRIC_NAME={metrics.get('primary_metric', 'metric')}")
    print(f"METRIC_VALUE={metrics.get('primary_value', 0)}")
    print(f"TRAIN_SCORE={metrics.get('train_score', 'N/A')}")
    print(f"VAL_SCORE={metrics.get('val_score', 'N/A')}")

except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
"$BEST_MODEL_FILE")

# Check if Python succeeded
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to parse BEST_MODEL.json${NC}"
    exit 1
fi

# Extract values
eval "$MODEL_INFO"

# Create PRD
cat > "$LISA_DIR/PRD.md" <<EOF
# PRD: ML Model Integration

## Overview

Integrate the trained **${MODEL_TYPE}** model into the existing codebase for ${TASK_TYPE}.

## Best Model Details

- **Model Type**: ${MODEL_TYPE}
- **Task Type**: ${TASK_TYPE}
- **Primary Metric**: ${METRIC_NAME} = ${METRIC_VALUE}
- **Training Score**: ${TRAIN_SCORE}
- **Validation Score**: ${VAL_SCORE}
- **MLflow Run ID**: ${RUN_ID}

## Model Information

The best performing model has been saved in MLflow. Full details are available in:
- \`lisa/BEST_MODEL.json\` - Complete model metadata
- \`lisa/lisas_diary/\` - ML experimentation documentation
- MLflow UI: \`http://127.0.0.1:5000/\`

## Implementation Tasks

### Task 1: Load Model from MLflow

**Objective**: Load the trained model artifact from MLflow.

**Action Items**:
- Install MLflow Python client if not already installed
- Load model using MLflow run ID: \`${RUN_ID}\`
- Verify model loads correctly and can make predictions
- Cache model in memory for performance

**Implementation**:
\`\`\`python
import mlflow.pyfunc

# Load model from MLflow
model = mlflow.pyfunc.load_model(f"runs:/${RUN_ID}/model")

# Test prediction
sample_input = {...}  # Your sample input
prediction = model.predict(sample_input)
\`\`\`

### Task 2: Create Inference Module

**Objective**: Create a reusable module for model inference.

**Action Items**:
- Create new file \`model_inference.py\` (or appropriate location in your codebase)
- Implement \`predict()\` function that:
  - Takes raw input data
  - Applies same preprocessing as training
  - Calls model.predict()
  - Returns formatted predictions
- Add input validation
- Handle errors gracefully

**Suggested Structure**:
\`\`\`python
class ModelPredictor:
    def __init__(self, model_run_id: str):
        self.model = mlflow.pyfunc.load_model(f"runs:/{model_run_id}/model")

    def predict(self, input_data: dict) -> dict:
        """
        Make prediction using trained model.

        Args:
            input_data: Dictionary with input features

        Returns:
            Dictionary with prediction and confidence
        """
        # TODO: Implement preprocessing
        # TODO: Make prediction
        # TODO: Format output
        pass
\`\`\`

### Task 3: Integrate with Existing Code

**Objective**: Integrate model predictions into your application workflow.

**Action Items**:
- Identify where predictions should be used in your codebase
- Import and initialize the ModelPredictor
- Replace existing logic or add new prediction endpoints
- Ensure input/output formats match your application's needs
- Maintain backward compatibility if replacing existing functionality

**Notes**:
- Review your codebase structure to determine best integration points
- Consider whether this replaces existing logic or adds new functionality
- Ensure feature preprocessing matches what was done during training

### Task 4: Add Model Configuration

**Objective**: Make model configurable and easy to update.

**Action Items**:
- Add model configuration to your app's config file
- Include model run ID for easy model versioning
- Document model metadata (performance, when trained, etc.)
- Make it easy to switch between model versions

**Example Configuration**:
\`\`\`yaml
model:
  mlflow_run_id: "${RUN_ID}"
  model_type: "${MODEL_TYPE}"
  task_type: "${TASK_TYPE}"
  version: "1.0.0"
  performance:
    ${METRIC_NAME}: ${METRIC_VALUE}
    train_score: ${TRAIN_SCORE}
    val_score: ${VAL_SCORE}
\`\`\`

### Task 5: Add Tests

**Objective**: Ensure model integration works correctly.

**Action Items**:
- Create test file for model inference module
- Test model loading
- Test predictions with sample data
- Test error handling (invalid input, missing features, etc.)
- Test integration in your application context

**Test Cases**:
\`\`\`python
def test_model_loads():
    # Test that model loads successfully
    pass

def test_prediction_format():
    # Test that predictions return expected format
    pass

def test_invalid_input():
    # Test error handling for bad input
    pass
\`\`\`

### Task 6: Update Documentation

**Objective**: Document how to use the integrated model.

**Action Items**:
- Document model usage in README or relevant docs
- Provide example of making predictions
- Document model performance metrics
- Explain how to update/retrain the model
- Link to MLflow run for full reproducibility

**Documentation Sections**:
- Model Overview (what it predicts, performance)
- Usage Examples (how to make predictions)
- Model Updates (how to train and deploy new versions)
- Troubleshooting (common issues and solutions)

## Success Criteria

- ✅ Model loads successfully from MLflow
- ✅ Predictions work with sample data
- ✅ Integrated into application workflow
- ✅ Tests pass
- ✅ Documentation updated
- ✅ Code follows project conventions

## Additional Context

### Model Artifact Location
- **MLflow URI**: \`runs:/${RUN_ID}/model\`
- **Local Path**: \`lisa/lisas_laboratory/models/best_model.pkl\`

### Training Context
Review ML experimentation details in:
- \`lisa/lisas_diary/\` - Decision logs and insights
- \`lisa/lisas_laboratory/plots/\` - Evaluation visualizations
- \`lisa/BEST_MODEL.json\` - Complete model metadata

### Preprocessing Notes
**IMPORTANT**: Ensure prediction preprocessing exactly matches training preprocessing:
- Feature engineering steps
- Scaling/normalization
- Encoding (categorical variables)
- Missing value handling

Review training code in \`lisa/lisas_laboratory/\` to understand preprocessing pipeline.

## Next Steps

1. Review this PRD and adjust tasks based on your specific codebase structure
2. Implement tasks in order, testing each step
3. Refer to \`lisa/BEST_MODEL.json\` for complete model details
4. Check \`lisa/lisas_diary/\` for ML experimentation insights
5. Use MLflow UI to explore model artifacts and metrics

## Notes

This is a template PRD. You may need to adjust tasks based on your specific:
- Application architecture (web app, CLI, library, etc.)
- Programming language/framework
- Deployment requirements
- Existing model integration patterns

The Code mode agent will analyze your codebase and refine these tasks with specific file paths and implementation details.
EOF

echo -e "${GREEN}✓ Template PRD created: $LISA_DIR/PRD.md${NC}"
exit 0
