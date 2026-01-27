#!/bin/bash
# ralph-review-file.sh - Review specific files

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Work in project root for file operations
cd "$PROJECT_ROOT"

# Set up logging environment
export LISA_LOG_DIR="$SCRIPT_DIR/logs"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1> [file2] [file3] ..."
    echo ""
    echo "Examples:"
    echo "  $0 src/main.js"
    echo "  $0 *.sh"
    echo "  $0 src/*.js"
    exit 1
fi

# Source the ralph library for logging and LISA_MODEL
if [[ -f "$SCRIPT_DIR/ralph-lib.sh" ]]; then
    source "$SCRIPT_DIR/ralph-lib.sh"
    lisa_info "Starting code review for specific files..."
fi

# Build file list
file_refs=""
file_count=0
for file in "$@"; do
    if [[ -f "$file" ]]; then
        file_refs="$file_refs @$file"
        file_count=$((file_count + 1))
        echo "  - $file"
    else
        echo "Warning: File not found: $file"
    fi
done

if [[ $file_count -eq 0 ]]; then
    echo "No valid files provided."
    exit 1
fi

echo ""
echo "Reviewing $file_count file(s)..."
echo ""

# Run Claude code review
claude --model "$LISA_MODEL" --dangerously-skip-permissions "$file_refs

You are an expert code reviewer. Review these files for:

1. **Code Quality**: Best practices, readability, maintainability
2. **Bugs & Issues**: Logic errors, edge cases, potential failures
3. **Security**: Vulnerabilities, unsafe patterns, input validation
4. **Performance**: Inefficiencies, optimization opportunities
5. **Documentation**: Comments, function docs, clarity

For each issue found:
- Specify the file path and line number
- Explain the issue clearly
- Suggest a specific fix or improvement
- Rate severity: CRITICAL, HIGH, MEDIUM, LOW

Format your response as:
## Summary
[Brief overview of code quality]

## Issues Found
### [Severity] - [File:Line]
**Issue**: [Description]
**Fix**: [Suggestion]

## Recommendations
[General improvements]
"
