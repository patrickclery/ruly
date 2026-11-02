# frozen_string_literal: true

module RulyBench
  # One compliance benchmark run over two conditions: `ruly` (the outputs of `ruly squash RECIPE`) and `native`
  # (the native Claude Code layout of the same corpus). A dry run builds both workspaces per task, locates the
  # rule in each and prints the claude commands a live run would make, without calling claude.
  class ComplianceRun
    CONDITIONS = %w[ruly native].freeze
    SEARCH = {
      'native' => ['.claude/rules/**/*', '.claude/skills/**/*', '.claude/commands/**/*'],
      'ruly' => ['CLAUDE.local.md', '.claude/skills/**/*', '.claude/commands/**/*']
    }.freeze
    WORKSPACE_ENTRIES = %w[.claude CLAUDE.local.md].freeze

    attr_reader :corpus, :env, :executor, :out, :tasks

    # @param corpus [RulyBench::Corpus]
    # @param tasks [RulyBench::ComplianceTasks]
    # @param model [String] model id passed to claude
    # @param max_budget_usd [Numeric] per-call cap passed to claude
    # @param claude_bin [String] claude executable
    # @param executor [#call] `call(env, argv, stdin_data:, chdir:)` returning [stdout, stderr, status]
    # @param out [IO]
    # @param env [Hash] environment overrides for claude (never written anywhere)
    def initialize(claude_bin:, corpus:, executor:, max_budget_usd:, model:, out:, tasks:, env: {})
      @corpus = corpus
      @tasks = tasks
      @argv = ClaudeCommand.argv(claude_bin:, max_budget_usd:, model:)
      @model = model
      @executor = executor
      @out = out
      @env = env
    end

    # Validate the suite, build both workspaces per task, locate each rule and score the canned replies.
    # @return [Integer] 0 when there is no problem, else 1
    def dry_run
      list = tasks.tasks
      out.puts "DRY RUN: #{list.size} tasks x #{CONDITIONS.size} conditions (no API calls)"
      problems = tasks.suite_problems
      with_workspaces(list) do |workspaces|
        problems.concat(workspace_problems(workspaces))
        list.each { |task| problems.concat(dry_run_task(task, workspaces)) }
      end
      finish_dry_run(problems, list.size)
    end

    private

    # Yields {'native' => dir, 'ruly' => {recipe => dir}}; the temp dirs are removed when the block returns.
    def with_workspaces(list, &)
      Dir.mktmpdir('ruly-compliance') do |root|
        native = File.join(root, 'native')
        FileUtils.mkdir_p(native)
        NativeLayout.build(corpus:, into: native)
        recipes = list.filter_map { |t| t['recipe'].to_s if t.is_a?(Hash) }.uniq.select { corpus.recipes.key?(_1) }
        ruly = recipes.each_with_index.to_h do |recipe, i|
          [recipe, ruly_workspace(File.join(root, "ruly-#{i}"), recipe)]
        end
        yield({'native' => native, 'ruly' => ruly})
      end
    end

    # The ruly condition holds only what `ruly squash RECIPE` writes for Claude Code: CLAUDE.local.md and .claude/.
    def ruly_workspace(dir, recipe)
      FileUtils.mkdir_p(dir)
      SquashRunner.run(corpus_dir: corpus.dir, recipe:) do |result|
        WORKSPACE_ENTRIES.each do |entry|
          source = File.join(result['workdir'], entry)
          FileUtils.cp_r(source, dir) if File.exist?(source)
        end
      end
      dir
    end

    def workspace_problems(workspaces)
      named = [['native', workspaces['native']]] + workspaces['ruly'].map { |recipe, dir| ["ruly #{recipe}", dir] }
      named.flat_map do |name, dir|
        (Dir.children(dir) - WORKSPACE_ENTRIES).sort.map { |entry| "#{name} workspace holds unexpected #{entry}" }
      end
    end

    def dry_run_task(task, workspaces)
      problems = tasks.task_problems(task)
      return problems.each { |p| out.puts "[FAIL] #{p}" } unless task.is_a?(Hash)

      locations = CONDITIONS.to_h { |c| [c, locate(workspace(workspaces, task, c), c, task['rule_marker'])] }
      locations.each { |c, loc| problems << "#{task['id']}: rule_marker not found in the #{c} workspace" unless loc }
      out.puts status_line(task, locations, problems.empty?)
      CONDITIONS.each { |c| out.puts "would run: #{Shellwords.join(@argv)} < prompt  (cwd: #{c} workspace)" }
      problems
    end

    # @return [Array(String, String), nil] the first file holding the marker and how Claude Code loads it
    def locate(dir, condition, marker)
      marker = marker.to_s.strip
      return nil if dir.nil? || marker.empty?

      rel = Dir.glob(SEARCH.fetch(condition), base: dir).find do |r|
        path = File.join(dir, r)
        File.file?(path) && File.read(path).include?(marker)
      end
      rel && [rel, load_label(dir, rel)]
    end

    def load_label(dir, rel)
      return 'skill' if rel.start_with?('.claude/skills/')
      return 'command' if rel.start_with?('.claude/commands/')

      frontmatter, = Ruly::Services::FrontmatterParser.parse(File.read(File.join(dir, rel)))
      path_rule = rel.start_with?('.claude/rules/') && frontmatter.is_a?(Hash) && frontmatter.key?('paths')
      path_rule ? 'path-scoped' : 'always'
    end

    def workspace(workspaces, task, condition)
      condition == 'native' ? workspaces['native'] : workspaces['ruly'][task['recipe'].to_s]
    end

    def status_line(task, locations, passed)
      where = CONDITIONS.map do |c|
        loc = locations[c]
        "#{c}: #{loc ? "#{loc[0]} (#{loc[1]})" : 'not found'}"
      end
      "[#{passed ? 'ok' : 'FAIL'}] #{task['id']} #{task['recipe']} | #{where.join(' | ')}"
    end

    def finish_dry_run(problems, count)
      if problems.empty?
        out.puts "dry run ok: #{count} tasks, #{count * CONDITIONS.size} commands"
        return 0
      end

      out.puts "dry run failed: #{problems.size} problems"
      problems.each { |p| out.puts "problem: #{p}" }
      1
    end
  end
end
