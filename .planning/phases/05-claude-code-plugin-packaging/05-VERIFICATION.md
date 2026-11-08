---
phase: 05-claude-code-plugin-packaging
verified: 2026-11-08T12:00:00Z
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
covered_digest: "v3:sha256:0850ab692ec2861d2ecc49a4b5f7fb7e19f16fa256877b19cb58a64106f14aa2"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 17/17
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 5: Claude Code Plugin Packaging Verification Report

**Phase Goal:** Package squashed recipe output as a Claude Code plugin (skills/, commands/, agents/, hooks, .mcp.json) so distribution uses the native format instead of ruly-specific file writing; resolve whether plugins can carry always-on instructions.
**Verified:** 2026-11-08
**Status:** passed (all automated checks pass; human UAT 3/3 passed, see 05-UAT.md)
**Re-verification:** Yes. The prior report went stale only because README.md changed after it ran: phase 08 (PRs #5 and #6) added the recipe-from-project lines and the "Available Ruly Commands" bullet.

## Goal Achievement

### Re-verification evidence (2026-11-08)

- `git diff 4163185 HEAD -- lib spec/ruly CHANGELOG.md` is empty. The implementation, the phase 05 specs and the CHANGELOG are unchanged since the original verification. The working tree has no uncommitted changes to `lib/`, `spec/`, `README.md` or `CHANGELOG.md`.
- The only README changes since 4163185 are: the phase 06 "Token cost of includes" table row (already covered by the previous re-verification), and the phase 08 additions (the `/recipe-from-project` bullet under "Available Ruly Commands", the "Drafting a Recipe From a Project" subsection with the `ruly-tools` recipe snippet, and the warning not to squash `ruly-tools` inside the scanned project). None touch the plugin content.
- README "Claude Code Plugin Output" section (line 778) is intact and unchanged: it still states "Rules are not always-on. Plugins cannot carry always-on instructions" with the four reasons, the `RECIPE-rules` skill, the version known limitation (WR-07), and the safety, MCP-secret and script-path rules. The cross-links at lines 202, 855 and 864 and the CLI example at 949 are intact. The new phase 08 text makes no claim about `-a claude-plugin`.
- `bundle exec rspec` on the three plugin specs: 196 examples, 0 failures. RuboCop on `claude_plugin.rb`: no offenses.
- Fresh e2e with an isolated HOME: `squash demo -a claude-plugin -o out` wrote exactly `.claude-plugin/plugin.json` (name demo, version 0.4.0, metadata.generator ruly) and `skills/demo-rules/SKILL.md`, printed the always-on notice naming `/demo:demo-rules` and `ruly squash demo`, wrote nothing else into the project (`.git .recipes.yml out rules`), and `claude plugin validate out --strict` printed "Validation passed".
- Guards: squashing into an unowned non-empty `keep/` exited 1 and left `keep/f` intact; `clean demo -a claude-plugin -o keep` skipped it with a warning; `clean ... -o out` removed only `out/`.
- `ruly help squash` lists claude-plugin; `ruly help` shows 8 commands; `version.rb` is 0.4.0.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `squash demo -a claude-plugin -o DIR` writes `.claude-plugin/plugin.json` with name=recipe, version=0.4.0, description, author, `metadata.generator: ruly`; no new flag/command/recipe key | VERIFIED | plugin.json inspected in the fresh run; lib unchanged since the prior full check, which found only `-a`/`-o` help text changed in cli.rb |
| 2 | Rules body is skill `skills/demo-rules/SKILL.md`; body equals the CLAUDE.local.md body | VERIFIED | File present in the fresh run; lib unchanged; the prior diff showed only the script path rewrite differing (intended) |
| 3 | Every run (dry run included) prints the "cannot carry always-on instructions" notice naming `/demo:demo-rules` and `ruly squash demo` | VERIFIED | Notice printed verbatim in the fresh run; covered by the specs (196 pass) for the dry-run case |
| 4 | Always-on question resolved with primary-source evidence and a NO verdict handled correctly | VERIFIED | 05-RESEARCH.md quotes the docs; the output has no CLAUDE.md, SessionStart hook or output style; README lines 806-812 record the verdict and are intact after the phase 08 edit |
| 5 | Nothing is written into the project (no `.claude/`, CLAUDE.local.md, .mcp.json, .mcp.yml); scripts go to `DIR/scripts/` | VERIFIED | Project listing after the fresh run is `.git .recipes.yml out rules`; script-mode behavior unchanged and spec-covered |
| 6 | Guards: refuses unowned non-empty dir, cwd, parent, HOME, `//`, `~`, file, and no recipe, all exit 1 with the dir untouched; dry run guarded too; owned dir rewritten | VERIFIED | Unowned dir: exit 1, `keep/f` intact (fresh run); remaining scenarios unchanged in lib and covered by cli_claude_plugin_spec (0 failures) |
| 7 | `clean RECIPE -a claude-plugin` removes only a ruly-owned dir and never `.claude/`; skips unowned dir | VERIFIED | Fresh run: `out/` removed, `keep/` skipped with a warning and left intact |
| 8 | `-i`/`-I` add `DIR/` to `.gitignore` / `.git/info/exclude`; `--dry-run` prints Would create, layout and script lines, writes nothing | VERIFIED | lib unchanged; spec-covered (0 failures); prior e2e confirmed |
| 9 | `claude plugin validate --strict` passes on the full fixture plugin | VERIFIED | Passed on the fresh minimal plugin; the prior run passed on the full fixture and the generating code is unchanged |
| 10 | claude, cursor, claude `-t`, agents output byte-identical to the pre-phase base (c0895d7^) | VERIFIED | lib unchanged since the prior differential run (clean apart from `-t` anchors that embed the scratch dir name) |
| 11 | Skills (nested flattened), commands, subagents (model kept; subagent skills in `skills/`) | VERIFIED | Unchanged code; subagent_plugin_mode_spec and claude_plugin_spec pass |
| 12 | Plugin agent frontmatter has no permissionMode/hooks/mcpServers; skills as `PLUGIN:skill` list | VERIFIED | Spec-covered; runtime resolution confirmed in a live session (05-UAT.md test 1: helper reported `demo:review` preloaded) |
| 13 | Skill/command escape and `RECIPE-rules` collision stop with exit 1 before writing | VERIFIED | Unchanged code (CR-02, WR-01, WR-06); spec-covered |
| 14 | `hooks/hooks.json` has top-level `hooks` and the script ref rewritten to `"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"` | VERIFIED | Unchanged code; spec-covered |
| 15 | `.mcp.json` from `~/.config/ruly/mcp.json`; literal secrets named (not printed) on stderr, also under `-W0` | VERIFIED | Unchanged code; spec-covered; prior e2e showed the token value absent from all output |
| 16 | Skipped-parts notice by key only; README section complete; `ruly version` is v0.4.0; `help squash` lists claude-plugin; 8 commands | VERIFIED | `help squash` mentions claude-plugin, `ruly help` lists 8 commands, VERSION 0.4.0, README section at line 778 intact and complete |
| 17 | Phase gates: no new rspec failures; no new RuboCop offenses | VERIFIED | Plugin specs 196/0 failures; RuboCop clean on claude_plugin.rb. lib and spec/ruly have no diff since the prior full-suite comparison (773 examples, 15 failures, all in the baseline) |

**Score:** 17/17 truths verified (0 behavior-unverified).

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No change to claude/cursor/agents output | PASS | lib unchanged since the differential gate (truth 10) |
| No writes to project `.claude/`, CLAUDE.local.md, .mcp.* | PASS | Project listing after the fresh run |
| No wipe of unowned dir, cwd, parents, HOME | PASS | Guard scenario (truth 6) |
| No CLAUDE.md, SessionStart hook or output style in plugin | PASS | File listing of the fresh plugin |
| No plugin.json component keys | PASS | plugin.json holds only name, version, description, author, metadata |
| No new command, flag, recipe key | PASS | lib unchanged |
| No `rubocop:disable` for ClassLength; ClassLength under 500 | PASS | Unchanged since the prior check |
| No `gem install`; Gemfile.lock not staged | PASS | Gemfile.lock is modified in the working tree only, not part of the phase |
| README sections Why ruly / Ruly vs. native / AGENTS.md Output untouched | PASS | The phase 05 README diff had no removed lines; later edits (06, 08) did not alter the plugin section |
| No MCPManager/SettingsManager modification (05-02) | INFO | `MCPManager.merge_recipe_servers` was added by the post-review refactor (6b0980e), a pure move; unchanged since |
| Judgment-tier prohibitions (ADR-550) | None declared | |

### Requirements Coverage

No requirement IDs for this phase (ROADMAP: TBD; plans declare `requirements: []`). REQUIREMENTS.md maps nothing to Phase 5, so nothing is orphaned.

### Anti-Patterns Found

No TBD/FIXME/XXX markers in `claude_plugin.rb`; no stubs found in the touched lib files.

### Human Verification Required

None outstanding. 05-UAT.md (3/3 passed, 2026-11-02): (1) A3, namespaced skill preloading works in a live session; (2) WR-03 trade-off accepted by the user; (3) WR-04 heuristic false positives accepted by the user. The phase 08 README change does not affect these, so they are kept as they were.

### Gaps Summary

No gaps. The goal is achieved: `-a claude-plugin` produces a strict-valid native plugin with skills, commands, agents, hooks, `.mcp.json` and scripts. The always-on question is settled (plugins cannot carry it) and handled with a rules skill, a runtime notice and a README record. WR-07 (manifest version pinned to the ruly version) was deliberately skipped and is documented in README and CHANGELOG as a known limitation, so it is not a gap.

---

_Verified: 2026-11-08T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
