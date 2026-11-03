# frozen_string_literal: true

module RulyBench
  # Command line for the token benchmark: parses options, runs TokenBenchmark, writes tokens.json and tokens.md.
  class TokensCLI
    # @param argv [Array<String>]
    # @param err [IO] stderr
    # @param out [IO] stdout
    # @param repo_root [String] repository root the default output dirs and the guard resolve against
    def initialize(argv, err: $stderr, out: $stdout, repo_root: REPO_ROOT)
      @argv = argv.dup
      @out = out
      @err = err
      @repo_root = repo_root
      @options = {}
    end

    # @return [Integer] exit status: 0 ok, 1 harness error, 2 usage error
    def run
      parse!
      return 0 if @options[:help]

      corpus = Corpus.new(@options.fetch(:corpus, FIXTURE_CORPUS))
      output_dir = resolve_output_dir(corpus)
      return refuse(output_dir) if forbidden_output?(corpus, output_dir)

      unknown = unknown_recipes(corpus)
      return usage("unknown recipe #{unknown.join(', ')}") unless unknown.empty?

      benchmark = TokenBenchmark.new(corpus:, label: label(corpus), recipe_names: @options[:recipes])
      write(benchmark, output_dir)
      report(benchmark)
      0
    rescue OptionParser::ParseError => e
      usage(e.message)
    rescue Error => e
      @err.puts "tokens: #{e.message}"
      1
    end

    private

    def parse!
      parser.parse!(@argv)
      raise OptionParser::InvalidArgument, "unexpected argument #{@argv.first}" unless @argv.empty?
    end

    def parser
      OptionParser.new do |o|
        o.banner = 'Usage: bundle exec ruby bench/tokens.rb [options]'
        o.on('--corpus DIR', 'Rules corpus with recipes.yml (default: bench/fixtures/corpus)') do |v|
          @options[:corpus] = v
        end
        o.on('--output-dir DIR', 'Where to write tokens.json and tokens.md') { |v| @options[:output_dir] = v }
        o.on('--recipes LIST', Array, 'Comma-separated recipe names (default: all)') { |v| @options[:recipes] = v }
        o.on('--label NAME', 'Corpus label for the report title') { |v| @options[:label] = v }
        o.on('-h', '--help', 'Show this help') do
          @out.puts o
          @options[:help] = true
        end
      end
    end

    def resolve_output_dir(corpus)
      OutputDir.resolve(corpus:, repo_root: @repo_root, requested: @options[:output_dir])
    end

    def forbidden_output?(corpus, output_dir)
      OutputDir.forbidden?(corpus:, output_dir:, repo_root: @repo_root)
    end

    def refuse(output_dir)
      @err.puts "tokens: #{OutputDir.refusal(output_dir)}"
      2
    end

    # A misspelled name would only show up as a skipped squash; a repeated one would count twice in the median.
    def unknown_recipes(corpus)
      return [] unless @options[:recipes]

      @options[:recipes] = @options[:recipes].uniq
      @options[:recipes] - corpus.recipes.keys
    end

    def usage(message)
      @err.puts "tokens: #{message}"
      2
    end

    def label(corpus)
      @options[:label] || (corpus.fixture? ? 'fixture' : 'local')
    end

    def write(benchmark, output_dir)
      FileUtils.mkdir_p(output_dir)
      File.write(File.join(output_dir, 'tokens.json'), benchmark.to_json)
      File.write(File.join(output_dir, 'tokens.md'), benchmark.to_markdown)
    end

    def report(benchmark)
      result = benchmark.result
      result['recipes'].each do |r|
        @out.puts format('%<name>-20s ruly %<ruly>7d  load-all %<all>7d  native floor %<floor>7d  ' \
                         'native ceiling %<ceiling>7d',
                         all: r['load_all'], ceiling: r['native_ceiling'], floor: r['native_floor'],
                         name: r['name'], ruly: r['ruly_total'])
      end
      summary = result['summary']
      medians = %w[load_all native_floor native_ceiling].map do |b|
        median = summary["reduction_vs_#{b}_pct"]['median']
        median.nil? ? 'n/a' : "#{median}%"
      end
      @out.puts "#{summary['recipes']} recipes measured, #{result['skipped'].size} skipped; median reduction " \
                "vs load-all #{medians[0]}, vs native floor #{medians[1]}, vs native ceiling #{medians[2]}"
    end
  end
end
