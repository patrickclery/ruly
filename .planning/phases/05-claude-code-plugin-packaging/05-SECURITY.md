---
phase: "05"
slug: "claude-code-plugin-packaging"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-02"
---

# Phase 05 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| CLI -> filesystem | `-a claude-plugin` writes/replaces a plugin dir; clean deletes it | generated plugin tree |
| recipe sources (possibly synced from GitHub) -> plugin | Names, skills, subagents, hooks become paths and JSON | untrusted names/paths |
| ~/.config/ruly/mcp.json -> shareable plugin | MCP server config copied into `.mcp.json` | possible credentials |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-05-01 | Tampering | Overwriting unowned dir | high | mitigate | `guard_dir!` marker check; re-guard before rm | closed |
| T-05-02 | Tampering | `-o` cwd/parents/HOME/root | high | mitigate | Real-path comparison (CR-01 fix df948f7) incl. symlinks, `//`, `~user` | closed |
| T-05-03 | Tampering | Unsafe/reserved plugin names | medium | mitigate | Anchored NAME_PATTERN, no `..`, reserved names | closed |
| T-05-04 | Tampering | Clean deleting project files | high | mitigate | Marker-gated `files_to_clean`; same real-path guard | closed |
| T-05-05 | Tampering | Writes into project | medium | mitigate | Plugin writer bypasses project writers | closed |
| T-05-06 | Information Disclosure | author from git config | low | accept | Omitted when unset; README notes it | closed |
| T-05-07 | Spoofing | Hand-added marker | low | accept | Documented | closed |
| T-05-08 | Information Disclosure | Literal secrets in .mcp.json | high | mitigate | Names-only warning for env/headers/args/url (WR-04 a821f06); values never printed; notices via $stderr (WR-05) | closed |
| T-05-09 | Tampering | Skill/command path escape | medium | mitigate | `check_paths!` before writes | closed |
| T-05-10 | Elevation of Privilege | permissionMode in plugin agents | low | mitigate | Dropped for plugin agents | closed |
| T-05-11 | Tampering | Hook command quoting | low | mitigate | Quote-aware rewrite (WR-03 b6405cb) | closed |
| T-05-12 | Repudiation | Skipped parts | low | mitigate | Names-only notice incl. dry run | closed |
| T-05-13 | Tampering | Rules skill overwritten by subagent skill | medium | mitigate | Subagent skills name-checked before write (CR-02 c06bc53) | closed |
| T-05-14 | Information Disclosure | Committing secrets | medium | mitigate | README guidance; `-i`/`-I` | closed |
| T-05-15 | Spoofing | Always-on expectation | low | mitigate | README + runtime notice | closed |
| T-05-16 | Tampering | Gem artifacts/install | low | mitigate | Temp-dir build only; no install | closed |
| T-05-SC | Tampering | Dependencies | low | accept | stdlib only; no manifest changes | closed |
| T-05-UF1 | Tampering | Subagent `name:` path traversal (unregistered, found in audit; also claude target) | medium | mitigate | NAME_PATTERN validation before writes for all targets except agents (WR-06 3f18772) | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-05-01 | T-05-06 | git user.name is the user's own public identity; omitted when unset | plan 05-01 (planner) | 2026-11-02 |
| AR-05-02 | T-05-07 | Adding the marker deliberately hands the dir to ruly | plan 05-01 (planner) | 2026-11-02 |
| AR-05-03 | T-05-SC | No dependency changes | planner | 2026-11-02 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-02 | 17 (+1 unregistered) | 16 | 1 medium (non-blocking) | gsd-security-auditor (OPEN_THREATS, threats_open 0) |
| 2026-11-02 | 18 | 18 | 0 | orchestrator after code-review fixes (05-REVIEW-FIX.md: df948f7, c06bc53, a821f06, 831114c, b6405cb, 3f18772) |

Informational (not threats): `--deepclean` with `-a claude-plugin` keeps its documented meaning; malformed mcp.json parse errors echo a snippet (shared code, pre-existing).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-02
