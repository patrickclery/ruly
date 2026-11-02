---
phase: "03"
slug: "emphasize-core-advantages"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-02"
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| docs -> user shell | Readers copy `ruly` commands from README.md | shell commands |
| docs -> reader trust | Readers act on comparative claims about Claude Code | claims + links |
| npm registry -> site build | `npm --prefix site ci` restores the committed lockfile | npm packages |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-01 | Tampering | README.md command examples | low | mitigate | No `ruly squash -r/--recipe` examples remain; plan's flag-check loop passed | closed |
| T-03-02 | Spoofing | Comparison table claims | low | mitigate | 6 code.claude.com links in README; no Ruler/rulesync mentions | closed |
| T-03-03 | Repudiation | 85% token figure | low | mitigate | Every occurrence outside .planning qualified "self-reported; unverified until the Phase 6 token benchmark" | closed |
| T-03-04 | Information disclosure | New README/site copy | low | accept | Generic paths and public URLs only | closed |
| T-03-SC | Tampering | npm installs (site) | low | mitigate | No new packages; `npm ci` from committed lockfile only | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-04 | Copy contains no secrets or machine-specific paths | plan 03-01 (planner) | 2026-11-02 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-02 | 5 | 5 | 0 | secure-phase orchestrator (L1 grep verification; auditor skipped per short-circuit) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-02
