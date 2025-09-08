# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'yaml'

RSpec.describe Ruly::CLI do
  let(:test_dir) { Dir.mktmpdir }
  let(:cli) { described_class.new }

  before do
    # Create test rules directory - use absolute paths
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'commands'))

    # Create test rule files - use absolute paths
    File.write(File.join(test_dir, 'rules', 'core', 'test.md'), "# Test Core Rule\nCore content")
    File.write(File.join(test_dir, 'rules', 'commands', 'test-command.md'), "# Test Command\nCommand content")

    # Mock gem_root - this needs to happen in before block, not around
    allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'))
  end

  around do |example|
    # Store the original directory
    original_dir = Dir.pwd

    begin
      # Change to test directory for the test
      Dir.chdir(test_dir)

      # Run the test
      example.run
    ensure
      # CRITICAL: Always return to original directory before ANY cleanup
      # This prevents bundler from losing its working directory
      Dir.chdir(original_dir)

      # Only NOW clean up the test directory
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe 'Recipe with local files only' do
    before do
      recipes = {
        'recipes' => {
          'local_only' => {
            'files' => [
              'rules/core/test.md',
              'rules/commands/test-command.md'
            ]
          }
        }
      }
      File.write('recipes.yml', recipes.to_yaml)
    end

    it 'loads all local files correctly' do
      sources, = cli.send(:load_recipe_sources, 'local_only')

      expect(sources.size).to eq(2)
      expect(sources.all? { |s| s[:type] == 'local' }).to be(true)
      expect(sources.map { |s| s[:path] }).to contain_exactly(
        'rules/core/test.md',
        'rules/commands/test-command.md'
      )
    end
  end

  describe 'Recipe with GitHub URLs' do
    before do
      recipes = {
        'recipes' => {
          'github_sources' => {
            'sources' => [
              'rules/core/test.md',
              'https://github.com/metabase/metabase/blob/master/.claude/commands/fix-issue.md',
              'https://raw.githubusercontent.com/anthropics/cookbook/main/prompts/guide.md'
            ]
          }
        }
      }
      File.write('recipes.yml', recipes.to_yaml)
    end

    it 'correctly identifies local and remote sources' do
      sources, = cli.send(:load_recipe_sources, 'github_sources')

      expect(sources.size).to eq(3)

      local_sources = sources.select { |s| s[:type] == 'local' }
      remote_sources = sources.select { |s| s[:type] == 'remote' }

      expect(local_sources.size).to eq(1)
      expect(remote_sources.size).to eq(2)

      # Check that GitHub blob URL is present
      github_source = remote_sources.find { |s| s[:path].include?('github.com') }
      expect(github_source).not_to be_nil

      # Check that raw GitHub URL is present
      raw_source = remote_sources.find { |s| s[:path].include?('raw.githubusercontent') }
      expect(raw_source).not_to be_nil
    end
  end

  describe 'Recipe with mixed sources array' do
    before do
      recipes = {
        'recipes' => {
          'mixed' => {
            'sources' => [
              'rules/core/test.md',
              'https://github.com/user/repo/blob/main/file1.md',
              'rules/commands/test-command.md',
              'https://example.com/file2.md'
            ]
          }
        }
      }
      File.write('recipes.yml', recipes.to_yaml)
    end

    it 'handles mixed local and remote sources in order' do
      sources, = cli.send(:load_recipe_sources, 'mixed')

      expect(sources.size).to eq(4)

      # Verify order is preserved
      expect(sources[0][:type]).to eq('local')
      expect(sources[1][:type]).to eq('remote')
      expect(sources[2][:type]).to eq('local')
      expect(sources[3][:type]).to eq('remote')
    end
  end

  describe 'Legacy format compatibility' do
    before do
      recipes = {
        'recipes' => {
          'legacy' => {
            'files' => ['rules/core/test.md'],
            'remote_sources' => [
              'https://github.com/user/repo/blob/main/remote.md'
            ]
          }
        }
      }
      File.write('recipes.yml', recipes.to_yaml)
    end

    it 'still supports separate files and remote_sources arrays' do
      sources, = cli.send(:load_recipe_sources, 'legacy')

      expect(sources.size).to eq(2)

      local_source = sources.find { |s| s[:type] == 'local' }
      expect(local_source[:path]).to eq('rules/core/test.md')

      remote_source = sources.find { |s| s[:type] == 'remote' }
      expect(remote_source[:path]).to include('github.com')
    end
  end

  describe 'Recipe with all formats combined' do
    before do
      recipes = {
        'recipes' => {
          'everything' => {
            'files' => ['rules/core/test.md'],
            'remote_sources' => ['https://legacy.com/old.md'],
            'sources' => [
              'rules/commands/test-command.md',
              'https://github.com/new/repo/blob/main/new.md'
            ]
          }
        }
      }
      File.write('recipes.yml', recipes.to_yaml)
    end

    it 'combines all three formats correctly' do
      sources, = cli.send(:load_recipe_sources, 'everything')

      expect(sources.size).to eq(4)

      # From 'files'
      expect(sources.any? { |s| s[:path] == 'rules/core/test.md' && s[:type] == 'local' }).to be(true)

      # From 'sources' (local)
      expect(sources.any? { |s| s[:path] == 'rules/commands/test-command.md' && s[:type] == 'local' }).to be(true)

      # From 'sources' (remote)
      expect(sources.any? { |s| s[:path].include?('github.com/new/repo') && s[:type] == 'remote' }).to be(true)

      # From 'remote_sources'
      expect(sources.any? { |s| s[:path] == 'https://legacy.com/old.md' && s[:type] == 'remote' }).to be(true)
    end
  end
end
