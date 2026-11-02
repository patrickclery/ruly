---
phase: "02"
slug: "lean-out-native-duplication"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-02"
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| shell argv -> Thor parser/dispatcher | Untrusted switches and command names select code paths, including deletion in `clean` | CLI arguments |
| CLI -> working-directory filesystem | `clean` deletes paths; `squash` writes output files in cwd | generated files |
| synced/remote recipes.yml -> RecipeLoader | Recipe YAML may come from a mirrored repo the user does not fully control | recipe config (may hold paths/tokens) |
| CLI -> `.mcp.json` in cwd | Squash writes MCP server definitions | MCP config (may hold secrets) |
| docs -> user shell | Users copy README commands into their shell | shell commands |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-01 | Tampering | `collect_files_to_clean` (lib/ruly/cli.rb) | medium | mitigate | No `.taskmaster` reference left in cli.rb; spec/ruly/cli_removed_options_spec.rb asserts deepclean never lists it | closed |
| T-02-02 | Tampering | Thor option parsing | low | mitigate | `check_unknown_options!` at lib/ruly/cli.rb:17 | closed |
| T-02-03 | Denial of Service | `squash -a sgpt -o role.json` | low | accept | Output is markdown; documented in CHANGELOG 0.2.0 | closed |
| T-02-04 | Tampering | analyzer.rb `YAML.load_file` | medium | mitigate | analyzer.rb and contexts.yml deleted; `git grep YAML.load_file -- lib` empty | closed |
| T-02-05 | Information Disclosure | `RecipeLoader.recipe_key_warnings` | low | mitigate | Messages name recipe + key only; spec/ruly/recipe_key_warnings_spec.rb asserts values absent | closed |
| T-02-06 | Denial of Service | recipe-key warning loop | low | accept | Bounded by keys per recipe | closed |
| T-02-07 | Information Disclosure | `.mcp.json` writer | low | accept | Removing `mcp` command removes a writer; recipe path unchanged | closed |
| T-02-08 | Tampering | README.md command examples | low | mitigate | No `ruly import/mcp/analyze`, `--cache`, or taskmaster examples remain in README.md | closed |
| T-02-09 | Repudiation | CHANGELOG.md / AUDIT.md | low | mitigate | CHANGELOG `[0.2.0] - 2026-11-02`; AUDIT.md cites decision IDs per removal | closed |
| T-02-SC | Tampering | package installs | low | accept | No packages or dependencies added | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-02-01 | T-02-03 | Hard removal of shell_gpt JSON output per D-09/D-13; user names the output file | plan 02-01 (planner) | 2026-11-02 |
| AR-02-02 | T-02-06 | Loop bounded by recipe key count | plan 02-02 (planner) | 2026-11-02 |
| AR-02-03 | T-02-07 | Pre-existing `.mcp.json` secret exposure (CONCERNS.md), not worsened | plan 02-02 (planner) | 2026-11-02 |
| AR-02-04 | T-02-SC | No dependency changes | planner | 2026-11-02 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-02 | 10 | 10 | 0 | secure-phase orchestrator (L1 grep verification; auditor skipped per short-circuit: plan-time register, ASVS 1, 0 open) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-02
