# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::Services::RecipeLoader, '.resolve_extends!' do
  describe 'basic extends' do
    it 'merges parent files into child' do
      recipes = {
        'base' => {
          'description' => 'Base recipe',
          'files' => ['rules/base.md']
        },
        'child' => {
          'description' => 'Child recipe',
          'extends' => 'base',
          'files' => ['rules/child.md']
        }
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(recipes['child']['description']).to eq('Child recipe')
      expect(recipes['child']).not_to have_key('extends')
    end
  end

  describe 'integration with load_all_recipes' do
    let(:test_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(test_dir) }

    it 'resolves extends when loading recipes from YAML' do
      recipes_yml = <<~YAML
        recipes:
          base:
            description: "Base recipe"
            files:
              - rules/base.md
            mcp_servers:
              - teams
          child:
            extends: base
            description: "Child recipe"
            files:
              - rules/child.md
            mcp_servers:
              - playwright
      YAML

      File.write(File.join(test_dir, 'recipes.yml'), recipes_yml)

      recipes = described_class.load_all_recipes(
        base_recipes_file: File.join(test_dir, 'recipes.yml'),
        gem_root: test_dir
      )

      expect(recipes['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(recipes['child']['mcp_servers']).to eq(%w[teams playwright])
      expect(recipes['child']).not_to have_key('extends')
      # Parent should be unchanged
      expect(recipes['base']['files']).to eq(['rules/base.md'])
    end
  end

  describe 'scalar override (child wins)' do
    it 'child description overrides parent' do
      recipes = {
        'base' => {'description' => 'Base', 'model' => 'sonnet'},
        'child' => {'description' => 'Child', 'extends' => 'base', 'model' => 'opus'}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['description']).to eq('Child')
      expect(recipes['child']['model']).to eq('opus')
    end

    it 'child inherits scalars it does not define' do
      recipes = {
        'base' => {'description' => 'Base', 'model' => 'sonnet', 'tier' => 'claude_pro'},
        'child' => {'description' => 'Child', 'extends' => 'base'}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['model']).to eq('sonnet')
      expect(recipes['child']['tier']).to eq('claude_pro')
    end
  end

  describe 'array union (deduped, parent first)' do
    it 'unions files without duplicates' do
      recipes = {
        'base' => {'files' => ['a.md', 'b.md']},
        'child' => {'extends' => 'base', 'files' => ['b.md', 'c.md']}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['files']).to eq(['a.md', 'b.md', 'c.md'])
    end

    it 'unions mcp_servers' do
      recipes = {
        'base' => {'mcp_servers' => ['teams']},
        'child' => {'extends' => 'base', 'mcp_servers' => ['playwright']}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['mcp_servers']).to eq(%w[teams playwright])
    end

    it 'handles child with no array key (inherits parent array)' do
      recipes = {
        'base' => {'files' => ['a.md']},
        'child' => {'extends' => 'base'}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['files']).to eq(['a.md'])
    end
  end

  describe 'subagent merging' do
    it 'unions subagents by name, child wins on conflict' do
      recipes = {
        'base' => {
          'subagents' => [
            {'name' => 'agent_a', 'recipe' => 'prof-a'},
            {'model' => 'sonnet', 'name' => 'agent_b', 'recipe' => 'prof-b'}
          ]
        },
        'child' => {
          'extends' => 'base',
          'subagents' => [
            {'model' => 'haiku', 'name' => 'agent_b', 'recipe' => 'prof-b'},
            {'name' => 'agent_c', 'recipe' => 'prof-c'}
          ]
        }
      }

      described_class.resolve_extends!(recipes)

      names = recipes['child']['subagents'].map { |s| s['name'] }
      expect(names).to contain_exactly('agent_a', 'agent_b', 'agent_c')

      agent_b = recipes['child']['subagents'].find { |s| s['name'] == 'agent_b' }
      expect(agent_b['model']).to eq('haiku')
    end
  end

  describe 'transitive extends (A extends B extends C)' do
    it 'resolves multi-level inheritance' do
      recipes = {
        'child' => {'extends' => 'parent', 'files' => ['c.md']},
        'grandparent' => {'files' => ['gp.md'], 'mcp_servers' => ['server-a']},
        'parent' => {'extends' => 'grandparent', 'files' => ['p.md']}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['child']['files']).to eq(['gp.md', 'p.md', 'c.md'])
      expect(recipes['child']['mcp_servers']).to eq(['server-a'])
      expect(recipes['parent']['files']).to eq(['gp.md', 'p.md'])
    end
  end

  describe 'circular extends detection' do
    it 'raises error on direct circular reference' do
      recipes = {
        'a' => {'extends' => 'b'},
        'b' => {'extends' => 'a'}
      }

      expect { described_class.resolve_extends!(recipes) }.to raise_error(
        Ruly::Error, /Circular extends detected/
      )
    end

    it 'raises error on indirect circular reference' do
      recipes = {
        'a' => {'extends' => 'b'},
        'b' => {'extends' => 'c'},
        'c' => {'extends' => 'a'}
      }

      expect { described_class.resolve_extends!(recipes) }.to raise_error(
        Ruly::Error, /Circular extends detected/
      )
    end
  end

  describe 'missing parent detection' do
    it 'raises error when parent does not exist' do
      recipes = {
        'child' => {'extends' => 'nonexistent'}
      }

      expect { described_class.resolve_extends!(recipes) }.to raise_error(
        Ruly::Error, /does not exist/
      )
    end
  end

  describe 'recipes without extends are unchanged' do
    it 'does not modify recipes that have no extends key' do
      recipes = {
        'standalone' => {'description' => 'Solo', 'files' => ['a.md']}
      }

      described_class.resolve_extends!(recipes)

      expect(recipes['standalone']).to eq({'description' => 'Solo', 'files' => ['a.md']})
    end
  end

  describe 'array recipes are skipped' do
    it 'does not attempt to resolve extends on array recipes' do
      recipes = {
        'agent' => ['file1.md', 'file2.md'],
        'base' => {'files' => ['a.md']}
      }

      expect { described_class.resolve_extends!(recipes) }.not_to raise_error
      expect(recipes['agent']).to eq(['file1.md', 'file2.md'])
    end
  end
end

RSpec.describe Ruly::CLI, 'squash with extends', type: :cli do
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

  before do
    FileUtils.mkdir_p(File.join(test_dir, 'rules'))
    File.write(File.join(test_dir, 'rules', 'base.md'), '# Base Rule')
    File.write(File.join(test_dir, 'rules', 'child.md'), '# Child Rule')

    recipes_yml = {
      'recipes' => {
        'base' => {
          'description' => 'Base recipe',
          'files' => ['rules/base.md']
        },
        'child' => {
          'description' => 'Child recipe',
          'extends' => 'base',
          'files' => ['rules/child.md']
        }
      }
    }
    File.write(File.join(test_dir, 'recipes.yml'), recipes_yml.to_yaml)

    allow(cli).to receive_messages(
      gem_root: test_dir,
      recipes_file: File.join(test_dir, 'recipes.yml'),
      rules_dir: File.join(test_dir, 'rules')
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(
      Ruly::Services::RecipeLoader.load_all_recipes(
        base_recipes_file: File.join(test_dir, 'recipes.yml'),
        gem_root: test_dir
      )
    )
    # rubocop:enable RSpec/AnyInstance
  end

  it 'squash output includes content from both parent and child files' do
    cli.invoke(:squash, ['child'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).to include('Child Rule')
  end

  it 'parent recipe squash is unaffected' do
    cli.invoke(:squash, ['base'])

    content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
    expect(content).to include('Base Rule')
    expect(content).not_to include('Child Rule')
  end
end
