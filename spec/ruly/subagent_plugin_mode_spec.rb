# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'ruly/services/subagent_processor'

RSpec.describe Ruly::Services::SubagentProcessor do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  let(:base_context) do
    {
      agent_name: 'helper',
      description: 'Helper agent',
      hooks: {'Stop' => [{'hooks' => [{'command' => 'x.sh', 'type' => 'command'}]}]},
      mcp_servers: ['grafana'],
      model: 'haiku',
      parent_recipe_name: 'demo',
      recipe_name: 'helper',
      skill_names: ['demo:review']
    }
  end

  def frontmatter_for(context)
    output = StringIO.new
    described_class.write_agent_frontmatter(output, context)
    output.string
  end

  def parsed_frontmatter(context)
    YAML.safe_load(frontmatter_for(context).match(/\A---\n(.*?)^---$/m)[1])
  end

  describe '.write_agent_frontmatter with plugin: true' do
    let(:parsed) { parsed_frontmatter(base_context.merge(plugin: true)) }

    it 'keeps the resolved model' do
      expect(parsed['model']).to eq('haiku')
    end

    it 'writes skills as a YAML list of namespaced names' do
      expect(parsed['skills']).to eq(['demo:review'])
    end

    it 'omits permissionMode, hooks and mcpServers' do
      expect(parsed.keys & %w[permissionMode hooks mcpServers]).to be_empty
    end
  end

  describe '.write_agent_frontmatter without plugin:' do
    let(:parsed) { parsed_frontmatter(base_context.merge(skill_names: ['review'])) }

    it 'writes the claude-target frontmatter unchanged' do
      expect(parsed.slice('skills', 'mcpServers', 'permissionMode'))
        .to eq('mcpServers' => '[grafana]', 'permissionMode' => 'bypassPermissions', 'skills' => '[review]')
    end

    it 'still writes the parent hooks' do
      expect(parsed['hooks']).to have_key('Stop')
    end
  end

  describe '.process_subagents with plugin_dir:' do
    let(:calls) { {save: [], squash: []} }
    let(:skill) { {content: "---\ndescription: Review\n---\n# Review\n", path: 'rules/skills/review.md'} }
    let(:deps) do
      {
        find_rule_file: ->(_path) {},
        load_all_recipes: -> { {'helper' => {'description' => 'Helper', 'files' => ['rules/base.md']}} },
        load_recipe_sources: ->(_name) { [[{path: 'rules/base.md', type: 'local'}]] },
        parse_frontmatter: ->(content) { [{}, content] },
        process_sources_for_squash: lambda do |*args|
          calls[:squash] << args
          [[{content: "# Base\n", path: 'rules/base.md'}], [], [], [skill]]
        end,
        save_skill_files: ->(files, **kwargs) { calls[:save] << [files, kwargs] }
      }
    end
    let(:recipe_config) { {'subagents' => [{'model' => 'haiku', 'name' => 'helper', 'recipe' => 'helper'}]} }

    def run(plugin_dir: nil)
      out = StringIO.new
      original = $stdout
      $stdout = out
      described_class.process_subagents(recipe_config, 'demo', plugin_dir:, **deps)
    ensure
      $stdout = original
    end

    it 'writes the agent file into DIR/agents and nothing into .claude/' do
      run(plugin_dir: 'plug')
      expect([File.file?('plug/agents/helper.md'), File.exist?('.claude')]).to eq([true, false])
    end

    it 'saves subagent skills into DIR/skills' do
      run(plugin_dir: 'plug')
      expect(calls[:save].first[1]).to include(skills_dir: File.join('plug', 'skills'))
    end

    it 'copies subagent scripts into DIR/scripts' do
      run(plugin_dir: 'plug')
      expect(calls[:squash].first[3]).to eq(scripts_dir: File.join('plug', 'scripts'))
    end

    it 'names preloaded skills PLUGIN:skill in plugin frontmatter' do
      run(plugin_dir: 'plug')
      parsed = YAML.safe_load(File.read('plug/agents/helper.md').match(/\A---\n(.*?)^---$/m)[1])
      expect([parsed['skills'], parsed.key?('permissionMode')]).to eq([['demo:review'], false])
    end

    it 'keeps today\'s paths and arguments without plugin_dir:' do
      run
      expect([File.file?('.claude/agents/helper.md'), calls[:squash].first[3], calls[:save].first[1].key?(:skills_dir)])
        .to eq([true, {}, false])
    end
  end
end
