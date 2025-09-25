---
description: Reply to and hide already-resolved PR comments without running the full feedback loop
alwaysApply: true
requires:
  - ../../commands.md
---

# Reply and Hide Resolved Comments Command

## Overview

The `/reply-and-hide-resolved-comments` command handles only the comment resolution part of the PR
review process. It will:

1. **Scan all unresolved PR comments**
2. **For already-resolved issues**: Reply with confirmation and mark as resolved
3. **For unresolved issues**: Leave them untouched for manual handling
4. **Skip the main feedback loop** - this is comment cleanup only

## Usage

```
/reply-and-hide-resolved-comments
```

## Process

### Step 1: Identify Comment Status

```bash
# Use Claude's native command to get all PR comments
/pr:comments

# This will show all review threads, their resolution status, and comment details
# Focus on threads where isResolved == false
```

### Step 2: Analyze Each Comment

For each unresolved comment, determine:

1. **Already Fixed**: The code issue mentioned in the comment has been resolved in current code
2. **Still Valid**: The issue still exists and needs attention
3. **Outdated**: The comment is no longer relevant due to code changes

### Step 3: Handle Resolved Comments Only

**CRITICAL**: For detailed instructions on replying to and resolving comments, see the shared instructions in `pr/common.md`.

```bash
# For comments where the issue is already resolved:

# Reply confirming resolution
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "This issue has been resolved in the current code. [Brief explanation of how/when it was fixed]"

# Mark as resolved
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

### Step 4: Leave Unresolved Issues

For comments where the issue still exists:

- **Do not reply**
- **Do not mark as resolved**
- **Leave for manual handling or main feedback loop**

## Decision Logic

### When to Mark as Resolved

✅ **Mark as resolved if**:

- The specific code mentioned in the comment has been fixed
- The file/line referenced no longer has the issue
- The suggestion has been implemented
- The comment is about code that no longer exists (refactored away)
- The comment asks a question that has been answered through code changes

❌ **Do NOT mark as resolved if**:

- The issue still exists in the code
- The suggestion hasn't been implemented
- You're uncertain about the fix status
- The comment requires further discussion

### Example Scenarios

#### Scenario 1: Fixed Code Issue

```
Comment: "This method is too long and should be split"
Current State: Method has been refactored into smaller methods
Action: Reply "This has been resolved - the method was split into smaller functions in commit abc123" + Mark resolved
```

#### Scenario 2: Still Valid Issue

```
Comment: "This could cause a memory leak"
Current State: The potential memory leak still exists
Action: Leave untouched (don't reply, don't resolve)
```

#### Scenario 3: Outdated Comment

```
Comment: "Consider using async/await here"
Current State: This entire section was refactored to use a different approach
Action: Reply "This section was refactored in commit xyz789 and no longer uses promises" + Mark resolved
```

## Output Format

```
🔍 Reply and Hide Resolved Comments
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Using /pr:comments to scan unresolved comments...

✅ Resolved and hidden: [N] comments
   - [Comment 1]: Fixed code issue
   - [Comment 2]: Outdated due to refactor
   - [Comment 3]: Question answered by code

⏸️ Left untouched: [M] comments
   - [Comment A]: Issue still exists
   - [Comment B]: Needs manual review

📊 Summary: [N] resolved, [M] remaining active
```

## Best Practices

1. **Be Conservative**: When in doubt, don't mark as resolved
2. **Be Specific**: Explain exactly why/how the issue was resolved
3. **Reference Commits**: Include commit SHAs when mentioning fixes
4. **Check Thoroughly**: Verify the issue is actually resolved before marking
5. **Use for Cleanup**: This command is ideal for cleaning up after major refactors

## Integration with Main Loop

This command can be used:

- **Before starting the main feedback loop** to clean up old resolved comments
- **After major refactors** to hide comments that are no longer relevant
- **Independently** when you just need to clean up comment threads without running the full loop
