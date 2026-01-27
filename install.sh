#!/bin/bash
set -e

LISA_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${1:-./lisa}"

echo "📦 Installing Lisa to $INSTALL_DIR..."
echo ""

# Create lisa directory
mkdir -p "$INSTALL_DIR"

# Copy main entry points
echo "Copying main scripts..."
cp "$LISA_DIR/lisa-start.sh" "$INSTALL_DIR/"
cp "$LISA_DIR/setup.sh" "$INSTALL_DIR/"

# Copy scripts directory
echo "Copying scripts directory..."
mkdir -p "$INSTALL_DIR/scripts"
cp "$LISA_DIR/scripts/"*.sh "$INSTALL_DIR/scripts/"

# Copy guidelines if exists
if [[ -f "$LISA_DIR/GUIDELINES.md" ]]; then
    echo "Copying guidelines..."
    cp "$LISA_DIR/GUIDELINES.md" "$INSTALL_DIR/"
fi

# Copy prompts directory (AI prompt templates)
if [[ -d "$LISA_DIR/prompts" ]]; then
    echo "Copying prompts..."
    cp -r "$LISA_DIR/prompts" "$INSTALL_DIR/"
fi

# Copy templates directory (code templates)
if [[ -d "$LISA_DIR/templates" ]]; then
    echo "Copying templates..."
    cp -r "$LISA_DIR/templates" "$INSTALL_DIR/"
fi

# Copy Python modules for ML mode
if [[ -d "$LISA_DIR/lisa" ]]; then
    echo "Copying Python ML modules..."
    mkdir -p "$INSTALL_DIR/python"
    cp -r "$LISA_DIR/lisa" "$INSTALL_DIR/python/"
fi

# Copy Python requirements
if [[ -f "$LISA_DIR/requirements-lisa.txt" ]]; then
    echo "Copying Python requirements..."
    cp "$LISA_DIR/requirements-lisa.txt" "$INSTALL_DIR/"
fi

# Copy default config template
if [[ -f "$LISA_DIR/lisa_config.yaml" ]]; then
    echo "Copying config template..."
    cp "$LISA_DIR/lisa_config.yaml" "$INSTALL_DIR/lisa_config.yaml.template"
fi

# Make all scripts executable
echo "Making scripts executable..."
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# Create initial files if they don't exist
if [[ ! -f "$INSTALL_DIR/PRD.md" ]]; then
    touch "$INSTALL_DIR/PRD.md"
fi
if [[ ! -f "$INSTALL_DIR/progress.txt" ]]; then
    touch "$INSTALL_DIR/progress.txt"
fi

# Create logs directory
mkdir -p "$INSTALL_DIR/logs"

# Create ML directories
echo "Creating ML directory structure..."
mkdir -p "$INSTALL_DIR/lisas_diary"
mkdir -p "$INSTALL_DIR/lisas_laboratory/models"
mkdir -p "$INSTALL_DIR/lisas_laboratory/plots/eda"
mkdir -p "$INSTALL_DIR/lisas_laboratory/plots/training"
mkdir -p "$INSTALL_DIR/lisas_laboratory/plots/evaluation"
mkdir -p "$INSTALL_DIR/lisas_laboratory/experiments"
mkdir -p "$INSTALL_DIR/lisas_laboratory/artifacts"
mkdir -p "$INSTALL_DIR/mlruns"

# Create .gitignore for Lisa directory
cat > "$INSTALL_DIR/.gitignore" <<'EOF'
# Lisa temporary files
review-results.txt
fix-results.txt
prd-review.txt
.lisa-status.json
.lisa-state.json
lisa-summary.txt
progress-archive.txt

# Log files
logs/
*.log

# Python
.venv-lisa-ml/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python

# ML artifacts
mlruns/
lisas_laboratory/models/
lisas_laboratory/artifacts/
*.pkl
*.h5
*.pt
*.pth

# Backup files
*.bak
*~
EOF

# Add lisa/ and context/ to repository's .gitignore if not already present
echo "Checking repository .gitignore..."
REPO_ROOT="$(cd "$INSTALL_DIR/.." && pwd)"
REPO_GITIGNORE="$REPO_ROOT/.gitignore"

# Determine the relative path entry to add
LISA_BASENAME="$(basename "$INSTALL_DIR")"

if [[ -f "$REPO_GITIGNORE" ]]; then
    # Check if lisa/ is already in .gitignore (with or without trailing slash)
    if grep -q "^${LISA_BASENAME}/\?$" "$REPO_GITIGNORE" 2>/dev/null; then
        echo "✓ $LISA_BASENAME/ already in repository .gitignore"
    else
        echo "Adding $LISA_BASENAME/ to repository .gitignore..."
        echo "" >> "$REPO_GITIGNORE"
        echo "# Lisa AI assistant directory" >> "$REPO_GITIGNORE"
        echo "$LISA_BASENAME/" >> "$REPO_GITIGNORE"
        echo "✓ Added $LISA_BASENAME/ to repository .gitignore"
    fi

    # Check if context/ is already in .gitignore
    if grep -q "^context/\?$" "$REPO_GITIGNORE" 2>/dev/null; then
        echo "✓ context/ already in repository .gitignore"
    else
        echo "Adding context/ to repository .gitignore..."
        echo "" >> "$REPO_GITIGNORE"
        echo "# Generated context documentation (regenerate with lisa-prestart)" >> "$REPO_GITIGNORE"
        echo "context/" >> "$REPO_GITIGNORE"
        echo "✓ Added context/ to repository .gitignore"
    fi
else
    echo "Creating repository .gitignore with $LISA_BASENAME/ and context/..."
    cat > "$REPO_GITIGNORE" <<EOF
# Lisa AI assistant directory
$LISA_BASENAME/

# Generated context documentation (regenerate with lisa-prestart)
context/
EOF
    echo "✓ Created repository .gitignore with $LISA_BASENAME/ and context/"
fi

echo ""
echo "✓ Lisa installed successfully to: $INSTALL_DIR"
echo ""
echo "📦 Main Scripts:"
echo "  ✓ lisa-start.sh       - Interactive setup & full workflow"
echo "  ✓ setup.sh             - System setup (adds to PATH)"
echo ""
echo "📂 Scripts Directory (scripts/):"
echo "  ✓ lisa-prestart.sh    - Generate context documentation"
echo "  ✓ lisa-once.sh        - Run single task"
echo "  ✓ lisa-afk.sh         - Run multiple iterations"
echo "  ✓ lisa-monitor.sh     - Oversight monitoring"
echo "  ✓ lisa-lib.sh         - Shared utility library"
echo "  ✓ lisa-review*.sh     - Code review scripts"
echo ""
echo "📁 Additional Directories:"
if [[ -d "$INSTALL_DIR/prompts" ]]; then
    echo "  ✓ prompts/             - AI prompt templates"
fi
if [[ -d "$INSTALL_DIR/templates" ]]; then
    echo "  ✓ templates/           - Code templates"
fi
if [[ -f "$INSTALL_DIR/GUIDELINES.md" ]]; then
    echo "  ✓ GUIDELINES.md        - Coding standards"
fi
echo "  ✓ PRD.md               - Product requirements"
echo "  ✓ progress.txt         - Progress tracking"
echo "  ✓ logs/                - Structured logs"
echo "  ✓ .gitignore           - Git ignore rules"
echo ""
echo "🚀 Quick Start:"
echo "  # From project root:"
echo "  $INSTALL_DIR/lisa-start.sh"
echo ""
echo "📚 Usage Examples (from project root):"
echo "  $INSTALL_DIR/scripts/lisa-prestart.sh             # Generate context documentation"
echo "  $INSTALL_DIR/lisa-start.sh                        # Full interactive workflow"
echo "  $INSTALL_DIR/scripts/lisa-once.sh                 # Single task execution"
echo "  $INSTALL_DIR/scripts/lisa-afk.sh 10               # Run 10 iterations"
echo "  $INSTALL_DIR/scripts/lisa-review.sh               # Quick code review"
echo "  $INSTALL_DIR/scripts/lisa-review-file.sh src/main.js  # Review specific file"
echo "  $INSTALL_DIR/scripts/lisa-review-and-fix.sh 5     # Review & fix with 5 iterations"
echo ""
echo "💡 Tip: Lisa works in your project root but keeps files in $INSTALL_DIR/"
echo "    All commands can be run from either location."
echo ""
