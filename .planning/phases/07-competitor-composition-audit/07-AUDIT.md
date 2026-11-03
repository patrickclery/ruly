# Phase 7: Competitor Composition Audit

**Audited:** 2026-11-02

**Question:** Can Ruler or rulesync select rules per task the way ruly recipes plus `requires:` do?

## Answer

Neither Ruler nor rulesync has named rule sets or profiles, includes between rule files with transitive resolution, or include-cycle detection, so recipes plus `requires:` remain ruly's main difference. Two earlier claims do not hold: both rivals set a model per subagent, and rulesync has shared sources with a SHA lockfile and overlays. Ruly is far behind on agent coverage (3 targets against 32 for Ruler and 69 for rulesync).

## Pinned evidence baseline

| Project  | Repo                    | Commit inspected                           | Commit date | Latest release       |
| -------- | ----------------------- | ------------------------------------------ | ----------- | -------------------- |
| Ruler    | `intellectronica/ruler` | `5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87` | 2026-10-27  | v0.3.46 (2026-10-22) |
| rulesync | `dyoshikawa/rulesync`   | `6e3869d378066dc2f0b4cda3896e444ae7f200a7` | 2026-11-02  | v43.4.2 (2026-11-01) |
| ruly     | this repo               | `4e859914ea87025b8d4d378f8752da7cf42c084b` | 2026-11-02  | 0.3.0                |

Ruly citations are repo-relative `path:line`, reproducible with `git show 4e85991:<path>`.

## Method

- **Evidence (D-01):** docs AND source of each rival, read at the pinned SHAs with read-only `gh api -H 'Accept: application/vnd.github.raw' "repos/<owner>/<repo>/contents/<path>?ref=<SHA>"` and raw reads. Every rival link below is pinned to `/blob/<SHA>/` or `/tree/<SHA>`.
- **Method limitation (D-02):** the planned `npx` run of each tool against a fixture was dropped by orchestrator override, because executing third-party code is not permitted in this run. No third-party code was executed. Runtime behavior that could only be inferred from code and docs is marked "inferred".
- **Verdict legend:** **yes** (feature present, read in source or docs), **partial** (covers part of the capability), **no** (absent), **unverified** (not established either way). "Inferred" means the conclusion follows from the code and docs read, but the behavior was not executed. Evidence tags: [VERIFIED] read in source or counted, [CITED] read in docs only, [ASSUMED] inferred.
- **Absence verdicts:** Ruler's config schema is `.strict()`, so an unknown key such as `profiles` is rejected. rulesync's schemas are non-strict, so a rulesync "no" means "no such field exists in the schema or processor", not "rejected".
- **Scope:** vibe-rules is out of scope (D-07, discretion item not covered). Interop (handing AGENTS.md to Ruler or rulesync for fan-out) is deferred to a future milestone.

## Capability matrix

| #   | Capability                                           | Ruler @5e551e6                          | rulesync @6e3869d                                                                                | ruly 0.3.0 @4e85991                                             |
| --- | ---------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| 1   | Named rule sets / profiles selectable per invocation | **no**                                  | **no** (partial workaround via `generate -c` with per-file `inputRoots`, inferred, not executed) | **yes**                                                         |
| 2   | Per-task selection (subset of rules for one run)     | **no**                                  | **partial**                                                                                      | **yes**                                                         |
| 3   | Include/require between rule files, transitive       | **no**                                  | **no**                                                                                           | **yes**                                                         |
| 4   | Cycle detection in includes                          | **no** (n/a: no includes)               | **no** (n/a: no includes)                                                                        | **yes** (listed by `ruly stats`; squash dedups)                 |
| 5   | Per-subagent model selection                         | **yes**                                 | **yes**                                                                                          | **yes** (plus a separately compiled recipe per subagent)        |
| 6   | Cross-machine shared source + per-machine overrides  | **no** (machine-wide fallback dir only) | **yes**                                                                                          | **yes**                                                         |
| 7   | Post-compile checks                                  | **partial**                             | **partial**                                                                                      | **yes** (ambiguous anchor links, duplicate skill requires)      |
| 8   | Agent coverage / AGENTS.md                           | **32 agents**; AGENTS.md yes            | **69 targets** (61 with project rules); AGENTS.md yes                                            | **3 targets** (claude full; agents = AGENTS.md; cursor partial) |

## Evidence

### 1. Named rule sets / profiles

- **Ruler: no.** `ruler.toml` is validated by a `.strict()` zod schema whose top-level keys are `default_agents`, `agents`, `mcp`, `mcp_servers`, `gitignore`, `backup`, `skills`, `subagents` (deprecated) and `nested`; none selects rule files or names a profile ([`src/core/ConfigLoader.ts#L75-L129`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/ConfigLoader.ts#L75-L129)). `--config <path>` only swaps which `ruler.toml` is read; the rules directory is found separately and all of its markdown is read regardless of the config ([`src/core/apply-engine.ts#L319-L351`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/apply-engine.ts#L319-L351)). So the README example `ruler apply --config ./team-configs/ruler.frontend.toml` changes agent and MCP settings, not the rule set; it is not a rule profile. [VERIFIED]
- **rulesync: no.** `ConfigParamsSchema` keys are `outputRoots`, `targets`, `features`, `verbose`, `delete`, `global`, `silent`, `simulateCommands`, `simulateSubagents`, `simulateSkills`, `preserveUnownedHooks`, `deriveSubprojectPathFromGlobs`, `flattenedCommandNaming`, `language`, `gitignoreTargetsOnly`, `gitignoreDestination`, `dryRun`, `check`, `inputRoot`, `inputRoots`, `sources`; there is no profile or preset key ([`src/config/config.ts#L118-L180`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/config/config.ts#L118-L180)). [VERIFIED]
  - Workaround (inferred, not executed): keep several config files, each with its own `inputRoots`, and pick one per run with `generate -c <path>` ([`src/cli/program.ts#L342`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/cli/program.ts#L342)). That gives a directory-granular "profile" with no name registry and no dependency resolution. [ASSUMED]
- **ruly: yes.** `ruly squash [RECIPE]` (`lib/ruly/cli.rb:54`); recipes are loaded from mirrored remotes, project and user files (`lib/ruly/services/recipe_loader.rb:100-116`). [VERIFIED]

### 2. Per-task selection

- **Ruler: no.** `readMarkdownFiles` collects every `.md` under `.ruler/`, skipping only `skills/` and `agents/` (unless `include_in_rules`) ([`src/core/FileSystemUtils.ts#L319-L436`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/FileSystemUtils.ts#L319-L436)). `--agents` selects target agents, not rules. Nested mode loads per-directory `.ruler/` trees, which is path scoping, not per-task sets ([`src/core/FileSystemUtils.ts#L611-L656`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/FileSystemUtils.ts#L611-L656)). [VERIFIED]
- **rulesync: partial.** A rule's `targets` picks tools and `globs` scopes paths ([`src/features/rules/rulesync-rule.ts#L34-L257`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/rules/rulesync-rule.ts#L34-L257)). `--input-roots <paths...>` composes source trees per invocation, later trees replacing same-path files ([`src/cli/program.ts#L356-L359`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/cli/program.ts#L356-L359); [`docs/guide/separate-input-root.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/separate-input-root.md)), so a base tree plus a task tree is possible, selected by directory, with no per-file list and no dependencies. `sources[].rules` selects named remote rules at install time, not per run ([`docs/guide/declarative-sources.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/declarative-sources.md)). [VERIFIED]
- **ruly: yes.** A recipe lists files, directories, skills, commands and MCP servers; only those plus their `requires:` closure are written (`lib/ruly/services/recipe_loader.rb:260`, `process_recipe_files`). [VERIFIED]

### 3. Include/require with transitive resolution

- **Ruler: no.** `concatenateRules` joins rule files with `<!-- Source: … -->` markers; there is no include or import parsing ([`src/core/RuleProcessor.ts#L7-L28`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/RuleProcessor.ts#L7-L28)). A code search of the repo for `@import` returns 0 hits. [VERIFIED]
- **rulesync: no.** The rule frontmatter schema has no `requires`, include or imports key ([`src/features/rules/rulesync-rule.ts#L34-L257`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/rules/rulesync-rule.ts#L34-L257)); code search for `@import` returns 0 hits. `takt.extends` is only emitted into Takt output for Takt to interpret; rulesync does not resolve it. [VERIFIED]
- **ruly: yes.** `DependencyResolver.resolve_requires_for_source` reads `frontmatter['requires']` and skips keys already processed (`lib/ruly/services/dependency_resolver.rb:10-25`); `SourceProcessor` pushes requires to the front of the queue for depth-first transitive processing (`lib/ruly/services/source_processor.rb:173-182`); `--strict` also fails on a missing transitive source (`lib/ruly/cli.rb:50-51`). [VERIFIED]

### 4. Cycle detection

- **Ruler: no (n/a).** Without includes there is no include graph. `visitedDirectories` is a symlinked-directory loop guard in the directory walk, not include-cycle detection ([`src/core/FileSystemUtils.ts#L329-L348`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/FileSystemUtils.ts#L329-L348)). [VERIFIED]
- **rulesync: no (n/a).** Its "circular" hits are YAML-alias cycles ([`src/features/shared/shared-config-gateway.ts#L169`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/shared/shared-config-gateway.ts#L169)) and symlink cycles in glob walks ([`docs/guide/separate-input-root.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/separate-input-root.md), "Symlinks and trust"). [VERIFIED]
- **ruly: yes (reporting).** `Operations::Stats#find_circular_dependencies` runs a DFS over the `requires` graph (`lib/ruly/operations/stats.rb:12-13, 122-140`) and writes `circular_dependencies` to `stats.md`. During squash a cycle cannot loop because of the `processed_files` set (`lib/ruly/services/source_processor.rb:68, 84, 100`); squash itself does not warn on cycles. [VERIFIED]

### 5. Per-subagent model selection

- **Ruler: yes.** A `.ruler/agents/*.md` subagent takes an optional string `model` field ([`src/core/SubagentsUtils.ts#L81-L86`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/SubagentsUtils.ts#L81-L86)), and `buildClaudeFile` writes it to the output as `meta.model` ([`src/core/SubagentsProcessor.ts#L403-L416`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/SubagentsProcessor.ts#L403-L416)). The feature is experimental ([`warnOnceExperimental`, `src/core/SubagentsProcessor.ts#L176`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/SubagentsProcessor.ts#L176)). Ruler's README calls it disabled by default; that was not confirmed in source. Upgraded from CITED to [VERIFIED].
- **rulesync: yes.** Subagent frontmatter has per-tool blocks such as `claudecode.model: inherit # opus, sonnet, haiku, fable, a full model id, or inherit` ([`docs/reference/file-formats.md?plain=1#L704-L760`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/reference/file-formats.md?plain=1#L704-L760)); the schema is a `looseObject`, so per-tool keys pass through ([`src/features/subagents/rulesync-subagent.ts#L23-L101`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/subagents/rulesync-subagent.ts#L23-L101)). [VERIFIED]
- **ruly: yes, plus a recipe per subagent.** `resolve_agent_model`: subagent model, then parent recipe model, then `inherit` (`lib/ruly/services/subagent_processor.rb:262-271`). Each `subagents:` entry names a recipe that is squashed into the agent's body. Neither rival compiles a separate rule set per subagent; each of their subagents is one hand-written file. [VERIFIED]

### 6. Cross-machine shared source + per-machine overrides

- **Ruler: no.** Without a local `.ruler/`, `findRulerDir` falls back to `$XDG_CONFIG_HOME/ruler` as a whole ([`src/core/FileSystemUtils.ts#L199-L237`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/FileSystemUtils.ts#L199-L237)); config resolution works the same way, local `ruler.toml` wins outright ([`src/core/ConfigLoader.ts#L653-L683`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/ConfigLoader.ts#L653-L683)). The fallback replaces, never merges, and there is no remote fetch. [VERIFIED]
- **rulesync: yes.** `sources` installs rules from GitHub, git or npm, with refs pinned to commit SHAs in `rulesync.lock`; only direct `.md` children of `rulesPath` are installed ([`docs/guide/declarative-sources.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/declarative-sources.md)). `inputRoots` overlays let a later tree replace same-path files ([`docs/guide/separate-input-root.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/separate-input-root.md)), and `rulesync.local.jsonc` overrides config per machine ([`docs/guide/configuration.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/guide/configuration.md)). [VERIFIED]
- **ruly: yes.** `remotes:` plus `ruly squash --sync` mirror into `~/.config/ruly/remotes/<owner>/<repo>/` (`lib/ruly/cli.rb:52-53`, `lib/ruly/services/remote_sync.rb:10`); `apply_overrides!` merges `overrides:` additively (`lib/ruly/services/recipe_loader.rb:109-116, 214-236`). [VERIFIED]
- **Difference:** ruly `overrides:` add to a named recipe; rulesync overlays replace whole files. rulesync's lockfile is reproducibility ruly lacks (`--sync` mirrors the current remote).

### 7. Post-compile checks

- **Ruler: partial.** Warns on a skill directory without `SKILL.md` ([`src/core/SkillsUtils.ts#L82-L85`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/SkillsUtils.ts#L82-L85)) and validates subagent frontmatter (`name` and `description` required, name must match the file stem) ([`src/core/SubagentsUtils.ts#L42-L62`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/SubagentsUtils.ts#L42-L62)). No link or anchor checks. Upgraded from CITED to [VERIFIED].
- **rulesync: partial.** `generate --check` exits 1 when output is stale ([`src/cli/program.ts#L365`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/cli/program.ts#L365)); `doctor` lints config and checks Codex `AGENTS.md` size ([`docs/reference/cli-commands.md?plain=1#L765-L785`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/reference/cli-commands.md?plain=1#L765-L785); [`src/features/rules/instruction-budget.ts`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/rules/instruction-budget.ts)). No link or anchor checks. Its `checks` feature distributes code-review instructions to tools and is not output validation ([`docs/reference/file-formats.md?plain=1#L922-L950`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/reference/file-formats.md?plain=1#L922-L950)). [VERIFIED]
- **ruly: yes.** `Checks::AmbiguousLinks` reports ambiguous anchors, a heading defined more than once, not broken ones (`lib/ruly/checks/ambiguous_links.rb:5-7`); `Checks::DuplicateSkillRequires` (`lib/ruly/checks/duplicate_skill_requires.rb:7`); both run after every squash that writes output (`lib/ruly/checks.rb:11-24`). [VERIFIED]

### 8. Agent coverage and AGENTS.md

- **Ruler: 32 agents, AGENTS.md yes.** 32 agent classes are instantiated, including `AgentsMdAgent` ([`src/agents/index.ts#L39-L70`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/agents/index.ts#L39-L70)). [VERIFIED, counted]
- **rulesync: 69 targets, AGENTS.md yes.** 69 `--targets` values in the generated table, 61 with project rules, including `agentsmd` ([`docs/reference/supported-tools.md`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/docs/reference/supported-tools.md)); 7 of them are packaging targets ([`src/types/tool-targets.ts#L23-L31`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/types/tool-targets.ts#L23-L31)). [VERIFIED, counted]
- **ruly: 3 targets.** `-a` accepts `claude`, `cursor`, `agents` (`lib/ruly/cli.rb:39`; `lib/ruly/services/agents_md.rb:12`); skills and commands are written only for `claude` (`lib/ruly/cli.rb:391, 395`); `sgpt`/`shell_gpt` were removed (`lib/ruly/cli.rb:17`). [VERIFIED]
- **Interop note:** rulesync `import` reads AGENTS.md (supported-tools.md above), so handing ruly's AGENTS.md to rulesync for fan-out is plausible. Interop is deferred to a future milestone.

## Corrections to the 2026-11-01 research

| Old claim                                  | Audited fact                                                 | Impact                                            |
| ------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------- |
| Per-task composition unverified for rivals | Neither has profiles or includes                             | Main advantage confirmed                          |
| Per-subagent model is a ruly advantage     | Both rivals set a model per subagent                         | Reword to "recipe + model per subagent"           |
| Cross-machine sharing is a ruly advantage  | rulesync has `sources` + lockfile + `inputRoots` overlays    | Advantage narrowed to "additive recipe overrides" |
| No rivals advertise post-compile checks    | rulesync has `--check` and `doctor`; Ruler validates sources | Narrow to "anchor-link checks"                    |
| rulesync ~67 agents + AGENTS.md            | 69 targets (61 with rules)                                   | Update number                                     |
| ruly has no AGENTS.md                      | ruly 0.3.0 `-a agents`                                       | Already fixed in Phase 4                          |

## README rows

| README row                  | Matrix row       | Note                                                                                 |
| --------------------------- | ---------------- | ------------------------------------------------------------------------------------ |
| Named rule sets             | 1 and 2 (folded) | rulesync cell states its verified `--input-roots` per-run layering                   |
| Includes between rule files | 3                |                                                                                      |
| Cycle reporting             | 4                | ruly wording: `ruly stats` lists chains; squash dedups                               |
| Per-subagent model          | 5                | Yes / Yes conceded                                                                   |
| Shared source + overrides   | 6                | Published with a rulesync "Yes", not framed as a ruly win (research Open Question 1) |
| Post-compile checks         | 7                | Partial / Partial; ruly wording says "ambiguous" anchors                             |
| Agents                      | 8                | 32 / 69 / 3                                                                          |

Kept out of the README: the inferred `generate -c` workaround (unverified behavior), star counts (stale quickly) and any link to `.planning/`. site/ has no competitor copy at BASE, so no site change.

## Assumptions and limits

- A1: rulesync `generate -c <file>` with a per-file `inputRoots` works as a manual profile. Inferred, only used in this file.
- A2: Ruler passes subagent `model` through. Resolved: VERIFIED in source (Evidence row 5).
- A3: ruly's AmbiguousLinks does not detect broken anchors. Wording stays "ambiguous".
- A4: No behavior was executed; a runtime quirk could differ from the code read.
- Agent counts and line anchors are valid for the pinned SHAs only.
- Method limitation: read, not run; no third-party code was executed.

## Spot-check log

| By       | File @SHA                                               | Lines                                                                                                                                               | Result                                                                                                                           |
| -------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| planner  | Ruler `src/core/ConfigLoader.ts` @5e551e6               | L75-L80, L125-L130                                                                                                                                  | Strict schema confirmed                                                                                                          |
| planner  | Ruler `src/agents/index.ts` @5e551e6                    | L39-L70                                                                                                                                             | 32 agents counted                                                                                                                |
| planner  | Ruler `src/core/RuleProcessor.ts` @5e551e6              | L7-L28                                                                                                                                              | `concatenateRules`, no include parsing                                                                                           |
| planner  | rulesync `src/config/config.ts` @6e3869d                | L116-L120, L176-L182                                                                                                                                | Schema range confirmed                                                                                                           |
| planner  | rulesync `docs/reference/file-formats.md` @6e3869d      | L702-L760                                                                                                                                           | Subagent section and `model` confirmed                                                                                           |
| planner  | rulesync `src/features/rules/rulesync-rule.ts` @6e3869d | L34-L40                                                                                                                                             | Frontmatter keys confirmed                                                                                                       |
| planner  | rulesync `src/cli/program.ts` @6e3869d                  | L342, L356-L359, L365                                                                                                                               | `-c`, `--input-roots`, `--check` confirmed                                                                                       |
| planner  | rulesync `docs/reference/cli-commands.md` @6e3869d      | L765-L768                                                                                                                                           | Doctor section confirmed                                                                                                         |
| planner  | ruly @4e85991                                           | `cli.rb` L17, L39, L50-L53; `subagent_processor.rb` L262-L271; `stats.rb` L12-L13, L122-L124; `checks/ambiguous_links.rb` L5-L7; `agents_md.rb` L12 | Confirmed                                                                                                                        |
| executor | Ruler `src/core/FileSystemUtils.ts` @5e551e6            | L199-L237                                                                                                                                           | `findRulerDir` walks up for `.ruler`, then returns `getXdgConfigDir()/ruler` if it is a directory; no merge, no fetch. Confirmed |
| executor | rulesync `src/types/tool-targets.ts` @6e3869d           | L23-L31                                                                                                                                             | `PACKAGING_TOOL_TARGETS` lists 7 `*-plugin` targets. Confirmed                                                                   |
| executor | Ruler `src/core/SubagentsProcessor.ts` @5e551e6         | L403-L416, L176                                                                                                                                     | `buildClaudeFile` sets `meta.model` when present (L410); `warnOnceExperimental` defined at L176. Confirmed                       |
