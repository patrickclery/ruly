# Token benchmark: fixture corpus

> These numbers come from the synthetic fixture corpus in `bench/fixtures/corpus`. They are not a measurement of any real rules repository.

Encoding: `cl100k_base` (tiktoken). ruly 0.4.0. Corpus: 30 files (19 always-loaded rules, 5 path-scoped rules, 4 skills, 2 commands).

## Conditions

- **ruly**: the CLAUDE.local.md written by a real `ruly squash RECIPE`, plus the `name: description` line of each skill and command it wrote (Claude Code loads those descriptions up front).
- **load-all**: every rule of the corpus (always-loaded and path-scoped), frontmatter stripped, concatenated, plus the `name: description` line of every skill and command.
- **native floor**: a native Claude Code layout of the same corpus at session start: every rule without `paths:` frontmatter, plus the `name: description` line of every skill and command.
- **native ceiling**: the native floor plus every path-scoped rule (`paths:` frontmatter), i.e. after files matching every path rule have been opened.

Skill and command bodies are not counted in any condition: every condition counts a skill or command by its `name: description` line, which is what Claude Code loads up front. Counted this way, load-all equals the native ceiling by construction: both hold every rule body and every description.

## Results

| Recipe | ruly | load-all | native floor | native ceiling | vs load-all | vs native floor | vs native ceiling |
|---|--:|--:|--:|--:|--:|--:|--:|
| bug | 2,677 | 9,972 | 8,098 | 9,972 | 73.2% | 66.9% | 73.2% |
| frontend | 1,620 | 9,972 | 8,098 | 9,972 | 83.8% | 80.0% | 83.8% |
| pr-review | 2,562 | 9,972 | 8,098 | 9,972 | 74.3% | 68.4% | 74.3% |
| ruby-feature | 3,015 | 9,972 | 8,098 | 9,972 | 69.8% | 62.8% | 69.8% |
| testing | 2,085 | 9,972 | 8,098 | 9,972 | 79.1% | 74.3% | 79.1% |

Token counts in `cl100k_base` tokens. Percentages are reductions of ruly against each baseline; a negative value means the ruly output is larger.

## Summary

Recipes measured: 5.

- vs load-all: median 74.3% (min 69.8%, max 83.8%)
- vs native floor: median 68.4% (min 62.8%, max 80.0%)
- vs native ceiling: median 74.3% (min 69.8%, max 83.8%)

Reproduce with `bundle exec ruby bench/tokens.rb`. Identical inputs give identical output.
