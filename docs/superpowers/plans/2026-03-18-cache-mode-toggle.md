# Cache Mode Toggle Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `RULY_CACHE_MODE` env var support to `check-cache-freshness.sh` and a `/cache` slash command to toggle it.

**Architecture:** Single enforcement point in `check-cache-freshness.sh` reads `RULY_CACHE_MODE` (default `auto`) and short-circuits before existing staleness logic. Slash command instructs the agent to pass the env var on subsequent invocations.

**Tech Stack:** Bash, Ruly markdown commands

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `rules/comms/bin/check-cache-freshness.sh` | Modify | Add `RULY_CACHE_MODE` case block between `MANIFEST=` (line 32) and `if [ ! -f "$MANIFEST" ]` (line 35) |
| `rules/comms/bin/test-cache-scripts.sh` | Modify | Add tests for `never`, `always`, and unknown mode behaviors |
| `rules/comms/commands/cache.md` | Create | Slash command to show/set cache mode |

---

### Task 1: Add cache mode tests to test-cache-scripts.sh

**Files:**
- Modify: `rules/comms/bin/test-cache-scripts.sh`

Tests go first. Add new test cases after existing Test 8, before the Cleanup section.

- [ ] **Step 1: Add test for `never` mode with existing cache**

Add after the Test 8 block (line 91), before the Cleanup section (line 93):

```bash
echo ""
echo "=== Test 9: RULY_CACHE_MODE=never with existing cache ==="
# Recreate fresh cache
cat > "$ISSUE_DIR/jira-TEST-12345.toon" << 'EOF'
key: TEST-12345
fields:
  updated: "2026-02-06T12:00:00Z"
EOF
echo 'number: 1234' > "$ISSUE_DIR/pull-request-1234.toon"
write-cache-manifest.sh "$ISSUE_DIR" 2>&1
# Invalidate to make it stale
invalidate-cache.sh "$ISSUE_DIR" --type jira 2>&1
# In never mode, should still return FRESH even though jira is stale
RESULT=$(RULY_CACHE_MODE=never check-cache-freshness.sh "$ISSUE_DIR" 2>&1)
assert_eq "never mode with stale cache returns FRESH" "FRESH" "$RESULT"
```

- [ ] **Step 2: Add test for `never` mode with no cache**

```bash
echo ""
echo "=== Test 10: RULY_CACHE_MODE=never with no cache ==="
rm -f "$ISSUE_DIR/.cache-manifest.toon"
RESULT=$(RULY_CACHE_MODE=never check-cache-freshness.sh "$ISSUE_DIR" 2>&1 || true)
assert_eq "never mode with no cache returns NO_CACHE" "NO_CACHE" "$RESULT"
```

- [ ] **Step 3: Add test for `always` mode**

```bash
echo ""
echo "=== Test 11: RULY_CACHE_MODE=always forces NO_CACHE ==="
# Recreate fresh cache
write-cache-manifest.sh "$ISSUE_DIR" 2>&1
RESULT=$(RULY_CACHE_MODE=always check-cache-freshness.sh "$ISSUE_DIR" 2>&1 || true)
assert_eq "always mode returns NO_CACHE even with fresh cache" "NO_CACHE" "$RESULT"
```

- [ ] **Step 4: Add test for unknown mode (falls back to auto)**

```bash
echo ""
echo "=== Test 12: Unknown RULY_CACHE_MODE falls back to auto ==="
write-cache-manifest.sh "$ISSUE_DIR" 2>&1
RESULT=$(RULY_CACHE_MODE=bogus check-cache-freshness.sh "$ISSUE_DIR" 2>&1)
assert_eq "Unknown mode falls back to auto (FRESH)" "FRESH" "$RESULT"
```

- [ ] **Step 5: Run tests to verify all 4 new tests fail**

```bash
cd /Users/patrick/Projects/ruly && rules/comms/bin/test-cache-scripts.sh
```

Expected: Tests 1-8 pass, Tests 9-12 fail (check-cache-freshness.sh doesn't know about `RULY_CACHE_MODE` yet).

---

### Task 2: Add RULY_CACHE_MODE support to check-cache-freshness.sh

**Files:**
- Modify: `rules/comms/bin/check-cache-freshness.sh:32-35`

- [ ] **Step 1: Insert cache mode block**

Insert between line 32 (`MANIFEST="$ISSUE_DIR/.cache-manifest.toon"`) and line 34 (`# No manifest = no cache`). The new block goes after `MANIFEST=` so it can reference `$MANIFEST`:

```bash
# Cache mode override (set via RULY_CACHE_MODE env var)
CACHE_MODE="${RULY_CACHE_MODE:-auto}"

case "$CACHE_MODE" in
  never)
    # Use cache if it exists, even if stale. Allow initial fetch if missing.
    if [ -f "$MANIFEST" ]; then
      echo "FRESH"
      exit 0
    fi
    echo "NO_CACHE"
    exit 1
    ;;
  always)
    # Force re-fetch every time
    echo "NO_CACHE"
    exit 1
    ;;
  auto|"")
    # Fall through to existing staleness logic
    ;;
  *)
    echo "WARNING: Unknown RULY_CACHE_MODE '$CACHE_MODE', falling back to auto" >&2
    ;;
esac
```

- [ ] **Step 2: Run tests to verify all 12 pass**

```bash
cd /Users/patrick/Projects/ruly && rules/comms/bin/test-cache-scripts.sh
```

Expected: All 12 tests pass (8 existing + 4 new).

- [ ] **Step 3: Commit**

```bash
git add rules/comms/bin/check-cache-freshness.sh rules/comms/bin/test-cache-scripts.sh
git commit -m "feat: add RULY_CACHE_MODE support to check-cache-freshness.sh

Supports three modes via env var (default: auto):
- auto: existing staleness behavior
- never: use cache if exists, only fetch if missing
- always: force re-fetch every time

Includes tests for all modes."
```

---

### Task 3: Create /cache slash command

**Files:**
- Create: `rules/comms/commands/cache.md`

- [ ] **Step 1: Create the command file**

```markdown
---
description: Show or set cache mode for context fetching (auto, never, always)
alwaysApply: false
requires:
  - ./context-fetching.md
---

# Cache Mode

Show or set the cache mode for context fetching. Controls whether `check-cache-freshness.sh` checks staleness, skips refresh, or forces re-fetch.

## Usage

```
/cache [mode]
```

## Modes

| Mode | Behavior |
|---|---|
| `auto` | Default. Check staleness, refresh when stale. |
| `never` | Use cached data even if stale. Only fetch if no cache exists at all. |
| `always` | Ignore cache, force re-fetch every time. |

## No Args: Show Current Mode

Read `RULY_CACHE_MODE` from the environment. If unset, the mode is `auto`.

Print:

```
Cache mode: {MODE} ({description})
```

Descriptions:
- `auto`: check staleness, refresh when stale
- `never`: use existing cache, skip refresh
- `always`: ignore cache, force re-fetch

## With Arg: Set Mode

Validate the argument is one of `auto`, `never`, `always`. If not, print available modes and do not change anything.

If valid, pass `RULY_CACHE_MODE={MODE}` as an environment variable on all subsequent `check-cache-freshness.sh` invocations for the rest of this session.

Print:

```
Cache mode set to: {MODE} ({description})
```

## How It Works

This command does not write a config file or export a shell variable. It instructs the agent to prepend `RULY_CACHE_MODE={MODE}` to all future `check-cache-freshness.sh` calls in this session. The mode resets to `auto` when the session ends.
```

- [ ] **Step 2: Update README.md**

Add `/cache` to the slash commands section of README.md with a brief description.

- [ ] **Step 3: Commit**

```bash
git add rules/comms/commands/cache.md README.md
git commit -m "feat: add /cache slash command for cache mode toggle"
```
