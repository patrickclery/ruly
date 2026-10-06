# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Services::RecipeLoader, '.apply_overrides!' do
  let(:test_dir) { Dir.mktmpdir('ruly-overrides') }
  let(:remotes_dir) { File.join(test_dir, 'remotes') }
  let(:user_file) { File.join(test_dir, 'user-recipes.yml') }
  let(:project_file) { File.join(test_dir, '.recipes.yml') }
  let(:mirror_dir) { File.join(remotes_dir, 'acme', 'rules') }

  let(:mirror_yaml) do
    <<~YAML
      recipes:
        base:
          description: "Base"
          files: [base.md]
        homelab:
          extends: base
          description: "Homelab"
          model: sonnet
          files:
            - home/core.md
          mcp_servers:
            - teams
          subagents:
            - name: media
              recipe: media
              model: haiku
    YAML
  end

  def load
    described_class.load_all_recipes(project_recipes_file: project_file, remotes_dir:, user_recipes_file: user_file)
  end

  before do
    allow(described_class).to receive(:warn)
    FileUtils.mkdir_p(mirror_dir)
    File.write(File.join(mirror_dir, 'recipes.yml'), mirror_yaml)
  end

  after { FileUtils.rm_rf(test_dir) }

  it 'adds files and mcp_servers to a shared recipe without restating it' do
    File.write(user_file, <<~YAML)
      remotes:
        - github: acme/rules
      overrides:
        homelab:
          files:
            - /home/me/notes/local.md
          mcp_servers:
            - grafana
    YAML

    recipe = load['homelab']

    expect(recipe['files']).to eq([File.join(mirror_dir, 'base.md'), File.join(mirror_dir, 'home/core.md'),
                                   '/home/me/notes/local.md'])
    expect(recipe['mcp_servers']).to eq(%w[teams grafana])
    expect(recipe['description']).to eq('Homelab')
    expect(described_class.recipe_origins['homelab']).to include('overrides')
  end

  it 'replaces scalars and merges subagents by name' do
    File.write(user_file, <<~YAML)
      overrides:
        homelab:
          model: opus
          subagents:
            - name: media
              recipe: media
              model: opus
            - name: sysadmin
              recipe: sysadmin
    YAML

    recipe = load['homelab']

    expect(recipe['model']).to eq('opus')
    expect(recipe['subagents'].map { |s| [s['name'], s['model']] }).to eq([%w[media opus], ['sysadmin', nil]])
  end

  it 'rebases relative override entries onto the target mirror dir' do
    File.write(user_file, "overrides:\n  homelab:\n    skills:\n      - home/skills/extra.md\n")

    expect(load['homelab']['skills']).to eq([File.join(mirror_dir, 'home/skills/extra.md')])
  end

  it 'still applies extends: on an overridden recipe' do
    File.write(user_file, "overrides:\n  homelab:\n    mcp_servers: [grafana]\n")

    recipe = load['homelab']

    expect(recipe['files'].first).to eq(File.join(mirror_dir, 'base.md'))
    expect(recipe).not_to have_key('extends')
  end

  it 'applies project overrides after user overrides' do
    File.write(user_file, "overrides:\n  homelab:\n    files: [/u.md]\n    model: opus\n")
    File.write(project_file, "overrides:\n  homelab:\n    files: [/p.md]\n    model: haiku\n")

    recipe = load['homelab']

    expect(recipe['files'].last(2)).to eq(['/u.md', '/p.md'])
    expect(recipe['model']).to eq('haiku')
  end

  it 'raises when an override targets a recipe that is not loaded' do
    File.write(user_file, "overrides:\n  nope:\n    files: [/x.md]\n")

    expect { load }.to raise_error(Ruly::Error, /overrides: 'nope'.*does not match a loaded recipe/)
  end

  it 'lets user recipes: define machine-local recipes only when they win the chain' do
    File.write(user_file, "recipes:\n  scratch:\n    files: [/s.md]\n")

    expect(load.keys).to eq(%w[base homelab])
  end
end
