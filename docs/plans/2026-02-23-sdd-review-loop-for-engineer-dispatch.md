# SDD Review Loop + Subagent Consolidation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate `bug_fix` and `core_architect` into `core_engineer`, then add the SDD two-stage review loop (spec compliance + code quality) after every `core_engineer` dispatch.

**Architecture:** The `core_engineer` becomes the single implementation subagent. It already has a superset of everything `bug_fix` and `core_architect` load. The dispatcher routes all coding work (features, bug fixes, design questions) to `core_engineer`. After every dispatch, the SDD review loop runs using the existing reviewer prompt templates from the SDD skill.

**Tech Stack:** Ruly profiles (YAML), markdown dispatch rules

---

### Task 1: Remove `bug_fix` subagent from profiles.yml

**Files:**
- Modify: `profiles.yml`

**Step 1: Remove `bug_fix` from the `core` profile's subagents list**

Delete these lines from the core profile subagents section (~lines 86-87):
```yaml
      - name: bug_fix
        profile: bug-fix
```

**Step 2: Remove `bug_fix` from the `orchestrator` profile's subagents list**

Delete these lines from the orchestrator profile subagents section (~lines 502-503):
```yaml
      - name: bug_fix
        profile: bug-fix
```

**Step 3: Remove the `bug-fix` profile definition entirely**

Delete the entire `bug-fix:` profile block (~lines 850-881).

**Step 4: Verify YAML is valid**

Run: `ruby -ryaml -e "YAML.load_file('/Users/patrick/Projects/ruly/profiles.yml')"`
Expected: No error output

---

### Task 2: Remove `core_architect` subagent from profiles.yml

**Files:**
- Modify: `profiles.yml`

**Step 1: Remove `core_architect` from the `core` profile's subagents list**

Delete these lines (~lines 76-77):
```yaml
      - name: core_architect
        profile: core-architect
```

**Step 2: Remove `use-core-architect.md` from the `core` profile's files list**

Delete this line (~line 33):
```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-core-architect.md
```

**Step 3: Remove `core_architect` from the `orchestrator` profile's subagents list**

Delete these lines (~lines 466-467):
```yaml
      - name: core_architect
        profile: core-architect
```

**Step 4: Remove `use-core-architect.md` from the `orchestrator` profile's files list**

Find and delete this line from the orchestrator profile:
```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-core-architect.md
```

**Step 5: Remove the `core-architect` profile definition entirely**

Delete the entire `core-architect:` profile block (~lines 739-768).

**Step 6: Verify YAML is valid**

Run: `ruby -ryaml -e "YAML.load_file('/Users/patrick/Projects/ruly/profiles.yml')"`
Expected: No error output

---

### Task 3: Add SDD reviewer prompt templates to core profile

**Files:**
- Modify: `profiles.yml`

**Step 1: Add the two SDD reviewer prompt files to the core profile**

In `profiles.yml`, inside the `core:` profile's `files:` list, add after the Context Fetching section and before `subagents:`:

```yaml
      # === SDD Review Loop (spec compliance + code quality after engineer dispatches) ===
      - /Users/patrick/Projects/ruly/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md
      - /Users/patrick/Projects/ruly/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md
```

**Why not the full SKILL.md?** It describes multi-task plan execution with TodoWrite. The dispatcher only needs the review portion — the prompt templates for dispatching reviewers.

**Why not implementer-prompt.md?** The `core_engineer` IS the implementer. It already has TDD, coding standards, and verification via its profile.

**Step 2: Verify YAML is valid**

Run: `ruby -ryaml -e "YAML.load_file('/Users/patrick/Projects/ruly/profiles.yml')"`
Expected: No error output

---

### Task 4: Delete the `use-core-architect.md` dispatch rule

**Files:**
- Delete: `rules/workaxle/core/dispatches/use-core-architect.md`

**Step 1: Delete the file**

Run: `git rm rules/workaxle/core/dispatches/use-core-architect.md`

---

### Task 5: Delete the `bug-fix.md` dispatch rule

**Files:**
- Delete: `rules/workaxle/core/dispatches/bug-fix.md`

**Step 1: Remove `bug-fix.md` from the `core` profile's files list in profiles.yml**

Delete this line (~line 38):
```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/bug-fix.md
```

**Step 2: Remove `bug-fix.md` from the `orchestrator` profile's files list in profiles.yml**

Find and delete the corresponding line from the orchestrator profile.

**Step 3: Delete the file**

Run: `git rm rules/workaxle/core/dispatches/bug-fix.md`

---

### Task 6: Delete the `bug-fix.md` skill

**Files:**
- Delete: `rules/workaxle/core/skills/bug-fix.md`

**Step 1: Remove from any profile that loads it**

Search profiles.yml for references to `rules/workaxle/core/skills/bug-fix.md` and remove those lines.

**Step 2: Delete the file**

Run: `git rm rules/workaxle/core/skills/bug-fix.md`

---

### Task 7: Rewrite `use-core-engineer.md` dispatch rule

**Files:**
- Modify: `rules/workaxle/core/dispatches/use-core-engineer.md`

This is the big one. The engineer dispatch rule now handles ALL implementation work (features, bug fixes, design). Replace the entire file with:

```markdown
---
description: Forces all implementation work to dispatch core_engineer subagent with SDD review loop
alwaysApply: true
dispatches:
  - core_engineer
---
# Implementation Work: Dispatch to Subagent

## When This Applies

Any time you need code written, designed, or fixed:
- Implementing a feature (new or existing)
- Fixing a diagnosed bug (after diagnosis is complete and user approves)
- Designing how something should be structured
- Refactoring or code changes of any size
- Adding feature flags, new classes, new files, new patterns
- Simple one-line fixes, typos, or trivial code changes

## The Rule

**You MUST dispatch the `core_engineer` subagent.** Do NOT write code yourself.

The subagent has TDD superpowers (red-green-refactor), all framework standards, testing patterns, migration guides, and debugging skills. You are a dispatcher — route the work.

## How to Dispatch

### Feature Work

```
Task tool:
  subagent_type: "core_engineer"
  prompt: |
    Implement this feature:

    [User's request with full context]

    Requirements:
    - Follow TDD (failing test first, then implementation)
    - Follow all framework standards and code patterns
    - Include database migrations if needed
```

### Bug Fix (after diagnosis)

Pre-dispatch checklist — confirm before dispatching:
- Diagnosis is complete (root cause identified)
- User has approved the fix approach

```
Task tool:
  subagent_type: "core_engineer"
  prompt: |
    Fix this diagnosed bug:

    ## Diagnosis Summary
    [Paste the diagnosis report or key findings]

    ## Root Cause
    [What causes the bug]

    ## Approved Fix
    [What fix was approved]

    Requirements:
    - Write a failing regression test FIRST (TDD red phase)
    - Verify the test fails for the right reason
    - Implement the minimal fix (TDD green phase)
    - Verify all tests pass
    - Commit the fix
```

If diagnosis is NOT complete, dispatch `bug_diagnose` first (see [Bug Diagnosis: Dispatch to Subagent](#bug-diagnosis-dispatch-to-subagent)).

## After Subagent Returns (SDD Review Loop)

Every `core_engineer` dispatch is followed by the two-stage Subagent-Driven Development review loop. The `core_engineer` is your implementer — if reviewers find issues, dispatch `core_engineer` again to fix them.

**Stage 1: Spec Compliance Review**

1. Note the git SHA before the engineer's work (BASE_SHA) and after (HEAD_SHA)
2. Dispatch a spec compliance reviewer using the [Spec Compliance Reviewer Prompt Template](#spec-compliance-reviewer-prompt-template):
   - "What Was Requested" = the task requirements you gave the engineer
   - "What Implementer Claims They Built" = the engineer's report
3. If reviewer reports ❌ issues:
   - Dispatch `core_engineer` again with the specific issues to fix
   - After engineer returns, dispatch spec reviewer again
   - Repeat until ✅ spec compliant
4. Do NOT proceed to code quality review until spec compliance passes

**Stage 2: Code Quality Review**

5. Dispatch a code quality reviewer using the [Code Quality Reviewer Prompt Template](#code-quality-reviewer-prompt-template):
   - BASE_SHA and HEAD_SHA from the implementation
   - Description of what was implemented
6. If reviewer reports issues (Critical or Important severity):
   - Dispatch `core_engineer` again with the specific issues to fix
   - After engineer returns, dispatch code quality reviewer again
   - Repeat until approved
7. Minor issues: note them but don't block — present to user

**Stage 3: Complete**

8. Present the final results to the user including review outcomes
9. Proceed with PR creation if appropriate

## Does NOT Apply When

- User is reporting a bug or error → dispatch `core_debugger` instead
- User is asking about debugging techniques → dispatch `core_debugging` instead
- Communication tasks → dispatch `comms` instead
- Merging PRs → dispatch `merger` instead

## Red Flags — You Are Violating This Rule

- Writing implementation code directly
- Implementing features without TDD
- Skipping the subagent because "it's a small change"
- Writing code without framework standards loaded
- Fixing a bug without a diagnosis report and user approval
- Skipping the SDD review loop after engineer returns
- Proceeding to code quality review before spec compliance passes

**All of these mean: STOP. Dispatch `core_engineer`.**
```

---

### Task 8: Update `bug-diagnose.md` dispatch rule

**Files:**
- Modify: `rules/workaxle/core/dispatches/bug-diagnose.md`

**Step 1: Update "After Subagent Returns" section**

Replace the current "After Subagent Returns" section (lines 41-44) with:

```markdown
## After Subagent Returns

1. Read the diagnosis report
2. Present findings to the user
3. If fix is approved, dispatch `core_engineer` with the diagnosis (see [Implementation Work: Dispatch to Subagent](#implementation-work-dispatch-to-subagent))
```

---

### Task 9: Update `use-core-debugger.md` dispatch rule

**Files:**
- Modify: `rules/workaxle/core/dispatches/use-core-debugger.md`

**Step 1: Update the description that references `bug_fix`**

Find the line that mentions `bug_fix` (~line 23) and update it to reference `core_engineer` instead. Change:

> can further dispatch to `bug_diagnose` (systematic root cause analysis) and `bug_fix` (TDD-driven implementation)

To:

> can further dispatch to `bug_diagnose` (systematic root cause analysis). After diagnosis, dispatch `core_engineer` for implementation.

---

### Task 10: Update `orchestrator/dispatch.md` routing table

**Files:**
- Modify: `rules/workaxle/orchestrator/dispatch.md`

**Step 1: Remove `core_architect` from routing table**

Find the line routing architecture tasks to `core_architect` (~line 15) and either:
- Delete it (architecture questions go to `core_engineer` now)
- Or change it to route to `core_engineer`

---

### Task 11: Update `diagnose.md` command

**Files:**
- Modify: `rules/workaxle/core/commands/diagnose.md`

**Step 1: Update reference to `bug_fix`**

Find the line referencing `bug_fix` (~line 26) and change to `core_engineer`:

Before: `5. If fix approved, dispatch `bug_fix` subagent`
After: `5. If fix approved, dispatch `core_engineer` subagent`

---

### Task 12: Sync profile files

**Files:**
- Modify: `~/.config/ruly/profiles.yml`
- Modify: `/Users/patrick/Projects/chezmoi/config/ruly/profiles.yml`

**Step 1: Apply ALL profile changes from Tasks 1-3 and 5-6 to both files**

Both files must mirror the changes made to the project's `profiles.yml`:
- Remove `bug_fix` subagent and `bug-fix` profile
- Remove `core_architect` subagent and `core-architect` profile
- Remove `use-core-architect.md` and `bug-fix.md` from file lists
- Remove `bug-fix.md` skill from file lists
- Add SDD reviewer prompt templates to core profile

**Step 2: Verify all three files match**

Run: `diff /Users/patrick/Projects/ruly/profiles.yml ~/.config/ruly/profiles.yml`
Expected: No output (files match)

Run: `diff /Users/patrick/Projects/ruly/profiles.yml /Users/patrick/Projects/chezmoi/config/ruly/profiles.yml`
Expected: No output (files match)

---

### Task 13: Test with ruly squash

**Step 1: Squash the core profile in a temp directory**

Run:
```bash
cd $(mktemp -d) && ruly squash --profile core
```

Expected: Squash completes without errors. The output should contain:
- The spec-reviewer-prompt content (look for "Spec Compliance Reviewer Prompt Template")
- The code-quality-reviewer-prompt content (look for "Code Quality Reviewer Prompt Template")
- The updated use-core-engineer dispatch rule with the SDD review loop
- NO references to `bug_fix` or `core_architect`

**Step 2: Verify the section anchors resolve**

In the squashed output, confirm these anchor targets exist:
- `#spec-compliance-reviewer-prompt-template`
- `#code-quality-reviewer-prompt-template`
- `#implementation-work-dispatch-to-subagent` (referenced by updated bug-diagnose.md)
- `#bug-diagnosis-dispatch-to-subagent` (referenced by updated use-core-engineer.md)

---

### Task 14: Commit

**Step 1: Stage and commit all changes**

```bash
cd /Users/patrick/Projects/ruly
git add -A profiles.yml rules/workaxle/core/dispatches/ rules/workaxle/core/skills/ rules/workaxle/core/commands/ rules/workaxle/orchestrator/ rules/bug/
git commit -m "refactor: consolidate bug_fix and core_architect into core_engineer with SDD review

Remove bug_fix and core_architect subagents. The core_engineer handles
all implementation work: features, bug fixes, and design. After every
dispatch, the two-stage SDD review loop runs (spec compliance then code
quality) using the existing SDD reviewer prompt templates."
```
