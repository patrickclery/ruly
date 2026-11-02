# Phase 3: Emphasize Core Advantages - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning
**Note:** User was away (asked for unattended work). All decisions below are the recommended defaults, auto-accepted by Claude; revisit on review.

<domain>
## Phase Boundary

Reposition README.md and the `site/` landing page around ruly's verified advantages: task-scoped recipe composition, `requires:` dependency resolution with cycle detection, per-subagent recipe/model selection, multi-machine `--sync` with per-machine `overrides:`, and post-squash checks. Contrast honestly against native `.claude/rules/` (path-only scoping), `@imports` (no token savings), and symlink-sharing limits. Docs/positioning only — no CLI behavior changes.

</domain>

<decisions>
## Implementation Decisions

### README Structure
- Open with a short "Why ruly" section (≤ 15 lines) listing the five advantages above, before install instructions
- Add a "Ruly vs. native Claude Code" comparison table (rows: per-task selection, dependency resolution, token cost of includes, cross-machine sharing, per-subagent model, post-squash checks)
- Keep existing install/usage sections; move long reference material (subagents, MCP propagation, agent file format) below the fold, do not delete
- Reflect Phase 2 removals (no `import`, `analyze`, `mcp`, `--cache`, taskmaster) — verify README has no stale references

### Claims & Evidence
- Every comparative claim about Claude Code cites the official docs URL from `.planning/research-competitive-2026-11-01.md` sources list
- Remove or soften the self-reported "85% token reduction" claim to "measured in Phase 6 benchmark" wording until Phase 6 produces numbers
- Do NOT claim superiority over Ruler/rulesync composition — that is unverified until Phase 7; describe ruly's model without comparative claims there
- Tone: factual, no marketing superlatives

### Site
- Update `site/app/page.tsx` hero/feature copy to match the README "Why ruly" points
- No new pages, no design changes — copy only
- Site must still build (`npm --prefix site run build`) and lint

### Claude's Discretion
- Exact wording, ordering of the advantage list, and table formatting

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- README.md (~1288 lines): sections "How It Works", "What Ruly Does", "Sharing Recipes Across Machines", "Subagents", "MCP Server Propagation"
- site/app/page.tsx, site/components/ — Next.js static export landing page
- `.planning/research-competitive-2026-11-01.md` — verified claims and source URLs

### Established Patterns
- Prettier for Markdown (printWidth 100); markdown-table-prettify for tables
- Mermaid for diagrams (never graphviz)

### Integration Points
- README.md, site/app/page.tsx, site/components/*

</code_context>

<specifics>
## Specific Ideas

- Native `.claude/rules/` reads only `paths:` frontmatter; `@imports` "don't reduce context cost"; symlinked shared rules need per-project approval and only path-less rules load after approval — cite https://code.claude.com/docs/en/memory

</specifics>

<deferred>
## Deferred Ideas

- Benchmark numbers for token reduction — Phase 6
- Comparative claims vs Ruler/rulesync composition — Phase 7 (may revise this phase's copy)

</deferred>
