# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Ruly::Services::AgentsMd do
  let(:fixture_dir) { File.expand_path('../fixtures/agents_md', __dir__) }
  let(:fixture_recipe) { YAML.safe_load_file(File.join(fixture_dir, '.recipes.yml'))['recipes']['demo'] }

  describe '.render_skill' do
    let(:skill_path) { File.join(fixture_dir, 'rules/skills/deploy.md') }
    let(:skill) { {content: File.read(skill_path, encoding: 'UTF-8'), path: skill_path} }
    let(:rendered) { described_class.render_skill(skill) }

    it 'drops the leading frontmatter' do
      expect(rendered).not_to include('description:')
      expect(rendered.lstrip).not_to start_with('---')
    end

    it 'demotes headings by two levels' do
      expect(rendered.lines.map(&:chomp)).to include('### Deploy Skill', '#### Rollback')
    end

    it 'leaves fenced code untouched' do
      expect(rendered.lines.map(&:chomp)).to include('# deploy comment')
    end

    it 'prepends a skill-name heading when the body has none' do
      out = described_class.render_skill({content: "Just text.\n", path: 'rules/skills/release/notes.md'})
      expect(out.lines.first.chomp).to eq('### release/notes')
    end

    it 'caps demotion at h6' do
      out = described_class.render_skill({content: "# Top\n\n##### Deep\n\n###### Max\n", path: 'x.md'})
      expect(out.lines.map(&:chomp)).to include('###### Deep', '###### Max')
    end
  end

  describe '.skipped_parts' do
    let(:command) { [{content: '# Ship', path: 'rules/commands/ship.md'}] }

    it 'lists the fixture recipe parts in fixed order' do
      expect(described_class.skipped_parts(fixture_recipe, command_files: command, local_sources: []))
        .to eq(['commands (1)', 'subagents (1)', 'hooks', 'mcp_servers'])
    end

    it 'adds model and isolate' do
      parts = described_class.skipped_parts({'isolate' => true, 'model' => 'haiku'}, command_files: [],
                                                                                     local_sources: [])
      expect(parts).to eq(%w[model isolate])
    end

    it 'adds mcp_servers from rule frontmatter alone' do
      source = {content: "---\nmcp_servers:\n  - teams\n---\n# R\n", path: 'r.md'}
      expect(described_class.skipped_parts({}, command_files: [], local_sources: [source])).to eq(['mcp_servers'])
    end

    it 'returns [] for an empty recipe' do
      expect(described_class.skipped_parts({}, command_files: [], local_sources: [])).to eq([])
    end

    it 'returns [] for an Array recipe' do
      expect(described_class.skipped_parts(['rules/a.md'], command_files: [], local_sources: [])).to eq([])
    end
  end

  describe '.skipped_notice' do
    it 'is nil for no parts' do
      expect(described_class.skipped_notice([])).to be_nil
    end

    it 'names the parts' do
      expect(described_class.skipped_notice(['hooks']))
        .to eq('ℹ️  AGENTS.md target skips Claude-only parts: hooks')
    end
  end

  describe '.generated?' do
    let(:dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(dir) }

    it 'is true for a file with the ruly header' do
      path = File.join(dir, 'AGENTS.md')
      File.write(path, "#{described_class.header('demo')}\n\nbody\n")
      expect(described_class.generated?(path)).to be(true)
    end

    it 'is false for a hand-written file' do
      path = File.join(dir, 'AGENTS.md')
      File.write(path, "# Team notes\n")
      expect(described_class.generated?(path)).to be(false)
    end

    it 'is false for a missing path' do
      expect(described_class.generated?(File.join(dir, 'nope.md'))).to be(false)
    end

    it 'is false for a directory' do
      expect(described_class.generated?(dir)).to be(false)
    end
  end
end
