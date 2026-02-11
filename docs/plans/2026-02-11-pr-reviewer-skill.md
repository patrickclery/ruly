# PR Reviewer Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a PR review skill that fetches context, verifies readiness gates, runs code review against WorkAxle standards, and guides interactive comment posting.

**Architecture:** A new skill file in `rules/github/pr/skills/` defines the review workflow. The context fetcher subagent gets an optional `--author` parameter for reviewing others' PRs. The existing `review` recipe is renamed to `reviewer` and wired to this skill plus WorkAxle coding standards.

**Tech Stack:** Ruly rules/skills, gh CLI, context fetcher subagent, superpowers:code-reviewer

---

### Task 1: Add `--author` Override to Context Fetcher Subagent

**Files:**
- Modify: `rules/comms/context-fetcher-subagent.md` (lines 28-31, 113-114)

**Step 1: Update Step 2 in the context fetcher to support an optional author parameter**

In `rules/comms/context-fetcher-subagent.md`, change Step 2 from hardcoded `--author @me` to a parameterized author:

Replace the Step 2 section (around lines 28-31):

```markdown
### Step 2: Find ALL related PRs

```bash
gh pr list --state all --author @me --limit 500 --json number,headRefName \
  --jq '.[] | select(.headRefName | test("{ISSUE}"; "i")) | .number'
```
```

With:

```markdown
### Step 2: Find ALL related PRs

```bash
gh pr list --state all --author {AUTHOR} --limit 500 --json number,headRefName \
  --jq '.[] | select(.headRefName | test("{ISSUE}"; "i")) | .number'
```

**Default:** `{AUTHOR}` is `@me` unless the dispatch prompt specifies a different author.

**Examples:**
- `"Fetch context for WA-12345"` → uses `--author @me`
- `"Fetch context for WA-12345 --author jdoe"` → uses `--author jdoe`
```

**Step 2: Update the example execution section**

Update the example (around lines 104-133) to show both default and override cases:

After the existing example, add:

```markdown
### Example: Reviewing Someone Else's PR

Prompt: "Fetch context for WA-15182 --author jdoe"

```bash
# Step 1: Fetch Jira FIRST
fetch-jira-details.sh -O ~/tmp/context/WA-15182 WA-15182

# Step 2: Find ALL PRs by specified author
gh pr list --state all --author jdoe --limit 500 --json number,headRefName \
  --jq '.[] | select(.headRefName | test("WA-15182"; "i")) | .number'

# Steps 3-6: Same as default
```
```

**Step 3: Commit**

```bash
git add rules/comms/context-fetcher-subagent.md
git commit -m "feat: add --author override to context fetcher subagent

Defaults to @me, but accepts --author {username} in dispatch prompt
for reviewing other people's PRs."
```

---

### Task 2: Create the Reviewing PRs Skill

**Files:**
- Create: `rules/github/pr/skills/reviewing-prs.md`

**Step 1: Write the skill file**

Create `rules/github/pr/skills/reviewing-prs.md` with the full workflow:

```markdown
---
name: reviewing-prs
description: Use when reviewing a PR — fetches context, verifies readiness, runs code review against WorkAxle standards, and guides interactive comment posting
requires:
  # PR workflow
  - ../common.md
  - ./verify-pr-readiness.md
  - ./creating-prs.md
  - ../../comms/use-context-fetcher.md
  - ../../comms/jira/statuses.md
  # WorkAxle architecture & runtime
  - ../../workaxle/core/standards/code-patterns.md
  - ../../workaxle/core/standards/architecture-patterns.md
  - ../../workaxle/core/standards/runtime-concerns.md
  # WorkAxle frameworks
  - ../../workaxle/core/frameworks/monads.md
  - ../../workaxle/core/frameworks/ruby-practices.md
  - ../../workaxle/core/frameworks/sequel.md
  # WorkAxle Ruby standards
  - ../../workaxle/core/frameworks/standards/code-style-guidelines.md
  - ../../workaxle/core/frameworks/standards/constants-configuration.md
  - ../../workaxle/core/frameworks/standards/duck-typing-polymorphism.md
  - ../../workaxle/core/frameworks/standards/error-handling.md
  - ../../workaxle/core/frameworks/standards/guard-clauses-early-returns.md
  - ../../workaxle/core/frameworks/standards/instance-variables-memoization.md
  - ../../workaxle/core/frameworks/standards/iteration-enumeration.md
  - ../../workaxle/core/frameworks/standards/method-chaining-fluent-interfaces.md
  - ../../workaxle/core/frameworks/standards/module-composition.md
  - ../../workaxle/core/frameworks/standards/ruby-3-features.md
---

# Reviewing PRs

## Workflow

### Step 1: Receive PR

Accept a PR number, GitHub URL, or `owner/repo#number`. Extract the PR number.

### Step 2: Quick Metadata Fetch

Run a lightweight `gh pr view` to get routing info only:

```bash
gh pr view {PR_NUMBER} --json headRefName,author,title --jq '{branch: .headRefName, author: .author.login, title: .title}'
```

Extract:
- **Jira key** from `headRefName` using regex: `/([A-Z]+-\d+)/`
- **Author login** for context fetcher dispatch

If no Jira key found in the branch name, ask the user for the ticket key.

### Step 3: Fetch Full Context

Dispatch the context_fetcher subagent with the extracted issue key and the PR author:

```
Task tool:
  subagent_type: "context_fetcher"
  prompt: "Fetch context for {ISSUE} --author {AUTHOR}"
```

Then read ALL context files:
- `~/tmp/context/{ISSUE}/jira-{ISSUE}.toon`
- `~/tmp/context/{ISSUE}/pull-request-{PR_NUMBER}.toon`
- All sibling `pull-request-*.toon` files

### Step 4: Verify PR Readiness

Run the [Definition of Ready](#definition-of-ready-requesting-review) checks from the verify-pr-readiness skill.

**If any gate fails:** HALT. Show the user exactly what's blocking:
- Which gate failed
- Current value vs required value
- What needs to happen before review can proceed

**Do NOT continue to code review if readiness gates fail.**

### Step 5: Code Review

Fetch the diff directly via `gh pr diff` (the `.toon` file does not include the diff or commit SHAs), then dispatch the `superpowers:code-reviewer` subagent:

```bash
gh pr diff {PR_NUMBER}
```

```
Task tool:
  subagent_type: "code-reviewer"
  prompt: |
    Review PR #{PR_NUMBER}: {TITLE}

    WHAT_WAS_IMPLEMENTED: {PR title and description from .toon file}
    PLAN_OR_REQUIREMENTS: WorkAxle coding standards (architecture patterns, code patterns, runtime concerns, Ruby standards, Sequel patterns, monads)
    DESCRIPTION: {PR body/description from .toon}

    Fetch the diff with: gh pr diff {PR_NUMBER}

    Pay special attention to:
    - Sequel patterns (NOT ActiveRecord)
    - Soft-delete handling (.not_deleted, company dataset associations)
    - dry-monads do notation and App:: failure types
    - AASM state transitions (never direct assignment)
    - dry-container compatible initializers (no params)
    - Multi-tenant isolation (company scoping)
    - Feature flag testing (BOTH enabled and disabled states)
    - Blue-green safe migrations
    - Batch processing for large datasets
```

### Step 6: Review Summary

Present the code-reviewer's findings in a structured format:

```
## PR Review Summary: #{PR_NUMBER}

### Readiness Gates: PASSED

### Strengths
[From code-reviewer output]

### Issues

#### Critical (Must Fix)
[File:line references with WorkAxle standard violated]

#### Important (Should Fix)
[File:line references with explanation]

#### Minor (Nice to Have)
[Suggestions]

### Assessment
[Ready to approve / Request changes / Comment only]
```

### Step 7: Interactive Comment Posting

For each finding from the review, prompt the user one at a time:

```
**Finding 1/N:** [severity] [file:line]
[Description of issue]

Draft comment:
> [Suggested comment text]

Action? (comment / edit / skip / stop)
```

- **comment** — Post the draft as-is via `gh api`
- **edit** — Let the user modify the comment text, then post
- **skip** — Move to next finding
- **stop** — End comment posting

#### Posting Comments

Use `gh api` to post review comments on specific lines:

```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments \
  --field body="{COMMENT}" \
  --field commit_id="{HEAD_SHA}" \
  --field path="{FILE_PATH}" \
  --field line={LINE_NUMBER} \
  --field side="RIGHT"
```

### Step 8: Submit Review

After all findings are processed (or stopped), ask:

```
All comments posted. Submit the review?

1. Approve
2. Request changes
3. Comment only (no verdict)
4. Skip (don't submit a review)
```

Submit via:

```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews \
  --field event="{APPROVE|REQUEST_CHANGES|COMMENT}" \
  --field body="{SUMMARY}"
```
```

**Step 2: Commit**

```bash
git add rules/github/pr/skills/reviewing-prs.md
git commit -m "feat: add reviewing-prs skill

Workflow: receive PR → fetch context → verify readiness → code review
against WorkAxle standards → interactive comment posting → submit review"
```

---

### Task 3: Rename `review` Recipe to `reviewer` and Wire New Skill

**Files:**
- Modify: `recipes.yml` (lines 277-285)
- Modify: `/Users/patrick/Projects/chezmoi/config/ruly/recipes.yml` (same section)

**Step 1: Replace the `review` recipe with `reviewer` in `recipes.yml`**

Replace lines 277-285:

```yaml
  review:
    description: "WorkAxle final review and QA stage"
    files:
      - /Users/patrick/Projects/ruly/rules/comms/jira/commands/comment.md
      - /Users/patrick/Projects/ruly/rules/comms/ms-teams/commands/dm.md
      - /Users/patrick/Projects/ruly/rules/github/pr/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/
    mcp_servers:
      - atlassian # For Confluence page creation only (Jira uses CLI)
```

With:

```yaml
  reviewer:
    description: "WorkAxle PR code review — readiness gates, standards enforcement, interactive commenting"
    files:
      # === New reviewing skill (pulls in all requires: dependencies) ===
      - /Users/patrick/Projects/ruly/rules/github/pr/skills/reviewing-prs.md
      # === Context fetching ===
      - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
      - /Users/patrick/Projects/ruly/rules/comms/context-fetcher-subagent.md
      # === PR common ===
      - /Users/patrick/Projects/ruly/rules/github/pr/common.md
      # === Superpowers code-reviewer ===
      - /Users/patrick/Projects/ruly/superpowers/skills/requesting-code-review/SKILL.md
      - /Users/patrick/Projects/ruly/superpowers/skills/requesting-code-review/code-reviewer.md
    subagents:
      - name: context_fetcher
        recipe: context-fetcher
```

**Step 2: Apply the exact same change to the chezmoi config**

Replace the same `review:` block in `/Users/patrick/Projects/chezmoi/config/ruly/recipes.yml` with the identical `reviewer:` block.

**Step 3: Verify no other recipes reference the old `review` name**

Search for `recipe: review` in both recipe files to ensure nothing dispatches to the old name.

**Step 4: Commit**

```bash
git add recipes.yml
git commit -m "feat: rename review recipe to reviewer, wire reviewing-prs skill

Replaces the old review recipe (QA stage) with a focused PR code
review recipe including readiness gates, WorkAxle standards, and
interactive commenting via superpowers:code-reviewer."
```

Note: The chezmoi config is in a separate repo and should be committed there separately.

---

### Task 4: Update the Rules Submodule and Push

**Step 1: Commit the rules submodule changes**

The context fetcher update and new skill are in the `rules/` submodule:

```bash
cd rules/
git add comms/context-fetcher-subagent.md github/pr/skills/reviewing-prs.md
git commit -m "feat: add reviewing-prs skill and --author override for context fetcher"
git push
cd ..
```

**Step 2: Update submodule reference in parent repo**

```bash
git add rules
git commit -m "feat: update rules submodule with reviewing-prs skill"
git push
```

**Step 3: Update chezmoi config**

```bash
cd /Users/patrick/Projects/chezmoi
# The recipes.yml change was already made in Task 3
git add config/ruly/recipes.yml
git commit -m "feat: rename review recipe to reviewer"
git push
cd /Users/patrick/Projects/ruly
```

---

### Task 5: Verify

**Step 1: Test squash in temp directory**

```bash
cd $(mktemp -d)
ruly squash --recipe reviewer
```

Expected: Squash completes without errors, output includes the reviewing-prs skill content and all `requires:` dependencies.

**Step 2: Verify the skill appears in squashed output**

Check that the squashed output contains:
- "Reviewing PRs" heading
- "Definition of Done" (from verify-pr-readiness)
- "Code Patterns" (from WorkAxle standards)
- "Architecture Patterns"
- "Sequel" patterns
- Code-reviewer template sections

**Step 3: Verify context fetcher still works with default author**

Check that the context fetcher subagent instructions still default to `@me` when no `--author` is specified.
