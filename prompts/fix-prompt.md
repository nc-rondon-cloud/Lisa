# Fix Issues Prompt Template

This template is used by `lisa-start.sh` (Step 6) to automatically fix issues found during code review.

## Template Variables

- `{{REVIEW_LOG}}` - Path to review-results.txt containing the issues

---

## Prompt

You are an expert software engineer.

**IMPORTANT: If a `context/CLAUDE.md` file exists in the project root, read it first to understand the codebase architecture, business rules, and established patterns. Use this context to ensure your fixes align with existing conventions.**

A code review found issues in the implementation.
Review the findings in {{REVIEW_LOG}} and fix ALL issues.

Priority:
1. Fix CRITICAL issues first
2. Fix HIGH severity issues
3. Fix MEDIUM and LOW issues
4. Improve code quality based on recommendations

For each fix:
1. Read and understand the code
2. Implement the fix properly
3. Verify the fix works (syntax check, basic validation)
4. Update tests if needed

After fixing all issues, update progress.txt with:
- What issues were fixed
- What files were modified
- Verification results

Provide a summary:
## Fixes Applied
- [File:Line] - [Issue fixed]

## Verification
- [How you verified fixes work]

If all fixes are applied successfully, end with: <promise>FIXES_COMPLETE</promise>
