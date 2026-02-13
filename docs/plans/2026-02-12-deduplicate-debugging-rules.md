# Deduplicate Debugging Rules Against superpowers:systematic-debugging

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove generic debugging methodology from `rules/bug/` files that duplicates `superpowers:systematic-debugging`, keeping only WorkAxle-specific domain patterns.

**Architecture:** The `bug-diagnose` recipe already loads `superpowers:systematic-debugging/SKILL.md`. The `rules/bug/` files re-state the same generic methodology (root cause before fix, read-only investigation, phased analysis). We'll strip redundant methodology, consolidate domain-specific patterns into fewer files, and update all recipe references.

**Tech Stack:** Markdown rules, YAML recipe configs, Ruly CLI

---

## Analysis Summary

### Token counts for all debugging-related files

| File | Tokens | Overlap Level |
|------|--------|---------------|
| `bug/commands/fix.md` | 2,146 | HIGH (TDD workflow = superpowers:TDD) |
| `bug/bug-workflow.md` | 1,649 | HIGH (investigation + fix phases) |
| `bug/commands/diagnose.md` | 1,216 | HIGH (6-step investigation = systematic-debugging Phase 1-3) |
| `bug/skills/debugging.md` | 1,121 | MIXED (generic methodology HIGH, domain patterns NONE) |
| `bug/commands/grpc.md` | 1,070 | NONE (100% domain-specific) |
| `bug/policies.md` | 1,041 | NONE (100% domain-specific) |
| `workaxle/core/debugging.md` | 812 | NONE (100% domain-specific) |
| `bug/rspec-debugging-guide.md` | 530 | NONE (100% domain-specific) |
| `bug/debugging.md` | 483 | HIGH (generic methodology, minor domain content) |
| `use-core-debugging.md` | 453 | NONE (dispatch rule) |
| `bug-fix.md` | 435 | NONE (dispatch rule) |
| `use-core-debugger.md` | 387 | NONE (dispatch rule) |
| `bug-diagnose.md` | 383 | NONE (dispatch rule) |
| `bug-investigation.md` | 241 | REDUNDANT (profile loader, recipe handles this) |
| **TOTAL** | **11,966** | |

### What superpowers:systematic-debugging already covers

- Root cause investigation methodology (4 phases)
- "Read-only first" / "root cause before fix" principles
- Evidence gathering and data flow tracing
- Pattern analysis (compare working vs broken)
- Scientific hypothesis testing
- Red flags for skipping investigation
- Integration with superpowers:test-driven-development for Phase 4

### What is NOT covered (must keep)

- Debug script naming convention (`WA-XXXX-NN-description.rb`)
- WorkAxle commands (`just r`, `just rails-console`, `just spec`, `just bash`)
- Sequel debugging patterns (dataset methods, soft-delete awareness, Niceql)
- Policy/authorization debugging patterns
- gRPC debugging setup
- JWT token decoding
- PERSIST_TEST_DATA workflow
- Container debugging commands
- Ruby inspection helpers
- Materialized view pollution / flaky test patterns
- RSpec supervisor assignment patterns
- Destructive operations warning (just db-restore-remote, etc.)
- Bug workflow: Jira/PR/QA/deployment phases (NOT the investigation phases)

### Recipes affected

| Recipe | Bug files loaded | Notes |
|--------|-----------------|-------|
| `core-debugger` | 9 files | Primary consumer |
| `core-debugging` | 6 files | Tooling patterns |
| `bug-diagnose` | 6 files + superpowers | Already has systematic-debugging |
| `bug-fix` | 1 file (commands/fix.md) | Already has TDD skill |
| `finalize` | 2 files | debugging.md (duplicated!), rspec-debugging-guide.md |
| `spike` | 5 files | debugging.md (duplicated!), skills/debugging.md |

---

## Task 1: Delete `bug/bug-workflow.md` (1,649 tokens saved)

This file's content is either redundant or covered elsewhere:
- Investigation phases (Phases 1-3) → superpowers:systematic-debugging
- PR creation templates → `github/pr/commands/create.md` and `create-develop.md`
- Jira status transitions → `comms/jira/commands/ready-for-qa.md`
- QA comment templates → `comms/jira/commands/ready-for-qa.md`
- Deployment pipeline → `skills/deploy-to-production.md`

**Files:**
- Delete: `rules/bug/bug-workflow.md`

**Step 1: Verify no unique content**

Read these files to confirm the Jira/PR/QA workflow is already documented:
- `rules/comms/jira/commands/ready-for-qa.md`
- `rules/github/pr/commands/create.md`
- `rules/github/pr/commands/create-develop.md`

If any unique WorkAxle-specific workflow content exists that isn't elsewhere, extract it into `rules/workaxle/core/debugging.md` before deleting.

**Step 2: Remove from recipes**

Remove `bug/bug-workflow.md` from these recipes in `recipes.yml`:
- `core-debugger` (line 72)

**Step 3: Update requires**

No other files have `requires: bug-workflow.md` (it requires debugging.md, not the other way around).

**Step 4: Delete the file**

```bash
cd /Users/patrick/Projects/ruly
git rm rules/bug/bug-workflow.md
```

**Step 5: Commit**

```bash
git add rules/bug/bug-workflow.md recipes.yml
git commit -m "refactor: remove bug-workflow.md (covered by superpowers + comms/github rules)"
```

---

## Task 2: Delete `bug/debugging.md` and merge domain content into `workaxle/core/debugging.md` (483 tokens saved)

`bug/debugging.md` is almost entirely generic methodology. The only domain-specific parts are:
- Debug script naming convention → already in `bug/skills/debugging.md`
- Quick reference table (`just r`, etc.) → already in `workaxle/core/debugging.md`
- Destructive operations warning → already in `workaxle/core/debugging.md` (we'll verify)

**Files:**
- Delete: `rules/bug/debugging.md`
- Verify: `rules/workaxle/core/debugging.md` has destructive ops warning (add if not)

**Step 1: Check if destructive ops warning exists in core/debugging.md**

Read `rules/workaxle/core/debugging.md` — it currently does NOT have a destructive operations warning. Add the warning from `bug/debugging.md`.

**Step 2: Add destructive ops warning to `workaxle/core/debugging.md`**

Append to end of `rules/workaxle/core/debugging.md`:

```markdown
## Destructive Operations Warning

NEVER run without explicit user confirmation:

| Command                  | Description                       |
|--------------------------|-----------------------------------|
| `just db-restore-remote` | Imports remote database (20+ min) |
| `just db-reset`          | Resets local database             |
| `just db-drop`           | Drops database completely         |
| `just reset`             | Full application reset            |
| `just reset-remote`      | Reset with remote data            |
```

**Step 3: Remove from recipes**

Remove `bug/debugging.md` from these recipes in `recipes.yml`:
- `core-debugger` (line 73)
- `finalize` (lines 267-268 — listed TWICE, remove both)
- `spike` (lines 415-416 — listed TWICE, remove both)
- `core-debugging` (line 718)
- `bug-diagnose` (line 748)

**Step 4: Update requires**

These files have `requires: debugging.md` (relative to bug/):
- `bug/bug-workflow.md` → already deleted in Task 1
- `bug/rspec-debugging-guide.md` → remove the `requires: debugging.md` line
- `bug/commands/fix.md` → remove `requires: ../debugging.md` line
- `bug/commands/grpc.md` → check if it requires debugging.md (it requires `../../commands.md` and `../debugging.md`)

For `commands/fix.md` and `commands/grpc.md`: remove the `requires: ../debugging.md` line from their frontmatter.
For `rspec-debugging-guide.md`: remove the `requires: debugging.md` line from its frontmatter.

**Step 5: Delete the file**

```bash
git rm rules/bug/debugging.md
```

**Step 6: Commit**

```bash
git add -A rules/bug/debugging.md rules/workaxle/core/debugging.md rules/bug/rspec-debugging-guide.md rules/bug/commands/fix.md rules/bug/commands/grpc.md recipes.yml
git commit -m "refactor: remove bug/debugging.md, merge destructive ops warning into core/debugging.md"
```

---

## Task 3: Refactor `bug/skills/debugging.md` — strip generic methodology, keep domain patterns (est. ~600 tokens saved)

This file mixes generic investigation methodology with valuable domain-specific patterns. Strip the generic parts.

**Files:**
- Modify: `rules/bug/skills/debugging.md`

**Step 1: Remove these sections (redundant with superpowers:systematic-debugging)**

- "Core Principles" section (Read-Only First, Root Cause Before Fix, Propose and Wait) — covered by systematic-debugging Phase 1
- "Investigation Methodology" section (Identify, Scope, Timeline, Root Cause, Prevention) — covered by systematic-debugging Phase 1-2
- "Red Flags" section — covered by systematic-debugging's Red Flags
- "Common Mistakes" table — covered by systematic-debugging's Common Rationalizations

**Step 2: Keep these sections (domain-specific)**

- "Debug Script Convention" (naming, location, run command)
- "Debug Script Template" (Ruby code template)
- "Quick Reference" table (just r, just rails-console, just spec, Niceql)
- "Sequel Debugging" patterns
- "Common Patterns" — Policy/Authorization, Association Inspection, JWT Token Decoding, gRPC Debug Setup
- "Database State Investigation" (PERSIST_TEST_DATA)
- "Destructive Operations Warning" — REMOVE (now in core/debugging.md from Task 2)

**Step 3: Update description**

Change the skill description from "Use when investigating bugs..." to:
```yaml
name: debugging-patterns
description: WorkAxle-specific debugging tools — debug scripts, Sequel, policy, gRPC, and test data patterns
```

**Step 4: Verify**

Confirm the file is now purely domain-specific patterns with no generic methodology.

**Step 5: Commit**

```bash
git add rules/bug/skills/debugging.md
git commit -m "refactor: strip generic methodology from debugging skill (covered by superpowers)"
```

---

## Task 4: Refactor `bug/commands/diagnose.md` — simplify to output template only (est. ~800 tokens saved)

The 6-step investigation process duplicates systematic-debugging Phase 1-3. The only unique value is the WorkAxle-specific output template and debug script patterns.

**Files:**
- Modify: `rules/bug/commands/diagnose.md`

**Step 1: Replace the investigation steps with a reference to systematic-debugging**

Replace Steps 1-5 with:

```markdown
## Investigation Process

Follow the systematic-debugging skill (four phases: Root Cause Investigation → Pattern Analysis → Hypothesis Testing → Implementation).

Use [Debugging Patterns](#debugging-patterns) for WorkAxle-specific tools (debug scripts, Sequel, policy debugging, gRPC).
```

**Step 2: Keep the output template (Step 6)**

Keep the "Generate Diagnosis Report" section with its output format — this is the required deliverable format.

**Step 3: Keep "Special Debugging Scenarios"**

Keep the Database Schema Issues and Test Failures sections (domain-specific).

**Step 4: Keep "Output Requirements"**

Keep the 7-point output requirements list.

**Step 5: Remove "Important Reminders"**

These are all covered by systematic-debugging.

**Step 6: Commit**

```bash
git add rules/bug/commands/diagnose.md
git commit -m "refactor: simplify diagnose command (defer methodology to superpowers)"
```

---

## Task 5: Refactor `bug/commands/fix.md` — simplify TDD section, keep domain patterns (est. ~1,200 tokens saved)

The TDD workflow (RED → GREEN → REFACTOR) duplicates `superpowers:test-driven-development`. The domain-specific value is: transaction wrapping patterns, data migration fix patterns, rollback scripts, monitoring scripts.

**Files:**
- Modify: `rules/bug/commands/fix.md`

**Step 1: Replace the TDD methodology with a reference**

Replace the "TDD Workflow Summary" section and "Step 1: Write a Failing Test" with:

```markdown
## Fix Process

### Step 1: Write Failing Test (TDD)

Follow the test-driven-development skill (RED → GREEN → REFACTOR). Write a regression test in `spec/regressions/[ticket_id]_spec.rb`.
```

**Step 2: Keep these domain-specific sections**

- "Pre-Fix Checklist" — keep, it's a WorkAxle-specific gate
- "Step 2: Create Fix Script" — keep (WA naming convention)
- "Step 3: Implement Fix with Transaction" — keep (Sequel transaction pattern)
- "Step 4: Data Migration Fixes" — keep (migration pattern)
- "Step 5: Apply Code Fixes and Verify Tests Pass" — simplify, reference TDD skill
- "Step 6: Prevent Recurrence" — keep (validation/constraint patterns)
- "Rollback Plan" — keep
- "Post-Fix Monitoring" — keep (monitoring script template)

**Step 3: Remove redundant sections**

- Remove "Fix Verification" section (covered by superpowers:verification-before-completion)
- Remove "Important Reminders" emoji list (covered by TDD and verification skills)
- Remove "Success Criteria" (generic, covered by superpowers)

**Step 4: Remove `requires: ../debugging.md`**

Already done in Task 2.

**Step 5: Commit**

```bash
git add rules/bug/commands/fix.md
git commit -m "refactor: simplify fix command (defer TDD to superpowers)"
```

---

## Task 6: Delete `workaxle/profiles/bug-investigation.md` (241 tokens saved)

This is a profile loader that just lists what modules to load. The recipe system (`core-debugger` recipe) already handles this — the profile is redundant.

**Files:**
- Delete: `rules/workaxle/profiles/bug-investigation.md`

**Step 1: Remove from recipes**

Remove from these recipes in `recipes.yml`:
- `core-debugger` (line 71)
- `spike` (line 411)

**Step 2: Delete the file**

```bash
git rm rules/workaxle/profiles/bug-investigation.md
```

**Step 3: Commit**

```bash
git add rules/workaxle/profiles/bug-investigation.md recipes.yml
git commit -m "refactor: remove bug-investigation profile (recipe handles loading)"
```

---

## Task 7: Consider merging `core-debugging` recipe into `core-debugger` (optional — removes one dispatch layer)

Currently:
```
core → use-core-debugger → core_debugger (subagent)
core → use-core-debugging → core_debugging (subagent)
```

The `core-debugging` recipe provides debugging *tooling* patterns (how to use Sequel, how to inspect containers). The `core-debugger` recipe provides the bug *workflow*. But `core-debugger` already dispatches to `core_debugging` as a sub-subagent — this is 3 layers deep.

**Decision needed:** Should `core-debugging` files be merged into `core-debugger` to eliminate one dispatch layer?

**Arguments FOR merging:**
- Eliminates a dispatch layer (core → core_debugger already has the tooling)
- `core-debugger` already includes most of the same files (`bug/debugging.md`, `bug/skills/debugging.md`, etc.)
- Saves the dispatch overhead (one fewer subagent spawn)

**Arguments AGAINST merging:**
- `core_debugging` is also dispatched from `core-engineer` and `bug-fix` (not just `core-debugger`)
- Keeping it separate means any recipe can access debugging tooling without the full bug workflow
- It's a reusable component

**Recommendation:** KEEP separate for now. The reusability across 3+ recipes justifies the separate recipe. Revisit if token budget is still tight.

---

## Task 8: Update ALL recipe config files

Both recipe files must stay in sync.

**Files:**
- Modify: `/Users/patrick/Projects/ruly/recipes.yml`
- Modify: `/Users/patrick/.config/ruly/recipes.yml`
- Modify: `/Users/patrick/Projects/chezmoi/config/ruly/recipes.yml`

**Step 1: Apply all recipe changes from Tasks 1-6**

Summary of recipe changes:
- `core-debugger`: Remove `bug-workflow.md`, `bug/debugging.md`, `bug-investigation.md`
- `finalize`: Remove both `bug/debugging.md` references (duplicated)
- `spike`: Remove both `bug/debugging.md` references (duplicated), remove `bug-investigation.md`
- `core-debugging`: Remove `bug/debugging.md`
- `bug-diagnose`: Remove `bug/debugging.md`

**Step 2: Copy to user config and chezmoi**

```bash
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/.config/ruly/recipes.yml
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml
```

**Step 3: Verify with ruly stats**

```bash
cd $(mktemp -d) && ruly squash --recipe core-debugger && wc -c CLAUDE.local.md
cd $(mktemp -d) && ruly squash --recipe bug-diagnose && wc -c CLAUDE.local.md
cd $(mktemp -d) && ruly squash --recipe core-debugging && wc -c CLAUDE.local.md
```

**Step 4: Commit both repos**

```bash
# Rules submodule
cd /Users/patrick/Projects/ruly/rules
git add -A && git commit -m "refactor: deduplicate debugging rules against superpowers:systematic-debugging"

# Parent ruly repo
cd /Users/patrick/Projects/ruly
git add recipes.yml rules
git commit -m "refactor: deduplicate debugging rules, update recipes"

# Chezmoi
cd /Users/patrick/Projects/chezmoi
git add config/ruly/recipes.yml
git commit -m "chore: sync ruly recipes after debugging deduplication"
```

---

## Estimated Token Savings

| File | Before | After | Saved |
|------|--------|-------|-------|
| `bug/bug-workflow.md` | 1,649 | 0 (deleted) | **1,649** |
| `bug/debugging.md` | 483 | 0 (deleted) | **483** |
| `bug/skills/debugging.md` | 1,121 | ~550 | **~571** |
| `bug/commands/diagnose.md` | 1,216 | ~450 | **~766** |
| `bug/commands/fix.md` | 2,146 | ~1,000 | **~1,146** |
| `bug-investigation.md` | 241 | 0 (deleted) | **241** |
| `workaxle/core/debugging.md` | 812 | ~900 (added destructive ops) | **-88** |
| **TOTAL** | **7,668** | **~2,900** | **~4,768** |

**Per-recipe context savings (files loaded):**
- `core-debugger`: ~3,500 tokens saved (loads 5 of the affected files)
- `bug-diagnose`: ~2,700 tokens saved (loads 4 of the affected files)
- `core-debugging`: ~1,050 tokens saved (loads 2 of the affected files)
- `finalize`: ~970 tokens saved (loads debugging.md twice!)
- `spike`: ~1,300 tokens saved (loads 3 of the affected files)

---

## Files NOT touched (confirmed no overlap)

These files are 100% domain-specific and stay as-is:
- `bug/policies.md` (1,041 tokens) — Policy/authorization debugging
- `bug/rspec-debugging-guide.md` (530 tokens) — RSpec supervisor patterns
- `bug/commands/grpc.md` (1,070 tokens) — gRPC debugging
- `workaxle/core/debugging.md` (812 tokens) — Container/SQL/Ruby tooling
- `use-core-debugger.md` (387 tokens) — Dispatch rule
- `use-core-debugging.md` (453 tokens) — Dispatch rule
- `bug-diagnose.md` (383 tokens) — Dispatch rule
- `bug-fix.md` (435 tokens) — Dispatch rule
