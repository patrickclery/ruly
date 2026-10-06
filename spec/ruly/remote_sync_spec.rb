# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Services::RemoteSync do
  let(:remotes_dir) { Dir.mktmpdir('ruly-remotes') }
  let(:remote) { described_class.normalize_remote({'github' => 'acme/rules'}, remotes_dir:) }
  let(:mirror_dir) { File.join(remotes_dir, 'acme', 'rules') }
  let(:blob_prefix) { 'https://github.com/acme/rules/blob/main/' }

  let(:recipes_yaml) do
    <<~YAML
      recipes:
        homelab:
          description: "Homelab"
          files:
            - home/core.md
            - /abs/elsewhere.md
            - https://github.com/other/repo/blob/main/x.md
          skills:
            - home/skills/
          scripts:
            - bin/deploy.sh
    YAML
  end

  # Simulated remote repository: repo-relative path => content
  let(:remote_files) do
    {
      'bin/deploy.sh' => "#!/bin/sh\necho deploy\n",
      'home/core.md' => "---\nrequires:\n  - ./shared.md\n  - /linux/base\n---\n# Core\n",
      'home/shared.md' => "---\nskills:\n  - skills/network.md\n---\n# Shared\n",
      'home/skills/network.md' => "# Network skill\n",
      'home/skills/plane.md' => "---\nrequires:\n  - ../core.md\n---\n# Plane skill\n",
      'linux/base.md' => "# Base\n",
      'recipes.yml' => recipes_yaml
    }
  end

  before do
    files = remote_files
    rel = ->(url) { url.delete_prefix(blob_prefix) }
    client = Ruly::Services::GitHubClient
    allow(client).to receive(:fetch_remote_content) { |url| files[rel.call(url)] }
    allow(client).to receive(:fetch_github_files_graphql) do |_repo, sources|
      sources.to_h { |s| [s[:path], files[rel.call(s[:path])]] }.compact
    end
    allow(client).to receive(:list_github_directory) do |_repo, _branch, path, **|
      files.keys.select { |k| k.start_with?("#{path}/") && k != 'recipes.yml' }
    end
    allow(described_class).to receive(:puts)
    allow(described_class).to receive(:warn)
    allow(described_class).to receive(:gh_available?).and_return(true)
  end

  after { FileUtils.rm_rf(remotes_dir) }

  describe '.normalize_remote' do
    it 'accepts a bare owner/repo string with defaults' do
      spec = described_class.normalize_remote('acme/rules', remotes_dir:)
      expect(spec).to eq(branch: 'main', github: 'acme/rules', mirror_dir:, path: 'recipes.yml')
    end

    it 'accepts a hash with branch and path overrides' do
      spec = described_class.normalize_remote({'branch' => 'dev', 'github' => 'acme/rules', 'path' => 'cfg/r.yml'},
                                              remotes_dir:)
      expect(spec).to include(branch: 'dev', path: 'cfg/r.yml')
    end

    it 'strips github: and URL prefixes' do
      expect(described_class.normalize_remote('github:acme/rules', remotes_dir:)[:github]).to eq('acme/rules')
      expect(described_class.normalize_remote('https://github.com/acme/rules.git', remotes_dir:)[:github])
        .to eq('acme/rules')
    end

    it 'rejects entries without owner/repo' do
      expect { described_class.normalize_remote('just-a-name', remotes_dir:) }
        .to raise_error(Ruly::Error, %r{owner/repo})
      expect { described_class.normalize_remote({}, remotes_dir:) }.to raise_error(Ruly::Error)
    end
  end

  describe '.sync!' do
    it 'mirrors the recipes file and every referenced file with repo-relative paths' do
      result = described_class.sync!(remote)

      expect(result[:mirror_dir]).to eq(mirror_dir)
      expect(File.read(File.join(mirror_dir, 'recipes.yml'))).to eq(recipes_yaml)
      expect(File.exist?(File.join(mirror_dir, 'home/core.md'))).to be(true)
      expect(File.exist?(File.join(mirror_dir, 'bin/deploy.sh'))).to be(true)
    end

    it 'expands directory entries and follows requires:/skills: transitively' do
      described_class.sync!(remote)

      %w[home/skills/network.md home/skills/plane.md home/shared.md linux/base.md].each do |rel|
        expect(File.exist?(File.join(mirror_dir, rel))).to be(true), "expected #{rel} to be mirrored"
      end
    end

    it 'does not fetch absolute paths or URLs' do
      described_class.sync!(remote)

      expect(Ruly::Services::GitHubClient).not_to have_received(:fetch_remote_content)
        .with(a_string_including('other/repo'))
      expect(Dir.glob(File.join(mirror_dir, '**', '*')).grep(/elsewhere/)).to be_empty
    end

    it 'raises listing every missing file and leaves an existing mirror untouched' do
      described_class.sync!(remote)
      remote_files['linux/base.md'] = nil # listed but unfetchable
      remote_files['home/skills/plane.md'] = nil

      expect { described_class.sync!(remote) }
        .to raise_error(Ruly::Error) { |e| expect(e.message).to include('linux/base.md', 'home/skills/plane.md') }
      expect(File.exist?(File.join(mirror_dir, 'linux/base.md'))).to be(true)
    end

    it 'raises when the recipes file cannot be fetched and no mirror exists' do
      remote_files.delete('recipes.yml')

      expect { described_class.sync!(remote) }.to raise_error(Ruly::Error, %r{Could not fetch acme/rules})
      expect(Dir.exist?(mirror_dir)).to be(false)
    end

    it 'keeps the existing mirror with a warning when the recipes file cannot be fetched' do
      described_class.sync!(remote)
      remote_files.delete('recipes.yml')

      expect(described_class.sync!(remote)).to be_nil
      expect(described_class).to have_received(:warn).with(/keeping existing mirror/)
      expect(File.exist?(File.join(mirror_dir, 'home/core.md'))).to be(true)
    end

    it 'removes files that are no longer referenced upstream' do
      described_class.sync!(remote)
      remote_files['recipes.yml'] = "recipes:\n  homelab:\n    files:\n      - linux/base.md\n"

      described_class.sync!(remote)

      expect(File.exist?(File.join(mirror_dir, 'linux/base.md'))).to be(true)
      expect(File.exist?(File.join(mirror_dir, 'home/core.md'))).to be(false)
    end
  end

  describe '.sync! via git clone' do
    let(:clone_dir) { Dir.mktmpdir('ruly-clone') }

    before do
      remote_files.each do |rel, content|
        FileUtils.mkdir_p(File.join(clone_dir, File.dirname(rel)))
        File.write(File.join(clone_dir, rel), content)
      end
      allow(described_class).to receive(:clone_repo).and_return(clone_dir)
    end

    it 'falls back to a shallow clone when gh is unavailable and never calls the GitHub API' do
      allow(described_class).to receive(:gh_available?).and_return(false)

      described_class.sync!(remote)

      expect(described_class).to have_received(:clone_repo).with(remote)
      expect(Ruly::Services::GitHubClient).not_to have_received(:fetch_remote_content)
      %w[recipes.yml home/core.md home/shared.md linux/base.md home/skills/plane.md bin/deploy.sh].each do |rel|
        expect(File.exist?(File.join(mirror_dir, rel))).to be(true), "expected #{rel} to be mirrored"
      end
      expect(Dir.exist?(clone_dir)).to be(false)
    end

    it 'falls back to a clone when gh is present but cannot fetch the recipes file' do
      allow(Ruly::Services::GitHubClient).to receive(:fetch_remote_content).and_return(nil)

      described_class.sync!(remote)

      expect(described_class).to have_received(:clone_repo)
      expect(File.exist?(File.join(mirror_dir, 'home/core.md'))).to be(true)
    end

    it 'raises when neither gh nor git can fetch' do
      allow(described_class).to receive_messages(clone_repo: nil, gh_available?: false)

      expect { described_class.sync!(remote) }.to raise_error(Ruly::Error, /Could not fetch/)
    end
  end

  describe '.sync_all!' do
    before { described_class.reset_synced_repos! }

    it 'syncs each remote only once per process' do
      allow(described_class).to receive(:sync!).and_call_original

      described_class.sync_all!([remote])
      described_class.sync_all!([remote])

      expect(described_class).to have_received(:sync!).once
    end
  end

  describe '.undeclared_mirrors' do
    it 'lists mirrors on disk that are not declared' do
      described_class.sync!(remote)
      FileUtils.mkdir_p(File.join(remotes_dir, 'other', 'repo'))
      File.write(File.join(remotes_dir, 'other', 'repo', 'recipes.yml'), "recipes: {}\n")

      extra = described_class.undeclared_mirrors([remote], remotes_dir:)

      expect(extra.map { |r| r[:github] }).to eq(['other/repo'])
    end
  end
end
