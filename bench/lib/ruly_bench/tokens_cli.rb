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

      benchmark = TokenBenchmark.new(corpus:, label: label(corpus), recipe_names: @options[:recipes])
      write(benchmark, output_dir)
      report(benchmark)
      0
    rescue OptionParser::ParseError => e
      @err.puts "tokens: #{e.message}"
      2
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
      default = corpus.fixture? ? 'bench/results' : 'bench/results/local'
      real_path(@options.fetch(:output_dir, File.join(@repo_root, default)))
    end

    # Expand a path and resolve symlinks through its nearest existing ancestor (the path may not exist yet).
    def real_path(path)
      path = File.expand_path(path)
      missing = []
      until File.exist?(path) || path == File.dirname(path)
        missing.unshift(File.basename(path))
        path = File.dirname(path)
      end
      File.join(File.realpath(path), *missing)
    end

    # A non-fixture corpus may be private: it never writes under bench/results/ outside bench/results/local/.
    def forbidden_output?(corpus, output_dir)
      return false if corpus.fixture?

      results = real_path(File.join(@repo_root, 'bench/results'))
      local = real_path(File.join(@repo_root, 'bench/results/local'))
      inside?(output_dir, results) && !inside?(output_dir, local)
    end

    def inside?(path, dir)
      path == dir || path.start_with?("#{dir}/")
    end

    def refuse(output_dir)
      @err.puts "tokens: refusing to write results of a non-fixture corpus to #{output_dir}; " \
                'use bench/results/local (git-ignored) or a directory outside bench/results'
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
      @out.puts "#{summary['recipes']} recipes measured, #{result['skipped'].size} skipped; median reduction " \
                "vs load-all #{summary['reduction_vs_load_all_pct']['median']}%, " \
                "vs native floor #{summary['reduction_vs_native_floor_pct']['median']}%, " \
                "vs native ceiling #{summary['reduction_vs_native_ceiling_pct']['median']}%"
    end
  end
end
