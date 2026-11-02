# Token benchmark: fixture corpus

> These numbers come from the synthetic fixture corpus in `bench/fixtures/corpus`. They are not a measurement of any real rules repository.

Encoding: `cl100k_base` (tiktoken). ruly 0.4.0. Corpus: 30 files (19 always-loaded rules, 5 path-scoped rules, 4 skills, 2 commands).

## Conditions

- **ruly**: the CLAUDE.local.md written by a real `ruly squash RECIPE`, plus the `name: description` line of each skill and command it wrote (Claude Code loads those descriptions up front).
- **load-all**: every markdown file of the corpus, frontmatter stripped, concatenated.
- **native floor**: a native Claude Code layout of the same corpus at session start: every rule without `paths:` frontmatter, plus the `name: description` line of every skill and command.
- **native ceiling**: the native floor plus every path-scoped rule (`paths:` frontmatter), i.e. after files matching every path rule have been opened.

Skill and command bodies are not counted in any condition.

## Results

| Recipe | ruly | load-all | native floor | native ceiling | vs load-all | vs native floor | vs native ceiling |
|---|--:|--:|--:|--:|--:|--:|--:|
| bug | 2,677 | 11,083 | 8,098 | 9,972 | 75.8% | 66.9% | 73.2% |
| frontend | 1,620 | 11,083 | 8,098 | 9,972 | 85.4% | 80.0% | 83.8% |
| pr-review | 2,562 | 11,083 | 8,098 | 9,972 | 76.9% | 68.4% | 74.3% |
| ruby-feature | 3,015 | 11,083 | 8,098 | 9,972 | 72.8% | 62.8% | 69.8% |
| testing | 2,085 | 11,083 | 8,098 | 9,972 | 81.2% | 74.3% | 79.1% |

Token counts in `cl100k_base` tokens. Percentages are reductions of ruly against each baseline; a negative value means the ruly output is larger.

## Summary

Recipes measured: 5.

- vs load-all: median 76.9% (min 72.8%, max 85.4%)
- vs native floor: median 68.4% (min 62.8%, max 80.0%)
- vs native ceiling: median 74.3% (min 69.8%, max 83.8%)

Reproduce with `bundle exec ruby bench/tokens.rb`. Identical inputs give identical output.
