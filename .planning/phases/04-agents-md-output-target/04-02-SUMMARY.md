---
phase: 04-agents-md-output-target
plan: 02
subsystem: docs-release
status: complete
tags: [agents-md, readme, changelog, release]
requires: [04-01]
provides:
  - "README `### AGENTS.md Output` section with cross-links and examples"
  - "ruly 0.3.0 (version.rb, gemspec via Ruly::VERSION, CHANGELOG)"
affects: []
tech-stack:
  added: []
  patterns: ["gemspec reads version from Ruly::VERSION via require_relative"]
key-files:
  created: []
  modified:
    - README.md
    - CHANGELOG.md
    - lib/ruly/version.rb
    - ruly.gemspec
decisions:
  - "README section placed directly above `### Commands`; message texts copied from agents_md.rb and cli.rb"
  - "Gem built only into a temp dir; global install deferred to the user after merge"
metrics:
  duration: 6min
  completed: 2026-11-02
actuals:
  tokens: 1800
  tasks: 2
  commits: 2
plan_head_before: 01666a498c52b701f01860b0d3d595f25fc0203b
plan_head_after: 220affb591b1b92bd4a4f66ad30bf88a3048f592
---

# Phase 4 Plan 02: AGENTS.md Docs and 0.3.0 Release Summary

README now documents `-a agents` (aliases, `-o`, header, skills under `## Skills`, skipped parts, overwrite and clean safety, `-i`/`-I`, recommended cross-agent path, cursor unchanged). The release is 0.3.0, and the gemspec now reads `Ruly::VERSION`, so `gem build` produces 0.3.0 instead of the stale 0.1.0.

## Tasks

| Task | Name | Commit |
|------|------|--------|
| 1 | README AGENTS.md Output section, links, examples | d03a07b |
| 2 | 0.3.0 version, gemspec, CHANGELOG, closing gates | 220affb |

## Verification

- README gate: section=1, `-a agents` lines=8, anchor links=2, stale bullet=0; Phase 3 headings intact; section-content gate has no MISSING keys; Prettier clean.
- `bin/ruly version` → `Ruly v0.3.0`; `help squash` lists `claude, cursor, agents`; gemspec loads as 0.3.0; first CHANGELOG heading is `## [0.3.0] - 2026-11-02`.
- Full suite: 546 examples, 15 failures, 1 pending; no failure outside `02-rspec-baseline.txt`.
- Differential gate vs 996098c: claude, cursor and claude `-t` output identical.
- RuboCop: 2 files inspected, no offenses.
- Temp-dir `gem build` packages 0.3.0; no `.gem` in the working tree; no `gem install` or `gem push` run.

## Post-merge step

After merging, refresh the installed `ruly`:

```bash
gem build ruly.gemspec && gem install --local ruly-0.3.0.gem && rm ruly-0.3.0.gem
```

This was deferred because the branch is unmerged and the run was unattended.

## Deviations from Plan

None - plan executed exactly as written. (Gemfile.lock stays modified and unstaged, as before the plan.)

## Self-Check: PASSED

- README.md, CHANGELOG.md, lib/ruly/version.rb, ruly.gemspec modified as listed.
- Commits d03a07b and 220affb are ancestors of HEAD.
