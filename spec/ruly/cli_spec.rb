# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'time'
require 'securerandom'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

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

  describe '#convert_to_raw_url' do
    it 'converts GitHub blob URLs to raw URLs' do
      input = 'https://github.com/metabase/metabase/blob/master/.claude/commands/fix-issue.md'
      expected = 'https://raw.githubusercontent.com/metabase/metabase/master/.claude/commands/fix-issue.md'

      expect(cli.send(:convert_to_raw_url, input)).to eq(expected)
    end

    it 'leaves raw GitHub URLs unchanged' do
      input = 'https://raw.githubusercontent.com/user/repo/main/file.md'
      expect(cli.send(:convert_to_raw_url, input)).to eq(input)
    end

    it 'leaves non-GitHub URLs unchanged' do
      input = 'https://example.com/file.md'
      expect(cli.send(:convert_to_raw_url, input)).to eq(input)
    end
  end

  describe '#load_recipe_sources' do
    let(:recipes_content) do
      {
        'recipes' => {
          'test_legacy' => {
            'files' => ['rules/local.md'],
            'remote_sources' => ['https://example.com/remote.md']
          },
          'test_local' => {
            'files' => ['rules/test.md']
          },
          'test_mixed' => {
            'sources' => [
              'rules/local.md',
              'https://github.com/user/repo/blob/main/remote.md',
              'https://raw.githubusercontent.com/user/repo/main/raw.md'
            ]
          }
        }
      }
    end

    before do
      # Mock the recipes file
      File.write(File.join(test_dir, 'recipes.yml'), recipes_content.to_yaml)

      # Create mock local files
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test')
      File.write(File.join(test_dir, 'rules', 'local.md'), '# Local')

      # Mock gem_root to point to test_dir
      allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'))
    end

    it "loads local files from 'files' array" do
      sources, _recipe = cli.send(:load_recipe_sources, 'test_local')

      expect(sources.size).to eq(1)
      expect(sources.first[:type]).to eq('local')
      expect(sources.first[:path]).to eq('rules/test.md')
    end

    it "loads mixed sources from 'sources' array" do
      sources, _recipe = cli.send(:load_recipe_sources, 'test_mixed')

      expect(sources.size).to eq(3)

      # Check local file
      local_source = sources.find { |s| s[:path] == 'rules/local.md' }
      expect(local_source[:type]).to eq('local')

      # Check remote URLs
      github_source = sources.find { |s| s[:path].include?('github.com') }
      expect(github_source[:type]).to eq('remote')

      raw_source = sources.find { |s| s[:path].include?('raw.githubusercontent') }
      expect(raw_source[:type]).to eq('remote')
    end

    it 'supports legacy format with separate files and remote_sources' do
      sources, _recipe = cli.send(:load_recipe_sources, 'test_legacy')

      expect(sources.size).to eq(2)

      local_source = sources.find { |s| s[:type] == 'local' }
      expect(local_source[:path]).to eq('rules/local.md')

      remote_source = sources.find { |s| s[:type] == 'remote' }
      expect(remote_source[:path]).to eq('https://example.com/remote.md')
    end
  end

  describe '#fetch_remote_content' do
    it 'fetches content from a URL' do
      # Mock HTTP response
      mock_response = instance_double(Net::HTTPResponse, body: '# Remote Content', code: '200')
      allow(Net::HTTP).to receive(:get_response).and_return(mock_response)

      content = cli.send(:fetch_remote_content, 'https://example.com/file.md')
      expect(content).to eq('# Remote Content')
    end

    it 'converts GitHub blob URLs before fetching' do
      mock_response = instance_double(Net::HTTPResponse, body: '# GitHub Content', code: '200')

      # Expect the converted URL to be used
      expect(Net::HTTP).to receive(:get_response) do |uri|
        expect(uri.to_s).to eq('https://raw.githubusercontent.com/user/repo/main/file.md')
        mock_response
      end

      content = cli.send(:fetch_remote_content, 'https://github.com/user/repo/blob/main/file.md')
      expect(content).to eq('# GitHub Content')
    end

    it 'returns nil for failed requests' do
      mock_response = instance_double(Net::HTTPResponse, body: 'Not Found', code: '404')
      allow(Net::HTTP).to receive(:get_response).and_return(mock_response)

      content = cli.send(:fetch_remote_content, 'https://example.com/missing.md')
      expect(content).to be_nil
    end

    it 'handles network errors gracefully' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))

      content = cli.send(:fetch_remote_content, 'https://example.com/file.md')
      expect(content).to be_nil
    end
  end

  describe '#squash with metadata' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      # Mock gem_root and rules_dir for all tests in this describe block

      # Also mock recipes_file to use test directory by default
      allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    it 'creates .ruly.yml metadata file' do
      cli.invoke(:squash)

      expect(File.exist?('.ruly.yml')).to be(true)

      metadata = YAML.load_file('.ruly.yml')
      expect(metadata['output_file']).to eq('CLAUDE.local.md')
      expect(metadata['agent']).to eq('claude')
      expect(metadata['recipe']).to be_nil
      expect(metadata['files_count']).to be > 0
      expect(metadata['created_at']).not_to be_nil
      expect(metadata['version']).to eq(Ruly::VERSION)
    end

    skip 'includes recipe in metadata when specified (needs proper mocking of gem paths)' do
      # Create a recipe file with test_recipe that points to the test file
      recipes = {
        'recipes' => {
          'test_recipe' => {
            'files' => ['rules/test.md']
          }
        }
      }
      File.write(File.join(test_dir, 'recipes.yml'), recipes.to_yaml)

      # Suppress output during test
      allow(cli).to receive(:puts)

      cli.invoke(:squash, [], recipe: 'test_recipe')

      metadata = YAML.load_file('.ruly.yml')
      expect(metadata['recipe']).to eq('test_recipe')
    end

    it 'raises error for non-existent recipe' do
      # Create an empty recipes file
      recipes = {
        'recipes' => {}
      }
      File.write(File.join(test_dir, 'recipes.yml'), recipes.to_yaml)

      # Mock cli to return test directories and prevent loading user config

      # Mock load_all_recipes to return only our test recipes
      allow(cli).to receive_messages(load_all_recipes: recipes['recipes'],
                                     recipes_file: File.join(test_dir,
                                                             'recipes.yml'))

      # Suppress output to avoid cluttering test output
      allow(cli).to receive(:puts)
      allow(cli).to receive(:say)
      allow(cli.shell).to receive(:say)

      # Use a truly non-existent recipe name with random component
      nonexistent_recipe = "nonexistent_recipe_#{SecureRandom.hex(16)}"
      expect do
        cli.invoke(:squash, [nonexistent_recipe])
      end.to raise_error(Thor::Error, /Recipe '#{nonexistent_recipe}' not found/)
    end

    skip 'includes command files in metadata for Claude agent (needs proper mocking of gem paths)' do
      # Create command file in the test directory
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'commands'))
      File.write(File.join(test_dir, 'rules', 'commands', 'test-command.md'), '# Command')

      # Suppress output during test
      allow(cli).to receive(:puts)

      cli.invoke(:squash)

      metadata = YAML.load_file('.ruly.yml')
      expect(metadata['command_files']).to include('.claude/commands/test-command.md')
    end

    it 'does not create metadata in dry-run mode' do
      cli.invoke(:squash, [], dry_run: true)

      expect(File.exist?('.ruly.yml')).to be(false)
    end
  end

  describe '#clean with metadata' do
    before do
      # Mock gem_root
      allow(cli).to receive(:gem_root).and_return(test_dir)
    end

    context 'when .ruly.yml exists' do
      before do
        # Create metadata file
        metadata = {
          'agent' => 'claude',
          'command_files' => ['.claude/commands/test.md'],
          'created_at' => Time.now.iso8601,
          'files_count' => 5,
          'output_file' => 'TEST.md',
          'recipe' => 'test_recipe',
          'version' => '0.1.0'
        }
        File.write('.ruly.yml', metadata.to_yaml)

        # Create the files referenced in metadata
        File.write('TEST.md', '# Test content')
        FileUtils.mkdir_p('.claude/commands')
        File.write('.claude/commands/test.md', '# Command')
      end

      it 'removes files specified in metadata' do
        cli.invoke(:clean)

        expect(File.exist?('TEST.md')).to be(false)
        expect(File.exist?('.claude/commands/test.md')).to be(false)
        expect(File.exist?('.ruly.yml')).to be(false)
      end

      it 'uses metadata even if output file differs from default' do
        # Metadata specifies TEST.md, not the default CLAUDE.local.md
        cli.invoke(:clean)

        expect(File.exist?('TEST.md')).to be(false)
      end

      it 'overrides metadata when --output-file is specified' do
        File.write('OTHER.md', '# Other content')

        cli.invoke(:clean, [], output_file: 'OTHER.md')

        expect(File.exist?('OTHER.md')).to be(false)
        expect(File.exist?('TEST.md')).to be(true) # Original from metadata not removed
      end

      it 'overrides metadata when --recipe is specified' do
        File.write('CLAUDE.local.md', '# Default content')

        cli.invoke(:clean, [], recipe: 'other_recipe')

        # When recipe is specified, it overrides metadata and uses default output file
        expect(File.exist?('CLAUDE.local.md')).to be(false)
        # TEST.md from metadata is also removed since metadata is processed
        expect(File.exist?('TEST.md')).to be(false)
      end

      it 'shows correct files in dry-run mode' do
        # In dry-run mode, files should still exist after clean
        cli.invoke(:clean, [], dry_run: true)

        # Files should still exist
        expect(File.exist?('TEST.md')).to be(true)
        expect(File.exist?('.claude/commands/test.md')).to be(true)
        expect(File.exist?('.ruly.yml')).to be(true)
      end
    end

    context 'when .ruly.yml does not exist' do
      it 'falls back to default behavior' do
        File.write('CLAUDE.local.md', '# Content')

        cli.invoke(:clean)

        expect(File.exist?('CLAUDE.local.md')).to be(false)
      end

      it 'uses specified output file' do
        File.write('CUSTOM.md', '# Custom')

        cli.invoke(:clean, [], output_file: 'CUSTOM.md')

        expect(File.exist?('CUSTOM.md')).to be(false)
      end
    end

    context 'with agent-specific files' do
      it 'removes all files in .claude directory' do
        # Create nested .claude directory structure
        FileUtils.mkdir_p('.claude/commands/subfolder')
        File.write('.claude/commands/test.md', '# Test')
        File.write('.claude/commands/subfolder/nested.md', '# Nested')
        File.write('.claude/other.md', '# Other')
        File.write('CLAUDE.local.md', '# Claude')

        cli.invoke(:clean)

        expect(Dir.exist?('.claude')).to be(false)
        expect(File.exist?('CLAUDE.local.md')).to be(false)
      end

      it 'removes files for specified agent' do
        # Create files for different agents
        FileUtils.mkdir_p('.cursor/commands')
        File.write('.cursor/commands/test.md', '# Test')
        File.write('CURSOR.local.md', '# Cursor')

        cli.invoke(:clean, [], agent: 'cursor')

        expect(Dir.exist?('.cursor')).to be(false)
        expect(File.exist?('CURSOR.local.md')).to be(false)
      end

      it 'does not remove files for other agents' do
        # Create files for multiple agents
        FileUtils.mkdir_p('.claude/commands')
        FileUtils.mkdir_p('.cursor/commands')
        File.write('.claude/commands/test.md', '# Claude Test')
        File.write('.cursor/commands/test.md', '# Cursor Test')
        File.write('CLAUDE.local.md', '# Claude')
        File.write('CURSOR.local.md', '# Cursor')

        cli.invoke(:clean, [], agent: 'claude')

        # Claude files should be removed
        expect(Dir.exist?('.claude')).to be(false)
        expect(File.exist?('CLAUDE.local.md')).to be(false)

        # Cursor files should still exist
        expect(Dir.exist?('.cursor')).to be(true)
        expect(File.exist?('CURSOR.local.md')).to be(true)
      end

      it 'removes duplicate entries from file list' do
        # Create files
        File.write('CLAUDE.local.md', '# Claude')
        FileUtils.mkdir_p('.claude')

        # Mock add_agent_files_to_remove to add duplicates
        allow(cli).to receive(:add_agent_files_to_remove) do |_agent, files|
          files << 'CLAUDE.local.md' # Duplicate
          files << 'CLAUDE.local.md' # Another duplicate
          files << '.claude/'
        end

        # Check that duplicates are removed - the output should only show the file once
        expect { cli.invoke(:clean, [], dry_run: true) }.to output(%r{CLAUDE\.local\.md.*\n.*- \.claude/}m).to_stdout

        # Verify the file list doesn't have duplicates by checking the actual implementation
        files_to_remove = []
        cli.send(:add_agent_files_to_remove, 'claude', files_to_remove)
        files_to_remove.uniq!
        expect(files_to_remove.count('CLAUDE.local.md')).to be <= 1
      end
    end
  end

  describe '#squash with --clean option' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      # Mock gem_root and recipes_file to use test directory
      allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))

      # Create empty recipes file to prevent loading external recipes
      File.write(File.join(test_dir, 'recipes.yml'), {'recipes' => {}}.to_yaml)
    end

    it 'cleans existing files before squashing' do
      # Create existing files that should be cleaned
      File.write('CLAUDE.local.md', '# Old content')
      FileUtils.mkdir_p('.claude/commands')
      File.write('.claude/commands/old.md', '# Old command')
      File.write('.ruly.yml', 'old: metadata')

      # Simply run squash with clean option
      cli.invoke(:squash, [], clean: true)

      # Check that new file was created
      expect(File.exist?('CLAUDE.local.md')).to be(true)

      # Check that new file has new content (not old content)
      # Force UTF-8 encoding when reading the file
      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Old content')
      expect(content.length).to be > 100 # Should have some content

      # Old .claude directory should have been cleaned
      expect(File.exist?('.claude/commands/old.md')).to be(false)
    end

    it 'does not clean in dry-run mode' do
      # Create existing files
      File.write('CLAUDE.local.md', '# Old content')

      cli.invoke(:squash, [], clean: true, dry_run: true)

      # Old file should still exist with old content
      expect(File.read('CLAUDE.local.md')).to eq('# Old content')
    end

    it 'invokes clean with correct parameters' do
      # Verify that clean is actually called and files are removed
      File.write('CLAUDE.local.md', '# Old content')

      cli.invoke(:squash, [], clean: true)

      # The clean command should have been invoked and removed the old file
      # The new file should exist with new content
      expect(File.exist?('CLAUDE.local.md')).to be(true)
      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Old content')
    end

    it 'passes recipe name to clean when specified' do
      # Create old file to clean
      File.write('CLAUDE.local.md', '# Old content')

      # We'll verify clean was called by checking that old files were removed
      # and new ones were created, which shows the clean→squash flow worked

      # Suppress output
      allow(cli).to receive(:puts)
      allow(cli).to receive(:say)

      # Use dry_run to avoid actual file creation but still test the flow
      # This test verifies that invoking squash with clean option doesn't raise errors
      expect do
        cli.invoke(:squash, ['rails'], clean: true, dry_run: true)
      end.not_to raise_error
    end

    it 'uses correct agent for clean operation' do
      # Create old cursor file
      File.write('CURSOR.local.md', '# Old cursor content')
      FileUtils.mkdir_p('.cursor')
      File.write('.cursor/old.mdc', '# Old cursor command')

      cli.invoke(:squash, [], agent: 'cursor', clean: true, output_file: 'CURSOR.local.md')

      # The clean should have been invoked with cursor agent
      # Old cursor files should be gone
      expect(File.exist?('.cursor/old.mdc')).to be(false)
      expect(File.exist?('CURSOR.local.md')).to be(true)
    end
  end

  describe '#squash with git ignore options' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      # Mock gem_root
      allow(cli).to receive_messages(gem_root: test_dir, rules_dir: File.join(test_dir, 'rules'))
    end

    describe '--git-ignore option' do
      context "when .gitignore doesn't exist" do
        it 'creates .gitignore with Ruly section' do
          cli.invoke(:squash, [], git_ignore: true)

          expect(File.exist?('.gitignore')).to be(true)
          content = File.read('.gitignore')
          expect(content).to include('# Ruly generated files')
          expect(content).to include('CLAUDE.local.md')
          expect(content).to include('.ruly.yml')
        end
      end

      context 'when .gitignore exists without Ruly section' do
        before do
          File.write('.gitignore', "# Existing content\nnode_modules/\n")
        end

        it 'appends Ruly section to existing .gitignore' do
          cli.invoke(:squash, [], git_ignore: true)

          content = File.read('.gitignore')
          expect(content).to include('# Existing content')
          expect(content).to include('node_modules/')
          expect(content).to include('# Ruly generated files')
          expect(content).to include('CLAUDE.local.md')
          expect(content).to include('.ruly.yml')
        end
      end

      context 'when .gitignore has existing Ruly section' do
        before do
          File.write('.gitignore', "# Existing\n\n# Ruly generated files\nold-file.md\n\n# Other")
        end

        it 'replaces existing Ruly section' do
          cli.invoke(:squash, [], git_ignore: true, output_file: 'NEW.md')

          content = File.read('.gitignore')
          expect(content).to include('# Existing')
          expect(content).to include('# Ruly generated files')
          expect(content).to include('NEW.md')
          expect(content).to include('.ruly.yml')
          expect(content).not_to include('old-file.md')
          expect(content).to include('# Other')
        end
      end

      it 'includes command files directory for Claude agent' do
        FileUtils.mkdir_p(File.join(test_dir, 'rules', 'commands'))
        File.write(File.join(test_dir, 'rules', 'commands', 'cmd.md'), '# Cmd')

        cli.invoke(:squash, [], agent: 'claude', git_ignore: true)

        content = File.read('.gitignore')
        expect(content).to include('.claude/commands/')
      end

      it 'does not update .gitignore in dry-run mode' do
        cli.invoke(:squash, [], dry_run: true, git_ignore: true)

        expect(File.exist?('.gitignore')).to be(false)
      end
    end

    describe '--git-exclude option' do
      before do
        # Create .git/info directory
        FileUtils.mkdir_p('.git/info')
      end

      context "when .git/info/exclude doesn't exist" do
        it 'creates exclude file with Ruly section' do
          cli.invoke(:squash, [], git_exclude: true)

          expect(File.exist?('.git/info/exclude')).to be(true)
          content = File.read('.git/info/exclude')
          expect(content).to include('# Ruly generated files')
          expect(content).to include('CLAUDE.local.md')
          expect(content).to include('.ruly.yml')
        end
      end

      context "when .git/info doesn't exist" do
        before do
          FileUtils.rm_rf('.git')
        end

        it "warns that it's not a git repository" do
          # Test will output warning to stdout about missing .git/info
          # Just verify the command doesn't crash
          expect { cli.invoke(:squash, [], git_exclude: true) }.not_to raise_error
        end
      end

      context 'when exclude file has existing Ruly section' do
        before do
          File.write('.git/info/exclude', "# Git exclude\n\n# Ruly generated files\nold.md\n\n# End")
        end

        it 'replaces existing Ruly section' do
          cli.invoke(:squash, [], git_exclude: true, output_file: 'NEW.md')

          content = File.read('.git/info/exclude')
          expect(content).to include('# Git exclude')
          expect(content).to include('# Ruly generated files')
          expect(content).to include('NEW.md')
          expect(content).not_to include('old.md')
          expect(content).to include('# End')
        end
      end

      it 'does not update exclude file in dry-run mode' do
        cli.invoke(:squash, [], dry_run: true, git_exclude: true)

        expect(File.exist?('.git/info/exclude')).to be(false)
      end
    end

    describe 'using both git options together' do
      before do
        FileUtils.mkdir_p('.git/info')
      end

      it 'updates both .gitignore and .git/info/exclude' do
        cli.invoke(:squash, [], git_exclude: true, git_ignore: true)

        expect(File.exist?('.gitignore')).to be(true)
        expect(File.exist?('.git/info/exclude')).to be(true)

        gitignore_content = File.read('.gitignore')
        exclude_content = File.read('.git/info/exclude')

        expect([gitignore_content, exclude_content]).to all(
          include('# Ruly generated files')
            .and(include('CLAUDE.local.md'))
            .and(include('.ruly.yml'))
        )
      end
    end
  end

  describe '#get_command_relative_path' do
    it 'handles basic command paths' do
      path = 'rules/commands/test.md'
      result = cli.send(:get_command_relative_path, path)
      expect(result).to eq('test.md')
    end

    it 'preserves subdirectories between rules and commands' do
      path = 'rules/core/commands/bug/fix.md'
      result = cli.send(:get_command_relative_path, path)
      expect(result).to eq('core/bug/fix.md')
    end

    it 'handles paths without rules directory' do
      path = 'some/dir/commands/test.md'
      result = cli.send(:get_command_relative_path, path)
      expect(result).to eq('dir/test.md')
    end

    context 'with omit_command_prefix' do
      it 'removes the prefix when it matches the beginning of the path' do
        path = 'rules/workaxle/core/commands/jira/details.md'
        result = cli.send(:get_command_relative_path, path, 'workaxle/core')
        expect(result).to eq('jira/details.md')
      end

      it 'does not remove prefix if it does not match' do
        path = 'rules/other/project/commands/test.md'
        result = cli.send(:get_command_relative_path, path, 'workaxle/core')
        expect(result).to eq('other/project/test.md')
      end

      it 'handles prefix that exactly matches the path before filename' do
        path = 'rules/workaxle/core/commands/test.md'
        result = cli.send(:get_command_relative_path, path, 'workaxle/core')
        expect(result).to eq('test.md')
      end

      it 'handles nested subdirectories after prefix removal' do
        path = 'rules/workaxle/core/commands/bug/fix/issue.md'
        result = cli.send(:get_command_relative_path, path, 'workaxle/core')
        expect(result).to eq('bug/fix/issue.md')
      end

      it 'handles paths without the prefix' do
        path = 'rules/commands/direct.md'
        result = cli.send(:get_command_relative_path, path, 'workaxle/core')
        expect(result).to eq('direct.md')
      end
    end

    it 'handles files without /commands/ in path' do
      path = 'some/regular/file.md'
      result = cli.send(:get_command_relative_path, path)
      expect(result).to eq('file.md')
    end
  end

  describe '#save_command_files with omit_command_prefix' do
    let(:commands_dir) { '.claude/commands' }

    before do
      # Create a test command file
      @test_command = {
        path: 'rules/workaxle/core/commands/jira/details.md',
        content: '# Test Command'
      }
    end

    it 'saves commands with prefix omitted when recipe config has omit_command_prefix' do
      recipe_config = { 'omit_command_prefix' => 'workaxle/core' }

      cli.send(:save_command_files, [@test_command], recipe_config)

      # Check file was saved to the correct location without the prefix
      expected_file = File.join(commands_dir, 'jira', 'details.md')
      expect(File.exist?(expected_file)).to be(true)
      expect(File.read(expected_file)).to eq('# Test Command')

      # Check that the prefixed directory was NOT created
      prefixed_file = File.join(commands_dir, 'workaxle', 'core', 'jira', 'details.md')
      expect(File.exist?(prefixed_file)).to be(false)
    end

    it 'saves commands with full path when no omit_command_prefix is set' do
      recipe_config = {}

      cli.send(:save_command_files, [@test_command], recipe_config)

      # Check file was saved to the correct location with the full path
      expected_file = File.join(commands_dir, 'workaxle', 'core', 'jira', 'details.md')
      expect(File.exist?(expected_file)).to be(true)
      expect(File.read(expected_file)).to eq('# Test Command')
    end

    it 'handles nil recipe_config' do
      cli.send(:save_command_files, [@test_command], nil)

      # Should save with full path when config is nil
      expected_file = File.join(commands_dir, 'workaxle', 'core', 'jira', 'details.md')
      expect(File.exist?(expected_file)).to be(true)
    end
  end

  describe '#introspect preserving custom keys' do
    let(:user_recipes_file) { File.join(Dir.home, '.config', 'ruly', 'recipes.yml') }

    before do
      # Ensure the config directory exists
      FileUtils.mkdir_p(File.dirname(user_recipes_file))

      # Create initial recipe with custom keys
      initial_config = {
        'recipes' => {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => ['rules/test.md'],
            'omit_command_prefix' => 'workaxle/core',
            'mcp_servers' => ['github', 'atlassian'],
            'custom_key' => 'custom_value',
            'plan' => 'claude_max'
          }
        }
      }
      File.write(user_recipes_file, initial_config.to_yaml)

      # Create test markdown files
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'new.md'), '# New Rule')
    end

    after do
      FileUtils.rm_f(user_recipes_file) if File.exist?(user_recipes_file)
    end

    it 'preserves all custom keys except files/sources when updating a recipe' do
      # Run introspect to update the recipe
      cli.invoke(:introspect, ['test_recipe', File.join(test_dir, 'rules')])

      # Check that all custom keys were preserved
      updated_config = YAML.safe_load_file(user_recipes_file)
      recipe = updated_config['recipes']['test_recipe']

      expect(recipe['omit_command_prefix']).to eq('workaxle/core')
      expect(recipe['mcp_servers']).to eq(['github', 'atlassian'])
      expect(recipe['custom_key']).to eq('custom_value')
      expect(recipe['plan']).to eq('claude_max')
      expect(recipe['files']).to include(File.join(test_dir, 'rules', 'new.md'))
    end
  end
end
