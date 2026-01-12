# frozen_string_literal: true

require 'spec_helper'
require 'ruly/cli'
require 'tempfile'
require 'fileutils'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }

  describe '#extract_require_shell_commands_from_frontmatter' do
    it 'extracts require_shell_commands from frontmatter' do
      content = <<~MD
        ---
        description: Test rule
        require_shell_commands:
          - post-jira-comment.sh
          - markdown-to-adf.mjs
        ---
        # Test content
      MD

      commands = cli.send(:extract_require_shell_commands_from_frontmatter, content)
      expect(commands).to eq(['post-jira-comment.sh', 'markdown-to-adf.mjs'])
    end

    it 'returns empty array when no require_shell_commands' do
      content = <<~MD
        ---
        description: Test rule
        ---
        # Test content
      MD

      commands = cli.send(:extract_require_shell_commands_from_frontmatter, content)
      expect(commands).to eq([])
    end

    it 'returns empty array when no frontmatter' do
      content = '# Test content without frontmatter'

      commands = cli.send(:extract_require_shell_commands_from_frontmatter, content)
      expect(commands).to eq([])
    end

    it 'handles single command as string' do
      content = <<~MD
        ---
        description: Test rule
        require_shell_commands: post-jira-comment.sh
        ---
        # Test content
      MD

      commands = cli.send(:extract_require_shell_commands_from_frontmatter, content)
      expect(commands).to eq(['post-jira-comment.sh'])
    end
  end

  describe '#check_shell_command_available' do
    it 'returns true for commands that exist in PATH' do
      # 'ls' should exist on all systems
      result = cli.send(:check_shell_command_available, 'ls')
      expect(result).to be true
    end

    it 'returns false for commands that do not exist' do
      result = cli.send(:check_shell_command_available, 'nonexistent-command-xyz-123')
      expect(result).to be false
    end

    it 'returns true for executable scripts in PATH' do
      Dir.mktmpdir do |tmpdir|
        script_path = File.join(tmpdir, 'test-script.sh')
        File.write(script_path, '#!/bin/bash\necho "test"')
        File.chmod(0o755, script_path)

        # Temporarily add to PATH
        original_path = ENV['PATH']
        ENV['PATH'] = "#{tmpdir}:#{original_path}"

        begin
          result = cli.send(:check_shell_command_available, 'test-script.sh')
          expect(result).to be true
        ensure
          ENV['PATH'] = original_path
        end
      end
    end

    it 'returns false for non-executable scripts in PATH' do
      Dir.mktmpdir do |tmpdir|
        script_path = File.join(tmpdir, 'non-executable-script.sh')
        File.write(script_path, '#!/bin/bash\necho "test"')
        File.chmod(0o644, script_path) # Not executable

        original_path = ENV['PATH']
        ENV['PATH'] = "#{tmpdir}:#{original_path}"

        begin
          result = cli.send(:check_shell_command_available, 'non-executable-script.sh')
          expect(result).to be false
        ensure
          ENV['PATH'] = original_path
        end
      end
    end
  end

  describe '#collect_required_shell_commands' do
    it 'collects require_shell_commands from all sources' do
      Dir.mktmpdir do |tmpdir|
        # Create test rule files
        rule1 = File.join(tmpdir, 'rule1.md')
        File.write(rule1, <<~MD)
          ---
          description: Rule 1
          require_shell_commands:
            - cmd1.sh
            - cmd2.sh
          ---
          # Rule 1
        MD

        rule2 = File.join(tmpdir, 'rule2.md')
        File.write(rule2, <<~MD)
          ---
          description: Rule 2
          require_shell_commands:
            - cmd3.sh
          ---
          # Rule 2
        MD

        rule3 = File.join(tmpdir, 'rule3.md')
        File.write(rule3, <<~MD)
          ---
          description: Rule 3 without commands
          ---
          # Rule 3
        MD

        sources = [
          { type: 'local', path: rule1 },
          { type: 'local', path: rule2 },
          { type: 'local', path: rule3 }
        ]

        commands = cli.send(:collect_required_shell_commands, sources)
        expect(commands).to contain_exactly('cmd1.sh', 'cmd2.sh', 'cmd3.sh')
      end
    end

    it 'deduplicates commands across sources' do
      Dir.mktmpdir do |tmpdir|
        rule1 = File.join(tmpdir, 'rule1.md')
        File.write(rule1, <<~MD)
          ---
          require_shell_commands:
            - shared-cmd.sh
            - unique1.sh
          ---
          # Rule 1
        MD

        rule2 = File.join(tmpdir, 'rule2.md')
        File.write(rule2, <<~MD)
          ---
          require_shell_commands:
            - shared-cmd.sh
            - unique2.sh
          ---
          # Rule 2
        MD

        sources = [
          { type: 'local', path: rule1 },
          { type: 'local', path: rule2 }
        ]

        commands = cli.send(:collect_required_shell_commands, sources)
        expect(commands).to contain_exactly('shared-cmd.sh', 'unique1.sh', 'unique2.sh')
      end
    end
  end

  describe '#check_required_shell_commands' do
    it 'returns hash with available and missing commands' do
      Dir.mktmpdir do |tmpdir|
        # Create an executable script
        script_path = File.join(tmpdir, 'available-cmd.sh')
        File.write(script_path, '#!/bin/bash\necho "test"')
        File.chmod(0o755, script_path)

        original_path = ENV['PATH']
        ENV['PATH'] = "#{tmpdir}:#{original_path}"

        begin
          commands = ['available-cmd.sh', 'missing-cmd.sh']
          result = cli.send(:check_required_shell_commands, commands)

          expect(result[:available]).to include('available-cmd.sh')
          expect(result[:missing]).to include('missing-cmd.sh')
        ensure
          ENV['PATH'] = original_path
        end
      end
    end

    it 'returns empty arrays when no commands provided' do
      result = cli.send(:check_required_shell_commands, [])
      expect(result[:available]).to eq([])
      expect(result[:missing]).to eq([])
    end
  end

  describe 'warning output for missing commands' do
    it 'outputs warning for each missing command' do
      # Test the warning message format directly
      commands = ['missing-cmd1.sh', 'missing-cmd2.sh']

      output = capture_stdout do
        check_result = cli.send(:check_required_shell_commands, commands)
        check_result[:missing].each do |cmd|
          puts "⚠️  Warning: Required shell command '#{cmd}' not found in PATH"
        end
      end

      expect(output).to include('missing-cmd1.sh')
      expect(output).to include('missing-cmd2.sh')
      expect(output).to include('not found')
    end

    it 'outputs nothing when all commands are available' do
      # 'ls' should exist on all systems
      commands = ['ls']

      output = capture_stdout do
        check_result = cli.send(:check_required_shell_commands, commands)
        check_result[:missing].each do |cmd|
          puts "⚠️  Warning: Required shell command '#{cmd}' not found in PATH"
        end
      end

      expect(output).not_to include('not found')
    end
  end

  describe 'end-to-end warning integration' do
    it 'collects commands and warns about missing ones' do
      Dir.mktmpdir do |tmpdir|
        # Create a rule file with require_shell_commands
        rule_file = File.join(tmpdir, 'test-rule.md')
        File.write(rule_file, <<~MD)
          ---
          description: Test rule
          require_shell_commands:
            - nonexistent-command-xyz.sh
            - another-missing-cmd.sh
          ---
          # Test Rule Content
        MD

        sources = [{ type: 'local', path: rule_file }]

        # Collect commands
        commands = cli.send(:collect_required_shell_commands, sources)
        expect(commands).to contain_exactly('nonexistent-command-xyz.sh', 'another-missing-cmd.sh')

        # Check availability
        result = cli.send(:check_required_shell_commands, commands)
        expect(result[:missing]).to contain_exactly('nonexistent-command-xyz.sh', 'another-missing-cmd.sh')
        expect(result[:available]).to be_empty
      end
    end

    it 'finds available commands in PATH' do
      Dir.mktmpdir do |tmpdir|
        # Create an executable script
        script_path = File.join(tmpdir, 'my-test-script.sh')
        File.write(script_path, '#!/bin/bash\necho "test"')
        File.chmod(0o755, script_path)

        # Create a rule file
        rule_file = File.join(tmpdir, 'test-rule.md')
        File.write(rule_file, <<~MD)
          ---
          description: Test rule
          require_shell_commands:
            - my-test-script.sh
            - ls
          ---
          # Test Rule Content
        MD

        original_path = ENV['PATH']
        ENV['PATH'] = "#{tmpdir}:#{original_path}"

        begin
          sources = [{ type: 'local', path: rule_file }]
          commands = cli.send(:collect_required_shell_commands, sources)
          result = cli.send(:check_required_shell_commands, commands)

          expect(result[:available]).to contain_exactly('my-test-script.sh', 'ls')
          expect(result[:missing]).to be_empty
        ensure
          ENV['PATH'] = original_path
        end
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
