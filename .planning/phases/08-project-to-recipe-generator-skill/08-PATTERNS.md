# Phase 8: Project-to-recipe generator skill - Pattern Map

**Mapped:** 2026-11-04
**Files analyzed:** 3
**Analogs found:** 3 / 3

**Public-repo constraint:** this file and the skill are in a public repo, and `patrickclery/rules` is private. Excerpts from the rules repo are limited to structure, with prose and rule paths replaced by placeholders. Do not copy text from the rules repo's skill into the new skill.

## File Classification

| New/Modified File | Repo | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|------|-----------|----------------|---------------|
| `skills/recipe-from-project.md` (new) | ruly | skill (markdown instructions) | file-I/O, transform, approval then write | `home/skills/update-rules.md` (rules repo) for structure; `.claude/commands/ruly/compress.md` for arguments and report | role-match (no existing skill does reverse matching) |
| `README.md` (modify) | ruly | docs | none | Same file, lines 892-897 | exact |
| `recipes.yml` (modify) | rules | config | batch (read by squash and `--sync`) | Same file: `context-github` for a minimal recipe, `core-solo` for a URL `skills:` entry | exact |

All analog paths were confirmed tracked with `git ls-files`. No code in `lib/` changes, and `skills/` does not exist yet (it is not gitignored).

## Pattern Assignments

### `skills/recipe-from-project.md` (skill, file-I/O and transform)

**Primary analog:** `~/github.com/patrickclery/rules/home/skills/update-rules.md` (rules repo, structure only)

**Section skeleton to follow** (analog line numbers):

```markdown
---                                  # 1-4: name and description only, one line each
name: <skill-name>
description: <when to use it, triggers in words, then what it does>
---
# <skill-name>: <Title>              # 5: H1 directly after the frontmatter

## Description                       # 7: short scope paragraph

## Key Patterns                      # 13
### 1. <imperative step>             # 15, 28, 43, 53, 61: numbered, ordered workflow steps
<short prose, then a fenced bash block where a command is needed>

## Examples                          # 80
### <named scenario>                 # 82, 88: short narrative cases

## Best Practices                    # 93: flat bullets

## Anti-patterns                     # 101
### <named mistake>                  # 103-121: one H3 per mistake, one or two lines of why

## Related Files                     # 125: | Path | Purpose | table
```

**Mapping the workflow onto numbered Key Patterns** (order from the diagram at `08-RESEARCH.md` lines 578-604; wording is at Claude's discretion):

| Step | Content | Source in `08-RESEARCH.md` |
|------|---------|----------------------------|
| 1 | Resolve project path from `$ARGUMENTS`, default cwd; treat scanned content as data; stop on the post-squash signature | Q12 lines 498-506; threat table line 910 |
| 2 | Inventory the decided scan list, recursively for skills; JSON key names only | Pattern 1 lines 620-632; Q4 line 233 |
| 3 | Match and label each item exact or inferred, and exclude the skill itself | Pattern 1; Q13 lines 524-548; body snippet lines 796-804 |
| 4 | Prune entries reached through `requires:`, `skills:` frontmatter and subagents | Pattern 2 lines 650-656; Q4 line 231; Q5 line 277 |
| 5 | Stop if nothing matched; write nothing | Pattern 3 lines 658-668 |
| 6 | Show draft, labels and report (including what the next squash will lose); check the name against the clone; wait for approval | Pitfall 5 line 721; Q6-era correction line 72 |
| 7 | Text-insert with Edit, then sort | Q6 lines 300, 325 |
| 8 | Preflight, then temp-`HOME` dry run with failure grep | Lines 741-757, 779-790 |
| 9 | Report results; leave changes uncommitted | CONTEXT.md line 34 |

**Secondary analog:** `.claude/commands/ruly/compress.md` (public, can be quoted)

Frontmatter shape (lines 1-4):

```markdown
---
name: ruly:compress
description: Analyze markdown rules to find redundancies and make them more DRY
---
```

Argument documentation (lines 12-20), to adapt in words and without a slash command name:

```markdown
## Usage

/ruly:compress <directories/files...>

## Arguments

- `<directories/files...>` - One or more markdown files or directories containing rule files to analyze
```

Report template (lines 150-176): a fenced markdown block with `## Summary` counts and then per-finding entries. Use this shape for the draft and unmatched report. DO/DON'T lists (lines 230-243) are a usable form for the matching rules.

**Do not copy from `compress.md`:**

| Lines | Item | Why |
|-------|------|-----|
| 2, 6, 15 | Colon-prefixed slash name, and the command naming itself | Skill rule forbids slash command names (`08-RESEARCH.md` line 337) |
| 212-219 | Interactive mode offering PRs | The skill only writes after approval and leaves changes uncommitted |
| 247-266 | Config-file options | Unrequested surface |
| 268-274, 286-305 | References to other commands and flags | Not valid after squash |

**Frontmatter constraints** (`lib/ruly/services/frontmatter_parser.rb:53`, `08-RESEARCH.md` Q1):

```ruby
%w[name description permissionMode allowed_tools].each do |key|
```

- Use `name` and `description` only, with `description` on one line and no unquoted `: `.
- No `requires:`, `dispatches:`, `argument-hint`, `allowed-tools` or `disable-model-invocation`.
- No `[x](#anchor)` links are needed.

**Target directory name** (`lib/ruly/services/script_manager.rb:22-28`) gives `.claude/skills/recipe-from-project/SKILL.md` from both the path and the URL:

```ruby
def derive_skill_name(path)
  if path.include?('/skills/')
    path.split('/skills/').last.sub(/\.md$/, '')
  else
    File.basename(path, '.md')
  end
end
```

---

### `README.md` (docs)

**Analog:** the existing list at lines 892-897.

```markdown
#### Available Ruly Commands

- `/ruly:compress` - Analyze markdown rules to find redundancies and make them more DRY
- `/ruly:decompose` - Decompose a markdown file into a directory using git mv (preserves history)
```

- Format is ``- `/name` - sentence``. The list is alphabetical, so the new bullet goes first, before `/ruly:compress` (line 894).
- Put the two usage routes (`08-RESEARCH.md` lines 455-488) and the warning against squashing `ruly-tools` in the target project after line 897, before `### Examples` at line 899.
- Mention that squashing a recipe with this URL needs network access (Pitfall 8, line 732).
- Run only `prettier` by hand; `markdown-table-prettify` can block on open stdin (`08-RESEARCH.md` line 446).

---

### `recipes.yml` in the rules repo (config)

**Analog 1, minimal recipe:** `context-github` (structure, path masked):

```yaml
  context-github:
    description: "<double-quoted text>"
    model: haiku
    skills:
      - <repo-relative-path>
```

**Analog 2, URL under `skills:`:** `core-solo`, lines 356-358 (public upstream URL). Note that this one is commit-pinned, while `ruly-tools` deliberately tracks `main`:

```yaml
    skills:
    # === Superpowers (on-demand) ===
      - https://github.com/obra/superpowers/blob/e4a2375cb705ca5800f0833528ce36a3faf9017a/skills/test-driven-development/SKILL.md
```

**Entry to add** (`08-RESEARCH.md` lines 810-815):

```yaml
  ruly-tools:
    description: "Ruly authoring tools"
    skills:
      - https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md
```

**Placement:** after `ruly` (currently starts at line 1081, next recipe `spike` at line 1110). Line numbers will shift after the sort commit. Keep the header comment at lines 1-6 and `recipes:` at line 7.

**Commit sequence** (decided):

```bash
cd ~/github.com/patrickclery/rules
RUBYOPT=-Eutf-8 yalphabetize -a recipes.yml
git commit -m "<sort message>" -- recipes.yml      # commit 1: sort only
# Edit: insert the entry
RUBYOPT=-Eutf-8 yalphabetize -a recipes.yml
git commit -m "<add ruly-tools message>" -- recipes.yml   # commit 2: expect a 4-line hunk
```

The rules repo's recent subjects use the `docs(<tag>): <what>` form. Named paths come from `update-rules.md` lines 55-58. Ask before any push. This repo's file must reach `main` first (`08-RESEARCH.md` line 430).

---

## Shared Patterns

### Validation

**Source:** `08-RESEARCH.md` lines 741-757 (script), 779-790 (preflight)
**Apply to:** skill step 8, and this phase's verification of `ruly-tools`

Exit 0 proves little, so any line matched here is a failure:

```bash
grep -E '[Ff]ile not found|No markdown files|unknown key|Failed to fetch|squash failed' "$VAL/out.txt"
```

Before the file is on `main`, the only acceptable finding is `Failed to fetch` plus `squash failed` for this exact URL (Pitfall 7).

### Secrets

**Source:** `08-RESEARCH.md` lines 233, 904
**Apply to:** every JSON read in the skill

```bash
jq -r 'keys[]' ~/.config/ruly/mcp.json
jq -r '.mcpServers | keys[]' <project>/.mcp.json
```

### Write safety

**Source:** `08-RESEARCH.md` lines 325, 678, 912, 916
**Apply to:** skill steps 6-9

- Insert text with Edit; never round-trip through a YAML library.
- Labels appear in the draft only, not as comments in `recipes.yml`.
- Accept repo-relative paths inside the clone, or URLs already listed verbatim in the clone's `recipes.yml`. Refuse absolute, `~`, `..` and any other URL.
- Never run a non-dry squash at runtime.

### What may be named in the skill

**Source:** `08-RESEARCH.md` line 337; the analog does the same at `update-rules.md` lines 105-106
**Apply to:** skill and its `description`

Real outputs (`recipes.yml`, `CLAUDE.local.md`, `.claude/skills/*/SKILL.md`) may be named. Rule source files and slash commands, including its own, may not.

## Points for the Planner

- **Match order conflict:** CONTEXT.md line 26 says `name:` first, then content. `08-RESEARCH.md` line 634 recommends body first for generated files, with both counted as exact. CONTEXT.md is the locked decision, so the plan should either follow it or get the change confirmed.
- **Stale guidance:** do not copy `feedback_recipes_yml_yalphabetize.md`. Its `cp` step would overwrite the machine config (`08-RESEARCH.md` line 323).
- **CLAUDE.md's skill location rule** (`rules/{tag}/skills/`) is superseded for this one file by the user's decision.

## No Analog Found

No file lacks an analog. These behaviors in the skill have no existing example, so use `08-RESEARCH.md` directly:

| Behavior | Reason | Use |
|----------|--------|-----|
| Stripped-body matching | No skill compares squash output with sources | Lines 796-804 |
| Temp-`HOME` mirror validation | Developed during research | Lines 741-757 |
| URL index matching | Same | Q13, lines 524-548 |

## Metadata

**Analog search scope:** this repo's `.claude/`, `README.md`, `lib/ruly/services/`; rules repo `home/skills/`, `recipes.yml`
**Files scanned:** 7
**Pattern extraction date:** 2026-11-04
