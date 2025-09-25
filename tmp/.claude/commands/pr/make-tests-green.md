---
description: Automated CI workflow monitoring and fixing loop for GitHub Actions
alwaysApply: true
requires:
  - ../../commands.md
---

# CI Workflow Fix Loop

## Overview

This command initiates an automated loop that monitors and fixes failing CI workflows until the workflow run is green. Works for any branch, with or without a pull request.

## Initial Setup

### 1. Detect Repository Context

Automatically detect repository and branch from current git repository:

```bash
# Get current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# Get repository info from git remote
REPO_URL=$(git config --get remote.origin.url)
# Extract owner and repo name from URL (works with both HTTPS and SSH)
if [[ $REPO_URL =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
fi

echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Branch: $BRANCH_NAME"
```

### 2. Find and Check Workflow Status

```bash
# Get the latest workflow run for current branch
echo "Finding latest workflow run for branch: $BRANCH_NAME"

# Get most recent workflow runs for the branch
LATEST_RUN=$(gh run list --branch "$BRANCH_NAME" --limit 1 --json databaseId,status,conclusion,workflowName,headSha --jq '.[0]')

if [ -z "$LATEST_RUN" ]; then
  echo "No workflow runs found for branch $BRANCH_NAME"
  # Optionally trigger a new workflow run
  # gh workflow run [workflow-name] --ref "$BRANCH_NAME"
  exit 1
fi

# Extract workflow run details
WORKFLOW_RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
WORKFLOW_STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
WORKFLOW_CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')
WORKFLOW_NAME=$(echo "$LATEST_RUN" | jq -r '.workflowName')
HEAD_SHA=$(echo "$LATEST_RUN" | jq -r '.headSha')

echo "Found workflow run: #$WORKFLOW_RUN_ID"
echo "Workflow: $WORKFLOW_NAME"
echo "Status: $WORKFLOW_STATUS"
echo "Conclusion: $WORKFLOW_CONCLUSION"
echo "Commit: $HEAD_SHA"

# If workflow is still running, wait for it
if [ "$WORKFLOW_STATUS" = "in_progress" ] || [ "$WORKFLOW_STATUS" = "queued" ]; then
  echo "Workflow is still running. Monitoring..."
  gh run watch "$WORKFLOW_RUN_ID"
fi

# Check all job statuses if workflow failed
if [ "$WORKFLOW_CONCLUSION" = "failure" ]; then
  echo "Workflow failed. Getting job details..."
  gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$WORKFLOW_RUN_ID/jobs --paginate | \
    jq '.jobs[] | select(.conclusion == "failure") | {name: .name, conclusion: .conclusion}'
  
  # Get failed job logs
  gh run view "$WORKFLOW_RUN_ID" --log-failed > workflow_errors.log
fi
```

## Main Feedback Loop

### Loop Configuration

- **Initial Wait**: 30 seconds for workflow to start or complete current jobs
- **Check Interval After Push**: 30 seconds (for new workflow runs)
- **Check Interval When Tests Running**: 1 minute (60 seconds)
- **Max Iterations**: 60 cycles (1 hour total)
- **Exit Conditions**:
  - ALL CI checks pass (100% success rate, NO EXCEPTIONS)
  - User explicitly stops the loop
  - Maximum iterations reached

**CRITICAL**: There are NO acceptable reasons for test failures. ALL tests must pass, including:

- Tests that appear "unrelated" to your changes
- Tests that seem to be "flaky" or intermittent
- Tests that were "already failing" before your PR
- ANY test failure is considered YOUR responsibility to fix

### Loop Process

#### Step 1: Check Workflow Status

```bash
# Get latest workflow run for current branch (in case new one started)
LATEST_RUN=$(gh run list --branch "$BRANCH_NAME" --limit 1 --json databaseId,status,conclusion,workflowName,headSha --jq '.[0]')

# Update workflow run ID if a newer run exists
NEW_RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
if [ "$NEW_RUN_ID" != "$WORKFLOW_RUN_ID" ]; then
  echo "New workflow run detected: #$NEW_RUN_ID"
  WORKFLOW_RUN_ID=$NEW_RUN_ID
fi

# Get current status
WORKFLOW_STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
WORKFLOW_CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')

echo "Workflow #$WORKFLOW_RUN_ID - Status: $WORKFLOW_STATUS, Conclusion: $WORKFLOW_CONCLUSION"

# If workflow is complete and failed, get details
if [ "$WORKFLOW_CONCLUSION" = "failure" ]; then
  # Get failed jobs
  echo "Failed jobs:"
  gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$WORKFLOW_RUN_ID/jobs --paginate | \
    jq '.jobs[] | select(.conclusion == "failure") | {name: .name, conclusion: .conclusion}'
  
  # Get logs from failed jobs
  gh run view "$WORKFLOW_RUN_ID" --log-failed > workflow_errors.log
  echo "Error logs saved to workflow_errors.log"
fi
```

#### Step 2: Analyze Failures

##### A. Parse Workflow Logs

```bash
# Extract test failures from logs
grep -E "(FAILED|ERROR|FAIL)" workflow_errors.log

# Look for specific error patterns
grep -E "(AssertionError|TestFailure|RSpec::Expectations::ExpectationNotMetError)" workflow_errors.log

# Extract file paths and line numbers
grep -E "(\w+\.rb:\d+|spec/.*_spec\.rb)" workflow_errors.log
```

##### B. Identify Failure Types

- Test failures (unit, integration, E2E)
- Linting errors (rubocop, eslint, etc.)
- Build/compilation errors
- Database/migration issues
- Environment/dependency problems

#### Step 3: Address Issues

**MANDATORY: After making ANY changes to fix failures, you MUST run appropriate tests locally:**

1. **First, make the code changes** to address failures
2. **Then run tests locally** before pushing

```bash
# Run specific failing tests locally
bundle exec rspec spec/path/to/failing_spec.rb

# Run linters
bundle exec rubocop --auto-correct

# Run full test suite
bundle exec rspec
```

For specific issue types:

##### Test Failures:

- Fix the actual code causing test failures
- Update tests if they have incorrect expectations
- Fix test setup/teardown issues
- Address flaky test timing issues

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

- Test failures are resolved then validated locally
- Linting issues are auto-fixed by linters
- Build errors are addressed then verified locally

#### Step 4: Commit and Push Changes

```bash
# Stage fixed files
git add .

# Commit with descriptive message
git commit -m "Fix CI failures: [brief description of fixes]"

# Push to trigger new workflow run
git push origin "$BRANCH_NAME"

# Wait for new workflow to start
echo "Waiting for new workflow to start..."
sleep 10

# Get the new workflow run ID
NEW_RUN=$(gh run list --branch "$BRANCH_NAME" --limit 1 --json databaseId --jq '.[0].databaseId')
if [ "$NEW_RUN" != "$WORKFLOW_RUN_ID" ]; then
  echo "New workflow run started: #$NEW_RUN"
  WORKFLOW_RUN_ID=$NEW_RUN
else
  echo "Waiting for workflow to trigger..."
  sleep 10
  NEW_RUN=$(gh run list --branch "$BRANCH_NAME" --limit 1 --json databaseId --jq '.[0].databaseId')
  WORKFLOW_RUN_ID=$NEW_RUN
fi
```

#### Step 5: Wait for New Workflow Run

After pushing fixes:

```bash
# Monitor new workflow run
echo "Monitoring workflow run #$WORKFLOW_RUN_ID"

# Check workflow status
LATEST_RUN=$(gh run list --branch "$BRANCH_NAME" --limit 1 --json databaseId,status,conclusion --jq '.[0]')
WORKFLOW_STATUS=$(echo "$LATEST_RUN" | jq -r '.status')

# Watch workflow progress if running
if [ "$WORKFLOW_STATUS" = "in_progress" ] || [ "$WORKFLOW_STATUS" = "queued" ]; then
  echo "Workflow is running. Watching progress..."
  gh run watch "$WORKFLOW_RUN_ID" --exit-status || true
fi

# Check final status
WORKFLOW_CONCLUSION=$(gh run view "$WORKFLOW_RUN_ID" --json conclusion --jq '.conclusion')
echo "Workflow completed with status: $WORKFLOW_CONCLUSION"
```

#### Step 6: Wait and Monitor

**IMPORTANT: Display an active countdown timer during all wait periods**

```bash
# Determine wait interval based on current state
if [ "$JUST_PUSHED" = true ]; then
  WAIT_TIME=30  # 30 seconds after pushing to wait for workflow to start
elif [ "$WORKFLOW_RUNNING" = true ]; then
  WAIT_TIME=60  # 1 minute when workflow is running
else
  WAIT_TIME=30  # Default to 30 seconds
fi

# Display active countdown timer
echo "⏱️ Waiting $WAIT_TIME seconds before next check..."
for i in $(seq $WAIT_TIME -1 1); do
  printf "\r⏳ Time remaining: %02d seconds" $i
  sleep 1
done
printf "\r✅ Wait complete, checking status...\n"

# Then repeat from Step 1
```

**Timer Display Requirements:**

- Show exact seconds remaining
- Update every second in place (using \r)
- Clear indication when timer completes
- Different wait times based on state:
  - 30s after pushing commits (waiting for workflow to start)
  - 60s when workflow is running
  - 30s for general checks

## Status Reporting

### Progress Updates

Every iteration, report:

- Current iteration number
- Workflow run ID and status
- Tests fixed
- CI status
- Next actions

### Summary Format

```
🔄 CI Fix Loop - Iteration X/60
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 Workflow Run: #[RUN_ID]
📊 Status: [running/completed]
✅ Jobs Passing: X/Y (MUST reach 100% pass rate)
🔧 Changes Made:
  - Fixed [issue 1]
  - Updated [file 2]
  - Added tests for [feature 3]
⚠️ REMAINING FAILURES (ALL must be fixed):
  - [Job name 1] - [Error summary]
  - [Test name 2] - [Error summary]
⏱️ Next check in: [30s/60s]
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
- ✅ Workflow run shows "success" conclusion
- ✅ All jobs completed successfully

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

- `CHECK_INTERVAL_AFTER_PUSH`: Time to wait after pushing (default: 30 seconds)
- `CHECK_INTERVAL_FOR_RUNNING`: Time to wait when workflow is running (default: 60 seconds)
- `MAX_ITERATIONS`: Maximum loop cycles (default: 60)
- `AUTO_COMMIT`: Automatically commit fixes (default: true)
- `AUTO_PUSH`: Automatically push changes (default: true)
- `SHOW_TIMER`: Display active countdown timer (default: true, REQUIRED)

## Usage

To start the CI fix loop for the current branch:

```
/ci:fix-workflow
```

The command will automatically:
1. Detect the current git repository and branch
2. Find the latest workflow run for that branch
3. Monitor and fix failures until all tests pass

With custom options:

```
/ci:fix-workflow CHECK_INTERVAL_AFTER_PUSH=20 CHECK_INTERVAL_FOR_RUNNING=45 MAX_ITERATIONS=60
```

To check a specific branch:

```
git checkout [branch-name]
/ci:fix-workflow
```

To stop the loop:

```
Type "STOP" or Ctrl+C
```

## Best Practices

1. **Commit Frequently**: Make small, focused commits for each fix
2. **Clear Messages**: Write descriptive commit messages referencing the failures fixed
3. **Test Locally**: Always verify fixes locally before pushing
4. **Monitor Progress**: Watch for patterns in failures to improve code quality
5. **Check Logs Thoroughly**: Parse workflow logs to understand root causes

## Notes

- The loop will automatically pause if rate limits are approached
- Complex workflows may require longer intervals between checks
- Some infrastructure issues may require manual intervention
- The loop tracks all workflow runs for audit purposes
- Works for any branch, with or without an associated pull request
