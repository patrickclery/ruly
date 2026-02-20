# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, type: :cli do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd

    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe 'subagent model specification' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when subagent entry has model' do
      before do
        recipes_content = {
          'child-recipe' => {
            'description' => 'Child recipe',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'subagents' => [
              {'model' => 'haiku', 'name' => 'child_agent', 'recipe' => 'child-recipe'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'uses the subagent model in agent file frontmatter' do
        cli.invoke(:squash, ['parent'])

        content = File.read('.claude/agents/child_agent.md', encoding: 'UTF-8')
        expect(content).to include('model: haiku')
      end
    end

    context 'when recipe has model but subagent does not' do
      before do
        recipes_content = {
          'child-recipe' => {
            'description' => 'Child recipe',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'model' => 'sonnet',
            'subagents' => [
              {'name' => 'child_agent', 'recipe' => 'child-recipe'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'falls back to the parent recipe model' do
        cli.invoke(:squash, ['parent'])

        content = File.read('.claude/agents/child_agent.md', encoding: 'UTF-8')
        expect(content).to include('model: sonnet')
      end
    end

    context 'when subagent model overrides recipe model' do
      before do
        recipes_content = {
          'child-recipe' => {
            'description' => 'Child recipe',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'model' => 'sonnet',
            'subagents' => [
              {'model' => 'haiku', 'name' => 'child_agent', 'recipe' => 'child-recipe'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'uses the subagent model over the recipe model' do
        cli.invoke(:squash, ['parent'])

        content = File.read('.claude/agents/child_agent.md', encoding: 'UTF-8')
        expect(content).to include('model: haiku')
        expect(content).not_to include('model: sonnet')
      end
    end

    context 'when neither subagent nor recipe has model' do
      before do
        recipes_content = {
          'child-recipe' => {
            'description' => 'Child recipe',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'subagents' => [
              {'name' => 'child_agent', 'recipe' => 'child-recipe'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'defaults to inherit' do
        cli.invoke(:squash, ['parent'])

        content = File.read('.claude/agents/child_agent.md', encoding: 'UTF-8')
        expect(content).to include('model: inherit')
      end
    end
  end
end
