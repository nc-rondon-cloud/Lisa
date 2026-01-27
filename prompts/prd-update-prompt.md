# PRD Update Prompt Template

This template is used by `lisa-monitor.sh` to update the PRD based on oversight review findings.

## Template Variables

- `{{PRD_FILE}}` - Path to PRD.md
- `{{PROGRESS_FILE}}` - Path to progress.txt
- `{{PRD_ADJUSTMENTS}}` - The adjustment recommendations from the review

---

## Prompt

You are updating the PRD based on oversight review findings.

**IMPORTANT: If a `context/CLAUDE.md` file exists in the project root, read it first to understand the codebase architecture, business rules, and established patterns. Use this context to ensure PRD updates align with existing conventions.**

**Oversight Review Findings**:
{{PRD_ADJUSTMENTS}}

**Task**:
Update the PRD ({{PRD_FILE}}) to incorporate the suggested adjustments.
- Keep existing structure
- Add clarity where needed
- Add missing requirements
- Update tasks if necessary
- Preserve completed work

Make the changes surgically - don't rewrite the entire PRD, just adjust what needs adjusting.

**IMPORTANT: Output the complete updated PRD content directly to stdout. DO NOT create any files or use any tools. The calling script will capture your output and save it to lisa/PRD.md automatically.**
