---
phase: 03-emphasize-core-advantages
fixed_at: 2026-11-02T09:44:35Z
review_path: .planning/phases/03-emphasize-core-advantages/03-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-11-02T09:44:35Z
**Source review:** .planning/phases/03-emphasize-core-advantages/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (WR-01..WR-04, IN-01, IN-03 site install part, IN-04 "Phase 6" part)
- Fixed: 7
- Skipped: 0

**Where it ran:** main checkout on `gsd/competitive-positioning`, with no worktree. A temp-branch worktree could not fast-forward if the concurrent planner committed to the same branch, and it would have no `site/node_modules`. Site gates (`npm --prefix site run lint && npm --prefix site run build`) ran in the main checkout and passed after WR-03 and IN-03.

## Fixed Issues

### WR-01: Patterns file still instructs a command that fails on 0.2.0

**Files modified:** `.claude/ruly-recipes-mcp-patterns.md`
**Commit:** 48ce0b3
**Applied fix:** `ruly squash --recipe workaxle-testing` is now `ruly squash workaxle-testing`. `mise install ruby` is replaced with `cd ~/ruly && git pull && bundle install`, the same steps `setup.rb update` runs.

### WR-02: Patterns file gives contradictory path rules

**Files modified:** `.claude/ruly-recipes-mcp-patterns.md`
**Commit:** a4e7e8a
**Applied fix:** Deleted anti-pattern 3 ("Must use absolute paths") and renumbered the next one. The `files:` examples in section 2, both recipe examples and anti-pattern 2 now use repo-relative paths. The intentional "WRONG" absolute-path example in section 1 and the "Related Files" list are unchanged.

### WR-03: Site metadata and demo carry the old positioning

**Files modified:** `site/app/layout.tsx`, `site/components/InteractiveTerminal.tsx`, `site/lib/generate-demo-data.ts`
**Commit:** 54bae07
**Applied fix:** The metadata title and description now use the new hero line and subtitle. Override, Merge and Ghost are not real ruly features, so the demo's deploy-mode question was removed. The demo now defaults `deployMode` to `"merge"`, because ruly writes `CLAUDE.local.md`, which loads alongside `CLAUDE.md`. The two merge-mode strings in the generated demo output no longer say "merge mode". The unused override and ghost branches in `generate-demo-data.ts` were left in place to keep the change small.
**Status:** fixed: requires human verification (demo flow changed: project type now leads straight to the repo-name step)

### WR-04: Recipes card says squash reports circular chains

**Files modified:** `site/app/page.tsx`
**Commit:** a2fe63a
**Applied fix:** "...and circular chains are reported." is now "...and ruly stats lists any circular chains."

### IN-01: "Checks after every squash" is not true for `--dry-run`

**Files modified:** `README.md`, `site/app/page.tsx`
**Commit:** 0764cfc (wording), 347a2ae (Prettier realignment of the README comparison table; lefthook is not installed in this clone, so hooks did not reformat it)
**Applied fix:** README "Why ruly" bullet, README comparison-table cell, site hero and site "Sync and checks" card now say checks run on squashes that write output/files (README bullet notes "not `--dry-run`").

### IN-03 (site part): Install story contradicts itself

**Files modified:** `site/app/page.tsx`
**Commit:** a87826c
**Applied fix:** The hero `gem install ruly` badge is now a link to the README Quick Install section, labeled "One-line install: ruby setup.rb". The footer shows the README's one-line curl + `ruby setup.rb` command. The RubyGems footer link is unchanged. Moving "Requirements" out of the README Benefits list was out of scope and was not done.

### IN-04 (Phase 6 part): Internal planning jargon in session-loaded file

**Files modified:** `.claude/ruly-recipes-mcp-patterns.md`
**Commit:** 79f0cbe
**Applied fix:** All 3 occurrences of "until the Phase 6 token benchmark measures it" now say "until an independent benchmark measures it". The other IN-04 items (the "Key Achievements" heading, "file patterns", and "quoted from" in the README) were out of scope and were not changed.

## Out of scope (not attempted)

- IN-02 (code styling for config tokens on the site).
- IN-03 README part (Requirements listed under Benefits).
- IN-04 remainder (heading rename, "file patterns", README "quoted" vs "summarized").

---

_Fixed: 2026-11-02T09:44:35Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
