# Phase 6: Token and Compliance Benchmark - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning
**Note:** User was away (asked for unattended work). All decisions below are the recommended defaults, auto-accepted by Claude; revisit on review.

<domain>
## Phase Boundary

Independently measure (1) token cost of recipe-scoped output vs. alternatives and (2) rule compliance/task success of recipe-scoped output vs. native path-scoped rules + skills. Produce a reproducible benchmark harness and a results document. Replace the self-reported "85%" claim with measured numbers.

</domain>

<decisions>
## Implementation Decisions

### Token Benchmark (fully automated)
- Script under `bench/` (Ruby, reuses tiktoken via `Ruly::Operations::Stats` encoder, `cl100k_base`)
- Compare per recipe: (a) ruly squashed output, (b) all rules concatenated (load-everything baseline), (c) native layout equivalent: always-loaded CLAUDE.md + `.claude/rules/` files without `paths:` (what native loads up front), skills counted by description only
- Corpus: a fixture rules set committed under `bench/fixtures/` (deterministic, no network) PLUS optional run against the user's real rules repo when present (results noted separately, not committed if private)
- Output: `bench/results/tokens.md` table + JSON

### Compliance Benchmark (harness built, live run optional)
- Harness uses headless `claude -p` with a fixed small task suite (≤ 10 tasks) where each task has a checkable rule (e.g. "use single quotes", "no puts outside CLI"), scored by deterministic checks on output
- Two conditions: recipe-scoped CLAUDE.local.md vs native rules+skills layout
- Live run costs API money → NOT run automatically in this phase's verification; harness has a `--dry-run` that validates task/condition wiring. Results doc states compliance numbers are pending a manual run
- Use Claude models current at run time (default `claude-sonnet-5-5`), configurable

### Reporting
- `docs/benchmarks.md` (or README section if no docs/ dir) with methodology, numbers, and limitations
- README/site "85%" wording replaced with the measured token figure and a link

### Claude's Discretion
- Exact fixture contents and task suite wording

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/ruly/operations/stats.rb` — tiktoken `cl100k_base` encoder and per-file counting
- `ruly squash --dry-run` and recipe loader for resolving recipe file sets

### Established Patterns
- RSpec for harness unit tests; no network in specs (WebMock)

### Integration Points
- New `bench/` directory; README positioning from Phase 3

</code_context>

<specifics>
## Specific Ideas

- Research context: IFScale (~68% compliance at 500 instructions), Gloaguen et al. (context files +20% inference cost) — cite in methodology

</specifics>

<deferred>
## Deferred Ideas

- Running the live compliance benchmark at scale / multiple models
- CI integration of benchmarks

</deferred>
