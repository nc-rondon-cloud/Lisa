# PRD Generation Prompt Template

This template is used by `lisa-start.sh` to generate the initial Product Requirements Document from a user's description.

## Template Variables

- `{{USER_DESCRIPTION}}` - The user's project description/idea

---

## Prompt

You are a technical product manager. Based on this brief description, create a detailed PRD (Product Requirements Document) in Markdown format.

**IMPORTANT: If a `context/CLAUDE.md` file exists in the project root, read it first to understand the codebase architecture, business rules, and general context. This will help you create a PRD that aligns with existing patterns and conventions.**

USER DESCRIPTION:
{{USER_DESCRIPTION}}

Create a PRD with:
1. **Project Overview** - Clear summary of what we're building
2. **Tech Stack** - Recommended technologies (keep it simple)
3. **Features** - Numbered list of features, ordered by priority
4. **Tasks** - Break each feature into small, implementable tasks with checkboxes [ ]
5. **Success Criteria** - How do we know it's done?
6. Tests should be written as the last task on the PRD. So after all coding is done, write the tests and iterate fixes if needed.

Keep tasks small and atomic (1-2 hours of work max each).

**IMPORTANT: Output the PRD content directly to stdout. DO NOT create any files or use any tools. The calling script will capture your output and save it to lisa/PRD.md automatically.**

Output ONLY the PRD markdown content, no explanations or commentary.
