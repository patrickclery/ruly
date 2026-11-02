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

  describe '.demote_headings' do
    def demote(text) = described_class.demote_headings(text).lines.map(&:chomp)

    it 'keeps a 3-backtick block nested in a 4-backtick fence untouched' do
      text = "# Top\n\n````md\n# in outer\n```bash\n# in inner\n```\n# still code\n````\n\n# After\n"
      expect(demote(text)).to eq(['### Top', '', '````md', '# in outer', '```bash', '# in inner', '```',
                                  '# still code', '````', '', '### After'])
    end

    it 'keeps backtick fences inside a ~~~ block untouched and demotes the heading after it' do
      text = "~~~\n```\n# code\n```\n~~~\n# After\n"
      expect(demote(text)).to eq(['~~~', '```', '# code', '```', '~~~', '### After'])
    end

    it 'closes a fence only on a run at least as long as the opener' do
      text = "~~~~\n~~~\n# code\n~~~~~\n# After\n"
      expect(demote(text)).to eq(['~~~~', '~~~', '# code', '~~~~~', '### After'])
    end

    it 'does not close a fence on a line with an info string' do
      text = "```\n```ruby\n# code\n```\n# After\n"
      expect(demote(text)).to eq(['```', '```ruby', '# code', '```', '### After'])
    end

    it 'accepts up to 3 spaces of fence indent and trailing whitespace on the closer' do
      text = "   ```\n# code\n```  \n# After\n"
      expect(demote(text)).to eq(['   ```', '# code', '```  ', '### After'])
    end

    it 'ignores a fence-like line indented 4 spaces' do
      text = "    ```\n# Real\n"
      expect(demote(text)).to eq(['    ```', '### Real'])
    end

    it 'does not open a fence on a backtick run whose info string contains a backtick' do
      text = "``` a`b\n# Real\n"
      expect(demote(text)).to eq(['``` a`b', '### Real'])
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

  describe '.rule_body' do
    it 'drops kept directive frontmatter and keeps the body as strip_metadata splits it' do
      expect(described_class.rule_body("---\ndescription: X\n---\n# R\n")).to eq("\n# R\n")
    end

    it 'returns content without frontmatter unchanged' do
      expect(described_class.rule_body("# R\n\n---\n")).to eq("# R\n\n---\n")
    end

    it 'returns an unterminated frontmatter block unchanged' do
      expect(described_class.rule_body("---\n# R\n")).to eq("---\n# R\n")
    end
  end

  describe '.script_ignore_patterns' do
    it 'lists each local and remote script under .claude/scripts/ once' do
      scripts = {local: [{relative_path: 'a.sh'}, {relative_path: 'a.sh'}], remote: [{filename: 'b.sh'}]}
      expect(described_class.script_ignore_patterns(scripts)).to eq(%w[.claude/scripts/a.sh .claude/scripts/b.sh])
    end

    it 'is empty without scripts' do
      expect(described_class.script_ignore_patterns({local: [], remote: []})).to eq([])
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
