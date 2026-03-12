# Frontend Orchestrator Recipe

## Summary

Create a `frontend` top-level orchestrator recipe for WorkAxle's `workaxle-desktop` React/TypeScript application, at the same level as the existing `core` orchestrator. Extract conventions from the repo's CLAUDE.md and `.claude/` rules into `rules/workaxle/frontend/`, wire up a `frontend-engineer` subagent with superpowers skills, and reuse existing shared subagents.

## Source Material

- `workaxle/workaxle-desktop` repo CLAUDE.md (~17.5KB)
- `.claude/rules/comments.md` — comment policy
- `.claude/rules/testing.md` — BDD-style test structure
- `.claude/rules/typescript.md` — TypeScript naming and safety rules
- `.claude/skills/react-useeffect/` — useEffect best practices
- Tech stack: React 19, TypeScript 5.9, Vite, Apollo Client, Storeon, React Hook Form + Vest, Vitest + RTL, styled-components + styled-system

## Files to Create

### Frontend Rule Files (`rules/workaxle/frontend/`)

| # | File | Content | Source |
|---|------|---------|--------|
| 1 | `conventions.md` | Component/hook/handler naming (PascalCase, `use` prefix, `handle` prefix, boolean `is`/`has`/`can`/`should`), comment policy (no what-comments, no commented-out code), fractal folder structure, barrel exports | CLAUDE.md naming + `.claude/rules/comments.md` |
| 2 | `state-management.md` | When to use Storeon vs Apollo Client vs Redux vs React Query, deprecation of Redux for new features, server state vs client state rules | CLAUDE.md state management section |
| 3 | `graphql.md` | Apollo Client patterns, fragment conventions, operation naming, GraphQL Codegen typed documents, cache policies | CLAUDE.md GraphQL conventions |
| 4 | `forms.md` | React Hook Form preferences, Vest validation, string trimming requirements, dirty state detection patterns | CLAUDE.md form handling |
| 5 | `styling.md` | styled-components + styled-system, theme values (numbers for spacing), custom pixel values as strings, `css` function extraction rule (only for multi-property), path aliases | CLAUDE.md styling rules |
| 6 | `testing.md` | Vitest + React Testing Library, BDD structure (`#given`/`#when`/`#then`), test ID conventions (`composeTestId()`, constants not inline strings, `testIdPrefix` prop, `data-testid` on interactive elements), what to unit test vs integration test | CLAUDE.md testing + `.claude/rules/testing.md` |
| 7 | `typescript.md` | No `any` without justification, no `@ts-ignore`/`@ts-expect-error` without explanation, prefer `unknown`, enum placement in `constants/` not `types/`, descriptive parameter names (no single-letter), async/await rules | `.claude/rules/typescript.md` + CLAUDE.md |
| 8 | `performance.md` | Debouncing patterns, picker optimization, memoization rules (useMemo/useCallback), when NOT to use useEffect (from `.claude/skills/react-useeffect/`), React 19 considerations | CLAUDE.md performance + `.claude/skills/react-useeffect/` |
| 9 | `architecture.md` | AHA Programming, KISS, SOLID principles, domain-driven API organization (107 domain folders), utils organization (global vs component-specific), CASL authorization patterns, Auth0 integration patterns | CLAUDE.md architecture |

### Dispatch Rule (`rules/workaxle/frontend/standards/`)

| # | File | Content |
|---|------|---------|
| 10 | `use-frontend-engineer.md` | Dispatch rule: when the orchestrator should route to `frontend_engineer` subagent (feature implementation, bug fixing, architecture questions, component design) |

### Recipes (in `recipes.yml` and `~/.config/ruly/recipes.yml`)

#### 11. `frontend` (orchestrator)

```yaml
frontend:
  description: "WorkAxle frontend dispatcher - routes tasks to specialized subagents"
  files:
    # === Frontend Core (minimal for routing) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/conventions.md
    # === Dispatch Rules ===
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/standards/use-frontend-engineer.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-comms.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-merger.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-pr-readiness.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/standards/use-reviewer.md
    # === PR Operations ===
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-develop.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/create-dual.md
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/review-feedback-loop.md
    # === Context Fetching ===
    - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
    - /Users/patrick/Projects/ruly/rules/comms/commands/refresh-context.md
  subagents:
    - name: frontend_engineer
      recipe: frontend-engineer
    - name: context_fetcher
      recipe: context-fetcher
    - name: comms
      recipe: comms
    - name: merger
      recipe: merger
    - name: pr_readiness
      recipe: pr-readiness
    - name: reviewer
      recipe: frontend-reviewer
```

#### 12. `frontend-engineer` (subagent)

```yaml
frontend-engineer:
  description: "WorkAxle frontend feature development and architecture - React/TypeScript with TDD"
  files:
    # === Superpowers: TDD & Verification ===
    - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/SKILL.md
    - /Users/patrick/Projects/ruly/superpowers/skills/test-driven-development/testing-anti-patterns.md
    - /Users/patrick/Projects/ruly/superpowers/skills/verification-before-completion/SKILL.md
    # === Frontend Rules (all 9) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/conventions.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/state-management.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/graphql.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/forms.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/styling.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/testing.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/typescript.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/performance.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/architecture.md
    # === Playwright ===
    - /Users/patrick/Projects/ruly/rules/workaxle/orchestrator/playwright.md
  mcp_servers:
    - playwright
    - Ref
```

#### 13. `frontend-reviewer` (subagent)

```yaml
frontend-reviewer:
  description: "WorkAxle frontend PR code review - React/TypeScript standards enforcement"
  files:
    # === Superpowers: Code Review ===
    - /Users/patrick/Projects/ruly/superpowers/skills/requesting-code-review/SKILL.md
    - /Users/patrick/Projects/ruly/superpowers/skills/requesting-code-review/code-reviewer.md
    # === Reviewing skill ===
    - /Users/patrick/Projects/ruly/rules/github/pr/skills/reviewing-prs.md
    # === Frontend Standards (review lens) ===
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/conventions.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/state-management.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/graphql.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/forms.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/styling.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/testing.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/typescript.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/performance.md
    - /Users/patrick/Projects/ruly/rules/workaxle/frontend/architecture.md
    # === Context fetching ===
    - /Users/patrick/Projects/ruly/rules/comms/use-context-fetcher.md
    - /Users/patrick/Projects/ruly/rules/comms/context-fetcher-subagent.md
    # === PR common ===
    - /Users/patrick/Projects/ruly/rules/github/pr/common.md
    # === PR readiness chart ===
    - /Users/patrick/Projects/ruly/rules/github/pr/commands/readiness-chart.md
    # === Jira statuses (for readiness gates) ===
    - /Users/patrick/Projects/ruly/rules/comms/jira/statuses.md
  subagents:
    - name: context_fetcher
      recipe: context-fetcher
```

## Implementation Order

1. **Create directory structure**: `rules/workaxle/frontend/` and `rules/workaxle/frontend/standards/`
2. **Clone workaxle-desktop** to `/tmp/workaxle-desktop` (if not already there) to extract content
3. **Extract rule files** (1-9): Read workaxle-desktop's CLAUDE.md and .claude/ files, write each rule file
4. **Create dispatch rule** (10): `use-frontend-engineer.md`
5. **Update recipes.yml** with all 3 recipes (frontend, frontend-engineer, frontend-reviewer)
6. **Copy recipes.yml** to `~/.config/ruly/recipes.yml`
7. **Test**: Run `ruly squash --recipe frontend` from a temp directory to verify
8. **Test**: Run `ruly squash --recipe frontend-engineer` from a temp directory to verify
9. **Test**: Run `ruly squash --recipe frontend-reviewer` from a temp directory to verify

## Notes

- The 9 frontend rule files are extracted from workaxle-desktop's existing conventions — they become the ruly source of truth
- Shared subagents (comms, merger, pr_readiness, context_fetcher) are reused from existing recipes without modification
- The `frontend` orchestrator uses `frontend-reviewer` instead of the generic `reviewer` recipe so reviews apply frontend-specific standards
- Playwright rules are included in `frontend-engineer` via the existing `orchestrator/playwright.md` file
- Refinement of individual rule files happens after initial extraction
