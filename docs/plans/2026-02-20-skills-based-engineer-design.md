# Skills-Based Engineer: Design Document

## Problem

The `core` orchestrator dispatches work to subagents (`core_engineer`, `core_reviewer`, `core_debugger`, etc.) to manage context lifecycle. Each subagent gets a fresh context window, and the orchestrator recovers context when the subagent returns.

This works well but creates duplication. The engineer, reviewer, and debugger all need the same coding standards and framework rules. Each recipe lists the same files independently. When standards change, multiple recipes need updating.

We want to test whether a single engineer recipe with on-demand skills can replace the orchestrator pattern for some workflows — loading capabilities only when needed via the Skill tool.

## Approach

Build two recipes and compare them in real work:

- **Recipe A (new): `core-engineer-skilled`** — A single engineer with reviewing, debugging, and diagnosis compiled as skills. Standards load on demand when Claude invokes a skill. No subagents for those capabilities.

- **Recipe B (existing): `core`** — The current orchestrator that dispatches to `core_engineer`, `core_reviewer`, `core_debugger` as separate agents with fresh context.

## Design

### Compiled Skills

A compiled skill combines multiple standard files into a single skill using `requires:` frontmatter. Ruly already supports this — `requires:` pulls in referenced files during squash, and files in `/skills/` directories auto-generate `.claude/skills/{name}/SKILL.md`.

Each compiled skill needs a rich `description` in its frontmatter. This description is the only thing Claude sees before invoking — it determines whether Claude reaches for the skill.

### New Compiled Skills to Create

**1. `rules/workaxle/core/skills/code-review.md`**

Compiles review standards into a single on-demand skill.

```yaml
---
description: >
  Code review skill — invoke when reviewing PRs, evaluating code quality,
  or checking standards compliance. Covers WorkAxle coding standards,
  architecture patterns, Ruby style, Sequel ORM patterns, and monad usage.
  Use for any "review this code" or "check this PR" task.
requires:
  - ../../github/pr/skills/reviewing-prs.md
  - ../standards/code-patterns.md
  - ../standards/architecture-patterns.md
  - ../frameworks/monads.md
  - ../frameworks/ruby-practices.md
  - ../frameworks/sequel.md
  - ../frameworks/standards/code-style-guidelines.md
  - ../frameworks/standards/guard-clauses-early-returns.md
  - ../frameworks/standards/instance-variables-memoization.md
  - ../frameworks/standards/constants-configuration.md
  - ../frameworks/standards/error-handling.md
---
```

**2. `rules/workaxle/core/skills/bug-diagnosis.md`**

Compiles systematic debugging into a single on-demand skill.

```yaml
---
description: >
  Bug diagnosis skill — invoke when investigating bugs, test failures,
  or unexpected behavior. Covers systematic debugging workflow, root cause
  tracing, defense-in-depth verification, and WorkAxle-specific debugging
  patterns (Sequel, gRPC, policies, RSpec).
requires:
  - ../../bug/skills/debugging.md
  - ../../bug/policies.md
  - ../../bug/rspec-debugging-guide.md
  - ../../bug/commands/grpc.md
---
```

**3. `rules/workaxle/core/skills/bug-fix.md`**

Compiles TDD-driven fix workflow into a single on-demand skill.

```yaml
---
description: >
  Bug fix skill — invoke after diagnosis is complete and you need to
  implement a fix. Covers TDD workflow (failing test first), RSpec patterns,
  factory setup, and WorkAxle testing standards.
requires:
  - ../testing/rspec-reference.md
  - ../testing/rspec-patterns.md
  - ../testing/rspec-sequel.md
  - ../testing/specs.md
  - ../standards/runtime-concerns.md
---
```

### The Test Recipe

```yaml
core-engineer-skilled:
  description: "WorkAxle engineer with on-demand skills for reviewing, debugging, and fixing"
  model: sonnet
  files:
    # === Core (always loaded) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/essential/
    # === Frameworks (always loaded — needed for daily coding) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/sequel.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/monads.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/ruby-practices.md
    # === Standards (always loaded — core coding patterns) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/code-patterns.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/architecture-patterns.md
    # === TDD (always loaded — engineer always uses TDD) ===
    - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/SKILL.md
    - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/testing-anti-patterns.md
    - /Users/patrick/Projects/ruly/superpowers/skills/verification-before-completion/SKILL.md
    # === Skills (loaded on demand via Skill tool) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core/skills/code-review.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/skills/bug-diagnosis.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/skills/bug-fix.md
    # === Existing skills (already work) ===
    - /Users/patrick/Projects/ruly/rules/bug/skills/debugging.md
    # === Dispatch rules for agents that remain agents ===
    - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-comms.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-merger.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/dispatches/use-context-grabber.md
    # === PR Operations ===
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
    - /Users/patrick/Projects/ruly/rules/github/pr/skills/pr-review-loop.md
    # === Context ===
    - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
  subagents:
    # Only agents that genuinely need fresh context / isolation
    - name: comms
      recipe: comms
    - name: merger
      recipe: merger
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
```

### What Changes vs Current `core-engineer`

| Capability | Current `core-engineer` | New `core-engineer-skilled` |
|-----------|------------------------|---------------------------|
| Coding standards | Always loaded | Always loaded (same) |
| Frameworks | Always loaded | Always loaded (same) |
| TDD | Always loaded | Always loaded (same) |
| Code review | Not available | On-demand skill |
| Bug diagnosis | Minimal (debugging.md only) | On-demand compiled skill |
| Bug fix | Not available | On-demand compiled skill |
| PR review loop | Not available | Available (loaded) |
| Comms/Merger | Not available | Dispatched to agents |

### What We're Testing

1. **Does Claude invoke skills reliably?** — When asked to review code, does it invoke the `code-review` skill, or does it try to review without standards?
2. **Are descriptions sufficient as hints?** — If Claude ignores skills, we know we need `invokes/` hint files.
3. **Context accumulation** — Does a long session with skill invocations fill context faster than the orchestrator pattern?
4. **Quality comparison** — Is the review quality from a skill (shared context, sees the code) comparable to a fresh agent reviewer?

## Future: `invokes/` Hint Files

If testing shows Claude needs stronger routing signals for skills, we add `invokes/` as a parallel to `dispatches/`:

- `invokes:` frontmatter on hint files in `invokes/` directories
- Auto-detected by path (like `commands/`, `skills/`, `dispatches/`)
- Validated at squash time: `invokes:` names must match available skills
- Lightweight instruction files with "When This Applies" / "Red Flags" sections

We build this only if the experiment proves descriptions alone are insufficient.

## No New Ruly Features Required

Everything in this design uses existing ruly capabilities:

- `requires:` frontmatter for composing compiled skills
- `/skills/` directory convention for auto-detection
- `skills:` frontmatter in rule files for referencing skills
- Standard recipe YAML with `files:` and `subagents:`

The only new artifacts are the compiled skill files and the test recipe entry in recipes.yml.
