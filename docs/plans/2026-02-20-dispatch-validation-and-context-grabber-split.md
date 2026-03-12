# Dispatch Validation & Context-Grabber Split

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent subagent recipes from including dispatch rules they can't execute, and split the monolithic `context-grabber` into source-specific subagents.

**Architecture:** Add `dispatches:` frontmatter to files that dispatch subagents. Validate during `ruly squash` that (1) standalone recipes register all dispatched types as subagents, and (2) subagent recipes never contain dispatch instructions. Split `context-grabber` into `context-jira`, `context-github`, `context-teams`, and `context-summarizer`. Move all `use-*.md` dispatch rules into `dispatches/` directories under their dispatcher domain.

**Tech Stack:** Ruby (ruly gem), Markdown rules, YAML recipes

---

## Part 1: `dispatches:` Frontmatter

Any markdown rule file that contains instructions to dispatch a subagent via the Task tool must declare this in YAML frontmatter:

```yaml
---
dispatches:
  - context_jira
  - context_github
---
```

Values are subagent names (the `name:` field from the parent recipe's `subagents:` list). Collected transitively through `requires:` chains.

## Part 2: Validation

### Validation 1: Standalone recipe dispatch check

After processing all sources, compare collected `dispatches:` against the recipe's registered `subagents:`. Error if any dispatched type is not registered.

```
$ ruly squash core-reviewer

ERROR: Recipe 'core-reviewer' dispatches: context_grabber
       but does not register it as a subagent.
       Add to recipe:
         subagents:
           - name: context_grabber
             recipe: context-grabber
```

### Validation 2: Subagent recipe dispatch check

During `process_subagents`, if any file in the subagent recipe has `dispatches:`, error immediately.

```
$ ruly squash core

ERROR: Subagent 'core_reviewer' (recipe: core-reviewer)
contains files that dispatch other subagents:

  - reviewing-prs.md dispatches: context_grabber
  - use-context-grabber.md dispatches: context_grabber

Subagents cannot dispatch other subagents.
Remove these files from the recipe, or inline
the functionality without subagent dispatch.
```

Order: Validation 1 runs first (main recipe), Validation 2 runs during subagent generation.

## Part 3: Move Dispatch Rules to `dispatches/` Directories

Dispatch rules (`use-*.md`) move out of `standards/` into dedicated `dispatches/` directories. Only dispatcher domains get them — `comms` is a subagent, not a dispatcher.

```
rules/
├── workaxle/core/dispatches/
│   ├── use-core-engineer.md
│   ├── use-core-debugger.md
│   ├── use-core-debugging.md
│   ├── use-core-architect.md
│   ├── use-comms.md
│   ├── use-merger.md
│   ├── use-dashboard.md
│   ├── use-pr-readiness.md
│   ├── use-reviewer.md
│   ├── use-pr-review-loop.md
│   ├── use-qa.md
│   ├── use-context-grabber.md    (moved from comms/)
│   ├── bug-diagnose.md
│   └── bug-fix.md
└── workaxle/frontend/dispatches/
    └── use-frontend-engineer.md  (moved from frontend/standards/)
```

## Part 4: Split context-grabber Into Source-Specific Recipes

### Current (monolithic)

```
core dispatches → context_grabber (orchestrates everything internally)
                    ├── downloads Jira    (inline skill)
                    ├── downloads GitHub  (inline skill)
                    ├── downloads Teams   (inline skill)
                    └── summarizes        (inline skill)
```

### Proposed (split)

```
core dispatches → context_jira       (fetch Jira details)
               → context_github      (fetch GitHub PRs)
               → context_teams       (search Teams threads)
               → context_summarizer  (read .toon files, produce summary)
```

### New recipes

```yaml
context-jira:
  description: "Downloads Jira ticket details"
  files:
    - rules/comms/context/skills/context-downloader-jira.md

context-github:
  description: "Downloads GitHub PR details for a ticket"
  files:
    - rules/comms/context/skills/context-downloader-github.md

context-teams:
  description: "Searches Teams threads for ticket/PR references"
  files:
    - rules/comms/context/skills/context-downloader-teams.md
  mcp_servers:
    - teams

context-summarizer:
  description: "Reads cached .toon files and produces ticket summary"
  files:
    - rules/comms/context/skills/context-summarizer.md
```

### Deleted

- `context-grabber` recipe
- `comms/context/agents/context-grabber.md` (orchestration moves to dispatch rule)
- All mattermost downloader references

## Part 5: Rewritten `use-context-grabber.md` Dispatch Rule

Lives at `workaxle/core/dispatches/use-context-grabber.md`. Only loaded by dispatcher recipes.

```yaml
---
dispatches:
  - context_jira
  - context_github
  - context_teams
  - context_summarizer
alwaysApply: true
---
```

Orchestration flow:

1. Check cache: `check-cache-freshness.sh ~/tmp/context/{ISSUE}`
2. Phase A — Parallel (Jira + GitHub): dispatch `context_jira` + `context_github` in a single message
3. Phase B — Teams (needs PR numbers): dispatch `context_teams` with PR numbers from GitHub result
4. Phase C — Summarize: dispatch `context_summarizer`
5. Write cache manifest: `write-cache-manifest.sh ~/tmp/context/{ISSUE}`

Selective refresh: `STALE: pr` → only `context_github` + `context_summarizer`. `STALE: jira` → only `context_jira` + `context_summarizer`.

Hard stop rules carry over — agents must never run `gh pr view`, `jira issue view`, etc. directly.

## Part 6: Recipe Impact

### Dispatcher recipes — replace context_grabber with 4 subagents

| Recipe | Change |
|--------|--------|
| `core` | Replace `context_grabber` with `context_jira`, `context_github`, `context_teams`, `context_summarizer` |
| `orchestrator` | Same replacement |
| `auth0` | Same replacement |

### Dispatcher recipes — update dispatch rule path

| Recipe | Old path | New path |
|--------|----------|----------|
| `core` | `comms/use-context-grabber.md` | `workaxle/core/dispatches/use-context-grabber.md` |
| `orchestrator` | `comms/use-context-grabber.md` | `workaxle/core/dispatches/use-context-grabber.md` |
| `auth0` | `comms/use-context-grabber.md` | `workaxle/core/dispatches/use-context-grabber.md` |

### Subagent recipes — remove dispatch rules, inline context fetching

| Recipe | File | Fix |
|--------|------|-----|
| `core-reviewer` | `reviewing-prs.md` | Inline: run fetch scripts directly |
| `pr-readiness` | `verify-pr-readiness.md` | Inline: run fetch scripts directly |
| `dashboard` | `dashboard.md` | Inline: run fetch scripts directly |
| `pr-review-loop` | `pr-review-loop.md` | Inline: run fetch scripts directly |

Remove `use-context-grabber.md` from all subagent recipes.

### Dispatch rule files — move and add frontmatter

All `use-*.md` files move to `dispatches/` directories and get `dispatches:` frontmatter. All `recipes.yml` paths and `requires:` references updated.

## Files That Must NOT Change

| File | Reason |
|------|--------|
| `comms/commands/dashboard.md` line 41 | `--author @me` lists YOUR open PRs |
| `github/pr/commands/update-branches.md` line 27 | `--author @me` updates YOUR PRs |
