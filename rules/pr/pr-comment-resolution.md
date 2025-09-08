---
description: Shared instructions for replying to and resolving PR comments
alwaysApply: true
---

# PR Comment Resolution Instructions

## Overview

This document provides detailed instructions for replying to and resolving PR comments. These instructions are shared between multiple commands:

- `/pr:review-feedback-loop` (uses these instructions in Step 5)
- `/pr:reply-and-hide-resolved-comments` (uses these instructions throughout)

## Comment Resolution Workflow

### Getting PR Comments

**Use Claude's native command to fetch all PR comments:**

```
/pr:comments
```

This will retrieve all comments, review threads, and their current resolution status.

### When Addressing Review Comments

**Always follow this workflow when fixing issues raised in PR comments:**

1. **Fix the Issue**: Make the necessary code changes
2. **Commit with Clear Message**: Reference the issue being fixed
3. **Push the Changes**: Push to the PR branch
4. **Reply to Comment**: Reply with "Fixed in commit [short SHA]: [brief explanation]"
5. **Mark as Resolved**: Use GraphQL API to mark the thread as resolved

### Example Resolution Flow

```bash
# 1. After fixing an issue and pushing the commit
git add -A
git commit -m "[TICKET-ID] fix: Address review feedback about [issue]"
git push

# 2. Reply to the specific comment
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "Fixed in commit [SHA]: [explanation of what was changed]"

# 3. Get the thread ID for the comment
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

# 4. Mark the thread as resolved
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

## Comment Types and Responses

### A. Comments with Code Suggestions (Fixed)

For comments where code has been changed:

```bash
# Step 1: Reply to the comment with fix details
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "Fixed in commit [SHA]: [explanation of fix]"

# Step 2: Mark the comment thread as resolved
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "[THREAD_ID]"}) {
    thread {
      id
      isResolved
    }
  }
}'
```

### B. Comments Without Code Suggestions (General Feedback)

For general comments, questions, or suggestions without specific code changes:

```bash
# Reply acknowledging the comment
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "Acknowledged. [Provide response/explanation/agreement]"

# Must still mark as resolved to hide from active review
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "[THREAD_ID]"}) {
    thread {
      id
      isResolved
    }
  }
}'
```

### C. Outdated or Irrelevant Comments

For comments that are no longer applicable:

```bash
# Reply noting the comment status
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "This comment is now outdated/irrelevant due to [reason - e.g., code has been refactored, requirement changed, etc.]"

# Mark as resolved to hide from active review
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "[THREAD_ID]"}) {
    thread {
      id
      isResolved
    }
  }
}'
```

## Finding Thread IDs for Comments

**Note:** Use Claude's `/pr:comments` command to easily get all PR comments and their thread information.

If you need to manually query thread IDs:

```bash
# To find thread IDs for all comments needing resolution:
gh api graphql -f query='
{
  repository(owner: "[REPO_OWNER]", name: "[REPO_NAME]") {
    pullRequest(number: [PR_NUMBER]) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 3) {
            nodes {
              id
              body
              author {
                login
              }
            }
          }
        }
      }
    }
  }
}' | jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

## Response Patterns

### For Common Review Comments

#### "Consider extracting this logic into a separate method"

1. Create appropriate private method
2. Move logic with proper parameters
3. Add method documentation
4. Update tests if needed

#### "This could be simplified"

1. Refactor complex conditionals
2. Use appropriate Ruby idioms
3. Remove redundant code
4. Improve readability

#### "Missing test coverage"

1. Identify untested paths
2. Add comprehensive test cases
3. Include edge cases
4. Verify coverage metrics

#### "Potential N+1 query"

1. Add includes/preloading
2. Optimize database queries
3. Add query tests
4. Verify with query logs

## Resolution Requirements

**CRITICAL REQUIREMENT**: Before starting the next loop iteration (in main feedback loop), ALL comments that have been replied to must be marked as resolved using the "Hide" option. This includes:

1. **Fixed Issues**: Comments where code has been changed → Reply with fix details + Mark resolved
2. **General Comments**: Comments without code suggestions → Reply acknowledging + Mark resolved
3. **Outdated Comments**: Comments no longer relevant → Reply noting outdated status + Mark resolved

**No exceptions**: Every comment type must be addressed and hidden to maintain clean PR state.
