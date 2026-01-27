# Lisa Coding Guidelines

This document defines coding standards and best practices for all code generated or modified by the Lisa automation system. Follow these guidelines strictly to ensure consistent, maintainable, and high-quality code.

---

## General Principles

### 1. Keep It Simple (KISS)
- Write the simplest solution that works
- Avoid over-engineering and premature optimization
- Don't add features that aren't explicitly requested

### 2. Don't Repeat Yourself (DRY)
- Extract repeated code into reusable functions
- Use variables for repeated values
- Reference shared code via sourcing or imports

### 3. Single Responsibility
- Each function should do one thing well
- Keep functions under 50 lines when possible
- Split complex functions into smaller, focused helpers

### 4. Fail Fast
- Validate inputs at function entry points
- Return early on error conditions
- Don't continue with invalid state

---

## Bash-Specific Guidelines

### Shebang and Headers
```bash
#!/bin/bash
# script-name.sh - Brief description of what this script does
# This script handles X, Y, and Z functionality
```

### Variable Naming
- Use `UPPER_SNAKE_CASE` for constants and environment variables
- Use `lower_snake_case` for local variables
- Prefix internal/private variables with underscore: `_internal_var`

```bash
# Good
readonly MAX_RETRIES=3
local file_path="$1"
local _temp_result=""

# Bad
readonly maxRetries=3
local FilePath="$1"
```

### Function Naming
- Use `lower_snake_case` for function names
- Prefix related functions with a common namespace
- Use descriptive verb-noun names

```bash
# Good
lisa_log_info() { ... }
parse_config_file() { ... }
validate_user_input() { ... }

# Bad
LogInfo() { ... }
pcf() { ... }
doStuff() { ... }
```

### Function Structure
```bash
# Function description (what it does, not how)
# Usage: function_name "arg1" "arg2"
# Arguments:
#   arg1 - Description of first argument
#   arg2 - Description of second argument (optional)
# Returns: 0 on success, 1 on failure
function_name() {
    local arg1="$1"
    local arg2="${2:-default_value}"

    # Validate inputs
    if [[ -z "$arg1" ]]; then
        echo "Error: arg1 is required" >&2
        return 1
    fi

    # Function body
    ...
}
```

### Quoting Rules
- Always quote variables: `"$variable"`
- Use `"${variable}"` when concatenating or in ambiguous contexts
- Quote command substitutions: `"$(command)"`

```bash
# Good
local path="$1"
local full_path="${base_dir}/${filename}"
local result="$(some_command "$arg")"

# Bad
local path=$1
local full_path=$base_dir/$filename
local result=$(some_command $arg)
```

### Conditionals
- Use `[[ ]]` instead of `[ ]` for tests
- Use `(( ))` for arithmetic comparisons
- Prefer `&&` and `||` over `-a` and `-o`

```bash
# Good
if [[ -n "$variable" ]] && [[ -f "$file" ]]; then
    ...
fi

if (( count > 10 )); then
    ...
fi

# Bad
if [ -n "$variable" -a -f "$file" ]; then
    ...
fi
```

### Error Handling
- Check return codes of critical commands
- Use `set -e` cautiously (prefer explicit checks)
- Log errors with context before returning

```bash
# Good
if ! some_command "$arg"; then
    lisa_error "Failed to run some_command with arg: $arg"
    return 1
fi

# Or using ||
some_command "$arg" || {
    lisa_error "Failed to run some_command with arg: $arg"
    return 1
}
```

### Command Substitution
- Prefer `$(command)` over backticks
- Store results in variables for reuse
- Handle empty results explicitly

```bash
# Good
local result
result=$(some_command)
if [[ -z "$result" ]]; then
    lisa_warn "Command returned empty result"
fi

# Bad
local result=`some_command`
```

### Arrays
- Use arrays for lists of items
- Quote array expansions properly
- Use `"${array[@]}"` to expand all elements

```bash
# Good
local -a files=("file1.txt" "file2.txt" "file3.txt")
for file in "${files[@]}"; do
    process_file "$file"
done

# Bad
local files="file1.txt file2.txt file3.txt"
for file in $files; do
    process_file $file
done
```

### Here Documents
- Use `<<'EOF'` to prevent variable expansion when appropriate
- Use `<<-EOF` for indented here-docs (with tabs)

```bash
# Variables NOT expanded
cat <<'EOF'
This $variable is literal
EOF

# Variables expanded
cat <<EOF
This $variable is expanded
EOF
```

---

## JavaScript/TypeScript Guidelines

### Naming Conventions
- Use `camelCase` for variables and functions
- Use `PascalCase` for classes and types
- Use `UPPER_SNAKE_CASE` for constants
- Prefix private members with underscore

```javascript
// Good
const maxRetries = 3;
const MAX_TIMEOUT_MS = 5000;

function processUserInput(input) { ... }
class UserManager { ... }

// Bad
const max_retries = 3;
function ProcessUserInput(input) { ... }
```

### Function Structure
- Keep functions focused and small (under 30 lines preferred)
- Use JSDoc comments for public functions
- Validate inputs at the start

```javascript
/**
 * Process the user input and return formatted result.
 * @param {string} input - The raw user input
 * @param {Object} options - Processing options
 * @returns {string} The formatted result
 * @throws {Error} If input is invalid
 */
function processUserInput(input, options = {}) {
    if (!input || typeof input !== 'string') {
        throw new Error('Input must be a non-empty string');
    }

    // Function body
    ...
}
```

### Error Handling
- Use try-catch for async operations
- Throw meaningful error messages
- Don't swallow errors silently

```javascript
// Good
try {
    const result = await fetchData(url);
    return result;
} catch (error) {
    console.error(`Failed to fetch data from ${url}:`, error.message);
    throw error;
}

// Bad
try {
    const result = await fetchData(url);
    return result;
} catch (error) {
    return null; // Silent failure
}
```

### Async/Await
- Prefer async/await over raw promises
- Handle all promise rejections
- Use Promise.all for parallel operations

```javascript
// Good
async function fetchAllData(urls) {
    const results = await Promise.all(
        urls.map(url => fetchData(url))
    );
    return results;
}

// Bad
function fetchAllData(urls) {
    return Promise.all(urls.map(url => fetchData(url)))
        .then(results => results);
}
```

---

## Python Guidelines

### Naming Conventions
- Use `snake_case` for variables, functions, and modules
- Use `PascalCase` for classes
- Use `UPPER_SNAKE_CASE` for constants
- Prefix private members with underscore

```python
# Good
MAX_RETRIES = 3
file_path = "/path/to/file"

def process_user_input(input_text):
    ...

class UserManager:
    def __init__(self):
        self._cache = {}

# Bad
maxRetries = 3
FilePath = "/path/to/file"
```

### Function Structure
- Use type hints for function signatures
- Include docstrings for public functions
- Keep functions focused (under 30 lines preferred)

```python
def process_user_input(input_text: str, options: dict = None) -> str:
    """
    Process the user input and return formatted result.

    Args:
        input_text: The raw user input
        options: Optional processing options

    Returns:
        The formatted result string

    Raises:
        ValueError: If input_text is empty
    """
    if not input_text:
        raise ValueError("input_text must be non-empty")

    options = options or {}
    # Function body
    ...
```

### Error Handling
- Use specific exception types
- Provide meaningful error messages
- Use context managers for resource cleanup

```python
# Good
try:
    with open(file_path, 'r') as f:
        data = f.read()
except FileNotFoundError:
    logger.error(f"File not found: {file_path}")
    raise
except PermissionError:
    logger.error(f"Permission denied: {file_path}")
    raise

# Bad
try:
    f = open(file_path, 'r')
    data = f.read()
    f.close()
except:
    pass
```

---

## Code Documentation

### When to Comment
- Explain WHY, not WHAT (code shows what)
- Document non-obvious behavior
- Note workarounds and their reasons
- Don't comment obvious code

```bash
# Good - explains why
# Use temp file because process substitution doesn't work with read in bash 3.x
local temp_file=$(mktemp)

# Bad - explains what (obvious from code)
# Increment counter by 1
counter=$((counter + 1))
```

### Function Documentation
- Document purpose, usage, arguments, and return values
- Include examples for complex functions
- Note any side effects

---

## Testing and Validation

### Before Completing Any Task
1. Verify syntax: `bash -n script.sh` for bash scripts
2. Run shellcheck: `shellcheck script.sh` (if available)
3. Test the specific functionality you changed
4. Verify integration with existing code

### Self-Review Checklist
- [ ] All variables are properly quoted
- [ ] Error conditions are handled
- [ ] Functions have appropriate documentation
- [ ] No hardcoded values that should be configurable
- [ ] Code follows existing patterns in the codebase
- [ ] No debug/test code left in place

---

## File Organization

### Script Structure
1. Shebang and file header
2. Configuration/constants
3. Source dependencies
4. Utility functions (internal)
5. Main functions (public API)
6. Main execution block (if applicable)

```bash
#!/bin/bash
# script.sh - Description

# ==============================================================================
# Configuration
# ==============================================================================
readonly CONFIG_FILE="${CONFIG_FILE:-config.conf}"

# ==============================================================================
# Dependencies
# ==============================================================================
source "$(dirname "$0")/lib.sh"

# ==============================================================================
# Internal Functions
# ==============================================================================
_helper_function() {
    ...
}

# ==============================================================================
# Public Functions
# ==============================================================================
main_function() {
    ...
}

# ==============================================================================
# Main
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_function "$@"
fi
```

---

## Integration Guidelines

### Working with Existing Code
- Match the style of surrounding code
- Use existing utility functions (from lisa-lib.sh)
- Don't refactor unrelated code
- Maintain backward compatibility

### Adding New Functions
- Add to appropriate section of the file
- Export new functions if they need to be used by other scripts
- Update any relevant documentation

---

## Summary Checklist

Before finalizing any code change:

1. **Syntax Valid**: Code passes syntax checks
2. **Style Consistent**: Follows existing patterns
3. **Well Documented**: Complex logic is explained
4. **Error Handled**: Failures are caught and logged
5. **Tested**: Functionality verified working
6. **Minimal**: No unnecessary changes or features
