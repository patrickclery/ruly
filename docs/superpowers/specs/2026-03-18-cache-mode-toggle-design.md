# Cache Mode Toggle

## Problem

The context-fetching cache system (Jira, PR, Teams) has no way to override its staleness behavior. Sometimes you want to force fresh data; other times you want to skip fetching entirely and use whatever is cached.

## Design

### Cache Modes

Three modes, controlled by `RULY_CACHE_MODE` environment variable (default: `auto`):

| Mode | Behavior | `check-cache-freshness.sh` returns |
|---|---|---|
| `auto` | Check manifest staleness (current behavior) | `FRESH`, `STALE: <types>`, or `NO_CACHE` |
| `never` | Never refresh — use cached data even if stale. Allow initial fetch if no cache exists. | `FRESH` if manifest exists; `NO_CACHE` if no manifest |
| `always` | Always refresh — ignore cache, force re-fetch every time | `NO_CACHE` (always) |

### Slash Command: `/cache`

New file: `rules/comms/commands/cache.md`

**No args** — show current mode:
```
/cache
→ Cache mode: auto (check staleness, refresh when stale)
```

**With arg** — set mode:
```
/cache never
→ Cache mode set to: never (use existing cache, skip refresh)
```

The command instructs the agent to pass `RULY_CACHE_MODE=<mode>` on all subsequent `check-cache-freshness.sh` invocations for the session. This is agent memory, not a shell export (child processes cannot set parent env vars).

### Changes to `check-cache-freshness.sh`

Insert the `case` block **after** `MANIFEST=` is defined (line 32) and **before** the existing `if [ ! -f "$MANIFEST" ]` check (line 35):

```bash
CACHE_MODE="${RULY_CACHE_MODE:-auto}"

case "$CACHE_MODE" in
  never)
    # Use cache if it exists, even if stale. Allow initial fetch if missing.
    if [ -f "$MANIFEST" ]; then
      echo "FRESH"
      exit 0
    fi
    # Fall through to NO_CACHE if no manifest
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

### Behavioral Notes

- **`--type` flag is ignored in `never` and `always` modes.** These modes are blunt overrides — `never` returns FRESH for ALL types if the manifest exists, `always` forces re-fetch of ALL types. Selective per-type refresh only applies in `auto` mode.
- **`/refresh-context` still works in `never` mode.** It deletes the manifest, so `never` mode sees no manifest and returns `NO_CACHE`, allowing the fetch to proceed.

### No Other Changes

All callers already branch on `check-cache-freshness.sh` exit codes. No caller changes needed.

## Files to Create/Modify

1. **Create** `rules/comms/commands/cache.md` — slash command
2. **Modify** `rules/comms/bin/check-cache-freshness.sh` — add `RULY_CACHE_MODE` handling
