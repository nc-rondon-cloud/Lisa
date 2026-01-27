# Lisa Scripts Reference

Complete documentation of all Lisa scripts, their purposes, and usage.

---

## Table of Contents

- [Main Entry Points](#main-entry-points)
- [Core Automation Scripts](#core-automation-scripts)
- [Review & Quality Scripts](#review--quality-scripts)
- [Utility Library](#utility-library)
- [AI Prompts](#ai-prompts)
- [Code Templates](#code-templates)
- [File Structure](#file-structure)

---

## Main Entry Points

Scripts in the root directory - your primary interfaces to Lisa.

### lisa-start.sh

**Purpose**: The complete Lisa workflow - interactive setup, PRD generation, implementation, review, fix, and validation.

**What it does**:
1. Prompts user for project description (text or editor)
2. Generates detailed PRD using Claude AI
3. Allows PRD review/editing/regeneration
4. Asks for execution mode (babysitting or AFK)
5. Launches implementation (lisa-once or lisa-afk + monitor)
6. Runs comprehensive code review (3 iteration max)
7. Auto-fixes issues found in review
8. Validates syntax (shellcheck, python, javascript)
9. Provides final summary and next steps

**Usage**:
```bash
./lisa-start.sh
# Interactive prompts guide you through the process
```

**When to use**: Starting a new project or feature from scratch. This is the recommended entry point for most users.

**Environment Variables**:
- `EDITOR` - Your preferred text editor (default: vim)
- `MAX_FIX_ITERATIONS` - Max review/fix cycles (default: 3)

---

### setup.sh

**Purpose**: System-level setup - adds Lisa to your PATH so you can run Lisa commands from anywhere.

**What it does**:
1. Makes all Lisa scripts executable
2. Adds Lisa directory to PATH in ~/.zshrc
3. Provides instructions for activation

**Usage**:
```bash
./setup.sh
# Then restart terminal or: source ~/.zshrc
```

**When to use**: First time using Lisa, or after moving Lisa to a new location.

---

### install.sh

**Purpose**: Install Lisa into another project directory.

**What it does**:
1. Copies Lisa scripts to target directory
2. Creates `scripts/`, `prompts/`, `templates/` folders
3. Sets up PRD.md, progress.txt, logs/
4. Creates .gitignore
5. Makes all scripts executable

**Usage**:
```bash
# Install to new project
cd your-project
/path/to/lisa/install.sh

# Install to specific subdirectory
/path/to/lisa/install.sh ./lisa
```

**When to use**: Setting up Lisa in a different project directory.

---

## Core Automation Scripts

Scripts in the `scripts/` directory that drive Lisa's automation.

### scripts/lisa-once.sh

**Purpose**: Execute exactly one task from the PRD (babysitting mode).

**What it does**:
1. Reads PRD.md and progress.txt
2. Finds the next incomplete task
3. Implements that one task
4. Updates progress.txt
5. Stops and waits for user

**Usage**:
```bash
./scripts/lisa-once.sh
```

**When to use**: When you want to review each task as Lisa completes it. Ideal for learning what Lisa does or maintaining tight control.

**Prompt Template**: `prompts/lisa-once-prompt.md`

---

### scripts/lisa-afk.sh

**Purpose**: Autonomous mode - execute multiple tasks without stopping (AFK = "Away From Keyboard").

**What it does**:
1. Takes iteration count as parameter
2. For each iteration:
   - Finds highest-priority incomplete task
   - Implements the task
   - Runs tests (if configured)
   - Updates PRD and progress.txt
3. Stops when complete or iteration limit reached

**Usage**:
```bash
./scripts/lisa-afk.sh 10    # Run 10 iterations
./scripts/lisa-afk.sh 50    # Run 50 iterations
```

**When to use**: When you want Lisa to work autonomously on multiple tasks. Great for running overnight or during meetings.

**Completion Signal**: Outputs `<promise>COMPLETE</promise>` when PRD is fully implemented.

**Prompt Template**: `prompts/lisa-afk-prompt.md`

---

### scripts/lisa-monitor.sh

**Purpose**: Continuous oversight loop that reviews progress every 10 minutes (runs in parallel with lisa-afk).

**What it does**:
1. Runs in background during AFK mode
2. Every 10 minutes:
   - Detects code changes (git diff)
   - Reviews implementation quality
   - Checks PRD alignment
   - Reads context/ folder (if exists)
   - Suggests PRD updates if needed
   - Automatically updates PRD when issues found
3. Classifies status: ON_TRACK | NEEDS_ATTENTION | CRITICAL_ISSUE
4. Logs all findings to `logs/lisa-monitor.log`

**Usage**:
```bash
# Automatic (started by lisa-start.sh in AFK mode)

# Manual
./scripts/lisa-monitor.sh &
MONITOR_PID=$!
# Stop later: kill $MONITOR_PID
```

**When to use**: Automatically launched by lisa-start.sh in AFK mode. Can be run manually for continuous oversight.

**Review Criteria**:
- PRD alignment
- Code quality (4 severity levels)
- Security vulnerabilities
- Performance issues
- Test coverage
- Documentation

**Prompt Template**: `prompts/monitor-review-prompt.md`

---

### scripts/lisa-lib.sh

**Purpose**: Shared utility library used by all Lisa scripts.

**What it provides**:
- **Logging**: Structured logging with levels (DEBUG, INFO, WARN, ERROR)
- **Timestamps**: ISO 8601 formatted timestamps
- **File Logging**: Daily logs, error logs, metrics logs
- **JSON Functions**: JSON escaping, array building
- **State Management**: Status tracking, progress management
- **Validation**: File checks, git status parsing
- **Output Filtering**: Claude output summarization
- **Template Loading**: Load and process prompt templates
- **Metrics**: Performance tracking, iteration counts

**Key Functions**:
- `lisa_log()` - Log with severity level
- `lisa_info()`, `lisa_warn()`, `lisa_error()` - Convenience logging
- `lisa_setup_logging()` - Initialize logging system
- `lisa_load_template()` - Load AI prompt templates
- `lisa_init_logs()` - Create log directory
- `lisa_json_escape()` - Escape strings for JSON
- `lisa_validate_file()` - Check file existence
- `lisa_get_git_status()` - Parse git status

**Usage**: Automatically sourced by other scripts.

**Size**: ~1700 lines of utilities.

---

## Review & Quality Scripts

Scripts in `scripts/` that handle code review and quality assurance.

### scripts/lisa-review.sh

**Purpose**: Quick review of all modified/staged files in the project.

**What it does**:
1. Detects modified, staged, and untracked files
2. Runs comprehensive code review on all changes
3. Checks against PRD requirements
4. Identifies bugs, security issues, performance problems
5. Outputs review with severity ratings

**Usage**:
```bash
./scripts/lisa-review.sh
```

**When to use**: Before committing changes, or to get a quick quality check on recent work.

**Review Categories**:
- PRD Completeness
- Code Quality
- Bugs & Issues
- Security
- Performance
- Testing
- Documentation

---

### scripts/lisa-review-file.sh

**Purpose**: Review specific files (not all changes).

**What it does**:
1. Takes file paths as arguments
2. Reviews only those specific files
3. Provides detailed feedback per file

**Usage**:
```bash
./scripts/lisa-review-file.sh src/main.js
./scripts/lisa-review-file.sh src/main.js src/utils.js
./scripts/lisa-review-file.sh src/**/*.js
```

**When to use**: When you want to review specific files without reviewing everything.

---

### scripts/lisa-review-diff.sh

**Purpose**: Review git changes (diff) before committing.

**What it does**:
1. Shows git diff (unstaged, staged, or all)
2. Reviews the changes in context
3. Catches issues before they're committed

**Usage**:
```bash
./scripts/lisa-review-diff.sh              # Unstaged changes
./scripts/lisa-review-diff.sh staged       # Staged changes
./scripts/lisa-review-diff.sh all          # All uncommitted
```

**When to use**: As a pre-commit check to catch issues before they enter version control.

---

### scripts/lisa-review-and-fix.sh

**Purpose**: The "magic loop" - review code, find issues, fix them automatically, review again.

**What it does**:
1. Runs code review
2. Finds issues
3. Automatically fixes issues using Claude
4. Reviews again to verify fixes
5. Repeats until clean (max iterations configurable)

**Usage**:
```bash
./scripts/lisa-review-and-fix.sh           # Default 3 iterations
./scripts/lisa-review-and-fix.sh 5         # 5 iterations max
```

**When to use**: When you want Lisa to not just find issues, but fix them automatically. Great for cleaning up code before a PR.

**Iteration Logic**:
- Iteration 1: Review → Fix
- Iteration 2: Review fixes → Fix remaining
- Iteration 3: Final review → Fix critical issues
- If still has issues after max iterations, manual review needed

---

### scripts/lisa-review-prd.sh

**Purpose**: Check if the implementation actually matches what the PRD requested.

**What it does**:
1. Reads PRD.md requirements
2. Reviews implementation
3. Checks completeness (are all tasks done?)
4. Verifies quality (are they done correctly?)
5. Offers to auto-fix any gaps

**Usage**:
```bash
./scripts/lisa-review-prd.sh
```

**When to use**: At the end of development to verify the PRD is fully implemented before delivery.

---

## Utility Library

### scripts/lisa-lib.sh Functions Reference

#### Logging Functions
```bash
lisa_log "LEVEL" "message"           # Core logging
lisa_debug "message"                 # Debug level
lisa_info "message"                  # Info level
lisa_warn "message"                  # Warning level
lisa_error "message"                 # Error level
lisa_setup_logging                   # Initialize logging system
lisa_init_logs                       # Create log directory
```

#### File Logging
```bash
lisa_log_to_file "filename" "msg"    # Log to specific file
lisa_log_daily "LEVEL" "message"     # Log to daily file
lisa_log_error_file "msg" "context"  # Log to error file
lisa_get_daily_log_path              # Get today's log path
```

#### Template Functions
```bash
lisa_load_template "name.md" "VAR=val"  # Load prompt template
lisa_load_template_safe "name" "fallback" "VAR=val"  # Load with fallback
lisa_list_templates                  # List available templates
```

#### JSON Functions
```bash
lisa_json_escape "string"            # Escape for JSON
lisa_json_array "item1,item2"        # Build JSON array
```

#### Utility Functions
```bash
lisa_timestamp                       # ISO 8601 UTC timestamp
lisa_timestamp_local                 # Local timestamp
lisa_date                            # YYYY-MM-DD format
lisa_validate_file "path"            # Check file exists
lisa_get_git_status                  # Parse git status
```

---

## AI Prompts

Templates in `prompts/` folder that define how Claude behaves.

### prompts/prd-generation-prompt.md

**Used by**: lisa-start.sh

**Purpose**: Transform user's brief description into detailed PRD.

**Variables**:
- `{{USER_DESCRIPTION}}` - User's project idea

**Output**: Markdown PRD with:
- Project Overview
- Tech Stack
- Features (prioritized)
- Tasks (atomic, with checkboxes)
- Success Criteria

---

### prompts/code-review-prompt.md

**Used by**: lisa-start.sh (Step 6)

**Purpose**: Comprehensive code review against PRD and quality standards.

**Variables**:
- `{{PRD_FILE}}` - Path to requirements
- `{{PROGRESS_FILE}}` - Path to progress log

**Output**: Structured review with:
- Summary
- Issues Found (by severity)
- Recommendations
- Special marker: `<promise>NO_ISSUES</promise>` if clean

---

### prompts/fix-prompt.md

**Used by**: lisa-start.sh (Step 6)

**Purpose**: Automatically fix issues found during code review.

**Variables**:
- `{{REVIEW_LOG}}` - Path to review results

**Output**: Fix summary with:
- Fixes Applied (file:line)
- Verification results
- Special marker: `<promise>FIXES_COMPLETE</promise>`

---

### prompts/lisa-once-prompt.md

**Used by**: scripts/lisa-once.sh

**Purpose**: Execute single task from PRD.

**Variables**:
- `{{PRD_FILE}}` - Path to requirements
- `{{PROGRESS_FILE}}` - Path to progress log

**Output**: Completed task + updated progress

---

### prompts/lisa-afk-prompt.md

**Used by**: scripts/lisa-afk.sh

**Purpose**: Autonomous multi-task execution.

**Variables**:
- `{{PRD_FILE}}` - Path to requirements
- `{{PROGRESS_FILE}}` - Path to progress log

**Output**: Task completion + special marker `<promise>COMPLETE</promise>` when done

---

### prompts/monitor-review-prompt.md

**Used by**: scripts/lisa-monitor.sh

**Purpose**: Oversight review every 10 minutes (222 lines - most comprehensive).

**Variables**:
- `{{PRD_FILE}}` - Path to requirements
- `{{PROGRESS_FILE}}` - Path to progress
- `{{CONTEXT_DIR}}` - Path to documentation
- `{{MODIFIED_FILES}}` - List of changed files
- `{{ITERATION}}` - Current monitor cycle

**Output**: Detailed oversight with:
- Status classification
- Recent activity analysis
- Issues by severity
- PRD alignment check
- Context compliance
- PRD adjustment recommendations
- Guidance for next iterations

---

### prompts/prd-update-prompt.md

**Used by**: scripts/lisa-monitor.sh

**Purpose**: Update PRD based on oversight findings.

**Variables**:
- `{{PRD_FILE}}` - Path to PRD
- `{{PROGRESS_FILE}}` - Path to progress
- `{{PRD_ADJUSTMENTS}}` - Recommended changes

**Output**: Surgically updated PRD (preserves completed work)

---

## Code Templates

Examples in `templates/` folder for reference.

### templates/bash-function.sh

**Purpose**: Example bash function templates with best practices.

**Contains**:
- Function documentation patterns
- Parameter handling
- Error handling
- Return values

---

### templates/documentation.md

**Purpose**: Documentation template examples.

**Contains**:
- README structures
- API documentation
- Code comments
- User guides

---

### templates/error-handling.sh

**Purpose**: Error handling patterns for bash scripts.

**Contains**:
- set -e usage
- trap handlers
- Error messages
- Exit codes
- Cleanup patterns

---

## File Structure

Complete Lisa directory layout:

```
lisa/
├── lisa-start.sh              # Main entry point
├── setup.sh                    # System setup
├── install.sh                  # Install to other projects
│
├── scripts/                    # Core automation
│   ├── lisa-once.sh           # Single task mode
│   ├── lisa-afk.sh            # Autonomous mode
│   ├── lisa-monitor.sh        # Oversight loop
│   ├── lisa-lib.sh            # Utility library
│   ├── lisa-review.sh         # Quick review
│   ├── lisa-review-file.sh    # Review specific files
│   ├── lisa-review-diff.sh    # Review git changes
│   ├── lisa-review-and-fix.sh # Auto review+fix loop
│   └── lisa-review-prd.sh     # PRD compliance check
│
├── prompts/                    # AI prompt templates
│   ├── prd-generation-prompt.md
│   ├── code-review-prompt.md
│   ├── fix-prompt.md
│   ├── lisa-once-prompt.md
│   ├── lisa-afk-prompt.md
│   ├── monitor-review-prompt.md
│   └── prd-update-prompt.md
│
├── templates/                  # Code templates
│   ├── bash-function.sh
│   ├── documentation.md
│   └── error-handling.sh
│
├── logs/                       # Generated logs
│   ├── lisa-YYYY-MM-DD.log    # Daily logs
│   ├── lisa-errors.log        # Error log
│   ├── lisa-metrics.log       # Metrics (JSON)
│   └── lisa-monitor.log       # Monitor output
│
├── PRD.md                      # Product requirements
├── progress.txt                # Implementation progress
├── GUIDELINES.md               # Coding standards
├── readme.md                   # Main documentation
├── lisa.md                    # This file
└── .gitignore                  # Git ignore rules
```

---

## Common Workflows

### Workflow 1: Start New Project
```bash
./lisa-start.sh
# 1. Describe project
# 2. Review/approve PRD
# 3. Choose AFK mode
# 4. Let Lisa work
# 5. Review results
```

### Workflow 2: Single Task at a Time
```bash
./scripts/lisa-once.sh  # Do task 1
# Review
./scripts/lisa-once.sh  # Do task 2
# Review
# Repeat...
```

### Workflow 3: Autonomous Development
```bash
./scripts/lisa-afk.sh 50
# Come back later
# Lisa completes 50 tasks or until PRD is done
```

### Workflow 4: Code Review Before PR
```bash
./scripts/lisa-review.sh                    # Quick review
./scripts/lisa-review-and-fix.sh 5          # Auto-fix issues
./scripts/lisa-review-prd.sh                # Verify PRD complete
git add . && git commit -m "feat: ..."       # Commit clean code
```

### Workflow 5: Monitor Long-Running Work
```bash
# Terminal 1
./scripts/lisa-afk.sh 100

# Terminal 2 (optional - monitor already runs in AFK mode)
tail -f logs/lisa-monitor.log
```

---

## Environment Variables

### Logging
```bash
export LISA_LOG_LEVEL=DEBUG              # DEBUG, INFO, WARN, ERROR
export LISA_LOG_DIR=./logs               # Log directory
export LISA_FILTER_OUTPUT=true           # Filter verbose output
```

### Templates
```bash
export LISA_TEMPLATES_DIR=prompts        # Prompt templates location
```

### Behavior
```bash
export LISA_PROGRESS_MAX_LINES=500       # Auto-summarize progress
export MAX_FIX_ITERATIONS=5               # Review/fix cycles
export EDITOR=vim                         # Preferred editor
```

---

## Exit Codes

Lisa scripts use standard exit codes:
- `0` - Success
- `1` - General error
- `2` - Usage error (wrong parameters)

---

## Special Markers

Lisa uses special markers in output to signal completion:

- `<promise>COMPLETE</promise>` - PRD fully implemented
- `<promise>NO_ISSUES</promise>` - Code review passed
- `<promise>FIXES_COMPLETE</promise>` - All fixes applied
- `NO_PRD_CHANGES_NEEDED` - Monitor found no PRD issues

---

## Tips & Best Practices

1. **Start with lisa-start.sh** - It's the recommended entry point
2. **Use context/ folder** - Add docs for monitor to reference
3. **Customize prompts** - Edit `prompts/*.md` for project needs
4. **Check logs** - `logs/` has detailed execution history
5. **Run setup.sh once** - Add Lisa to PATH for convenience
6. **Review early** - Use lisa-once.sh for first few tasks
7. **Trust AFK mode** - Once comfortable, let Lisa work autonomously
8. **Monitor watches** - In AFK mode, monitor keeps Lisa aligned
9. **Review before commits** - Use lisa-review-and-fix.sh
10. **Read lisa-lib.sh** - Great source of utility functions

---

## Troubleshooting

### Lisa isn't finding prompts
```bash
# Check LISA_TEMPLATES_DIR
echo $LISA_TEMPLATES_DIR
# Should be: prompts

# Verify prompts exist
ls -la prompts/
```

### Logging not working
```bash
# Check log directory
ls -la logs/

# If missing, initialize
mkdir -p logs

# Check lisa-lib.sh is sourced
grep lisa_setup_logging your-script.sh
```

### Scripts not executable
```bash
./setup.sh
# or
chmod +x *.sh scripts/*.sh
```

### Monitor not stopping
```bash
# Find monitor PID
ps aux | grep lisa-monitor

# Kill it
kill <PID>

# Or use PID file
cat .lisa-monitor.pid
kill $(cat .lisa-monitor.pid)
```

---

## Version Information

- **Lisa Version**: 2026 Edition
- **Features**: Auto-review, self-healing, parallel monitoring
- **Lines of Code**: ~10,000+ across all scripts
- **Templates**: 7 AI prompts + 3 code templates

---

## See Also

- `readme.md` - Main documentation
- `GUIDELINES.md` - Coding standards
- `prompts/` - Customizable AI prompts
- `templates/` - Code examples

---

*This reference was generated for Lisa Simpson, Senior Software Engineer.*

*"I'm making a difference!" - Lisa*
