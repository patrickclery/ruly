# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'ruly/services/subagent_processor'

RSpec.describe Ruly::Services::SubagentProcessor, 'hooks in frontmatter' do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  describe '.write_agent_frontmatter' do
    it 'renders hooks in YAML frontmatter when present' do
      context = {
        agent_name: 'test_agent',
        description: 'Test agent',
        model: 'inherit',
        skill_names: [],
        mcp_servers: [],
        profile_name: 'test',
        parent_profile_name: 'parent',
        hooks: {
          'WorktreeCreate' => [
            { 'hooks' => [{ 'type' => 'command', 'command' => '.claude/scripts/worktree-create.sh', 'timeout' => 120 }] }
          ],
          'PostToolUse' => [
            { 'matcher' => 'Edit|Write', 'hooks' => [{ 'type' => 'command', 'command' => '.claude/hooks/fix.sh' }] }
          ]
        }
      }

      output = StringIO.new
      described_class.write_agent_frontmatter(output, context)
      content = output.string

      yaml_content = content.match(/---\n(.*?)---/m)[1]
      parsed = YAML.safe_load(yaml_content, permitted_classes: [Symbol])

      expect(parsed['hooks']).to have_key('WorktreeCreate')
      expect(parsed['hooks']).to have_key('PostToolUse')
      expect(parsed['hooks']['PostToolUse'].first['matcher']).to eq('Edit|Write')
    end

    it 'omits hooks from frontmatter when empty' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        model: 'inherit',
        skill_names: [],
        mcp_servers: [],
        profile_name: 'test',
        parent_profile_name: 'parent',
        hooks: {}
      }

      output = StringIO.new
      described_class.write_agent_frontmatter(output, context)
      expect(output.string).not_to include('hooks:')
    end

    it 'omits hooks from frontmatter when nil' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        model: 'inherit',
        skill_names: [],
        mcp_servers: [],
        profile_name: 'test',
        parent_profile_name: 'parent',
        hooks: nil
      }

      output = StringIO.new
      described_class.write_agent_frontmatter(output, context)
      expect(output.string).not_to include('hooks:')
    end

    it 'preserves existing skills and mcp lines' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        model: 'opus',
        skill_names: ['debugging'],
        mcp_servers: ['Ref'],
        profile_name: 'test',
        parent_profile_name: 'parent',
        hooks: { 'WorktreeCreate' => [{ 'hooks' => [{ 'type' => 'command', 'command' => 'test.sh' }] }] }
      }

      output = StringIO.new
      described_class.write_agent_frontmatter(output, context)
      content = output.string

      expect(content).to include('skills:')
      expect(content).to include('mcpServers:')
      expect(content).to include('hooks:')
      expect(content).to include('model:')
    end
  end
end
