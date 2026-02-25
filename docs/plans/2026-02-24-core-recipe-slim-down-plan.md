# Core Profile Slim-Down Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce the core orchestrator profile from ~104KB squashed output to ~50-55KB by removing code patterns, extracting PR creation into a subagent, slimming transitive requires chains, and merging overlapping dispatch rules.

**Architecture:** The core profile is a pure dispatcher. It should contain only dispatch rules, reference docs, and minimal skills. All code knowledge, PR creation commands, and their transitive dependencies belong in subagent profiles.

**Tech Stack:** Ruly (Ruby gem), YAML profiles, Markdown rule files with frontmatter

---

### Task 1: Create the `use-pr-creator.md` dispatch rule

**Files:**
- Create: `rules/workaxle/core/dispatches/use-pr-creator.md`

**Step 1: Create the dispatch rule file**

```markdown
---
description: Forces PR creation tasks to dispatch pr_creator subagent
alwaysApply: true
dispatches:
  - pr_creator
---
# PR Creation: Dispatch to Subagent

## When This Applies

- /create, /create-develop, /create-dual, /create-branch
- "Create a PR", "Open a pull request"
- Any request involving PR creation or branch creation for PRs

## The Rule

**You MUST dispatch the `pr_creator` subagent.** Do NOT create PRs yourself.

The subagent has all PR creation commands, merge verification, conflict resolution, and health check patterns. You don't — and creating PRs without them leads to missing steps.

## How to Dispatch

```
Task tool:
  subagent_type: "pr_creator"
  prompt: |
    Create a PR:
    - Type: {create | create-develop | create-dual | create-branch}
    - Issue: {JIRA_ISSUE}
    - Any additional context from the user
```

## After Subagent Returns

1. Read the PR URL and summary
2. Present results to the user
3. If review loop is needed, use the pr-review-loop skill

## Does NOT Apply When

- Merging PRs → dispatch `merger` instead
- Reviewing PRs → dispatch `core_reviewer` instead
- Monitoring PR reviews → use pr-review-loop skill
- Rebasing/squashing → dispatch `merger` instead

## Red Flags — You Are Violating This Rule

- Running `gh pr create` yourself
- Writing PR descriptions without the subagent
- Checking merge compatibility yourself
- Skipping the subagent because "it's just a simple PR"

**All of these mean: STOP. Dispatch `pr_creator`.**
```

Write this to `rules/workaxle/core/dispatches/use-pr-creator.md`.

**Step 2: Verify file exists**

Run: `ls -la rules/workaxle/core/dispatches/use-pr-creator.md`
Expected: File exists with reasonable size (~1.2KB)

**Step 3: Commit**

```bash
git add rules/workaxle/core/dispatches/use-pr-creator.md
git commit -m "feat: add use-pr-creator dispatch rule for core profile slim-down"
```

---

### Task 2: Create the `pr-creator` profile in profiles.yml

**Files:**
- Modify: `profiles.yml` (add new profile after existing profiles)
- Modify: `~/.config/ruly/profiles.yml` (keep in sync)

**Step 1: Add pr-creator profile to profiles.yml**

Add this profile block after the `pr-review-loop:` profile (around line 821). Insert it before `context-jira:`:

```yaml
  pr-creator:
    description: "PR creation commands - create, create-develop, create-dual, create-branch"
    omit_command_prefix: github
    files:
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      - /Users/patrick/Projects/ruly/rules/github/pr/common.md
    commands:
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-branch.md
```

Note: `create.md` has `requires:` for `creating-prs.md`, `commands.md`, `context-common.md`, `health-checks-common.md`, `review-feedback-loop.md`, `create-branch.md`, `create-develop.md` — these will be pulled in transitively. The `pr-creator` profile can handle that weight because it's a subagent, not the orchestrator.

**Step 2: Copy the same change to ~/.config/ruly/profiles.yml**

The user config must be kept in sync. Copy the exact same `pr-creator:` block to `~/.config/ruly/profiles.yml`.

**Step 3: Verify YAML is valid**

Run: `ruby -ryaml -e "YAML.load_file('profiles.yml'); puts 'OK'"`
Expected: `OK`

**Step 4: Commit**

```bash
git add profiles.yml
git commit -m "feat: add pr-creator profile for PR creation subagent"
```

---

### Task 3: Inline comment resolution into pr-review-loop.md

**Files:**
- Modify: `rules/github/pr/skills/pr-review-loop.md`
- Reference (read-only): `rules/comms/github/pr/pr-comment-resolution.md`

**Step 1: Read `pr-comment-resolution.md` and identify essential content**

The file has these sections:
- **Comment Resolution Workflow** (lines ~18-75) — GraphQL for getting thread IDs and resolving threads. INLINE THIS.
- **Comment Types and Responses** (A, B, C) (lines ~77-165) — The three comment type patterns with GraphQL. INLINE THIS.
- **Finding Thread IDs** (lines ~167-193) — GraphQL query for thread IDs. INLINE THIS.
- **Response Patterns** (lines ~196-227) — Generic coding advice ("Consider extracting...", "This could be simplified..."). STRIP THIS — it's coding guidance that doesn't belong in a review loop skill.
- **Resolution Requirements** (lines ~229-237) — Summary of resolution rules. INLINE THIS.

**Step 2: Add the inlined content to pr-review-loop.md**

The pr-review-loop.md file already has a "Comment Resolution Workflow" section reference at line ~417 that says "For manual resolution if needed, see [Comment Resolution Workflow](#comment-resolution-workflow)."

Add the following section **at the end of pr-review-loop.md** (before the final `## Common Error Handling` section), replacing the dangling anchor reference:

```markdown
## Comment Resolution Workflow

### Getting PR Comments

**Use Claude's native command to fetch all PR comments:**

```
/pr-comments
```

This will retrieve all comments, review threads, and their current resolution status.

### When Addressing Review Comments

**Always follow this workflow when fixing issues raised in PR comments:**

1. **Fix the Issue**: Make the necessary code changes
2. **Commit with Clear Message**: Reference the issue being fixed
3. **Push the Changes**: Push to the PR branch
4. **Reply to Comment**: Reply with "Fixed in commit [short SHA]: [brief explanation]"
5. **Mark as Resolved**: Use GraphQL API to mark the thread as resolved

### Comment Types and Responses

#### A. Comments with Code Suggestions (Fixed)

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

#### B. Comments Without Code Suggestions (General Feedback)

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

#### C. Outdated or Irrelevant Comments

For comments that are no longer applicable:

```bash
# Reply noting the comment status
mcp__github__add_pull_request_review_comment with:
- owner: [REPO_OWNER]
- repo: [REPO_NAME]
- pull_number: [PR_NUMBER]
- in_reply_to: [COMMENT_ID]
- body: "This comment is now outdated/irrelevant due to [reason]"

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

### Finding Thread IDs for Comments

**Note:** Use Claude's `/pr-comments` command to easily get all PR comments and their thread information.

If you need to manually query thread IDs:

```bash
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

### Resolution Requirements

**CRITICAL**: Before starting the next loop iteration, ALL comments that have been replied to must be marked as resolved. This includes:

1. **Fixed Issues**: Comments where code has been changed → Reply with fix details + Mark resolved
2. **General Comments**: Comments without code suggestions → Reply acknowledging + Mark resolved
3. **Outdated Comments**: Comments no longer relevant → Reply noting outdated status + Mark resolved

**No exceptions**: Every comment type must be addressed and hidden to maintain clean PR state.
```

**Step 3: Update the frontmatter requires**

Change the frontmatter of `pr-review-loop.md` from:

```yaml
requires:
  - ../common.md
  - ../parallel-fix-orchestration.md
  - ../../../comms/github/pr/pr-comment-resolution.md
```

To:

```yaml
requires:
  - ../parallel-fix-orchestration.md
```

This removes both `common.md` (and its transitive `context-common.md`) and `pr-comment-resolution.md` (now inlined).

**Step 4: Verify the file is well-formed**

Run: `head -10 rules/github/pr/skills/pr-review-loop.md`
Expected: Frontmatter with only `parallel-fix-orchestration.md` in requires

Run: `grep -c "Comment Resolution Workflow" rules/github/pr/skills/pr-review-loop.md`
Expected: At least 2 (the reference and the new section)

**Step 5: Commit**

```bash
git add rules/github/pr/skills/pr-review-loop.md
git commit -m "refactor: inline comment resolution into pr-review-loop, remove common.md require"
```

---

### Task 4: Remove ralph/pattern.md require from ralph-loop.md

**Files:**
- Modify: `rules/github/pr/ralph-loop.md:1-5` (frontmatter)

**Step 1: Update the frontmatter**

Change from:

```yaml
---
description: Ralph loop adapted for PR review fix iterations - fresh agent per issue with persistent progress tracking
alwaysApply: false
requires:
  - ../../ralph/pattern.md
---
```

To:

```yaml
---
description: Ralph loop adapted for PR review fix iterations - fresh agent per issue with persistent progress tracking
alwaysApply: false
---
```

The adapted ralph-loop.md is self-contained. The generic `ralph/pattern.md` adds ~174 lines of conceptual background that's already incorporated into the adapted version.

**Step 2: Verify**

Run: `head -5 rules/github/pr/ralph-loop.md`
Expected: No `requires:` in frontmatter

**Step 3: Commit**

```bash
git add rules/github/pr/ralph-loop.md
git commit -m "refactor: remove ralph/pattern.md require from ralph-loop (self-contained)"
```

---

### Task 5: Update core profile — remove files, commands, skills, subagent

**Files:**
- Modify: `profiles.yml:10-94` (core profile)
- Modify: `~/.config/ruly/profiles.yml` (keep in sync)

**Step 1: Remove code pattern files from core profile**

Remove these three lines from the `files:` section:

```yaml
      # === WorkAxle Core ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      # === Essential (minimal for routing) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/development-commands.md
```

These stay in subagent profiles (core-engineer, core-debugger) which independently include them.

**Step 2: Remove bug-diagnose.md from files**

Remove this line from the `files:` section:

```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/bug-diagnose.md
```

**Step 3: Add use-pr-creator.md to files**

Add this line to the `files:` section, in the dispatch rules block:

```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-pr-creator.md
```

**Step 4: Remove rebase-and-squash from skills**

Remove this line from `skills:`:

```yaml
      # === Git Skills ===
      - /Users/patrick/Projects/ruly/rules/git/skills/rebase-and-squash.md
```

The merger profile already has this skill (confirmed at profiles.yml line 735).

**Step 5: Remove PR creation commands**

Remove these three lines from `commands:`:

```yaml
      # === PR Operations (orchestrator handles PR creation) ===
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
```

**Step 6: Remove bug_diagnose subagent, add pr_creator subagent**

Remove from `subagents:`:

```yaml
      - name: bug_diagnose
        profile: bug-diagnose
```

Add to `subagents:`:

```yaml
      - name: pr_creator
        profile: pr-creator
```

**Step 7: Verify the final core profile shape**

The core profile should now look like:

```yaml
  core:
    description: "WorkAxle development dispatcher - routes tasks to specialized subagents"
    omit_command_prefix:
      - comms/github
      - github
      - comms
    files:
      # === Reference (high-level codebase understanding) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/service-overview.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/technology-stack.md
      # === Dispatch Rules ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-core-debugger.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-core-engineer.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-core-debugging.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-comms.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-merger.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-dashboard.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-pr-readiness.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-reviewer.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-pr-review-loop.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-qa.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-context-grabber.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-pr-creator.md
      # === SDD Review Loop (spec compliance + code quality after engineer dispatches) ===
      - /Users/patrick/Projects/ruly/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md
      - /Users/patrick/Projects/ruly/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md
    skills:
      # === PR Operations ===
      - /Users/patrick/Projects/ruly/rules/github/pr/skills/pr-review-loop.md
    commands:
      # === Context Fetching (orchestrator handles context) ===
      - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
    subagents:
      - name: core_debugger
        profile: core-debugger
      - name: core_engineer
        profile: core-engineer
      - name: context_jira
        profile: context-jira
        model: haiku
      - name: context_github
        profile: context-github
        model: haiku
      - name: context_teams
        profile: context-teams
        model: haiku
      - name: context_summarizer
        profile: context-summarizer
        model: haiku
      - name: core_debugging
        profile: core-debugging
      - name: comms_jira
        profile: comms-jira
      - name: comms_teams
        profile: comms-teams
      - name: comms_mattermost
        profile: comms-mattermost
      - name: comms_github
        profile: comms-github
      - name: merger
        profile: merger
      - name: dashboard
        profile: dashboard
      - name: pr_readiness
        profile: pr-readiness
      - name: core_reviewer
        profile: core-reviewer
      - name: pr_review_loop
        profile: pr-review-loop
      - name: qa_tester
        profile: qa
      - name: pr_creator
        profile: pr-creator
```

**Step 8: Copy all changes to ~/.config/ruly/profiles.yml**

Apply the exact same modifications to `~/.config/ruly/profiles.yml`. Both files must be identical.

**Step 9: Verify YAML validity for both files**

Run: `ruby -ryaml -e "YAML.load_file('profiles.yml'); puts 'OK'"`
Expected: `OK`

Run: `ruby -ryaml -e "YAML.load_file(File.expand_path('~/.config/ruly/profiles.yml')); puts 'OK'"`
Expected: `OK`

**Step 10: Commit**

```bash
git add profiles.yml
git commit -m "refactor: slim core profile - remove code patterns, PR commands, bug-diagnose; add pr_creator"
```

---

### Task 6: Update use-core-debugger.md to absorb bug-diagnose triggers

**Files:**
- Modify: `rules/workaxle/core/dispatches/use-core-debugger.md`

**Step 1: Update the dispatch rule**

The current `use-core-debugger.md` needs to incorporate "production incidents" from `bug-diagnose.md`'s triggers. Change the "When This Applies" section from:

```markdown
## When This Applies

Any time you encounter or are asked to work on:
- A bug, error, or unexpected behavior
- Test failures that need investigation or fixing
- Data inconsistencies or corruption
- Performance issues
- Production incidents
- "Why is X happening?" or "X is broken" scenarios
```

Wait — it already has "Production incidents" at line 15. Let me check the current file more carefully.

Looking at the current `use-core-debugger.md`, it already covers all the triggers from `bug-diagnose.md`:
- Bug, error, unexpected behavior ✓
- Test failures ✓
- Data inconsistencies ✓
- Performance issues ✓
- Production incidents ✓

The main addition needed is to clarify that `core_debugger` handles **both diagnosis AND fixing** (since `bug_diagnose` was read-only diagnosis, while `core_debugger` does both):

Add this line to the description in the `## The Rule` section, after "The subagent has bug investigation workflows...":

Change from:
```markdown
The subagent has bug investigation workflows, debugging patterns, and can further dispatch to `bug_diagnose` (systematic root cause analysis). After diagnosis, dispatch `core_engineer` for implementation. You are a dispatcher — route the work.
```

To:
```markdown
The subagent has bug investigation workflows, systematic debugging (four-phase root cause analysis), and WorkAxle-specific debugging patterns. It handles the full lifecycle: diagnosis, root cause analysis, and dispatching fixes to `core_engineer`. You are a dispatcher — route the work.
```

**Step 2: Verify**

Run: `grep "systematic debugging" rules/workaxle/core/dispatches/use-core-debugger.md`
Expected: Match found

**Step 3: Commit**

```bash
git add rules/workaxle/core/dispatches/use-core-debugger.md
git commit -m "refactor: update use-core-debugger to cover full bug lifecycle (absorb bug-diagnose)"
```

---

### Task 7: Test squash in temp directory

**Files:**
- None modified (verification only)

**Step 1: Run squash for core profile**

```bash
cd $(mktemp -d) && ruly squash --profile core
```

Expected: Squash completes without errors.

**Step 2: Check output size**

```bash
wc -c CLAUDE.local.md
wc -l CLAUDE.local.md
```

Expected: Significantly smaller than the previous ~104KB / 3,151 lines. Target is ~50-55KB.

**Step 3: Verify key content is present**

```bash
# Dispatch rules should be present
grep -c "Dispatch to Subagent" CLAUDE.local.md

# PR creator dispatch should be present
grep "pr_creator" CLAUDE.local.md

# Code patterns should NOT be present
grep -c "Sequel ORM" CLAUDE.local.md  # Should be 0
grep -c "gRPC" CLAUDE.local.md  # Should be 0
grep -c "just test" CLAUDE.local.md  # Should be 0 (development-commands content)

# PR creation commands should NOT be present
grep -c "/create - Pull Request Creation" CLAUDE.local.md  # Should be 0

# Comment resolution should be in pr-review-loop section
grep -c "resolveReviewThread" CLAUDE.local.md  # Should be > 0

# bug_diagnose subagent should NOT be listed
grep "bug_diagnose" CLAUDE.local.md  # Should be 0 matches for subagent listing
```

**Step 4: Run stats**

```bash
ruly stats --profile core
```

Review the stats.md output for token counts per section.

**Step 5: Verify pr-creator profile squashes independently**

```bash
cd $(mktemp -d) && ruly squash --profile pr-creator
```

Expected: Squash succeeds, includes create commands and their transitive requires.

**Step 6: Verify merger profile still works**

```bash
cd $(mktemp -d) && ruly squash --profile merger
```

Expected: Squash succeeds, includes rebase-and-squash skill.

---

### Task 8: Final sync and push

**Files:**
- Verify: `~/.config/ruly/profiles.yml` matches `profiles.yml`
- Verify: `/Users/patrick/Projects/chezmoi/config/ruly/profiles.yml` matches too

**Step 1: Diff the profile files**

```bash
diff profiles.yml ~/.config/ruly/profiles.yml
diff profiles.yml /Users/patrick/Projects/chezmoi/config/ruly/profiles.yml
```

Expected: No differences (or only expected differences if chezmoi has its own additions).

**Step 2: Update installed ruly**

```bash
cd /Users/patrick/Projects/ruly && bundle exec rake install
```

Or if using mise:

```bash
mise install ruby
```

**Step 3: Push all commits**

```bash
git push
```
