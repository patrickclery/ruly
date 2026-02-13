# PR Readiness Chart Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a shell script that reads cached `.toon` context files, evaluates PR readiness gates, and outputs a colored Mermaid flowchart — green for passed gates, red for failed, grey for intermediate nodes.

**Architecture:**

```
Slash command (/readiness-chart)
  │
  ├─ 1. Check cache freshness (check-cache-freshness.sh)
  ├─ 2. If stale/missing → dispatch context_fetcher subagent
  ├─ 3. Run pr-readiness-chart.sh ~/tmp/context/{ISSUE}
  └─ 4. Present Mermaid output
```

The script does NOT fetch anything — it only reads `.toon` files from a cache directory. All fetching is handled by the existing `context_fetcher` subagent, cache freshness by `check-cache-freshness.sh`, and invalidation by `invalidate-cache.sh`.

**Tech Stack:** Bash, jq, Mermaid

---

### Task 1: Create script that reads cache and evaluates gates

**Files:**
- Create: `rules/github/pr/bin/pr-readiness-chart.sh`

The script takes a cache directory path, finds all `.toon` files, reads them, and evaluates gates.

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pr-readiness-chart.sh <context_dir>

Read cached .toon files from a context directory and output a colored
Mermaid flowchart showing PR readiness gate status.

Arguments:
  context_dir    Path to ~/tmp/context/{ISSUE} with cached .toon files

Prerequisites:
  Run fetch-pr-details.sh and fetch-jira-details.sh first (or dispatch
  context_fetcher subagent) to populate the context directory.

Output: Mermaid markdown to stdout (one chart per PR)
  Green = gate passed | Red = gate failed | Grey = neutral
EOF
  exit "${1:-0}"
}

# Args
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
CONTEXT_DIR="${1:-}"
[[ -z "$CONTEXT_DIR" ]] && { echo "Error: Provide a context directory path" >&2; usage 1; }

# Expand ~
CONTEXT_DIR="${CONTEXT_DIR/#\~/$HOME}"

[[ ! -d "$CONTEXT_DIR" ]] && { echo "Error: Directory not found: $CONTEXT_DIR" >&2; exit 1; }

# Dependency check
command -v jq &>/dev/null || { echo "Error: jq is required" >&2; exit 1; }

# --- Read .toon files ---

read_cached_json() {
  local file=$1
  [[ ! -f "$file" ]] && { echo "{}"; return; }
  # Try as JSON first
  local content
  content=$(jq '.' "$file" 2>/dev/null) && { echo "$content"; return; }
  # Try TOON decode
  if command -v npx &>/dev/null; then
    content=$(npx @toon-format/cli --decode < "$file" 2>/dev/null) && { echo "$content"; return; }
  fi
  echo "{}"
}

# Find PR and Jira files in context dir
PR_FILES=()
while IFS= read -r f; do
  PR_FILES+=("$f")
done < <(find "$CONTEXT_DIR" -maxdepth 1 -name 'pull-request-*.toon' -type f 2>/dev/null | sort)

JIRA_FILE=$(find "$CONTEXT_DIR" -maxdepth 1 -name 'jira-*.toon' -type f 2>/dev/null | head -1)

[[ ${#PR_FILES[@]} -eq 0 ]] && { echo "Error: No pull-request-*.toon files in $CONTEXT_DIR" >&2; exit 1; }

# Read Jira status
jira_status="UNKNOWN"
if [[ -n "$JIRA_FILE" ]]; then
  jira_json=$(read_cached_json "$JIRA_FILE")
  jira_status=$(echo "$jira_json" | jq -r '.fields.status.name // .fields.status // "UNKNOWN"')
fi
```

**Step 2: Make executable and test**

```bash
chmod +x rules/github/pr/bin/pr-readiness-chart.sh
rules/github/pr/bin/pr-readiness-chart.sh --help
rules/github/pr/bin/pr-readiness-chart.sh
```

Expected: Usage on `--help`, error on no args.

If there's existing cached context, also test file discovery:

```bash
rules/github/pr/bin/pr-readiness-chart.sh ~/tmp/context/WA-15655
```

Expected: Should find `.toon` files (or error if directory doesn't exist yet).

**Step 3: Commit**

```bash
git add rules/github/pr/bin/pr-readiness-chart.sh
git commit -m "feat: add pr-readiness-chart script skeleton"
```

---

### Task 2: Add gate evaluation

**Files:**
- Modify: `rules/github/pr/bin/pr-readiness-chart.sh`

**Note on field names:** `fetch-pr-details.sh` renames fields in its jq filter:
- `statusCheckRollup` → `.checks` (array of `{name, status, conclusion}`)
- `author.login` → `.author` (flat string)
- Adds `.unresolvedThreadCount` (computed via GraphQL)
- `comments[].author.login` → `.comments[].author` (flat string)

**Step 1: Add gate evaluation function after the file discovery section**

```bash
# --- Gate Evaluation ---
# Sets global GATE_* variables: "pass" or "fail", plus GATE_*_DETAIL strings

evaluate_gates() {
  local pr_json=$1 jira_status=$2

  local merge_state title unresolved
  merge_state=$(echo "$pr_json" | jq -r '.mergeStateStatus // "UNKNOWN"')
  title=$(echo "$pr_json" | jq -r '.title')
  unresolved=$(echo "$pr_json" | jq -r '.unresolvedThreadCount // 0')

  # CI check counts (.checks from fetch-pr-details.sh, not .statusCheckRollup)
  local total success failing pending neutral
  total=$(echo "$pr_json" | jq '[.checks // [] | .[]] | length')
  success=$(echo "$pr_json" | jq '[.checks // [] | .[] | select(.conclusion == "SUCCESS")] | length')
  failing=$(echo "$pr_json" | jq '[.checks // [] | .[] | select(.conclusion == "FAILURE")] | length')
  pending=$(echo "$pr_json" | jq '[.checks // [] | .[] | select(.conclusion == null)] | length')
  neutral=$(echo "$pr_json" | jq '[.checks // [] | .[] | select(.conclusion == "NEUTRAL")] | length')

  # Bot comment heuristic (.author is flat string from fetch script)
  local last_bot bot_issues="false"
  last_bot=$(echo "$pr_json" | jq -r '
    [.comments // [] | .[] | select(.author == "github-actions" or .author == "cursor")]
    | last // {body:""} | .body')
  if echo "$last_bot" | grep -qiE 'issues?\s+found|warning|critical' 2>/dev/null; then
    echo "$last_bot" | grep -qiE 'no\s+issues|no\s+critical|passed' 2>/dev/null || bot_issues="true"
  fi

  # Branch up-to-date
  GATE_BRANCH="pass"; GATE_BRANCH_DETAIL="Up to date"
  [[ "$merge_state" == "BEHIND" ]] && { GATE_BRANCH="fail"; GATE_BRANCH_DETAIL="BEHIND"; }

  # CI checks
  GATE_CI="pass"; GATE_CI_DETAIL="${success}/${total} passed"
  if [[ $failing -gt 0 ]]; then
    GATE_CI="fail"; GATE_CI_DETAIL="${failing}/${total} failing"
  elif [[ $neutral -gt 0 ]]; then
    GATE_CI="fail"; GATE_CI_DETAIL="Bugbot NEUTRAL"
  elif [[ $pending -gt 0 ]]; then
    GATE_CI="fail"; GATE_CI_DETAIL="${pending}/${total} pending"
  fi

  # Unresolved threads (already computed by fetch-pr-details.sh GraphQL)
  GATE_THREADS="pass"; GATE_THREADS_DETAIL="0 unresolved"
  [[ $unresolved -gt 0 ]] && { GATE_THREADS="fail"; GATE_THREADS_DETAIL="${unresolved} unresolved"; }

  # Bot comments
  GATE_BOT="pass"; GATE_BOT_DETAIL="No issues"
  [[ "$bot_issues" == "true" ]] && { GATE_BOT="fail"; GATE_BOT_DETAIL="Unaddressed issues"; }

  # PR title convention: [WA-XXXX] type(scope): description
  GATE_TITLE="pass"; GATE_TITLE_DETAIL="Matches convention"
  if ! [[ "$title" =~ ^\[[A-Z]+-[0-9]+\]\ [a-z]+\( ]]; then
    GATE_TITLE="fail"; GATE_TITLE_DETAIL="Needs fixing"
  fi

  # Jira status
  GATE_JIRA="pass"; GATE_JIRA_DETAIL="$jira_status"
  [[ "$jira_status" == "UNDER REVIEW" ]] || GATE_JIRA="fail"
}
```

**Step 2: Add a temporary debug loop at the end to verify gates**

```bash
# --- Temporary: verify gate evaluation ---
for pr_file in "${PR_FILES[@]}"; do
  pr_json=$(read_cached_json "$pr_file")
  pr_num=$(echo "$pr_json" | jq -r '.number // "?"')
  evaluate_gates "$pr_json" "$jira_status"

  echo "PR #$pr_num gate results:" >&2
  echo "  Branch:  $GATE_BRANCH ($GATE_BRANCH_DETAIL)" >&2
  echo "  CI:      $GATE_CI ($GATE_CI_DETAIL)" >&2
  echo "  Threads: $GATE_THREADS ($GATE_THREADS_DETAIL)" >&2
  echo "  Bot:     $GATE_BOT ($GATE_BOT_DETAIL)" >&2
  echo "  Title:   $GATE_TITLE ($GATE_TITLE_DETAIL)" >&2
  echo "  Jira:    $GATE_JIRA ($GATE_JIRA_DETAIL)" >&2
done
```

**Step 3: Test with existing cached context**

If cached context exists from a previous context_fetcher run:

```bash
rules/github/pr/bin/pr-readiness-chart.sh ~/tmp/context/WA-15655
```

Expected: Gate results printed to stderr. Cross-check against `gh pr checks` to verify accuracy.

**Step 4: Commit**

```bash
git add rules/github/pr/bin/pr-readiness-chart.sh
git commit -m "feat: add gate evaluation for PR readiness chart"
```

---

### Task 3: Add colored Mermaid chart generation

**Files:**
- Modify: `rules/github/pr/bin/pr-readiness-chart.sh`

**Step 1: Add Mermaid generation functions and replace debug loop with main loop**

```bash
# --- Mermaid Generation ---

gate_class() { echo "$1"; }
fix_class() { [[ "$1" == "fail" ]] && echo "fail" || echo "neutral"; }

generate_chart() {
  local pr_num=$1 base_ref=$2

  local all_pass="pass"
  for g in "$GATE_BRANCH" "$GATE_CI" "$GATE_THREADS" "$GATE_BOT" "$GATE_TITLE" "$GATE_JIRA"; do
    [[ "$g" == "fail" ]] && { all_pass="fail"; break; }
  done
  local final_class
  [[ "$all_pass" == "pass" ]] && final_class="pass" || final_class="neutral"

  echo '```mermaid'
  cat <<CHART
---
title: "PR #${pr_num} → ${base_ref}"
---
flowchart TD
    Start([Code Complete]) --> BranchCheck{Branch up to date?\\n${GATE_BRANCH_DETAIL}}

    BranchCheck -->|No| UpdateBranch[Update the branch from\\nGitHub or the CLI]
    UpdateBranch --> WaitForCI
    BranchCheck -->|Yes| CICheck

    WaitForCI[Wait for CI to run] --> CICheck{CI checks passing?\\n${GATE_CI_DETAIL}}

    CICheck -->|Failing| FixCI[Fix failing checks\\nand push]
    FixCI --> WaitForCI
    CICheck -->|Pending| WaitCI[Wait for CI to complete]
    WaitCI --> CICheck
    CICheck -->|All passing| ThreadCheck{Review threads resolved?\\n${GATE_THREADS_DETAIL}}

    ThreadCheck -->|No| ResolveThreads[Resolve threads:\\nfix and mark resolved]
    ResolveThreads --> WaitForCI
    ThreadCheck -->|Yes| BotCheck{Bot comments addressed?\\n${GATE_BOT_DETAIL}}

    BotCheck -->|No| AddressBot[Address bot concerns\\nand push]
    AddressBot --> WaitForCI
    BotCheck -->|Yes| TitleCheck{PR title follows convention?\\n${GATE_TITLE_DETAIL}}

    TitleCheck -->|No| FixTitle[Rename the PR]
    FixTitle --> TitleCheck
    TitleCheck -->|Yes| PRPass

    PRPass(All PR gates passed) --> JiraCheck{Jira ticket set to\\nUNDER REVIEW?\\nStatus: ${GATE_JIRA_DETAIL}}
    JiraCheck -->|No| SetJira[Move ticket to\\nUNDER REVIEW]
    SetJira --> ReadyForReview
    JiraCheck -->|Yes| ReadyForReview([Ready for Review])

    classDef pass fill:#22c55e,color:#fff,stroke:#16a34a
    classDef fail fill:#ef4444,color:#fff,stroke:#dc2626
    classDef neutral fill:#e5e7eb,color:#6b7280,stroke:#d1d5db

    class Start pass
    class BranchCheck $(gate_class "$GATE_BRANCH")
    class UpdateBranch $(fix_class "$GATE_BRANCH")
    class WaitForCI neutral
    class CICheck $(gate_class "$GATE_CI")
    class FixCI $(fix_class "$GATE_CI")
    class WaitCI $(fix_class "$GATE_CI")
    class ThreadCheck $(gate_class "$GATE_THREADS")
    class ResolveThreads $(fix_class "$GATE_THREADS")
    class BotCheck $(gate_class "$GATE_BOT")
    class AddressBot $(fix_class "$GATE_BOT")
    class TitleCheck $(gate_class "$GATE_TITLE")
    class FixTitle $(fix_class "$GATE_TITLE")
    class PRPass $(gate_class "$all_pass")
    class JiraCheck $(gate_class "$GATE_JIRA")
    class SetJira $(fix_class "$GATE_JIRA")
    class ReadyForReview ${final_class}
CHART
  echo '```'
}

# --- Main ---

for pr_file in "${PR_FILES[@]}"; do
  pr_json=$(read_cached_json "$pr_file")
  pr_num=$(echo "$pr_json" | jq -r '.number // "?"')
  base_ref=$(echo "$pr_json" | jq -r '.baseRefName // "unknown"')

  evaluate_gates "$pr_json" "$jira_status"
  generate_chart "$pr_num" "$base_ref"
done
```

**Step 2: Test with existing cached context**

```bash
rules/github/pr/bin/pr-readiness-chart.sh ~/tmp/context/WA-15655
```

Expected: Mermaid code blocks to stdout (one per PR). Copy output and paste into https://mermaid.live to verify rendering and colors.

**Step 3: Commit**

```bash
git add rules/github/pr/bin/pr-readiness-chart.sh
git commit -m "feat: generate colored Mermaid flowchart for PR readiness"
```

---

### Task 4: Create the slash command

**Files:**
- Create: `rules/github/pr/commands/readiness-chart.md`

The slash command handles all orchestration: cache check, context fetching, and running the script. It follows the existing patterns from `rules/comms/use-context-fetcher.md`.

**Step 1: Write the command**

```markdown
---
description: Generate a colored Mermaid flowchart showing PR readiness gate status
alwaysApply: false
requires:
  - ../../comms/use-context-fetcher.md
---
# Readiness Chart

Generate a visual Mermaid flowchart showing which PR readiness gates are passing and failing for a Jira issue.

## Usage

```
/readiness-chart WA-15655
```

## Workflow

### Step 1: Extract issue key

The argument is a Jira issue key (e.g., `WA-15655`).

### Step 2: Ensure fresh context

Check cache freshness and dispatch context_fetcher if needed, following the standard context fetching rules:

```bash
check-cache-freshness.sh ~/tmp/context/{ISSUE}
```

| Result | Action |
|--------|--------|
| `NO_CACHE` | Dispatch `context_fetcher` for full fetch |
| `FRESH` | Use cached files directly |
| `STALE: pr` | Dispatch with "Refresh PR context for {ISSUE}" |
| `STALE: jira` | Dispatch with "Refresh Jira context for {ISSUE}" |
| `STALE: pr jira` | Dispatch with "Fetch context for {ISSUE}" |

### Step 3: Generate the chart

```bash
pr-readiness-chart.sh ~/tmp/context/{ISSUE}
```

### Step 4: Present the output

Show the Mermaid chart to the user. Offer to post it as a GitHub PR comment if useful.

## Output

Colored Mermaid flowchart:
- **Green** nodes = gate passed
- **Red** nodes = gate failed (action required)
- **Grey** nodes = intermediate / not applicable

Renders in GitHub comments, Confluence, mermaid.live, etc.
```

**Step 2: Commit**

```bash
git add rules/github/pr/commands/readiness-chart.md
git commit -m "feat: add /readiness-chart slash command"
```

---

### Task 5: Integration test

**Step 1: Test the script directly with existing cached context**

```bash
rules/github/pr/bin/pr-readiness-chart.sh ~/tmp/context/WA-15655
```

Copy the Mermaid output, paste into https://mermaid.live, and verify:
- Chart renders without syntax errors
- Green nodes for passing gates
- Red nodes for failing gates
- Grey for intermediate/neutral nodes
- Detail text readable in diamond nodes

**Step 2: Test with a directory that has no context**

```bash
rules/github/pr/bin/pr-readiness-chart.sh ~/tmp/context/NONEXISTENT
```

Expected: Error about missing directory.

**Step 3: Test with a directory that has no PR files**

```bash
mkdir -p /tmp/test-empty-ctx
rules/github/pr/bin/pr-readiness-chart.sh /tmp/test-empty-ctx
```

Expected: Error about no `pull-request-*.toon` files found.
