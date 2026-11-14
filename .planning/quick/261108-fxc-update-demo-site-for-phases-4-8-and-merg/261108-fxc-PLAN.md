---
phase: quick-261108-fxc
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - site/app/page.tsx
  - site/app/layout.tsx
autonomous: true
requirements: [QUICK-261108-fxc]

estimate:
  tokens: 40000
  raw_tokens: 40000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "The site home page says `ruly squash RECIPE -a agents` writes AGENTS.md and skips the Claude-only parts (commands, subagents, hooks, MCP servers)"
    - "The site home page says `-a claude-plugin` packages the recipe as a Claude Code plugin directory and that its rules ship as the skill /RECIPE:RECIPE-rules, loaded when invoked, not always-on"
    - "The site home page shows the fixture benchmark median (74.3% smaller than loading every rule, 68.4% vs a native layout's always-loaded set), labelled as ruly's synthetic fixture, with a link to docs/benchmarks.md"
    - "The site home page describes the /recipe-from-project skill and says it is fetched by URL from a recipe's skills: entry, not installed with the gem"
    - "The interactive demo and the three existing cards (Recipes, Subagents, Sync and checks) are unchanged"
    - "gsd/phase-06-subscription-only contains origin/main, is merged to main through a GitHub PR, and the Deploy to GitHub Pages run for the merge commit concludes success"
    - "The pre-existing uncommitted paths (.planning/config.json, Gemfile.lock, the phase .gitkeep files, .planning/research/, .planning/state.json) are still uncommitted at the end"
  artifacts:
    - path: "site/app/page.tsx"
      provides: "Hero sentence on output targets plus three new feature cards"
      contains: "-a claude-plugin"
    - path: "site/app/layout.tsx"
      provides: "Page metadata description naming AGENTS.md and Claude Code plugin output"
      contains: "AGENTS.md"
  key_links:
    - from: "site/app/page.tsx"
      to: "site/out/index.html"
      via: "next build static export (output: export)"
      pattern: "-a claude-plugin"
    - from: "merge commit on main touching site/**"
      to: ".github/workflows/deploy-site.yml"
      via: "push to main with paths: [site/**] filter"
      pattern: "Deploy to GitHub Pages"
---

<objective>
Bring the demo site (site/, Next.js static export) up to date with phases 4-8, then merge the branch to main so GitHub Pages redeploys it.

Purpose: The site was last edited in phase 3 and does not mention the AGENTS.md target (phase 4), Claude Code plugin output (phase 5), the fixture benchmark (phase 6) or the recipe-from-project skill (phase 8). Phase 7 (the competitor audit) only changed README comparison tables. The site has no comparison section, and this plan does not add one.
Output: Updated site/app/page.tsx and site/app/layout.tsx, one site commit, origin/main merged into the branch, a merged PR to main, and a successful Pages deploy.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@site/app/page.tsx
@site/app/layout.tsx
@.github/workflows/deploy-site.yml

Wording sources (README.md is the source of truth; read only these ranges):
- README.md "Why ruly" (about lines 10-20) and the "For other agents" list (about lines 197-204)
- README.md "### AGENTS.md Output" and "### Claude Code Plugin Output" (about lines 746-830)
- README.md "Ruly vs. native Claude Code" token-cost row (about line 100), which holds the benchmark sentence
- README.md "#### Available Ruly Commands" and "#### Drafting a Recipe From a Project" (about lines 892-925)
- docs/benchmarks.md lines 1-12

Baselines observed at plan time (HEAD b3a098c): page.tsx has 3 `card-glow` cards; 0 hits for `-a agents`, `-a claude-plugin`, `74.3%`, `recipe-from-project`, `benchmarks.md`, `AGENTS.md`, `fixture`; layout.tsx has 0 `AGENTS.md`. `cd site && npm run lint` and `npm run build` both pass. The branch diff against origin/main touches no site/ files, so the only site change in the eventual merge to main is this plan's commit, and that commit is what triggers the deploy workflow's `paths: [site/**]` filter. Main uses merge commits for PRs (#4, #5, #6). main is not branch-protected and has no PR check workflows. Pages html_url is reported by `gh api repos/patrickclery/ruly/pages --jq .html_url`.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Site copy for phases 4-8, from source through the built static page</name>
  <files>site/app/page.tsx, site/app/layout.tsx</files>
  <action>
Edit site/app/page.tsx and site/app/layout.tsx only. Keep the existing visual style: same Tailwind classes, same card markup (the `card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200` div, the `h-8 w-8 text-green-500 mb-3` outline svg, h3 `text-lg font-semibold text-white`, p `mt-2 text-sm text-gray-400`), and the same grid (`md:grid-cols-3`, so six cards make two rows with no class change). Take every claim from the README ranges listed in context and do not describe features README does not document.

1. Hero paragraph in page.tsx: append one sentence after the existing text saying the same recipe can also be written as AGENTS.md (`-a agents`) or packaged as a Claude Code plugin directory (`-a claude-plugin`). This follows README "For other agents". Leave the h1 and the two buttons unchanged.

2. Add three cards after the existing three, in this order:
   a. "AGENTS.md and plugin output": `ruly squash RECIPE -a agents` writes AGENTS.md, the cross-agent instruction file standard, and skips the Claude-only parts (commands, subagents, hooks, MCP servers). `-a claude-plugin` packages the skills, commands, agents, hooks and MCP servers as a plugin directory for `claude --plugin-dir`. Plugins cannot carry always-on instructions, so the rules ship as the skill /RECIPE:RECIPE-rules, loaded when invoked. Icon: a Heroicons v2 outline 24x24 path such as puzzle-piece.
   b. "Fixture benchmark": state that on ruly's synthetic bench fixture (five recipes, cl100k_base tokens), the squashed recipe output plus its skill and command descriptions was a median 74.3% smaller than loading every rule, and 68.4% smaller than a native layout's always-loaded set. Use these figures exactly as README and docs/benchmarks.md give them. The median figure in the quick-task description is wrong; use README's. The card must say the numbers come from the synthetic fixture. End with a link "Benchmark details" to https://github.com/patrickclery/ruly/blob/main/docs/benchmarks.md, styled `text-green-400 hover:brightness-110 transition duration-200` (green-400 is already used on the page). Icon: Heroicons v2 outline chart-bar.
   c. "Draft a recipe from a project": the /recipe-from-project skill drafts a recipe from a project folder's current rules, skills, commands, subagents and MCP servers, and writes it to the rules repo's recipes.yml only after you approve the draft. It is not installed with the gem: list https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md under a recipe's `skills:` and `ruly squash` fetches it (so that squash needs the network). End with a link "How to run it" to https://github.com/patrickclery/ruly#drafting-a-recipe-from-a-project, same link style. Icon: Heroicons v2 outline document-magnifying-glass or sparkles.
   Any valid 24x24 stroke path is acceptable for the icons. Build success is the only check on the path data.

3. layout.tsx metadata.description: keep the current sentence and add that output goes to Claude Code, AGENTS.md or a Claude Code plugin. Leave title unchanged.

4. Leave site/components/ and site/lib/ unchanged (Claude's discretion). The interactive demo models the default Claude Code target (CLAUDE.local.md plus .claude/), and README says that default output is unchanged by the new targets. So the demo stays accurate, and the new targets get cards instead of new demo branches.

5. From the repo root, run `npm --prefix site run lint` and `npm --prefix site run build`. Fix any errors in the two edited files.

6. Commit only the two site files: `git add site/app/page.tsx site/app/layout.tsx` (never `git add -A`, `git add .` or `git commit -a`). The pre-existing dirty paths .planning/config.json, Gemfile.lock, the phase .gitkeep files, .planning/research/ and .planning/state.json must stay uncommitted. Message subject: `feat(site): show AGENTS.md and plugin output, fixture benchmark and recipe-from-project`. End the body with the two trailer lines `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01PHVzHp8N7xeCr2tgiRcu7m`.
  </action>
  <verify>
    <automated>npm --prefix site run lint && npm --prefix site run build && test "$(grep -o 'card-glow' site/app/page.tsx | wc -l)" -eq 6 && grep -q -F -- '-a agents' site/out/index.html && grep -q -F -- '-a claude-plugin' site/out/index.html && grep -q -F 'RECIPE:RECIPE-rules' site/out/index.html && grep -q -F '74.3%' site/out/index.html && grep -q -F '68.4%' site/out/index.html && grep -qi 'synthetic' site/out/index.html && grep -q -F 'docs/benchmarks.md' site/out/index.html && grep -q -F 'recipe-from-project' site/out/index.html && ! grep -q -F '76.9' site/app/page.tsx && grep -q -F 'AGENTS.md' site/app/layout.tsx && files=$(git show --name-only --format= HEAD) && test -n "$files" && ! printf '%s\n' "$files" | grep -v '^site/app/' && st=$(git status --short) && printf '%s\n' "$st" | grep -q -F 'Gemfile.lock'</automated>
  </verify>
  <done>Lint and build pass. The built site/out/index.html contains the AGENTS.md/plugin card (with -a agents, -a claude-plugin and /RECIPE:RECIPE-rules), the fixture benchmark card (74.3%, 68.4%, the word synthetic, a docs/benchmarks.md link) and the recipe-from-project card. page.tsx has exactly six cards. layout.tsx metadata mentions AGENTS.md. The HEAD commit touches only site/app/ files, and Gemfile.lock is still an uncommitted modification.</done>
</task>

<task type="auto">
  <name>Task 2: Merge origin/main, open and merge the PR to main, confirm the Pages deploy</name>
  <files>(merge result; conflicted files are observed live, not listed here)</files>
  <action>
The user has authorized push and merge without asking, so add no checkpoints.

1. Run `git fetch origin`, then `git merge origin/main` with a merge commit message whose subject is `Merge origin/main into gsd/phase-06-subscription-only` and whose final paragraph is the two trailer lines (Co-Authored-By and Claude-Session, exactly as in Task 1).
   - If git refuses because local changes would be overwritten, stash only the paths git names (`git stash push -- <those paths>`), merge, then `git stash pop`. Those paths must end up uncommitted, as before.
   - Conflicts: list them live with `git diff --name-only --diff-filter=U`; do not assume which files they are. Resolve each by content and keep both sides' intent. Where both sides edited the same hunk, compare `git log -1 --format='%h %ci %s'` on HEAD and on origin/main for that file, and keep the later fix. Do not use blanket `-X ours`, `-X theirs`, `checkout --ours` or `checkout --theirs` on a whole file. Then `git add` the resolved files and conclude the merge with the same message.
   - After the merge, if `git diff --name-only HEAD^1 HEAD` includes anything under lib/, spec/ or bin/, run `bundle exec rspec` and fix failures before pushing. If it includes anything under site/, re-run `npm --prefix site run build`.

2. Push the branch with `git push origin gsd/phase-06-subscription-only` (its upstream already exists).

3. PR: first check `gh pr list --head gsd/phase-06-subscription-only --state open --json number`. If none exists, run `gh pr create --base main --head gsd/phase-06-subscription-only` with title `Phases 4-8: AGENTS.md and plugin targets, fixture benchmark, recipe-from-project, site update` and a body written to a file in the session scratchpad and passed with `--body-file`. The body briefly summarizes the branch (run `git log --oneline origin/main..HEAD` for the list, and call out the site update) and ends with the line `🤖 Generated with [Claude Code](https://claude.com/claude-code)`, a blank line, then `https://claude.ai/code/session_01PHVzHp8N7xeCr2tgiRcu7m`.

4. Merge with `gh pr merge <number> --merge`. Use a merge commit, matching PRs #4-#6. Do not pass `--delete-branch`.

5. Deploy: run `git fetch origin` and read the merge commit sha from `gh pr view <number> --json mergeCommit --jq .mergeCommit.oid`. Find the run with `gh run list --workflow deploy-site.yml --branch main --limit 5 --json databaseId,headSha,status,conclusion` and pick the entry whose headSha equals that sha. Allow up to about 2 minutes for it to appear; use the harness's wait mechanism if a foreground sleep is blocked. If no run appears for that sha, dispatch one with `gh workflow run deploy-site.yml --ref main` and use that run. Wait with `gh run watch <id> --exit-status`. If it fails, read `gh run view <id> --log-failed`, fix the cause on the branch, push, and open and merge a follow-up PR the same way until a deploy for main's head succeeds.

6. Live check: fetch the URL from `gh api repos/patrickclery/ruly/pages --jq .html_url` with curl. Follow redirects and retry for a few minutes to allow for CDN cache. Confirm the page contains `-a claude-plugin`.

7. Confirm `git status --short` still lists the pre-existing uncommitted paths, none of them committed.
  </action>
  <verify>
    <automated>git fetch origin -q && git merge-base --is-ancestor HEAD origin/main && test -z "$(git diff --name-only --diff-filter=U)" && test "$(gh pr list --head gsd/phase-06-subscription-only --state merged --limit 1 --json number --jq length)" = 1 && test "$(gh run list --workflow deploy-site.yml --branch main --limit 1 --json conclusion --jq '.[0].conclusion')" = success && url=$(gh api repos/patrickclery/ruly/pages --jq .html_url) && html=$(curl -fsSL "$url") && printf '%s\n' "$html" | grep -q -F -- '-a claude-plugin' && st=$(git status --short) && printf '%s\n' "$st" | grep -q -F 'Gemfile.lock'</automated>
  </verify>
  <done>origin/main is merged into the branch with no unresolved files. The branch is pushed, a PR to main is merged with a merge commit, and its body ends with the Claude Code attribution lines. The latest Deploy to GitHub Pages run on main concluded success. The live Pages URL serves the new plugin/AGENTS.md copy. The pre-existing local-only files remain uncommitted.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| local working tree -> origin (GitHub) | Commits and the merge become public on push and on the merge to main |
| main -> GitHub Pages | Any push to main touching site/** publishes the static site publicly |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-fxc-01 | Information Disclosure | git add / commit (Task 1, Task 2 merge) | medium | mitigate | Stage only site/app/page.tsx and site/app/layout.tsx by explicit path. The verify gate asserts the HEAD commit touches only site/app/ and that Gemfile.lock stays an uncommitted modification. Stash only the git-named paths during the merge and pop them afterwards |
| T-fxc-02 | Tampering | merge conflict resolution (Task 2) | medium | mitigate | Resolve conflicts by content with no blanket ours/theirs. The verify gate asserts no unmerged paths. Run rspec if the merge touched lib/, spec/ or bin/ |
| T-fxc-03 | Repudiation / integrity of public claims | site copy (Task 1) | low | mitigate | Copy is taken from the README sections listed in context. Gates check the built page for the README benchmark figures and the "synthetic" label, and that the wrong median from the task description is absent from page.tsx |
| T-fxc-04 | Denial of Service | Pages deploy (Task 2) | low | mitigate | Wait on the run for the merge sha with `gh run watch --exit-status`. Use workflow_dispatch if the paths filter skips it. Fix and redeploy on failure |
| T-fxc-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs and no package.json/package-lock.json changes in this plan. CI runs `npm ci` against the existing lockfile |
</threat_model>

<verification>
- `npm --prefix site run lint` and `npm --prefix site run build` pass.
- site/out/index.html contains the three new cards' key strings, and page.tsx has six cards.
- The branch is an ancestor of origin/main after the PR merge, and the latest deploy-site.yml run on main concluded success.
- The live Pages URL serves the new copy.
- The pre-existing uncommitted paths remain uncommitted.
</verification>

<success_criteria>
- The deployed site mentions AGENTS.md output, Claude Code plugin output (rules ship as a skill, not always-on), the fixture benchmark at the README figures with the synthetic-fixture label, and the recipe-from-project skill fetched by URL via skills:.
- The existing hero, demo and three cards keep their style and content.
- main contains the branch through a merged PR, and the Pages deploy for it succeeded.
</success_criteria>

<output>
Create `.planning/quick/261108-fxc-update-demo-site-for-phases-4-8-and-merg/261108-fxc-SUMMARY.md` when done
</output>
