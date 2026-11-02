# frozen_string_literal: true

module RulyBench
  # Measures each recipe of a corpus: ruly squash output versus load-all and the native floor/ceiling.
  class TokenBenchmark
    SCHEMA = 2
    BASELINES = %w[load_all native_floor native_ceiling].freeze
    REDUCTION_KEYS = BASELINES.to_h { |b| [b, "reduction_vs_#{b}_pct"] }.freeze
    FIXTURE_CORPUS_LABEL = 'bench/fixtures/corpus'
    DESCRIBED_KINDS = %i[skill command].freeze
    TOKEN_COLUMNS = %w[ruly_total load_all native_floor native_ceiling].freeze

    attr_reader :corpus, :label

    # Reduction of ruly against a baseline in percent, rounded to one decimal; negative when ruly is larger.
    # nil for an empty baseline, where no percentage is meaningful (0.0 would hide an increase).
    def self.reduction(baseline, ruly)
      return nil if baseline.zero?

      ((baseline - ruly) * 100.0 / baseline).round(1)
    end

    # Median rounded to one decimal; an even count takes the mean of the middle two; nil when there is no value.
    def self.median(values)
      return nil if values.empty?

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
      lines = header_lines + conditions_lines + results_lines + summary_lines + unreferenced_lines + footer_lines
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
        'excluding_unreferenced' => excluding_unreferenced(rows),
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
      text, descriptors = SquashRunner.run(corpus_dir: corpus.dir, recipe: name) do |out|
        [out['claude_local_md'], out['descriptors']]
      end
      outputs << [text, descriptors]
      row(name, TokenCounter.count(text), descriptors.sum { |d| TokenCounter.count(d) }, baselines)
    end

    # Squash outputs of the measured recipes: [CLAUDE.local.md text, descriptors] each.
    def outputs
      @outputs ||= []
    end

    def row(name, ruly_body, ruly_descriptors, bases)
      ruly_total = ruly_body + ruly_descriptors
      {
        'load_all' => bases['load_all'],
        'name' => name,
        'native_ceiling' => bases['native_ceiling'],
        'native_floor' => bases['native_floor'],
        'reduction_vs_load_all_pct' => self.class.reduction(bases['load_all'], ruly_total),
        'reduction_vs_native_ceiling_pct' => self.class.reduction(bases['native_ceiling'], ruly_total),
        'reduction_vs_native_floor_pct' => self.class.reduction(bases['native_floor'], ruly_total),
        'ruly_body' => ruly_body,
        'ruly_descriptors' => ruly_descriptors,
        'ruly_total' => ruly_total
      }
    end

    def baselines
      @baselines ||= baselines_for(corpus.files)
    end

    # Every condition counts a skill or command by its descriptor, never its body, so load-all and the native
    # ceiling hold the same text: every rule body plus every descriptor.
    def baselines_for(files)
      descriptors = of_kind(files, *DESCRIBED_KINDS).sum { |f| TokenCounter.count(corpus.source_descriptor(f)) }
      every_rule = body_tokens(of_kind(files, :rule, :path_rule)) + descriptors
      floor = body_tokens(of_kind(files, :rule)) + descriptors
      {'load_all' => every_rule, 'native_ceiling' => every_rule, 'native_floor' => floor}
    end

    def of_kind(files, *kinds)
      files.select { |f| kinds.include?(corpus.kind(f)) }
    end

    def body_tokens(files)
      TokenCounter.count(corpus.concat(files.map { |f| corpus.body(f) }))
    end

    def corpus_stats
      counts = corpus.files.map { |f| corpus.kind(f) }.tally
      {
        'commands' => counts.fetch(:command, 0),
        'files' => corpus.files.size,
        'path_rules' => counts.fetch(:path_rule, 0),
        'rules' => counts.fetch(:rule, 0),
        'skills' => counts.fetch(:skill, 0),
        'unreferenced_files' => unreferenced_files.size
      }
    end

    def unreferenced_files
      @unreferenced_files ||= corpus.files.reject { |f| referenced?(f) }
    end

    def referenced?(rel)
      if described?(rel)
        descriptor = corpus.source_descriptor(rel)
        return outputs.any? { |_, descriptors| descriptors.include?(descriptor) }
      end

      body = corpus.body(rel).strip
      body.empty? || outputs.any? { |text, _| text.include?(body) }
    end

    # @return [Boolean] true for a skill or command, which every condition counts by its descriptor
    def described?(rel)
      DESCRIBED_KINDS.include?(corpus.kind(rel))
    end

    # Corpus files that no measured recipe's squash output holds. They count in every baseline (a native
    # layout loads every rule without `paths:`) but can never appear in a ruly output, so the result also
    # gives the baselines and reductions with them left out.
    def excluding_unreferenced(rows)
      files = unreferenced_files
      bases = baselines_for(corpus.files - files)
      alt_rows = rows.map { |r| row(r['name'], r['ruly_body'], r['ruly_descriptors'], bases) }
      {'baselines' => bases, 'files' => files, 'summary' => summary(alt_rows), 'tokens' => file_tokens(files)}
    end

    def summary(rows)
      stats = REDUCTION_KEYS.values.sort.to_h do |key|
        values = rows.filter_map { |r| r[key] }
        [key, {'max' => values.max, 'median' => self.class.median(values), 'min' => values.min}]
      end
      {'recipes' => rows.size}.merge(stats).sort.to_h
    end

    # Tokens of the files counted one by one: rule bodies, and skill and command descriptors.
    def file_tokens(files)
      files.sum do |f|
        TokenCounter.count(described?(f) ? corpus.source_descriptor(f) : corpus.body(f))
      end
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
        '> Local run on an external corpus. Not for committing: keep it in the git-ignored `bench/results/local` ' \
          'or outside the repository.'
      end
    end

    def conditions_lines
      [
        '## Conditions',
        '',
        '- **ruly**: the CLAUDE.local.md written by a real `ruly squash RECIPE`, plus the `name: description` ' \
        'line of each skill and command it wrote (Claude Code loads those descriptions up front).',
        '- **load-all**: every rule of the corpus (always-loaded and path-scoped), frontmatter stripped, ' \
        'concatenated, plus the `name: description` line of every skill and command.',
        '- **native floor**: a native Claude Code layout of the same corpus at session start: every rule ' \
        'without `paths:` frontmatter, plus the `name: description` line of every skill and command.',
        '- **native ceiling**: the native floor plus every path-scoped rule (`paths:` frontmatter), i.e. ' \
        'after files matching every path rule have been opened.',
        '',
        'Skill and command bodies are not counted in any condition: every condition counts a skill or command ' \
        'by its `name: description` line, which is what Claude Code loads up front. Counted this way, ' \
        'load-all equals the native ceiling by construction: both hold every rule body and every description.',
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

    def pct(value) = value.nil? ? 'n/a' : format('%.1f%%', value)

    def skipped_lines
      return [] if result['skipped'].empty?

      ['Skipped recipes:', ''] + result['skipped'].map { |s| "- #{s['name']}: #{s['reason']}" } + ['']
    end

    def summary_lines
      ['## Summary', '', "Recipes measured: #{result['summary']['recipes']}.", '',
       *summary_items(result['summary']), '']
    end

    def summary_items(summary)
      names = {'load_all' => 'load-all', 'native_ceiling' => 'native ceiling', 'native_floor' => 'native floor'}
      BASELINES.map do |b|
        s = summary[REDUCTION_KEYS[b]]
        "- vs #{names[b]}: median #{pct(s['median'])} (min #{pct(s['min'])}, max #{pct(s['max'])})"
      end
    end

    def unreferenced_lines
      excl = result['excluding_unreferenced']
      heading = ['## Files in no measured recipe', '']
      if excl['files'].empty?
        return heading + ['Every corpus file is in the output of at least one measured recipe.', '']
      end

      bases = excl['baselines']
      heading + [
        "#{excl['files'].size} corpus files are in no measured recipe's output: " \
        "#{excl['files'].map { |f| "`#{f}`" }.join(', ')} (#{tokens(excl['tokens'])} tokens counted file by file). " \
        'They count in load-all and both native baselines, because a native layout loads every rule without ' \
        '`paths:`, but no ruly output can include them.',
        '',
        "Without them, load-all is #{tokens(bases['load_all'])}, the native floor #{tokens(bases['native_floor'])} " \
        "and the native ceiling #{tokens(bases['native_ceiling'])} tokens, and the reductions are:",
        '',
        *summary_items(excl['summary']),
        ''
      ]
    end

    def footer_lines
      ['Reproduce with `bundle exec ruby bench/tokens.rb`. Identical inputs give identical output.']
    end
  end
end
