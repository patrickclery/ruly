---
phase: 06-token-and-compliance-benchmark
reviewed: 2026-11-02T00:00:00Z
depth: standard
files_reviewed: 28
files_reviewed_list:
  - bench/tokens.rb
  - bench/compliance.rb
  - bench/lib/ruly_bench.rb
  - bench/lib/ruly_bench/claude_command.rb
  - bench/lib/ruly_bench/compliance_cli.rb
  - bench/lib/ruly_bench/compliance_run.rb
  - bench/lib/ruly_bench/compliance_tasks.rb
  - bench/lib/ruly_bench/corpus.rb
  - bench/lib/ruly_bench/native_layout.rb
  - bench/lib/ruly_bench/output_dir.rb
  - bench/lib/ruly_bench/scorer.rb
  - bench/lib/ruly_bench/squash_runner.rb
  - bench/lib/ruly_bench/token_benchmark.rb
  - bench/lib/ruly_bench/token_counter.rb
  - bench/lib/ruly_bench/tokens_cli.rb
  - bench/compliance/tasks.yml
  - bench/fixtures/corpus/recipes.yml
  - bench/results/tokens.json
  - bench/results/tokens.md
  - spec/bench/compliance_spec.rb
  - spec/bench/corpus_spec.rb
  - spec/bench/native_layout_spec.rb
  - spec/bench/scorer_spec.rb
  - spec/bench/token_benchmark_spec.rb
  - spec/bench/token_counter_spec.rb
  - docs/benchmarks.md
  - README.md
  - .claude/ruly-recipes-mcp-patterns.md
findings:
  critical: 1
  warning: 10
  info: 5
  total: 16
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-11-02
**Depth:** standard
**Files Reviewed:** 28 (plus .gitignore; fixture `*.md` skimmed for secrets/real paths, none found)
**Status:** issues_found

## Summary

The harness runs deterministically. A fresh `bench/tokens.rb` run to a scratch dir is byte-identical to the committed `tokens.json`/`tokens.md`. `spec/bench` passes (94 examples) and RuboCop is clean. Subprocesses use argv arrays with no shell interpolation, the recipe and model ids are regex-gated, and the prompt goes on stdin. No live `claude -p` call was made during this review.

**Requested range check.** `tokens.json` gives vs load-all min 72.8 / max 85.4 and vs native floor min 62.8 / max 80.0. `docs/benchmarks.md` (72.8%–85.4%), the README (76.9% / 68.4%) and the patterns note (76.9%) all match `tokens.json`. The "62.8%–85.4%" range in 06-01-SUMMARY is wrong: it pairs the native-floor minimum with the load-all maximum (WR-02).

**Main problem.** The headline load-all baseline counts skill and command bodies, but the docs say no condition counts them (CR-01). Separately, 3 always-loaded fixture rules that belong to no recipe inflate every native and load-all baseline without being disclosed (WR-01). The padding is not a material bias (IN-05).

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: load-all counts skill and command bodies, but the published methodology says no condition does

**File:** `bench/lib/ruly_bench/token_benchmark.rb:116`, `:188`; `docs/benchmarks.md:18`, `:99`; `bench/results/tokens.md:16`; `README.md:100`
**Issue:** `load_all` is `corpus.concat(corpus.files.map { body })`, and `corpus.files` includes `skills/*.md` and `commands/*.md`. The ruly side counts only the `name: description` line of each skill and command. Measured on the fixture, skill and command bodies are 1,210 of the 11,083 load-all tokens. load-all equals the native ceiling minus 99 descriptor tokens plus those bodies. Three claims are therefore false:
- the generated tokens.md and docs line 18 say "Skill and command bodies are not counted in any condition";
- docs line 99 says skills and commands "are counted by their `name: description` line on both sides";
- the README describes the baseline as "loading every rule file", but it also includes non-rule skill and command files.

The headline median is inflated as a result. With skill and command bodies excluded (B=9,873), the vs-load-all median is 74.1% (range 69.5–83.6), not 76.9% (72.8–85.4). The spec at `spec/bench/token_benchmark_spec.rb:43` (`load_all > native_ceiling`) only passes because of this inclusion.
**Fix:** Pick one definition and make code, docs and specs agree. Either count skills and commands as descriptors in load-all:
```ruby
'load_all' => body_tokens(%i[rule path_rule]) + TokenCounter.count(corpus.concat(files_of(:skill, :command).map { |f| corpus.body(f) }))
```
and reword the condition to "every file, including skill and command bodies", or exclude the bodies and add descriptors. Then regenerate tokens.json/md and update the 76.9% in docs, the README and the patterns note.

## Warnings

### WR-01: Orphan always-loaded rules inflate every baseline (undisclosed corpus bias)

**File:** `bench/fixtures/corpus/recipes.yml:1-46`; `docs/benchmarks.md:22,102`
**Issue:** `comms/issue-tracker.md`, `comms/status-updates.md` and `database/queries.md` (1,175 tokens, 14.5% of the native floor) are always-loaded rules that no recipe uses. They can never appear in ruly output, but they count fully in load-all, the native floor and the native ceiling. Without them, the vs-native-floor median falls from 68.4% to 63.0% (range 56.4–76.6), and vs-native-ceiling falls from 74.3% to 70.9%. The docs describe the recipes as "each the set of files one kind of task needs" and never mention rules outside every recipe.
**Fix:** Either drop the orphans, or disclose them in Corpus/Limitations with the with/without figures. Better still, add a `corpus_stats['unreferenced_files']` count to tokens.json so the bias is machine-visible.

### WR-02: 06-01 reported a mixed-baseline range (62.8%–85.4%)

**File:** `.planning/phases/06-token-and-compliance-benchmark/06-01-SUMMARY.md:49`
**Issue:** "range 62.8% to 85.4%" pairs the native-floor min (62.8) with the load-all max (85.4). No baseline has that range. The docs' 72.8%–85.4% is correct for load-all. The figure has not leaked into docs, the README or the patterns note, but the summary feeds downstream milestone summaries.
**Fix:** Correct the summary to give one range per baseline: load-all 72.8–85.4, native floor 62.8–80.0, native ceiling 69.8–83.8.

### WR-03: Docs give a corpus size (11,091) that matches no published figure

**File:** `docs/benchmarks.md:102`
**Issue:** "bringing the corpus to 11,091 tokens". 11,091 is the sum of per-file body counts, while the published load-all figure (the concatenated corpus) is 11,083. A reader checking the docs against tokens.json finds two different "whole corpus" numbers.
**Fix:** Use 11,083 (the load-all figure), or say "11,091 tokens counted file by file (11,083 concatenated)".

### WR-04: The private-corpus output guard covers only bench/results; docs claim results go "only" to bench/results/local

**File:** `bench/lib/ruly_bench/output_dir.rb:19-25`; `docs/benchmarks.md:83`
**Issue:** `forbidden?` only refuses paths under `bench/results/` outside `local/`. `--output-dir docs` or `--output-dir .` with a private corpus is accepted, writing private `compliance.json` (full model replies) or `tokens.json` into tracked repo paths. The refusal message even suggests "a directory outside bench/results". The docs say results "are written only to the git-ignored `bench/results/local/`".
**Fix:** For a non-fixture corpus, refuse any output dir inside `repo_root` that is not inside `bench/results/local` (`inside?(output_dir, real_path(repo_root)) && !inside?(output_dir, local)`). Otherwise, soften the docs to "by default".

### WR-05: A live run keeps results only in memory; any mid-run exception loses all paid results

**File:** `bench/lib/ruly_bench/compliance_run.rb:62-64,179-184`
**Issue:** `live_run` writes compliance.json only after all 16 calls finish. `live_cell` rescues only `SystemCallError`. An `Interrupt` (Ctrl-C), a `JSON::GeneratorError` on an odd reply, or a squash failure aborts the run. All replies and cost data already paid for are then discarded.
**Fix:** Append each cell to a `compliance.partial.jsonl` in `output_dir` as it completes, and write the final files from it. Rescue `StandardError` in `live_cell` into an `error_cell` so one bad call cannot sink the run.

### WR-06: "The model can only reply" is overstated; read and agent tools remain enabled and are an asymmetric confound

**File:** `bench/lib/ruly_bench/claude_command.rb:7`; `docs/benchmarks.md:81`
**Issue:** `DISALLOWED_TOOLS = 'Edit,Write,Bash,NotebookEdit'` leaves Read, Glob, Grep, Task/Agent, Skill and Web* enabled. In the native workspace, the model can Grep or Read `.claude/rules/*`, including path-scoped and non-recipe rules. The ruly workspace has no non-recipe rules to find. So tool use can change which rules reach the model differently per condition, and the docs claim it cannot act at all.
**Fix:** Either disallow `Read,Glob,Grep,Task,WebFetch,WebSearch` too (keeping `Skill` so the skill task stays testable), or document which tools remain and record tool-use counts from the JSON output per cell.

### WR-07: Stale `.claude/` or `CLAUDE.local.md` in an external corpus is counted on the ruly side only

**File:** `bench/lib/ruly_bench/squash_runner.rb:42-46,73-83`; `bench/lib/ruly_bench/corpus.rb:100`
**Issue:** `prepare_workspace` copies every root entry except `.git`, including a corpus's existing `.claude/skills/*` and `.claude/commands/*`. `collect` then globs those into the ruly descriptors, and `ComplianceRun#ruly_workspace` copies them into the ruly workspace. `Corpus#files` skips dot dirs, so the baselines never include them. Verified: an external corpus with a leftover `.claude/skills/stale/SKILL.md` produced `descriptors == ["stale: Leftover skill ..."]` for a recipe without skills.
**Fix:** Skip `.claude`, `CLAUDE.md`, `CLAUDE.local.md` and other generated outputs when copying in `prepare_workspace` (`next if %w[.git .claude CLAUDE.local.md].include?(entry)`).

### WR-08: NativeLayout silently overwrites colliding targets

**File:** `bench/lib/ruly_bench/native_layout.rb:13-19,26,32`
**Issue:** Rules are flattened with `rel.tr('/', '-')`, so `a-b/c.md` and `a/b-c.md` both become `.claude/rules/a-b-c.md`. Verified: `build` returned the same path twice and one rule was lost. Two skills with the same derived name collide the same way. On an external corpus, the native compliance workspace then silently drops rules, and dry-run marker location can report the wrong file.
**Fix:** Raise `RulyBench::Error` on a duplicate target, or keep the directory structure under `.claude/rules/` (Claude Code reads subdirectories).

### WR-09: The ruby-single-quotes check fails compliant code that has two interpolated strings on a line

**File:** `bench/compliance/tasks.yml:20`
**Issue:** `'"[^"#\n]*"'` also matches the text between two strings. In `log("#{a}", "#{b}")` it matches `", "`, so a reply that fully follows the rule is scored as failing (verified with `Scorer.score`). Quotes in comments also trip the check.
**Fix:** Match whole string literals, for example `(?<![\w"])"(?:[^"\\#]|\\.|#(?!\{))*"`. Add a compliant `example_pass` with two interpolated strings on one line so the dry run guards it.

### WR-10: Scorer misses indented fences, then scores prose as code; specs don't guard doc-vs-result drift

**File:** `bench/lib/ruly_bench/scorer.rb:7,44-47`; `spec/bench/token_benchmark_spec.rb`
**Issue:** `FENCE = /\A(`{3,}|~{3,})/` rejects fences indented by 1–3 spaces, which CommonMark allows. The `code` scope then falls back to the whole reply, so prose such as "I avoided puts here" fails `no-puts-in-library` (verified). Separately, no spec checks that the committed `bench/results/tokens.json` equals a fresh run, or that the figures in docs, the README and the patterns note equal `tokens.json['summary']`. Those numbers are hand-copied, and CR-01/WR-02/WR-03 are exactly that kind of drift.
**Fix:** Use `FENCE = /\A {0,3}(`{3,}|~{3,})/` and strip indentation in `closing_fence?`. Add a spec that regenerates the fixture benchmark into a tmp dir, compares it to `bench/results/tokens.json`, and greps `docs/benchmarks.md`/`README.md` for the summary medians.

## Info

### IN-01: The react-named-export check rejects valid named exports

**File:** `bench/compliance/tasks.yml:233`
**Issue:** It requires `export function|const UserBadge`, so `function UserBadge…; export { UserBadge };` fails (verified), even though it follows "use named exports".
**Fix:** Also accept `export\s*\{[^}]*\bUserBadge\b`.

### IN-02: A sub-cent `--max-budget-usd` is passed to claude as 0.00

**File:** `bench/lib/ruly_bench/claude_command.rb:23`; `compliance_cli.rb:93-97`
**Issue:** `format('%.2f', 0.004)` gives `"0.00"`, while the printed worst case uses the unrounded value.
**Fix:** Reject values below 0.01, or format with more precision.

### IN-03: A zero baseline reports a 0.0% reduction even when ruly output is non-empty

**File:** `bench/lib/ruly_bench/token_benchmark.rb:15-19`
**Issue:** An external corpus with only skills or commands yields `native_floor` 0 and a "0.0%" that hides an increase.
**Fix:** Return `nil` and render "n/a".

### IN-04: Unknown or duplicate `--recipes` names are not usage errors

**File:** `bench/lib/ruly_bench/tokens_cli.rb:53`; `token_benchmark.rb:73-89`
**Issue:** On an external corpus, a misspelled recipe shows up as "squash failed (exit 1)" in skipped and the run exits 0. `--recipes a,a` measures `a` twice and skews the median.
**Fix:** Validate names against `corpus.recipes.keys` and call `uniq` up front, returning 2 on unknown names.

### IN-05: The padding of 19 fixture files does not materially bias results; the disclosure could be more precise

**File:** `docs/benchmarks.md:102`
**Issue:** 06-01 padded the corpus from 10,115 to 11,091 tokens, about 51 tokens on each of 19 of the 24 rule files. Uniform per-file padding grows the recipe output and the baselines roughly in proportion, so the effect on the percentages is under about 1 point; the orphan rules (WR-01) are the real composition bias. The docs disclose the padding, but not the pre-padding size or which files were padded.
**Fix:** Add "from 10,115 tokens" and say that the padding was one section per padded file, roughly even across files.

---

_Reviewed: 2026-11-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
