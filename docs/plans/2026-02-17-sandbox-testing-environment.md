# Sandbox Testing Environment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `create-sandbox.sh` script for the ruly project that clones any git repo into a sandbox directory and squashes a specified ruly recipe into it, producing a ready-to-use Claude Code environment for TDD of squashed rules.

**Architecture:** A bash script at `bin/create-sandbox.sh` accepts a repo URL and recipe name, clones the repo into `tmp/sandbox/<name>/`, runs `ruly squash <recipe>` inside it, and reports the result. The `tmp/` directory is already gitignored. Repeated runs with the same repo skip the clone and just re-squash (useful after rule changes).

**Tech Stack:** Bash, Git, Ruly CLI

---

### Task 1: Create the create-sandbox.sh script

**Files:**
- Create: `/Users/patrick/Projects/ruly/bin/create-sandbox.sh`

**Step 1: Write the script**

Create `/Users/patrick/Projects/ruly/bin/create-sandbox.sh`:

```bash
#!/usr/bin/env bash
# Creates a sandbox environment for testing ruly recipes against a real codebase.
#
# Clones a git repo into tmp/sandbox/<name>/, then squashes the specified
# recipe into it. If the repo is already cloned, pulls latest and re-squashes.
#
# Usage:
#   create-sandbox.sh <repo_url> <recipe> [--name <dir_name>]
#
# Arguments:
#   <repo_url>   Git repository URL (SSH or HTTPS)
#   <recipe>     Ruly recipe to squash
#   --name       Optional directory name (default: derived from repo URL)
#
# Examples:
#   create-sandbox.sh git@github.com:org/backend.git core
#   create-sandbox.sh git@github.com:org/backend.git comms --name api
#   create-sandbox.sh git@github.com:org/frontend.git frontend --name fe

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SANDBOX_DIR="$RULY_ROOT/tmp/sandbox"

# Parse arguments
REPO_URL=""
RECIPE=""
DIR_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      shift
      DIR_NAME="$1"
      shift
      ;;
    -h|--help)
      sed -n '2,/^[^#]/{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *)
      if [ -z "$REPO_URL" ]; then
        REPO_URL="$1"
      elif [ -z "$RECIPE" ]; then
        RECIPE="$1"
      else
        echo "Error: unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$REPO_URL" ] || [ -z "$RECIPE" ]; then
  echo "Usage: create-sandbox.sh <repo_url> <recipe> [--name <dir_name>]"
  echo "  Run 'create-sandbox.sh --help' for details"
  exit 1
fi

# Derive directory name from repo URL if not specified
if [ -z "$DIR_NAME" ]; then
  DIR_NAME=$(basename "$REPO_URL" .git)
fi

TARGET_DIR="$SANDBOX_DIR/$DIR_NAME"

# Verify ruly is available
if ! command -v ruly &>/dev/null; then
  echo "Error: ruly is not installed or not in PATH"
  exit 1
fi

echo "=== Ruly Sandbox ==="
echo "  Repo:    $REPO_URL"
echo "  Recipe:  $RECIPE"
echo "  Target:  $TARGET_DIR"
echo ""

# Clone or pull
if [ -d "$TARGET_DIR/.git" ]; then
  echo "Repo already cloned. Pulling latest..."
  git -C "$TARGET_DIR" pull --ff-only 2>/dev/null || echo "Warning: pull failed (detached HEAD or conflicts). Continuing with existing checkout."
else
  echo "Cloning repo..."
  mkdir -p "$SANDBOX_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

echo ""
echo "Squashing recipe '$RECIPE'..."
cd "$TARGET_DIR" && ruly squash "$RECIPE"

echo ""
echo "=== Sandbox Ready ==="
echo "  Directory: $TARGET_DIR"
echo "  Recipe:    $RECIPE"
echo ""
echo "To use:"
echo "  cd $TARGET_DIR"
echo "  claude -p 'your test prompt'"
echo ""
echo "To re-squash after rule changes:"
echo "  cd $TARGET_DIR && ruly squash $RECIPE"
```

**Step 2: Make it executable**

Run: `chmod +x /Users/patrick/Projects/ruly/bin/create-sandbox.sh`

**Step 3: Verify syntax**

Run: `bash -n /Users/patrick/Projects/ruly/bin/create-sandbox.sh`

Expected: No output (silent success).

**Step 4: Commit**

```bash
cd /Users/patrick/Projects/ruly && git add bin/create-sandbox.sh && git commit -m "feat: add create-sandbox script for recipe TDD"
```

---

### Task 2: Test the script end-to-end

**Step 1: Run create-sandbox.sh with any repo and recipe**

Run:
```bash
/Users/patrick/Projects/ruly/bin/create-sandbox.sh git@github.com:org/myapp.git core --name core
```

Expected:
- Clones repo to `tmp/sandbox/core/`
- Squashes recipe
- Reports success with CLAUDE.local.md size, token count, commands, skills, subagents

**Step 2: Verify generated files exist**

Run:
```bash
ls tmp/sandbox/core/CLAUDE.local.md && find tmp/sandbox/core/.claude -name '*.md' | head -10
```

Expected: CLAUDE.local.md exists, `.claude/` contains generated `.md` files (commands, skills, agents — varies by recipe).

**Step 3: Verify sandbox is gitignored**

Run:
```bash
cd /Users/patrick/Projects/ruly/rules && git status
```

Expected: Clean — no sandbox files showing.

---

### Task 3: Test re-squash (already cloned)

**Step 1: Re-run with a different recipe (same repo)**

Run:
```bash
/Users/patrick/Projects/ruly/bin/create-sandbox.sh git@github.com:org/myapp.git comms --name core
```

Expected:
- Detects repo already cloned, pulls latest
- Squashes the new recipe
- Reports success

**Step 2: Verify the recipe switched**

Run:
```bash
find tmp/sandbox/core/.claude -name '*.md' | head -10
```

Expected: Different files than the previous recipe — confirms the squash replaced the prior output.

---

## Notes

### Script Location

Lives at `bin/create-sandbox.sh` alongside `bin/ruly` — it's a ruly development tool, not a rule.

### Sandbox Lifecycle

```
create-sandbox.sh <repo> <recipe>    # First run: clone + squash
create-sandbox.sh <repo> <recipe>    # Subsequent: pull + re-squash
cd tmp/sandbox/<name> && claude -p "your test prompt"  # Run headless
rm -rf tmp/sandbox/<name>          # Clean up
```

### TDD Workflow for Rules

1. Edit rules in `rules/`
2. Re-squash: `cd tmp/sandbox/<name> && ruly squash <recipe>`
3. Start a Claude session: `claude`
4. Test the squashed behavior
5. Iterate

### Multiple Sandboxes

Different repos can coexist:

```bash
create-sandbox.sh git@github.com:org/backend.git core --name api
create-sandbox.sh git@github.com:org/frontend.git frontend --name fe
```

Each gets its own directory under `tmp/sandbox/`.
