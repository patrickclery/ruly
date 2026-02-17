# Ready or Not — GitHub Marketplace Action

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish a GitHub Marketplace Action that posts a Mermaid PR readiness flowchart when users comment `/ready-or-not` on a PR.

**Repo:** `patrickclery/ready-or-not` (new public repo)

**Tech Stack:** TypeScript, `@actions/core`, `@actions/github` (Octokit), `@vercel/ncc`, `vitest`

---

## Architecture

A composite TypeScript action bundled into `dist/index.js` via `ncc`. No external dependencies beyond the automatic `GITHUB_TOKEN`. No Jira, no CLI tools, no caching layer.

### Three Gates

| Gate | API Call | Pass | Fail |
|------|----------|------|------|
| Branch freshness | `GET /repos/{owner}/{repo}/compare/{base}...{head}` | `behind_by == 0` | `behind_by > 0` |
| CI checks | `GET /repos/{owner}/{repo}/commits/{ref}/check-runs` + `statuses` | All success | Any failure |
| Review threads | `GraphQL: pullRequest.reviewThreads` | All resolved | Unresolved threads exist |

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `token` | `github.token` | GitHub token (auto-provided) |
| `pr-number` | auto-detected | Override PR number |
| `comment-tag` | `ready-or-not-marker` | HTML comment marker for collapsing old comments |

### Output

Posts a Mermaid flowchart as a PR comment. Hides previous readiness comments via `minimizeComment` GraphQL mutation. Adds a thumbs-up reaction to the trigger comment.

**Node coloring:**
- Green (`#2ea043`) — gate passed
- Red (`#cf222e`) — gate failed
- Grey (`#848d97`) — not yet reached / pending

Gate failure details appear in edge labels (e.g., `|No: 3/12 failing: CI, SAST, lint|`).

### Usage

```yaml
name: PR Readiness Check
on:
  issue_comment:
    types: [created]

jobs:
  readiness:
    if: |
      github.event.issue.pull_request &&
      contains(github.event.comment.body, '/ready-or-not')
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
      checks: read
      statuses: read
      actions: read
    steps:
      - uses: patrickclery/ready-or-not@v1
```

---

## Project Structure

```
ready-or-not/
├── action.yml              # Action metadata
├── src/
│   ├── index.ts            # Entry point
│   ├── gates/
│   │   ├── branch.ts       # Branch freshness
│   │   ├── checks.ts       # CI checks + statuses
│   │   └── threads.ts      # Unresolved review threads
│   ├── chart.ts            # Mermaid flowchart generator
│   └── comment.ts          # Post comment, hide previous, add reaction
├── dist/
│   └── index.js            # Bundled output (committed)
├── __tests__/
│   ├── gates/
│   │   ├── branch.test.ts
│   │   ├── checks.test.ts
│   │   └── threads.test.ts
│   ├── chart.test.ts
│   └── comment.test.ts
├── package.json
└── tsconfig.json
```

---

## Tasks

### Task 1: Scaffold the project

**Files:**
- Create: `package.json`, `tsconfig.json`, `action.yml`, `.gitignore`

**Step 1:** Create a new public repo `patrickclery/ready-or-not` on GitHub.

**Step 2:** Initialize the project:

```bash
mkdir -p src/gates __tests__/gates dist
npm init -y
npm install @actions/core @actions/github
npm install -D typescript @vercel/ncc vitest @types/node
```

**Step 3:** Create `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "./lib",
    "rootDir": "./src",
    "resolveJsonModule": true,
    "declaration": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "__tests__", "dist"]
}
```

**Step 4:** Create `action.yml`:

```yaml
name: 'Ready or Not'
description: 'PR readiness check — posts a Mermaid flowchart showing gate status'
branding:
  icon: 'check-circle'
  color: 'green'
inputs:
  token:
    description: 'GitHub token'
    default: ${{ github.token }}
  pr-number:
    description: 'PR number (auto-detected if omitted)'
  comment-tag:
    description: 'HTML comment marker for collapsing old comments'
    default: 'ready-or-not-marker'
runs:
  using: 'node20'
  main: 'dist/index.js'
```

**Step 5:** Add scripts to `package.json`:

```json
{
  "scripts": {
    "build": "ncc build src/index.ts -o dist --source-map --license licenses.txt",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

**Step 6:** Create `.gitignore`:

```
node_modules/
lib/
*.js.map
```

Note: `dist/` is NOT ignored — it must be committed for GHA marketplace.

**Step 7:** Commit.

---

### Task 2: Implement gate evaluators

**Files:**
- Create: `src/gates/branch.ts`, `src/gates/checks.ts`, `src/gates/threads.ts`, `src/gates/types.ts`

**Step 1:** Create `src/gates/types.ts`:

```typescript
export type GateStatus = 'pass' | 'fail' | 'pending'

export interface GateResult {
  status: GateStatus
  detail: string
}
```

**Step 2:** Create `src/gates/branch.ts`:

Pure function. Takes the compare response, returns GateResult.
- `behind_by == 0` → pass
- `behind_by > 0` → fail with detail "N commits behind"

**Step 3:** Create `src/gates/checks.ts`:

Takes check runs and commit statuses. Merges them into a single list.
- All success → pass
- Any failure → fail with failing check names
- Any pending (no failures) → pending
- No checks → pass (nothing configured)

**Step 4:** Create `src/gates/threads.ts`:

Takes the GraphQL reviewThreads response.
- All resolved (or none) → pass
- Any unresolved → fail with count

**Step 5:** Write tests for all three gates.

**Step 6:** Commit.

---

### Task 3: Implement Mermaid chart generator

**Files:**
- Create: `src/chart.ts`

**Step 1:** Create `src/chart.ts`:

Pure function. Takes three GateResults, returns a Mermaid flowchart string.

Flowchart structure:
```
Code Complete → Wait for CI → Branch check (diamond)
                            → Checks gate (diamond)
Branch fail → Update branch → Wait for CI
Checks fail → Fix checks → Wait for CI
Both pass → All gates passed → Ready for Review
```

Node coloring:
- Pass: `style NodeName fill:#2ea043,color:#fff`
- Fail: `style NodeName fill:#cf222e,color:#fff`
- Unreached: `style NodeName fill:#848d97,color:#fff`

Edge labels include gate failure details. Line breaks use `<br/>`.

**Step 2:** Write tests — pass all, fail all, mixed states, pending checks.

**Step 3:** Commit.

---

### Task 4: Implement comment posting

**Files:**
- Create: `src/comment.ts`

**Step 1:** Create `src/comment.ts`:

Three functions:
1. `hideOldComments(octokit, owner, repo, prNumber, tag)` — find comments containing the marker tag, minimize each via `minimizeComment` GraphQL mutation
2. `postComment(octokit, owner, repo, prNumber, body)` — post the chart as a PR comment
3. `addReaction(octokit, owner, repo, commentId)` — add thumbs-up to trigger comment

**Step 2:** Write tests with mocked Octokit calls.

**Step 3:** Commit.

---

### Task 5: Implement entry point

**Files:**
- Create: `src/index.ts`

**Step 1:** Create `src/index.ts`:

Orchestration:
1. Read inputs (`token`, `pr-number`, `comment-tag`)
2. Resolve PR number from event context if not provided
3. Fetch PR details (base ref, head ref, head SHA)
4. Evaluate three gates in parallel (`Promise.all`)
5. Generate Mermaid chart
6. Hide old comments
7. Post new comment
8. Add reaction to trigger comment (if `issue_comment` event)
9. Set outputs / summary

**Step 2:** Build with `npm run build`.

**Step 3:** Commit (including `dist/index.js`).

---

### Task 6: Test end-to-end on workaxle-core

**Step 1:** Update the workflow in `workaxle/workaxle-core` (branch `ready-or-not`) to use the action from the new repo:

```yaml
steps:
  - uses: patrickclery/ready-or-not@main
```

**Step 2:** Push and verify the `on: push` trigger works.

**Step 3:** Comment `/ready-or-not` on a test PR once merged to main.

**Step 4:** Verify the Mermaid chart renders correctly.

---

### Task 7: Publish to GitHub Marketplace

**Step 1:** Tag a release:

```bash
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

**Step 2:** Create a GitHub release from the tag. Check "Publish this Action to the GitHub Marketplace."

**Step 3:** Create the floating major version tag:

```bash
git tag -fa v1 -m "Update v1 tag"
git push origin v1 --force
```

**Step 4:** Verify `uses: patrickclery/ready-or-not@v1` works.

---

## Architecture Decisions

### Why TypeScript over bash?

The bash implementation works but has maintainability issues: TOON encoding/decoding, `sed` for `\n` replacement, word-splitting bugs with `$REPO_FLAG`, and permission errors from GraphQL field access. TypeScript gives type safety, direct Octokit API access, and standard tooling (npm, vitest, ncc).

### Why no Jira gate?

Jira is organization-specific. Removing it makes the action universally useful. Teams that need Jira integration can add it as a separate check or fork the action.

### Why `minimizeComment` instead of deleting?

Minimized comments are collapsed but still accessible. Deleting loses history. Users can expand old charts if they need to see previous state.
