# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench do
  let(:dir) { Dir.mktmpdir('ruly-bench-corpus') }
  let(:fake_output) { {'claude_local_md' => "# Rules\n\nKeep it small.\n", 'descriptors' => ['helper: Help out.']} }

  after { FileUtils.rm_rf(dir) }

  def write(rel, content, root: dir)
    path = File.join(root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def write_small_corpus(path_rule: true)
    write('core/a.md', "# Principles\n\nPrefer small, reviewable changes over large ones.\n")
    write('core/b.md', "# Communication\n\nPost a short status update when a task changes state.\n")
    if path_rule
      write('web/view.md', "---\npaths:\n  - \"**/*.tsx\"\n---\n# Views\n\nViews render data and hold no logic.\n")
    end
    write('skills/helper.md', "---\nname: helper\ndescription: Help out.\n---\n# Helper\n\n" \
                              "Gather the facts, list the options, pick one and explain the choice in two lines.\n")
    write('recipes.yml', "recipes:\n  demo:\n    description: Demo\n    files:\n      - core/a.md\n    " \
                         "skills:\n      - skills/helper.md\n")
  end

  def stub_squash(output)
    allow(RulyBench::SquashRunner).to receive(:run) { |**, &block| block.call(output) }
  end

  describe RulyBench::TokenBenchmark do
    describe 'on a small tmp corpus with a real squash' do
      it 'orders the baselines and computes reductions from ruly_total' do
        write_small_corpus
        benchmark = described_class.new(corpus: RulyBench::Corpus.new(dir), label: 'spec')
        row = benchmark.result['recipes'].first

        expect(row['name']).to eq('demo')
        expect(row['native_ceiling']).to be > row['native_floor']
        expect(row['load_all']).to eq(row['native_ceiling'])
        expect(row['ruly_descriptors']).to be > 0
        expect(row['ruly_total']).to eq(row['ruly_body'] + row['ruly_descriptors'])
        %w[load_all native_floor native_ceiling].each do |base|
          expected = ((row[base] - row['ruly_total']) * 100.0 / row[base]).round(1)
          expect(row["reduction_vs_#{base}_pct"]).to eq(expected)
        end
        expect(benchmark.result['corpus']).to eq('external')
        expect(benchmark.result['skipped']).to eq([])
      end
    end

    it 'discloses files no measured recipe includes and the baselines without them' do
      write_small_corpus
      corpus = RulyBench::Corpus.new(dir)
      result = described_class.new(corpus:, label: 'spec').result
      excl = result['excluding_unreferenced']
      a_tokens = RulyBench::TokenCounter.count(corpus.body('core/a.md'))
      descriptor = RulyBench::TokenCounter.count('helper: Help out.')

      expect(excl['files']).to eq(%w[core/b.md web/view.md])
      expect(result['corpus_stats']['unreferenced_files']).to eq(2)
      expect(excl['tokens']).to eq(%w[core/b.md web/view.md].sum { RulyBench::TokenCounter.count(corpus.body(_1)) })
      expect(excl['baselines']).to eq('load_all' => a_tokens + descriptor, 'native_ceiling' => a_tokens + descriptor,
                                      'native_floor' => a_tokens + descriptor)
      expect(excl['summary']['reduction_vs_native_floor_pct']['median'])
        .to be < result['summary']['reduction_vs_native_floor_pct']['median']
      expect(described_class.new(corpus:, label: 'spec').to_markdown)
        .to include('2 corpus files are in no measured recipe\'s output: `core/b.md`, `web/view.md`')
    end

    it 'counts skills and commands by descriptor in load-all, never by body' do
      write_small_corpus
      stub_squash(fake_output)
      corpus = RulyBench::Corpus.new(dir)
      row = described_class.new(corpus:, label: 'spec').result['recipes'].first
      bodies = %w[core/a.md core/b.md web/view.md].map { corpus.body(_1) }
      rule_bodies = RulyBench::TokenCounter.count(corpus.concat(bodies))
      descriptor = RulyBench::TokenCounter.count('helper: Help out.')

      expect(row['load_all']).to eq(rule_bodies + descriptor)
    end

    it 'gives native_ceiling == native_floor when the corpus has no path rule' do
      write_small_corpus(path_rule: false)
      stub_squash(fake_output)
      row = described_class.new(corpus: RulyBench::Corpus.new(dir), label: 'spec').result['recipes'].first
      expect(row['native_ceiling']).to eq(row['native_floor'])
    end

    it 'reports a negative reduction when the ruly output is larger' do
      expect(described_class.reduction(100, 150)).to eq(-50.0)
      expect(described_class.reduction(300, 100)).to eq(66.7)
    end

    it 'takes the median of an even count as the mean of the middle two' do
      expect(described_class.median([1.0, 2.0, 4.0, 10.0])).to eq(3.0)
    end

    it 'takes the median of an odd count as the middle value' do
      expect(described_class.median([5.0, 1.0, 3.0])).to eq(3.0)
    end

    it 'skips recipes with remote sources without running squash' do
      write_small_corpus
      write('recipes.yml', "recipes:\n  demo:\n    files:\n      - core/a.md\n  " \
                           "remote:\n    files:\n      - https://github.com/acme/rules/blob/main/x.md\n  " \
                           "sourced:\n    sources:\n      - github: acme/rules\n")
      stub_squash(fake_output)
      result = described_class.new(corpus: RulyBench::Corpus.new(dir), label: 'spec').result

      expect(RulyBench::SquashRunner).to have_received(:run).once
      expect(RulyBench::SquashRunner).to have_received(:run).with(corpus_dir: File.expand_path(dir), recipe: 'demo')
      expect(result['recipes'].map { |r| r['name'] }).to eq(%w[demo])
      expect(result['skipped']).to eq([{'name' => 'remote', 'reason' => 'remote sources'},
                                       {'name' => 'sourced', 'reason' => 'remote sources'}])
      expect(result['summary']['recipes']).to eq(1)
    end

    it 'moves a failed squash on an external corpus to skipped and continues' do
      write_small_corpus
      write('recipes.yml', "recipes:\n  broken:\n    files:\n      - core/a.md\n  " \
                           "demo:\n    files:\n      - core/a.md\n")
      allow(RulyBench::SquashRunner).to receive(:run) do |recipe:, **, &block|
        raise RulyBench::SquashRunner::SquashFailed.new('boom', 3) if recipe == 'broken'

        block.call(fake_output)
      end
      result = described_class.new(corpus: RulyBench::Corpus.new(dir), label: 'spec').result

      expect(result['skipped']).to eq([{'name' => 'broken', 'reason' => 'squash failed (exit 3)'}])
      expect(result['recipes'].map { |r| r['name'] }).to eq(%w[demo])
    end

    it 'raises on a failed squash of the fixture corpus' do
      allow(RulyBench::SquashRunner).to receive(:run).and_raise(RulyBench::SquashRunner::SquashFailed.new('boom', 3))
      benchmark = described_class.new(corpus: RulyBench::Corpus.new(RulyBench::FIXTURE_CORPUS), label: 'fixture',
                                      recipe_names: %w[ruby-feature])
      expect { benchmark.result }.to raise_error(RulyBench::SquashRunner::SquashFailed, /boom/)
    end

    it 'renders markdown with no absolute or temp paths' do
      write_small_corpus
      stub_squash(fake_output)
      benchmark = described_class.new(corpus: RulyBench::Corpus.new(dir), label: 'local')
      text = benchmark.to_json + benchmark.to_markdown

      expect(text).not_to include(dir)
      expect(text).not_to match(%r{/(home|Users|tmp)/})
      expect(benchmark.to_markdown).to start_with('# Token benchmark: local corpus')
    end
  end

  describe RulyBench::SquashRunner do
    let(:status) { instance_double(Process::Status, exitstatus: 0, success?: true) }

    before { allow(Open3).to receive(:capture2e).and_return(['', status]) }

    ['has space', 'a/b', 'x;rm -rf .', ''].each do |name|
      it "refuses the recipe name #{name.inspect} without running a subprocess" do
        expect { described_class.run(corpus_dir: dir, recipe: name) { nil } }.to raise_error(RulyBench::Error)
        expect(Open3).not_to have_received(:capture2e)
      end
    end

    it 'runs bin/ruly squash as an argv array with isolated HOME and RULY_HOME' do
      write_small_corpus
      described_class.run(corpus_dir: dir, recipe: 'demo') { nil }

      expect(Open3).to have_received(:capture2e) do |env, *argv, chdir:|
        expect(env['HOME']).not_to eq(Dir.home)
        expect(env['HOME']).not_to eq(RulyBench::REPO_ROOT)
        expect(env['RULY_HOME']).not_to eq(Dir.home)
        expect(env['RULY_HOME']).not_to eq(RulyBench::REPO_ROOT)
        expect(env['RULY_HOME']).to eq(chdir)
        expect(env['BUNDLE_GEMFILE']).to eq(File.join(RulyBench::REPO_ROOT, 'Gemfile'))
        expect(argv).to eq([RbConfig.ruby, '-rbundler/setup', File.join(RulyBench::REPO_ROOT, 'bin/ruly'),
                            'squash', 'demo'])
      end
    end

    it 'ignores a stale .claude/ and CLAUDE.local.md left in an external corpus' do
      allow(Open3).to receive(:capture2e).and_call_original
      write_small_corpus
      write('recipes.yml', "recipes:\n  plain:\n    files:\n      - core/a.md\n")
      write('.claude/skills/stale/SKILL.md', "---\nname: stale\ndescription: Leftover skill.\n---\n# Stale\n")
      write('.claude/commands/old.md', "---\ndescription: Leftover command.\n---\n# Old\n")
      write('CLAUDE.local.md', "# Stale output\n\nLeftover text.\n")
      result = described_class.run(corpus_dir: dir, recipe: 'plain') { |out| out.except('workdir') }

      expect(result['descriptors']).to eq([])
      expect(result['claude_local_md']).not_to include('Leftover')
      expect(result['claude_local_md']).to include('Prefer small, reviewable changes')
    end

    it 'raises SquashFailed with the exit status when squash fails' do
      write_small_corpus
      failed = instance_double(Process::Status, exitstatus: 4, success?: false)
      allow(Open3).to receive(:capture2e).and_return(["line\n", failed])

      expect { described_class.run(corpus_dir: dir, recipe: 'demo') { nil } }.to raise_error(
        an_instance_of(RulyBench::SquashRunner::SquashFailed).and(having_attributes(exit_status: 4))
      )
    end
  end

  describe RulyBench::TokensCLI do
    let(:root) { Dir.mktmpdir('ruly-bench-root') }
    let(:err) { StringIO.new }
    let(:out) { StringIO.new }
    let(:fake_benchmark) do
      instance_double(RulyBench::TokenBenchmark,
                      result: {'recipes' => [], 'skipped' => [], 'summary' => summary},
                      to_json: "{}\n",
                      to_markdown: "# Token benchmark: local corpus\n")
    end
    let(:summary) do
      stat = {'max' => 0.0, 'median' => 0.0, 'min' => 0.0}
      {
        'recipes' => 0,
        'reduction_vs_load_all_pct' => stat,
        'reduction_vs_native_ceiling_pct' => stat,
        'reduction_vs_native_floor_pct' => stat
      }
    end

    before do
      write_small_corpus
      allow(RulyBench::TokenBenchmark).to receive(:new).and_return(fake_benchmark)
    end

    after { FileUtils.rm_rf(root) }

    def cli(*argv)
      described_class.new(argv, err:, out:, repo_root: root)
    end

    ['bench/results', 'bench/results/other', 'bench/results/localx', 'docs', '.'].each do |target|
      it "refuses (exit 2) to write a non-fixture corpus to #{target}" do
        status = cli('--corpus', dir, '--output-dir', File.join(root, target)).run

        expect(status).to eq(2)
        expect(err.string).to include('bench/results/local')
        expect(RulyBench::TokenBenchmark).not_to have_received(:new)
        expect(Dir.glob('**/*', base: root)).to eq([])
      end
    end

    it 'writes a non-fixture corpus to bench/results/local by default' do
      expect(cli('--corpus', dir).run).to eq(0)
      expect(File.read(File.join(root, 'bench/results/local/tokens.json'))).to eq("{}\n")
      expect(File).to exist(File.join(root, 'bench/results/local/tokens.md'))
      expect(RulyBench::TokenBenchmark).to have_received(:new).with(hash_including(label: 'local'))
    end

    it 'allows a non-fixture corpus to write inside bench/results/local' do
      expect(cli('--corpus', dir, '--output-dir', File.join(root, 'bench/results/local/run1')).run).to eq(0)
      expect(File).to exist(File.join(root, 'bench/results/local/run1/tokens.json'))
    end

    it 'allows a non-fixture corpus to write outside the repository' do
      outside = Dir.mktmpdir('ruly-bench-outside')
      expect(cli('--corpus', dir, '--output-dir', outside).run).to eq(0)
      expect(File).to exist(File.join(outside, 'tokens.json'))
    ensure
      FileUtils.rm_rf(outside)
    end

    it 'writes the fixture corpus to bench/results by default' do
      expect(cli.run).to eq(0)
      expect(File).to exist(File.join(root, 'bench/results/tokens.json'))
      expect(RulyBench::TokenBenchmark).to have_received(:new).with(hash_including(label: 'fixture'))
    end

    it 'returns 2 on an unknown --recipes name without measuring' do
      expect(cli('--corpus', dir, '--recipes', 'demo,dmeo').run).to eq(2)
      expect(err.string).to include('unknown recipe dmeo')
      expect(RulyBench::TokenBenchmark).not_to have_received(:new)
    end

    it 'measures a repeated --recipes name once' do
      expect(cli('--corpus', dir, '--recipes', 'demo,demo').run).to eq(0)
      expect(RulyBench::TokenBenchmark).to have_received(:new).with(hash_including(recipe_names: %w[demo]))
    end

    it 'returns 2 on an unknown option' do
      expect(cli('--bogus').run).to eq(2)
      expect(err.string).to include('--bogus')
    end

    it 'returns 1 on a harness error' do
      allow(RulyBench::TokenBenchmark).to receive(:new).and_raise(RulyBench::Error, 'bad corpus')
      expect(cli('--corpus', dir).run).to eq(1)
      expect(err.string).to include('bad corpus')
    end
  end
end
