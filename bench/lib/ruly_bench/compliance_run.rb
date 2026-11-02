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
    FIXTURE_NOTICE = '> These numbers come from the synthetic fixture corpus in `bench/fixtures/corpus`. ' \
                     'They are not a measurement of any real rules repository.'
    EXTERNAL_NOTICE = '> Local run on an external corpus. Not for committing; results stay in `bench/results/local`.'

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
      @max_budget_usd = max_budget_usd
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

    # Run every task under both conditions through the executor, score the replies and write
    # compliance.json and compliance.md to output_dir.
    # @param output_dir [String]
    # @return [Integer] 0 after writing the results, 1 when the suite is invalid (nothing is run)
    def live_run(output_dir:)
      problems = tasks.validate
      return report_problems('live run aborted', problems) unless problems.empty?

      list = tasks.tasks
      out.puts live_header(list.size)
      rows = with_workspaces(list) { |workspaces| list.map { |task| live_task(task, workspaces) } }
      result = live_result(rows)
      write_results(result, output_dir)
      out.puts summary_line(result)
      out.puts "wrote #{File.join(output_dir, 'compliance.json')} and compliance.md"
      0
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
      return report_problems('dry run failed', problems) unless problems.empty?

      out.puts "dry run ok: #{count} tasks, #{count * CONDITIONS.size} commands"
      0
    end

    def report_problems(heading, problems)
      out.puts "#{heading}: #{problems.size} problems"
      problems.each { |p| out.puts "problem: #{p}" }
      1
    end

    def live_header(count)
      calls = count * CONDITIONS.size
      format('LIVE RUN: %<count>d tasks x %<conditions>d conditions = %<calls>d claude -p calls, model %<model>s, ' \
             'per-call cap $%<cap>.2f, worst case $%<worst>.2f',
             calls:, cap: @max_budget_usd, conditions: CONDITIONS.size, count:, model: @model,
             worst: calls * @max_budget_usd)
    end

    def live_task(task, workspaces)
      cells = CONDITIONS.to_h do |condition|
        cell = live_cell(task, workspace(workspaces, task, condition))
        out.puts "#{task['id']} #{condition}: #{cell_label(cell)} ($#{format('%.4f', cell['cost_usd'])})"
        [condition, cell]
      end
      {'id' => task['id'], 'native' => cells['native'], 'recipe' => task['recipe'], 'ruly' => cells['ruly']}
    end

    def live_cell(task, dir)
      stdout, _stderr, status = executor.call(env, @argv, chdir: dir, stdin_data: task['prompt'])
      parse_cell(stdout, status, task['checks'])
    rescue SystemCallError => e
      error_cell("could not run claude: #{e.class.name.split('::').last}")
    end

    # Reads claude's JSON output (`result`, `total_cost_usd`, `is_error`) and scores the reply.
    def parse_cell(stdout, status, checks)
      data = parse_json(stdout)
      cost = data.is_a?(Hash) ? data['total_cost_usd'].to_f : 0.0
      return error_cell("claude exited #{status.exitstatus}", cost) unless status.success?
      return error_cell('unparsable claude output') unless data.is_a?(Hash)
      return error_cell("claude reported an error (#{data['subtype']})", cost) if data['is_error']
      return error_cell('no result in claude output', cost) unless data['result'].is_a?(String)

      reply = data['result']
      score = Scorer.score(reply, checks)
      {'cost_usd' => cost, 'error' => nil, 'failed' => score[:failed], 'pass' => score[:pass], 'reply' => reply}
    end

    def parse_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      nil
    end

    def error_cell(message, cost = 0.0)
      {'cost_usd' => cost, 'error' => message, 'failed' => [], 'pass' => false, 'reply' => nil}
    end

    def cell_label(cell)
      return 'error' if cell['error']

      cell['pass'] ? 'pass' : 'fail'
    end

    def live_result(rows)
      {
        'conditions' => CONDITIONS.sort.to_h { |c| [c, condition_totals(rows, c)] },
        'corpus' => corpus.fixture? ? TokenBenchmark::FIXTURE_CORPUS_LABEL : 'external',
        'model' => @model,
        'schema' => 1,
        'tasks' => rows,
        'total_cost_usd' => rows.sum { |row| CONDITIONS.sum { |c| row[c]['cost_usd'] } }.round(6)
      }
    end

    def condition_totals(rows, condition)
      cells = rows.map { |row| row[condition] }
      {'errors' => cells.count { _1['error'] }, 'passed' => cells.count { _1['pass'] }, 'total' => cells.size}
    end

    def write_results(result, output_dir)
      FileUtils.mkdir_p(output_dir)
      File.write(File.join(output_dir, 'compliance.json'), "#{JSON.pretty_generate(result)}\n")
      File.write(File.join(output_dir, 'compliance.md'), markdown(result))
    end

    def markdown(result)
      lines = ["# Compliance benchmark: #{result['model']}", '',
               result['corpus'] == TokenBenchmark::FIXTURE_CORPUS_LABEL ? FIXTURE_NOTICE : EXTERNAL_NOTICE, '',
               'One sample per task and condition: these counts are not statistically significant.', '',
               *conditions_lines, *results_lines(result), *failure_lines(result),
               '## Totals', '', *CONDITIONS.map { |c| "- #{totals_text(c, result['conditions'][c])}" }, '',
               "Total cost: $#{format('%.4f', result['total_cost_usd'])} (model `#{result['model']}`).", '']
      lines.join("\n")
    end

    def conditions_lines
      [
        '## Conditions', '',
        '- **ruly**: `claude -p` in a workspace holding only the outputs of `ruly squash RECIPE` ' \
        '(CLAUDE.local.md and .claude/).',
        '- **native**: `claude -p` in a workspace holding the native Claude Code layout of the same corpus ' \
        '(.claude/rules/ with `paths:` kept, .claude/skills/, .claude/commands/).', ''
      ]
    end

    def results_lines(result)
      rows = result['tasks'].map do |row|
        "| #{row['id']} | #{row['recipe']} | #{cell_label(row['ruly'])} | #{cell_label(row['native'])} |"
      end
      ['## Results', '', '| Task | Recipe | ruly | native |', '|---|---|---|---|', *rows, '']
    end

    def failure_lines(result)
      items = result['tasks'].flat_map do |row|
        CONDITIONS.filter_map do |c|
          cell = row[c]
          next if cell['pass']

          detail = cell['error'] || cell['failed'].map { "`#{_1}`" }.join(', ')
          "- #{row['id']} (#{c}): #{cell_label(cell)}: #{detail}"
        end
      end
      items.empty? ? [] : ['## Failures', '', *items, '']
    end

    def totals_text(condition, totals)
      "#{condition}: #{totals['passed']}/#{totals['total']} passed, #{totals['errors']} errors"
    end

    def summary_line(result)
      totals = CONDITIONS.map { |c| totals_text(c, result['conditions'][c]) }
      "#{totals.join('; ')}; total cost $#{format('%.4f', result['total_cost_usd'])}"
    end
  end
end
