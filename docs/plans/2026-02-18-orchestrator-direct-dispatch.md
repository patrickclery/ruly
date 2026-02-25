# Orchestrator Direct Dispatch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate the double-dispatch pattern (orchestrator → core → core_engineer) by having the orchestrator dispatch directly to specialized subagents, while keeping `core` unchanged as a standalone profile.

**Architecture:** Currently, `orchestrator` dispatches to `core`, which is itself a dispatcher that routes to 11 subagents. This means backend work goes through two dispatch layers. The fix: promote all of `core`'s dispatch rules and subagents into `orchestrator` directly, so `orchestrator` routes to `core_engineer`, `core_debugger`, etc. without the intermediate `core` layer. `core` remains unchanged for standalone backend-only use.

**Tech Stack:** Ruly profile YAML configuration, markdown dispatch rules

---

## Current vs Target Architecture

```
CURRENT:
  orchestrator → core (dispatcher) → core_engineer
                                   → core_debugger
                                   → comms
                                   → merger
                                   → ...
               → frontend (dispatcher) → frontend_engineer
                                       → comms
                                       → merger
                                       → ...
               → qa
               → comms

TARGET:
  orchestrator → core_engineer (direct)
               → core_debugger (direct)
               → core_debugging (direct)
               → core_architect (direct)
               → frontend (dispatcher) → frontend_engineer → ...
               → comms (direct)
               → merger (direct)
               → dashboard (direct)
               → pr_readiness (direct)
               → reviewer (direct)
               → pr_review_loop (direct)
               → qa_tester (direct)
               → context_fetcher (direct)
```

The `core` profile stays exactly as-is for standalone use (`ruly squash --profile core`).

---

### Task 1: Update orchestrator dispatch.md

**Files:**
- Modify: `rules/workaxle/orchestrator/dispatch.md`

**Step 1: Read the current dispatch.md**

Already read — it's at `rules/workaxle/orchestrator/dispatch.md` (33 lines). Currently routes to `core`, `frontend`, `qa` with a simple signal table.

**Step 2: Rewrite dispatch.md with direct routing**

Replace the entire content with:

```markdown
---
description: Routes tasks directly to specialized subagents based on work domain and task type
alwaysApply: true
---
# Orchestrator Dispatch Rules

You are a lightweight dispatcher. Route ALL work to the appropriate subagent. **Never do implementation work yourself.**

## Backend Routing

| Signal | Dispatch to |
|--------|-------------|
| Bug, error, unexpected behavior, test failure, "X is broken" | `core_debugger` |
| Feature implementation, code changes, TDD | `core_engineer` |
| Architecture design, "where should this go", new patterns | `core_architect` |
| "How do I debug X", debugging techniques, inspection | `core_debugging` |

## Frontend Routing

| Signal | Dispatch to |
|--------|-------------|
| React, TypeScript, components, UI, styling, GraphQL queries | `frontend` |

## Cross-Cutting Routing

| Signal | Dispatch to |
|--------|-------------|
| Jira comment, Teams DM, Mattermost DM, review request, bug report | `comms` |
| Squash-and-merge, merge-to-develop, deploy, update branches | `merger` |
| "Show my open PRs", PR status overview, dashboard | `dashboard` |
| "Is this PR ready?", readiness check, definition of done | `pr_readiness` |
| Review someone's PR, code review | `reviewer` |
| Review feedback loop, monitor PR for reviews | `pr_review_loop` |
| Acceptance testing, QA, verify AC on dev | `qa_tester` |
| Cross-service or unclear | Ask the user which service is primary |

## How to Dispatch

```
Task tool:
  subagent_type: "{subagent_name}"
  prompt: |
    [Pass the user's full request with all context]
```

## Rules

- **Never do implementation work yourself** — always dispatch
- **Never load or read code** — the subagents have the right context
- If the user's request spans both backend and frontend, dispatch both in parallel
- Pass the user's request verbatim — don't summarize or interpret
- For backend work, route to the specific subagent (core_engineer, core_debugger, etc.) — NOT to a generic "core" dispatcher
```

**Step 3: Verify the file is valid markdown with proper frontmatter**

Run: `head -5 rules/workaxle/orchestrator/dispatch.md`
Expected: YAML frontmatter with `description:` and `alwaysApply: true`

**Step 4: Commit**

```bash
git add rules/workaxle/orchestrator/dispatch.md
git commit -m "refactor: update orchestrator dispatch to route directly to specialized subagents"
```

---

### Task 2: Update orchestrator profile in profiles.yml

**Files:**
- Modify: `profiles.yml` (lines 389-401)
- Modify: `~/.config/ruly/profiles.yml` (same section — must stay identical)

**Step 1: Read the current orchestrator profile definition**

Current (lines 389-401 of profiles.yml):
```yaml
orchestrator:
  description: "WorkAxle multi-service dispatcher - routes to core and frontend subagents"
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/orchestrator/dispatch.md
  subagents:
    - name: core
      profile: core
    - name: frontend
      profile: frontend
    - name: qa
      profile: qa
    - name: comms
      profile: comms
```

**Step 2: Replace the orchestrator profile with expanded version**

The new profile should include:
1. The updated dispatch.md (already there)
2. WorkAxle core essentials (for context, same as core profile lines 17-24)
3. All dispatch rules from core profile (lines 26-36) — the `use-*.md` files
4. PR operations from core profile (lines 38-41)
5. Git skills from core profile (line 43)
6. Context fetching from core profile (lines 45-46)
7. All subagents from core profile (lines 48-71) PLUS frontend and qa

Replace lines 389-401 with:

```yaml
  orchestrator:
    description: "WorkAxle multi-service dispatcher - routes directly to specialized subagents"
    omit_command_prefix:
      - comms/github
      - github
      - comms
    files:
      # === Orchestrator Dispatch ===
      - /Users/patrick/Projects/ruly/rules/workaxle/orchestrator/dispatch.md
      # === WorkAxle Core Context (for understanding routing signals) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/development-commands.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/service-overview.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/technology-stack.md
      # === Backend Dispatch Rules ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-core-debugger.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-core-engineer.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-core-debugging.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-core-architect.md
      # === Cross-Cutting Dispatch Rules ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-comms.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-merger.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-dashboard.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-pr-readiness.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-reviewer.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-pr-review-loop.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-qa.md
      # === PR Operations ===
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
      - /Users/patrick/Projects/ruly/rules/github/pr/skills/pr-review-loop.md
      # === Git Skills ===
      - /Users/patrick/Projects/ruly/rules/git/skills/rebase-and-squash.md
      # === Context Fetching ===
      - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
      - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
    subagents:
      # === Backend Subagents (promoted from core) ===
      - name: core_debugger
        profile: core-debugger
      - name: core_engineer
        profile: core-engineer
      - name: core_debugging
        profile: core-debugging
      - name: core_architect
        profile: core-architect
      # === Frontend Subagent ===
      - name: frontend
        profile: frontend
      # === Cross-Cutting Subagents (promoted from core) ===
      - name: context_fetcher
        profile: context-fetcher
      - name: comms
        profile: comms
      - name: merger
        profile: merger
      - name: dashboard
        profile: dashboard
      - name: pr_readiness
        profile: pr-readiness
      - name: reviewer
        profile: reviewer
      - name: pr_review_loop
        profile: pr-review-loop
      - name: qa_tester
        profile: qa
```

**Step 3: Apply the same change to `~/.config/ruly/profiles.yml`**

The two files must be identical (per CLAUDE.md: "they should be identical").

**Step 4: Verify both files are identical**

Run: `diff profiles.yml ~/.config/ruly/profiles.yml`
Expected: No output (files are identical)

**Step 5: Commit**

```bash
git add profiles.yml
git commit -m "refactor: orchestrator dispatches directly to specialized subagents

Promotes all core subagents (core_engineer, core_debugger, comms, merger, etc.)
to orchestrator level, eliminating the double-dispatch pattern where orchestrator
dispatched to core which then dispatched to the actual workers."
```

---

### Task 3: Test the squashed output

**Step 1: Create temp directory and squash the orchestrator profile**

Run:
```bash
cd $(mktemp -d) && ruly squash --profile orchestrator
```

Expected: Squashed output containing:
- Orchestrator dispatch rules with direct routing table
- All `use-*.md` dispatch rules (use-core-engineer, use-comms, use-merger, etc.)
- PR commands (create, create-develop, create-dual)
- Context fetching rules
- All subagent definitions in the output

**Step 2: Verify the squashed output does NOT contain a `core` subagent**

Run: `grep -c 'subagent_type.*core"' CLAUDE.local.md` (or whatever the output file is)

The word "core" should only appear in `core_engineer`, `core_debugger`, `core_debugging`, `core_architect` — NOT as a standalone `core` subagent.

**Step 3: Verify the `core` profile still squashes correctly (unchanged)**

Run:
```bash
cd $(mktemp -d) && ruly squash --profile core
```

Expected: Same output as before — all 11 subagents, all dispatch rules, all PR commands.

**Step 4: Run `ruly stats` to compare token counts**

Run: `ruly stats`

Note the token counts for both `orchestrator` and `core`. The orchestrator will be larger now (it includes dispatch rules that were previously hidden inside core), but this is correct — the total context when working is smaller because we eliminated one dispatch layer.

---

### Task 4: Update the installed ruly binary

**Step 1: Rebuild ruly**

Run: `mise install ruby`

This ensures the installed `ruly` binary at `/Users/patrick/.local/share/mise/installs/ruby/3.3.3/bin/ruly` is up to date.

---

## Summary of Changes

| File | Change |
|------|--------|
| `rules/workaxle/orchestrator/dispatch.md` | Rewritten with direct routing to all specialized subagents |
| `profiles.yml` | Orchestrator profile expanded with dispatch rules, PR ops, and all subagents |
| `~/.config/ruly/profiles.yml` | Mirror of profiles.yml |

| What stays the same | Why |
|---------------------|-----|
| `core` profile | Still works standalone for backend-only sessions |
| All subagent profiles | No changes to core-engineer, core-debugger, comms, etc. |
| All dispatch rule files | Reused by both core and orchestrator profiles |

**Key insight:** The `use-*.md` dispatch rule files are shared — both `core` and `orchestrator` include them. This is DRY: the rules are authored once and consumed by both dispatcher profiles.
