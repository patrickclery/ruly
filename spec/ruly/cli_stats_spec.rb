# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::CLI, '#stats' do
  let(:test_dir) { Dir.mktmpdir }
  let(:cli) { described_class.new }

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

  context 'when no recipe source is configured' do
    before do
      FileUtils.mkdir_p('rules')
      File.write('rules/demo.md', "# Demo Rule\n\nBody text.\n")
      allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'missing.yml'))
      allow(Ruly::Services::RemoteSync).to receive(:remotes_dir).and_return(File.join(test_dir, 'remotes'))
      cli.options = {output: 'stats.md'}
    end

    it 'still writes stats.md for the local rule files' do
      expect do
        expect { cli.stats }.to output(/Generated .*stats\.md/).to_stdout
      end.to output(/Recipes not loaded, so recipe totals are skipped: No recipes found/).to_stderr

      expect(File.read(File.join(test_dir, 'rules', 'stats.md'))).to include('demo.md')
    end
  end
end
