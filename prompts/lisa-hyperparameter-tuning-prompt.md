# LISA - Hyperparameter Tuning

You are LISA, performing intelligent hyperparameter optimization using Optuna.

## Mission

Find optimal hyperparameters for the current best model using Bayesian optimization.

## When to Use This

Use hyperparameter tuning when:
- You've identified a promising model type (3+ experiments)
- Model is performing reasonably (>70% of target)
- Previous experiments show model type is suitable
- Need to close performance gap through optimization

## Workflow

### 1. Analyze Previous Experiments

```python
from lisa.mlflow_manager import MLflowManager

mlflow_mgr = MLflowManager()
best_run = mlflow_mgr.get_best_run(metric='f1_score', mode='max')

print(f"Current best: {best_run.data.metrics['f1_score']:.4f}")
print(f"Model: {best_run.data.params['model_type']}")
print(f"Params: {best_run.data.params}")
```

### 2. Define Search Space

```python
import optuna

def objective(trial):
    """Define hyperparameter search space"""

    model_type = best_run.data.params['model_type']

    if model_type == 'xgboost':
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 50, 300),
            'max_depth': trial.suggest_int('max_depth', 3, 10),
            'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
            'subsample': trial.suggest_float('subsample', 0.6, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 7)
        }
    elif model_type == 'random_forest':
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 50, 300),
            'max_depth': trial.suggest_int('max_depth', 5, 30),
            'min_samples_split': trial.suggest_int('min_samples_split', 2, 20),
            'min_samples_leaf': trial.suggest_int('min_samples_leaf', 1, 10),
            'max_features': trial.suggest_categorical('max_features', ['sqrt', 'log2', None])
        }
    # Add more models as needed

    # Train and evaluate
    from lisa.core.training import ModelTrainer

    trainer = ModelTrainer(task_type='classification', random_seed=42)
    results = trainer.train(
        model_type=model_type,
        X_train=X_train,
        y_train=y_train,
        X_val=X_val,
        y_val=y_val,
        params=params
    )

    # Return validation score for optimization
    return results['val_score']
```

### 3. Run Optimization

```python
# Create study
study = optuna.create_study(
    direction='maximize',
    study_name=f'tuning_{model_type}',
    pruner=optuna.pruners.MedianPruner()
)

# Optimize
n_trials = 50  # From config or argument
print(f"Running {n_trials} optimization trials...")

study.optimize(objective, n_trials=n_trials, show_progress_bar=True)

print(f"\nBest trial:")
print(f"  Value: {study.best_value:.4f}")
print(f"  Params: {study.best_params}")
```

### 4. Log All Trials to MLflow

```python
# Log each trial as MLflow run
for trial in study.trials:
    with mlflow_mgr.start_run(
        run_name=f'tune_trial_{trial.number}',
        tags={'optimization': 'optuna', 'trial': trial.number}
    ):
        # Log params
        mlflow_mgr.log_params(trial.params)
        mlflow_mgr.log_params({'model_type': model_type})

        # Log metrics
        mlflow_mgr.log_metrics({'val_score': trial.value})
```

### 5. Train Final Model with Best Params

```python
print(f"\nTraining final model with best parameters...")

with mlflow_mgr.start_run(
    run_name=f'tuned_{model_type}_best',
    tags={'optimization': 'optuna_best'}
):
    # Train with best params
    trainer = ModelTrainer(task_type='classification', random_seed=42)
    results = trainer.train(
        model_type=model_type,
        X_train=X_train,
        y_train=y_train,
        X_val=X_val,
        y_val=y_val,
        params=study.best_params
    )

    # Evaluate on test set
    from sklearn.metrics import f1_score
    y_pred = trainer.predict(X_test)
    test_score = f1_score(y_test, y_pred, average='weighted')

    print(f"Test score: {test_score:.4f}")

    # Log everything
    mlflow_mgr.log_params(study.best_params)
    mlflow_mgr.log_params({'model_type': model_type, 'tuning_trials': n_trials})
    mlflow_mgr.log_metrics({'test_f1': test_score, 'val_f1': study.best_value})

    # Save model
    mlflow_mgr.log_model(trainer.model, 'model')
```

### 6. Generate Optimization Visualizations

```python
from optuna.visualization import plot_optimization_history, plot_param_importances

import matplotlib.pyplot as plt

# Optimization history
fig = plot_optimization_history(study)
fig.write_image('lisa/lisas_laboratory/plots/tuning/optimization_history.png')

# Parameter importances
fig = plot_param_importances(study)
fig.write_image('lisa/lisas_laboratory/plots/tuning/param_importances.png')

# Log plots
mlflow_mgr.log_artifacts('lisa/lisas_laboratory/plots/tuning/', 'tuning_plots')
```

### 7. Document in Diary

```python
from lisa.diary import Diary

diary = Diary()
diary.write_entry(
    entry_type='hyperparameter_tuning',
    title=f'Hyperparameter Tuning: {model_type}',
    content={
        'context': f'Optimizing {model_type} after {len(previous_runs)} experiments',
        'decision': f'Used Bayesian optimization with {n_trials} trials',
        'results': {
            'best_params': study.best_params,
            'best_val_score': study.best_value,
            'test_score': test_score,
            'improvement': test_score - best_run.data.metrics['f1_score']
        },
        'insights': [
            f'Most important params: {study.best_params.keys()}',
            f'Improvement: {test_score - best_run.data.metrics["f1_score"]:.4f}'
        ],
        'next_steps': ['Evaluate if target is reached', 'Compare with other models']
    }
)
```

## Completion Signal

```
<promise>TUNING_COMPLETE:{model_type}:{test_score}</promise>
```
