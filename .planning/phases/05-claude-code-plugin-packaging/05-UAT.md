---
status: testing
phase: 05-claude-code-plugin-packaging
source: [05-VERIFICATION.md]
started: 2026-11-02T11:30:43Z
updated: 2026-11-02T11:30:43Z
---

## Current Test

number: 1
name: Namespaced preloaded skill resolves in a live plugin session (A3)
expected: |
  Generate the fixture plugin (spec/fixtures/claude_plugin) with `ruly squash demo -a claude-plugin -o ruly-plugin-demo`, start `claude --plugin-dir ruly-plugin-demo`, invoke the `helper` subagent and confirm its preloaded skill `demo:review` is available. If not, switch to bare names in SubagentProcessor.extract_skill_names and the README line.
awaiting: user response

## Tests

1. A3 namespaced preloaded skill `demo:review` resolves in a live session. (pending)
2. WR-03 trade-off sign-off: inside `sh -c '...'` hook commands the rewrite is a bare ${CLAUDE_PLUGIN_ROOT} (word-splits if the plugin path has spaces). Accept or request a change. (pending)
3. WR-04 heuristic sign-off: MCP secret warning may false-positive (e.g. `--no-auth` + literal); names servers only. Accept or tune. (pending)

## Summary

total: 3
passed: 0
issues: 0
pending: 3

## Gaps

None recorded yet.
