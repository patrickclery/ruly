# frozen_string_literal: true

module RulyBench
  # Measures each recipe of a corpus: ruly squash output versus load-all and the native floor/ceiling.
  class TokenBenchmark
    SCHEMA = 1
    BASELINES = %w[load_all native_floor native_ceiling].freeze
    REDUCTION_KEYS = BASELINES.to_h { |b| [b, "reduction_vs_#{b}_pct"] }.freeze
    FIXTURE_CORPUS_LABEL = 'bench/fixtures/corpus'
    TOKEN_COLUMNS = %w[ruly_total load_all native_floor native_ceiling].freeze

    attr_reader :corpus, :label

    # Reduction of ruly against a baseline in percent, rounded to one decimal; negative when ruly is larger.
    def self.reduction(baseline, ruly)
      return 0.0 if baseline.zero?

      ((baseline - ruly) * 100.0 / baseline).round(1)
    end

    # Median rounded to one decimal; an even count takes the mean of the middle two.
    def self.median(values)
      return 0.0 if values.empty?

      sorted = values.sort
      mid = sorted.size / 2
      value = sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
      value.to_f.round(1)
    end

    # @param corpus [RulyBench::Corpus]
    # @param label [String] corpus label for the report title
    # @param recipe_names [Array<String>, nil] recipes to measure (default: all, sorted)
    def initialize(corpus:, label:, recipe_names: nil)
      @corpus = corpus
      @label = label
      @recipe_names = recipe_names
    end

    # @return [Hash] the full result (string keys, alphabetical)
    def result
      @result ||= build_result
    end

    def to_json(*_args)
      "#{JSON.pretty_generate(result)}\n"
    end

    def to_markdown
      lines = header_lines + conditions_lines + results_lines + summary_lines + footer_lines
      "#{lines.join("\n")}\n"
    end

    private

    def build_result
      skipped = []
      rows = recipe_names.filter_map { |name| measure_or_skip(name, skipped) }
      {
        'baselines' => baselines,
        'corpus' => corpus.fixture? ? FIXTURE_CORPUS_LABEL : 'external',
        'corpus_stats' => corpus_stats,
        'encoding' => TokenCounter::ENCODING,
        'label' => label,
        'recipes' => rows,
        'ruly_version' => Ruly::VERSION,
        'schema' => SCHEMA,
        'skipped' => skipped,
        'summary' => summary(rows)
      }
    end

    def recipe_names
      @recipe_names || corpus.recipes.keys.sort
    end

    # @return [Hash, nil] the row, or nil after recording why the recipe was skipped
    def measure_or_skip(name, skipped)
      if corpus.remote?(corpus.recipes[name])
        skipped << {'name' => name, 'reason' => 'remote sources'}
        return nil
      end
      measure(name)
    rescue SquashRunner::SquashFailed => e
      raise if corpus.fixture?

      skipped << {'name' => name, 'reason' => "squash failed (exit #{e.exit_status})"}
      nil
    end

    def measure(name)
      ruly_body, ruly_descriptors = SquashRunner.run(corpus_dir: corpus.dir, recipe: name) do |out|
        [TokenCounter.count(out['claude_local_md']), out['descriptors'].sum { |d| TokenCounter.count(d) }]
      end
      row(name, ruly_body, ruly_descriptors)
    end

    def row(name, ruly_body, ruly_descriptors)
      ruly_total = ruly_body + ruly_descriptors
      {
        'load_all' => baselines['load_all'],
        'name' => name,
        'native_ceiling' => baselines['native_ceiling'],
        'native_floor' => baselines['native_floor'],
        'reduction_vs_load_all_pct' => self.class.reduction(baselines['load_all'], ruly_total),
        'reduction_vs_native_ceiling_pct' => self.class.reduction(baselines['native_ceiling'], ruly_total),
        'reduction_vs_native_floor_pct' => self.class.reduction(baselines['native_floor'], ruly_total),
        'ruly_body' => ruly_body,
        'ruly_descriptors' => ruly_descriptors,
        'ruly_total' => ruly_total
      }
    end

    def baselines
      @baselines ||= {
        'load_all' => TokenCounter.count(corpus.concat(corpus.files.map { |f| corpus.body(f) })),
        'native_ceiling' => body_tokens(%i[rule path_rule]) + descriptor_tokens,
        'native_floor' => body_tokens(%i[rule]) + descriptor_tokens
      }
    end

    def body_tokens(kinds)
      TokenCounter.count(corpus.concat(files_of(*kinds).map { |f| corpus.body(f) }))
    end

    def files_of(*kinds)
      corpus.files.select { |f| kinds.include?(corpus.kind(f)) }
    end

    def descriptor_tokens
      @descriptor_tokens ||= files_of(:skill, :command).sum { |f| TokenCounter.count(corpus.source_descriptor(f)) }
    end

    def corpus_stats
      counts = corpus.files.map { |f| corpus.kind(f) }.tally
      {
        'commands' => counts.fetch(:command, 0),
        'files' => corpus.files.size,
        'path_rules' => counts.fetch(:path_rule, 0),
        'rules' => counts.fetch(:rule, 0),
        'skills' => counts.fetch(:skill, 0)
      }
    end

    def summary(rows)
      stats = REDUCTION_KEYS.values.sort.to_h do |key|
        values = rows.map { |r| r[key] }
        [key, {'max' => values.max || 0.0, 'median' => self.class.median(values), 'min' => values.min || 0.0}]
      end
      {'recipes' => rows.size}.merge(stats).sort.to_h
    end

    def header_lines
      stats = result['corpus_stats']
      [
        "# Token benchmark: #{label} corpus",
        '',
        corpus_notice,
        '',
        "Encoding: `#{result['encoding']}` (tiktoken). ruly #{result['ruly_version']}. " \
        "Corpus: #{stats['files']} files (#{stats['rules']} always-loaded rules, " \
        "#{stats['path_rules']} path-scoped rules, #{stats['skills']} skills, #{stats['commands']} commands).",
        ''
      ]
    end

    def corpus_notice
      if result['corpus'] == FIXTURE_CORPUS_LABEL
        '> These numbers come from the synthetic fixture corpus in `bench/fixtures/corpus`. ' \
          'They are not a measurement of any real rules repository.'
      else
        '> Local run on an external corpus. Not for committing; results stay in `bench/results/local`.'
      end
    end

    def conditions_lines
      [
        '## Conditions',
        '',
        '- **ruly**: the CLAUDE.local.md written by a real `ruly squash RECIPE`, plus the `name: description` ' \
        'line of each skill and command it wrote (Claude Code loads those descriptions up front).',
        '- **load-all**: every markdown file of the corpus, frontmatter stripped, concatenated.',
        '- **native floor**: a native Claude Code layout of the same corpus at session start: every rule ' \
        'without `paths:` frontmatter, plus the `name: description` line of every skill and command.',
        '- **native ceiling**: the native floor plus every path-scoped rule (`paths:` frontmatter), i.e. ' \
        'after files matching every path rule have been opened.',
        '',
        'Skill and command bodies are not counted in any condition.',
        ''
      ]
    end

    def results_lines
      rows = result['recipes'].map do |r|
        cells = [r['name']] + TOKEN_COLUMNS.map { |k| tokens(r[k]) } +
                REDUCTION_KEYS.values.map { |k| pct(r[k]) }
        "| #{cells.join(' | ')} |"
      end
      [
        '## Results',
        '',
        '| Recipe | ruly | load-all | native floor | native ceiling | vs load-all | vs native floor | ' \
        'vs native ceiling |',
        '|---|--:|--:|--:|--:|--:|--:|--:|',
        *rows,
        '',
        'Token counts in `cl100k_base` tokens. Percentages are reductions of ruly against each baseline; ' \
        'a negative value means the ruly output is larger.',
        ''
      ] + skipped_lines
    end

    def tokens(num) = Ruly::Operations::Stats.format_number(num)

    def pct(value) = format('%.1f%%', value)

    def skipped_lines
      return [] if result['skipped'].empty?

      ['Skipped recipes:', ''] + result['skipped'].map { |s| "- #{s['name']}: #{s['reason']}" } + ['']
    end

    def summary_lines
      names = {'load_all' => 'load-all', 'native_ceiling' => 'native ceiling', 'native_floor' => 'native floor'}
      items = BASELINES.map do |b|
        s = result['summary'][REDUCTION_KEYS[b]]
        "- vs #{names[b]}: median #{pct(s['median'])} (min #{pct(s['min'])}, max #{pct(s['max'])})"
      end
      ['## Summary', '', "Recipes measured: #{result['summary']['recipes']}.", '', *items, '']
    end

    def footer_lines
      ['Reproduce with `bundle exec ruby bench/tokens.rb`. Identical inputs give identical output.']
    end
  end
end
