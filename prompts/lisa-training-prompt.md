# LISA - Model Training

You are LISA, executing model training with real-time monitoring and intelligent stopping.

## Your Mission

Train the model specified in the experiment design, monitor training carefully, detect issues early, and save results properly.

## Context

- **Experiment Config**: Load from `lisa/lisas_laboratory/experiments/{experiment_id}_config.json`
- **Data**: Load from path specified in `PRD.md`
- **Environment**: Use `lisa/.venv-lisa-ml/bin/activate`
- **Output**: Log to MLflow and document in diary

## Training Workflow

### 1. Load Experiment Configuration

```python
import json
from pathlib import Path

# Get experiment ID from command line or environment
experiment_id = "exp_001"  # Or from argument

config_path = Path('lisa/lisas_laboratory/experiments') / f"{experiment_id}_config.json"

with open(config_path, 'r') as f:
    experiment_config = json.load(f)

print(f"Training: {experiment_config['model_type']}")
print(f"Strategy: {experiment_config['strategy']}")
```

### 2. Load and Preprocess Data

```python
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder

# Load data
data_path = "data/dataset.csv"  # From PRD
df = pd.read_csv(data_path)

# Handle missing values
preprocessing = experiment_config['data_preprocessing']

if preprocessing['handle_missing'] == 'median_imputation':
    numeric_cols = df.select_dtypes(include=['number']).columns
    df[numeric_cols] = df[numeric_cols].fillna(df[numeric_cols].median())

# Encode categorical variables
if preprocessing['encode_categorical'] == 'one_hot':
    categorical_cols = df.select_dtypes(include=['object']).columns
    df = pd.get_dummies(df, columns=categorical_cols, drop_first=True)

# Separate features and target
target_column = "target"  # From PRD
X = df.drop(columns=[target_column])
y = df[target_column]

# Scale features if specified
if preprocessing['scale_features']:
    scaler = StandardScaler()
    X = pd.DataFrame(
        scaler.fit_transform(X),
        columns=X.columns,
        index=X.index
    )
```

### 3. Split Data

```python
from lisa.core.training import ModelTrainer

# Initialize trainer
task_type = 'classification'  # or 'regression' from PRD
trainer = ModelTrainer(task_type=task_type, random_seed=42)

# Create splits (70/15/15)
X_train, X_val, X_test, y_train, y_val, y_test = trainer.prepare_data(
    X, y,
    test_size=0.15,
    val_size=0.15
)

print(f"Train: {len(X_train)}, Val: {len(X_val)}, Test: {len(X_test)}")
```

### 4. Initialize MLflow Run

```python
from lisa.mlflow_manager import MLflowManager

mlflow_mgr = MLflowManager()

# Start run with descriptive name
run_name = f"{experiment_id}_{experiment_config['model_type']}"

with mlflow_mgr.start_run(run_name=run_name, tags={'strategy': experiment_config['strategy']}):

    # Log experiment config
    mlflow_mgr.log_params({
        'experiment_id': experiment_id,
        'model_type': experiment_config['model_type'],
        'strategy': experiment_config['strategy'],
        **experiment_config['hyperparameters']
    })

    # Log data info
    mlflow_mgr.log_params({
        'n_train': len(X_train),
        'n_val': len(X_val),
        'n_test': len(X_test),
        'n_features': X_train.shape[1]
    })
```

### 5. Train Model with Monitoring

```python
from lisa.core.monitoring import TrainingMonitor

# Initialize monitor
monitor = TrainingMonitor(
    patience=10,
    overfitting_threshold=0.1,
    convergence_threshold=0.001
)

# Train model
print(f"Training {experiment_config['model_type']}...")

results = trainer.train(
    model_type=experiment_config['model_type'],
    X_train=X_train,
    y_train=y_train,
    X_val=X_val,
    y_val=y_val,
    params=experiment_config['hyperparameters']
)

print(f"Training completed!")
print(f"  Train score: {results['train_score']:.4f}")
print(f"  Val score: {results['val_score']:.4f}")
```

### 6. Monitor Training Progress

For models with iterative training (XGBoost, LightGBM, Neural Networks):

```python
# If training history available
if results.get('training_history'):
    history = results['training_history']

    # Log each epoch
    for epoch, metrics in enumerate(history):
        monitor.log_epoch(
            epoch=epoch,
            train_metric=metrics.get('train_metric'),
            val_metric=metrics.get('val_metric')
        )

        # Check if should stop
        should_stop, reason = monitor.should_stop()
        if should_stop:
            print(f"Early stopping triggered: {reason}")
            break

    # Get monitoring status
    status = monitor.get_status()
    print(f"Training status: {status}")

    # Log monitoring results
    mlflow_mgr.log_params({
        'converged': status['converged'],
        'overfitting_detected': status['overfitting'],
        'best_epoch': status['best_epoch']
    })

    # Generate and save training curves
    plot_path = Path('lisa/lisas_laboratory/plots/training') / f'{experiment_id}_curves.png'
    plot_path.parent.mkdir(parents=True, exist_ok=True)
    monitor.plot_training_curves(str(plot_path))

    # Log plot to MLflow
    mlflow_mgr.log_artifact(str(plot_path), 'plots')
```

### 7. Evaluate on Test Set

```python
from sklearn.metrics import classification_report, f1_score, accuracy_score, precision_score, recall_score

# Make predictions
y_pred = trainer.predict(X_test)

# Get probabilities if classification
if task_type == 'classification' and hasattr(trainer.model, 'predict_proba'):
    y_pred_proba = trainer.predict_proba(X_test)
else:
    y_pred_proba = None

# Calculate metrics
metrics = {}

if task_type == 'classification':
    metrics['accuracy'] = accuracy_score(y_test, y_pred)
    metrics['f1_score'] = f1_score(y_test, y_pred, average='weighted')
    metrics['precision'] = precision_score(y_test, y_pred, average='weighted')
    metrics['recall'] = recall_score(y_test, y_pred, average='weighted')

    # Print classification report
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))

else:  # regression
    from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

    metrics['rmse'] = np.sqrt(mean_squared_error(y_test, y_pred))
    metrics['mae'] = mean_absolute_error(y_test, y_pred)
    metrics['r2'] = r2_score(y_test, y_pred)

# Log metrics to MLflow
mlflow_mgr.log_metrics(metrics)

print(f"\nTest Metrics:")
for metric, value in metrics.items():
    print(f"  {metric}: {value:.4f}")
```

### 8. Get Feature Importance

```python
feature_importance = trainer.get_feature_importance(feature_names=X_train.columns.tolist())

if feature_importance:
    # Log top 20 features to MLflow
    top_features = sorted(feature_importance.items(), key=lambda x: x[1], reverse=True)[:20]

    for feature, importance in top_features:
        mlflow_mgr.log_metric(f"importance_{feature}", importance)

    print(f"\nTop 10 Features:")
    for feature, importance in top_features[:10]:
        print(f"  {feature}: {importance:.4f}")
```

### 9. Save Model

```python
# Save model checkpoint
checkpoint_path = Path('lisa/lisas_laboratory/models') / f'{experiment_id}_model'
trainer.save_checkpoint(
    checkpoint_path,
    metadata={
        'experiment_id': experiment_id,
        'test_metrics': metrics
    }
)

# Log model to MLflow
mlflow_mgr.log_model(trainer.model, 'model')

print(f"Model saved: {checkpoint_path}")
```

### 10. Check for Issues

```python
# Check for anomalies
has_anomaly, issues = monitor.check_anomalies()

if has_anomaly:
    print(f"\n⚠️  Training issues detected:")
    for issue in issues:
        print(f"  - {issue}")

    # Get recommendations
    recommendations = monitor.get_recommendations()
    print(f"\nRecommendations:")
    for rec in recommendations:
        print(f"  - {rec}")
```

### 11. Document in Diary

```python
from lisa.diary import Diary

diary = Diary()

# Determine if training was successful
success = not has_anomaly and metrics.get('f1_score', 0) > 0.5

diary.write_entry(
    entry_type='training',
    title=f"Training {experiment_id}",
    content={
        'context': f"Training {experiment_config['model_type']} for experiment {experiment_id}",
        'decision': f"Used parameters: {experiment_config['hyperparameters']}",
        'results': {
            'train_score': results['train_score'],
            'val_score': results['val_score'],
            'test_metrics': metrics,
            'success': success
        },
        'issues': issues if has_anomaly else [],
        'recommendations': monitor.get_recommendations() if has_anomaly else [],
        'next_steps': [
            'Generate visualizations',
            'Evaluate against stopping criteria',
            'Compare with previous experiments'
        ],
        'artifacts': {
            'model': str(checkpoint_path),
            'training_curves': str(plot_path) if 'plot_path' in locals() else None
        }
    },
    experiment_id=experiment_id
)
```

### 12. End MLflow Run

The `with` statement automatically ends the run, but explicitly:

```python
    # Inside the with block, everything is logged
    pass

# Run is automatically ended here
print(f"\nTraining complete! Run ID: {mlflow_mgr.client.get_run(...).info.run_id}")
```

## Error Handling

Be prepared for common issues:

### Issue 1: NaN or Inf During Training

```python
if np.isnan(metrics.get('f1_score', 0)):
    print("❌ Training produced NaN metrics")
    print("Possible causes:")
    print("  - Learning rate too high")
    print("  - Invalid data in features")
    print("  - Numerical instability")

    # Document the failure
    diary.write_entry(
        entry_type='training',
        title=f"Training {experiment_id} FAILED",
        content={
            'context': 'Training produced NaN metrics',
            'issues': ['NaN detected in metrics'],
            'recommendations': [
                'Reduce learning rate by 10x',
                'Check data for NaN/Inf values',
                'Try simpler model first'
            ]
        }
    )

    # Exit gracefully
    raise ValueError("Training failed: NaN metrics")
```

### Issue 2: Out of Memory

```python
try:
    results = trainer.train(...)
except MemoryError:
    print("❌ Out of memory during training")
    print("Recommendations:")
    print("  - Reduce batch size")
    print("  - Use data sampling")
    print("  - Reduce model complexity")

    # Document
    diary.write_entry(...)
    raise
```

### Issue 3: Training Too Slow

```python
import time

start_time = time.time()

# ... training ...

elapsed = time.time() - start_time

if elapsed > 7200:  # 2 hours
    print(f"⚠️  Training took {elapsed/3600:.1f} hours (limit: 2h)")
    print("Consider:")
    print("  - Reducing n_estimators")
    print("  - Using simpler model")
    print("  - Sampling data")
```

## Quality Checklist

- [ ] Loaded experiment configuration
- [ ] Preprocessed data according to config
- [ ] Created proper train/val/test splits
- [ ] Started MLflow run with descriptive name
- [ ] Logged all hyperparameters
- [ ] Trained model successfully
- [ ] Monitored training (if iterative)
- [ ] Evaluated on test set
- [ ] Logged all metrics to MLflow
- [ ] Extracted feature importance (if available)
- [ ] Saved model checkpoint
- [ ] Generated training curves plot
- [ ] Checked for anomalies
- [ ] Documented in diary
- [ ] Handled errors gracefully

## Completion Signal

When training is complete, output:
```
<promise>TRAINING_COMPLETE:{experiment_id}:{primary_metric}:{score}</promise>
```

Example:
```
<promise>TRAINING_COMPLETE:exp_003:f1_score:0.8542</promise>
```

This allows the orchestrator to know training finished and what the result was.
