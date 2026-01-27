# Documentation Templates

This file provides documentation templates for consistent code documentation across the project.

---

## Bash Script Header Template

```bash
#!/usr/bin/env bash
# =============================================================================
# Script Name: script-name.sh
# Description: Brief description of what this script does
# Author: Your Name
# Created: YYYY-MM-DD
# Modified: YYYY-MM-DD
# Version: 1.0.0
# =============================================================================
#
# Usage:
#   ./script-name.sh [options] <required-arg> [optional-arg]
#
# Arguments:
#   required-arg    Description of required argument
#   optional-arg    Description of optional argument (default: value)
#
# Options:
#   -h, --help      Show this help message
#   -v, --verbose   Enable verbose output
#   -d, --debug     Enable debug mode
#
# Examples:
#   ./script-name.sh input.txt
#   ./script-name.sh -v input.txt output/
#   ./script-name.sh --debug input.txt output/ extra
#
# Exit Codes:
#   0   Success
#   1   General error
#   2   Invalid arguments
#   3   File not found
#
# Dependencies:
#   - bash 3.2+
#   - jq (optional, for JSON processing)
#
# =============================================================================
```

---

## Bash Function Documentation Template

```bash
# -----------------------------------------------------------------------------
# Function: function_name
# -----------------------------------------------------------------------------
# Description:
#   Brief description of what this function does.
#   Can span multiple lines for complex functions.
#
# Usage:
#   function_name <arg1> <arg2> [arg3]
#
# Arguments:
#   arg1    (required) Description of first argument
#   arg2    (required) Description of second argument
#   arg3    (optional) Description of third argument (default: "value")
#
# Returns:
#   0 - Success
#   1 - Invalid arguments
#   2 - File not found
#
# Output:
#   Writes result to stdout
#   Writes errors to stderr
#
# Example:
#   result=$(function_name "input" "output")
#   function_name "file.txt" "/tmp" "verbose"
#
# Notes:
#   - Any important notes about behavior
#   - Edge cases to be aware of
# -----------------------------------------------------------------------------
function_name() {
    # Implementation
}
```

---

## JavaScript/TypeScript Function Documentation (JSDoc)

```javascript
/**
 * Brief description of what this function does.
 *
 * Longer description if needed, explaining the function's purpose,
 * behavior, and any important details.
 *
 * @param {string} paramName - Description of the parameter
 * @param {number} [optionalParam=10] - Optional parameter with default
 * @param {Object} options - Configuration options
 * @param {boolean} options.verbose - Enable verbose logging
 * @param {string} options.format - Output format ('json' | 'text')
 * @returns {Promise<ResultType>} Description of return value
 * @throws {ValidationError} When input validation fails
 * @throws {NetworkError} When API request fails
 *
 * @example
 * // Basic usage
 * const result = await functionName('input', 5);
 *
 * @example
 * // With options
 * const result = await functionName('input', 5, {
 *   verbose: true,
 *   format: 'json'
 * });
 */
async function functionName(paramName, optionalParam = 10, options = {}) {
  // Implementation
}
```

---

## Python Function Documentation (Docstring)

```python
def function_name(param1: str, param2: int, optional_param: str = "default") -> dict:
    """
    Brief description of what this function does.

    Longer description if needed, explaining the function's purpose,
    behavior, and any important details. This can span multiple
    paragraphs if necessary.

    Args:
        param1: Description of the first parameter.
        param2: Description of the second parameter.
        optional_param: Description of optional parameter.
            Defaults to "default".

    Returns:
        A dictionary containing:
            - key1 (str): Description of key1
            - key2 (int): Description of key2
            - nested (dict): Nested structure with more data

    Raises:
        ValueError: If param1 is empty or param2 is negative.
        FileNotFoundError: If the specified file doesn't exist.
        RuntimeError: If processing fails unexpectedly.

    Example:
        >>> result = function_name("input", 42)
        >>> print(result["key1"])
        'processed_input'

        >>> result = function_name("data", 10, optional_param="custom")
        >>> print(result)
        {'key1': 'data', 'key2': 10}

    Note:
        Any important notes about the function's behavior,
        performance characteristics, or edge cases.
    """
    # Implementation
    pass
```

---

## Class Documentation Template (Python)

```python
class ClassName:
    """
    Brief description of the class purpose.

    Longer description explaining what this class represents,
    its responsibilities, and how it should be used.

    Attributes:
        attr1 (str): Description of attribute 1.
        attr2 (int): Description of attribute 2.
        _private_attr (list): Description of private attribute.

    Example:
        >>> obj = ClassName("value", 42)
        >>> obj.process()
        'result'

        >>> with ClassName("value", 42) as obj:
        ...     obj.do_something()
    """

    def __init__(self, param1: str, param2: int) -> None:
        """
        Initialize ClassName instance.

        Args:
            param1: Description of param1.
            param2: Description of param2.

        Raises:
            ValueError: If param1 is empty.
        """
        self.attr1 = param1
        self.attr2 = param2
        self._private_attr = []
```

---

## README Section Template

```markdown
## Feature Name

Brief description of the feature.

### Installation

```bash
# Installation commands
npm install package-name
```

### Usage

Basic usage example:

```javascript
const feature = require('package-name');
feature.doSomething();
```

### Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `option1` | `string` | `"default"` | Description of option1 |
| `option2` | `boolean` | `false` | Description of option2 |
| `option3` | `number` | `10` | Description of option3 |

### Examples

#### Example 1: Basic Usage

```javascript
// Code example
```

#### Example 2: Advanced Usage

```javascript
// Code example
```

### API Reference

#### `methodName(param1, param2)`

Description of the method.

**Parameters:**
- `param1` (string): Description
- `param2` (object): Description

**Returns:** Description of return value

**Throws:** Description of errors
```

---

## Changelog Entry Template

```markdown
## [1.2.0] - YYYY-MM-DD

### Added
- New feature X that allows users to do Y
- Support for Z file format

### Changed
- Improved performance of function A by 50%
- Updated dependency B to version 2.0

### Fixed
- Fixed bug where X would fail when Y was empty (#123)
- Corrected calculation in Z function

### Deprecated
- Method `oldMethod()` is deprecated, use `newMethod()` instead

### Removed
- Removed support for legacy format X

### Security
- Fixed vulnerability in authentication module (CVE-XXXX-XXXX)
```

---

## Inline Comment Guidelines

### When to Comment

```bash
# GOOD: Explain WHY, not WHAT
# Retry with backoff because the API has rate limiting
for i in {1..3}; do
    api_call && break
    sleep $((i * 2))
done

# BAD: Explains what code does (obvious from reading)
# Loop from 1 to 3
for i in {1..3}; do
```

### Comment Types

```bash
# TODO: Description of what needs to be done
# FIXME: Description of known issue that needs fixing
# HACK: Explanation of why this workaround is necessary
# NOTE: Important information for future developers
# OPTIMIZE: Potential optimization opportunity
# DEPRECATED: This code/feature will be removed in version X
```

### Section Separators

```bash
# =============================================================================
# MAJOR SECTION (file-level sections)
# =============================================================================

# -----------------------------------------------------------------------------
# Minor Section (function groups, logical blocks)
# -----------------------------------------------------------------------------

# --- Subsection (within a function) ---
```

---

## Error Message Template

```
Error: [ACTION] failed: [REASON]
  File: [FILE_PATH]
  Line: [LINE_NUMBER]
  Details: [ADDITIONAL_CONTEXT]

Suggestion: [HOW_TO_FIX]
```

Example:
```
Error: File read failed: Permission denied
  File: /etc/config/settings.conf
  Line: N/A
  Details: User 'app' does not have read permissions

Suggestion: Run 'chmod +r /etc/config/settings.conf' or run as root
```
