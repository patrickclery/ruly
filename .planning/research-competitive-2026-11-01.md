# Ruly vs. the Rule-Management Landscape (2026-11-01)

Deep-research run: 23 sources, 114 claims extracted, 25 checked by 3 independent verifiers each, 23 confirmed and 2 refuted.

## Bottom line

Ruly's real advantage is **task-scoped composition**: named recipes, `requires:` dependency resolution with cycle detection, a recipe and model chosen per subagent, and one shared rules repo synced to every machine with per-machine overrides. Neither Claude Code nor the cross-agent sync tools offer this combination (as far as the research verified).

It is **behind** on agent coverage and adoption. It also **partly duplicates** Claude Code plugins and skills, which now package skills, commands, agents, hooks and MCP servers natively.

## Landscape

| Tool / approach                | What it is                                                                                           | Agents                                                 | Adoption                   |
| ------------------------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | -------------------------- |
| **ruly**                       | Ruby CLI that compiles recipes into CLAUDE.md, skills, commands and subagents                        | Claude (full); Cursor (`.mdc`) and shell_gpt (partial) | 5★, 0 forks                |
| **Ruler** (intellectronica)    | One `.ruler/` source synced to many agents                                                           | 32                                                     | ~2,956★, 165 forks, active |
| **rulesync** (dyoshikawa)      | Node CLI that generates rules, commands, MCP, ignore files, subagents, skills, hooks and permissions | ~67 + AGENTS.md                                        | ~1.6k★, ~8.2k commits      |
| **vibe-rules**                 | Global rule store plus npm-package rule distribution (`llms` export)                                 | ~10                                                    | —                          |
| **Claude Code native**         | CLAUDE.md hierarchy, `.claude/rules/` with `paths:`, `@imports`, skills, plugins                     | Claude                                                 | built in                   |
| **Basic Memory / memory MCPs** | Markdown + git as the source of truth, indexed as a graph and retrieved on demand through MCP search | any MCP client                                         | —                          |

**Closest rival: rulesync.** It covers nearly the same set of components as ruly across far more agents. Whether rulesync or Ruler can select rules per task the way ruly's recipes and `requires:` do was **not verified**. That is the most important open question. **Answered 2026-11-02 (Phase 7 audit, .planning/phases/07-competitor-composition-audit/07-AUDIT.md):** neither tool has named rule sets or profiles, includes between rule files, or include-cycle detection, so recipes plus `requires:` remain ruly's main difference. rulesync can layer whole source directories per run with `--input-roots`.

## Where ruly is ahead

- **Per-task selection.** Native `.claude/rules/` loads rules **only by file path** (`paths:` is the only frontmatter field it reads), with no way to compose rules per task or role and no dependency mechanism. Ruly's recipes fill that gap.
- **Token savings that `@imports` can't give.** Claude Code's docs say imports "don't reduce its context cost, because imported files load together with the CLAUDE.md that imports them".
- **Sharing across machines.** Natively, symlinked shared rules need approval once per project, and after approval only rules **without** `paths:` load. `~/.claude/rules/` covers one machine only. Neither has a sync or override mechanism, and `ruly squash --sync` plus `overrides:` does.
- **Per-subagent model choice and an always-loaded squashed body.** Plugins don't select a model per subagent per recipe.
- **Checks after compiling** (ambiguous anchor links, duplicate skill requires) and tiktoken stats. None of the rival tools reviewed advertise anything similar.

## Where ruly is behind

- **Agent coverage.** It fully supports one agent, against 32 for Ruler and about 67 for rulesync. In `lib/ruly/cli.rb`, skills, commands and subagents are only generated when `agent == 'claude'`.
- **Adoption and bus factor.** Ruler has about 590 times as many stars. Ruly has no community and depends on one maintainer.
- **Ecosystem.** It requires Ruby plus the `gh` CLI, while rival tools ship through npm and vibe-rules installs rules straight from npm dependencies. It produces no AGENTS.md output (the cross-agent standard).
- **Unverified headline claim.** The 85% token reduction is self-reported and has not been measured independently.

## Where ruly duplicates native features

- **Claude Code plugins** now bundle `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, LSP and output styles. Much of what ruly compiles from component files is now a native packaging format. Whether plugins can deliver always-on instructions is **uncertain**: two claims about plugin limits were refuted 1–2.
- **Skills** already give on-demand loading for task-specific instructions, and Claude Code's docs recommend them for exactly that.

## Obsidian and memory MCPs: a different problem

Memory systems like Basic Memory keep **knowledge** that agents retrieve on demand at runtime. Ruly compiles **instructions** ahead of time. They work alongside each other. No verified claims survived about Obsidian vaults or Obsidian MCPs, mem0 or MemPalace specifically, so this comparison is thin.

## What the research says about ruly's premise

- **Leaner, task-specific rules are justified.** IFScale found the best frontier models follow only about 68% of instructions when given 500 at once (near-perfect up to about 150 for top reasoning models). Chroma's context-rot study found performance dropping as input grew across 18 LLMs.
- **Context files have a cost.** Gloaguen et al. (ICLR 2026) found AGENTS.md and CLAUDE.md files don't generally raise task success (+~4% for developer-written files, −0.5–3% for LLM-generated ones) and **add more than 20% inference cost**.
- **But retrieval at runtime is favored just as much.** Anthropic's context-engineering guide says CLAUDE.md is "naively dropped into context up front" and recommends just-in-time retrieval. That backs ruly's goal of fewer tokens per task, but also backs native skills as a way to get there.

## Strategic options

1. **Emit AGENTS.md** (and possibly hand off to Ruler or rulesync for fan-out) to cover many agents without writing per-agent adapters.
2. **Package ruly output as a Claude Code plugin** to get native distribution and keep recipe composition as the unique layer.
3. **Benchmark the 85% claim** and measure rule compliance, not just tokens, against native path-scoped rules plus skills.
4. **Check Ruler's and rulesync's composition models.** If either has profiles or includes equivalent to recipes, ruly's main advantage shrinks.

## Caveats

Most feature evidence is self-reported in each project's README or docs, and these change quickly. Star counts only approximate adoption. Not verified: ai-rules, rule-porter, claude-code-templates, awesome-cursorrules, and the AGENTS.md spec itself. The research findings are directional and mostly use models from mid-2025.

## Sources

- Ruler: https://github.com/intellectronica/ruler · https://awesome.ecosyste.ms/projects/github.com%2Fintellectronica%2Fruler
- rulesync: https://github.com/dyoshikawa/rulesync · https://github.com/dyoshikawa/rulesync/wiki
- vibe-rules: https://unpkg.com/vibe-rules@0.3.41/README.md
- Claude Code memory: https://code.claude.com/docs/en/memory
- Claude Code plugins: https://code.claude.com/docs/en/plugins-reference
- Basic Memory: https://docs.basicmemory.com/reference/technical-information
- IFScale: https://arxiv.org/abs/2507.11538
- Chroma context rot: https://research.trychroma.com/context-rot
- Gloaguen et al.: https://arxiv.org/abs/2602.11988
- Anthropic context engineering: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
