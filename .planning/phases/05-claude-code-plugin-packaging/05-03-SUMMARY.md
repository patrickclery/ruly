---
phase: 05-claude-code-plugin-packaging
plan: 03
subsystem: docs-release
status: complete
tags: [claude-plugin, readme, changelog, release]
requires:
  - phase: 05-claude-code-plugin-packaging
    provides: "05-01/05-02 claude-plugin target (manifest, rules skill, components, hooks, MCP, scripts, safety)"
provides:
  - "README `### Claude Code Plugin Output` section plus How It Works, Commands, Command File Handling and Examples cross-links"
  - "CHANGELOG 0.4.0 entry; Ruly::VERSION 0.4.0 (plugin.json version follows at runtime)"
  - "Phase-closing gate results"
affects: []
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - README.md
    - CHANGELOG.md
    - lib/ruly/version.rb
decisions:
  - "No `### Changed` in CHANGELOG 0.4.0: 05-01/05-02 record no user-visible change to existing output, and the differential gate confirms it"
  - "README quotes the shipped skipped-parts text from ClaudePlugin.notices/skipped_parts verbatim"
metrics:
  duration: "4 min"
  completed: 2026-11-02
estimate:
  tokens: 50000
  tasks: 2
actuals:
  tokens: 4200
  tasks: 2
  commits: 2
plan_head_before: 7db8c61efd226646c8ad46c091956cf3a1b9a036
plan_head_after: 8b4897ef33cab1d9d122bd9450e7c488feae004b
---

# Phase 5 Plan 03: Document and Release the claude-plugin Target Summary

The README now has a `### Claude Code Plugin Output` section. It covers the layout, the manifest fields, the evidence that plugins cannot load rules always-on, the component mapping and its limits, MCP secrets, the overwrite and clean safety rules, and validation, with cross-links from four places. ruly is released as 0.4.0 in `version.rb`, the gemspec, the generated `plugin.json` and the CHANGELOG. Nothing was installed or published.

## Performance

- Started 2026-11-02T10:50:30Z, finished 2026-11-02T10:54:31Z (about 4 min)
- 2 tasks, 2 commits

## Task Commits

| Task | Name | Commit | Type |
|------|------|--------|------|
| 1 | README Claude Code Plugin Output section and cross-links | 008f99a | docs |
| 2 | Release 0.4.0 (version.rb, CHANGELOG) | 8b4897e | chore |

## Phase-Closing Gates

| Gate | Result |
|------|--------|
| Task 1 README checks | section=1, `-a claude-plugin`=8, anchor links=2, Why ruly / native comparison / AGENTS.md Output each 1, no MISSING keys |
| Version/help/gemspec/CHANGELOG | `Ruly v0.4.0`, help lists claude-plugin, 8 commands, gemspec 0.4.0, first heading `## [0.4.0] - 2026-11-02` |
| Full suite | 713 examples, 15 failures, 1 pending. All 15 failures are in 02-rspec-baseline.txt (0 new) |
| Differential (base `c0895d7^`) | claude, cursor, claude -t, agents and claude (claude_plugin fixture): byte-identical |
| RuboCop per touched file | cli.rb 1/1, script_manager.rb 8/8, subagent_processor.rb 8/8, all others 0/0; cli.rb has no ClassLength offense |
| Strict validate | **RAN**: `claude plugin validate --strict` printed `✔ Validation passed` (claude 2.1.304); plugin.json version 0.4.0 |
| Gem build | Built 0.4.0 into a temp dir only; it packages claude_plugin.rb, and no .gem is in the repo |

Strict-validate status across the phase: 05-01 **ran and passed**, 05-02 **ran and passed**, 05-03 **ran and passed**.

## Deviations from Plan

None. The plan ran exactly as written.

## Post-merge step

After merging, refresh the installed binary with `gem build ruly.gemspec && gem install --local ruly-0.4.0.gem`, then delete the built `ruly-0.4.0.gem`. This run did not do it because the branch is unmerged and the run was unattended.

## Human verification (post-run)

1. **A3, namespaced preloaded skills (carried from 05-02, [ASSUMED], non-blocking):** in a scratch dir with a generated fixture plugin, run `claude --plugin-dir ruly-plugin-demo` and open `/agents`. Confirm that `demo:helper` is listed. Then ask Claude to run the helper subagent and report whether the `Review Skill` content was preloaded. If it was not, switch the plugin-mode names in `SubagentProcessor.extract_skill_names` to bare names (a one-line change), and update the README line "Preloaded skills are listed as `RECIPE:skill`" to match. **Status: not run.**
2. Skim the new README section to confirm the tone fits.

## Known Stubs

None.

## Threat Flags

None. T-05-14 (README tells users to replace literal values with `${VAR}` and documents `-i`/`-I`), T-05-15 (README says plugins cannot carry always-on rules) and T-05-16 (temp-dir build only, no install or push) are mitigated.

## Self-Check: PASSED

- FOUND: README.md (`### Claude Code Plugin Output`), CHANGELOG.md (`## [0.4.0]`), lib/ruly/version.rb (`0.4.0`)
- FOUND commits: 008f99a, 8b4897e (both ancestors of HEAD)
