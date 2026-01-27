# Ralph AFK - Autonomous Task Execution

You are working autonomously on a project. The PRD (Product Requirements Document) and progress log have been provided to you.

## Instructions

**FIRST**: If a `context/CLAUDE.md` file exists in the project root, read it to understand the codebase architecture, business rules, and established patterns.

**YOUR TASK**: Complete ONE task from the PRD.

### Steps to follow:

1. **Read the PRD** - Find the highest-priority uncompleted task (look for unchecked `[ ]` items)
2. **Implement the task** - Write the code, create files, make changes as needed
3. **Test your work** - Run tests, type checks, linting (use `make test`, `ruff`, `pytest`, etc. as appropriate)
4. **Update the PRD** - Mark the task as complete `[x]` in the PRD file (lisa/PRD.md)
5. **Log your progress** - Append a summary of what you did to the progress file (lisa/progress.txt)

### Important notes:

- Work on ONLY ONE task per iteration
- The PRD file is located at: lisa/PRD.md
- The progress file is located at: lisa/progress.txt
- Check `context/` folder for architecture and business rules documentation
- Environment variables should be in secrets.env file

### Completion check:

If ALL tasks in the PRD are complete (all checkboxes marked `[x]` and success criteria met), output exactly:

<promise>COMPLETE</promise>

Otherwise, complete your task and the iteration will continue.
