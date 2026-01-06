# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Ruly::CLI do
  describe 'requires deduplication' do
    let(:cli) { described_class.new }
    let(:temp_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(temp_dir)
    end

    describe '#get_source_key' do
      context 'with local files' do
        before do
          # Create a test file structure
          FileUtils.mkdir_p(File.join(temp_dir, 'rules', 'commands', 'bug'))
          File.write(File.join(temp_dir, 'rules', 'commands.md'), '# Commands')

          # Mock gem_root to use temp_dir
          allow(cli).to receive(:gem_root).and_return(temp_dir)
        end

        it 'normalizes different relative paths to the same file' do
          # Create sources pointing to the same file via different paths
          source1 = {path: 'rules/commands.md', type: 'local'}
          source2 = {path: './rules/commands.md', type: 'local'}

          # Mock find_rule_file to return the actual paths
          allow(cli).to receive(:find_rule_file).with('rules/commands.md')
            .and_return(File.join(temp_dir, 'rules', 'commands.md'))
          allow(cli).to receive(:find_rule_file).with('./rules/commands.md')
            .and_return(File.join(temp_dir, 'rules', 'commands.md'))

          key1 = cli.send(:get_source_key, source1)
          key2 = cli.send(:get_source_key, source2)

          # Both should resolve to the same absolute path
          expect(key1).to eq(key2)
          expect(key1).to eq(File.realpath(File.join(temp_dir, 'rules', 'commands.md')))
        end

        it 'handles parent directory references correctly' do
          # Simulate being in rules/commands/bug/ and referencing ../../commands.md
          source1 = {path: 'rules/commands.md', type: 'local'}
          source2 = {path: 'rules/commands/../../commands.md', type: 'local'}

          allow(cli).to receive(:find_rule_file).with('rules/commands.md')
            .and_return(File.join(temp_dir, 'rules', 'commands.md'))
          allow(cli).to receive(:find_rule_file).with('rules/commands/../../commands.md')
            .and_return(File.join(temp_dir, 'rules', 'commands.md'))

          key1 = cli.send(:get_source_key, source1)
          key2 = cli.send(:get_source_key, source2)

          expect(key1).to eq(key2)
        end

        it 'returns different keys for different files' do
          File.write(File.join(temp_dir, 'rules', 'other.md'), '# Other')

          source1 = {path: 'rules/commands.md', type: 'local'}
          source2 = {path: 'rules/other.md', type: 'local'}

          allow(cli).to receive(:find_rule_file).with('rules/commands.md')
            .and_return(File.join(temp_dir, 'rules', 'commands.md'))
          allow(cli).to receive(:find_rule_file).with('rules/other.md')
            .and_return(File.join(temp_dir, 'rules', 'other.md'))

          key1 = cli.send(:get_source_key, source1)
          key2 = cli.send(:get_source_key, source2)

          expect(key1).not_to eq(key2)
        end
      end

      context 'with remote files' do
        it 'uses the URL as the key' do
          source = {path: 'https://github.com/user/repo/blob/main/file.md', type: 'remote'}

          key = cli.send(:get_source_key, source)

          expect(key).to eq('https://github.com/user/repo/blob/main/file.md')
        end
      end
    end

    describe '#resolve_local_require' do
      before do
        # Create test file structure
        FileUtils.mkdir_p(File.join(temp_dir, 'rules', 'commands', 'bug'))
        FileUtils.mkdir_p(File.join(temp_dir, 'rules', 'ruby'))

        File.write(File.join(temp_dir, 'rules', 'commands.md'), '# Commands')
        File.write(File.join(temp_dir, 'rules', 'commands', 'bug', 'diagnose.md'), '# Diagnose')
        File.write(File.join(temp_dir, 'rules', 'ruby', 'common.md'), '# Common')

        allow(cli).to receive(:gem_root).and_return(temp_dir)
      end

      it 'resolves relative paths correctly from source directory' do
        # Simulate requiring ../../commands.md from rules/commands/bug/diagnose.md
        source_path = 'rules/commands/bug/diagnose.md'
        required_path = '../../commands.md'

        allow(cli).to receive(:find_rule_file).with(source_path)
          .and_return(File.join(temp_dir, source_path))

        result = cli.send(:resolve_local_require, source_path, required_path)

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq('local')
        expect(result[:path]).to eq('rules/commands.md')
      end

      it 'adds .md extension if missing' do
        source_path = 'rules/commands/bug/diagnose.md'
        required_path = '../../commands' # No .md extension

        allow(cli).to receive(:find_rule_file).with(source_path)
          .and_return(File.join(temp_dir, source_path))

        result = cli.send(:resolve_local_require, source_path, required_path)

        expect(result).to be_a(Hash)
        expect(result[:path]).to eq('rules/commands.md')
      end

      it 'returns canonical path for consistency' do
        source_path = 'rules/commands/bug/diagnose.md'
        # Path with redundant segments
        required_path = '../.././commands.md'

        allow(cli).to receive(:find_rule_file).with(source_path)
          .and_return(File.join(temp_dir, source_path))

        result = cli.send(:resolve_local_require, source_path, required_path)

        expect(result[:path]).to eq('rules/commands.md')
      end
    end

    describe 'integration: deduplication in squash' do
      before do
        # Create a more complex file structure with requires
        # Use different paths to avoid collision with real project files
        FileUtils.mkdir_p(File.join(temp_dir, 'test_rules', 'commands', 'bug'))
        FileUtils.mkdir_p(File.join(temp_dir, 'test_rules', 'ruby'))

        # Main commands file
        File.write(File.join(temp_dir, 'test_rules', 'commands.md'), <<~MD)
          ---
          description: Commands base file
          ---
          # Commands
          Base commands documentation
        MD

        # Bug diagnose that requires commands.md via relative path
        File.write(File.join(temp_dir, 'test_rules', 'commands', 'bug', 'diagnose.md'), <<~MD)
          ---
          description: Bug diagnosis
          requires:
            - ../../commands.md
          ---
          # Bug Diagnose
          Diagnosis documentation
        MD

        # Bug fix that also requires commands.md but via different path
        File.write(File.join(temp_dir, 'test_rules', 'commands', 'bug', 'fix.md'), <<~MD)
          ---
          description: Bug fix
          requires:
            - ../../commands.md
          ---
          # Bug Fix
          Fix documentation
        MD

        # Ruby file that requires commands via yet another path
        File.write(File.join(temp_dir, 'test_rules', 'ruby', 'example.md'), <<~MD)
          ---
          description: Ruby example
          requires:
            - ../commands.md
          ---
          # Ruby Example
          Example documentation
        MD

        allow(cli).to receive(:gem_root).and_return(temp_dir)
        allow(Dir).to receive(:pwd).and_return(temp_dir)
      end

      it 'includes commands.md only once despite multiple requires' do
        sources = [
          {path: 'test_rules/commands/bug/diagnose.md', type: 'local'},
          {path: 'test_rules/commands/bug/fix.md', type: 'local'},
          {path: 'test_rules/ruby/example.md', type: 'local'}
        ]

        # Process sources with requires
        local_sources, command_files, = cli.send(:process_sources_for_squash, sources, 'claude', {}, {})

        # Combine all sources for testing
        all_sources = local_sources + command_files

        # Count how many times commands.md appears
        commands_count = all_sources.count { |s| s[:path] == 'test_rules/commands.md' }

        # Should only appear once
        expect(commands_count).to eq(1)

        # All three original files should be present
        paths = all_sources.map { |s| s[:path] }
        expect(paths).to include('test_rules/commands/bug/diagnose.md')
        expect(paths).to include('test_rules/commands/bug/fix.md')
        expect(paths).to include('test_rules/ruby/example.md')
        expect(paths).to include('test_rules/commands.md')

        # Total should be 4 files (3 originals + 1 commands.md)
        expect(all_sources.size).to eq(4)
      end

      it 'processes files in correct dependency order' do
        sources = [{path: 'test_rules/commands/bug/diagnose.md', type: 'local'}]

        local_sources, command_files, = cli.send(:process_sources_for_squash, sources, 'claude', {}, {})

        # Combine all sources for testing
        all_sources = local_sources + command_files
        paths = all_sources.map { |s| s[:path] }

        # commands.md should come before diagnose.md since it's required by it
        commands_index = paths.index('test_rules/commands.md')
        diagnose_index = paths.index('test_rules/commands/bug/diagnose.md')

        expect(commands_index).to be < diagnose_index
      end
    end
  end
end
