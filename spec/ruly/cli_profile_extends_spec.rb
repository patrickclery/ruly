# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::Services::ProfileLoader, '.resolve_extends!' do
  describe 'basic extends' do
    it 'merges parent files into child' do
      profiles = {
        'base' => {
          'description' => 'Base profile',
          'files' => ['rules/base.md']
        },
        'child' => {
          'extends' => 'base',
          'description' => 'Child profile',
          'files' => ['rules/child.md']
        }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(profiles['child']['description']).to eq('Child profile')
      expect(profiles['child']).not_to have_key('extends')
    end
  end

  describe 'integration with load_all_profiles' do
    let(:test_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(test_dir) }

    it 'resolves extends when loading profiles from YAML' do
      profiles_yml = <<~YAML
        profiles:
          base:
            description: "Base profile"
            files:
              - rules/base.md
            mcp_servers:
              - task-master-ai
          child:
            extends: base
            description: "Child profile"
            files:
              - rules/child.md
            mcp_servers:
              - playwright
      YAML

      File.write(File.join(test_dir, 'profiles.yml'), profiles_yml)

      profiles = described_class.load_all_profiles(
        gem_root: test_dir,
        base_profiles_file: File.join(test_dir, 'profiles.yml')
      )

      expect(profiles['child']['files']).to eq(['rules/base.md', 'rules/child.md'])
      expect(profiles['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
      expect(profiles['child']).not_to have_key('extends')
      # Parent should be unchanged
      expect(profiles['base']['files']).to eq(['rules/base.md'])
    end
  end

  describe 'scalar override (child wins)' do
    it 'child description overrides parent' do
      profiles = {
        'base' => { 'description' => 'Base', 'model' => 'sonnet' },
        'child' => { 'extends' => 'base', 'description' => 'Child', 'model' => 'opus' }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['description']).to eq('Child')
      expect(profiles['child']['model']).to eq('opus')
    end

    it 'child inherits scalars it does not define' do
      profiles = {
        'base' => { 'description' => 'Base', 'model' => 'sonnet', 'tier' => 'claude_pro' },
        'child' => { 'extends' => 'base', 'description' => 'Child' }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['model']).to eq('sonnet')
      expect(profiles['child']['tier']).to eq('claude_pro')
    end
  end

  describe 'array union (deduped, parent first)' do
    it 'unions files without duplicates' do
      profiles = {
        'base' => { 'files' => ['a.md', 'b.md'] },
        'child' => { 'extends' => 'base', 'files' => ['b.md', 'c.md'] }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['files']).to eq(['a.md', 'b.md', 'c.md'])
    end

    it 'unions mcp_servers' do
      profiles = {
        'base' => { 'mcp_servers' => ['task-master-ai'] },
        'child' => { 'extends' => 'base', 'mcp_servers' => ['playwright'] }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['mcp_servers']).to eq(['task-master-ai', 'playwright'])
    end

    it 'handles child with no array key (inherits parent array)' do
      profiles = {
        'base' => { 'files' => ['a.md'] },
        'child' => { 'extends' => 'base' }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['files']).to eq(['a.md'])
    end
  end

  describe 'subagent merging' do
    it 'unions subagents by name, child wins on conflict' do
      profiles = {
        'base' => {
          'subagents' => [
            { 'name' => 'agent_a', 'profile' => 'prof-a' },
            { 'name' => 'agent_b', 'profile' => 'prof-b', 'model' => 'sonnet' }
          ]
        },
        'child' => {
          'extends' => 'base',
          'subagents' => [
            { 'name' => 'agent_b', 'profile' => 'prof-b', 'model' => 'haiku' },
            { 'name' => 'agent_c', 'profile' => 'prof-c' }
          ]
        }
      }

      described_class.resolve_extends!(profiles)

      names = profiles['child']['subagents'].map { |s| s['name'] }
      expect(names).to contain_exactly('agent_a', 'agent_b', 'agent_c')

      agent_b = profiles['child']['subagents'].find { |s| s['name'] == 'agent_b' }
      expect(agent_b['model']).to eq('haiku')
    end
  end

  describe 'transitive extends (A extends B extends C)' do
    it 'resolves multi-level inheritance' do
      profiles = {
        'grandparent' => { 'files' => ['gp.md'], 'mcp_servers' => ['server-a'] },
        'parent' => { 'extends' => 'grandparent', 'files' => ['p.md'] },
        'child' => { 'extends' => 'parent', 'files' => ['c.md'] }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['child']['files']).to eq(['gp.md', 'p.md', 'c.md'])
      expect(profiles['child']['mcp_servers']).to eq(['server-a'])
      expect(profiles['parent']['files']).to eq(['gp.md', 'p.md'])
    end
  end

  describe 'circular extends detection' do
    it 'raises error on direct circular reference' do
      profiles = {
        'a' => { 'extends' => 'b' },
        'b' => { 'extends' => 'a' }
      }

      expect { described_class.resolve_extends!(profiles) }.to raise_error(
        Ruly::Error, /Circular extends detected/
      )
    end

    it 'raises error on indirect circular reference' do
      profiles = {
        'a' => { 'extends' => 'b' },
        'b' => { 'extends' => 'c' },
        'c' => { 'extends' => 'a' }
      }

      expect { described_class.resolve_extends!(profiles) }.to raise_error(
        Ruly::Error, /Circular extends detected/
      )
    end
  end

  describe 'missing parent detection' do
    it 'raises error when parent does not exist' do
      profiles = {
        'child' => { 'extends' => 'nonexistent' }
      }

      expect { described_class.resolve_extends!(profiles) }.to raise_error(
        Ruly::Error, /does not exist/
      )
    end
  end

  describe 'profiles without extends are unchanged' do
    it 'does not modify profiles that have no extends key' do
      profiles = {
        'standalone' => { 'description' => 'Solo', 'files' => ['a.md'] }
      }

      described_class.resolve_extends!(profiles)

      expect(profiles['standalone']).to eq({ 'description' => 'Solo', 'files' => ['a.md'] })
    end
  end

  describe 'array profiles are skipped' do
    it 'does not attempt to resolve extends on array profiles' do
      profiles = {
        'base' => { 'files' => ['a.md'] },
        'agent' => ['file1.md', 'file2.md']
      }

      expect { described_class.resolve_extends!(profiles) }.not_to raise_error
      expect(profiles['agent']).to eq(['file1.md', 'file2.md'])
    end
  end
end
