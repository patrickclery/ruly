---
phase: "04"
slug: "agents-md-output-target"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-02"
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| CLI -> working-directory filesystem | `squash -a agents` writes AGENTS.md; `clean -a agents` deletes it | generated/hand-written files |
| recipe sources -> AGENTS.md | Squashed rule bodies and skills land in a commonly-committed file | rule content (may be private) |
| repo -> gem build | `gem build` packages the release | gem artifact |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-04-01 | Tampering | squash overwrite of hand-written AGENTS.md | high | mitigate | `guard_agents_md_output!` (cli.rb:293-299, called :68 before prepare_output and dry-run); specs in cli_agents_md_spec.rb | closed |
| T-04-02 | Tampering | `clean -a agents` deleting hand-written AGENTS.md | high | mitigate | Marker-gated `agents_md_files_to_clean` (cli.rb:508-514); `AgentsMd.generated?` reads line 1 only | closed |
| T-04-03 | Tampering | `clean -a agents` touching .claude/.mcp/CLAUDE.local.md | medium | mitigate | Early return for agents target (cli.rb:490); spec asserts survivors | closed |
| T-04-04 | Information Disclosure | AGENTS.md committed accidentally | medium | mitigate | `-i`/`-I` add AGENTS.md via GitIgnoreManager; specs | closed |
| T-04-05 | Information Disclosure | skipped-parts notice | low | mitigate | Names/counts only (agents_md.rb:120-145); spec asserts values absent | closed |
| T-04-06 | Spoofing | user-added ruly header on hand-written file | low | accept | Documented README.md:724 | closed |
| T-04-07 | Tampering | `-o` arbitrary path | low | accept | Behavior unchanged; guard still applies | closed |
| T-04-08 | Information Disclosure | private rules in committed AGENTS.md | medium | mitigate | README.md:725-726 guidance | closed |
| T-04-09 | Tampering | gem build artifacts / global install | low | mitigate | Temp-dir build only; no .gem tracked; no gem install run | closed |
| T-04-10 | Repudiation | release version consistency | low | mitigate | 0.3.0 consistent across version.rb, gemspec, CHANGELOG, bin, built gem | closed |
| T-04-SC | Tampering | dependencies | low | accept | No runtime dependency changes | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-01 | T-04-06 | Adding the ruly header deliberately hands the file to ruly; documented | plan 04-01 (planner) | 2026-11-02 |
| AR-04-02 | T-04-07 | `-o` semantics unchanged from prior releases | plan 04-01 (planner) | 2026-11-02 |
| AR-04-03 | T-04-SC | No dependency changes | planner | 2026-11-02 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-02 | 11 | 11 | 0 | gsd-security-auditor (SECURED, ASVS L1; includes scratch-dir runtime checks) |

Informational: pre-existing `-t` TOC anchors embed absolute paths (deferred-items.md) — relevant if a committed AGENTS.md is generated with `-t`.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-02
