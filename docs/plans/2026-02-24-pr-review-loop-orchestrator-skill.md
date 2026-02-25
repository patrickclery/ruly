the # PR Review Loop: Convert from Subagent to Orchestrator Skill

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert pr-review-loop from a dispatched subagent (invisible to user) into an orchestrator skill that diagnoses issues via `core_debugger` and fixes them via `core_engineer` in parallel worktrees, keeping the user informed throughout.

**Architecture:** Remove the `pr_review_loop` subagent entirely. The pr-review-loop becomes a skill that runs on the orchestrator, dispatching `core_debugger` for diagnosis and `core_engineer` for parallel fixes in isolated git worktrees. The dispatch rule changes from "dispatch subagent" to "invoke skill directly." This gives the user full visibility into the review-fix cycle.

**Tech Stack:** Ruly rules (Markdown), profile YAML, ruly squash verification

---

### Task 1: Remove `pr_review_loop` subagent from all profiles

The `pr_review_loop` subagent and its profile definition are no longer needed. The skill will run directly on the orchestrator.

**Files:**
- Modify: `profiles.yml:83-84` (remove from `core` subagents)
- Modify: `profiles.yml:518-519` (remove from `orchestrator` subagents)
- Modify: `profiles.yml:783-788` (remove `pr-review-loop` profile definition)
- Sync: `~/.config/ruly/profiles.yml` (must match)

**Step 1: Remove `pr_review_loop` from `core` profile subagents (line 83-84)**

Delete these two lines:
```yaml
      - name: pr_review_loop
        profile: pr-review-loop
```

**Step 2: Remove `pr_review_loop` from `orchestrator` profile subagents (line 518-519)**

Delete these two lines:
```yaml
      - name: pr_review_loop
        profile: pr-review-loop
```

**Step 3: Remove `pr-review-loop` profile definition (lines 783-788)**

Delete this entire block:
```yaml
  pr-review-loop:
    description: "Automated PR review feedback loop - monitors reviews, fixes issues, re-checks"
    omit_command_prefix: github
    skills:
      - /Users/patrick/Projects/ruly/rules/github/pr/skills/pr-review-loop.md
```

**Step 4: Sync profiles**

```bash
cp /Users/patrick/Projects/ruly/profiles.yml ~/.config/ruly/profiles.yml
cp /Users/patrick/Projects/ruly/profiles.yml /Users/patrick/Projects/chezmoi/config/ruly/profiles.yml
```

**Step 5: Verify no dangling references**

```bash
grep -rn 'pr-review-loop' /Users/patrick/Projects/ruly/profiles.yml
grep -rn 'pr_review_loop' /Users/patrick/Projects/ruly/profiles.yml
```

Expected: Only `skills:` references to `pr-review-loop.md` remain (these are correct — the skill stays). No `profile: pr-review-loop` or `name: pr_review_loop` entries.

**Step 6: Commit**

```bash
git add profiles.yml
git commit -m "refactor: remove pr_review_loop subagent — skill runs on orchestrator now"
```

---

### Task 2: Convert dispatch rule from subagent dispatch to skill invocation

The dispatch rule currently forces the orchestrator to dispatch a `pr_review_loop` subagent. Change it to instruct the orchestrator to invoke the `pr-review-loop` skill directly.

**Files:**
- Modify: `rules/workaxle/core/dispatches/use-pr-review-loop.md`
- Modify: `rules/workaxle/orchestrator/dispatch.md`

**Step 1: Rewrite `use-pr-review-loop.md`**

Replace the entire content of `rules/workaxle/core/dispatches/use-pr-review-loop.md` with:

```markdown
---
description: Forces PR review feedback loop tasks to invoke the pr-review-loop skill directly for visible orchestration
alwaysApply: true
---
# PR Review Loop: Invoke Skill Directly

## When This Applies

Any time you are asked to or encounter:
- Starting the review feedback loop on a PR
- Monitoring a PR for reviews or CI status
- Fixing review comments or feedback from reviewers
- Running the automated review-fix-recheck cycle
- "Watch this PR" or "handle the reviews"

## The Rule

**Invoke the `pr-review-loop` skill and follow it yourself.** Do NOT dispatch a subagent for this. The skill orchestrates the work by dispatching `core_debugger` (diagnosis) and `core_engineer` (fixes) as subagents. You stay in control so the user sees progress.

## Why Not a Subagent?

The review loop is **orchestration**, not implementation. It:
1. Fetches context and parses issues (lightweight)
2. Dispatches `core_debugger` for diagnosis (subagent)
3. Dispatches `core_engineer` for fixes in parallel worktrees (subagent)
4. Integrates fixes, pushes, replies to comments (lightweight)
5. Loops

This is dispatcher work. You are the dispatcher. Run the skill.

## Does NOT Apply When

- User asks to **create** a PR (use PR creation commands directly)
- User asks to **merge** a PR (defer to `merger` subagent)
- User asks to **review** someone else's PR (defer to `reviewer` subagent)
- User asks to check PR **readiness** without starting the loop (defer to `pr_readiness` subagent)
- User asks to fix a single specific issue without the loop (dispatch `core_engineer`)

## Red Flags — You Are Violating This Rule

- You dispatched a subagent for the review loop instead of running the skill
- You are fixing code yourself instead of dispatching `core_engineer`
- You are investigating failures yourself instead of dispatching `core_debugger`

**The skill dispatches subagents. You run the skill. The subagents do the work.**
```

Note: The `dispatches:` frontmatter key is removed — this rule no longer dispatches a subagent.

**Step 2: Update the orchestrator routing table**

In `rules/workaxle/orchestrator/dispatch.md`, change the routing entry from:

```
| Review feedback loop, monitor PR for reviews | `pr_review_loop` |
```

To:

```
| Review feedback loop, monitor PR for reviews | **Use `pr-review-loop` skill** (handle directly) |
```

**Step 3: Commit**

```bash
cd /Users/patrick/Projects/ruly/rules
git add workaxle/core/dispatches/use-pr-review-loop.md workaxle/orchestrator/dispatch.md
git commit -m "refactor: change pr-review-loop dispatch from subagent to skill invocation"
```

---

### Task 3: Rewrite the pr-review-loop skill as an orchestrator skill

The current skill is a 758-line detailed procedure that the (now-removed) subagent followed. Rewrite it as a lean orchestration workflow that dispatches `core_debugger` for diagnosis and `core_engineer` for parallel fixes.

**Files:**
- Modify: `rules/github/pr/skills/pr-review-loop.md`

**Step 1: Replace the skill content**

Replace the entire content of `rules/github/pr/skills/pr-review-loop.md` with the content below. The `requires:` stay the same — the referenced files have the patterns (parallel worktrees, ralph loop, comment resolution) that the skill references via section anchors.

```markdown
---
name: pr-review-loop
description: Use when monitoring a PR for reviews, fixing review feedback, or running the automated review-fix-recheck cycle
alwaysApply: false
requires:
  - ../common.md
  - ../parallel-fix-orchestration.md
  - ../../../comms/github/pr/pr-comment-resolution.md
requires_shell_command:
  - countdown-timer.sh
---

# PR Review Feedback Loop

## Overview

**You are the orchestrator.** This skill runs the automated review-fix-recheck cycle by dispatching subagents. Do NOT fix issues yourself.

Workflow per iteration:
1. Fetch PR context and parse issues
2. Dispatch `core_debugger` to diagnose each issue
3. Dispatch `core_engineer` in parallel worktrees to fix each diagnosed issue
4. Cherry-pick fixes back, push, reply to comments
5. Wait and repeat until approved

## Initial Setup

### 1. Detect Repository Context

See [PR Context Detection](#pr-context-detection) for automatic repository and PR detection.

### 2. Determine Current Issue and Find All Related PRs

```bash
CURRENT_BRANCH=$(git branch --show-current)
JIRA_ISSUE=$(echo "$CURRENT_BRANCH" | grep -oE 'WA-[0-9]+')

# Fallback: try directory name
if [ -z "$JIRA_ISSUE" ]; then
  JIRA_ISSUE=$(basename "$PWD" | grep -oE 'WA-[0-9]+')
fi

# Find all open PRs for this issue
PR_NUMBERS=$(gh pr list --repo workaxle/workaxle-core --state open --json number,headRefName \
  --jq ".[] | select(.headRefName | test(\"$JIRA_ISSUE\"; \"i\")) | .number")
```

### 3. Fetch Context

```bash
check-cache-freshness.sh ~/tmp/context/{JIRA_ISSUE}

# If not FRESH:
fetch-jira-details.sh -O ~/tmp/context/{JIRA_ISSUE} {JIRA_ISSUE}
fetch-pr-details.sh -O ~/tmp/context/{JIRA_ISSUE} {PR_NUMBER}
```

Read from:
- `~/tmp/context/{JIRA_ISSUE}/pull-request-{PR_NUMBER}.toon`
- `~/tmp/context/{JIRA_ISSUE}/jira-{JIRA_ISSUE}.toon`

### 4. Initial Wait

```bash
countdown-timer.sh 30 "Waiting for reviewers to process"
```

## Main Loop

### Exit Conditions

- ALL CI checks pass AND no unresolved review comments AND PR approved
- User types "STOP" or Ctrl+C
- Maximum iterations reached (default: 60)

**CRITICAL**: 100% test success is the ONLY acceptable outcome. No exceptions for "flaky", "pre-existing", or "unrelated" failures.

### Phase 1: Check Status & Parse Issues

1. **Check PR status** (OK to call directly for real-time status):

```bash
gh pr checks "$PR_NUMBER"
gh pr view "$PR_NUMBER" --json state,mergeable,mergeStateStatus,statusCheckRollup
```

2. **Re-fetch cached context** for reviews and comments:

```bash
fetch-pr-details.sh -O ~/tmp/context/{JIRA_ISSUE} {PR_NUMBER}
```

3. **Parse all actionable issues** from the cached `.toon` file:
   - `unresolvedThreads` — inline review comments (each thread = one issue)
   - `comments` — PR conversation comments with actionable feedback (bot reviews, human comments)
   - CI check failures — each failing check = one issue

4. **CRITICAL**: `unresolvedThreadCount: 0` does NOT mean all feedback is addressed. Always check `comments` too. See [Two Types of Feedback](#two-types-of-feedback--both-must-be-addressed).

5. If no issues found and all checks pass → **exit loop (success)**. Otherwise continue.

### Phase 2: Diagnose Issues

Dispatch `core_debugger` for each issue. All dispatches in **one message** (parallel).

**For review comments:**

```
Task tool:
  subagent_type: "core_debugger"
  prompt: |
    Diagnose this PR review issue. Read the code and produce a diagnosis report.

    ## Review Comment
    File: {file_path}:{line_range}
    Reviewer said: {comment_body}
    {If suggested_fix: "Suggested code: {suggested_fix}"}

    ## Your Job
    1. Read the file and surrounding context
    2. Understand what the reviewer is asking for
    3. Produce a diagnosis:
       - What needs to change and why
       - Which files to modify
       - Recommended approach
       - Any risks or edge cases to watch for
```

**For CI failures:**

```
Task tool:
  subagent_type: "core_debugger"
  prompt: |
    Diagnose this CI failure from PR #{PR_NUMBER}.

    ## Failure Details
    Check: {check_name}
    Error output: {error_summary}

    ## Your Job
    1. Investigate what's causing the failure
    2. Identify root cause (may be unrelated to this PR)
    3. Produce a diagnosis:
       - Root cause
       - Files to modify
       - Recommended fix approach
```

**Collect all diagnosis reports** before proceeding to Phase 3.

**Report to user:**
```
🔍 Diagnosed N issues:
  1. {issue_id}: {one-line summary of diagnosis}
  2. {issue_id}: {one-line summary of diagnosis}
  ...
```

### Phase 3: Parallel Fix in Worktrees

Use [Parallel Fix Orchestration](#parallel-fix-orchestration) for the full pattern.

**Step 1: Create worktrees** (one per diagnosed issue):

```bash
mkdir -p .worktrees
git check-ignore -q .worktrees 2>/dev/null || echo ".worktrees/" >> .gitignore

# For each issue:
git worktree add ".worktrees/fix-${issue_id}" -b "fix-${issue_id}" HEAD
```

**Step 2: Dispatch `core_engineer` per worktree** (all in one message, parallel):

```
Task tool:
  subagent_type: "core_engineer"
  prompt: |
    Fix this diagnosed issue. Work in the worktree at {worktree_path}.

    ## Diagnosis
    {diagnosis_report from Phase 2}

    ## Original Review Comment
    {comment_body}

    ## Your Job
    1. cd {worktree_path}
    2. Make the fix per the diagnosis
    3. Run tests to verify
    4. Commit your fix (do NOT push)

    ## Important
    - Fix ONLY this specific issue, nothing else
    - Do NOT modify files unrelated to this issue
    - Do NOT push (the orchestrator handles that)
    - Commit your fix in this worktree with a descriptive message
```

**Step 3: Handle results**

After all agents complete, check each result:
- `solved` → ready for cherry-pick
- `relay_needed` → dispatch fresh `core_engineer` with progress (max 3 iterations per issue per [Iteration Control](#iteration-control))
- `blocked` → mark for manual intervention, report to user

### Phase 4: Integration

Follow the [Merge Back Strategy](#step-5-merge-back-cherry-pick-strategy).

1. **Cherry-pick** from each worktree to PR branch:

```bash
git checkout {PR_BRANCH}
for each fixed_issue:
  COMMIT_SHA=$(cd .worktrees/fix-${issue_id} && git log --format=%H -1)
  git cherry-pick $COMMIT_SHA
```

2. **Resolve conflicts** — reviewer's requested change always wins for the lines they commented on.

3. **Run tests** locally to validate combined changes.

4. **Push:**

```bash
git push
```

5. **Reply to comments** with commit SHAs per [Comment Resolution Workflow](#comment-resolution-workflow).

6. **Clean up worktrees:**

```bash
for each issue_id:
  git worktree remove ".worktrees/fix-${issue_id}" --force
  git branch -D "fix-${issue_id}"
```

### Phase 5: Wait and Loop

```bash
countdown-timer.sh 30 "Waiting for new reviews"
```

Repeat from Phase 1.

## Status Reporting

Display after each iteration:

```
🔄 PR Review Loop - Iteration X/Y
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 PR: #{PR_NUMBER} - {TITLE}
🌿 Branch: {BRANCH_NAME}

📊 Issues Found: N
🔍 Diagnosed: N (via core_debugger)
🔧 Fixed: N (via core_engineer in parallel worktrees)
⚠️ Blocked: N (needs manual intervention)

📊 CI Status:
  ✅ {check-name} (success)
  ⏳ {check-name} (pending)
  ❌ {check-name} (failure)

⏱️ Next check in: X seconds
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## When to Use Parallel vs Sequential

**Use parallel dispatch when:**
- 2+ independent issues found
- Issues are in different files or different sections

**Fall back to sequential when:**
- Only 1 issue found
- All issues are in the same function/block
- Review is a single "rewrite this entire approach" comment

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CHECK_INTERVAL_AFTER_COMMIT` | 30 seconds | Wait after pushing |
| `CHECK_INTERVAL_FOR_TESTS` | 60 seconds | Wait when monitoring CI |
| `MAX_ITERATIONS` | 60 | Maximum loop cycles |
| `MAX_FIX_ITERATIONS` | 3 | Max fresh agent dispatches per issue |

## Error Handling

### Merge Conflicts During Cherry-Pick

1. Check which files conflict
2. Resolve: reviewer's requested change wins for their lines, keep PR branch for others
3. If ambiguous, mark for manual intervention

### Issues Needing Manual Intervention

Report to user with full details:
- What the issue was
- What was attempted
- Why it's blocked
- Suggested next step

### Branch Behind Main

See [Update Branch from Main](#update-branch-from-main). Only merge from `main`, never from `develop`.

### Develop PR Conflicts

See [Develop PR Conflicts](#develop-pr-conflicts). Focus on main PR, report develop conflicts but take no action.
```

**Step 2: Verify the skill file is valid markdown**

Read the file back and verify it has correct frontmatter, section headers, and anchor links to required content.

**Step 3: Commit**

```bash
cd /Users/patrick/Projects/ruly/rules
git add github/pr/skills/pr-review-loop.md
git commit -m "refactor: rewrite pr-review-loop as orchestrator skill dispatching core_debugger + core_engineer"
```

---

### Task 4: Verify with ruly squash

**Step 1: Squash core profile in tmpdir**

```bash
cd $(mktemp -d) && ~/Projects/ruly/bin/ruly squash core
```

Expected:
- No `pr_review_loop` in the subagents list
- Skill `pr-review-loop` still generated in `.claude/skills/`
- No agent file `.claude/agents/pr_review_loop.md` generated
- No errors about missing `pr-review-loop` profile

**Step 2: Verify no agent file for pr_review_loop**

```bash
ls -la .claude/agents/ | grep -i review
```

Expected: No `pr_review_loop.md` file.

**Step 3: Verify skill content**

```bash
cat .claude/skills/pr-review-loop/SKILL.md | head -20
```

Expected: Contains "You are the orchestrator" and dispatches to `core_debugger` / `core_engineer`.

**Step 4: Verify dispatch rule content**

```bash
grep -A5 "PR Review Loop" CLAUDE.local.md | head -10
```

Expected: Contains "Invoke the `pr-review-loop` skill" (not "dispatch the `pr_review_loop` subagent").

**Step 5: Squash orchestrator profile**

```bash
cd $(mktemp -d) && ~/Projects/ruly/bin/ruly squash orchestrator
```

Expected: Same results — no pr_review_loop agent, skill present, dispatch rule updated.

---

### Task 5: Update the installed ruly binary and push

**Step 1: Rebuild**

```bash
cd /Users/patrick/Projects/ruly && mise install ruby
```

**Step 2: Push rules submodule**

```bash
cd /Users/patrick/Projects/ruly/rules
git push
```

**Step 3: Update ruly submodule reference and push**

```bash
cd /Users/patrick/Projects/ruly
git add rules
git commit -m "refactor: pr-review-loop is now orchestrator skill, not subagent

The review loop runs directly on the orchestrator, dispatching
core_debugger for diagnosis and core_engineer for parallel fixes
in isolated git worktrees. User sees all progress."
git push
```
