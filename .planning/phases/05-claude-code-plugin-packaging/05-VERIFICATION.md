---
phase: 05-claude-code-plugin-packaging
verified: 2026-11-02T18:20:00Z
status: passed
score: 17/17 must-haves verified
covered_files:
  - .planning/phases/05-claude-code-plugin-packaging/05-01-PLAN.md
  - .planning/phases/05-claude-code-plugin-packaging/05-01-SUMMARY.md
  - .planning/phases/05-claude-code-plugin-packaging/05-02-PLAN.md
  - .planning/phases/05-claude-code-plugin-packaging/05-02-SUMMARY.md
  - .planning/phases/05-claude-code-plugin-packaging/05-03-PLAN.md
  - .planning/phases/05-claude-code-plugin-packaging/05-03-SUMMARY.md
  - CHANGELOG.md
  - README.md
  - lib/ruly/cli.rb
  - lib/ruly/services.rb
  - lib/ruly/services/claude_plugin.rb
  - lib/ruly/services/display.rb
  - lib/ruly/services/mcp_manager.rb
  - lib/ruly/services/script_manager.rb
  - lib/ruly/services/source_processor.rb
  - lib/ruly/services/subagent_processor.rb
  - lib/ruly/version.rb
  - spec/ruly/claude_plugin_spec.rb
  - spec/ruly/cli_claude_plugin_spec.rb
  - spec/ruly/subagent_plugin_mode_spec.rb
covered_digest: "v3:sha256:3ebc245f71eea63191751daeb5bb8468469bdce892127cbbee279b848932529b"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 17/17
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 5: Claude Code Plugin Packaging Verification Report

**Phase Goal:** Package squashed recipe output as a Claude Code plugin (skills/, commands/, agents/, hooks, .mcp.json) so distribution uses the native format instead of ruly-specific file writing; resolve whether plugins can carry always-on instructions.
**Verified:** 2026-11-02
**Status:** passed (all automated checks pass; human UAT 3/3 passed, see 05-UAT.md)
**Re-verification:** Yes. The prior report was stale because phase 06 commits (e.g. 36fc981) edited README.md (one table row, benchmark figures)

## Goal Achievement

Verified by running the real CLI (`bin/ruly`) in scratch dirs with an isolated HOME and a planted `mcp.json`, then `claude plugin validate --strict` on the output. Review fixes (WR-01 to WR-06, CR-01, CR-02) were included.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `squash demo -a claude-plugin -o DIR` writes `.claude-plugin/plugin.json` with name=recipe, version=0.4.0, description, author, `metadata.generator: ruly`; no new flag/command/recipe key | VERIFIED | plugin.json inspected; only the `-a`/`-o` help text changed in cli.rb, no new `option`/`desc` lines |
| 2 | Rules body is skill `skills/demo-rules/SKILL.md`; body equals the CLAUDE.local.md body | VERIFIED | Diff vs. a plain `squash demo` shows one line differing, the script path rewritten to `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh` (intended) |
| 3 | Every run (dry run included) prints the "cannot carry always-on instructions" notice naming `/demo:demo-rules` and `ruly squash demo` | VERIFIED | Seen in real and `--dry-run` output |
| 4 | Always-on question resolved with primary-source evidence and a NO verdict handled correctly | VERIFIED | 05-RESEARCH.md quotes the docs (plugin-root CLAUDE.md not loaded, SessionStart 10,000-char cap, force-for-plugin style, `agent` setting). Local validator warning cited. Output has no CLAUDE.md, SessionStart hook or output style. README records it |
| 5 | Nothing is written into the project (no `.claude/`, CLAUDE.local.md, .mcp.json, .mcp.yml); scripts go to `DIR/scripts/` | VERIFIED | Project dir listing after a real run is `.git .recipes.yml rules` only; `scripts/notify.sh` is mode 755 |
| 6 | Guards: refuses unowned non-empty dir, cwd, parent, HOME, `//`, `~`, file, and no recipe, all exit 1 with the dir untouched; dry run guarded too; owned dir rewritten | VERIFIED | Each scenario run and exited 1. Symlinked cwd refused (CR-01). Re-squash into an owned dir succeeds. Unowned `keep/f` intact |
| 7 | `clean RECIPE -a claude-plugin` removes only a ruly-owned dir and never `.claude/`; skips unowned dir | VERIFIED | `ok1/` removed; `keep/` skipped with a warning and left intact |
| 8 | `-i`/`-I` add `DIR/` to `.gitignore` / `.git/info/exclude`; `--dry-run` prints Would create, layout and script lines, writes nothing | VERIFIED | `ok2/` in .gitignore, `ok3/` in exclude; dry-run output and absent `dd` |
| 9 | `claude plugin validate --strict` passes on the full fixture plugin | VERIFIED | Read-only run: "Validation passed" |
| 10 | claude, cursor, claude `-t`, agents output byte-identical to the pre-phase base (c0895d7^) | VERIFIED | Differential on the agents_md fixture and claude on claude_plugin, 5 runs. Only `-t` anchors differ, because they embed the scratch dir name (d_old vs d_new). Timestamps excluded |
| 11 | Skills (nested flattened), commands, subagents (model kept; subagent skills in `skills/`) | VERIFIED | `skills/{deploy,review,tdd,demo-rules}`, `commands/ship.md`, `agents/helper.md` has `model: haiku` |
| 12 | Plugin agent frontmatter has no permissionMode/hooks/mcpServers; skills as `PLUGIN:skill` list | VERIFIED | helper.md has `skills: - demo:review`. Runtime resolution confirmed in a live `claude --plugin-dir` session (05-UAT.md test 1: helper reported `demo:review` preloaded, "# Review Skill") |
| 13 | Skill/command escape and `RECIPE-rules` collision stop with exit 1 before writing | VERIFIED | Subagent skill `demo-rules.md` gave "collides with the generated rules skill", exit 1, previous plugin byte-identical, no `.ruly-previous` leftover (CR-02, WR-01). Unsafe subagent name `../../esc` refused for plugin and claude targets (WR-06) |
| 14 | `hooks/hooks.json` has top-level `hooks` and the script ref rewritten to `"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"` | VERIFIED | hooks.json inspected |
| 15 | `.mcp.json` from `~/.config/ruly/mcp.json`; literal secrets named (not printed) on stderr, also under `-W0` | VERIFIED | Warning names `grafana`; the `glsa_` token value is not in any output. Notice present under `RUBYOPT=-W0` |
| 16 | Skipped-parts notice by key only; README section complete; `ruly version` is v0.4.0; `help squash` lists claude-plugin; 8 commands | VERIFIED | `claude-plugin target skips: subagent permissionMode`; README section at line 778; CHANGELOG and version.rb updated |
| 17 | Phase gates: no new rspec failures; no new RuboCop offenses | VERIFIED | rspec 773 examples, 15 failures, 1 pending. Failure descriptions are a subset of the baseline (nothing new). RuboCop on the touched files: 1 offense, the pre-existing `Obsession/MethodOrder` in cli.rb. spec/bench did not interfere |

**Score:** 17/17 truths verified (0 behavior-unverified).

**Re-verification evidence (2026-11-02):** `git diff 4163185 HEAD -- README.md lib spec CHANGELOG.md` shows the only change to covered files is one README table row (benchmark figures in the "Token cost of includes" row); `lib/` and the phase 05 specs are unchanged. The README "Claude Code Plugin Output" section (line 778) is intact, including "Rules are not always-on. Plugins cannot carry always-on instructions" with its four reasons. `bundle exec rspec` on the three plugin specs: 196 examples, 0 failures. A fresh e2e `squash demo -a claude-plugin -o out` wrote plugin.json (name demo, version 0.4.0, metadata.generator ruly) and `skills/demo-rules/SKILL.md`, printed the always-on notice, wrote nothing outside `out/`, and `claude plugin validate out --strict` passed.

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No change to claude/cursor/agents output | PASS | Differential gate (truth 10) |
| No writes to project `.claude/`, CLAUDE.local.md, .mcp.* | PASS | Project listing after a real run |
| No wipe of unowned dir, cwd, parents, HOME | PASS | Guard scenarios (truth 6) |
| No CLAUDE.md, SessionStart hook or output style in plugin | PASS | File listing; the only mentions in claude_plugin.rb are comments |
| No plugin.json component keys | PASS | plugin.json holds only name, version, description, author, metadata |
| No new command, flag, recipe key | PASS | cli.rb diff has only the `-a`/`-o` help text changes |
| No `rubocop:disable` for ClassLength; ClassLength under 500 | PASS | No disable lines in the cli.rb diff; 484/500 per REVIEW-FIX |
| No `gem install`; Gemfile.lock not staged | PASS | Gemfile.lock is absent from the c0895d7^..HEAD diff; it is modified in the working tree only |
| README sections Why ruly / Ruly vs. native / AGENTS.md Output untouched | PASS | Headings present; the README diff has no removed lines |
| No MCPManager/SettingsManager modification (05-02) | INFO | `MCPManager.merge_recipe_servers` was added by the post-review refactor (6b0980e). Pure move of `CLI#merge_mcp_servers`, behavior unchanged, and the differential gate is clean. Not treated as a failure |
| Judgment-tier prohibitions (ADR-550) | None declared | |

### Requirements Coverage

No requirement IDs for this phase (ROADMAP: TBD; plans declare `requirements: []`). Nothing orphaned.

### Anti-Patterns Found

No unreferenced TBD/FIXME/XXX debt markers or stubs found in the touched lib files by inspection of the implementation and by the e2e runs.

### Human Verification Required

None outstanding. 05-UAT.md (3/3 passed, 2026-11-02): (1) A3, namespaced skill preloading works in a live session; (2) WR-03 trade-off accepted by the user; (3) WR-04 heuristic false positives accepted by the user.

### Gaps Summary

No gaps. The goal is achieved: `-a claude-plugin` produces a strict-valid native plugin with skills, commands, agents, hooks, `.mcp.json` and scripts. The always-on question is settled (plugins cannot carry it) and handled with a rules skill, a runtime notice and a README record. WR-07 (manifest version pinned to the ruly version) was deliberately skipped and is documented in README and CHANGELOG as a known limitation, so it is not a gap. The global gem install is a post-merge step.

---

_Verified: 2026-11-02T18:20:00Z_
_Verifier: Claude (gsd-verifier)_
