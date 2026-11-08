# frozen_string_literal: true

module RulyBench
  # Command line for the compliance benchmark. A dry run is the default and makes no API call; only `--live`
  # runs `claude -p`.
  class ComplianceCLI
    DEFAULT_EXECUTOR = lambda do |env, argv, chdir:, stdin_data:|
      Open3.capture3(env, *argv, chdir:, stdin_data:)
    end
    DEFAULT_MAX_BUDGET_USD = 0.50
    DEFAULT_TASKS = File.join(REPO_ROOT, 'bench/compliance/tasks.yml')

    # @param argv [Array<String>]
    # @param env [Hash] environment, read for presence checks only (never printed or written)
    # @param err [IO]
    # @param executor [#call] runs claude in a live run
    # @param out [IO]
    # @param repo_root [String] repository root the default output dirs and the guard resolve against
    def initialize(argv, err: $stderr, executor: DEFAULT_EXECUTOR, out: $stdout, repo_root: REPO_ROOT)
      @argv = argv.dup
      @err = err
      @executor = executor
      @out = out
      @repo_root = repo_root
      @options = {}
    end

    # @return [Integer] exit status: 0 ok, 1 harness error or failed validation, 2 usage error or refused run
    def run
      parse!
      return 0 if @options[:help]
      return usage(usage_problem) if usage_problem

      corpus = Corpus.new(@options.fetch(:corpus, FIXTURE_CORPUS))
      tasks = ComplianceTasks.new(corpus:, path: @options.fetch(:tasks, DEFAULT_TASKS))
      unknown = @options[:only] ? tasks.restrict(@options[:only]) : []
      return usage("unknown task id #{unknown.join(', ')}") unless unknown.empty?

      @options[:live] ? live(corpus, tasks) : dry(corpus, tasks)
    rescue OptionParser::ParseError => e
      usage(e.message)
    rescue Error => e
      @err.puts "compliance: #{e.message}"
      1
    end

    private

    def parse!
      parser.parse!(@argv)
      raise OptionParser::InvalidArgument, "unexpected argument #{@argv.first}" unless @argv.empty?
    end

    def parser
      OptionParser.new do |o|
        o.banner = 'Usage: bundle exec ruby bench/compliance.rb [options]'
        mode_options(o)
        run_options(o)
        o.on('-h', '--help', 'Show this help') do
          @out.puts o
          @options[:help] = true
        end
      end
    end

    def mode_options(opts)
      opts.on('--dry-run', 'Validate tasks and workspaces, print the claude commands (default)') do
        @options[:dry_run] = true
      end
      opts.on('--live', 'Run claude -p for every task and condition (uses your Claude subscription)') do
        @options[:live] = true
      end
      opts.on('--check-cli', 'Dry run only: check that claude --help lists every flag used') do
        @options[:check_cli] = true
      end
      opts.on('--allow-private-corpus', 'Allow --live on a corpus other than the fixture') do
        @options[:allow_private_corpus] = true
      end
    end

    def run_options(opts)
      opts.on('--model ID', "Model for claude -p (default: #{ClaudeCommand::DEFAULT_MODEL})") { @options[:model] = _1 }
      opts.on('--tasks FILE', 'Task suite (default: bench/compliance/tasks.yml)') { @options[:tasks] = _1 }
      opts.on('--only LIST', Array, 'Comma-separated task ids (default: all)') { @options[:only] = _1 }
      opts.on('--corpus DIR', 'Rules corpus with recipes.yml (default: bench/fixtures/corpus)') do |v|
        @options[:corpus] = v
      end
      opts.on('--output-dir DIR', 'Where a live run writes compliance.json and compliance.md') do |v|
        @options[:output_dir] = v
      end
      opts.on('--max-budget-usd N', Float, "Per-call cap passed to claude (default: #{DEFAULT_MAX_BUDGET_USD})") do |v|
        # claude receives the cap with two decimals, so a smaller value would reach it as 0.00.
        raise OptionParser::InvalidArgument, "--max-budget-usd must be at least 0.01, got #{v}" unless v >= 0.01

        @options[:max_budget_usd] = v
      end
      opts.on('--claude-bin NAME', 'claude executable (default: claude)') { @options[:claude_bin] = _1 }
    end

    def usage_problem
      return '--live and --dry-run are exclusive' if @options[:live] && @options[:dry_run]

      '--check-cli works in a dry run only' if @options[:live] && @options[:check_cli]
    end

    def usage(message)
      @err.puts "compliance: #{message}"
      2
    end

    def live(corpus, tasks)
      unless corpus.fixture? || @options[:allow_private_corpus]
        return usage('--live sends the corpus rules to Claude; pass --allow-private-corpus for a non-fixture corpus')
      end

      output_dir = OutputDir.resolve(corpus:, repo_root: @repo_root, requested: @options[:output_dir])
      return usage(OutputDir.refusal(output_dir)) if OutputDir.forbidden?(corpus:, output_dir:, repo_root: @repo_root)

      compliance_run(corpus, tasks, ClaudeCommand::SUBSCRIPTION_ENV).live_run(output_dir:)
    end

    def compliance_run(corpus, tasks, env)
      ComplianceRun.new(claude_bin:, corpus:, env:, executor: @executor,
                        max_budget_usd: @options.fetch(:max_budget_usd, DEFAULT_MAX_BUDGET_USD),
                        model: @options.fetch(:model, ClaudeCommand::DEFAULT_MODEL), out: @out, tasks:)
    end

    def claude_bin
      @options.fetch(:claude_bin, 'claude')
    end

    def dry(corpus, tasks)
      status = compliance_run(corpus, tasks, {}).dry_run
      @options[:check_cli] ? [status, check_cli].max : status
    end

    # Calls only `claude --help`, which makes no API request.
    def check_cli
      bin = claude_bin
      problems, count = ClaudeCommand.check_binary(bin)
      if problems.empty?
        @out.puts "cli flags: ok (#{count} flags listed by #{bin} --help)"
        return 0
      end

      problems.each { |problem| @out.puts "problem: #{problem}" }
      1
    end
  end
end
