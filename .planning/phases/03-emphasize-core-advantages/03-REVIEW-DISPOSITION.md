---
phase: 03
review: 03-REVIEW.md
titles: json
findings:
  - id: IN-01
    severity: info
    disposition: open
    title: "Config/CLI tokens rendered as bare prose, now mixed with one code span in the same paragraph (carried over, evidence updated)"
  - id: IN-02
    severity: info
    disposition: open
    title: "Site claims contradict the README comparison-table row they should match (carried over)"
  - id: IN-03
    severity: info
    disposition: open
    title: "Meta description is 219 characters (carried over)"
  - id: IN-04
    severity: info
    disposition: open
    title: "The card's ruly-tools route skips the two README steps it depends on"
  - id: WR-01
    severity: warning
    disposition: fixed
    title: "Raw skill URL overflows the \"Draft a recipe from a project\" card"
  - id: WR-02
    severity: warning
    disposition: fixed
    title: "Recipe-from-project card tells users to squash the skill into \"a recipe\" without the README's data-loss warning"
  - id: WR-03
    severity: warning
    disposition: fixed
    title: "Benchmark card drops the \"rules in no recipe\" qualifier that docs/benchmarks.md attaches to the same medians"
open: 4
total: 7
recorded: 2026-11-13T09:16:30.800Z
---

# Phase 03: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| WR-01 | warning | fixed | 03-REVIEW-FIX.md (not in the current review) |
| WR-02 | warning | fixed | 03-REVIEW-FIX.md (not in the current review) |
| WR-03 | warning | fixed | 03-REVIEW-FIX.md (not in the current review) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
