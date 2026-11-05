---
phase: 06-token-and-compliance-benchmark
verified: 2026-11-04T12:00:00Z
status: passed
score: 6/6 must-haves verified
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
  - "bench/lib/ruly_bench.rb"
  - "bench/lib/ruly_bench/claude_command.rb"
  - "bench/lib/ruly_bench/compliance_cli.rb"
  - "bench/lib/ruly_bench/compliance_run.rb"
  - "bench/lib/ruly_bench/output_dir.rb"
  - "bench/lib/ruly_bench/scorer.rb"
  - "bench/lib/ruly_bench/token_benchmark.rb"
  - "bench/results/compliance.json"
  - "bench/results/compliance.md"
  - "bench/results/tokens.json"
  - "bench/results/tokens.md"
  - "bench/tokens.rb"
  - "docs/benchmarks.md"
  - "spec/bench/compliance_spec.rb"
  - "spec/bench/published_figures_spec.rb"
  - "spec/bench/token_benchmark_spec.rb"
covered_digest: "v3:sha256:1e466e58561105d4a90d57052dbd836a7aeb162d0cbc46c5066f76abf7c977be"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/6
  gaps_closed:
    - "Measured compliance / task-success numbers (truth 6): live run published, UAT 3/3 passed"
  gaps_remaining: []
  regressions: []
---

# Phase 6: Token and Compliance Benchmark Verification Report

**Phase Goal:** Independently measure the self-reported 85% token-reduction claim and rule compliance/task success of recipe-scoped output vs. native path-scoped rules + skills.
**Verified:** 2026-11-04
**Status:** passed
**Re-verification:** Yes. The prior report (2026-11-02, human_needed) is stale: bench code, docs/benchmarks.md and results changed. All three prior human_verification items are resolved by 06-UAT.md (3/3 passed).

Both halves of the goal are now measured and published. The published compliance numbers match the committed JSON, the docs' caveats match the data, and the token results and figures are unchanged and still correct.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Token harness measures every fixture recipe with cl100k_base against 4 conditions and writes tokens.json/tokens.md | VERIFIED | `bench/tokens.rb` run to a scratch dir: 5 recipes, exit 0. |
| 2 | Token results are deterministic and the committed results are current | VERIFIED | Fresh run to the scratchpad: `cmp` byte-identical for tokens.json and tokens.md. `git diff 52cc940 HEAD` shows no change to tokens.* or bench/fixtures since the last verification. |
| 3 | Published token figures in docs, README and the patterns note match tokens.json | VERIFIED | tokens.json summary: median 74.3% (69.8-83.8) vs load-all and vs ceiling, 68.4% (62.8-80.0) vs floor. `excluding_unreferenced`: 8,797 / 6,923 tokens, medians 70.9 / 63.0 / 70.9, 3 files, 1,175 tokens. docs lines 7-9 and 28-52 match exactly. 1,175/8,098 = 14.5% holds. The `referenced?` change (body OR descriptor, regardless of path) did not change the result: the same 3 files are flagged and the output is byte-identical. `published_figures_spec` passes. No `85%` remains in README, docs or the patterns note. |
| 4 | Compliance harness: dry run by default, 8 tasks x 2 conditions, prints argv, no API call; live and private-corpus guards hold | VERIFIED | Logging fake `claude` (exit 99) first on PATH: `dry run ok: 8 tasks, 16 commands`; argv shows `--tools Skill --strict-mcp-config --setting-sources project,local --max-budget-usd 0.50`; the fake's call log was never created. `--live --corpus bench/fixtures` exits 2; `--isolated-home` exits 2 (option removed; a spec asserts the rejection). |
| 5 | Docs describe methodology (IFScale, Chroma, Gloaguen), limitations, reproduction | VERIFIED | docs/benchmarks.md Methodology, Limitations and Reproduce sections present. The stale "pending" status and `--isolated-home` text are gone (no match for either in README, docs, bench). |
| 6 | Measured compliance / task-success numbers, recipe-scoped vs native, published | VERIFIED | `bench/results/compliance.json` (complete: true, schema 2, model claude-sonnet-5-5): ruly 8/8, native 6/8, 0 errors each. Published in docs/benchmarks.md line 62 and in compliance.md. See the check below. |

**Score:** 6/6 truths verified.

### Published compliance figures against compliance.json

| Claim in docs/benchmarks.md | Source check | Result |
|---|---|---|
| ruly 8/8, native 6/8, one sample per task and condition | JSON `conditions`; recounted from `tasks[].pass`: ruly 8, native 6, errors 0 | Match |
| The 4 always-loaded rules passed in both | `ruby-single-quotes`, `frozen-string-literal`, `no-puts-in-library`, `commit-subject` (tasks.yml placement "always"): pass in ruly and native | Match |
| 3 path-scoped rules cannot load in native; `migration-up-down` and `react-named-export` failed there | Native failures are exactly these two. Native migration reply uses `def change`; native React reply ends `export default UserBadge;`. Both are correct fails. Ruly passes both. | Match |
| `rspec-expect` passed anyway | Passes in both conditions | Match |
| `bug-root-cause` passes in both in this run | Both replies start `Root cause:` | Match |
| Skill task varied between runs (earlier run failed in both) | The earlier run is not in the repo (journal deleted on completion). It rests on the 06-UAT.md note, which the user accepted. | Not checkable from artifacts; consistent with UAT |
| compliance.md dollar figures are cost estimates | Per-task `cost_usd` sums to 0.8966615; JSON total 0.896662; compliance.md prints $0.8967 | Match |
| Scoring is deterministic regex | I re-read the 16 replies against the rule checks (commit-subject first lines are 64 and 62 chars, lower-case `type(scope):`) | No scorer error found |

### Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No Anthropic API use | HELD | `SUBSCRIPTION_ENV` unsets `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN`; `compliance_cli.rb:119` passes it to the live run, whose executor receives `env`. No `--isolated-home`. Docs state "never the API". I made no live call. |
| No non-fixture results committed | HELD | `git ls-files bench/results` is compliance.json, compliance.md, tokens.json, tokens.md; the corpus field is `bench/fixtures/corpus` and `bench/results/local/` is gitignored. |
| Fixture label on results | HELD | compliance.md opens with the "synthetic fixture corpus, not any real rules repository" note and states the results are not statistically significant. |
| No lib/, bin/, rules/ or dependency-manifest changes by this phase | HELD | `git diff 52cc940 HEAD --stat -- lib bin rules Gemfile` is empty. (The working-tree Gemfile.lock edit belongs to another session and is untouched.) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Token run reproducible | `bundle exec ruby bench/tokens.rb --output-dir <scratch>`; `cmp` | byte-identical | PASS |
| Compliance dry run, no API | fake `claude` first on PATH | 8 tasks, 16 commands, 0 fake calls | PASS |
| Guards | `--live --corpus bench/fixtures`; `--isolated-home` | both exit 2 | PASS |
| Bench specs | `bundle exec rspec spec/bench` | 137 examples, 0 failures | PASS |
| RuboCop | `bundle exec rubocop bench spec/bench` | 22 files, no offenses | PASS |

### Anti-Patterns Found

No TBD/FIXME/XXX/TODO markers in bench/ or docs/benchmarks.md. Advisory notes only:

| File | Pattern | Severity | Impact |
|---|---|---|---|
| spec/bench/published_figures_spec.rb | Guards token figures only; nothing ties the hand-copied compliance numbers in docs (8/8, 6/8) to compliance.json | Info | They match today (checked above). Drift is possible if compliance.json is regenerated without editing the docs. |
| docs/benchmarks.md | "Earlier run failed in both conditions" has no artifact in the repo | Info | Rests on the user-accepted UAT note. The doc words it as a report of an earlier run, not a measurement. |
| bench/results/tokens.md | load-all and native ceiling are identical columns (9,972) | Info | Disclosed in docs. |
| Compliance suite | One sample per cell; the 3 path-scoped tasks measure path-scoping cost under a no-file-tools setup; user memory may reach both conditions | Info | All three are stated under Limitations and in the Status paragraph; the docs explicitly say the run does not show ruly beats native. |

### Requirements Coverage

The phase declares no requirement IDs (`requirements: []` in all three plans). Nothing orphaned.

### Human Verification Required

None. The three prior items are resolved by 06-UAT.md: (1) the live run completed on the Max subscription; (2) skill triggering variance and the quote scorer were accepted; (3) the no-recipe detector was accepted after the second-corpus check.

### Gaps Summary

No gaps. Token figures are unchanged, reproducible and correctly published. Compliance numbers are published and exactly match compliance.json, and the docs' caveats describe the data accurately. One caveat cannot be checked from artifacts: the earlier-run skill failure, which relies on the accepted UAT record.

---

_Verified: 2026-11-04_
_Verifier: Claude (gsd-verifier)_
