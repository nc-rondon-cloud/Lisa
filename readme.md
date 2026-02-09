# LISA

Meet Lisa Simpson — Brilliant Data Scientist & Software Engineer, straight-A student, expert in analytical thinking and machine learning, and current holder of the world record for "most thorough documentation of every single experiment."

While real senior devs are busy:
- Writing 47-page design docs nobody reads
- Arguing about dependency injection in Slack
- Quietly pushing `console.log("works on my machine")` to production
- Demanding bonus and unlimited PTO

Lisa just **learns and iterates**.
Analyze → experiment → optimize → document → repeat.
No ego. No standups. No "let me circle back on that."
Just pure, methodical, unstoppable intelligence powered by Claude and elegant bash scripts.

This is **LISA (Learning Intelligent Software Agent)** — evolved from the original Ralph Loop, now with dual capabilities: general programming (Code mode) and autonomous data science (ML mode). She keeps sessions fresh, avoids context drift, and can even train ML models while you sleep. Because why pay a senior six figures when Lisa will do it for API credits and a gold star?

![Lisa Simpson, Data Scientist & Software Engineer](lisa.jpeg)

## Prerequisites

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured with an API key
- Bash shell (macOS/Linux)
- Python 3.8+ (for ML mode)

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/luisbebop/lisa.git

# 2. Run setup to add lisa to your PATH
cd lisa
./setup.sh

# 3. Go to the project where you want to use Lisa
cd /path/to/your-project

# 4. Install Lisa into your project
install.sh

# 5. Start Lisa
./lisa/lisa-start.sh
```

## What Happens

### Code Mode (General Programming)
When you run `./lisa/lisa-start.sh --mode=code`:
1. Lisa asks what you want to build
2. Generates a PRD (Product Requirements Document)
3. You approve, edit, or regenerate the PRD
4. Lisa implements all tasks autonomously:
   - **Babysitting mode**: You manually trigger each iteration
   - **AFK mode**: Lisa runs continuously until all PRD tasks are complete
5. Reviews the code for issues
6. Auto-fixes problems found during review

**Important**: Lisa works autonomously and makes technical decisions without asking. She uses existing codebase patterns and best practices to resolve any ambiguity.

### ML Mode (Data Science) - NEW!
When you run `./lisa/lisa-start.sh --mode=ml`:
1. Lisa reads your PRD with ML objectives and data specifications
2. Performs comprehensive exploratory data analysis (EDA)
3. Designs and runs experiments autonomously
4. Finds optimal hyperparameters via automated search
5. Trains and evaluates models
6. Generates visualizations and documentation
7. Stops automatically when optimal results are achieved
8. Documents everything in `lisas_diary/`

### Individual Scripts

| Script | Description |
|--------|-------------|
| `scripts/gen-prd.sh` | Generate a PRD from a description |
| `scripts/lisa-once.sh` | Execute a single task from the PRD |
| `scripts/lisa-afk.sh [max]` | Run autonomously until all PRD tasks complete (default max: 1000 iterations) |
| `scripts/lisa-review.sh` | Review all modified files |
| `scripts/lisa-review-file.sh <files>` | Review specific files |
| `scripts/lisa-review-diff.sh [staged\|all]` | Review git changes |
| `scripts/lisa-review-and-fix.sh [n]` | Review and auto-fix in a loop (default: 3 cycles) |
| `scripts/lisa-review-prd.sh` | Check implementation against PRD |
| `scripts/lisa-monitor.sh` | Oversight loop for AFK mode (runs every 10 min) |
| `scripts/lisa-experiment.sh` | ML: Run complete experiment cycle |
| `scripts/lisa-train.sh` | ML: Train model with monitoring |
| `scripts/lisa-evaluate.sh` | ML: Evaluate trained models |
| `scripts/lisa-visualize.sh` | ML: Generate visualizations |
| `scripts/lisa-reset.sh` | Reset Lisa to clean state (clear all artifacts) |

### Examples

**Run autonomously until all tasks complete (with safety limit of 100 iterations):**
```bash
./scripts/lisa-afk.sh 100
```

**Run with default safety limit (1000 iterations):**
```bash
./scripts/lisa-afk.sh
```

**Review and fix all issues:**
```bash
./scripts/lisa-review-and-fix.sh
```

**Review only staged changes:**
```bash
./scripts/lisa-review-diff.sh staged
```

**ML: Run autonomous experimentation:**
```bash
./scripts/lisa-afk.sh 20  # With lisa_config.yaml present
```

## Resetting Lisa

To start a fresh project or experiment without reinstalling:

```bash
# Interactive reset with confirmation
./scripts/lisa-reset.sh

# Create backup before reset
./scripts/lisa-reset.sh --backup

# Reset without confirmation (use with caution!)
./scripts/lisa-reset.sh --force

# Preview what will be deleted
./scripts/lisa-reset.sh --dry-run

# Keep ML configuration
./scripts/lisa-reset.sh --keep-config

# Keep context documentation
./scripts/lisa-reset.sh --keep-context

# Combine options
./scripts/lisa-reset.sh --backup --keep-config
```

**What gets cleared:**
- Project requirements (PRD.md) and progress logs
- All state and temporary files
- ML artifacts, experiments, and models
- MLflow tracking data
- All log files

**What gets preserved:**
- Lisa scripts, prompts, and templates
- Python ML modules
- Configuration templates
- Guidelines and documentation

After reset, Lisa is in a clean state as if `install.sh` had just been run.

## Key Files

### Code Mode
| File | Purpose |
|------|---------|
| `PRD.md` | Product requirements document (source of truth for tasks) |
| `progress.txt` | Tracks completed work and current state |
| `logs/` | JSON logs for metrics, errors, and monitor activity |
| `prompts/` | Customizable prompt templates for Claude interactions |
| `context/` | Optional folder for docs/specs the monitor reads |

### ML Mode (Additional)
| File/Directory | Purpose |
|----------------|---------|
| `lisa_config.yaml` | ML configuration (datasets, metrics, stopping criteria) |
| `lisas_diary/` | Markdown documentation of all ML decisions and insights |
| `lisas_laboratory/` | ML artifacts (models, plots, checkpoints) |
| `mlruns/` | MLflow experiment tracking |

## AFK Mode with Monitor

When running in AFK mode via `lisa-start.sh`, a monitor process runs in parallel:
- Checks progress every 10 minutes
- Validates implementation against PRD
- Adjusts PRD if requirements were unclear
- Logs findings to `logs/lisa-monitor.log`
- In ML mode: monitors training metrics and stopping criteria

To use additional context, create a `context/` folder with architecture docs, API specs, or examples.

## Configuration

**Environment variables:**
```bash
LISA_LOG_LEVEL=DEBUG|INFO|WARN|ERROR   # Log verbosity
LISA_FILTER_OUTPUT=true                 # Filter verbose output
LISA_PROGRESS_MAX_LINES=500             # Auto-summarize threshold
MAX_FIX_ITERATIONS=5                     # Review/fix cycle limit
```

**ML Mode Configuration:**

Create a `lisa_config.yaml` in your project root:
```yaml
project:
  name: "my-ml-project"

paths:
  data: "data/"
  diary: "lisa/lisas_diary"
  laboratory: "lisa/lisas_laboratory"

mlflow:
  tracking_uri: "file:./lisa/mlruns"
  experiment_name: "my-experiments"

stopping_criteria:
  performance:
    enabled: true
    metric: "f1_score"
    threshold: 0.95
  improvement:
    enabled: true
    min_improvement_percent: 1.0
    window_size: 5
  resources:
    max_experiments: 50
    max_time_hours: 24
```

**Customizing prompts:**

Edit templates in `prompts/` to customize Claude's behavior. Templates use `{{VARIABLE}}` syntax for substitution.

## ML Mode: How It Works

1. **EDA Phase**: Lisa discovers datasets, analyzes distributions, correlations, and quality issues
2. **Baseline**: Creates a simple baseline model to establish performance floor
3. **Experimentation**: Autonomously tries different models and hyperparameters
4. **Optimization**: Uses Optuna or similar for hyperparameter tuning
5. **Evaluation**: Generates comprehensive metrics and visualizations
6. **Documentation**: Every decision is documented with reasoning in `lisas_diary/`
7. **Stopping**: Automatically stops when criteria are met (performance threshold, convergence, resource limits)

Lisa integrates with MLflow for full experiment tracking and model versioning.

## Credits

Originally inspired by the Ralph Wiggum loop concept. Evolved into LISA with ML capabilities and systematic approach to both software engineering and data science.
