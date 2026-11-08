---
phase: 08-project-to-recipe-generator-skill
reviewed: 2026-11-08T07:30:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - skills/recipe-from-project.md
  - README.md
findings:
  critical: 0
  warning: 8
  info: 6
  total: 14
status: issues_found
---

# Phase 8: Code Review Report

**Reviewed:** 2026-11-08T07:30:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

I reviewed `skills/recipe-from-project.md` (every embedded bash, jq and ruby block) and the README lines this phase added (892-920), plus the `ruly-tools` recipe from rules commit 611a89e. I ran the snippets in zsh against scratch fixtures: a `ruly-tools` squash, a `spike` squash, a bad recipe, an offline squash under `unshare -n`, and copies of `recipes.yml`. I did not change the real clone or any config.

The core blocks work as written. These all behave as the skill says:
- exact-match, url-match and preflight
- the temp-HOME dry run, including its findings grep
- the README claims that an offline run exits 1 and still overwrites the evidence

There are no blockers. The defects are:
- **Sort step:** it rewrites lines outside the insert, which the skill says never happens.
- **Self skill:** it gets two contradictory rows.
- **Evidence check:** it rejects a valid layout, and passes silently when the path has a literal `~`.
- **Labels:** a name-only match is labelled exact.
- **Step 6:** it contradicts itself about `omit_command_prefix`.
- **README:** one setup step is silently ignored in the standard mirror-based setup.

## Warnings

### WR-01: `yalphabetize -a` rewrites unrelated lines, so the approved insert is not the only write

**File:** `skills/recipe-from-project.md:254-262, 331`
**Issue:** Step 7 inserts the recipe under `recipes:` and then runs `yalphabetize -a`. Any insert out of sorted order counts as an offence, so the whole file gets re-emitted. On a copy of the current `recipes.yml`, inserting one recipe changed 8 unrelated lines:
- comments re-indented at original lines 537, 541, 552 and 555
- a trailing space added after `mcp_servers:` at 669, 734, 765 and 788
- the final blank line removed

That breaks the line 331 promise ("Its only write is the approved insert"). It also breaks the reasoning on line 255, which forbids re-dumping through a YAML library because that rewrites comments and quoting across the file. When I inserted the same recipe at its sorted position, `yalphabetize` reported `Offences: 0` and changed nothing else.
**Fix:** Insert at the alphabetical position. Check without autocorrect, and only autocorrect if needed:
```bash
cd "${RULES}" && RUBYOPT=-Eutf-8 yalphabetize recipes.yml
# Only if it reports an offence:
cd "${RULES}" && RUBYOPT=-Eutf-8 yalphabetize -a recipes.yml && git -C "${RULES}" diff -- recipes.yml
```
Then show the full diff and point out any hunk outside the new recipe before reporting.

### WR-02: The self skill gets both a `self` row and an `exact-url` row

**File:** `skills/recipe-from-project.md:104-112, 158-165, 178, 203`
**Issue:** The `ruly-tools` URL is listed in the clone's `recipes.yml`. So when the skill runs in a project that has `.claude/skills/recipe-from-project/SKILL.md` (route 1), url-match prints:
`exact-url  .claude/skills/recipe-from-project/SKILL.md  https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md`
exact-match prints `self` for the same path. I reproduced both rows. Line 178 only says a URL row replaces a `none` row, and line 178 also says "Put matched URLs in the draft verbatim". So an agent can reasonably put the tool's own URL into the draft as exact, against Step 4 line 203.
**Fix:** Skip the self path in url-match, mirroring exact-match:
```ruby
next if derive[url] == 'recipe-from-project'
```
Or state in the prose that `self` overrides every URL row for the same path.

### WR-03: The evidence check rejects real projects whose recipe has no `files:`

**File:** `skills/recipe-from-project.md:27-39`
**Issue:** `no-evidence` fires when all three hold: the skill is installed, `CLAUDE.local.md` is empty, and `.mcp.json` has no servers. A recipe with only `skills:`, `commands:` or `subagents:` and no MCP servers produces exactly that state. My `ruly-tools` squash wrote a 0-byte `CLAUDE.local.md`. Route 1 adds this skill to such a recipe, and the skill then says the folder holds no evidence and stops, even though `.claude/skills`, `.claude/commands` and `.claude/agents` are full of matchable files.
**Fix:** Also require that nothing else is present:
```bash
others="$(find "${PROJECT}/.claude/skills" "${PROJECT}/.claude/commands" "${PROJECT}/.claude/agents" \
  -name '*.md' ! -path '*/recipe-from-project/*' 2>/dev/null | head -1)"
# ...and add `[ -z "${others}" ] && [ ! -e "${PROJECT}/AGENTS.md" ] &&` to the condition.
```

### WR-04: The blocks handle a literal `~` inconsistently, and the evidence check passes it silently

**File:** `skills/recipe-from-project.md:14, 21, 29-32, 250, 259, 313`
**Issue:** Line 14 tells the agent to `export PROJECT="..." RULES="..."` with double quotes, and the default `RULES` is written `~/github.com/patrickclery/rules`, so a literal `~` is likely. The blocks handle it differently:

| Blocks | Literal `~` |
| --- | --- |
| Ruby blocks (`File.expand_path`) and validate-recipe (`${RULES/#\~/${HOME}}`) | handled |
| evidence check (`[ -f "${PROJECT}/..." ]`) | silently prints `evidence-ok` |
| `git -C "${RULES}"` (line 250) | fails: `fatal: cannot change to '~/github.com/...'` (verified) |
| `cd "${RULES}"` (line 259) | fails |
| `jq ... "${PROJECT}/.mcp.json"` (line 58) | fails |

**Fix:** Normalize once, at the top of every block that uses the variables:
```bash
PROJECT="${PROJECT/#\~/${HOME}}" RULES="${RULES/#\~/${HOME}}"
```
Or change line 14 to say the paths must be absolute, and fix the example to `export PROJECT="$PWD" RULES="${HOME}/github.com/patrickclery/rules"`.

### WR-05: A name-only match with a different body is labelled exact

**File:** `skills/recipe-from-project.md:95-96, 128`
**Issue:** If exactly one clone file shares the project skill's `name:`, the row is `exact-name` even when the bodies differ. Line 128 makes that exact and explains `body-differs` as "edited after it was generated". A hand-written skill that only happens to share a common name (for example `debugging`) is then labelled exact and goes into the recipe. Squashing that recipe replaces the user's skill with the shared one. That weakens the CONTEXT.md decision that every label is honest ("Label every match ... as exact or inferred").
**Fix:** Label `exact-name` + `body-differs` as inferred, and have the agent compare the content before keeping it:
```ruby
row[bodies[named.first] == body[text] ? 'exact-name' : 'inferred-name', rel, named.first, '']
```

### WR-06: Step 6 says to use only six keys, then says to add `omit_command_prefix`

**File:** `skills/recipe-from-project.md:213, 236`
**Issue:** Line 213 says to show the recipe "using only the keys `description`, `files`, `skills`, `commands`, `subagents` and `mcp_servers`". Line 236, in the same step, says to add `omit_command_prefix`, and CONTEXT.md allows that key. An agent that follows line 213 drops the key, and the drafted recipe then renames the project's commands. The YAML template on lines 215-229 also leaves it out.
**Fix:** Add `omit_command_prefix` to the line 213 key list ("...and `omit_command_prefix` when Step 6 requires it"), and add it to the template as an optional key.

### WR-07: The README says to define `ruly-tools` in your own recipes file, which ruly ignores once a mirror exists

**File:** `README.md:912-918`
**Issue:** `RecipeLoader#select_recipe_source` uses mirrored remotes whenever any exist. It reads `recipes:` from `./.recipes.yml` or `~/.config/ruly/recipes.yml` only when there are no mirrors. Overrides cannot add a recipe either: `apply_overrides!` raises "does not match a loaded recipe". I tested a temp HOME with one mirror and `ruly-tools2` defined in the user file, and `ruly squash ruly-tools2 --dry-run` printed `Recipe 'ruly-tools2' not found`. The mirror-based setup is the documented standard, so this README advice fails for most users.
**Fix:** Say the snippet works only without `remotes:`, or that it belongs in the rules repo's `recipes.yml`. Mirror users already get `ruly-tools` from the rules repo after `ruly squash --sync`.

### WR-08: Recipe directory entries come back as long lists of single files

**File:** `skills/recipe-from-project.md:118-124, 199, 213`
**Issue:** `exact-rule` reports one row per clone file found in `CLAUDE.local.md`. In a project squashed from `spike` (whose `files:` includes `comms/` and `workaxle/orchestrator/`), it printed about 50 single-file rows. Nothing in Steps 4 or 6 says to fold these back into a directory entry. Line 213 ("List every entry in full, with no shorthand") pushes toward listing each file. The resulting recipe freezes today's file set: files added to `comms/` later are silently not picked up, which differs from the recipe the project came from.
**Fix:** Add a pruning rule: if every `.md` file under a clone directory matched (or was reached through `requires:`), replace them with the directory entry and label it exact with that reason.

## Info

### IN-01: The name-check one-liner crashes if `recipes.yml` has no `recipes:` key

**File:** `skills/recipe-from-project.md:243`
**Issue:** `YAML.safe_load_file(...)["recipes"].keys` raises `NoMethodError` on nil (verified). The other blocks guard with `|| {}`.
**Fix:** `puts((YAML.safe_load_file(ARGV[0], aliases: true) || {}).fetch("recipes", {}).keys)`

### IN-02: The name check allows names that YAML reads as numbers or booleans

**File:** `skills/recipe-from-project.md:246`
**Issue:** `[A-Za-z0-9._-]` accepts `2024`, `on`, `yes`, `null` and `1.0`. Unquoted, Psych loads these keys as Integer, Boolean, nil or Float. Preflight then aborts with "not in recipes.yml", and `ruly squash` cannot find the recipe. A leading `-` also gets parsed as a CLI option.
**Fix:** Also require `\A[A-Za-z][A-Za-z0-9._-]*\z`, and reject YAML 1.1 boolean/null words.

### IN-03: url-match drops failed `files:` fetches silently and handles only some URL forms

**File:** `skills/recipe-from-project.md:142-145, 149, 171`
**Issue:**
- `fetched = fetch[url] or next` leaves no row and no warning when a `files:` URL fails to fetch, so its content looks unmatched.
- The regex handles only `github.com/.../blob/<ref>/...` with no `/` in the ref.
- `commands:` URLs are never collected, although preflight checks them.

**Fix:** Print an `unfetched-url` row on failure, and add `commands` to `urls`.

### IN-04: Errors that stop the squash do not show up in the findings section

**File:** `skills/recipe-from-project.md:318, 325`
**Issue:** The grep does not match `Recipe 'x' not found`, `No recipes found` or a Ruby exception. Those runs show `exit=1` with an empty findings section. Line 325 calls only preflight rows and findings lines failures.
**Fix:** Add "A nonzero `exit=` is always a failure" to line 325, and add `not found|No recipes found|Error` to the grep.

### IN-05: Rule files under 200 characters can never be an exact match

**File:** `skills/recipe-from-project.md:122, 172`
**Issue:** The `>= 200` size cutoff is not mentioned anywhere in the prose. Short rule files silently fall through to judgment.
**Fix:** Document the cutoff next to line 128.

### IN-06: The README lists the skill under "Available Ruly Commands" although nothing installs it

**File:** `README.md:894`
**Issue:** The other entries in that list are available in this repo. This one exists only after a recipe that lists the URL has been squashed, which line 902 explains only afterwards.
**Fix:** Add "(add to a recipe first, see [Drafting a Recipe From a Project](#drafting-a-recipe-from-a-project))" to the bullet.

---

_Reviewed: 2026-11-08T07:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
