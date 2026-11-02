---
phase: 05-claude-code-plugin-packaging
plan: 02
subsystem: cli-output-targets
status: complete
tags: [claude-plugin, squash, hooks, mcp, subagents, skills]
requires:
  - phase: 05-claude-code-plugin-packaging
    provides: "05-01 ClaudePlugin service, plugin dir guard/marker, rules skill, scripts_dir: keyword"
provides:
  - "Plugin skills (flattened names), commands, subagent agents and subagent skills in the plugin dir"
  - "hooks/hooks.json with quoted ${CLAUDE_PLUGIN_ROOT} script paths; .mcp.json with literal-secret warning"
  - "Frontmatter scripts copied to DIR/scripts; .claude/scripts/X references rewritten in skills/commands/agents"
  - "Skipped-parts notice (model, isolate, subagent permissionMode, subagent cwd hooks)"
  - "ScriptManager.flat_skill_name, skills_dir:/commands_dir: keywords; SubagentProcessor plugin_dir: mode"
affects: [05-03]
tech-stack:
  added: []
  patterns:
    - "Plugin-mode switches behind one keyword (plugin_dir:, skills_dir:, commands_dir:); nil keeps claude output byte-identical"
    - "Script references rewritten only for scripts actually copied into DIR/scripts"
key-files:
  created:
    - spec/ruly/subagent_plugin_mode_spec.rb
  modified:
    - lib/ruly/services/claude_plugin.rb
    - lib/ruly/services/script_manager.rb
    - lib/ruly/services/subagent_processor.rb
    - lib/ruly/services/display.rb
    - lib/ruly/cli.rb
    - spec/ruly/claude_plugin_spec.rb
    - spec/ruly/cli_claude_plugin_spec.rb
decisions:
  - "Plugin agent skills: are a YAML list of namespaced PLUGIN:skill names [ASSUMED A3, post-run human check]"
  - "Nested skill names are flattened for the plugin only (tdd/SKILL -> tdd, git/commit -> git-commit); claude target keeps nested layout"
  - "Plugin agent frontmatter omits permissionMode, hooks and mcpServers; parent hooks/MCP ship via hooks/hooks.json and .mcp.json"
  - "Checks.run_all call factored into a one-line CLI#run_checks delegator (shared with the agents target) to keep cli.rb at ClassLength 498"
metrics:
  duration: "10 min"
  completed: 2026-11-02
estimate:
  tokens: 95000
  tasks: 2
actuals:
  tokens: 8900
  tasks: 2
  commits: 5
plan_head_before: da886f2816b37295e494d3f1fc5f2175201053d9
plan_head_after: ea6acd02c44d45e84bb981efd5f896564c027c72
---

# Phase 5 Plan 02: Claude Code Plugin Target (part 2) Summary

`ruly squash RECIPE -a claude-plugin` now writes a complete plugin. It has the recipe and subagent skills (flattened names), the commands, plugin-valid agent files, `hooks/hooks.json` with quoted `"${CLAUDE_PLUGIN_ROOT}/scripts/X"` commands, a `.mcp.json` that names literal-secret servers on stderr without printing their values, and every copied script reference rewritten to the plugin root. The full fixture plugin passes `claude plugin validate --strict`, and claude, cursor and agents output is byte-identical to the pre-phase base.

## Performance

- Started 2026-11-02T10:41:12Z, finished 2026-11-02T10:51:06Z (about 10 min)
- 2 tasks, 5 commits (2 RED, 2 GREEN, 1 fix)

## Measurements

| Item | Value |
|------|-------|
| cli.rb ClassLength | 489 at start, 500 mid-Task 1, **498** final (Max 500, no offense, no disable) |
| Strict validate gate | **RAN**: `claude plugin validate --strict` printed `✔ Validation passed` (claude 2.1.304) on the full fixture plugin |
| Full suite | 713 examples, 15 failures, 1 pending. All 15 are in 02-rspec-baseline.txt (0 new) |
| RuboCop per touched file | cli.rb 1/1, script_manager.rb 8/8, subagent_processor.rb 8/8, all others 0/0 |
| Differential gate | claude, cursor, claude -t, agents (agents_md) and claude (claude_plugin): byte-identical to base `c0895d7^` |
| MCPManager, SettingsManager, GitIgnoreManager, RecipeLoader | unchanged against base |
| `ruly help` commands | 8 |

## Task Commits

| Task | Name | Commit | Type |
|------|------|--------|------|
| 1 | RED: skills, commands, subagents, check_paths! specs | cf71d03 | test |
| 1 | GREEN: skills, commands and subagents into the plugin dir | 7eb98fe | feat |
| 2 | RED: hooks, MCP, scripts, skipped-notice specs | 7fa0b41 | test |
| 2 | GREEN: hooks.json, .mcp.json, scripts with plugin-root paths | 33b13ca | feat |
| 2 | Dry run names the plugin scripts dir | ea6acd0 | fix |

## TDD Gate Compliance

- Task 1: RED cf71d03 had 25 of 111 examples failing (missing `flat_skill_name`, `skills_dir:`, `commands_dir:`, `check_paths!`, plugin agent mode and plugin layout). GREEN 7eb98fe: 111 examples, 0 failures.
- Task 2: RED 7fa0b41 had 25 failures among the 29 new examples (undefined `hook_command`, `write_hooks`, `literal_secret_servers`, `write_mcp`, `rewrite_script_paths` and `skipped_parts`). The 2 examples that passed were invariant guards that already held. GREEN 33b13ca: 138 examples, 0 failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] cli.rb ClassLength budget**
- **Found during:** Task 1
- **Issue:** The planned wiring brought cli.rb to 500 before Task 2's three extra lines.
- **Fix:** Added a one-line `run_checks` delegator next to the existing endless delegators. `write_claude_plugin` and `write_agents_md` both call it. Arguments are identical, and the agents output is byte-identical (differential gate). `post_squash` is untouched.
- **Commit:** 7eb98fe

**2. [Rule 1 - Bug] 05-01 spec asserted an un-rewritten rules body**
- **Found during:** Task 2
- **Issue:** `writes the same rules body the claude target writes` compared the rules skill with CLAUDE.local.md verbatim. Plan 05-02 deliberately rewrites `.claude/scripts/notify.sh` to `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh` in that skill.
- **Fix:** The example now compares against the claude body with that one substitution.
- **Commit:** 33b13ca

**3. [Rule 1 - Bug] Dry run said `.claude/scripts/` for plugin frontmatter scripts**
- **Found during:** after Task 2 (noted as open in 05-01 SUMMARY)
- **Issue:** Frontmatter scripts now go to `DIR/scripts`, but `Display.dry_run_scripts` printed `.claude/scripts/`.
- **Fix:** Added a `scripts_dir:` keyword (default `.claude/scripts`) fed by the existing plugin `scripts_dir`. Output for the other targets is unchanged. 2 unit examples.
- **Files modified:** lib/ruly/services/display.rb, spec/ruly/claude_plugin_spec.rb
- **Commit:** ea6acd0

**4. [Rule 2 - Security] `..` segments in hook script references**
- **Found during:** Task 2
- **Issue:** `File.file?(DIR/scripts/X)` alone would accept `X = ../../something`.
- **Fix:** `copied_script?` rejects any X with a `..` segment.
- **Commit:** 33b13ca

### Notes

- `write_mcp` runs `mkdir_p(dir)` before writing. This matters only for direct unit calls, because the CLI has already reset the dir.
- The script-reference regex requires X to end in a word character, so a sentence-ending `.` after a path is not captured.

## Human verification (post-run)

1. **A3, namespaced preloaded skills (non-blocking):** in a scratch dir with a generated fixture plugin, run `claude --plugin-dir ruly-plugin-demo` and open `/agents`. Confirm that `demo:helper` is listed. Then ask Claude to run the helper subagent and report whether the `Review Skill` content was preloaded. If it was not, switch the plugin-mode names in `SubagentProcessor.extract_skill_names` to bare names (a one-line change) and re-check. **Status: not run** (unattended; plugin installs and Claude sessions were out of scope).
2. Strict validate gate: **ran and passed**. No human action is needed.
3. Final cli.rb ClassLength: **498**.

## Known Stubs

None.

## Threat Flags

None. All new surface (hook commands, `.mcp.json` copy, skill and command paths) is covered by T-05-08 to T-05-13.

## Self-Check: PASSED

- FOUND: spec/ruly/subagent_plugin_mode_spec.rb, lib/ruly/services/claude_plugin.rb (`def write_hooks`), lib/ruly/services/script_manager.rb (`def flat_skill_name`), lib/ruly/services/subagent_processor.rb (`plugin_dir`)
- FOUND commits: cf71d03, 7eb98fe, 7fa0b41, 33b13ca, ea6acd0 (all ancestors of HEAD)
