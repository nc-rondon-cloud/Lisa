# Product Requirements Document - ML Mode

## Mode
**LISA Mode**: ML (Machine Learning / Data Science)

## Model Objective

### Problem Type
**Type**: [Classification | Regression | Clustering | Time Series | NLP | Computer Vision | Recommendation]

### Business Goal
Describe what the model should solve and why it matters:
- Example: Predict customer churn to enable proactive retention
- Example: Recommend products to increase conversion rate
- Example: Detect fraudulent transactions in real-time

## Data

### Dataset Locations
```yaml
datasets:
  - name: "main_dataset"
    path: "data/dataset.csv"
    type: "csv"
    description: "Main dataset with features and target"

  # Add more datasets if needed
  # - name: "additional_data"
  #   path: "data/additional.parquet"
  #   type: "parquet"
  #   description: "Additional features to join"
```

### Features and Target
- **Features**: [List specific columns, or write "LISA to choose based on EDA"]
- **Target Variable**: `target_column_name`
- **Join Keys** (if multiple datasets): `customer_id`, `transaction_id`

### Data Characteristics
- **Expected Size**: ~X rows, Y columns
- **Time Period**: [Date range if applicable]
- **Known Issues**: [Missing values in certain columns, class imbalance, etc.]

## Metrics and Stopping Criteria

### Evaluation Metrics
- **Primary Metric**: `f1_score` (or accuracy, rmse, mae, roc_auc, etc.)
- **Secondary Metrics**: `precision`, `recall`, `roc_auc`

### Stopping Criteria
```yaml
stop_when:
  performance:
    metric: "f1_score"
    threshold: 0.90  # Stop when this is achieved

  improvement:
    min_improvement_percent: 1.0  # Stop if improvement < 1% for N experiments
    window_size: 5

  convergence:
    max_variance: 0.01  # Stop if performance variance < 0.01
    window_size: 10

  resources:
    max_experiments: 50  # Maximum number of experiments to run
    max_time_hours: 24   # Maximum total time
```

## Constraints and Preferences

### Allowed Models
- ✅ RandomForest, XGBoost, LightGBM
- ✅ Logistic Regression, Linear Models
- ✅ Neural Networks (shallow)
- ❌ Deep Learning (no GPU available)
- ❌ Transformer models (too resource-intensive)

### Feature Constraints
**Required Features**: These MUST be included in the final model
- `feature_1`, `feature_2`

**Forbidden Features**: Do NOT use (risk of data leakage or unavailable in production)
- `customer_id`, `created_at`, `internal_id`

**Derived Features**: LISA may create these
- Time-based features (day_of_week, hour, etc.)
- Aggregations (mean, max, count, etc.)
- Interactions (feature_a * feature_b)

### Computational Resources
- **Memory Limit**: 16GB RAM
- **Time per Experiment**: Max 2 hours
- **GPU**: Not available
- **Parallel Processing**: Up to 4 cores

### Model Preferences
Order from most to least preferred:
1. **Interpretability**: Prefer models with feature importance
2. **Performance**: Prioritize accuracy/F1 score
3. **Speed**: Fast inference time (< 100ms per prediction)
4. **Simplicity**: Prefer simpler models if performance is similar

### Specific Requirements
- **Cross-Validation**: Use 5-fold CV for all experiments
- **Train/Val/Test Split**: 70/15/15
- **Handle Imbalance**: Use SMOTE or class weights if needed
- **Feature Selection**: Apply if > 50 features
- **Regularization**: Prevent overfitting (dropout, L2, etc.)

## Expected Workflow

LISA will autonomously:
1. **EDA Phase**: Analyze datasets, identify issues, suggest preprocessing
2. **Baseline**: Create simple baseline model (e.g., RandomForest with default params)
3. **Experimentation**: Try different models and feature sets
4. **Optimization**: Hyperparameter tuning via Optuna
5. **Evaluation**: Generate metrics and visualizations
6. **Documentation**: Record all decisions and results in `lisas_diary/`
7. **Stopping**: Automatically stop when criteria are met
8. **Final Report**: Summarize all experiments and recommend best model

## Tasks (LISA will update progress)
- [ ] Exploratory Data Analysis (EDA)
- [ ] Data preprocessing and cleaning
- [ ] Baseline model training
- [ ] Feature engineering
- [ ] Hyperparameter optimization
- [ ] Model evaluation and comparison
- [ ] Generate visualizations
- [ ] Final model selection
- [ ] Documentation and model card

## Notes

### Context for LISA
[Add any additional context that would help LISA understand the problem better]
- Domain knowledge (e.g., "customers with high balance are less likely to churn")
- Business constraints (e.g., "false negatives are 5x more costly than false positives")
- Production environment (e.g., "model will be deployed as REST API on AWS Lambda")

### Success Criteria
The ML project is considered successful when:
- [ ] Primary metric threshold is achieved (`f1_score >= 0.90`)
- [ ] Model is interpretable (feature importance available)
- [ ] All experiments are documented
- [ ] Best model is saved and versioned in MLflow
- [ ] Visualizations are generated (confusion matrix, ROC curves, etc.)

---

**Instructions for LISA**:
1. Read this PRD carefully
2. Start with EDA - analyze all datasets in `data/` directory
3. Document every decision in `lisas_diary/`
4. Track all experiments in MLflow
5. Generate relevant visualizations in `lisas_laboratory/plots/`
6. Stop when stopping criteria are met
7. Generate final report with model recommendation
