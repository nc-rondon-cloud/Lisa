# BigQuery Access via MCP

## Overview

Lisa has access to BigQuery through MCP (Model Context Protocol) for data validation and verification during ML workflows.

## Purpose

BigQuery access enables Lisa to:
- Validate data freshness before experiments
- Check schema and data quality in source systems
- Verify assumptions about data distributions
- Sample production data for validation
- Compare model predictions with actuals
- Detect data drift

## How Lisa Uses BigQuery

### 1. Identifying Data Sources

Lisa autonomously identifies BigQuery data sources from repository context:

**Sources to check**:
- `README.md` - Project documentation
- `lisa_config.yaml` - Configuration files
- `lisa/PRD.md` - Product requirements
- `.env` files - Environment variables
- Existing SQL queries in codebase
- Previous diary entries
- Code comments and documentation

**What to look for**:
- Project IDs (e.g., `my-gcp-project`)
- Dataset names (e.g., `analytics_dataset`)
- Table names (e.g., `user_events`)
- BigQuery references in code
- GCP service account paths

### 2. Query Guidelines

Lisa follows these principles when querying BigQuery:

#### ✅ Lightweight Queries (Encouraged)
```sql
-- Check metadata
SELECT table_name, creation_time, row_count
FROM `project.dataset.__TABLES__`

-- Sample data
SELECT * FROM `project.dataset.table` LIMIT 100

-- Count and basic stats
SELECT COUNT(*) as total,
       COUNT(DISTINCT user_id) as unique_users
FROM `project.dataset.table`

-- Check freshness
SELECT MAX(timestamp) as latest_data
FROM `project.dataset.table`

-- Validate schema
SELECT column_name, data_type
FROM `project.dataset.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'table_name'
```

#### ❌ Heavy Queries (Avoid)
```sql
-- Avoid: Full table scans without LIMIT
SELECT * FROM `project.dataset.huge_table`

-- Avoid: Complex joins on large tables
SELECT * FROM table1 t1
JOIN table2 t2 ON t1.id = t2.id
JOIN table3 t3 ON t2.id = t3.id

-- Avoid: Expensive aggregations across all data
SELECT col1, col2, COUNT(*), AVG(val), STDDEV(val)
FROM `project.dataset.huge_table`
GROUP BY col1, col2
```

### 3. Use Cases by Phase

#### During EDA
- Check data freshness in source
- Validate row counts before downloading
- Sample data for initial exploration
- Verify schema matches expectations
- Check for recent changes

#### During Experiment Design
- Validate training data is current
- Check feature distributions haven't shifted
- Verify target variable balance
- Sample recent data for experiments

#### During Evaluation
- Validate model on fresh production data
- Compare predictions with actual outcomes
- Check for data drift
- Validate on different time periods

## Best Practices

### 1. Be Strategic
- Query only when validation adds value
- Use LIMIT for exploration
- Check metadata before querying data
- Cache results when possible

### 2. Document Queries
```python
from lisa.diary import Diary

diary = Diary()
diary.write_entry(
    entry_type='validation',
    title='BigQuery Data Validation',
    content={
        'query': 'SELECT COUNT(*) FROM `project.dataset.table`',
        'purpose': 'Verify row count matches local data',
        'result': '1,234,567 rows',
        'decision': 'Data is fresh, proceeding with experiment'
    }
)
```

### 3. Handle Errors Gracefully
- BigQuery might not always be available
- Tables might have changed
- Queries might time out
- Have fallback strategies

### 4. Cost Awareness
- Use `LIMIT` for exploration
- Query only necessary columns
- Use partitioned tables when available
- Leverage table metadata instead of querying data

## Example Workflows

### Workflow 1: Validate Before Downloading
```python
# 1. Check BigQuery for data info
query = """
SELECT
  COUNT(*) as row_count,
  MAX(timestamp) as latest_data,
  MIN(timestamp) as earliest_data
FROM `project.dataset.training_data`
"""
# Run via MCP

# 2. Decide if download is needed
if latest_data > local_data_timestamp:
    print("New data available, downloading...")
else:
    print("Local data is current, using cached version")
```

### Workflow 2: Validate Data Distribution
```python
# Check if distribution has changed
query = """
SELECT
  target_class,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `project.dataset.training_data`
WHERE date >= CURRENT_DATE() - 30
GROUP BY target_class
"""
# Run via MCP
# Compare with training distribution
```

### Workflow 3: Production Validation
```python
# Sample recent production data for testing
query = """
SELECT *
FROM `project.dataset.production_data`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY RAND()
LIMIT 1000
"""
# Run via MCP
# Evaluate model on this fresh sample
```

## Integration with Lisa Workflow

### Automatic Detection
Lisa automatically:
1. Scans repository for BigQuery references
2. Identifies project, dataset, table names
3. Determines appropriate queries based on context
4. Runs validation queries when beneficial
5. Documents findings in diary

### Manual Override
You can also explicitly specify BigQuery details in:
- `lisa_config.yaml`:
  ```yaml
  bigquery:
    project_id: "my-gcp-project"
    dataset: "ml_dataset"
    validation_table: "training_data"
  ```

- `lisa/PRD.md`:
  ```markdown
  ## Data Sources

  Training data is in BigQuery:
  - Project: my-gcp-project
  - Dataset: ml_dataset
  - Table: training_data
  - Updated: Daily at 2 AM UTC
  ```

## Security & Permissions

- Lisa uses MCP for BigQuery access
- Credentials managed by MCP configuration
- Lisa has read-only access
- Respects BigQuery quotas and limits
- All queries logged for audit

## Troubleshooting

### Issue: "Table not found"
- Check table name spelling
- Verify project and dataset IDs
- Confirm Lisa has access permissions

### Issue: "Query timeout"
- Simplify query (add LIMIT)
- Use table metadata instead
- Check if table is too large

### Issue: "Permission denied"
- Verify MCP BigQuery configuration
- Check service account permissions
- Confirm project ID is correct

## Summary

BigQuery access via MCP empowers Lisa to:
- ✅ Validate data autonomously
- ✅ Make informed decisions
- ✅ Detect issues early
- ✅ Ensure model training on fresh data
- ✅ Verify assumptions continuously

Lisa identifies what to query from repository context and runs lightweight validation queries intelligently throughout the ML workflow.
