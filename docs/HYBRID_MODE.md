# LISA Hybrid ML→Code Mode

## Overview

The Hybrid Mode enables Lisa to automatically transition from ML experimentation to code integration, creating a seamless workflow that requires no manual intervention between finding the best model and integrating it into your codebase.

## How It Works

### Workflow

```
1. ML Phase (Experimentation)
   ↓
   • Run ML experiments to find best model
   • Track performance in MLflow
   • Stop when target achieved or max iterations

2. Model Extraction
   ↓
   • Query MLflow for best performing run
   • Extract model metadata and hyperparameters
   • Create BEST_MODEL.json

3. PRD Generation
   ↓
   • Analyze existing codebase structure
   • Generate specific implementation tasks
   • Create PRD.md for Code mode

4. Code Integration
   ↓
   • Load and implement PRD tasks
   • Integrate model into existing code
   • Add tests and documentation
```

## Usage

### Starting Hybrid Mode

When you run Lisa in ML mode with an existing codebase, you'll be prompted:

```bash
./lisa-start.sh --mode=ml
```

Lisa will detect your codebase and offer Hybrid Mode:

```
╔════════════════════════════════════════════╗
║      Hybrid ML→Code Mode Available        ║
╚════════════════════════════════════════════╝

📦 Codebase detected!

I can run in Hybrid Mode to automatically:
  1. Find the best ML model (ML mode)
  2. Integrate it into your codebase (Code mode)

Use Hybrid ML→Code mode? [Y/n]:
```

### Configuration

You'll specify iterations for each phase:

```
Phase 1 - ML Optimization:
  How many ML experiments to run?
  ML iterations [20]: 30

Phase 2 - Code Integration:
  How many coding iterations for implementation?
  Code iterations [50]: 100
```

### Direct Invocation

You can also call hybrid mode directly:

```bash
# Full hybrid flow
./scripts/lisa-hybrid.sh --ml-iterations 30 --code-iterations 100

# Only generate PRD from existing ML results
./scripts/lisa-hybrid.sh --skip-ml --skip-code

# Run ML phase only
./scripts/lisa-hybrid.sh --ml-iterations 25 --skip-code
```

## Generated Files

### BEST_MODEL.json

Contains complete information about the best model found:

```json
{
  "status": "ready_for_integration",
  "run_id": "abc123...",
  "model_type": "lightgbm",
  "task_type": "classification",
  "metrics": {
    "primary_metric": "f1_score",
    "primary_value": 0.9123,
    "train_score": 0.9234,
    "val_score": 0.9123
  },
  "hyperparameters": {
    "n_estimators": 200,
    "max_depth": 8,
    "learning_rate": 0.05
  },
  "paths": {
    "model_artifact": "runs:/abc123.../model",
    "mlflow_ui": "http://127.0.0.1:5000/..."
  }
}
```

### PRD.md (Code Phase)

Auto-generated implementation plan with specific tasks:

```markdown
# PRD: ML Model Integration

## Overview
Integration of lightgbm classifier into Flask API

## Best Model Details
- Model: lightgbm
- F1-Score: 0.9123
- Run ID: abc123...

## Implementation Tasks

### Task 1: Load Model from MLflow
File: app/models/ml_predictor.py
- Import MLflow client
- Load model using run ID
- Cache in memory

### Task 2: Create Inference Module
File: app/models/inference.py
- Prediction function
- Preprocessing pipeline
- Error handling

### Task 3: Add API Endpoint
File: app/routes/api.py
- POST /api/predict endpoint
- Input validation
- Response formatting

...
```

## Codebase Detection

Hybrid mode is offered when Lisa detects these indicators:

- `src/` or `app/` directories
- `main.py`, `app.py`, `index.js`, `server.js` files
- `package.json` file

## Requirements

1. **ML Configuration**: `lisa_config.yaml` must exist
2. **Claude CLI**: Must be available for PRD generation
3. **Existing Codebase**: Code files to integrate model into

## Exit Codes

- `0`: Success - Full integration complete
- `1`: Partial - Some tasks remain
- `10`: ML target achieved (ML phase only)
- Other: Error occurred

## Scripts

### write-best-model-info.sh
Extracts best model from MLflow and creates `BEST_MODEL.json`

```bash
./scripts/write-best-model-info.sh
```

### generate-implementation-prd.sh
Analyzes codebase and generates implementation PRD

```bash
./scripts/generate-implementation-prd.sh
```

### lisa-hybrid.sh
Main orchestrator for the full ML→Code flow

```bash
./scripts/lisa-hybrid.sh --ml-iterations N --code-iterations N
```

## Example Session

```bash
$ ./lisa-start.sh --mode=ml

🤖 LISA - Learning Intelligent Software Agent
Mode: ml

╔════════════════════════════════════════════╗
║      Hybrid ML→Code Mode Available        ║
╚════════════════════════════════════════════╝

📦 Codebase detected!
Use Hybrid ML→Code mode? [Y/n]: y

🔬 Configuring Hybrid Mode

Phase 1 - ML Optimization:
  ML iterations [20]: 30

Phase 2 - Code Integration:
  Code iterations [50]: 100

═══════════════════════════════════════════
Hybrid Mode Summary:
  • ML Experiments: 30
  • Code Iterations: 100
  • Total Phases: 4 (ML → Extract → PRD → Code)
═══════════════════════════════════════════

🚀 Starting Hybrid ML→Code Mode...

═══════════════════════════════════════════
Phase 1: ML Optimization
═══════════════════════════════════════════

Running ML experiments...

Experiment 1/30: baseline_random_forest
  F1-Score: 0.7234

Experiment 15/30: lightgbm_optimized
  F1-Score: 0.9123 ✓ NEW BEST

✓ Target metric achieved!

═══════════════════════════════════════════
Phase 2: Model Information Extraction
═══════════════════════════════════════════

✓ Best model info written to lisa/BEST_MODEL.json
  Model: lightgbm
  F1-Score: 0.9123

═══════════════════════════════════════════
Phase 3: Implementation PRD Generation
═══════════════════════════════════════════

Analyzing codebase structure...
  Found: app.py, models/predictor.py, api/routes.py

✓ Implementation PRD generated

═══════════════════════════════════════════
Phase 4: Code Integration
═══════════════════════════════════════════

Running Code mode integration...

Iteration 1/100:
  ✓ Created models/ml_inference.py
  ✓ Loaded model from MLflow

Iteration 3/100:
  ✓ Integration complete
  <promise>COMPLETE</promise>

═══════════════════════════════════════════
╔════════════════════════════════════════════╗
║          Hybrid Mode Complete               ║
╚════════════════════════════════════════════╝

✓ Success: Model Integration Complete

Summary:
  ✓ ML Phase: Best model found (lightgbm | f1_score=0.9123)
  ✓ Code Phase: Integration implemented

Next steps:
  1. Review integrated code
  2. Run tests to verify functionality
  3. Test with real data
  4. Deploy if ready

Files generated:
  • Model info: lisa/BEST_MODEL.json
  • Implementation PRD: lisa/PRD.md
  • Progress log: lisa/progress.txt
  • ML diary: lisa/lisas_diary/
```

## Troubleshooting

### ML Phase Fails
- Check `lisa_config.yaml` exists and is valid
- Review ML logs in `lisa/logs/`
- Check data paths in configuration

### No Experiments Found
- Ensure ML mode ran at least once
- Check `lisa/mlruns/` directory exists
- Review MLflow tracking URI

### PRD Generation Fails
- Verify Claude CLI is installed and configured
- Check `BEST_MODEL.json` exists
- Ensure codebase is readable

### Code Integration Incomplete
- Review `lisa/PRD.md` for remaining tasks
- Check `lisa/progress.txt` for what was completed
- Run Code mode again: `./scripts/lisa-once.sh`

## Benefits

1. **Fully Automatic**: No manual steps between ML and Code phases
2. **Context Aware**: Analyzes your actual codebase structure
3. **Specific Tasks**: Generates actionable, file-specific integration tasks
4. **Reproducible**: Tracks model run IDs for exact reproduction
5. **Flexible**: Separate iteration controls for each phase

## Technical Details

### Mode Detection
The system detects mode by presence/absence of `lisa_config.yaml`:
- Present → ML mode (uses ML prompts)
- Absent → Code mode (uses Code prompts)

### Transition Mechanism
1. ML mode runs with config present
2. Config temporarily hidden for Code mode
3. PRD replaces ML instructions
4. Code mode sees PRD and implements tasks

### Environment Variables
- `LISA_HYBRID_MODE=true`: Signals hybrid flow
- `LISA_ML_MAX_ITERATIONS=N`: ML iteration limit
- `LISA_CODE_MAX_ITERATIONS=N`: Code iteration limit
- `LISA_FROM_HYBRID=true`: Code mode knows it's from hybrid

## Architecture

```
lisa-start.sh
    ↓
    Detects codebase + ML mode
    ↓
    Offers Hybrid Mode
    ↓
lisa-hybrid.sh
    ↓
    ├─→ lisa-afk.sh (ML mode)
    │       ↓
    │   Exit code 10 or 0
    │
    ├─→ write-best-model-info.sh
    │       ↓
    │   BEST_MODEL.json created
    │
    ├─→ generate-implementation-prd.sh
    │       ↓
    │   Calls Claude with prompt
    │       ↓
    │   PRD.md generated
    │
    └─→ lisa-afk.sh (Code mode)
            ↓
        Integration complete
```

## Future Enhancements

Potential improvements:
- Support for multiple models (ensemble integration)
- A/B testing setup generation
- Model monitoring/drift detection setup
- Automated deployment pipeline creation
- Model versioning and rollback support

## Related Documentation

- [ML Mode Guide](ML_MODE.md)
- [Code Mode Guide](CODE_MODE.md)
- [Configuration Reference](CONFIGURATION.md)
- [MLflow Integration](MLFLOW.md)
