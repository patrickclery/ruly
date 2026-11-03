---
phase: "06"
slug: "token-and-compliance-benchmark"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-02"
---

# Phase 06 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| private rules corpus -> bench results | Real-repo runs must never land in committed results | rule text, paths |
| harness -> `claude -p` (live, opt-in) | Paid API calls with workspace contents | prompts, rule bodies, API key |
| bench -> subprocesses | `bin/ruly squash` and `claude` invocations | recipe/model names |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-06-01 | Information Disclosure | Token output dir | high | mitigate | OutputDir guard (symlink-resolved); private → bench/results/local (gitignored) or outside repo (WR-04 afadcf1) | closed |
| T-06-02 | Elevation of Privilege | SquashRunner | medium | mitigate | Recipe-name regex; argv-only Open3 | closed |
| T-06-03 | Tampering | SquashRunner env | medium | mitigate | Temp HOME/RULY_HOME + temp corpus copy | closed |
| T-06-04 | Repudiation | Fixture labeling | medium | mitigate | tokens.md H1 + "not a real repository" note | closed |
| T-06-05 | Information Disclosure | Live mode | high | mitigate | Dry-run default; `--allow-private-corpus`; output guard | closed |
| T-06-06 | Denial of Service | Cost | medium | mitigate | ≤10 tasks; `--max-budget-usd` (>=$0.01); worst-case line first | closed |
| T-06-07 | Elevation of Privilege | claude exec | medium | mitigate | Model regex; argv-only; prompt on stdin | closed |
| T-06-08 | Information Disclosure | API key | high | mitigate | Presence check only; never copied/written; spec asserts | closed |
| T-06-09 | Tampering | Live workspace | low | mitigate | `--tools Skill`, `--strict-mcp-config`, no session persistence (WR-06 5f5ae7a); stale `.claude/` excluded (WR-07) | closed |
| T-06-10 | Repudiation | Accidental spend | medium | mitigate | Tripwire-verified zero calls in dry run/specs | closed |
| T-06-11 | Repudiation | Published figures | medium | mitigate | Figures regenerated after CR-01; published_figures_spec ties docs/README/patterns note to tokens.json | closed |
| T-06-12 | Information Disclosure | Docs | medium | mitigate | Compliance "pending"; no paths/keys in docs/results | closed |
| T-06-13 | Tampering | Shared README | low | mitigate | Single-line Ruly cell change | closed |
| T-06-SC | Tampering | Installs | low | accept | No dependency/manifest changes | closed |

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-06-01 | T-06-SC | No dependency changes in phase 06 | planner | 2026-11-02 |

Informational (auditor): private-corpus live runs with recipe hooks/MCP would add `.claude/settings.local.json` to the ruly workspace; mitigated in practice by `--strict-mcp-config` and explicit `--allow-private-corpus`; hooks remain a consideration for private live runs.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-02 | 14 | 14 | 0 | gsd-security-auditor (SECURED, ASVS L1, tripwire-verified) |
| 2026-11-02 | 14 | 14 | 0 | orchestrator after review fixes (06-REVIEW-FIX.md) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-02
