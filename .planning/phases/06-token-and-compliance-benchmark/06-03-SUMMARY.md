---
phase: 06-token-and-compliance-benchmark
plan: 03
subsystem: docs
tags: [benchmark, docs, readme, tokens, compliance]
status: complete

requires:
  - "06-01: bench/results/tokens.json and tokens.md (fixture token results)"
  - "06-02: bench/compliance.rb and bench/compliance/tasks.yml (compliance harness, dry run)"
provides:
  - "docs/benchmarks.md: token results, compliance harness status (pending), methodology with citations, limitations, reproduction"
  - "README Token cost of includes row with the measured fixture medians and a link"
  - "Patterns note carries the measured fixture figure instead of the self-reported one"
affects: []

actuals:
  tokens: 4814
  tasks: 2
  commits: 2
plan_head_before: 322581b5c501489e171c41603af0c28b84341aa0
plan_head_after: e0103d33d432a151165f4f3c9f1beecd47484b13

tech-stack:
  added: []
  patterns:
    - "Every published figure is labeled as measured on ruly's synthetic fixture corpus and links docs/benchmarks.md"

key-files:
  created:
    - docs/benchmarks.md
  modified:
    - README.md
    - .claude/ruly-recipes-mcp-patterns.md

key-decisions:
  - "Headline figure is the fixture median reduction vs load-all (76.9%, range 72.8% to 85.4%); README also gives the native-floor median (68.4% smaller)"
  - "docs/benchmarks.md discloses that the fixture corpus is synthetic and was padded to clear a 10,000-token floor"

requirements-completed: []

coverage:
  - id: D1
    description: "README row and docs carry both medians recomputed from tokens.json, the fixture label and the docs link; README diff is one line"
    verification:
      - kind: integration
        ref: "Task 1 verify gates"
        status: pass
  - id: D2
    description: "docs/benchmarks.md sections, citations, commands, flags, model and task ids; patterns note has the median 3 times with the link"
    verification:
      - kind: integration
        ref: "Task 2 docs gate (run with LC_ALL=C.UTF-8)"
        status: pass
  - id: D3
    description: "Phase gates: tripwire dry run, token reproducibility, rspec vs baseline, RuboCop on bench/"
    verification:
      - kind: integration
        ref: "Task 2 closing gates"
        status: pass

duration: 3min
completed: 2026-11-02
---

# Phase 6 Plan 03: Benchmark Publication Summary

`docs/benchmarks.md` publishes the fixture token benchmark (median 76.9% smaller than loading every rule, 68.4% smaller than the native floor), describes the compliance harness as pending a paid live run, and states its methodology (IFScale, Chroma context rot, Gloaguen et al.) and limitations. The README token row and the three patterns-note lines now carry the measured fixture figure with a link.

## Performance

- **Started:** 2026-11-02T11:48:33Z
- **Completed:** 2026-11-02T11:51:15Z
- **Tasks:** 2/2
- **Files:** 3 (1 created, 2 modified)

## Accomplishments

- docs/benchmarks.md has five H2 sections: Token benchmark (results table copied from tokens.md, median/min/max table, conditions, corpus), Compliance benchmark (`Status: pending`, eight-task table with native placement, scoring, how to run with every guard flag), Methodology, Limitations, Reproduce.
- The methodology discloses that the fixture corpus is synthetic and that 19 of its rule files were padded with an extra section to clear the 10,000-token floor (11,091 tokens).
- The README edit is one line: the Ruly cell of `| Token cost of includes |`. The other rows and sections are byte-identical.
- The old self-reported percentage no longer appears in any tracked doc outside .planning. The compress.md threshold is untouched.

## Task Commits

1. **Task 1 (tracer): fixture token figure in docs and README**: `fe8022e`
2. **Task 2: methodology, compliance status, limitations, patterns note**: `e0103d3`

## Closing gates

- Task 1: `load_all_median=76.9% native_floor_median=68.4%`, no problems. README numstat vs the last non-06-03 README commit is `1 1`.
- Task 2 docs gate: `median=76.9% tasks=8`, no problems. The old-percentage grep and the home-path/key grep printed nothing, and site/, lib/, bin/, bench/ and rules/ have no changes.
- `phase-gates-ok`: the tripwire dry run printed `dry run ok: 8 tasks, 16 commands` with no call log, and a fresh tokens.json equals the committed one.
- Full rspec: 867 examples, 15 failures, 1 pending. All 15 failures are in the baseline.
- RuboCop `bench spec/bench`: 21 files inspected, no offenses.
- Tracer feedback gate: the automated verify was re-run and passed (not auto mode; human_verify_mode end-of-phase).
- No live `claude -p` or API call was made.

## Deviations from Plan

### Gate adaptations

**1. [Rule 3 - Blocking] Task 2 docs gate run with `LC_ALL=C.UTF-8`**
- **Found during:** Task 2 verify
- **Issue:** The shell sets `LC_ALL=C`, so Ruby read the patterns note as US-ASCII. Its existing emoji made `String#scan` raise, and the gate exited 1 with no output (stderr is discarded).
- **Fix:** Re-ran the identical gate with `LC_ALL=C.UTF-8`. It passed. No file changed.

**2. Patterns-note lines located by "85%" rather than by Phase 6 wording**
- **Issue:** Per the orchestrator note, the Phase 3 qualifier reads "(self-reported; unverified until an independent benchmark measures it)". The plan's gate checks that wording ("until an independent benchmark"), and it is gone from all three lines.

### Accuracy corrections in prose

- The corpus is described as 24 rule files across topics, and the padding as "19 of the rule files". 06-01 does not say the padded files are exactly the 19 always-loaded ones.

## Known Stubs

None. The compliance results are pending by design (D-07): a live run costs money and needs the user.

## Next Step for the User

To get compliance numbers, run `bundle exec ruby bench/compliance.rb --live`, optionally with `--isolated-home` and `ANTHROPIC_API_KEY` set. It makes 16 calls, worst case $8.00 at the default cap. Then publish the results in docs/benchmarks.md.

## Self-Check: PASSED

- FOUND: docs/benchmarks.md, README.md, .claude/ruly-recipes-mcp-patterns.md
- FOUND commits: fe8022e, e0103d3
