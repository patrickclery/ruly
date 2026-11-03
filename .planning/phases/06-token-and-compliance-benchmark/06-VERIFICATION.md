---
phase: 06-token-and-compliance-benchmark
verified: 2026-11-02T07:00:00Z
status: human_needed
score: 5/6 must-haves verified
covered_files:
  - ".claude/ruly-recipes-mcp-patterns.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-01-PLAN.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-01-SUMMARY.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-02-PLAN.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-02-SUMMARY.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-03-PLAN.md"
  - ".planning/phases/06-token-and-compliance-benchmark/06-03-SUMMARY.md"
  - "README.md"
  - "bench/compliance.rb"
  - "bench/compliance/tasks.yml"
  - "bench/lib/ruly_bench/claude_command.rb"
  - "bench/lib/ruly_bench/compliance_run.rb"
  - "bench/lib/ruly_bench/output_dir.rb"
  - "bench/lib/ruly_bench/scorer.rb"
  - "bench/lib/ruly_bench/token_benchmark.rb"
  - "bench/results/tokens.json"
  - "bench/results/tokens.md"
  - "bench/tokens.rb"
  - "docs/benchmarks.md"
  - "spec/bench/published_figures_spec.rb"
covered_digest: "v3:sha256:a819633e7a284c947a6822dcd807787b87594781d4a1889d183d7b97179c6326"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Run the live compliance benchmark once: `bundle exec ruby bench/compliance.rb --live` (paid, fixture corpus, default model claude-sonnet-5-5)"
    expected: "bench/results/compliance.json and compliance.md are written; the ruly vs native pass rates for the 8 tasks can then be published in docs/benchmarks.md. This is the only way to satisfy the 'rule compliance/task success' half of the phase goal."
    why_human: "Costs API money; locked out of this phase by 06-CONTEXT.md. Compliance numbers are documented as pending."
  - test: "During that live run, confirm `--tools Skill` actually lets the model invoke skills (the bug-root-cause task, skill condition) and that the single-quotes regex in tasks.yml scores real replies correctly"
    expected: "The skill is invoked in both conditions; no false pass/fail from the scorer"
    why_human: "06-REVIEW-FIX.md WR-06 and WR-09 both flag these as unverifiable without a live call. Offline specs cover the regex on 9 fixed cases only."
  - test: "Spot-check detection of 'files in no recipe' (WR-01) against a second corpus"
    expected: "Verbatim-substring detection neither misses nor over-reports unreferenced files"
    why_human: "Review-fix flagged it for human verification; the fixture's 3 hits are right but the method is heuristic."
---

# Phase 6: Token and Compliance Benchmark Verification Report

**Phase Goal:** Independently measure the self-reported 85% token-reduction claim and rule compliance/task success of recipe-scoped output vs. native path-scoped rules + skills.
**Verified:** 2026-11-02
**Status:** human_needed
**Re-verification:** No, initial verification

The token half of the goal is measured, published, and reproducible. The compliance half has a working, guarded harness but no measured numbers. That is the locked scope (06-CONTEXT.md), so it is routed to human verification (a paid manual run), not failed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Token benchmark harness measures every fixture recipe with tiktoken cl100k_base against 4 conditions (ruly, load-all, native floor, native ceiling) and writes tokens.json/tokens.md | VERIFIED | `bench/tokens.rb` run to a scratch dir: 5 recipes, 4 counts each. |
| 2 | Results are deterministic and the committed results are current | VERIFIED | Fresh `bundle exec ruby bench/tokens.rb --output-dir <scratch>`: `cmp` byte-identical for tokens.json and tokens.md (ruly_version 0.4.0 matches too, so no ignore needed). |
| 3 | Published figures in docs/benchmarks.md, README token row and .claude/ruly-recipes-mcp-patterns.md match tokens.json after the review fixes | VERIFIED | tokens.json: median 74.3% (69.8-83.8) vs load-all; 68.4% (62.8-80.0) vs native floor; 74.3% vs ceiling; without the 3 unreferenced rules 70.9% / 63.0% / 70.9%; baselines 9,972 / 8,098 / 9,972. docs tables (lines 30-52), README line 100 (74.3%, 68.4%, 63.0%) and patterns note lines 5, 156, 249 (74.3%) all agree. The 14.5% (1,175/8,098) checks out. `spec/bench/published_figures_spec.rb` enforces the ties and passes. The old self-reported 85% figure is gone from every tracked file outside .planning (only the unrelated `0.85` similarity threshold in compress.md remains). |
| 4 | Compliance harness: dry-run by default, 8 tasks x 2 conditions, prints argv, no API call; live mode and private corpus are guarded | VERIFIED | With a logging fake `claude` (exit 99) first on PATH: `dry run ok: 8 tasks, 16 commands`, fake call log never created. `--live --corpus bench/fixtures` exits 2 with the private-corpus message; `--isolated-home` without ANTHROPIC_API_KEY exits 2. Task prompts do not state the rule sentence. |
| 5 | docs describe the methodology (IFScale, Chroma, Gloaguen), limitations, reproduction, and state compliance results are pending | VERIFIED | docs/benchmarks.md has Methodology (lines 99-107 cite all three), Limitations (120), Reproduce (132), and "Status: pending. No live run has been made" (line 62). |
| 6 | Measured compliance / task-success numbers for recipe-scoped vs native (the second half of the phase goal) | HUMAN_NEEDED | `bench/results/compliance.*` does not exist, by design. Requires a paid live run. See human verification. |

**Score:** 5/6 truths verified (1 needs a paid manual run; locked scope, not a failure).

### Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No live API calls in verify/spec/benchmark | HELD | Fake-`claude` tripwire log never created across the dry run, guard checks and the full rspec run. I made no live call. |
| No non-fixture results committed | HELD | `git ls-files bench/results` is only tokens.json and tokens.md; `bench/results/local/` is gitignored (`.gitignore:9`) and absent. |
| Fixture label on results | HELD | tokens.md H1 and "not a measurement of any real rules repository" note; `"label": "fixture"` in JSON; docs and README say "synthetic". |
| No lib/ or bin/ changes by this phase | HELD | Files changed by the `(06` / `06-0x` commits include none under lib/, bin/, site/, rules/ or any dependency manifest. (lib/ diffs in the branch belong to Phases 4/5.) |
| No compliance results committed | HELD | No `bench/results/compliance*` file. |
| README change confined to the one row | HELD for Phase 6 | The Phase 6 hunk is the single "Token cost of includes" cell. Other README diffs are Phase 4/5/7. |
| No `rules` directory under bench/ | HELD | `find bench -name rules` returns nothing. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Token run reproducible | `bundle exec ruby bench/tokens.rb --output-dir <scratch>`; `cmp` | byte-identical | PASS |
| Compliance dry run | fake `claude` first on PATH, `bundle exec ruby bench/compliance.rb` | `dry run ok: 8 tasks, 16 commands`, 0 fake calls | PASS |
| Live/private guards | `--live --corpus bench/fixtures`; `--isolated-home` unset key | both exit 2 | PASS |
| rspec | `bundle exec rspec` | 908 examples, 15 failures, 1 pending; all 15 match `02-rspec-baseline.txt` by full description, 0 new (`comm -13` empty) | PASS |
| RuboCop | `bundle exec rubocop bench spec/bench` | 22 files, no offenses | PASS |

### Anti-Patterns Found

None blocking. Advisory notes:

| File | Pattern | Severity | Impact |
|---|---|---|---|
| bench/results/tokens.md | load-all and native ceiling are now identical columns (9,972) | Info | Redundant, disclosed in the docs and as a follow-up in 06-REVIEW-FIX.md. |
| 06-01-SUMMARY.md:49 | Stale mixed-baseline range "62.8% to 85.4%" | Info | Historical SUMMARY (WR-02 skipped on purpose); published docs are correct. |
| Fixture corpus | Padded to a target size; figures depend on corpus makeup | Info | Disclosed under Limitations. The 74.3% describes the fixture only, not a real repository. |
| Native condition | The 3 path-scoped compliance tasks never load their rules natively, since no file is opened | Info | Documented in docs and follow-ups; interpret as path-scoping cost when the live run happens. |

### Requirements Coverage

Phase has no requirement IDs. Nothing orphaned.

### Human Verification Required

1. **Live compliance run** (paid): `bundle exec ruby bench/compliance.rb --live`. Expected: compliance.json/md written, then publish the pass rates in docs/benchmarks.md. This is required to fully satisfy the compliance half of the phase goal.
2. **Live-only assumptions** from 06-REVIEW-FIX.md: that `--tools Skill` is the right way to enable skill invocation, and that the single-quotes regex scores real replies correctly.
3. **Unreferenced-file detection** (WR-01) is a verbatim-substring heuristic; sanity-check on a second corpus.

### Gaps Summary

No gaps. The token benchmark is measured, reproducible, correctly published, and the 85% claim is replaced with the measured fixture figure (74.3% median vs load-all, not 85%). The compliance harness is built and guarded but unmeasured by locked scope, so the phase is `human_needed` pending a paid manual run.

---

_Verified: 2026-11-02_
_Verifier: Claude (gsd-verifier)_
