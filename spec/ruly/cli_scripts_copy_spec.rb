# frozen_string_literal: true

require 'spec_helper'
require 'ruly/cli'
require 'tmpdir'
require 'fileutils'
require 'webmock/rspec'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  let(:rules_dir) { File.join(temp_dir, 'rules') }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    FileUtils.mkdir_p(rules_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
    WebMock.reset!
  end

  describe 'script copying during squash' do
    let(:scripts_dir) { File.join(rules_dir, 'bin') }
    let(:agent_dir) { File.join(temp_dir, 'agents', 'WA-11135') }

    before do
      # Create script files
      FileUtils.mkdir_p(scripts_dir)
      File.write(File.join(scripts_dir, 'markdown-to-adf.mjs'), '#!/usr/bin/env node\nconsole.log("adf")')
      File.write(File.join(scripts_dir, 'post-jira-comment.sh'), '#!/bin/bash\necho "post"')

      # Create a rule file that references scripts
      rule_content = <<~YAML
        ---
        description: Test rule with scripts
        scripts:
          - #{File.join(scripts_dir, 'markdown-to-adf.mjs')}
          - #{File.join(scripts_dir, 'post-jira-comment.sh')}
        ---
        # Test Rule

        Use this script to post:
        ```bash
        #{File.join(scripts_dir, 'post-jira-comment.sh')} TICKET "message"
        ```
      YAML
      File.write(File.join(rules_dir, 'test-rule.md'), rule_content)

      # Create agent directory
      FileUtils.mkdir_p(agent_dir)
    end

    describe '#copy_scripts with local destination' do
      it 'copies scripts to .claude/scripts/ relative to working directory' do
        script_files = {
          local: [
            {
              from_rule: 'rules/test-rule.md',
              relative_path: 'markdown-to-adf.mjs',
              source_path: File.join(scripts_dir, 'markdown-to-adf.mjs')
            },
            {
              from_rule: 'rules/test-rule.md',
              relative_path: 'post-jira-comment.sh',
              source_path: File.join(scripts_dir, 'post-jira-comment.sh')
            }
          ],
          remote: []
        }

        # Copy to the agent directory's .claude/scripts/
        local_scripts_dir = File.join(agent_dir, '.claude', 'scripts')
        cli.send(:copy_scripts, script_files, local_scripts_dir)

        expect(File.exist?(File.join(local_scripts_dir, 'markdown-to-adf.mjs'))).to be(true)
        expect(File.exist?(File.join(local_scripts_dir, 'post-jira-comment.sh'))).to be(true)
      end
    end
  end

  describe '#rewrite_script_references' do
    it 'rewrites absolute script paths to relative .claude/scripts/ paths' do
      content = <<~MARKDOWN
        # Test Rule

        Use this script to post:
        ```bash
        /Users/patrick/Projects/ruly/rules/bin/post-jira-comment.sh TICKET "message"
        ```

        Or use the ADF converter:
        /Users/patrick/Projects/ruly/rules/bin/markdown-to-adf.mjs
      MARKDOWN

      script_mappings = {
        '/Users/patrick/Projects/ruly/rules/bin/post-jira-comment.sh' => 'post-jira-comment.sh',
        '/Users/patrick/Projects/ruly/rules/bin/markdown-to-adf.mjs' => 'markdown-to-adf.mjs'
      }

      result = cli.send(:rewrite_script_references, content, script_mappings)

      expect(result).to include('.claude/scripts/post-jira-comment.sh TICKET "message"')
      expect(result).to include('.claude/scripts/markdown-to-adf.mjs')
      expect(result).not_to include('/Users/patrick/Projects/ruly/rules/bin/')
    end

    it 'handles mixed content with multiple script references' do
      content = <<~MARKDOWN
        Step 1: Convert markdown
        /path/to/scripts/convert.sh input.md

        Step 2: Post comment
        /path/to/scripts/post.sh TICKET -

        Step 3: Verify
        echo "done"
      MARKDOWN

      script_mappings = {
        '/path/to/scripts/convert.sh' => 'convert.sh',
        '/path/to/scripts/post.sh' => 'post.sh'
      }

      result = cli.send(:rewrite_script_references, content, script_mappings)

      expect(result).to include('.claude/scripts/convert.sh input.md')
      expect(result).to include('.claude/scripts/post.sh TICKET -')
      expect(result).to include('echo "done"')
    end

    it 'returns content unchanged when no mappings match' do
      content = "Some content without script references"
      script_mappings = {}

      result = cli.send(:rewrite_script_references, content, script_mappings)

      expect(result).to eq(content)
    end
  end

  describe '#build_script_mappings' do
    it 'builds mappings from collected scripts' do
      script_files = {
        local: [
          {
            from_rule: 'rules/test.md',
            relative_path: 'post-jira-comment.sh',
            source_path: '/Users/patrick/Projects/ruly/rules/bin/post-jira-comment.sh'
          },
          {
            from_rule: 'rules/test.md',
            relative_path: 'markdown-to-adf.mjs',
            source_path: '/Users/patrick/Projects/ruly/rules/bin/markdown-to-adf.mjs'
          }
        ],
        remote: []
      }

      result = cli.send(:build_script_mappings, script_files)

      expect(result).to eq({
        '/Users/patrick/Projects/ruly/rules/bin/post-jira-comment.sh' => 'post-jira-comment.sh',
        '/Users/patrick/Projects/ruly/rules/bin/markdown-to-adf.mjs' => 'markdown-to-adf.mjs'
      })
    end

    it 'handles empty script files' do
      script_files = { local: [], remote: [] }

      result = cli.send(:build_script_mappings, script_files)

      expect(result).to eq({})
    end
  end

  describe 'squash integration with scripts' do
    let(:script_path) { File.join(rules_dir, 'bin', 'test-script.sh') }

    before do
      # Create script
      FileUtils.mkdir_p(File.join(rules_dir, 'bin'))
      File.write(script_path, '#!/bin/bash\necho "test"')
    end

    it 'builds script mappings and rewrites content correctly' do
      # Create source content with script reference
      source_content = <<~MARKDOWN
        # Test Rule

        Run the script:
        ```bash
        #{script_path} arg1 arg2
        ```
      MARKDOWN

      script_files = {
        local: [{
          from_rule: 'rules/test.md',
          relative_path: 'test-script.sh',
          source_path: script_path
        }],
        remote: []
      }

      # Build mappings
      mappings = cli.send(:build_script_mappings, script_files)

      # Rewrite content
      result = cli.send(:rewrite_script_references, source_content, mappings)

      expect(result).to include('.claude/scripts/test-script.sh arg1 arg2')
      expect(result).not_to include(script_path)
    end

    it 'copies scripts to local .claude/scripts/ during squash flow' do
      agent_dir = File.join(temp_dir, 'agent-output')
      FileUtils.mkdir_p(agent_dir)

      script_files = {
        local: [{
          from_rule: 'rules/test.md',
          relative_path: 'test-script.sh',
          source_path: script_path
        }],
        remote: []
      }

      Dir.chdir(agent_dir) do
        cli.send(:copy_scripts, script_files)

        local_scripts_dir = File.join(agent_dir, '.claude', 'scripts')
        expect(File.exist?(File.join(local_scripts_dir, 'test-script.sh'))).to be(true)
        expect(File.executable?(File.join(local_scripts_dir, 'test-script.sh'))).to be(true)
      end
    end

    it 'handles multiple scripts with different paths' do
      # Create additional script
      script2_path = File.join(rules_dir, 'bin', 'other-script.mjs')
      File.write(script2_path, '#!/usr/bin/env node\nconsole.log("other")')

      source_content = <<~MARKDOWN
        # Multi-script Rule

        First: #{script_path}
        Second: #{script2_path} --flag
      MARKDOWN

      script_files = {
        local: [
          { from_rule: 'rules/test.md', relative_path: 'test-script.sh', source_path: script_path },
          { from_rule: 'rules/test.md', relative_path: 'other-script.mjs', source_path: script2_path }
        ],
        remote: []
      }

      mappings = cli.send(:build_script_mappings, script_files)
      result = cli.send(:rewrite_script_references, source_content, mappings)

      expect(result).to include('.claude/scripts/test-script.sh')
      expect(result).to include('.claude/scripts/other-script.mjs --flag')
      expect(result).not_to include(rules_dir)
    end
  end
end
