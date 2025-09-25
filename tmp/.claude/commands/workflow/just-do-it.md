---
name: just-do-it
type: command
description: Complete automated workflow from bug diagnosis to merged PR
requires:
  - ../../commands.md
---

# /workflow:just-do-it Command

## Overview

The `/workflow:just-do-it` command executes a complete automated workflow from bug diagnosis to PR approval by running these commands in sequence:

1. `/bug:diagnose` - Analyzes and diagnoses the bug (see [Bug Diagnose Command](../../commands/bug/diagnose.md))
2. `/bug:fix` - Implements the fix based on diagnosis (see [Bug Fix Command](../../commands/bug/fix.md))
3. `/pr:create` - Creates a pull request with the fix (see [PR Create Command](../../commands/pr/create.md))
4. `/pr:review-feedback-loop` - Handles all review feedback until approved (see [PR Review Feedback Loop](../../commands/pr/review-feedback-loop.md))

## Usage

```
/workflow:just-do-it

[Provide bug description or issue details]
```

## Important Notes

- **ALL tests must pass** - No exceptions for pre-existing failures
- **Fully automated** - Runs until PR is approved or explicitly stopped
- **Time required** - May take 30-60+ minutes for complex issues

## Exit Conditions

### Success

- All phases complete successfully
- PR approved and ready to merge

### Failure

- User stops the process
- Maximum iterations reached
- Unrecoverable error

For detailed information about each phase, refer to the individual command documentation linked above.

```

```
