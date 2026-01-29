#!/bin/bash
# lisa-review-diff.sh - Review git diff changes

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Work in project root for git operations
cd "$PROJECT_ROOT"

# Set up logging environment
export LISA_LOG_DIR="$SCRIPT_DIR/logs"

# Source the lisa library for logging
if [[ -f "$SCRIPT_DIR/lisa-lib.sh" ]]; then
    source "$SCRIPT_DIR/lisa-lib.sh"
    lisa_info "Starting code review of git changes..."
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get diff type from argument (default: unstaged)
DIFF_TYPE="${1:-unstaged}"

case "$DIFF_TYPE" in
    unstaged)
        DIFF=$(git diff)
        DESCRIPTION="unstaged changes"
        ;;
    staged)
        DIFF=$(git diff --cached)
        DESCRIPTION="staged changes"
        ;;
    all)
        DIFF=$(git diff HEAD)
        DESCRIPTION="all uncommitted changes"
        ;;
    *)
        echo "Usage: $0 [unstaged|staged|all]"
        echo ""
        echo "Options:"
        echo "  unstaged  - Review unstaged changes (default)"
        echo "  staged    - Review staged changes"
        echo "  all       - Review all uncommitted changes"
        exit 1
        ;;
esac

if [[ -z "$DIFF" ]]; then
    echo "No $DESCRIPTION to review."
    exit 0
fi

echo "Reviewing $DESCRIPTION..."
echo ""

# Show diff stats
git diff --stat $(if [[ "$DIFF_TYPE" == "staged" ]]; then echo "--cached"; fi)
echo ""

# Run Claude code review on the diff
claude --model "$LISA_MODEL" --dangerously-skip-permissions "
Here is a git diff showing code changes:

\`\`\`diff
$DIFF
\`\`\`

You are an expert code reviewer. Review these changes for:

1. **Code Quality**: Best practices, readability, maintainability
2. **Bugs & Issues**: Logic errors, edge cases, potential failures introduced
3. **Security**: New vulnerabilities, unsafe patterns
4. **Performance**: Inefficiencies, regression risks
5. **Testing**: Are tests needed for these changes?

For each issue found:
- Reference the file and approximate line
- Explain the issue clearly
- Suggest a specific fix or improvement
- Rate severity: CRITICAL, HIGH, MEDIUM, LOW

Format your response as:
## Summary
[Brief overview of changes and quality]

## Issues Found
### [Severity] - [File]
**Issue**: [Description]
**Fix**: [Suggestion]

## Testing Recommendations
[What tests should be added]

## Overall Assessment
[Approve/Request Changes/Comment]
"
