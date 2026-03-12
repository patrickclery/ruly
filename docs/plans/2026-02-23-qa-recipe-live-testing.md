# QA Recipe Live Testing & Improvement Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Verify and fix the QA recipe/skill so it reliably accepts acceptance criteria, logs in, writes a Playwright spec, and runs it — tested live against WA-15829 (manager-to-manager delegation).

**Architecture:** Iterative live testing. First verify Playwright infrastructure works (login + existing spec). Then run the QA skill manually in the foreground against real AC (WA-15829). Fix what breaks. Repeat until reliable. The test subject is the recipe/skill itself — WA-15829 is just the test case.

**Tech Stack:** Ruly recipes (YAML), Ruly rules (Markdown), automation-test-qa repo (Playwright + TypeScript), `npx playwright test`, `ruly squash`.

---

## Context: WA-15829 Acceptance Criteria (Delegation)

```
AC1: LM selects "Location Manager" access level → Recipient dropdown shows all LMs and DMs
AC2: DM selects "Department Manager" access level → Recipient dropdown shows all DMs and LMs, NOT Employees
AC3: LM Branch X → delegate to LM Branch Y → succeeds
AC4: LM Branch X → delegate to DM Branch Y → succeeds
AC5: DM Dept1/BranchX → delegate to DM Dept2/BranchY → succeeds
AC6: DM Dept1/BranchX → delegate to LM BranchY → succeeds
AC7: Delegation shows in Recipe Logs (who, location/dept, date range)
AC8: Delegated Manager can perform timesheet/leave approvals during effective period
AC9: No Employees visible in recipient dropdown
```

## Context: Current QA Recipe State

| Component | File | Status |
|-----------|------|--------|
| Recipe | `recipes.yml` lines 560-574 | Exists — loads qa-testing.md, playwright.md, jira/, 2 skills, playwright MCP |
| Rule | `rules/workaxle/qa/qa-testing.md` | Exists — repo layout, patterns, env config |
| Skill | `rules/workaxle/skills/run-acceptance-test.md` | Exists — 7-step workflow |
| Skill | `rules/workaxle/skills/sync-qa-repo.md` | Exists — pull + report |
| Dispatch | `rules/workaxle/core/dispatches/use-qa.md` | Exists — wired into core |
| Repo | `/Users/patrick/agents/qa/` | Cloned — has page objects, fixtures, specs |
| Agent dir | `~/agents/WA-15829/` | Has core recipe squashed in CLAUDE.local.md |

## Context: Environment

The automation-test-qa repo uses `environment-util.ts` which defaults to `ENV=RC`. For dev testing:

```bash
ENV=DEV npx playwright test ...
```

This requires `WORKAXLE_DEV_US` JSON secret in `.env` or environment. If missing, auth.setup.ts will fail.

---

## Task 1: Verify Playwright Infrastructure — Login Works

**Files:** None (read-only verification)

**Step 1: Check environment secrets are configured**

```bash
cd /Users/patrick/agents/qa
# Check if .env exists with DEV secrets
cat .env 2>/dev/null | grep -c DEV || echo "No DEV secrets in .env"
# Check environment
echo $WORKAXLE_DEV_US | head -c 20
```

If secrets are missing, the `environment-util.ts` will throw `"Missing secrets for client: WORKAXLE"`. Fix by creating/updating `.env` with the `WORKAXLE_DEV_US` JSON (ask user for credentials if needed).

**Step 2: Run auth setup only**

```bash
cd /Users/patrick/agents/qa
ENV=DEV npx playwright test --project=setup
```

Expected: PASS. Creates `playwright/.auth/user.json`.

If it fails: read the error. Common issues:
- Missing secrets → fix .env
- Auth0 login page changed → update `pages/signInPage/signin-page.ts`
- Timeout → increase timeout or check dev.workaxle.com is up

**Step 3: Run one existing spec to verify full pipeline**

```bash
cd /Users/patrick/agents/qa
ENV=DEV npx playwright test tests/management/people/work-cycle-assignment.spec.ts --timeout 90000
```

Expected: Some tests pass (confirms login + navigation + page objects work).

If all tests error on setup: auth issue. If tests fail on assertions: feature-specific, not our problem.

**Step 4: Record results**

Document what worked and what didn't. This establishes the baseline.

---

## Task 2: Write a Minimal Delegation Smoke Test (Manual RED)

This is the "failing test" for our TDD cycle — a minimal spec that proves we can navigate to the delegation UI. We write this manually so we know exactly what a working spec looks like.

**Files:**
- Create: `/Users/patrick/agents/qa/tests/management/delegation/delegation-smoke.spec.ts`

**Step 1: Explore the delegation UI to find selectors**

Use Playwright MCP to navigate to the delegation feature on dev.workaxle.com:

```
Navigate to https://dev.workaxle.com
After login, find the delegation/temporary access section
(likely: People > employee recipe > Temporary Access tab, or Management > somewhere)
```

Record the selectors needed for:
- Navigation to delegation page
- "Access Level" dropdown
- "Recipient" dropdown
- "Submit/Save" button

**Step 2: Write the smoke test**

```typescript
import { expect, test } from '@fixtures/base-fixture';

test.describe('WA-15829 Delegation Smoke Test', () => {
  test('can navigate to delegation page', async ({ pageManager, page }) => {
    await test.step('Navigate to People', async () => {
      await pageManager.gotoNavigateTo().navigateToPeoplePage();
      await expect(page.locator('#mainAppContainer')).toBeVisible({ timeout: 15000 });
    });

    // TODO: Navigate to delegation/temporary access
    // This step will be filled once we discover the UI path
  });
});
```

**Step 3: Run the smoke test**

```bash
cd /Users/patrick/agents/qa
ENV=DEV npx playwright test tests/management/delegation/delegation-smoke.spec.ts
```

Expected: PASS for navigation. The TODO step shows where we need to discover UI.

**Step 4: Commit**

```bash
cd /Users/patrick/agents/qa
git add tests/management/delegation/delegation-smoke.spec.ts
git commit -m "test(WA-15829): add delegation smoke test — navigation only"
```

---

## Task 3: Squash QA Recipe and Test in Foreground

This is where we test the actual QA recipe/skill. We squash it, start a foreground Claude session, and see if the skill can write and run a spec.

**Files:** None (testing existing recipe)

**Step 1: Squash the QA recipe**

```bash
cd $(mktemp -d) && ruly squash --recipe qa
```

Verify output looks reasonable:
- Contains the QA testing workflow section
- Contains the run-acceptance-test skill
- Contains Playwright patterns
- Not excessively long (should be focused)

Record the token count:
```bash
ruly stats
```

**Step 2: Copy the squash to the QA repo for testing**

```bash
cp CLAUDE.local.md /Users/patrick/agents/qa/CLAUDE.local.md
```

**Step 3: Start a foreground Claude session in the QA repo**

```bash
cd /Users/patrick/agents/qa
claude
```

**Step 4: Give it the WA-15829 AC and observe**

In the Claude session, type:

```
Test the following acceptance criteria for WA-15829 (manager-to-manager delegation) on dev.workaxle.com:

AC1: Given I am a Location Manager, when I select "Location Manager" access level, then the Recipient dropdown shows all Location Managers and Department Managers
AC2: Given I am a Department Manager, when I select "Department Manager" access level, then the Recipient dropdown shows DMs and LMs, NOT Employees
AC9: No Employees should be visible in the recipient dropdown
```

(Start with a subset of AC — 3 is enough to test the workflow.)

**Step 5: Record what happens**

Watch for:
- Does it read existing page objects? (Should read pageManager.ts, navigationPage, peoplePage)
- Does it look for similar existing specs? (Should browse tests/)
- Does it write a proper spec file? (Correct imports, describe/test structure, test.step)
- Does it run the spec correctly? (ENV=DEV npx playwright test ...)
- Does it handle missing page objects? (No delegation page exists — should use Playwright MCP)
- Does it report results? (Should produce the results table)

Document every failure point.

---

## Task 4: Fix the Rules Based on Failures

Based on what Task 3 reveals, fix the rules. Common issues predicted:

**Files:**
- Modify: `rules/workaxle/qa/qa-testing.md`
- Modify: `rules/workaxle/skills/run-acceptance-test.md`
- Possibly modify: `recipes.yml`

### Issue A: Agent doesn't know it needs ENV=DEV

The qa-testing.md says `demo@workaxle.com / workaxle` and env defaults to RC. Fix:

Add to `qa-testing.md` Environment section:

```markdown
## Running Tests

**ALWAYS run with `ENV=DEV`** (the repo defaults to RC which is wrong for dev testing):

```bash
cd /Users/patrick/agents/qa
ENV=DEV npx playwright test tests/{area}/{feature}.spec.ts
```
```

### Issue B: Agent gets confused by too much Playwright.md content

The `playwright.md` rule is 300+ lines of generic Playwright patterns that don't match the automation-test-qa repo patterns. It teaches raw `page.click()` / `page.$()` style instead of the repo's page object + fixture pattern.

Fix: Remove `playwright.md` from the QA recipe — the `qa-testing.md` already covers the correct patterns.

In `recipes.yml`, change:

```yaml
  qa:
    description: "WorkAxle QA acceptance testing — write and run specs in automation-test-qa against dev.workaxle.com"
    files:
      - /Users/patrick/Projects/ruly/rules/workaxle/qa/qa-testing.md
      - /Users/patrick/Projects/ruly/rules/comms/jira/
    skills:
      - /Users/patrick/Projects/ruly/rules/workaxle/skills/run-acceptance-test.md
      - /Users/patrick/Projects/ruly/rules/workaxle/skills/sync-qa-repo.md
    mcp_servers:
      - playwright
```

### Issue C: Agent writes spec but doesn't discover selectors for delegation

The skill says "use Playwright MCP to explore the page" but doesn't explain HOW. Fix the `run-acceptance-test.md` skill Step 2 to be more explicit:

```markdown
### Step 2: Find or Build Page Objects

1. Check if page objects exist for the feature:
   ```bash
   ls /Users/patrick/agents/qa/pages/managementPage/
   ```

2. If the feature has no page objects, discover selectors:
   - Navigate to the feature page in the browser (use Playwright MCP `browser_navigate`)
   - Take a screenshot (`browser_screenshot`) to see the current state
   - Use `browser_snapshot` to get the accessibility tree with selectors
   - Record the selectors you need for each AC step

3. If creating new page objects, follow the existing pattern:
   - Read one existing page object for reference
   - Create at `pages/managementPage/{featureName}Page/{featureName}.page.ts`
   - Extend BasePage
   - Register in pageManager.ts
```

### Issue D: Agent tries too many AC at once

Fix: Add to the skill workflow a note to test ONE AC first, verify it works, then add more.

**Step N: Commit fixes**

```bash
cd /Users/patrick/Projects/ruly/rules
git add workaxle/qa/qa-testing.md workaxle/skills/run-acceptance-test.md
cd /Users/patrick/Projects/ruly
git add recipes.yml
git commit -m "fix(qa): improve QA recipe based on live testing — ENV=DEV, remove playwright.md, explicit selector discovery"
```

---

## Task 5: Re-test with Fixed Recipe

Repeat Task 3 with the fixed recipe. This is the GREEN phase.

**Step 1: Re-squash**

```bash
cd $(mktemp -d) && ruly squash --recipe qa
cp CLAUDE.local.md /Users/patrick/agents/qa/CLAUDE.local.md
```

**Step 2: Re-run in foreground**

```bash
cd /Users/patrick/agents/qa
claude
```

Give it the same 3 AC from WA-15829.

**Step 3: Compare results**

- Did it improve? Which failure points are fixed?
- Any new issues?

**Step 4: If still failing, iterate** — go back to Task 4 with new findings.

**Step 5: If passing, run the full 9 AC** to verify it handles the complete set.

---

## Task 6: Refactor — Trim and Focus the Recipe

Once the skill works end-to-end, simplify.

**Files:**
- Modify: `rules/workaxle/qa/qa-testing.md`
- Modify: `rules/workaxle/skills/run-acceptance-test.md`

**Step 1: Measure token count**

```bash
cd $(mktemp -d) && ruly squash --recipe qa && ruly stats
```

**Step 2: Remove anything the agent didn't use**

Based on the live test, remove:
- Sections the agent skipped
- Duplicate information between qa-testing.md and the skill
- Over-detailed instructions for things that worked automatically

**Step 3: Re-test after trim**

Quick validation — give it 1 AC and confirm it still works.

**Step 4: Commit**

```bash
cd /Users/patrick/Projects/ruly/rules
git add workaxle/qa/qa-testing.md workaxle/skills/run-acceptance-test.md
cd /Users/patrick/Projects/ruly
git add recipes.yml
git commit -m "refactor(qa): trim QA recipe — remove unused sections, focus instructions"
```

---

## Task 7: Test via Core Dispatch (Subagent Mode)

Now test that the core orchestrator correctly dispatches to QA.

**Files:** None (validation only)

**Step 1: From ~/agents/WA-15829, trigger QA dispatch**

```bash
cd ~/agents/WA-15829
claude
```

In the session:
```
Test the delegation AC for WA-15829 on dev.workaxle.com
```

The core recipe should recognize this as a QA task and dispatch to the `qa_tester` subagent.

**Step 2: Verify dispatch works**

- Did it dispatch to `qa_tester`? (Not try to test in the backend repo)
- Did the QA subagent work in `/Users/patrick/agents/qa/`?
- Did it produce a spec and run it?

**Step 3: Fix dispatch issues if any**

If dispatch doesn't trigger, check `rules/workaxle/core/dispatches/use-qa.md`.

---

## Summary

| Task | Phase | What | Expected Time |
|------|-------|------|---------------|
| 1 | Setup | Verify Playwright infra (login + existing spec) | Quick |
| 2 | RED | Write manual delegation smoke test | Quick |
| 3 | RED | Squash QA recipe, test in foreground with WA-15829 AC | Medium |
| 4 | GREEN | Fix rules based on live failures | Medium |
| 5 | GREEN | Re-test with fixed recipe | Medium |
| 6 | REFACTOR | Trim recipe, verify still works | Quick |
| 7 | VALIDATE | Test via core dispatch (subagent mode) | Quick |

**Key predicted fixes:**
1. Add `ENV=DEV` to all test commands
2. Remove `playwright.md` from recipe (conflicts with repo patterns)
3. Make Playwright MCP selector discovery explicit in the skill
4. Add "test one AC first" guidance
