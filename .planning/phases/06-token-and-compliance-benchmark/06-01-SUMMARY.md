---
phase: 06-token-and-compliance-benchmark
plan: 01
subsystem: testing
tags: [benchmark, tiktoken, cl100k_base, fixtures, rspec]
status: complete

requires: []
provides:
  - "bench/tokens.rb: deterministic token benchmark running the real bin/ruly squash in an isolated temp workspace"
  - "RulyBench::Corpus / SquashRunner / TokenBenchmark / TokensCLI / TokenCounter under bench/lib"
  - "Synthetic fixture corpus (bench/fixtures/corpus): 19 rules, 5 path rules, 4 skills, 2 commands, 5 recipes, 11,091 tokens"
  - "Eight verbatim compliance rule sentences in the fixture corpus (input to plan 06-02)"
  - "Committed fixture results bench/results/tokens.json and tokens.md"
affects: [06-02, 06-03]

actuals:
  tokens: 27960
  tasks: 3
  commits: 4
plan_head_before: 59e04ac4f21ae9247c8b1263445e6a1a315f7313
plan_head_after: db61e018f7ec7ce165ab08aaa32210c4bb9644ee

tech-stack:
  added: []
  patterns:
    - "Benchmark harness lives under bench/ and requires repo lib via require_relative; no lib/ or bin/ change"
    - "Subprocess via Open3.capture2e argv array with HOME/RULY_HOME/BUNDLE_GEMFILE isolation"

key-files:
  created:
    - bench/tokens.rb
    - bench/lib/ruly_bench.rb
    - bench/lib/ruly_bench/token_counter.rb
    - bench/lib/ruly_bench/corpus.rb
    - bench/lib/ruly_bench/squash_runner.rb
    - bench/lib/ruly_bench/token_benchmark.rb
    - bench/lib/ruly_bench/tokens_cli.rb
    - bench/fixtures/corpus/recipes.yml
    - bench/results/tokens.json
    - bench/results/tokens.md
    - spec/bench/token_counter_spec.rb
    - spec/bench/corpus_spec.rb
    - spec/bench/token_benchmark_spec.rb
  modified:
    - .gitignore

key-decisions:
  - "Fixture token result: median ruly reduction 76.9% vs load-all, 68.4% vs native floor, 74.3% vs native ceiling (5 synthetic recipes; range 62.8% to 85.4%)"
  - "TokensCLI takes a repo_root: keyword (default REPO_ROOT) so the output-dir guard is spec-tested against a tmp root, never the real tree"
  - "SquashRunner raises SquashRunner::SquashFailed (carries exit_status) so external-corpus failures become skipped rows with 'squash failed (exit N)'"

requirements-completed: []

coverage:
  - id: D1
    description: "bundle exec ruby bench/tokens.rb measures all five fixture recipes with real squash output and writes tokens.json/tokens.md"
    verification:
      - kind: integration
        ref: "bundle exec ruby bench/tokens.rb (Task 1 and Task 3 gates)"
        status: pass
  - id: D2
    description: "Two runs give byte-identical output; committed JSON equals a fresh run"
    verification:
      - kind: integration
        ref: "Task 3 determinism gate (cmp of two fresh runs and committed files)"
        status: pass
  - id: D3
    description: "Non-fixture corpus refused (exit 2) outside git-ignored bench/results/local"
    verification:
      - kind: unit
        ref: "spec/bench/token_benchmark_spec.rb#RulyBench::TokensCLI"
        status: pass
  - id: D4
    description: "Fixture corpus shape, token range and eight compliance sentences"
    verification:
      - kind: other
        ref: "Task 2 corpus gate (kinds 19/5/4/2, total 11,091, missing=[])"
        status: pass

duration: 10min
completed: 2026-11-02
---

# Phase 6 Plan 01: Token Benchmark Summary

A Ruby harness under `bench/` that runs the real `bin/ruly squash` per recipe in an isolated temp workspace and compares it against load-all and the native Claude Code floor and ceiling (tiktoken `cl100k_base`). On the synthetic fixture the median reduction is 76.9% vs load-all and 68.4% vs native floor.

## Performance

- **Started:** 2026-11-02T11:26:52Z
- **Completed:** 2026-11-02T11:36:50Z
- **Tasks:** 3/3
- **Files:** 47 created or modified

## Accomplishments

- `bench/tokens.rb` with `--corpus`, `--output-dir`, `--recipes`, `--label`; exit 0 ok, 1 harness error, 2 usage error or refused output dir.
- `SquashRunner` copies the corpus to a temp `work/`, sets `HOME`, `RULY_HOME` and `BUNDLE_GEMFILE`, and runs `bin/ruly squash RECIPE` as an argv array after validating the name against `\A[\w.-]+\z`.
- Fixture corpus of 30 files (11,091 tokens; rule files 344 to 511 tokens) and 5 recipes. All 8 compliance sentences are present verbatim.
- 47 specs in `spec/bench` cover every behavior bullet. One example runs a real end-to-end squash on a tmp corpus.

## Fixture results (committed)

| Recipe | ruly | vs load-all | vs native floor | vs native ceiling |
|---|--:|--:|--:|--:|
| bug | 2,677 | 75.8% | 66.9% | 73.2% |
| frontend | 1,620 | 85.4% | 80.0% | 83.8% |
| pr-review | 2,562 | 76.9% | 68.4% | 74.3% |
| ruby-feature | 3,015 | 72.8% | 62.8% | 69.8% |
| testing | 2,085 | 81.2% | 74.3% | 79.1% |

Baselines are the same for every recipe: load-all 11,083, native floor 8,098, native ceiling 9,972.

## Task Commits

1. **Task 1 (tracer): one fixture recipe end to end**: `888627b`
2. **Task 2: full corpus, private-corpus guard, specs**: `ee5e6bd`
3. **Task 3: committed fixture results**: `db61e01`

The measured `commits: 4` includes `c841041 docs(phase-05): verification human_needed, defer UAT`. That commit came from the concurrent Phase 5 verifier, not from this plan.

## Closing gates

- Determinism: two fresh runs were byte-identical. The committed JSON matches a fresh run (`recipes=5 committed_matches=true`).
- `git ls-files bench/results` lists exactly `tokens.json` and `tokens.md`. The fixture H1 and the "not a measurement" sentence are present, and there are no absolute or temp paths.
- Full rspec: 820 examples, 15 failures, 1 pending. Every failure is listed in `02-rspec-baseline.txt` (no new failures).
- RuboCop `bench spec/bench`: 10 files inspected, no offenses. `lib/`, `bin/` and `.rubocop.yml` are untouched.
- Tracer feedback gate: the automated `<verify>` was re-run and passed (not auto mode; human_verify_mode end-of-phase).

## Optional real-repo run (Task 3 step 3)

Skipped by orchestrator decision: this was an unattended run, and that corpus holds private data. Nothing was written under `bench/results/local/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corpus initially landed at 10,115 tokens, too close to the 10,000 floor**
- **Found during:** Task 2
- **Fix:** Added a short section to 19 rule files, bringing the total to 11,091.
- **Commit:** ee5e6bd

**2. [Rule 2 - Testability] `TokensCLI` gained `repo_root:`, `err:` and `out:` keywords**
- **Found during:** Task 2
- **Issue:** The plan requires the guard specs never to touch the real tree.
- **Fix:** Added injectable defaults. `REPO_ROOT`, `$stderr` and `$stdout` stay the defaults, so CLI behavior is unchanged.
- **Commit:** ee5e6bd

Otherwise the plan was executed as written.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: bench/tokens.rb, bench/lib/ruly_bench/*.rb (6), bench/results/tokens.json, bench/results/tokens.md, spec/bench/*_spec.rb (3)
- FOUND commits: 888627b, ee5e6bd, db61e01
