# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'
require 'ruly/services/subagent_processor'
require 'ruly/services/repo_config_reader'

RSpec.describe Ruly::Services::SubagentProcessor, 'append repo content' do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  describe '.write_agent_content' do
    it 'appends repo content when repo_content is present' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        local_sources: [{ content: '# Recipe Rule' }],
        repo_content: "## Repository Context\n\n# My Repo\n\nGuidance here."
      }

      output = StringIO.new
      described_class.write_agent_content(output, context)

      expect(output.string).to include('# Recipe Rule')
      expect(output.string).to include('## Repository Context')
      expect(output.string).to include('Guidance here.')
    end

    it 'does not append repo section when repo_content is empty' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        local_sources: [{ content: '# Rule' }],
        repo_content: ''
      }

      output = StringIO.new
      described_class.write_agent_content(output, context)

      expect(output.string).not_to include('Repository Context')
    end

    it 'does not append repo section when repo_content is nil' do
      context = {
        agent_name: 'test_agent',
        description: 'Test',
        local_sources: [{ content: '# Rule' }],
        repo_content: nil
      }

      output = StringIO.new
      described_class.write_agent_content(output, context)

      expect(output.string).not_to include('Repository Context')
    end
  end

  describe '.collect_hooks' do
    it 'returns hooks from parent recipe config' do
      parent = {
        'hooks' => {
          'WorktreeCreate' => [{ 'hooks' => [{ 'type' => 'command', 'command' => 'test.sh' }] }]
        }
      }

      result = described_class.collect_hooks(parent)

      expect(result).to have_key('WorktreeCreate')
    end

    it 'returns empty hash when parent has no hooks' do
      expect(described_class.collect_hooks({})).to eq({})
    end

    it 'returns empty hash for nil parent' do
      expect(described_class.collect_hooks(nil)).to eq({})
    end
  end
end
