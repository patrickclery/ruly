# Core Recipe Slim-Down

## Problem

The core orchestrator recipe squashes to ~104KB (3,151 lines). The orchestrator is a pure dispatcher — it never writes code — yet it loads Sequel ORM patterns, testing rules, and deep `requires:` chains from PR creation commands and skills. The `create.md` command alone pulls in 7 transitive dependencies including merge verification, conflict resolution, and health checks.

**Root causes:**
1. Code patterns (`core.md`, `common.md`, `development-commands.md`) loaded for a non-coding orchestrator
2. `requires:` chains from commands/skills cascade into execution details that belong in subagents
3. Three overlapping bug dispatch rules with near-identical triggers
4. PR creation commands with heavy transitive dependencies loaded directly into orchestrator

## Changes

### 1. Remove code patterns from core recipe

Remove from `files:`:
- `core.md` (452 tokens) — Sequel ORM basics, testing rules, error returns
- `common.md` (573 tokens) — Extended patterns (gRPC, soft-delete, persistence checks)
- `development-commands.md` (402 tokens) — `just` commands reference

These stay in subagent recipes (`core-engineer`, `core-debugger`, etc.) which independently include them.

**Savings: ~1,427 tokens**

### 2. New pr_creator subagent

Move PR creation commands and their full `requires:` chains to a new subagent:

**New recipe: `pr-creator`**
- Commands: `create.md`, `create-develop.md`, `create-dual.md`, `create-branch.md`
- Inherits all transitive requires: `creating-prs.md`, `commands.md`, `context-common.md`, `health-checks-common.md`, `verifying-merge-compatibility.md`, `conflict-resolution.md`, `verify-develop-mergability.md`, `review-feedback-loop.md`

**New dispatch rule: `use-pr-creator.md`**

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

**You MUST dispatch the `pr_creator` subagent.**

## How to Dispatch

Task tool:
  subagent_type: "pr_creator"
  prompt: |
    Create a PR:
    - Type: {create | create-develop | create-dual | create-branch}
    - Issue: {JIRA_ISSUE}
    - Any additional context

## Does NOT Apply When

- Merging PRs → dispatch `merger` instead
- Reviewing PRs → dispatch `core_reviewer` instead
- Monitoring PR reviews → use pr-review-loop skill
```

**Core recipe changes:**
```yaml
# REMOVE from commands:
- create.md
- create-develop.md
- create-dual.md

# ADD to files:
- use-pr-creator.md

# ADD to subagents:
- name: pr_creator
  recipe: pr-creator
```

**Savings: ~6,500+ tokens of transitive requires**

### 3. Move rebase-and-squash to merger

Remove from core recipe `skills:`:
- `rebase-and-squash.md` (+ transitive `resolving-merge-conflicts.md`)

Add to merger recipe `skills:`:
- `rebase-and-squash.md`

No new dispatch rule needed — `use-merger.md` already routes squash/merge/rebase work.

**Savings: ~800 tokens**

### 4. Slim pr-review-loop skill

Remove transitive dependencies that bloat the core recipe:

**Changes to `pr-review-loop.md`:**
```yaml
requires:
  - ../parallel-fix-orchestration.md   # KEEP (core mechanic)
  # REMOVE: ../common.md (and its transitive context-common.md)
  # REMOVE: ../../../comms/github/pr/pr-comment-resolution.md
```

Inline the essential GraphQL snippets from `pr-comment-resolution.md` directly into `pr-review-loop.md` (the comment type handling and resolution workflow). Strip the generic "Response Patterns" section (coding advice).

**Changes to `ralph-loop.md`:**
```yaml
requires:
  # REMOVE: ../../ralph/pattern.md (generic pattern — redundant with the adapted version)
```

The adapted `ralph-loop.md` already contains everything the review loop needs. The generic `ralph/pattern.md` adds ~174 lines of conceptual background.

**Savings: ~3,000+ tokens**

### 5. Merge bug dispatch rules

Remove `bug-diagnose.md` from the core recipe's dispatch rules. The triggers overlap almost entirely with `use-core-debugger.md`:

| Rule | Trigger |
|---|---|
| `use-core-debugger.md` | Bug, error, test failure, "X is broken" |
| `bug-diagnose.md` | Bug, error, test failure, production incident |

The `core_debugger` subagent already internally dispatches `bug_diagnose` when it needs diagnosis. Having both dispatch rules at the orchestrator level creates ambiguity.

Keep `use-core-debugging.md` — it's distinct (debugging TECHNIQUES, not specific bugs).

Update `use-core-debugger.md` to mention that it covers both investigation and fixing (incorporating the bug-diagnose trigger scenarios).

**Savings: ~395 tokens**

Remove `bug_diagnose` from core recipe's subagent list (it's a sub-subagent of `core_debugger`, not directly dispatched by the orchestrator).

## Final Core Recipe Shape

```yaml
core:
  description: "WorkAxle development dispatcher - routes tasks to specialized subagents"
  files:
    # Reference (high-level understanding only)
    - service-overview.md
    - technology-stack.md
    # Dispatch rules
    - use-core-debugger.md         # Bug investigation + fixing
    - use-core-engineer.md         # Implementation work + SDD review loop
    - use-core-debugging.md        # Debugging techniques
    - use-comms.md                 # Communication (Jira, Teams, Mattermost, GitHub)
    - use-merger.md                # Merging & deployment
    - use-dashboard.md             # PR dashboard
    - use-pr-readiness.md          # PR readiness verification
    - use-reviewer.md              # PR code review
    - use-pr-review-loop.md        # PR review feedback loop
    - use-qa.md                    # QA testing
    - use-context-grabber.md       # Context fetching enforcement
    - use-pr-creator.md            # PR creation (NEW)
    # SDD review templates
    - spec-reviewer-prompt.md
    - code-quality-reviewer-prompt.md
  skills:
    - pr-review-loop.md            # Slimmed (no common.md, no ralph/pattern.md, comment resolution inlined)
  commands:
    - refresh-context.md           # Context refresh (pulls in context-fetching.md)
  subagents:
    - name: core_debugger
      recipe: core-debugger
    - name: core_engineer
      recipe: core-engineer
    - name: context_jira
      recipe: context-jira
      model: haiku
    - name: context_github
      recipe: context-github
      model: haiku
    - name: context_teams
      recipe: context-teams
      model: haiku
    - name: context_summarizer
      recipe: context-summarizer
      model: haiku
    - name: core_debugging
      recipe: core-debugging
    - name: comms_jira
      recipe: comms-jira
    - name: comms_teams
      recipe: comms-teams
    - name: comms_mattermost
      recipe: comms-mattermost
    - name: comms_github
      recipe: comms-github
    - name: merger
      recipe: merger
    - name: dashboard
      recipe: dashboard
    - name: pr_readiness
      recipe: pr-readiness
    - name: core_reviewer
      recipe: core-reviewer
    - name: pr_review_loop
      recipe: pr-review-loop
    - name: qa_tester
      recipe: qa
    - name: pr_creator             # NEW
      recipe: pr-creator
```

## Estimated Impact

| Metric | Before | After | Savings |
|---|---|---|---|
| Direct file tokens | 10,388 | ~8,200 | ~2,200 |
| Squashed output size | ~104KB | ~50-55KB | ~50% |
| Transitive requires | ~60KB | ~15KB | ~75% |
| Subagent count | 18 | 18 (replace bug_diagnose with pr_creator) | net zero |

## Implementation Steps

1. Create `use-pr-creator.md` dispatch rule
2. Create `pr-creator` recipe in `recipes.yml`
3. Inline comment resolution GraphQL into `pr-review-loop.md`
4. Remove `requires:` for `common.md`, `pr-comment-resolution.md` from `pr-review-loop.md`
5. Remove `requires: ralph/pattern.md` from `ralph-loop.md`
6. Add `rebase-and-squash` skill to merger recipe
7. Update core recipe: remove files, commands, skills; add dispatch rule + subagent
8. Remove `bug-diagnose.md` dispatch rule; update `use-core-debugger.md` to cover all bug triggers
9. Update both `recipes.yml` files (project + user config)
10. Test squash in temp directory: `cd $(mktemp -d) && ruly squash --recipe core`
11. Verify subagent recipes still work independently
