# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.describe Ruly::CLI, '.start' do
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd
    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      # CRITICAL: Always return to original directory before ANY cleanup
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  def expect_unknown_switch(args, switch)
    expect do
      expect { described_class.start(args) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end.to output(/Unknown switches "#{Regexp.escape(switch)}"/).to_stderr
  end

  context 'with the removed --cache switch' do
    it 'rejects squash --cache' do
      expect_unknown_switch(%w[squash --cache], '--cache')
    end

    it 'rejects squash --no-cache' do
      expect_unknown_switch(%w[squash --no-cache], '--no-cache')
    end
  end

  context 'with the removed TaskMaster switches' do
    it 'rejects squash -T' do
      expect_unknown_switch(%w[squash -T], '-T')
    end

    it 'rejects squash --taskmaster-config' do
      expect_unknown_switch(%w[squash --taskmaster-config], '--taskmaster-config')
    end

    it 'rejects squash --keep-taskmaster' do
      expect_unknown_switch(%w[squash --keep-taskmaster], '--keep-taskmaster')
    end

    it 'rejects clean -T' do
      expect_unknown_switch(%w[clean -T], '-T')
    end
  end

  context 'when a .taskmaster/ directory exists' do
    before do
      FileUtils.mkdir_p('.claude')
      FileUtils.mkdir_p('.taskmaster')
    end

    it 'never lists .taskmaster/ in clean --deepclean --dry-run' do
      expect { described_class.start(%w[clean --deepclean --dry-run]) }
        .to output(a_string_including('.claude/').and(satisfy { |out| !out.include?('.taskmaster') })).to_stdout
    end
  end

  context 'with the removed shell_gpt agent' do
    let(:cli) { described_class.new }

    before do
      FileUtils.mkdir_p('rules')
      File.write('rules/demo.md', "# Demo Rule\n\nBody text.\n")
      allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'))
    end

    %w[sgpt shell_gpt].each do |agent|
      it "writes plain markdown for -a #{agent}" do
        cli.options = {agent:, output_file: 'role.json'}
        expect { cli.squash }.to output.to_stdout

        content = File.read('role.json')
        expect(content).to start_with('# Demo Rule')
        expect { JSON.parse(content) }.to raise_error(JSON::ParserError)
      end
    end

    it 'still normalizes claudecode to claude' do
      expect(cli.send(:normalize_agent, 'claudecode')).to eq('claude')
    end
  end

  context 'with kept switches' do
    it 'still parses clean --dry-run' do
      expect { described_class.start(%w[clean --dry-run]) }.to output(/Already clean/).to_stdout
    end
  end
end
