---
description: Comprehensive guide for creating pull requests with GitHub MCP
alwaysApply: true
requires:
  - ../../commands.md
---

# /create-pr - Pull Request Creation Command

## Overview

This command creates a pull request following all established conventions and best practices. It
uses the GitHub MCP ( Model Context Protocol) tools instead of CLI commands for better structured
responses.

## Command Usage

```
/create-pr
```

## Pre-PR Checklist

Before creating a PR, ensure:

1. **Tests Pass**: Run all relevant tests

   ```bash
   make spec T="path/to/spec.rb"
   ```

2. **Code Style**: Check code formatting

   ```bash
   make rubocop-git
   ```

3. **No Uncommitted Changes**: Verify working directory is clean
   ```bash
   git status
   ```

## PR Creation Process

### Step 1: Gather Information

- Current branch name
- Jira ticket number (if applicable)
- Changes made (via git diff/log)
- Base branch (usually `main`)

### Step 2: Create Draft PR

**ALWAYS use GitHub MCP tools, not CLI:**

1. **Get current user information first:**

```javascript
mcp__github__get_me
// This returns the current user's username and details
```

2. **Create the PR:**

```javascript
mcp__github__create_pull_request with:
- owner: <owner>
- repo: <repo>
- title: [Follow title convention]
- head: [current branch]
- base: main
- draft: true  // ALWAYS start as draft
- body: [Comprehensive description]
```

3. **Immediately assign PR to yourself:**

```javascript
mcp__github__update_pull_request with:
- owner: <owner>
- repo: <repo>
- pullNumber: [PR number from creation response]
- assignees: [current user's username from get_me]
```

### Step 3: Title Convention

See [PR title conventions](../common.md#pr-title-conventions) for the strict format, type options, and examples.

- `[WA-8994] fix(export): Export from People tab missing correct login data`
- `[WA-1234] feat(auth): Add two-factor authentication support`
- `[WA-5678] refactor(database): Optimize user query performance`

### Step 4: PR Description Template

```markdown
## Summary

Fixes [JIRA-ID] - [Brief description of the issue/feature]

## Issues Resolved

1. **[Main Issue]**: [Detailed description]
2. **[Secondary Issue]**: [If applicable]

## Root Cause Analysis

[For bug fixes, explain what caused the issue]

## Solution

[Describe the approach taken to solve the problem]

## Changes Made

### Files Modified:

- `path/to/file.rb` - [What changed and why]
- `config/locales/en.yml` & `config/locales/fr.yml` - [Translation updates]
- `spec/path/to/spec.rb` - [Test coverage added/modified]

### Database Changes (if applicable):

- **Migration**: [Description of schema changes]
- **Index Changes**: [New/modified indexes]

### API Changes (if applicable):

- **Endpoint**: [New/modified endpoints]
- **Request/Response**: [Format changes]

## Testing

- ✅ All existing tests pass
- ✅ New functionality tested
- ✅ Rubocop clean
- ✅ Manual verification completed
- ✅ Edge cases covered

## Verification Steps

1. [Step-by-step instructions to verify the fix]
2. [Include any debug scripts from tmp/WA-XXXX.rb]
3. [Expected results]

## QA Instructions

[Clear instructions for QA team to test the changes]

## Screenshots (if UI changes)

[Before/after screenshots if applicable]

## Performance Impact

[Any performance considerations or improvements]

## Deployment Notes

[Any special deployment considerations]

Resolves: [JIRA-ID]
```

### Step 5: Auto-assign and Request Reviews

1. **Auto-assign to current user** (MANDATORY):

- **ALWAYS** assign the PR to the current user immediately after creation
- Use the GitHub API to get the current user's username
- Assign the PR using the update PR endpoint

2. **Request Automated Review** (immediately after creation):

   ```javascript
   # Request automated PR review bot
   # This will trigger any configured automated review bots
   # Check with your team for the specific bot command/API
   ```

3. **Tag Human Reviewers** (when ready):

- Common reviewers: `@vadshalamov`, `@artod`

## Important Rules

### DO NOT:

- ❌ Commit during PR creation unless explicitly requested
- ❌ Use `gh` CLI commands - always use GitHub MCP
- ❌ Create PR as "ready for review" initially
- ❌ Skip test verification
- ❌ Merge without all checks passing

### ALWAYS:

- ✅ Create as DRAFT initially
- ✅ **Auto-assign PR to yourself immediately after creation**
- ✅ Match Jira ticket title exactly
- ✅ Include comprehensive description
- ✅ Request automated review immediately
- ✅ Reference debug scripts if created
- ✅ Verify all tests pass before marking ready
- ✅ Include both EN and FR translations when applicable

## Multiple PR Strategy

For critical fixes that need deployment to multiple branches:

### Create PR Against Main

```javascript
mcp__github__create_pull_request with:
- owner: <owner>
- repo: <repo>
- title: [title]
- head: [feature-branch]
- base: main
- draft: true
```

### Create PR Against Develop (if needed)

```javascript
mcp__github__create_pull_request with:
- owner: <owner>
- repo: <repo>
- title: [title]
- head: [feature-branch]
- base: develop
- draft: true
```

## Jira Integration

### Update Ticket Status

When PR is ready for review:

```javascript
mcp__atlassian__transitionJiraIssue with:
- cloudId: [from getAccessibleAtlassianResources]
- issueIdOrKey: "WA-1234"
- transition: {id: "Ready to PR review"}
```

### Add Jira Comment

```javascript
mcp__atlassian__addCommentToJiraIssue with:
- cloudId: [cloud-id]
- issueIdOrKey: "WA-1234"
- commentBody: "PR created: #[number] - [link]"
```

## Execution Flow Summary

When `/pr:create` is executed, the assistant MUST:

1. **Get current user**: Call `mcp__github__get_me` first
2. **Create draft PR**: Using `mcp__github__create_pull_request`
3. **Auto-assign to self**: Using `mcp__github__update_pull_request` with current user
4. **Request automated review**: Trigger review bots if configured
5. **Update Jira**: If applicable, transition ticket status

This ensures every PR is properly tracked and assigned.

## Post-PR Creation

### Monitor CI Status

```javascript
mcp__github__get_pull_request_status with:
- owner: <owner>
- repo: <repo>
- pullNumber: [PR_NUMBER]
```

### Address Review Feedback

See `/pr-review-feedback-loop` for automated feedback handling

### Mark Ready for Review

Only after:

- All CI checks pass
- Automated review addressed
- Tests verified
- Code style clean

## Common Issues

### Merge Conflicts

1. Pull latest from base branch
2. Resolve conflicts locally
3. Re-run tests
4. Push resolution

### Failed CI Checks

1. Check workflow logs
2. Fix issues locally
3. Verify with local tests
4. Push fixes

### Large PRs

- Consider breaking into smaller PRs
- Add clear section headers in description
- Provide review guidance

## Best Practices

1. **Atomic Commits**: Make focused, logical commits
2. **Clear Messages**: Write descriptive commit messages
3. **Test Coverage**: Include tests for all changes
4. **Documentation**: Update docs if behavior changes
5. **Performance**: Consider and document performance impact
6. **Security**: Review for security implications
7. **Backwards Compatibility**: Note any breaking changes

## Related Commands

- `/pr-review-feedback-loop` - Automated review feedback handling
- `/create-branch` - Create feature branches with proper naming
- `/run-tests` - Run test suites before PR creation

## Configuration

Default values can be overridden:

- `BASE_BRANCH`: Default base branch (default: `main`)
- `DRAFT_MODE`: Create as draft (default: `true`)
- `AUTO_ASSIGN`: Auto-assign creator (default: `true`)
- `REQUEST_AUTOMATED_REVIEW`: Request automated review (default: `true`)
