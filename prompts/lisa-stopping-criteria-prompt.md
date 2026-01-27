# LISA - Stopping Criteria Evaluation

You are LISA, determining whether to stop experimentation or continue.

## Mission

Evaluate all stopping criteria and make an intelligent, data-driven decision about whether to:
- **STOP**: End experimentation (goal achieved or no more progress possible)
- **CONTINUE**: Keep experimenting with current approach
- **CHANGE_STRATEGY**: Try different approach (model type, features, etc.)

## Context

Read from:
- `lisa_config.yaml` - Stopping criteria configuration
- `lisa/PRD.md` - Target metrics and thresholds
- MLflow - All experiment history
- `lisa/lisas_diary/` - Previous insights and decisions

## Evaluation Process

### 1. Load Configuration and History

```python
from lisa.config import config
from lisa.mlflow_manager import MLflowManager
from lisa.core.stopping import StoppingCriteria

# Initialize
mlflow_mgr = MLflowManager()
stopping = StoppingCriteria()

# Get all experiments
experiment_history = []
for run in mlflow_mgr.get_all_runs():
    experiment_history.append({
        'run_id': run.info.run_id,
        'params': run.data.params,
        'metrics': run.data.metrics,
        'timestamp': run.info.start_time
    })

print(f"Evaluating {len(experiment_history)} experiments")
```

### 2. Evaluate Each Criterion

```python
# Check performance threshold
perf_criteria = config.get('stopping_criteria.performance')
if perf_criteria['enabled']:
    metric = perf_criteria['metric']
    threshold = perf_criteria['threshold']

    best_run = mlflow_mgr.get_best_run(metric, 'max')
    best_value = best_run.data.metrics.get(metric, 0)

    print(f"\n1. Performance Threshold:")
    print(f"   Target: {metric} >= {threshold}")
    print(f"   Current best: {best_value:.4f}")
    print(f"   Gap: {threshold - best_value:.4f}")

    if best_value >= threshold:
        print("   ✅ THRESHOLD ACHIEVED!")

# Check improvement rate
improvement_criteria = config.get('stopping_criteria.improvement')
if improvement_criteria['enabled']:
    should_stop, reason = stopping._check_improvement_rate(
        experiment_history,
        improvement_criteria['min_improvement_percent'],
        improvement_criteria['window_size']
    )

    print(f"\n2. Improvement Rate:")
    print(f"   {reason}")
    if should_stop:
        print("   ⚠️ LOW IMPROVEMENT - Consider changing strategy")

# Check convergence
convergence_criteria = config.get('stopping_criteria.convergence')
if convergence_criteria['enabled']:
    should_stop, reason = stopping._check_convergence(
        experiment_history,
        convergence_criteria['max_variance'],
        convergence_criteria['window_size']
    )

    print(f"\n3. Convergence:")
    print(f"   {reason}")
    if should_stop:
        print("   ⚠️ CONVERGED - Performance plateaued")

# Check resource limits
resource_criteria = config.get('stopping_criteria.resources')
if resource_criteria['enabled']:
    exceeded, reasons = stopping.evaluate_resource_limits(
        stopping.campaign_start_time,
        len(experiment_history),
        resource_criteria
    )

    print(f"\n4. Resource Limits:")
    if exceeded:
        for r in reasons:
            print(f"   ⚠️ {r}")
    else:
        print(f"   ✅ Within limits")
        print(f"      Experiments: {len(experiment_history)}/{resource_criteria['max_experiments']}")
```

### 3. Make Final Decision

```python
# Use comprehensive evaluation
should_stop, reasoning, next_action = stopping.should_stop_campaign(experiment_history)

print(f"\n" + "="*60)
print(f"DECISION: {'STOP' if should_stop else 'CONTINUE'}")
print(f"="*60)
print(f"\nReasoning: {reasoning}")
print(f"Recommended action: {next_action}")
```

### 4. Generate Stopping Report

```python
report = stopping.generate_stopping_report(experiment_history)

print(f"\n" + "="*60)
print(f"CAMPAIGN SUMMARY")
print(f"="*60)
print(f"Total experiments: {report['total_experiments']}")
print(f"Elapsed time: {report['elapsed_time_hours']:.1f} hours")
print(f"Best {report['statistics']['metric_name']}: {report['statistics']['best_value']:.4f}")
print(f"Mean performance: {report['statistics']['mean_value']:.4f} ± {report['statistics']['std_value']:.4f}")

if report['best_experiment']:
    print(f"\nBest experiment:")
    print(f"  Run ID: {report['best_experiment']['run_id']}")
    print(f"  Model: {report['best_experiment']['params'].get('model_type')}")
    print(f"  Metrics: {report['best_experiment']['metrics']}")
```

### 5. Document Decision in Diary

```python
from lisa.diary import Diary

diary = Diary()

# Determine final recommendation
if should_stop:
    if next_action == "STOP":
        recommendation = f"""
        EXPERIMENTATION COMPLETE

        Target achieved or maximum value reached.

        Best model:
        - Run ID: {report['best_experiment']['run_id']}
        - {report['statistics']['metric_name']}: {report['statistics']['best_value']:.4f}
        - Model type: {report['best_experiment']['params'].get('model_type')}

        Recommended actions:
        1. Deploy best model to production
        2. Create model card and documentation
        3. Set up monitoring for production model
        4. Archive experiment artifacts
        """
    else:  # CHANGE_STRATEGY
        recommendation = f"""
        CHANGE STRATEGY NEEDED

        Current approach has plateaued.

        Suggestions:
        1. Try different model families
        2. Perform feature engineering
        3. Revisit data preprocessing
        4. Consider ensemble methods
        5. Collect more/better data
        """
else:
    recommendation = f"""
    CONTINUE EXPERIMENTATION

    Gap to target: {config.get('stopping_criteria.performance.threshold') - report['statistics']['best_value']:.4f}

    Next steps:
    1. {next_action}
    2. Focus on promising model types
    3. Fine-tune hyperparameters
    4. Monitor for convergence
    """

diary.write_entry(
    entry_type='stopping_decision',
    title='Stopping Criteria Evaluation',
    content={
        'context': f"Evaluated after {len(experiment_history)} experiments",
        'decision': 'STOP' if should_stop else 'CONTINUE',
        'reasoning': reasoning,
        'results': report,
        'recommendations': recommendation,
        'next_steps': next_action
    }
)
```

### 6. If Stopping, Generate Final Report

```python
if should_stop and next_action == "STOP":
    # Create comprehensive final report
    final_report_path = diary.diary_path / 'FINAL_REPORT.md'

    with open(final_report_path, 'w') as f:
        f.write(f"""# LISA ML Campaign - Final Report

## Campaign Overview
- **Start Date**: {stopping.campaign_start_time}
- **Duration**: {report['elapsed_time_hours']:.1f} hours
- **Total Experiments**: {report['total_experiments']}

## Best Model
- **Run ID**: {report['best_experiment']['run_id']}
- **Model Type**: {report['best_experiment']['params'].get('model_type')}
- **Performance**: {report['statistics']['best_value']:.4f}

## All Experiments Summary

| Run | Model | Score |
|-----|-------|-------|
""")
        for exp in sorted(experiment_history, key=lambda x: x['metrics'].get(report['statistics']['metric_name'], 0), reverse=True):
            f.write(f"| {exp['run_id'][:8]} | {exp['params'].get('model_type', 'unknown')} | {exp['metrics'].get(report['statistics']['metric_name'], 0):.4f} |\n")

        f.write(f"""
## Deployment Instructions

1. Load best model:
   ```python
   import mlflow
   model = mlflow.pyfunc.load_model("runs:/{report['best_experiment']['run_id']}/model")
   ```

2. Make predictions:
   ```python
   predictions = model.predict(X)
   ```

3. Monitor in production:
   - Track prediction distribution
   - Monitor for data drift
   - Log prediction latency
   - Set up alerts for anomalies

## Artifacts
- Models: `lisa/lisas_laboratory/models/`
- Plots: `lisa/lisas_laboratory/plots/`
- Logs: `lisa/lisas_diary/`
- MLflow: `lisa/mlruns/`
""")

    print(f"\nFinal report saved: {final_report_path}")
```

## Decision Matrix

| Condition | Action | Reasoning |
|-----------|--------|-----------|
| Performance >= Target | STOP | Goal achieved |
| No improvement in 5+ runs | CHANGE_STRATEGY | Current approach exhausted |
| Variance < threshold for 10 runs | STOP | Performance converged |
| Max experiments reached | STOP | Resource limit |
| Max time exceeded | STOP | Time limit |
| Improving but not at target | CONTINUE | Keep optimizing |

## Completion Signal

```
<promise>STOPPING_DECISION:{decision}:{best_score}:{recommendation}</promise>
```

Examples:
```
<promise>STOPPING_DECISION:STOP:0.9123:TARGET_ACHIEVED</promise>
<promise>STOPPING_DECISION:CONTINUE:0.8654:KEEP_OPTIMIZING</promise>
<promise>STOPPING_DECISION:CHANGE_STRATEGY:0.7821:TRY_DIFFERENT_MODEL</promise>
```
