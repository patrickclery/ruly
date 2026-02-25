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
end
