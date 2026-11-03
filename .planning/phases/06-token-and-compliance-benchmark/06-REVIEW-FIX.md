---
phase: 06-token-and-compliance-benchmark
fixed_at: 2026-11-02T00:00:00Z
review_path: .planning/phases/06-token-and-compliance-benchmark/06-REVIEW.md
iteration: 1
findings_in_scope: 16
fixed: 15
skipped: 1
status: partial
---

# Phase 6: Code Review Fix Report

**Fixed at:** 2026-11-02
**Source review:** .planning/phases/06-token-and-compliance-benchmark/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 16 (CR-01, WR-01..WR-10, IN-01, IN-05 as requested; IN-02, IN-03, IN-04 added at discretion)
- Fixed: 15
- Skipped: 1 (WR-02, by instruction: SUMMARY files are historical)

## Published figures (new)

| Baseline | Median | Range | Without the 3 rules in no recipe |
|---|--:|--:|--:|
| vs load-all | 74.3% (was 76.9%) | 69.8–83.8% | 70.9% |
| vs native floor | 68.4% | 62.8–80.0% | 63.0% |
| vs native ceiling | 74.3% | 69.8–83.8% | 70.9% |

Load-all now equals the native ceiling (9,972 tokens) by construction. Both count every rule body plus every skill or command description.

## Verification

All gates ran in the **main checkout** (`workflow.use_worktrees` not used; the caller asked for no worktree).
- `bundle exec rspec`: 908 examples, 15 failures. All 15 are in `02-rspec-baseline.txt` (compared by full description), with no new failures. `spec/bench` passes: 135 examples, 0 failures.
- `bundle exec rubocop bench spec/bench`: 22 files, no offenses.
- A fresh `bench/tokens.rb` run to a scratch dir is byte-identical to the committed `tokens.json`/`tokens.md`. The new spec `spec/bench/published_figures_spec.rb` now enforces this.
- Dry run with a logging fake `claude` first on PATH: `dry run ok: 8 tasks, 16 commands`, and the fake was called 0 times. No live `claude -p` or API call was made. Only `claude --help` was run, to confirm the flags.

## Fixed Issues

### CR-01: load-all counted skill and command bodies
**Files modified:** `bench/lib/ruly_bench/token_benchmark.rb`, `spec/bench/token_benchmark_spec.rb`, `bench/results/tokens.{json,md}`, `docs/benchmarks.md`, `README.md`, `.claude/ruly-recipes-mcp-patterns.md`
**Commit:** eabca33
**Applied fix:** Every condition now counts skills and commands by description only. The spec that relied on the old inconsistency (`load_all > native_ceiling`) now asserts equality. A new spec checks that load-all counts descriptors and not bodies. Results were regenerated, and the docs, README cell and three patterns-note lines now give 74.3%.

### WR-01: always-loaded rules in no recipe
**Files modified:** `token_benchmark.rb`, `token_benchmark_spec.rb`, `tokens.{json,md}`, `docs/benchmarks.md`, `README.md`
**Commit:** 36fc981
**Applied fix:** The rules stay in the native baselines. The harness now finds files whose body or descriptor appears in no measured recipe's squash output. It reports them in `corpus_stats.unreferenced_files` and in `excluding_unreferenced` (file list, 1,175 tokens, baselines and summary without them), and the schema is now 2. tokens.md and docs have a "Files in no recipe" section with the alternative figures. The README cell adds "(63.0% if three fixture rules that no recipe uses are left out)". **Requires human verification:** detection is a verbatim substring match against the squash output.

### WR-03 + IN-05: corpus size and padding wording
**Files modified:** `docs/benchmarks.md`
**Commit:** e61abed
**Applied fix:** The docs now state the pre-padding size (10,115) and the post-padding size (11,091), both counted file by file including skill and command bodies, with about 51 tokens per padded file on average. They also give rule-only tokens (9,881) and the published load-all (9,972).

### WR-04: private-corpus output guard
**Files modified:** `bench/lib/ruly_bench/output_dir.rb`, `token_benchmark.rb`, `compliance_run.rb`, `spec/bench/token_benchmark_spec.rb`, `spec/bench/compliance_spec.rb`, `docs/benchmarks.md`
**Commit:** afadcf1
**Applied fix:** A non-fixture corpus may write only inside `bench/results/local` or outside the repo. Specs cover `docs` and `.` being refused and an outside dir being allowed. The docs and external-corpus notices were reworded to match.

### WR-05: live results lost on interrupt or error
**Files modified:** `bench/lib/ruly_bench/compliance_run.rb`, `spec/bench/compliance_spec.rb`, `docs/benchmarks.md`
**Commits:** 45a4b9a, 4c3edec (spec alignment for rubocop)
**Applied fix:** Each finished cell is appended to `compliance.partial.jsonl`. On `Interrupt` or any `StandardError`, the finished tasks are written with `"complete": false`, the journal is kept, and the exception is re-raised. On success the journal is deleted. `live_cell` turns any `StandardError` into an error cell, and replies are scrubbed. compliance.json schema is now 2 (adds `complete`).

### WR-06: read, search, agent and web tools were enabled
**Files modified:** `bench/lib/ruly_bench/claude_command.rb`, `compliance_run.rb`, `spec/bench/compliance_spec.rb`, `docs/benchmarks.md`
**Commit:** 5f5ae7a
**Applied fix:** Both conditions now pass `--strict-mcp-config --tools Skill` in place of `--disallowedTools`. Both flags were confirmed with `claude --help` (2.1.304), and `check_binary` passes 8/8. The docs no longer say "can only reply". The path-scoped limitation now says those 3 rules never load in the native condition, since no file is opened. **Requires human verification:** that `Skill` is the right tool name for invoking skills, which cannot be checked without a live call.

### WR-07: stale `.claude/` or CLAUDE.local.md counted on the ruly side only
**Files modified:** `bench/lib/ruly_bench/squash_runner.rb`, `spec/bench/token_benchmark_spec.rb`
**Commit:** 14bf078
**Applied fix:** `prepare_workspace` skips root dot entries and `CLAUDE.local.md`, matching `Corpus#files`. The new spec fails against the old code and passes with the fix.

### WR-08: native layout collisions
**Files modified:** `bench/lib/ruly_bench/native_layout.rb`, `spec/bench/native_layout_spec.rb`
**Commit:** 0dbe4b9
**Applied fix:** `build` maps every file first. On a duplicate target it raises `RulyBench::Error` naming the target and its sources, and writes nothing.

### WR-09: single-quotes check false-failed
**Files modified:** `bench/compliance/tasks.yml`, `spec/bench/scorer_spec.rb`, `docs/benchmarks.md`
**Commit:** dcad59b
**Applied fix:** The check now scans each line from its start over whole literals. It ignores comments and allows interpolation or escape sequences, which the fixture rule text permits. example_pass has two interpolated strings on one line, and specs run the committed pattern against 6 pass and 3 fail cases. **Requires human verification:** regex logic.

### WR-10: indented fences, and no drift guard
**Files modified:** `bench/lib/ruly_bench/scorer.rb`, `spec/bench/scorer_spec.rb`, `spec/bench/published_figures_spec.rb` (new)
**Commits:** 05672f4 (fences), 92553d2 (drift spec)
**Applied fix:** Fences may be indented up to 3 spaces. Content is dedented, and closing fences follow CommonMark (same character, at least as long, at most 3 spaces). The new spec regenerates the fixture run and compares it with the committed results, ignoring ruly_version. It also checks every docs table row and prose figure, the README cell and the 3 patterns-note lines against tokens.json.

### IN-01: named-export check
**Files modified:** `bench/compliance/tasks.yml`, `spec/bench/scorer_spec.rb`, `docs/benchmarks.md`
**Commit:** a8a6e67
**Applied fix:** `export { UserBadge }` now counts as a named export, and `as default` is forbidden. Both changes are covered by specs.

### IN-02: sub-cent budget (discretionary)
**Commit:** 76b6d8e. `--max-budget-usd` below 0.01 is a usage error.

### IN-04: unknown or duplicate `--recipes` (discretionary)
**Commit:** 48fd1a6. An unknown name exits 2 before any measurement, and repeated names are de-duplicated.

### IN-03: zero baseline (discretionary)
**Commit:** 55982b3. The reduction and summary are now null and render as "n/a" instead of 0.0%. Fixture results are unchanged and still byte-identical.

## Skipped Issues

### WR-02: mixed-baseline range in 06-01-SUMMARY
**File:** `.planning/phases/06-token-and-compliance-benchmark/06-01-SUMMARY.md:49`
**Reason:** Not edited, by instruction (SUMMARY ranges are historical). The published docs, README, patterns note and tokens.md give one range per baseline, and `published_figures_spec.rb` enforces this.
**Original issue:** "range 62.8% to 85.4%" pairs the native-floor minimum with the load-all maximum.

## Follow-ups (not done)
- Load-all and the native ceiling are now identical columns. A later schema could drop one, or redefine load-all, for example as a single concatenated CLAUDE.md that includes skill bodies, but only with a clearly different label.
- The three path-scoped compliance tasks now measure path-scoping cost rather than rule-following in the native condition, as documented. Consider a prompt that opens a matching file, or treat them separately in a live run.
- No lib/ change was needed.

---

_Fixed: 2026-11-02_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
