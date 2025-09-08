---
description: Common patterns and principles for PR management and workflows
globs:
alwaysApply: true
---

# Common PR Patterns and Principles

## Core Principles

### MCP-First Approach

**ALWAYS use MCP (Model Context Protocol) tools first for GitHub operations!**

- MCP tools provide structured, parsed responses that are easier to process
- Only fallback to `gh` CLI when:
  - MCP response is too large (>100KB)
  - MCP tool fails or times out
  - Specific data not available via MCP
- The `gh` CLI is a backup option, not the primary method

## Repository Context Detection

### Automatic Repository Detection

```bash
# Get repository owner and name from git remote
REPO_URL=$(git remote get-url origin)
REPO_OWNER=$(echo $REPO_URL | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/')
REPO_NAME=$(echo $REPO_URL | sed -E 's/.*\/([^/]+)\.git/\1/')

# Or use gh CLI to get current repo context
REPO_INFO=$(gh repo view --json owner,name)
REPO_OWNER=$(echo $REPO_INFO | jq -r '.owner.login')
REPO_NAME=$(echo $REPO_INFO | jq -r '.name')
```

## PR Title Conventions

### Standard Format

`[$issueNumber] $type($domain): $JiraTitle`

### Type Options

- `fix`: Bug fixes
- `feat`: New features
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `test`: Test additions/changes
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `perf`: Performance improvements
- `hotfix`: Critical production fixes

### Examples

- `[WA-8664] fix(timesheet): Supervisor timesheet creation for different locations`
- `[WA-1234] feat(auth): Add SSO support for enterprise clients`

## Branch Naming Conventions

### Format

`{type}/{TICKET}-{domain}-{title_words_snakecase}`

### Regex Pattern

`^(ci|feat|fix|hotfix|perf|tune)/([a-zA-Z]+-\d+)-([^-]+)-.+$`

### Rules

- Use exact JIRA title words with special characters removed
- Convert to snake_case for multi-word titles
- Domain should match the area of code being modified

## PR Creation Best Practices

### Always Start as Draft

```javascript
mcp__github__create_pull_request with:
- draft: true  // ALWAYS start as draft
```

### Auto-Assignment

- Always automatically assign PR to the current user
- Create in draft mode unless explicitly told "ready for review"

### PR Description Template

Include:

1. **Summary**: Brief overview of changes
2. **Root Cause**: Why the change was needed
3. **Solution**: How the issue was addressed
4. **Files Modified**: List of changed files
5. **Verification Steps**: How to test the changes

## Comment Resolution Workflow

### Standard Resolution Flow

1. **Fix the Issue**: Make the necessary code changes
2. **Commit with Clear Message**: Reference the issue being fixed
3. **Push the Changes**: Push to the PR branch
4. **Reply to Comment**: Reply with "Fixed in commit [short SHA]: [brief explanation]"
5. **Mark as Resolved**: Use GraphQL API to mark the thread as resolved

### Reply Format

For fixed issues:

```
Fixed in commit [SHA]: [Brief explanation of what was changed]
```

Examples:

- "Fixed in commit abc123d: Moved constant to App::Constants as suggested"
- "Fixed in commit abc123d: Added test coverage for logger failure scenario"
- "Fixed in commit abc123d: Refactored to use hash lookup instead of case statement"

### Using MCP for Comments

```javascript
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "Fixed in commit [SHA]: [explanation]"
```

## Getting PR Information

### Use Native Commands When Available

```
/pr-comments
```

This retrieves all comments, review threads, and their current resolution status.

### MCP Tools for PR Status

```javascript
// Get PR reviews
mcp__github__get_pull_request_reviews with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]

// Get PR status checks
mcp__github__get_pull_request_status with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]
```

## Pre-PR Checklist

Before creating any PR:

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

## Timer Display for Waiting Periods

When implementing wait periods, always show an active countdown:

```bash
# Display active countdown timer
echo "⏱️ Waiting $WAIT_TIME seconds..."
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
printf "\r✅ Wait complete\n"
```

## GraphQL for Thread Resolution

### Get Thread ID

```bash
THREAD_ID=$(gh api graphql -f query='
{
  repository(owner: "[REPO_OWNER]", name: "[REPO_NAME]") {
    pullRequest(number: [PR_NUMBER]) {
      reviewThreads(first: 100) {
        nodes {
          id
          comments(first: 1) {
            nodes {
              id
            }
          }
        }
      }
    }
  }
}' | jq -r '.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[].id == "[COMMENT_ID]") | .id')
```

### Mark Thread as Resolved

```bash
gh api graphql -f query="
mutation {
  resolveReviewThread(input: {threadId: \"$THREAD_ID\"}) {
    thread {
      id
      isResolved
    }
  }
}"
```

## Important Reminders

- 🔀 **Always use MCP tools first**, fallback to CLI only when necessary
- 📝 **Start PRs as draft** unless explicitly told otherwise
- ✅ **Reply to each comment individually** with specific commit SHAs
- 🔄 **Mark threads as resolved** after replying
- ⏱️ **Show active timers** during wait periods
- 🎯 **Follow naming conventions** for branches and PR titles
