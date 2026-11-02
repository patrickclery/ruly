# Benchmarks

Ruly's case rests on two claims: a recipe-scoped `CLAUDE.local.md` costs fewer tokens than loading every rule, and the model still follows the rules it gets. This page reports what the benchmark harness under `bench/` measures for both. The token figures replace an earlier self-reported reduction figure that had never been measured; that figure is no longer used anywhere in the docs.

## Token benchmark

Measured on ruly's synthetic fixture corpus, the squashed recipe output (plus the descriptions of the skills and commands it writes) was a median of 76.9% smaller than loading every rule file (range 72.8% to 85.4% across five recipes). Against a native Claude Code layout of the same rules, it was a median of 68.4% smaller than the native floor (range 62.8% to 80.0%) and 74.3% smaller than the native ceiling (range 69.8% to 83.8%).

These numbers describe the fixture corpus in `bench/fixtures/corpus`, not any real rules repository. A repository whose rules are mostly needed by every task would see a smaller reduction; see [Limitations](#limitations).

### Conditions

- **ruly**: the CLAUDE.local.md written by a real `ruly squash RECIPE`, plus the `name: description` line of each skill and command it wrote (Claude Code loads those descriptions up front).
- **load-all**: every markdown file of the corpus, frontmatter stripped, concatenated.
- **native floor**: a native Claude Code layout of the same corpus at session start: every rule without `paths:` frontmatter, plus the `name: description` line of every skill and command.
- **native ceiling**: the native floor plus every path-scoped rule (`paths:` frontmatter), i.e. after files matching every path rule have been opened.

Skill and command bodies are not counted in any condition.

### Corpus

The fixture corpus has 30 markdown files: 19 always-loaded rules, 5 path-scoped rules, 4 skills and 2 commands. Its `recipes.yml` defines five recipes, each the set of files one kind of task needs: `bug`, `frontend`, `pr-review`, `ruby-feature` and `testing`.

### Results

| Recipe | ruly | load-all | native floor | native ceiling | vs load-all | vs native floor | vs native ceiling |
|---|--:|--:|--:|--:|--:|--:|--:|
| bug | 2,677 | 11,083 | 8,098 | 9,972 | 75.8% | 66.9% | 73.2% |
| frontend | 1,620 | 11,083 | 8,098 | 9,972 | 85.4% | 80.0% | 83.8% |
| pr-review | 2,562 | 11,083 | 8,098 | 9,972 | 76.9% | 68.4% | 74.3% |
| ruby-feature | 3,015 | 11,083 | 8,098 | 9,972 | 72.8% | 62.8% | 69.8% |
| testing | 2,085 | 11,083 | 8,098 | 9,972 | 81.2% | 74.3% | 79.1% |

Token counts are `cl100k_base` tokens. Percentages are reductions of ruly against each baseline; a negative value would mean the ruly output is larger.

| Baseline | Median | Min | Max |
|---|--:|--:|--:|
| vs load-all | 76.9% | 72.8% | 85.4% |
| vs native floor | 68.4% | 62.8% | 80.0% |
| vs native ceiling | 74.3% | 69.8% | 83.8% |

The machine-readable results, including the split of each ruly total into squashed body and skill/command descriptions, are in [`bench/results/tokens.json`](../bench/results/tokens.json); [`bench/results/tokens.md`](../bench/results/tokens.md) is the same data as generated.

## Compliance benchmark

Fewer tokens only help if the model still follows the rules. The compliance benchmark checks whether a model follows a rule when it reaches it through a recipe-scoped CLAUDE.local.md, compared with the native layout of the same rules.

Status: pending. No live run has been made, because a live run costs API money. The harness, the task suite and the scoring are committed and tested offline; no compliance numbers are published until a live run on the fixture corpus produces them.

### Conditions

- **ruly**: a temp workspace holding only the outputs of `ruly squash RECIPE` for the task's recipe (CLAUDE.local.md, plus any `.claude/` skills and commands).
- **native**: a temp workspace holding only a native layout of the same corpus: rules in `.claude/rules/` (keeping their `paths:` frontmatter) and skills in `.claude/skills/`.

Both conditions run `claude -p` in the workspace with the same neutral prompt, which asks for an artifact and a reply format and never states the rule.

### Tasks

Eight tasks, defined in [`bench/compliance/tasks.yml`](../bench/compliance/tasks.yml). Each tests one rule sentence of the fixture corpus. "Native placement" is where the native layout loads that rule; in the ruly condition every rule except the skill sits in CLAUDE.local.md.

| Task | Recipe | Rule | Native placement | Check |
|---|---|---|---|---|
| `ruby-single-quotes` | ruby-feature | Use single quotes for Ruby string literals that contain no interpolation. | always | no double-quoted string without interpolation in the code |
| `frozen-string-literal` | ruby-feature | Every Ruby file starts with the magic comment `# frozen_string_literal: true`. | always | the code starts with the magic comment |
| `no-puts-in-library` | ruby-feature | Library code never calls puts; write through the injected logger. | always | no `puts` in the code |
| `rspec-expect` | testing | Write RSpec expectations with expect(...); never use the should syntax. | path-scoped | no `should`, and at least one `expect` |
| `commit-subject` | pr-review | Commit subjects follow type(scope): summary, in lower case, at most 72 characters. | always | the first line is a lower-case `type(scope): summary` of at most 72 characters |
| `migration-up-down` | ruby-feature | Every migration defines up and down methods; never define change. | path-scoped | no `def change`, and both `def up` and `def down` |
| `react-named-export` | frontend | React components use named exports; never export default. | path-scoped | no `export default`, and a named `UserBadge` export |
| `bug-root-cause` | bug | The first line of every bug summary is Root cause: followed by one sentence. | skill | the first line starts with `Root cause:` |

### Scoring

Each reply is scored by deterministic regex checks: `forbid` (the pattern must not match) or `require` (it must match), over the whole reply, the fenced code blocks, or the first line. Each task carries a canned passing reply and a canned failing reply, and the dry run proves every check against both without an API call.

The default model is `claude-sonnet-5-5`; pass `--model ID` to use another. A live run writes `compliance.json` and `compliance.md` with per-condition pass counts, each reply and its cost, and the failed checks.

### How to run it

- `bundle exec ruby bench/compliance.rb`: the dry run, and the default. It builds both workspaces, locates every rule, proves the checks on the canned replies and prints the exact `claude -p` commands. It makes no API calls.
- `bundle exec ruby bench/compliance.rb --live`: the paid run, 16 calls (8 tasks x 2 conditions). Each call passes `--max-budget-usd` to claude (default 0.50 per call, changeable with `--max-budget-usd N`), and the worst-case total is printed before the first call. File-editing and shell tools are disallowed, so the model can only reply.
- `--isolated-home`: runs claude with a temp HOME, so user-level memory and settings reach neither condition. A temp HOME has no login, so it needs `ANTHROPIC_API_KEY` in the environment; the key is inherited from the process, never written anywhere.
- A corpus other than the fixture needs `--allow-private-corpus` before `--live` sends its rules to the API, and results from it are written only to the git-ignored `bench/results/local/`.

## Methodology

Token counts matter because instruction following degrades as instructions and context grow:

- IFScale ([arXiv:2507.11538](https://arxiv.org/abs/2507.11538)) finds that the best frontier models follow about 68% of instructions at 500 instructions, with near-perfect adherence up to about 150 instructions only for top reasoning models.
- Chroma's context-rot study ([research.trychroma.com/context-rot](https://research.trychroma.com/context-rot)) finds that performance drops as input length grows, across 18 LLMs.
- Claude Code's own docs say imports "don't reduce its context cost, because imported files load together with the CLAUDE.md that imports them" ([docs](https://code.claude.com/docs/en/memory#import-additional-files)), so splitting rules into imported files does not by itself save tokens.

Token savings alone do not show that the rules help. Gloaguen et al., ICLR 2026 ([arXiv:2602.11988](https://arxiv.org/abs/2602.11988)), find that AGENTS.md and CLAUDE.md files do not generally raise task success (about +4% for developer-written files, -0.5% to -3% for LLM-generated ones) and add more than 20% inference cost. That is why the harness measures compliance as well as tokens, and why the compliance result is reported as pending rather than assumed.

How each condition is built:

- **ruly** is the output of a real `bin/ruly squash RECIPE`, run on a copy of the corpus in an isolated temp workspace with `HOME` and `RULY_HOME` redirected, so no user config or cache leaks in.
- **load-all**, **native floor** and **native ceiling** are built from the same corpus files. Rule bodies are stripped of frontmatter with the same frontmatter function squash uses, so both sides count the same text.
- Skills and commands are counted by their `name: description` line on both sides, because that is what Claude Code loads up front; their bodies load on demand and are not counted.
- Tokens are counted with tiktoken's `cl100k_base` encoding.

The fixture corpus is synthetic. It was written for this benchmark: five recipes over 24 rule files on Ruby, testing, databases, git, code review, security, bugs and frontend code, holding the eight rule sentences the compliance tasks test. To keep the corpus from being trivially small, it was sized to a floor of 10,000 tokens: when the first draft came in just above that floor, 19 of the rule files were each padded with one extra section, bringing the corpus to 11,091 tokens. The percentages depend on that makeup.

Runs are deterministic: results contain no timestamps or absolute paths, and the same inputs give byte-identical `tokens.json` and `tokens.md`.

## Limitations

- **Synthetic corpus.** The fixture corpus was written and sized for the benchmark, and its makeup drives the percentages. A repository where most rules are needed by every task gains less from recipes; one with many task-specific rules gains more. The numbers are not a measurement of any real rules repository.
- **Tokenizer.** `cl100k_base` is OpenAI's tiktoken encoding, not Claude's tokenizer. The counts are good for comparing conditions with each other, not as billing figures.
- **Excluded context.** Claude Code's system prompt, tool definitions and user memory are not counted. They would add the same amount to every condition, which would shrink the percentages but not change which condition is smallest.
- **One-to-one native mapping.** The native layout maps each rule file to one native rule. A native user could move more rules into skills or `paths:` scoping and get closer to ruly's numbers, so the native floor and ceiling bracket native cost rather than pin it.
- **Path-scoped rules.** A native path-scoped rule loads only when a matching file is opened. A text-only compliance task may never open such a file, so in the native condition three of the eight rules (`rspec-expect`, `migration-up-down`, `react-named-export`) may never reach the model.
- **Small compliance suite.** Eight tasks with one sample per task and condition is not statistically significant. The checks are regexes, which can pass a reply that breaks the rule's intent or fail one that follows it in an unexpected form.
- **User memory.** Without `--isolated-home`, user-level memory and settings may reach both conditions.
- **CLAUDE.local.md loading.** The ruly condition relies on Claude Code loading CLAUDE.local.md from the working directory.

## Reproduce

- `bundle exec ruby bench/tokens.rb` regenerates `bench/results/tokens.json` and `bench/results/tokens.md` byte for byte.
- `bundle exec rspec spec/bench` runs the harness specs. They never call claude.
- `bundle exec ruby bench/compliance.rb` runs the compliance dry run; see [How to run it](#how-to-run-it) for the live run.
- To measure your own rules, run `bundle exec ruby bench/tokens.rb --corpus <rules repo with recipes.yml at its root>`, for example a `~/.config/ruly/remotes/<owner>/<repo>` mirror. Results are written to the git-ignored `bench/results/local/`, and recipes with remote sources are skipped. Do not commit those results if the rules are private.
