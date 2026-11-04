---
status: testing
phase: 06-token-and-compliance-benchmark
source: [06-VERIFICATION.md]
started: 2026-11-02T12:15:15Z
updated: 2026-11-02T12:15:15Z
---

## Current Test

number: 1
name: Live compliance run on Max subscription
expected: |
  `bundle exec ruby bench/compliance.rb --live` (16 `claude -p` calls on your Max subscription, no API; API credentials are unset for every call) completes and writes bench/results/compliance.json and compliance.md, ready to publish in docs/benchmarks.md. User-level memory may reach both conditions, which the docs disclose. Reply `run` and I'll start it, or run it yourself with `!` and report back.
awaiting: user response

## Tests

### 1. Live compliance run on Max subscription
expected: `bundle exec ruby bench/compliance.rb --live` (16 `claude -p` calls on your Max subscription, no API; API credentials are unset for every call) completes and writes bench/results/compliance.json and compliance.md, ready to publish in docs/benchmarks.md. User-level memory may reach both conditions, which the docs disclose. Reply `run` and I'll start it, or run it yourself with `!` and report back.
result: [pending]

### 2. Skill invocation and quote scorer behave on real replies
expected: In the live results, the bug-root-cause task invokes the skill in both conditions (WR-06), and the single-quotes scorer's pass/fail matches what each real reply actually did (WR-09).
result: [pending]

### 3. "Files in no recipe" detection on a second corpus
expected: Run against a second corpus, the verbatim-substring detection (WR-01) neither misses nor over-reports files that no recipe references.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

None recorded yet.
