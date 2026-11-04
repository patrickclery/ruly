# Phase 8: Project-to-recipe generator skill - Context

**Gathered:** 2026-11-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver an AI skill that takes a project folder, works out which rules, skills, commands, subagents and MCP servers that project currently uses, and drafts a Ruly recipe from them for the user to approve. No new Ruby CLI command: matching a project's setup to shared rules takes judgment, and `ruly introspect` stays as the plain markdown lister it is today.

</domain>

<decisions>
## Implementation Decisions

### Where the skill lives
- Source file is `ruly/skills/recipe-from-project.md` in the rules repo clone at `~/github.com/patrickclery/rules`. `rules/` in this checkout is empty and gitignored, and `~/.config/ruly/remotes/` is generated and must never be edited.
- It is included through a new small `ruly-tools` recipe in the rules repo's `recipes.yml`. The existing `ruly` recipe is actually a WorkAxle subagent recipe, and `core` is not touched.
- Invocation takes a project path and defaults to the current folder.

### What counts as "currently used"
- Scan `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `.cursor/rules`, `.claude/skills`, `.claude/commands`, `.claude/agents`, and `.mcp.json` (which maps to `mcp_servers:`).
- Match exact first (skill `name:` frontmatter, then content), then use AI judgment for the rest. Label every match in the draft as exact or inferred.
- Content with no shared rule is listed in a report and left out of the recipe. The skill does not create new rule files.
- Ignore `.ruly.yml`: this repo's copy dates from 2025 and does not reflect current state.

### Output and safety
- Show the draft first, and write only after the user approves it. The target is `recipes.yml` in the rules repo, using repo-relative paths.
- Recipe name defaults to the project folder's name. If that name is taken, the skill asks.
- Validate by running yalphabetize, then `ruly squash <recipe> --dry-run` from a temp directory. Report any failure.
- Leave all changes uncommitted for the user to commit.

### Claude's Discretion
- Internal structure and section wording of the skill file, following the rules repo's standard sections.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ruly squash <recipe> --dry-run` validates a recipe without writing output.
- `ruly list-recipes` shows existing recipes and their origin, which covers the name-collision check.
- `yalphabetize` enforces the sort order of `recipes.yml` (a pre-commit hook checks it).

### Established Patterns
- Skills in the rules repo are plain `.md` files with `name` and `description` frontmatter; Ruly converts them to `SKILL.md` on squash.
- Rules must use section anchors plus `requires:`, never filenames or slash command names, because those do not survive a squash.
- Recipe paths are explicit repo-relative files or directories; globs are not supported.
- Recipe keys used by a draft: `description`, `files`, `skills`, `commands`, `subagents`, `mcp_servers`.

### Integration Points
- `recipes.yml` at the root of `~/github.com/patrickclery/rules`, mirrored to other machines by `ruly squash --sync`.
- Recipe lookup order is mirrored remotes, then `./.recipes.yml`, then `~/.config/ruly/recipes.yml`.
- Squashed `.claude/skills/*/SKILL.md` files keep their `name:` frontmatter, so they can be matched exactly. Squashed `CLAUDE.local.md` loses filenames, so its content needs content or judgment matching.

</code_context>

<specifics>
## Specific Ideas

The user's example target is this ruly repo itself: "a project that I give it like this current folder here". It should work as a real test case.

</specifics>

<deferred>
## Deferred Ideas

- Creating new shared rule files from unmatched project content.
- A Ruby helper for the mechanical inventory step, only if the skill keeps repeating it.

</deferred>
