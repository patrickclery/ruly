---
description: Automated PR review and feedback loop with GitHub Actions
alwaysApply: true
---

# PR Review Feedback Loop

## Overview

This command initiates an automated loop that:

1. Waits for reviews from ANY reviewer (GitHub Actions, human reviewers, bots)
2. Monitors for ALL review comments and CI workflow results
3. Addresses any feedback or failures from ANY source
4. **Marks ALL comments as resolved before starting the next loop iteration**
5. Repeats until PR is approved and all checks pass

**Important**: Whenever a fix is pushed, ALL comments that were responded to must be marked as
resolved before starting the loop again. This includes:

- Comments with code suggestions that have been fixed
- General comments without code suggestions (must still be addressed and hidden)
- Outdated or irrelevant comments (must be replied to noting their status, then hidden)

## Important: MCP-First Approach

See `@rules/pr/common.md` for the MCP-first approach principles and when to use CLI fallbacks.

## Initial Setup

### 1. Detect Repository Context

See `@rules/pr/common.md#repository-context-detection` for automatic repository detection patterns.

### 2. Verify PR Exists

Check if there's an open PR for the current branch. If not, help create one.

### 3. Wait for Reviews

```bash
# Initial wait with visible timer
echo "⏱️ Waiting 30 seconds for reviewers to process..."
for i in $(seq 30 -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
printf "\r✅ Initial wait complete\n"

# Check for ALL reviews (not just GitHub Actions)
# This includes human reviewers, bots, and automated systems
mcp__github__get_pull_request_reviews with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]

# Get ALL review comments from ANY reviewer
gh api repos/[REPO_OWNER]/[REPO_NAME]/pulls/[PR_NUMBER]/reviews --paginate | jq '.[] | {author: .author.login, state: .state, body: .body}'

# Monitor CI/CD workflow status
mcp__github__get_pull_request_status with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]

# Note: Reviews can come from ANY source - humans, bots, or automated systems
# We must check for ALL review comments, not just automated ones
```

## Main Feedback Loop

### Loop Configuration

- **Initial Wait**: 30 seconds for GitHub Actions to start reviewing
- **Check Interval After Commit**: 30 seconds (for new PR comments)
- **Check Interval When Only Waiting for Tests**: 1 minute (60 seconds)
- **Max Iterations**: 60 cycles (1 hour total)
- **Exit Conditions**:
  - ALL CI checks pass (100% success rate, NO EXCEPTIONS) AND no unresolved review comments from ANY reviewer
  - User explicitly stops the loop
  - Maximum iterations reached

**CRITICAL**: There are NO acceptable reasons for test failures. ALL tests must pass, including:

- Tests that appear "unrelated" to your changes
- Tests that seem to be "flaky" or intermittent
- Tests that were "already failing" before your PR
- ANY test failure is considered YOUR responsibility to fix

### Loop Process

**IMPORTANT**: Every iteration MUST run `/pr:reply-and-hide-resolved-comments` after checking for comments to ensure all resolved issues are properly marked and hidden before continuing.

#### Step 1: Check PR Status and Clean Up Resolved Comments and Clean Up Resolved Comments

```bash
# Use Claude's native /pr:comments command to get all PR comments
/pr:comments

# ALWAYS try MCP first for other GitHub operations
mcp__github__get_pull_request
mcp__github__get_pull_request_status

# Run reply-and-hide command to clean up any resolved comments
/pr:reply-and-hide-resolved-comments

# FALLBACK: If MCP responses are too large or fail, use gh CLI
# gh pr view [PR_NUMBER] --json state,reviews,statusCheckRollup
# gh pr checks [PR_NUMBER]
```

#### Step 2: Analyze Feedback

##### A. Review Comments

- Use `/pr:comments` to get ALL review comments from ANY reviewer
- Parse review comments from ALL sources (humans, bots, automated systems)
- Check specifically for:
  - Human reviewer comments (team members)
  - GitHub Actions automated reviews
  - Bot reviews (automated review bots, security scanners, etc.)
- Identify actionable feedback vs suggestions
- Group comments by file and type
- NEVER filter by reviewer - process ALL comments

##### B. CI Workflow Status

- Check all workflow runs
- Identify failed tests
- Parse error messages and stack traces

#### Step 3: Address Issues

**MANDATORY: After making ANY changes to address PR comments, you MUST run /testing:pre-commit:**

1. **First, make the code changes** to address review feedback
2. **Then ALWAYS run /testing:pre-commit** before committing

```
/testing:pre-commit
```

**CRITICAL**: Never commit changes manually after addressing PR comments. The /testing:pre-commit command MUST be used because it:

- Runs rubocop-git on changed files to ensure code style compliance
- Executes all relevant tests to verify nothing is broken
- Fixes issues iteratively until everything passes
- Only then stages, commits, and pushes the changes

For specific issue types:

##### Review Comments:

- Make code changes based on reviewer feedback
- **ALWAYS run /testing:pre-commit** to validate changes
- Logic issues are fixed and tested via /testing:pre-commit
- Documentation is updated as needed

##### CI Check Failures:

**ABSOLUTE REQUIREMENT: 100% of ALL tests MUST pass:**

- New test failures introduced by your changes
- Pre-existing test failures that were already in the codebase
- Flaky or intermittent test failures
- Tests that appear unrelated to your current PR changes
- VCR cassette errors
- SNS/AWS related failures
- Database connection issues
- ANY test failure for ANY reason

**ZERO TOLERANCE POLICY**:

- Do NOT skip or ignore ANY test failures
- Do NOT classify tests as "unrelated" to your changes
- Do NOT dismiss failures as "flaky" or "intermittent"
- EVERY test failure is YOUR responsibility to investigate and fix
- The loop MUST continue until 100% of tests pass

- Test failures are resolved then validated by /testing:pre-commit
- Linting issues are auto-fixed by /testing:pre-commit
- Build errors are addressed then verified by /testing:pre-commit

#### Step 4: Commit and Push Using Pre-Commit

**NEVER manually commit after addressing PR comments. ALWAYS use /testing:pre-commit:**

```
/testing:pre-commit
```

This is MANDATORY because it ensures:

- All tests pass after your changes
- Code is properly linted
- No new issues are introduced
- Changes are safely committed and pushed only after validation

#### Step 5: Reply to ALL Review Comments and Mark as Resolved

**CRITICAL WORKFLOW - Must complete before continuing loop:**

After running /testing:pre-commit and pushing changes, you MUST individually reply to EACH review comment:

### MANDATORY: Reply to Each Individual Comment

**DO NOT just post a general PR comment!** You must reply to EACH specific review comment:

```bash
# 1. First get all unresolved review comments with their IDs
gh api repos/[OWNER]/[REPO]/pulls/[PR_NUMBER]/comments --paginate | jq '.[] | {id: .id, user: .user.login, path: .path, line: .line, body: .body}'

# 2. For EACH comment that was addressed, create a reply using the GitHub API
# The reply MUST reference the specific commit SHA that fixed it
gh api repos/[OWNER]/[REPO]/pulls/[PR_NUMBER]/comments/[COMMENT_ID]/replies \
  -X POST \
  -f body="Fixed in commit [SHORT_SHA]: [Brief explanation of fix]"
```

**Example replies for different comment types:**

- Code change: "Fixed in commit abc123d: Moved constant to App::Constants as suggested"
- Test addition: "Fixed in commit abc123d: Added test coverage for logger failure scenario"
- Refactor: "Fixed in commit abc123d: Refactored to use hash lookup instead of case statement"
- No change needed: "Not applicable - this is an internal gRPC service following existing patterns"

### Alternative: Use the /pr:reply-and-hide-resolved-comments command

```
/pr:reply-and-hide-resolved-comments
```

This command will:

1. **Reply to Each Individual Comment**:

- Find all unresolved review comments
- Reply to EACH one with the commit SHA that fixed it
- Provide a specific explanation for each fix
- Example: "Fixed in commit abc123: Updated validation logic to handle nil values"

2. **Mark as Resolved**:

- After replying, mark each comment thread as resolved
- Hide comment threads that have been addressed

3. **Verify All Comments Handled**:

- Ensure NO unresolved comments remain
- Check that all threads show as "Resolved"

**IMPORTANT NOTES:**

- **NEVER** just post a general PR comment summarizing fixes
- **ALWAYS** reply to each individual comment with the specific commit that addressed it
- **ALWAYS** include the short commit SHA (use `git rev-parse --short HEAD`)
- If a comment doesn't require a fix, still reply explaining why

**DO NOT CONTINUE THE LOOP** until all individual comments have been replied to.

For manual resolution if needed, see `@rules/pr/pr-comment-resolution.md`.

#### Step 6: Wait for New Review

After pushing fixes:

```bash
# Check for new reviews from ALL reviewers after new commits
# This includes humans, bots, and automated systems
mcp__github__get_pull_request_reviews with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]

# Also check for any new review comments from human reviewers
gh api repos/[REPO_OWNER]/[REPO_NAME]/pulls/[PR_NUMBER]/reviews --paginate | jq '.[] | select(.submittedAt > "[LAST_CHECK_TIME]") | {author: .author.login, state: .state}'

# Monitor workflow status for the new commit
mcp__github__get_pull_request_status with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pullNumber: [PR_NUMBER]
```

#### Step 7: Wait and Monitor

**IMPORTANT: Display an active countdown timer during all wait periods**

```bash
# Determine wait interval based on current state
if [ "$JUST_COMMITTED" = true ]; then
  WAIT_TIME=30  # 30 seconds after committing to check for PR comments
elif [ "$ALL_COMMENTS_RESOLVED" = true ]; then
  WAIT_TIME=60  # 1 minute when just waiting for tests
else
  WAIT_TIME=30  # Default to 30 seconds for active comment resolution
fi

# Display active countdown timer
echo "⏱️ Waiting $WAIT_TIME seconds before next check..."
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
printf "\r✅ Wait complete, checking status...\n"

# Then repeat from Step 1 (which includes /pr:reply-and-hide-resolved-comments)
```

**Timer Display Requirements:**

- Show exact seconds remaining
- Update every second in place (using \r)
- Clear indication when timer completes
- Different wait times based on state:
  - 30s after pushing commits (checking for new comments)
  - 60s when all comments resolved (waiting for tests)
  - 30s during active comment resolution

## Status Reporting

### Progress Updates

Every iteration, report:

- Current iteration number
- Review comments addressed
- Tests fixed
- CI status
- Next actions

### Summary Format

```
🔄 PR Review Loop - Iteration X/60
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Review Comments: X addressed, Y pending
✅ CI Checks: X passing, Y failing (MUST reach 100% pass rate)
🔧 Changes Made:
  - Fixed [issue 1]
  - Updated [file 2]
  - Added tests for [feature 3]
⚠️ REMAINING FAILURES (ALL must be fixed):
  - [Test name 1] - [Error summary]
  - [Test name 2] - [Error summary]
⏱️ Next check in: [30s for comments / 60s for tests]
```

**Active Timer Display:**

```
⏳ Time remaining: 45 seconds
```

(Updates every second in place)

## Error Handling

### Common Issues

#### Merge Conflicts

1. Pull latest changes
2. Resolve conflicts locally
3. Run tests to verify
4. Push resolved version

#### Persistent Test Failures

1. Debug with detailed output
2. Check for environment issues
3. Review test assumptions
4. Consider flaky test patterns

#### Review Comment Disagreements

1. Provide explanation in reply
2. Suggest alternative approach
3. Mark as "won't fix" if appropriate
4. Document reasoning

## Exit Criteria

### Success Conditions

- ✅ 100% of ALL CI checks passing (ZERO failures tolerated)
- ✅ 100% of ALL tests passing (NO EXCEPTIONS)
- ✅ No unresolved review comments
- ✅ PR approved by automated review bot
- ✅ Ready for human review

**ABSOLUTE REQUIREMENT**: The loop MUST NOT stop if there are ANY test failures:

- Pre-existing test failures MUST be fixed
- "Flaky" tests MUST be made stable and pass consistently
- Tests that were already failing MUST be fixed
- Tests that seem "unrelated" to your changes MUST still pass
- VCR/SNS/AWS errors MUST be resolved
- Database or connection issues MUST be fixed
- EVERY SINGLE TEST must show green/pass status

**NO ACCEPTABLE EXCUSES FOR TEST FAILURES**:

- ❌ "This test was already failing" - FIX IT
- ❌ "This is a flaky test" - MAKE IT STABLE
- ❌ "This is unrelated to my changes" - STILL YOUR RESPONSIBILITY
- ❌ "This is a VCR/cassette issue" - FIX THE VCR SETUP
- ❌ "This is an infrastructure problem" - FIND A SOLUTION

100% test success is the ONLY acceptable outcome.

### Failure Conditions

- ❌ Maximum iterations reached
- ❌ Unresolvable conflicts
- ❌ Critical blocker identified
- ❌ User intervention required

## Configuration Options

### Customizable Parameters

- `CHECK_INTERVAL_AFTER_COMMIT`: Time to wait after commits (default: 30 seconds)
- `CHECK_INTERVAL_FOR_TESTS`: Time to wait when only monitoring tests (default: 60 seconds)
- `MAX_ITERATIONS`: Maximum loop cycles (default: 60)
- `AUTO_COMMIT`: Automatically commit fixes (default: true)
- `AUTO_PUSH`: Automatically push changes (default: true)
- `REPLY_TO_ALL_COMMENTS`: Reply to ALL comments before next iteration (default: true, REQUIRED)
- `AUTO_RESOLVE_ALL_COMMENTS`: Mark ALL replied comments as resolved (default: true, REQUIRED)
- `SHOW_TIMER`: Display active countdown timer (default: true, REQUIRED)

## Usage

To start the full feedback loop:

```
/pr:review-feedback-loop
```

With custom options:

```
/pr:review-feedback-loop CHECK_INTERVAL_AFTER_COMMIT=20 CHECK_INTERVAL_FOR_TESTS=45 MAX_ITERATIONS=60
```

To stop the loop:

```
Type "STOP" or Ctrl+C
```

## Best Practices

1. **Commit Frequently**: Make small, focused commits for each fix
2. **Clear Messages**: Write descriptive commit messages referencing the feedback
3. **Test Locally**: Always verify fixes locally before pushing
4. **Document Changes**: Reply to comments explaining what was changed
5. **Monitor Progress**: Watch for patterns in feedback to improve code quality

## Notes

- The loop will automatically pause if rate limits are approached
- Large PRs may require longer intervals between checks
- Some complex issues may require manual intervention
- The loop preserves all feedback history for audit purposes
