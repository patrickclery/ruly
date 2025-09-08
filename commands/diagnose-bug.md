---
description: Systematically diagnose bugs using the debugging workflow methodology
globs:
alwaysApply: true
---

# Diagnose Bug Command

## Command

`/diagnose-bug`

## Description

This command guides you through a systematic bug investigation process following the methodology in
[@rules/core/debugging/bug-workflow.md].

It will:

1. Analyze the issue (from Jira ticket if available)
2. Create and run debug scripts with proper naming conventions
3. Apply appropriate debugging patterns (Policy, Sequel, Supervisor relationships)
4. Identify and document the root cause
5. **STOP** once the bug is diagnosed (does NOT implement fixes)

## Process

When invoked, I will follow **Phase 1: Initial Investigation** from the bug workflow:

1. **Jira Ticket Analysis** (if ticket provided)
   - Fetch details using Atlassian MCP
   - Document reproduction steps
   - Identify affected components

2. **Create Debug Script**
   - Location: `debug/` folder
   - Naming: `WA-XXXX-NN-description.rb`
   - Run with: `make rails-r T=debug/WA-XXXX-NN-description.rb`

3. **Apply Debugging Patterns**
   - Policy debugging for authorization issues
   - Sequel patterns for database issues
   - Supervisor relationship debugging for hierarchy issues

4. **Stop at Diagnosis**
   - Present root cause analysis
   - Show problematic code location
   - No fix implementation

## Usage Examples

```
/diagnose-bug WA-1234
```

Fetches Jira ticket, creates debug scripts, diagnoses the issue.

```
/diagnose-bug Users are seeing incorrect permissions when accessing branch data
```

Creates debug scripts to investigate the described issue.

```
/diagnose-bug continue WA-1234
```

Creates additional numbered debug scripts (02, 03, etc.) for deeper investigation.

## Important Notes

- **Diagnosis only** - No fix implementation
- **References bug-workflow.md** - Full debugging methodology at
  [@rules/core/debugging/bug-workflow.md]
- **Debug scripts preserved** - All scripts remain in `debug/` folder
- **Database operations** - Require explicit confirmation before running

## After Diagnosis

Once diagnosed, use the debug scripts created to:

- Verify any fixes implemented
- Test related functionality
- Validate the root cause analysis
