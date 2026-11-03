---
phase: 06-token-and-compliance-benchmark
plan: 02
subsystem: testing
tags: [benchmark, compliance, claude-p, dry-run, rspec]
status: complete

requires:
  - "06-01: RulyBench::Corpus, SquashRunner, fixture corpus with the eight rule sentences"
provides:
  - "bench/compliance.rb: compliance benchmark. Dry run by default; --live is the only paid path"
  - "bench/compliance/tasks.yml: eight tasks, one per fixture rule sentence, each with deterministic checks and canned pass/fail replies"
  - "RulyBench::NativeLayout / Scorer / ComplianceTasks / ClaudeCommand / ComplianceRun / ComplianceCLI / OutputDir"
affects: [06-03]

actuals:
  tokens: 16076
  tasks: 2
  commits: 2
plan_head_before: cdad9a9dd7261eeff4a9f9457dd7234e4749a426
plan_head_after: 3a12d50e4e9ab6333811395218fbc3a3d53cec3f

tech-stack:
  added: []
  patterns:
    - "Executor injected as a callable (env, argv, chdir:, stdin_data:), so specs never spawn claude"
    - "Condition workspaces are temp dirs that hold only generated files (CLAUDE.local.md and .claude/, or .claude/ alone)"

key-files:
  created:
    - bench/compliance.rb
    - bench/compliance/tasks.yml
    - bench/lib/ruly_bench/native_layout.rb
    - bench/lib/ruly_bench/scorer.rb
    - bench/lib/ruly_bench/compliance_tasks.rb
    - bench/lib/ruly_bench/claude_command.rb
    - bench/lib/ruly_bench/compliance_run.rb
    - bench/lib/ruly_bench/compliance_cli.rb
    - bench/lib/ruly_bench/output_dir.rb
    - spec/bench/native_layout_spec.rb
    - spec/bench/scorer_spec.rb
    - spec/bench/compliance_spec.rb
  modified:
    - bench/lib/ruly_bench.rb
    - bench/lib/ruly_bench/squash_runner.rb
    - bench/lib/ruly_bench/tokens_cli.rb

key-decisions:
  - "Compliance harness: dry run is the default. --live runs claude -p (default model claude-sonnet-5-5) with a per-call --max-budget-usd cap and Edit/Write/Bash/NotebookEdit disallowed, and prints the worst-case spend first"
  - "Output-dir guard extracted to RulyBench::OutputDir and shared by TokensCLI and ComplianceCLI, so there is one private-corpus guard"
  - "--isolated-home sets HOME to a temp dir and unsets CLAUDE_CONFIG_DIR. The API key is inherited from the process and never copied into the env overrides"

requirements-completed: []

coverage:
  - id: D1
    description: "Dry run over 8 tasks x 2 conditions, no API call, path-scoped native location reported"
    verification:
      - kind: integration
        ref: "Task 2 tripwire gate: bundle exec ruby bench/compliance.rb --dry-run --check-cli"
        status: pass
  - id: D2
    description: "Live mode guards (exclusive flags, private corpus, isolated home key, output dir) and scoring with a fake executor"
    verification:
      - kind: unit
        ref: "spec/bench/compliance_spec.rb#RulyBench::ComplianceCLI"
        status: pass
  - id: D3
    description: "Token results unchanged by the SquashRunner change"
    verification:
      - kind: integration
        ref: "fresh bench/tokens.rb run equals bench/results/tokens.json (tokens_unchanged=true)"
        status: pass

duration: 10min
completed: 2026-11-02
---

# Phase 6 Plan 02: Compliance Benchmark Harness Summary

`bench/compliance.rb` runs eight fixture-rule tasks under two conditions. The **ruly** condition is the outputs of `ruly squash RECIPE`; the **native** condition is `.claude/rules` plus `.claude/skills` for the same corpus. Each reply is scored by deterministic regex checks. The default dry run builds both workspaces, locates every rule, proves the scoring on canned replies and prints the exact `claude -p` argv, without calling claude. A paid run needs `--live`.

## Performance

- **Started:** 2026-11-02T11:37Z (approx.)
- **Completed:** 2026-11-02T11:47Z
- **Tasks:** 2/2
- **Files:** 15 created or modified

## Accomplishments

- Dry run output (fixture): 8 `[ok]` lines, `dry run ok: 8 tasks, 16 commands`. In the native condition, three rules are path-scoped (rspec, migrations, components), four are always loaded, and the bug-report rule is a skill in both conditions. In ruly, every rule except the skill sits in CLAUDE.local.md.
- `--check-cli` runs only `claude --help` and confirms all 7 flags (`--print` + 6 used).
- Live call: `claude -p --model M --output-format json --setting-sources project,local --no-session-persistence --max-budget-usd CAP --disallowedTools Edit,Write,Bash,NotebookEdit`, with the prompt on stdin and the workspace as cwd.
- A live run writes `compliance.json` (schema 1, per-condition passed/total/errors, per-cell reply, cost and failed checks) and `compliance.md` (fixture notice, results table, failures, totals and a "not statistically significant" note).
- 47 new specs (94 in spec/bench). Every live path uses a fake executor.

## Task Commits

1. **Task 1 (tracer): one task through the dry run**: `0f69720`
2. **Task 2: eight-task suite, guarded live mode, specs**: `3a12d50`

## Closing gates

- Tripwire dry run with `--check-cli` passed (exit 0, empty call log), as did the plain dry run with no call log.
- `bundle exec rspec spec/bench`: 94 examples, 0 failures. Full rspec: 867 examples, 15 failures. All 15 are in `02-rspec-baseline.txt`, so there are no new failures.
- RuboCop `bench spec/bench`: 21 files inspected, no offenses.
- A fresh token run equals `bench/results/tokens.json`. `bench/results` holds only tokens.json and tokens.md, and `lib/`, `bin/` and the fixtures are untouched.
- Tracer feedback gate: the automated `<verify>` was re-run and passed (not in auto mode; human_verify_mode end-of-phase).
- No live `claude -p` or API call was made.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Single guard] Output-dir guard extracted to `RulyBench::OutputDir`**
- **Found during:** Task 2
- **Issue:** The plan asked the live output-dir guard to "mirror TokensCLI". Copying it would have left two private-corpus guards that could drift apart.
- **Fix:** Added `bench/lib/ruly_bench/output_dir.rb`. TokensCLI now delegates to it, with the same messages and exit codes, and its 23 existing specs still pass.
- **Files modified:** bench/lib/ruly_bench/output_dir.rb, bench/lib/ruly_bench/tokens_cli.rb, bench/lib/ruly_bench.rb
- **Commit:** 3a12d50

**2. [Rule 1 - Bug] `--check-cli` crashed on non-ASCII `claude --help` output**
- **Found during:** Task 2 gate
- **Issue:** `Open3.capture2e` returned US-ASCII-tagged bytes, and regex matching raised "invalid byte sequence".
- **Fix:** The help text is now force-encoded to UTF-8 and scrubbed before matching.
- **Commit:** 3a12d50

**3. [Rule 3 - Blocking] Task YAML loaded with `aliases: true`, malformed YAML raises `RulyBench::Error`**
- **Found during:** Task 2 (specs build task files with `to_yaml`, which emits aliases)
- **Commit:** 3a12d50

### Discretion notes

- Commands found in a workspace get the label `command`. The plan listed only always, path-scoped and skill; no task targets a command.
- `--isolated-home` is checked in every mode, so it exits 2 without a key even in a dry run.

## Known Stubs

None.

## Next Step for the User

Live run (paid, about 16 calls, worst case $8.00 at the default cap): `bundle exec ruby bench/compliance.rb --live` (add `--isolated-home` with `ANTHROPIC_API_KEY` set for a clean HOME).

## Self-Check: PASSED

- FOUND: bench/compliance.rb, bench/compliance/tasks.yml, bench/lib/ruly_bench/{native_layout,scorer,compliance_tasks,claude_command,compliance_run,compliance_cli,output_dir}.rb, spec/bench/{native_layout,scorer,compliance}_spec.rb
- FOUND commits: 0f69720, 3a12d50
