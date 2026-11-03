---
status: testing
phase: 06-token-and-compliance-benchmark
source: [06-VERIFICATION.md]
started: 2026-11-02T12:15:15Z
updated: 2026-11-02T12:15:15Z
---

## Current Test

number: 1
name: Paid live compliance run
expected: |
  `bundle exec ruby bench/compliance.rb --live` (16 calls, worst case $8.00 at the default $0.50/call cap) completes; publish results in docs/benchmarks.md (replace "Status: pending").
awaiting: user response

## Tests

1. Paid live compliance run produces numbers; publish in docs/benchmarks.md. (pending)
2. During the live run confirm `--tools Skill` lets the model invoke skills (WR-06) and the single-quotes scorer grades real replies correctly (WR-09). (pending)
3. Sanity-check the "files in no recipe" verbatim-substring detection (WR-01) on a second corpus. (pending)

## Summary

total: 3
passed: 0
issues: 0
pending: 3

## Gaps

None recorded yet.
