# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench::Corpus do
  subject(:corpus) { described_class.new(dir) }

  let(:dir) { Dir.mktmpdir('ruly-bench-corpus') }

  after { FileUtils.rm_rf(dir) }

  def write(rel, content)
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  describe '#kind' do
    before do
      write('skills/x.md', "---\nname: x\ndescription: Do x.\n---\n# X\n")
      write('a/commands/y.md', "---\ndescription: Run y.\n---\n# Y\n")
      write('frontend/components.md', "---\npaths:\n  - \"**/*.tsx\"\n---\n# Components\n")
      write('core/plain.md', "# Plain\n")
    end

    it 'classifies a file under skills/ as a skill' do
      expect(corpus.kind('skills/x.md')).to eq(:skill)
    end

    it 'classifies a file under a commands/ segment as a command' do
      expect(corpus.kind('a/commands/y.md')).to eq(:command)
    end

    it 'classifies a file with paths: frontmatter as a path rule' do
      expect(corpus.kind('frontend/components.md')).to eq(:path_rule)
    end

    it 'classifies a plain file as a rule' do
      expect(corpus.kind('core/plain.md')).to eq(:rule)
    end
  end

  describe '#files' do
    before do
      write('core/plain.md', "# Plain\n")
      write('.git/info.md', "# git\n")
      write('.claude/skills/x/SKILL.md', "# generated\n")
      write('stats.md', "# stats\n")
      write('README.md', "# Readme\n")
      write('docs/README.md', "# Nested readme\n")
    end

    it 'lists markdown files sorted, skipping dot dirs, stats.md and a root README.md' do
      expect(corpus.files).to eq(%w[core/plain.md docs/README.md])
    end
  end

  describe '#descriptor' do
    it 'joins name and description' do
      expect(corpus.descriptor("---\nname: deploy\ndescription: Ship a release.\n---\n# D\n", 'f')).to eq(
        'deploy: Ship a release.'
      )
    end

    it 'falls back to the given name when frontmatter has no name' do
      expect(corpus.descriptor("---\ndescription: Open a PR.\n---\n# O\n", 'open-pr')).to eq('open-pr: Open a PR.')
    end

    it 'returns the name alone when the description is blank' do
      expect(corpus.descriptor("---\nname: deploy\ndescription: ''\n---\n# D\n", 'f')).to eq('deploy')
    end
  end

  describe '#source_descriptor' do
    it 'names a command file without a name: key by its basename' do
      write('commands/triage.md', "---\ndescription: Triage new issues.\n---\n# Triage\n")
      expect(corpus.source_descriptor('commands/triage.md')).to eq('triage: Triage new issues.')
    end
  end

  describe '#body' do
    it 'strips frontmatter the way squash does' do
      write('ruby/style.md', "---\nrequires:\n  - ../core/principles.md\n---\n# Style\n")
      expect(corpus.body('ruby/style.md')).to eq("\n# Style\n")
    end
  end

  describe '#concat' do
    it 'newline-terminates each body and separates bodies with one blank line' do
      bodies = %W[a b\n]
      expect(corpus.concat(bodies)).to eq("a\n\nb\n")
    end
  end

  describe '#recipes' do
    it 'reads the recipes: hash of recipes.yml' do
      write('recipes.yml', "recipes:\n  demo:\n    files:\n      - core/plain.md\n")
      expect(corpus.recipes).to eq('demo' => {'files' => ['core/plain.md']})
    end

    it 'raises RulyBench::Error when recipes.yml is missing' do
      expect { corpus.recipes }.to raise_error(RulyBench::Error, /no recipes\.yml/)
    end

    it 'raises RulyBench::Error when the recipes: key is missing' do
      write('recipes.yml', "other: {}\n")
      expect { corpus.recipes }.to raise_error(RulyBench::Error, /no recipes: key/)
    end
  end

  describe '#remote?' do
    it 'is true when a files entry is an https URL' do
      expect(corpus.remote?('files' => ['https://github.com/acme/rules/blob/main/x.md'])).to be(true)
    end

    it 'is true when a skills or commands entry is an http URL' do
      expect(corpus.remote?('skills' => ['http://example.test/s.md'])).to be(true)
      expect(corpus.remote?('commands' => ['http://example.test/c.md'])).to be(true)
    end

    it 'is true when the recipe has a sources: key' do
      expect(corpus.remote?('sources' => [{'github' => 'acme/rules'}])).to be(true)
    end

    it 'is false for local paths only' do
      expect(corpus.remote?('files' => ['core/'], 'skills' => ['skills/x.md'])).to be(false)
    end
  end

  describe '#fixture?' do
    it 'is true only for the committed fixture corpus' do
      expect(described_class.new(RulyBench::FIXTURE_CORPUS).fixture?).to be(true)
      expect(corpus.fixture?).to be(false)
    end
  end
end
