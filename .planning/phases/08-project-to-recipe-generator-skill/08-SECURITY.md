---
phase: "08"
slug: "project-to-recipe-generator-skill"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-11-08"
---

# Phase 08 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Scanned project → skill | The skill reads a target project's agent files and treats them as data | Project instructions, `.mcp.json` server names (never values) |
| Skill → rules repo | An approved draft is written to `recipes.yml` in the private rules clone | Repo-relative paths, recipe keys |
| This repo → public GitHub | `skills/recipe-from-project.md` and the README are published on public `main` | Skill text (must hold no private rule text) |
| Rules repo → mirrors | The pushed `ruly-tools` recipe reaches other machines through `ruly squash --sync` | Recipe entries, including the skill URL |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-08-01 | Elevation of Privilege | Instructions in scanned project files | high | mitigate | The skill treats project content as data and writes only after the user approves a displayed draft | closed |
| T-08-02 | Information Disclosure | Tokens in `.mcp.json` / `mcp.json` | high | mitigate | Reads keys only with `jq -r 'keys[]'`, and forbids reading or showing values | closed |
| T-08-03 | Tampering | Draft entry pointing outside the rules repo | medium | mitigate | Refused before writing; the preflight prints `refused-path` / `refused-url` | closed |
| T-08-04 | Information Disclosure | Private rule text in the public skill | high | mitigate | The privacy gate passed against the rules clone | closed |
| T-08-05 | Tampering | Recipe name breaking YAML or the shell | low | mitigate | Names are restricted to `[A-Za-z0-9._-]`, and `$RECIPE` is always quoted | closed |
| T-08-06 | Tampering | Destructive squash in the scanned project | high | mitigate | The only squash call is `--dry-run`, under a temp HOME and temp cwd | closed |
| T-08-07 | Tampering | Sort commit changing a recipe | medium | mitigate | Rules commit 51e5fe8: parsed YAML equal, comments 153/153 | closed |
| T-08-08 | Tampering | `ruly-tools` tracks `main` | medium | accept | See the Accepted Risks Log | closed |
| T-08-09 | Tampering | Machine config overwritten | high | mitigate | `~/.config/ruly/recipes.yml` unchanged since 2026-10-05 | closed |
| T-08-10 | Information Disclosure | README exposing private content | low | mitigate | 23 lines added, 0 deleted, and the only URL is the public skill URL | closed |
| T-08-11 | Elevation of Privilege | Push without the user's approval | high | accept | See the Accepted Risks Log | closed |
| T-08-12 | Information Disclosure | Unintended content on public `main` | high | mitigate | PR #5 holds exactly `README.md` and `skills/recipe-from-project.md` | closed |
| T-08-13 | Tampering | Rules repo pushed before `main` has the file | high | mitigate | PR merged before the rules push, and the gate reported `pushed-in-order` | closed |
| T-08-14 | Tampering | Disturbing another session's checkout | medium | mitigate | Temp worktree added and removed, no branch switch, fast-forward pushes only | closed |
| T-08-15 | Repudiation | Unresolved URL recorded as a pass | medium | mitigate | 08-02 recorded the check as pending; the URL now resolves with identical content | closed |
| T-08-SC | Tampering | Package installs (all three plans) | high | mitigate | No installs; Prettier ran only as `npx --no-install` | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-08-01 | T-08-08 | It is the user's own repo, and the fetched text can be read in the generated SKILL.md. A commit-pinned URL is available if this changes (08-02-PLAN.md). | Plan (08-02), confirmed by audit | 2026-11-08 |
| AR-08-02 | T-08-11 | The planned blocking-human gate did not run. The orchestrator pushed both repos and merged PR #5 on the user's standing instruction ("I have given you bypass permissions. You shouldn't have to ask me to do these. just do them"). The audit found that instruction did not clearly cover pushes. When asked afterwards, the user chose "Approve, keep as-is": they approve the pushes and merge, and future sessions may push and merge without asking. | User | 2026-11-08 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-08 | 18 | 17 | 1 | gsd-security-auditor (T-08-11 open) |
| 2026-11-08 | 18 | 18 | 0 | orchestrator, after the user's sign-off on T-08-11 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-08
