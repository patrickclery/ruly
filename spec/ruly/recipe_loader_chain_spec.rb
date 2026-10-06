# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Services::RecipeLoader, '.load_all_recipes' do
  let(:test_dir) { Dir.mktmpdir('ruly-chain') }
  let(:remotes_dir) { File.join(test_dir, 'remotes') }
  let(:user_file) { File.join(test_dir, 'user-recipes.yml') }
  let(:project_file) { File.join(test_dir, '.recipes.yml') }
  let(:mirror_dir) { File.join(remotes_dir, 'acme', 'rules') }

  def load(**opts)
    described_class.load_all_recipes(project_recipes_file: project_file, remotes_dir:, user_recipes_file: user_file,
                                     **opts)
  end

  def write_mirror(yaml)
    FileUtils.mkdir_p(mirror_dir)
    File.write(File.join(mirror_dir, 'recipes.yml'), yaml)
  end

  before do
    allow(described_class).to receive(:warn)
    allow(Ruly::Services::GitHubClient).to receive(:fetch_remote_content)
  end

  after { FileUtils.rm_rf(test_dir) }

  describe 'fallback chain' do
    let(:user_yaml) do
      <<~YAML
        remotes:
          - github: acme/rules
        recipes:
          from_user:
            files: [user.md]
      YAML
    end

    it 'uses the mirrored remote when present and ignores project and user recipes' do
      File.write(user_file, user_yaml)
      File.write(project_file, "recipes:\n  from_project:\n    files: [p.md]\n")
      write_mirror("recipes:\n  homelab:\n    files:\n      - home/core.md\n")

      recipes = load

      expect(recipes.keys).to eq(['homelab'])
      expect(described_class.source_origin).to eq(:remotes)
      expect(described_class.recipe_origins['homelab']).to eq('remote acme/rules')
      expect(Ruly::Services::GitHubClient).not_to have_received(:fetch_remote_content)
    end

    it 'rebases repo-relative entries onto the mirror dir and leaves absolute, ~ and URL entries alone' do
      File.write(user_file, user_yaml)
      write_mirror(<<~YAML)
        recipes:
          homelab:
            files:
              - home/core.md
              - /abs/file.md
              - ~/home/file.md
              - https://github.com/x/y/blob/main/z.md
            skills:
              - home/skills/
            commands:
              - home/commands/dm.md
            scripts:
              - bin/deploy.sh
          agent_style:
            - home/agent.md
      YAML

      recipes = load

      expect(recipes['homelab']['files']).to eq([
                                                  File.join(mirror_dir, 'home/core.md'),
                                                  '/abs/file.md',
                                                  '~/home/file.md',
                                                  'https://github.com/x/y/blob/main/z.md'
                                                ])
      expect(recipes['homelab']['skills']).to eq([File.join(mirror_dir, 'home/skills/')])
      expect(recipes['homelab']['commands']).to eq([File.join(mirror_dir, 'home/commands/dm.md')])
      expect(recipes['homelab']['scripts']).to eq([File.join(mirror_dir, 'bin/deploy.sh')])
      expect(recipes['agent_style']).to eq([File.join(mirror_dir, 'home/agent.md')])
    end

    it 'falls back to the project .recipes.yml when no mirror exists' do
      File.write(user_file, user_yaml)
      File.write(project_file, "recipes:\n  from_project:\n    files: [p.md]\n")

      recipes = load

      expect(recipes.keys).to eq(['from_project'])
      expect(described_class.source_origin).to eq(:project)
      expect(described_class).to have_received(:warn).with(%r{acme/rules is not mirrored yet})
    end

    it 'falls back to the user config when neither mirror nor project file exists' do
      File.write(user_file, user_yaml)

      recipes = load

      expect(recipes.keys).to eq(['from_user'])
      expect(described_class.source_origin).to eq(:user)
      expect(described_class.recipe_origins['from_user']).to eq(user_file)
    end

    it 'raises with a --sync hint when nothing in the chain exists' do
      expect { load }.to raise_error(Ruly::Error, /No recipes found.*ruly squash --sync/m)
    end

    it 'loads undeclared mirrors found on disk' do
      write_mirror("recipes:\n  homelab:\n    files: [home/core.md]\n")

      recipes = load

      expect(recipes.keys).to eq(['homelab'])
      expect(described_class.source_origin).to eq(:remotes)
    end

    it 'reads remotes: from the project file too' do
      File.write(project_file, "remotes:\n  - github: acme/rules\n")
      write_mirror("recipes:\n  homelab:\n    files: [home/core.md]\n")

      expect(load.keys).to eq(['homelab'])
    end
  end

  describe 'sync: true' do
    it 'mirrors declared remotes before loading' do
      File.write(user_file, "remotes:\n  - github: acme/rules\n")
      allow(Ruly::Services::RemoteSync).to receive(:sync_all!) do |remotes|
        expect(remotes.map { |r| r[:github] }).to eq(['acme/rules'])
        write_mirror("recipes:\n  homelab:\n    files: [home/core.md]\n")
      end

      recipes = load(sync: true)

      expect(Ruly::Services::RemoteSync).to have_received(:sync_all!)
      expect(recipes.keys).to eq(['homelab'])
    end
  end
end
