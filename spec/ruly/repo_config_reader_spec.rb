# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'ruly/services/repo_config_reader'

RSpec.describe Ruly::Services::RepoConfigReader do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  describe '.read_repo_content' do
    it 'reads CLAUDE.md content' do
      File.write('CLAUDE.md', "# My Repo\n\nSome guidance here.")
      result = described_class.read_repo_content('.')
      expect(result[:claude_md]).to eq("# My Repo\n\nSome guidance here.")
    end

    it 'strips frontmatter from CLAUDE.md' do
      File.write('CLAUDE.md', "---\nalwaysApply: true\n---\n# My Repo\n\nGuidance.")
      result = described_class.read_repo_content('.')
      expect(result[:claude_md]).to eq("# My Repo\n\nGuidance.")
    end

    it 'returns nil claude_md when CLAUDE.md does not exist' do
      result = described_class.read_repo_content('.')
      expect(result[:claude_md]).to be_nil
    end

    it 'reads .claude/rules/*.md files' do
      FileUtils.mkdir_p('.claude/rules')
      File.write('.claude/rules/typescript.md', "---\npaths: \"**/*.ts\"\n---\n## TypeScript Rules\n\nUse strict mode.")
      File.write('.claude/rules/testing.md', "## Testing\n\nAlways test.")
      result = described_class.read_repo_content('.')
      expect(result[:rules]).to be_an(Array)
      expect(result[:rules].size).to eq(2)
      expect(result[:rules].map { |r| r[:name] }).to contain_exactly('testing', 'typescript')
    end

    it 'strips frontmatter from rule files' do
      FileUtils.mkdir_p('.claude/rules')
      File.write('.claude/rules/ts.md', "---\npaths: \"**/*.ts\"\n---\n## TS Rules\n\nContent.")
      result = described_class.read_repo_content('.')
      ts_rule = result[:rules].find { |r| r[:name] == 'ts' }
      expect(ts_rule[:content]).to eq("## TS Rules\n\nContent.")
    end

    it 'returns empty rules when .claude/rules/ does not exist' do
      result = described_class.read_repo_content('.')
      expect(result[:rules]).to eq([])
    end

    it 'reads hooks from .claude/settings.json' do
      FileUtils.mkdir_p('.claude')
      File.write('.claude/settings.json', JSON.pretty_generate(
        'hooks' => {
          'PostToolUse' => [
            { 'matcher' => 'Edit|Write', 'hooks' => [{ 'type' => 'command', 'command' => '.claude/hooks/fix.sh' }] }
          ]
        }
      ))
      result = described_class.read_repo_content('.')
      expect(result[:hooks]).to have_key('PostToolUse')
    end

    it 'returns empty hooks when settings.json has no hooks' do
      FileUtils.mkdir_p('.claude')
      File.write('.claude/settings.json', JSON.pretty_generate('permissions' => {}))
      result = described_class.read_repo_content('.')
      expect(result[:hooks]).to eq({})
    end

    it 'returns empty hooks when settings.json does not exist' do
      result = described_class.read_repo_content('.')
      expect(result[:hooks]).to eq({})
    end
  end

  describe '.format_repo_content' do
    it 'formats CLAUDE.md as Repository Context section' do
      repo = { claude_md: "# Repo\n\nGuidance.", rules: [], hooks: {} }
      output = described_class.format_repo_content(repo)
      expect(output).to include("## Repository Context\n")
      expect(output).to include("# Repo\n\nGuidance.")
    end

    it 'formats rules as Repository Rules section' do
      repo = {
        claude_md: nil,
        rules: [
          { name: 'typescript', content: "## TypeScript\n\nStrict mode." },
          { name: 'testing', content: "## Testing\n\nAlways test." }
        ],
        hooks: {}
      }
      output = described_class.format_repo_content(repo)
      expect(output).to include("## Repository Rules\n")
      expect(output).to include("## TypeScript\n\nStrict mode.")
      expect(output).to include("## Testing\n\nAlways test.")
    end

    it 'returns empty string when no content' do
      repo = { claude_md: nil, rules: [], hooks: {} }
      expect(described_class.format_repo_content(repo)).to eq('')
    end
  end
end
