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
