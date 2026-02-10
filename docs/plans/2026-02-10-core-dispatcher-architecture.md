# Core Dispatcher Architecture — Recipe Restructuring Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure `core` into a slim dispatcher (~5K tokens) that routes to `bug` or `feature` subagents, absorb `testing` into `feature`, and eliminate token waste from cross-recipe duplication.

**Architecture:** Core becomes a lightweight orchestrator with only essential context and dispatch rules. All coding work delegates to specialized subagents — `feature` for new development (with TDD, full standards, testing, migrations) and `bug` for investigation/fixing (with its own bug_diagnose/bug_fix sub-dispatch). The `testing` recipe is removed since tests and code belong together.

**Tech Stack:** Ruly recipes (YAML), markdown dispatch rules, ruly squash for verification.

---

## Current State (token costs)

| Recipe | Tokens | Role |
|--------|--------|------|
| `core` | 29,340 (14.7%) | Monolithic — has everything |
| `bug` | 15,519 (7.8%) | Bug investigation orchestrator |
| `feature` | 25,433 (12.7%) | Feature dev — missing superpowers, framework standards, migrations |
| `testing` | 24,686 (12.3%) | Redundant — subset of core with PR merge commands |

## Target State (estimated)

| Recipe | Est. Tokens | Role |
|--------|-------------|------|
| `core` | ~5-7K | Slim dispatcher — routes to bug/feature/debugging |
| `bug` | ~12-14K | Bug orchestrator — leaner (no feature-flags/outbox) |
| `feature` | ~28-30K | Full coding subagent — superpowers, all standards, testing, migrations |
| `testing` | REMOVED | Absorbed into feature |

## New Dispatch Flow

```
core (slim dispatcher, ~5K tokens)
├── use-bug.md ────────► bug subagent (investigation orchestrator)
│                         ├── bug_diagnose → read-only root cause analysis
│                         ├── bug_fix → TDD fix implementation
│                         └── core_debugging → debugging patterns
├── use-feature.md ────► feature subagent (full coding with TDD)
│                         ├── context_fetcher → Jira/PR context
│                         └── core_debugging → debugging patterns
└── use-core-debugging.md ► core_debugging subagent (debugging reference)
```

---

## Task 1: Create `use-bug.md` dispatch rule

**Files:**
- Create: `rules/workaxle/core/standards/use-bug.md`

**Step 1: Write the dispatch rule**

```markdown
---
description: Forces bug-related tasks to dispatch bug subagent for investigation and fixing
alwaysApply: true
---
# Bug Work: Dispatch to Subagent

## When This Applies

Any time you encounter or are asked to work on:
- A bug, error, or unexpected behavior
- Test failures that need investigation or fixing
- Data inconsistencies or corruption
- Performance issues
- Production incidents
- "Why is X happening?" or "X is broken" scenarios

## The Rule

**You MUST dispatch the `bug` subagent.** Do NOT investigate or fix bugs yourself.

The subagent has bug investigation workflows, debugging patterns, and can further dispatch to `bug_diagnose` (systematic root cause analysis) and `bug_fix` (TDD-driven implementation). You are a dispatcher — route the work.

## How to Dispatch

    Task tool:
      subagent_type: "bug"
      prompt: |
        Investigate and fix this bug:

        [Describe the bug, error message, reproduction steps, Jira ticket, and any context]

## After Subagent Returns

1. Read the results (diagnosis report, fix summary, test results)
2. Present findings to the user
3. If additional work needed, dispatch again with updated context

## Does NOT Apply When

- User is building a new feature → dispatch `feature` instead
- User is asking about debugging techniques → dispatch `core_debugging` instead
- User is asking a quick question that doesn't involve investigation

## Red Flags — You Are Violating This Rule

- Reading code to "quickly check" what's wrong
- Proposing fixes without systematic investigation
- Debugging by trial and error
- Skipping the subagent because "this seems simple"

**All of these mean: STOP. Dispatch `bug`.**
```

**Step 2: Verify file exists**

```bash
cat rules/workaxle/core/standards/use-bug.md | head -5
```

---

## Task 2: Create `use-feature.md` dispatch rule

**Files:**
- Create: `rules/workaxle/core/standards/use-feature.md`

**Step 1: Write the dispatch rule**

```markdown
---
description: Forces feature and coding tasks to dispatch feature subagent with TDD and full standards
alwaysApply: true
---
# Feature Work: Dispatch to Subagent

## When This Applies

Any time you are asked to:
- Build a new feature or functionality
- Implement a Jira story or task (not a bug)
- Write or modify application code
- Add database migrations
- Refactor existing code
- Any coding task that isn't bug investigation/fixing

## The Rule

**You MUST dispatch the `feature` subagent.** Do NOT write code yourself.

The subagent has TDD superpowers (red-green-refactor), all framework standards, testing patterns, and migration guides. You are a dispatcher — route the work.

## How to Dispatch

    Task tool:
      subagent_type: "feature"
      prompt: |
        Implement this feature:

        [Describe the feature, requirements, Jira ticket, acceptance criteria, and any context]

        Requirements:
        - Follow TDD (failing test first, then implementation)
        - Follow all framework standards and code patterns
        - Include database migrations if needed
        - Create PR when complete

## After Subagent Returns

1. Read the implementation summary (what was built, tests, migrations)
2. Present results to the user
3. If additional work needed, dispatch again with updated context

## Does NOT Apply When

- User is reporting a bug or error → dispatch `bug` instead
- User is asking about debugging techniques → dispatch `core_debugging` instead
- User is asking a high-level architecture question (answer directly using reference files)

## Red Flags — You Are Violating This Rule

- Writing implementation code directly
- Implementing features without TDD
- Skipping the subagent because "it's a small change"
- Writing code without framework standards loaded

**All of these mean: STOP. Dispatch `feature`.**
```

**Step 2: Verify file exists**

```bash
cat rules/workaxle/core/standards/use-feature.md | head -5
```

---

## Task 3: Restructure `core` recipe → slim dispatcher

**Files:**
- Modify: `recipes.yml` (core recipe section)

**Step 1: Replace core recipe definition**

The new core recipe keeps ONLY:
- `core.md` — always-apply WorkAxle patterns
- `essential/common.md` — common conventions
- `essential/development-commands.md` — just commands
- `reference/` — high-level codebase understanding (helps dispatcher route tasks)
- Three dispatch rules (use-bug, use-feature, use-core-debugging)

**Remove from core:**
- ALL essential files except common.md and development-commands.md (feature-flags, outbox, sequel-patterns, soft-delete → subagents)
- ALL frameworks (sequel, monads, ruby-practices → feature subagent)
- ALL framework standards (11 files → feature subagent)
- ALL testing files (5 files → feature subagent)
- ALL standards except dispatch rules (architecture-patterns, code-patterns, runtime-concerns → subagents)
- ALL migrations (3 files → feature subagent)
- Superpowers (TDD, verification → feature subagent)
- `bug-diagnose.md` and `bug-fix.md` dispatch rules → move to bug recipe
- `commands/diagnose.md` → move to bug recipe

**New core recipe:**

```yaml
  core:
    description: "WorkAxle development dispatcher - routes tasks to specialized subagents"
    files:
      # === WorkAxle Core ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      # === Essential (minimal for routing) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/development-commands.md
      # === Reference (high-level codebase understanding) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/service-overview.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/reference/technology-stack.md
      # === Dispatch Rules ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-bug.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-feature.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-core-debugging.md
    mcp_servers:
      - task-master-ai
    subagents:
      - name: bug
        recipe: bug
      - name: feature
        recipe: feature
      - name: core_debugging
        recipe: core-debugging
```

**Step 2: Verify squash**

```bash
cd $(mktemp -d) && ruly squash core
```

Expected: ~5-7K tokens, 8 files, 3 subagents.

---

## Task 4: Restructure `bug` recipe — leaner, with dispatch rules

**Files:**
- Modify: `recipes.yml` (bug recipe section)

**Step 1: Replace bug recipe definition**

Changes from current:
- Remove `essential/` directory → explicit files WITHOUT feature-flags.md and outbox.md
- Add `bug-diagnose.md` and `bug-fix.md` dispatch rules (moved from core)
- Add `commands/diagnose.md` (moved from core)
- Keep context-fetcher, bug_diagnose, bug_fix, core_debugging subagents

```yaml
  bug:
    description: "WorkAxle bug investigation and fixing orchestrator"
    files:
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      # === Essential (no feature-flags, no outbox — bugs don't need these) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/development-commands.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/sequel-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/soft-delete-pattern.md
      # === Bug Investigation ===
      - /Users/patrick/Projects/ruly/rules/workaxle/profiles/bug-investigation.md
      - /Users/patrick/Projects/ruly/rules/bug/bug-workflow.md
      - /Users/patrick/Projects/ruly/rules/bug/debugging.md
      - /Users/patrick/Projects/ruly/rules/bug/policies.md
      - /Users/patrick/Projects/ruly/rules/bug/rspec-debugging-guide.md
      - /Users/patrick/Projects/ruly/rules/bug/skills/debugging.md
      # === Dispatch Rules (moved from core) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/bug-diagnose.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/bug-fix.md
      # === Commands ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/commands/diagnose.md
      # === Context Fetching ===
      - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
      - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
      # === PR Operations ===
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/review-feedback-loop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/verify-develop-mergability.md
    mcp_servers:
      - task-master-ai
    subagents:
      - name: context_fetcher
        recipe: context-fetcher
      - name: bug_diagnose
        recipe: bug-diagnose
      - name: bug_fix
        recipe: bug-fix
      - name: core_debugging
        recipe: core-debugging
```

**Step 2: Verify squash**

```bash
cd $(mktemp -d) && ruly squash bug
```

Expected: ~12-14K tokens, fewer than current 15.5K.

---

## Task 5: Restructure `feature` recipe — full coding subagent

**Files:**
- Modify: `recipes.yml` (feature recipe section)

**Step 1: Replace feature recipe definition**

Changes from current:
- Add superpowers (TDD + verification) — currently missing
- Add `ruby-practices.md` framework — currently missing
- Add ALL 11 framework standards — currently missing
- Add 3 migration files — currently missing
- Add runtime-concerns standard — currently missing
- Add `core_debugging` subagent — currently missing
- Keep context-fetcher subagent
- Keep Ref MCP server

```yaml
  feature:
    description: "WorkAxle feature development subagent - TDD, full standards, testing, and migrations"
    files:
      # === Superpowers: TDD & Verification (core tenets) ===
      - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/SKILL.md
      - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/testing-anti-patterns.md
      - /Users/patrick/Projects/ruly/superpowers/skills/verification-before-completion/SKILL.md
      # === WorkAxle Core ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core.md
      # === Essential (ALL — features need feature-flags and outbox) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/common.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/development-commands.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/feature-flags.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/outbox.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/sequel-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/soft-delete-pattern.md
      # === Frameworks ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/sequel.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/monads.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/ruby-practices.md
      # === Framework Standards ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/_common-ruby-language-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/code-style-guidelines.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/constants-configuration.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/duck-typing-polymorphism.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/error-handling.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/guard-clauses-early-returns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/instance-variables-memoization.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/iteration-enumeration.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/method-chaining-fluent-interfaces.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/module-composition.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/standards/ruby-3-features.md
      # === Testing (RSpec) ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/rspec-reference.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/rspec-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/rspec-sequel.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/materialized-views-and-test-isolation.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/specs.md
      # === Standards ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/architecture-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/code-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/runtime-concerns.md
      # === Migrations ===
      - /Users/patrick/Projects/ruly/rules/workaxle/core/migrations/database-migration-patterns.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/migrations/migration-safety.md
      - /Users/patrick/Projects/ruly/rules/workaxle/core/migrations/schema-vs-data-migrations.md
      # === Context Fetching ===
      - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
      - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
      # === PR Operations ===
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/review-feedback-loop.md
      - /Users/patrick/Projects/ruly/rules/github/pr/commands/verify-develop-mergability.md
    mcp_servers:
      - Ref
      - task-master-ai
    subagents:
      - name: context_fetcher
        recipe: context-fetcher
      - name: core_debugging
        recipe: core-debugging
```

**Step 2: Verify squash**

```bash
cd $(mktemp -d) && ruly squash feature
```

Expected: ~28-30K tokens with all standards, testing, migrations.

---

## Task 6: Remove `testing` recipe

**Files:**
- Modify: `recipes.yml` (remove testing recipe section)

**Step 1: Delete the entire `testing:` recipe block from recipes.yml**

The testing recipe is now redundant because:
- All RSpec testing files are in `feature` (5 testing files)
- `bug-fix` already has its own testing files (rspec-reference, rspec-patterns, rspec-sequel, specs)
- PR merge commands (squash-and-merge, merge-to-develop, etc.) belong in `merger` or `finalize`
- The testing profile (`workaxle/profiles/testing.md`) can be added to feature if its content is valuable

**Step 2: Verify no other recipes reference `testing` as a subagent**

```bash
grep -n "recipe: testing" recipes.yml
```

Expected: no results (testing was never used as a subagent).

---

## Task 7: Sync recipes and verify all squash

**Step 1: Copy recipes.yml to both config locations**

```bash
cp recipes.yml ~/.config/ruly/recipes.yml
cp recipes.yml ~/Projects/chezmoi/config/ruly/recipes.yml
```

**Step 2: Verify squash for all affected recipes**

```bash
cd $(mktemp -d) && ruly squash core
cd $(mktemp -d) && ruly squash bug
cd $(mktemp -d) && ruly squash feature
cd $(mktemp -d) && ruly squash bug-fix
cd $(mktemp -d) && ruly squash bug-diagnose
cd $(mktemp -d) && ruly squash core-debugging
```

**Step 3: Verify no duplicate commands in bug recipe**

Check that `/bug:diagnose` doesn't appear alongside `/bug_diagnose:bug:diagnose`.

---

## Task 8: Commit and push

**Step 1: Commit rules submodule** (new dispatch rules)

```bash
cd rules/
git add workaxle/core/standards/use-bug.md workaxle/core/standards/use-feature.md
git commit -m "feat: add use-bug and use-feature dispatch rules for core dispatcher architecture"
git push
```

**Step 2: Commit parent repo** (recipes.yml + submodule ref)

```bash
cd ..
git add recipes.yml rules
git commit -m "refactor: restructure core as slim dispatcher, absorb testing into feature

Core recipe slimmed from ~29K to ~5-7K tokens. Feature subagent gains
superpowers, framework standards, migrations. Bug recipe drops feature-flags
and outbox. Testing recipe removed (absorbed into feature)."
git push
```

**Step 3: Commit chezmoi**

```bash
cd ~/Projects/chezmoi
git add config/ruly/recipes.yml
git commit -m "chore: sync recipes.yml - core dispatcher architecture"
git push
```

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Core keeps `reference/` files | Dispatcher needs high-level codebase understanding to route tasks correctly |
| Core keeps `common.md` + `development-commands.md` | Minimal context for understanding user requests |
| Bug drops `feature-flags.md` + `outbox.md` | Bug investigation doesn't need these; bug_fix subagent has them |
| Feature gains superpowers + framework standards | Feature is now the full coding subagent; needs TDD discipline and all standards |
| Feature gains migrations | Building features often requires schema changes |
| Testing recipe removed entirely | Tests and code belong together; feature and bug-fix already have testing files |
| `bug-diagnose.md` + `bug-fix.md` move to bug recipe | Core dispatches to bug orchestrator, which handles sub-dispatch internally |
| `commands/diagnose.md` moves to bug recipe | Diagnose command is bug-specific, not general |
| `core_debugging` stays accessible from core AND bug/feature | Debugging techniques are orthogonal — needed regardless of task type |

## Unchanged Recipes

These recipes are NOT modified by this plan:
- `bug-diagnose` — subagent, unchanged
- `bug-fix` — subagent, unchanged
- `core-debugging` — subagent, unchanged
- `merger`, `finalize`, `refactor`, `full`, `review`, `jira`, `confluence`, `orchestrator`, `gateway`, `playwright`, `spike`, `initiative-core`, `agile`, `local`, `awesomer`, `comms`, `dashboard` — unchanged
- All subagent-only recipes (context-fetcher, ms-teams-dm, etc.) — unchanged
