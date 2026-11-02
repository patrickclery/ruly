# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench do
  let(:dir) { Dir.mktmpdir('ruly-bench-compliance') }
  let(:corpus_dir) { File.join(dir, 'corpus') }
  let(:corpus) { RulyBench::Corpus.new(corpus_dir) }
  let(:tasks_path) { File.join(dir, 'tasks.yml') }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:ok_status) { double('status', exitstatus: 0, success?: true) }
  let(:base_task) do
    {
      'checks' => [{'pattern' => '[A-Z]{3,}', 'scope' => 'text', 'type' => 'forbid'}],
      'example_fail' => 'HELLO THERE',
      'example_pass' => 'hello there',
      'id' => 'no-shout',
      'prompt' => 'Say hello.',
      'recipe' => 'demo',
      'rule_file' => 'core/style.md',
      'rule_marker' => 'Never shout in replies.'
    }
  end

  after { FileUtils.rm_rf(dir) }

  def write(rel, content, root: corpus_dir)
    path = File.join(root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def write_corpus
    write('core/style.md', "# Style\n\nNever shout in replies.\n")
    write('web/views.md', "---\npaths:\n  - \"**/*.tsx\"\n---\n# Views\n\nViews hold no logic.\n")
    write('recipes.yml', "recipes:\n  demo:\n    description: Demo\n    files:\n      - core/\n")
  end

  def write_tasks(tasks)
    File.write(tasks_path, {'tasks' => tasks}.to_yaml)
  end

  def suite(tasks)
    write_corpus
    write_tasks(tasks)
    RulyBench::ComplianceTasks.new(corpus:, path: tasks_path)
  end

  # Squash replaced by a workdir holding a CLAUDE.local.md with the rule, so live specs need no subprocess.
  def stub_squash
    allow(RulyBench::SquashRunner).to receive(:run) do |**, &block|
      Dir.mktmpdir('ruly-bench-fake-squash') do |work|
        File.write(File.join(work, 'CLAUDE.local.md'), "# Style\n\nNever shout in replies.\n")
        block.call('claude_local_md' => '', 'descriptors' => [], 'workdir' => work)
      end
    end
  end

  def cli(argv, env: {}, executor: ->(*) { raise 'executor must not be called' })
    RulyBench::ComplianceCLI.new(argv, env:, err:, executor:, out:, repo_root: dir).run
  end

  describe RulyBench::ComplianceTasks do
    describe 'the committed suite' do
      fixture = RulyBench::Corpus.new(RulyBench::FIXTURE_CORPUS)
      committed = described_class.new(corpus: fixture, path: RulyBench::ComplianceCLI::DEFAULT_TASKS)

      it 'has eight tasks' do
        expect(committed.tasks.size).to eq(8)
      end

      committed.tasks.each do |task|
        it "validates #{task['id']} against the fixture corpus" do
          expect(committed.task_problems(task)).to eq([])
        end
      end

      it 'has no suite problems' do
        expect(committed.suite_problems).to eq([])
      end
    end

    it 'accepts a valid task' do
      expect(suite([base_task]).validate).to eq([])
    end

    it 'rejects more than ten tasks' do
      tasks = (1..11).map { |i| base_task.merge('id' => "task-#{i}") }
      expect(suite(tasks).validate).to include('expected 1 to 10 tasks, found 11')
    end

    it 'rejects a duplicate id' do
      expect(suite([base_task, base_task]).validate).to include('duplicate task id no-shout')
    end

    it 'rejects an unknown recipe' do
      expect(suite([base_task.merge('recipe' => 'nope')]).validate).to include('no-shout: unknown recipe nope')
    end

    it 'rejects a rule_marker that is not a whole line of rule_file' do
      problems = suite([base_task.merge('rule_marker' => 'Never shout')]).validate
      expect(problems).to include('no-shout: rule_marker is not a line of core/style.md')
    end

    it 'rejects a pattern that does not compile' do
      task = base_task.merge('checks' => [{'pattern' => '(', 'scope' => 'text', 'type' => 'forbid'}])
      expect(suite([task]).validate.join("\n")).to include('does not compile')
    end

    it 'rejects an example_fail that passes every check' do
      expect(suite([base_task.merge('example_fail' => 'quiet')]).validate)
        .to include('no-shout: example_fail passes every check')
    end

    it 'rejects a prompt that contains the rule_marker, ignoring case' do
      task = base_task.merge('prompt' => 'Say hello. never shout in replies.')
      expect(suite([task]).validate).to include('no-shout: prompt contains the rule_marker')
    end
  end

  describe RulyBench::ClaudeCommand do
    it 'builds the exact argv for the defaults' do
      argv = described_class.argv(max_budget_usd: 0.5, model: described_class::DEFAULT_MODEL)
      expect(argv).to eq(['claude', '-p', '--model', 'claude-sonnet-5-5', '--output-format', 'json',
                          '--setting-sources', 'project,local', '--no-session-persistence', '--max-budget-usd',
                          '0.50', '--disallowedTools', 'Edit,Write,Bash,NotebookEdit'])
    end

    it 'rejects a model id with a space or a semicolon' do
      ['claude sonnet', 'claude;rm'].each do |model|
        expect { described_class.argv(max_budget_usd: 0.5, model:) }.to raise_error(RulyBench::Error, /model/)
      end
    end

    it 'reports a missing flag by name' do
      help = "-p, --print\n--model <m>\n--output-format\n--setting-sources\n--max-budget-usd\n--disallowedTools\n"
      expect(described_class.check_cli(help)).to eq(['--no-session-persistence is not listed'])
    end

    it 'passes when --print and every flag are listed' do
      help = (['-p, --print'] + described_class::FLAGS.map { "#{_1} <x>" }).join("\n")
      expect(described_class.check_cli(help)).to eq([])
    end
  end

  describe RulyBench::ComplianceCLI do
    it 'dry-runs a valid one-task suite with a real squash and never calls the executor' do
      write_corpus
      write_tasks([base_task])

      status = cli(['--corpus', corpus_dir, '--tasks', tasks_path])

      expect(status).to eq(0)
      lines = out.string.lines.map(&:chomp)
      expect(lines.first).to eq('DRY RUN: 1 tasks x 2 conditions (no API calls)')
      expect(lines).to include(a_string_starting_with('[ok] no-shout demo | ruly: CLAUDE.local.md (always)'))
      expect(lines.grep(/\Awould run: claude -p /).size).to eq(2)
      expect(lines.last).to eq('dry run ok: 1 tasks, 2 commands')
    end

    it 'refuses --live together with --dry-run' do
      expect(cli(%w[--live --dry-run])).to eq(2)
    end

    it 'refuses --check-cli in a live run' do
      expect(cli(%w[--live --check-cli])).to eq(2)
    end

    it 'refuses --live on a non-fixture corpus without --allow-private-corpus' do
      write_corpus
      write_tasks([base_task])
      expect(cli(['--live', '--corpus', corpus_dir, '--tasks', tasks_path])).to eq(2)
      expect(err.string).to include('--allow-private-corpus')
    end

    it 'refuses --isolated-home without ANTHROPIC_API_KEY' do
      expect(cli(%w[--isolated-home], env: {'ANTHROPIC_API_KEY' => ''})).to eq(2)
      expect(err.string).to include('ANTHROPIC_API_KEY')
    end

    it 'refuses a non-fixture live run writing to bench/results outside bench/results/local' do
      write_corpus
      write_tasks([base_task])
      argv = ['--live', '--allow-private-corpus', '--corpus', corpus_dir, '--tasks', tasks_path,
              '--output-dir', File.join(dir, 'bench/results')]
      expect(cli(argv)).to eq(2)
      expect(err.string).to include('bench/results/local')
    end

    it 'refuses a non-fixture live run writing to a tracked repo path such as docs' do
      write_corpus
      write_tasks([base_task])
      argv = ['--live', '--allow-private-corpus', '--corpus', corpus_dir, '--tasks', tasks_path,
              '--output-dir', File.join(dir, 'docs')]
      expect(cli(argv)).to eq(2)
      expect(err.string).to include('outside the repository')
    end

    it 'rejects an unknown --only id' do
      write_corpus
      write_tasks([base_task])
      expect(cli(['--corpus', corpus_dir, '--tasks', tasks_path, '--only', 'nope'])).to eq(2)
    end

    describe 'a live run with a fake executor' do
      let(:output_dir) { File.join(dir, 'bench/results/local') }
      let(:calls) { [] }
      let(:executor) do
        lambda do |env, argv, chdir:, stdin_data:|
          calls << {argv:, chdir:, env:, stdin_data:}
          ruly = File.exist?(File.join(chdir, 'CLAUDE.local.md'))
          if stdin_data == 'Say hello.'
            reply = ruly ? 'hello there' : 'HELLO THERE'
            [{is_error: false, result: reply, total_cost_usd: 0.01}.to_json, '', ok_status]
          elsif ruly
            ['not json', '', ok_status]
          else
            [{is_error: true, subtype: 'error_max_budget_usd', total_cost_usd: 0.5}.to_json, '',
             double('status', exitstatus: 1, success?: false)]
          end
        end
      end
      let(:argv) do
        ['--live', '--allow-private-corpus', '--corpus', corpus_dir, '--tasks', tasks_path, '--output-dir', output_dir]
      end

      before do
        write_corpus
        write_tasks([base_task, base_task.merge('id' => 'no-shout-bye', 'prompt' => 'Say bye.')])
        stub_squash
      end

      it 'prints the cost line before any call' do
        cli(argv, executor:)
        expect(out.string.lines.first.chomp).to eq('LIVE RUN: 2 tasks x 2 conditions = 4 claude -p calls, ' \
                                                   'model claude-sonnet-5-5, per-call cap $0.50, worst case $2.00')
      end

      it 'passes the prompt on stdin, the workspace as chdir and never the prompt in argv' do
        expect(cli(argv, executor:)).to eq(0)
        expect(calls.size).to eq(4)
        expect(calls.map { _1[:stdin_data] }.uniq).to eq(['Say hello.', 'Say bye.'])
        expect(calls.map { _1[:chdir] }.uniq.size).to eq(2)
        calls.each { |call| expect(call[:argv].join(' ')).not_to include('Say') }
      end

      it 'scores each condition and records errors' do
        cli(argv, executor:)
        result = JSON.parse(File.read(File.join(output_dir, 'compliance.json')))

        expect(result.keys).to eq(%w[conditions corpus model schema tasks total_cost_usd])
        expect(result['conditions']).to eq('native' => {'errors' => 1, 'passed' => 0, 'total' => 2},
                                           'ruly' => {'errors' => 1, 'passed' => 1, 'total' => 2})
        hello, bye = result['tasks']
        expect(hello['ruly']).to include('error' => nil, 'pass' => true, 'reply' => 'hello there')
        expect(hello['native']).to include('failed' => ['forbid text /[A-Z]{3,}/'], 'pass' => false)
        expect(bye['ruly']).to include('error' => 'unparsable claude output', 'pass' => false)
        expect(bye['native']['error']).to include('exited 1')
        expect(result['total_cost_usd']).to eq(0.52)
        expect(result['corpus']).to eq('external')
        expect(result['schema']).to eq(1)
      end

      it 'writes compliance.md with the title, totals and the significance caveat' do
        cli(argv, executor:)
        md = File.read(File.join(output_dir, 'compliance.md'))

        expect(md).to start_with("# Compliance benchmark: claude-sonnet-5-5\n")
        expect(md).to include('| no-shout | demo | pass | fail |')
        expect(md).to include('ruly: 1/2 passed, 1 errors')
        expect(md).to include('not statistically significant')
      end

      it 'runs claude with a temp HOME under --isolated-home and never writes the key' do
        key = 'sk-ant-spec-secret-0123'
        expect(cli(argv + ['--isolated-home'], env: {'ANTHROPIC_API_KEY' => key}, executor:)).to eq(0)

        homes = calls.map { _1[:env]['HOME'] }.uniq
        expect(homes.size).to eq(1)
        expect(homes.first).not_to eq(Dir.home)
        calls.each { |call| expect(call[:env].values).not_to include(key) }
        written = Dir.glob('**/*', base: output_dir).map { File.read(File.join(output_dir, _1)) }.join
        expect(out.string + err.string + written).not_to include(key)
      end

      it 'runs only the tasks named by --only' do
        cli(argv + ['--only', 'no-shout-bye'], executor:)
        expect(calls.map { _1[:stdin_data] }.uniq).to eq(['Say bye.'])
      end
    end
  end
end
