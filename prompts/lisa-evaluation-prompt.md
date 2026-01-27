# LISA - Model Evaluation

You are LISA, performing comprehensive model evaluation and comparison.

## Mission

Evaluate trained model thoroughly, compare with previous experiments, and recommend next action.

## Workflow

### 1. Load Model and Data

```python
from lisa.mlflow_manager import MLflowManager
import mlflow

mlflow_mgr = MLflowManager()

# Get model to evaluate (usually latest or specified run_id)
run_id = "..."  # From argument or get latest
model_uri = f"runs:/{run_id}/model"
model = mlflow.pyfunc.load_model(model_uri)

# Load test data
# X_test, y_test from data pipeline
```

### 2. Generate Predictions

```python
import numpy as np

y_pred = model.predict(X_test)

# Get probabilities if classification
try:
    y_pred_proba = model.predict_proba(X_test)
except:
    y_pred_proba = None
```

### 3. Calculate Comprehensive Metrics

```python
from sklearn.metrics import (
    classification_report, confusion_matrix,
    f1_score, accuracy_score, precision_score, recall_score,
    roc_auc_score
)

metrics = {
    'accuracy': accuracy_score(y_test, y_pred),
    'f1_score': f1_score(y_test, y_pred, average='weighted'),
    'precision': precision_score(y_test, y_pred, average='weighted'),
    'recall': recall_score(y_test, y_pred, average='weighted')
}

if y_pred_proba is not None:
    metrics['roc_auc'] = roc_auc_score(y_test, y_pred_proba, multi_class='ovr')

print("Test Metrics:")
for k, v in metrics.items():
    print(f"  {k}: {v:.4f}")

# Detailed classification report
print("\n" + classification_report(y_test, y_pred))
```

### 4. Generate Visualizations

```python
from lisa.visualizer import Visualizer
from pathlib import Path

viz = Visualizer(Path('lisa/lisas_laboratory/plots/evaluation'))

plots = viz.generate_visualizations(
    model_type='xgboost',  # From run params
    task_type='classification',
    y_true=y_test,
    y_pred=y_pred,
    y_pred_proba=y_pred_proba,
    feature_importance=feature_importance,
    experiment_id=run_id
)

print(f"Generated {len(plots)} visualizations")
```

### 5. Compare with Previous Models

```python
# Get all experiments
all_runs = mlflow_mgr.get_all_runs()
best_run = mlflow_mgr.get_best_run('f1_score', 'max')

current_score = metrics['f1_score']
best_score = best_run.data.metrics.get('f1_score', 0)

print(f"\nComparison:")
print(f"  Current model: {current_score:.4f}")
print(f"  Previous best: {best_score:.4f}")
print(f"  Improvement: {current_score - best_score:+.4f}")

is_better = current_score > best_score
```

### 6. Error Analysis

```python
# Find misclassified examples
misclassified_idx = np.where(y_test != y_pred)[0]

print(f"\nMisclassified: {len(misclassified_idx)} / {len(y_test)} ({len(misclassified_idx)/len(y_test)*100:.1f}%)")

# Analyze errors by class
from collections import Counter
error_by_class = Counter(y_test[misclassified_idx])

print("Errors by true class:")
for class_label, count in error_by_class.most_common():
    print(f"  Class {class_label}: {count} errors")
```

### 7. Generate Evaluation Report

```python
from lisa.diary import Diary

diary = Diary()

# Determine recommendation
target = 0.90  # From config
if current_score >= target:
    recommendation = "DEPLOY - Target achieved!"
    next_action = "STOP"
elif is_better and (target - current_score) < 0.05:
    recommendation = "CONTINUE - Close to target, try fine-tuning"
    next_action = "FINE_TUNE"
elif is_better:
    recommendation = "CONTINUE - Improving, keep experimenting"
    next_action = "CONTINUE"
else:
    recommendation = "TRY_DIFFERENT_APPROACH - No improvement"
    next_action = "CHANGE_STRATEGY"

diary.write_entry(
    entry_type='evaluation',
    title=f'Model Evaluation: {run_id}',
    content={
        'context': f'Evaluating model from run {run_id}',
        'results': {
            'metrics': metrics,
            'comparison': {
                'current': current_score,
                'previous_best': best_score,
                'improvement': current_score - best_score,
                'is_better': is_better
            },
            'error_analysis': {
                'total_errors': len(misclassified_idx),
                'error_rate': len(misclassified_idx) / len(y_test),
                'errors_by_class': dict(error_by_class)
            }
        },
        'conclusions': recommendation,
        'next_steps': next_action,
        'artifacts': {
            'plots': [str(p) for p in plots]
        }
    },
    experiment_id=run_id
)
```

## Completion Signal

```
<promise>EVALUATION_COMPLETE:{run_id}:{recommendation}:{current_score}</promise>
```

Example:
```
<promise>EVALUATION_COMPLETE:abc123:CONTINUE:0.8645</promise>
```
