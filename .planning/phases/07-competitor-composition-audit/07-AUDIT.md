# Phase 7: Competitor Composition Audit

**Audited:** 2026-11-02

**Question:** Can Ruler or rulesync select rules per task the way ruly recipes plus `requires:` do?

## Answer

Neither Ruler nor rulesync has named rule sets or profiles, includes between rule files with transitive resolution, or include-cycle detection, so recipes plus `requires:` remain ruly's main difference. Two earlier claims do not hold: both rivals set a model per subagent, and rulesync has shared sources with a SHA lockfile and overlays. Ruly is far behind on agent coverage (3 targets against 32 for Ruler and 69 for rulesync).

## Pinned evidence baseline

| Project  | Repo                    | Commit inspected                           | Commit date | Latest release       |
| -------- | ----------------------- | ------------------------------------------ | ----------- | -------------------- |
| Ruler    | `intellectronica/ruler` | `5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87` | 2026-10-27  | v0.3.46 (2026-10-22) |
| rulesync | `dyoshikawa/rulesync`   | `6e3869d378066dc2f0b4cda3896e444ae7f200a7` | 2026-11-02  | v43.4.2 (2026-11-01) |
| ruly     | this repo               | `4e859914ea87025b8d4d378f8752da7cf42c084b` | 2026-11-02  | 0.3.0                |

Ruly citations are repo-relative `path:line`, reproducible with `git show 4e85991:<path>`.

## Method

- **Evidence (D-01):** docs AND source of each rival, read at the pinned SHAs with read-only `gh api -H 'Accept: application/vnd.github.raw' "repos/<owner>/<repo>/contents/<path>?ref=<SHA>"` and raw reads. Every rival link below is pinned to `/blob/<SHA>/` or `/tree/<SHA>`.
- **Method limitation (D-02):** the planned `npx` run of each tool against a fixture was dropped by orchestrator override, because executing third-party code is not permitted in this run. No third-party code was executed. Runtime behavior that could only be inferred from code and docs is marked "inferred".
- **Verdict legend:** **yes** (feature present, read in source or docs), **partial** (covers part of the capability), **no** (absent), **unverified** (not established either way). "Inferred" means the conclusion follows from the code and docs read, but the behavior was not executed.
- **Absence verdicts:** Ruler's config schema is `.strict()`, so an unknown key such as `profiles` is rejected. rulesync's schemas are non-strict, so a rulesync "no" means "no such field exists in the schema or processor", not "rejected".
- **Scope:** vibe-rules is out of scope (D-07, discretion item not covered). Interop (handing AGENTS.md to Ruler or rulesync for fan-out) is deferred to a future milestone.

## Capability matrix

| #   | Capability                                     | Ruler @5e551e6 | rulesync @6e3869d | ruly 0.3.0 @4e85991 |
| --- | ---------------------------------------------- | -------------- | ----------------- | ------------------- |
| 3   | Include/require between rule files, transitive | **no**         | **no**            | **yes**             |

## Evidence

### 3. Include/require with transitive resolution

- **Ruler: no.** `concatenateRules` joins rule files with `<!-- Source: … -->` markers; there is no include or import parsing ([`src/core/RuleProcessor.ts#L7-L28`](https://github.com/intellectronica/ruler/blob/5e551e60952fb1c81c6c5ad6f5fe8b7a412bda87/src/core/RuleProcessor.ts#L7-L28)). A code search of the repo for `@import` returns 0 hits. [VERIFIED]
- **rulesync: no.** The rule frontmatter schema has no `requires`, include or imports key ([`src/features/rules/rulesync-rule.ts#L34-L257`](https://github.com/dyoshikawa/rulesync/blob/6e3869d378066dc2f0b4cda3896e444ae7f200a7/src/features/rules/rulesync-rule.ts#L34-L257)); code search for `@import` returns 0 hits. `takt.extends` is only emitted into Takt output for Takt to interpret; rulesync does not resolve it. [VERIFIED]
- **ruly: yes.** `DependencyResolver.resolve_requires_for_source` reads `frontmatter['requires']` and skips keys already processed (`lib/ruly/services/dependency_resolver.rb:10-25`); `SourceProcessor` pushes requires to the front of the queue for depth-first transitive processing (`lib/ruly/services/source_processor.rb:173-182`); `--strict` also fails on a missing transitive source (`lib/ruly/cli.rb:50-51`). [VERIFIED]
