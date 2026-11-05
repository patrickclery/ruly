---
status: testing
phase: 06-token-and-compliance-benchmark
source: [06-VERIFICATION.md]
started: 2026-11-02T12:15:15Z
updated: 2026-11-05T03:06:02Z
---

## Current Test

number: 3
name: "Files in no recipe" detection on a second corpus
expected: |
  I ran the "files in no recipe" check on your real rules (237 files, private results kept outside the repo). It wrongly flagged 13 files whose recipes do use them, and I fixed that. It now flags 26, and each one is used only by recipes the benchmark skips (8 with remote sources, plus `full`, which fails to squash), and a separate walk of the recipes and their `requires:` reached the same 26 files, so it neither misses nor over-reports. The fix leaves the published fixture numbers unchanged. Pass means you accept this.
awaiting: user response

## Tests

### 1. Live compliance run on Max subscription
expected: `bundle exec ruby bench/compliance.rb --live` (16 `claude -p` calls on your Max subscription, no API; API credentials are unset for every call) completes and writes bench/results/compliance.json and compliance.md, ready to publish in docs/benchmarks.md. User-level memory may reach both conditions, which the docs disclose. Reply `run` and I'll start it, or run it yourself with `!` and report back.
result: pass
note: run on Max subscription. First run lost 2 tasks to a harness encoding bug (LC_CTYPE=C), now fixed; second run complete: ruly 8/8, native 6/8. Both native failures are path-scoped rules the no-file-tools setup cannot load (disclosed limitation).

### 2. Skill invocation and quote scorer behave on real replies
expected: In the two live runs, bug-root-cause followed the skill's `Root cause:` rule in neither condition on run 1 and in both on run 2, so the skill can be invoked (`--tools Skill` works) but doesn't trigger every time. The quote scorer's single-quotes results matched the replies in the run I checked (no plain double-quoted strings in either). Pass means you accept this, and the published results will state the skill task varied between runs.
result: pass

### 3. "Files in no recipe" detection on a second corpus
expected: I ran the "files in no recipe" check on your real rules (237 files, private results kept outside the repo). It wrongly flagged 13 files whose recipes do use them, and I fixed that. It now flags 26, and each one is used only by recipes the benchmark skips (8 with remote sources, plus `full`, which fails to squash), and a separate walk of the recipes and their `requires:` reached the same 26 files, so it neither misses nor over-reports. The fix leaves the published fixture numbers unchanged. Pass means you accept this.
result: [pending]

## Summary

total: 3
passed: 2
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

None recorded yet.
