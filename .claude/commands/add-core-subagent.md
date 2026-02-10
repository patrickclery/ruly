---
name: add-core-subagent
description: Use when adding a new subagent to the core orchestrator recipe, wiring dispatch rules and recipe registration
---

# Add Subagent to Core Orchestrator

## Overview

Automates wiring a new subagent into the core dispatcher. Core is a slim orchestrator that routes tasks to specialized subagents -- it never does the work itself. Each subagent needs a dispatch rule (so core knows when to route) and a recipe registration (so ruly generates the agent file).

## When to Use

- "Add X as a core subagent"
- "Wire up the Y subagent to core"
- "Core should dispatch to Z"
- "Register W in the core recipe"
- Creating a new specialized agent that core should delegate to

## Gather Information

Before creating anything, collect these from the user (ask if not provided):

| Input | Example | Required |
|-------|---------|----------|
| Subagent name | `qa` | Yes |
| Recipe name (if different) | `qa-testing` | Only if differs from name |
| Work type heading | `QA & Testing` | Yes |
| Trigger conditions | Test planning, QA reports, test execution | Yes |
| Has slash commands? | yes/no | Yes |
| Capabilities summary | test planning, execution, QA reports | Yes |

**Naming convention:**
- `subagent_type` in Task tool uses underscores: `core_debugging`, `context_fetcher`
- `recipe` name uses hyphens: `core-debugging`, `context-fetcher`
- Dispatch rule filename uses hyphens: `use-core-debugging.md`
- Simple names are the same everywhere: `bug`, `comms`, `merger`

## Step 1: Create the Dispatch Rule

Create the file at:
```
/Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-{name}.md
```

Use this template, filling in the placeholders:

````markdown
---
description: Forces {task_type} tasks to dispatch {subagent_type} subagent for {capabilities}
alwaysApply: true
---
# {Work Type}: Dispatch to Subagent

## When This Applies

Any time you are asked to or encounter:
{trigger_list -- bullet points of actions, keywords, slash commands}

## The Rule

**You MUST dispatch the `{subagent_type}` subagent.** Do NOT:
{do_not_list -- bullet points of what core must not do itself}

The subagent has {capabilities_description}. You are a dispatcher -- route the work.

## CRITICAL: Slash Command Override

> **Only include this section if the subagent has slash commands.**

When a {work_type_lower} slash command is invoked, the command file content will load into your context. **Do NOT follow those instructions yourself.** Instead:

1. Extract the user's intent and any arguments from the command
2. Dispatch the `{subagent_type}` subagent with those details
3. The subagent will follow the command workflow (it has the same files)

## How to Dispatch

{dispatch_examples -- one or more ### subsections with Task tool examples like:}

### For {Action Name}

```
Task tool:
  subagent_type: "{subagent_type}"
  prompt: |
    {Action description}:
    - {relevant parameters}
```

## After Subagent Returns

1. Present the subagent's results to the user
2. If the subagent needs confirmation, relay to user, then dispatch again
3. If additional work needed, dispatch again with updated context

## Does NOT Apply When

{boundary_conditions -- bullet list deferring to other subagents}

## Red Flags -- You Are Violating This Rule

{red_flags -- bullet list of anti-patterns}

**All of these mean: STOP. Dispatch `{subagent_type}`.**
````

**Reference examples:**
- Minimal dispatch rule: `use-bug.md` (no slash command override, single dispatch example)
- Full dispatch rule: `use-comms.md` (slash command override, 6 dispatch examples, detailed boundaries)

## Step 2: Update recipes.yml

Edit `/Users/patrick/Projects/ruly/recipes.yml`:

**Add dispatch rule to core.files** (in the `# === Dispatch Rules ===` section, after the last `use-*.md` entry):

```yaml
      - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-{name}.md
```

**Add subagent to core.subagents** (after the last entry):

```yaml
      - name: {subagent_type}
        recipe: {recipe_name}
```

**Verify the target recipe exists** in recipes.yml. If it doesn't, the user needs to create it first.

## Step 3: Sync to Chezmoi

Copy the updated recipes.yml:

```bash
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml
```

Both files must be identical.

## Step 4: Install and Test

```bash
cd /Users/patrick/Projects/ruly && bundle exec rake install
cd $(mktemp -d) && ruly squash --recipe core
```

**Verify:**
- `CLAUDE.local.md` contains the new dispatch rule content
- `.claude/agents/{subagent_type}.md` was generated
- The dispatch rule heading appears in the squashed output

## Step 5: Commit All Repos

**Rules submodule:**
```bash
cd /Users/patrick/Projects/ruly/rules
git add workaxle/core/standards/use-{name}.md
git commit -m "feat: add {name} dispatch rule for core orchestrator"
git push
```

**Ruly parent:**
```bash
cd /Users/patrick/Projects/ruly
git add recipes.yml rules
git commit -m "feat: wire {subagent_type} subagent into core orchestrator"
git push
```

**Chezmoi:**
```bash
cd /Users/patrick/Projects/chezmoi
git add config/ruly/recipes.yml
git commit -m "chore: sync recipes.yml ({subagent_type} subagent in core)"
git push
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting `alwaysApply: true` | Dispatch rule won't load -- core won't route to the subagent |
| Wrong naming convention | `subagent_type` uses underscores, `recipe` uses hyphens |
| Only updating one recipes.yml | Must update both ruly and chezmoi copies |
| Recipe doesn't exist yet | Create the recipe in recipes.yml before registering as subagent |
| Not testing with squash | Always verify with `ruly squash --recipe core` in a temp dir |
| Committing only one repo | Must commit rules submodule, ruly parent, and chezmoi |

## Red Flags

- The dispatch rule file exists but core doesn't route to the subagent (missing from recipes.yml)
- recipes.yml has the subagent but no dispatch rule in core.files
- The chezmoi copy is out of sync with the project copy
- `ruly squash --recipe core` doesn't show the new dispatch rule
