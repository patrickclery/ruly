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

  describe 'nested subagent validation' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when a subagent recipe has its own subagents' do
      before do
        recipes_content = {
          'child-with-subagents' => {
            'description' => 'Child that has its own subagents',
            'files' => ['rules/test.md'],
            'subagents' => [
              {'name' => 'grandchild', 'recipe' => 'grandchild-recipe'}
            ]
          },
          'grandchild-recipe' => {
            'description' => 'Grandchild recipe',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'subagents' => [
              {'name' => 'nested_one', 'recipe' => 'child-with-subagents'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises an error rejecting nested subagents' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /child-with-subagents.*subagents.*skills/i)
      end

      it 'includes the sub-subagent name in the error message' do
        expect { cli.invoke(:squash, ['parent']) }.to raise_error(Ruly::Error, /grandchild/)
      end
    end

    context 'when a subagent recipe has no subagents (leaf node)' do
      before do
        recipes_content = {
          'leaf-recipe' => {
            'description' => 'Leaf recipe with no subagents',
            'files' => ['rules/test.md']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => ['rules/test.md'],
            'subagents' => [
              {'name' => 'leaf_agent', 'recipe' => 'leaf-recipe'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'generates the agent file without error' do
        expect { cli.invoke(:squash, ['parent']) }.not_to raise_error
      end

      it 'creates the subagent file' do
        cli.invoke(:squash, ['parent'])

        expect(File.exist?('.claude/agents/leaf_agent.md')).to be(true)
      end
    end
  end
end
