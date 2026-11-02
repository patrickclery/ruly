# frozen_string_literal: true

module RulyBench
  # Command line for the compliance benchmark. A dry run is the default and makes no API call.
  class ComplianceCLI
    DEFAULT_MAX_BUDGET_USD = 0.50
    DEFAULT_TASKS = File.join(REPO_ROOT, 'bench/compliance/tasks.yml')
    DEFAULT_EXECUTOR = lambda do |env, argv, chdir:, stdin_data:|
      Open3.capture3(env, *argv, chdir:, stdin_data:)
    end

    # @param argv [Array<String>]
    # @param env [Hash] environment (read for presence checks only)
    # @param err [IO]
    # @param executor [#call] runs claude in a live run
    # @param out [IO]
    def initialize(argv, env: ENV, err: $stderr, executor: DEFAULT_EXECUTOR, out: $stdout)
      @argv = argv.dup
      @env = env
      @err = err
      @executor = executor
      @out = out
      @options = {}
    end

    # @return [Integer] exit status: 0 ok, 1 harness error or failed validation, 2 usage error
    def run
      parse!
      return 0 if @options[:help]

      corpus = Corpus.new(@options.fetch(:corpus, FIXTURE_CORPUS))
      tasks = ComplianceTasks.new(corpus:, path: @options.fetch(:tasks, DEFAULT_TASKS))
      compliance_run(corpus, tasks).dry_run
    rescue OptionParser::ParseError => e
      @err.puts "compliance: #{e.message}"
      2
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
        o.on('--dry-run', 'Validate tasks and workspaces, print the claude commands (default)') do
          @options[:dry_run] = true
        end
        o.on('--model ID', "Model for claude -p (default: #{ClaudeCommand::DEFAULT_MODEL})") { |v| @options[:model] = v }
        o.on('--tasks FILE', 'Task suite (default: bench/compliance/tasks.yml)') { |v| @options[:tasks] = v }
        o.on('--corpus DIR', 'Rules corpus with recipes.yml (default: bench/fixtures/corpus)') do |v|
          @options[:corpus] = v
        end
        o.on('--max-budget-usd N', Float, "Per-call cap passed to claude (default: #{DEFAULT_MAX_BUDGET_USD})") do |v|
          raise OptionParser::InvalidArgument, "--max-budget-usd must be positive, got #{v}" unless v.positive?

          @options[:max_budget_usd] = v
        end
        o.on('--claude-bin NAME', 'claude executable (default: claude)') { |v| @options[:claude_bin] = v }
        o.on('-h', '--help', 'Show this help') do
          @out.puts o
          @options[:help] = true
        end
      end
    end

    def compliance_run(corpus, tasks)
      ComplianceRun.new(claude_bin: @options.fetch(:claude_bin, 'claude'), corpus:, executor: @executor,
                        max_budget_usd: @options.fetch(:max_budget_usd, DEFAULT_MAX_BUDGET_USD),
                        model: @options.fetch(:model, ClaudeCommand::DEFAULT_MODEL), out: @out, tasks:)
    end
  end
end
