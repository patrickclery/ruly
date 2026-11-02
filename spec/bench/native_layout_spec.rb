# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench::NativeLayout do
  let(:corpus_dir) { Dir.mktmpdir('ruly-bench-native-corpus') }
  let(:into) { Dir.mktmpdir('ruly-bench-native-out') }

  after { FileUtils.rm_rf([corpus_dir, into]) }

  def write(rel, content)
    path = File.join(corpus_dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  before do
    write('core/principles.md', "# Principles\n\nPrefer small changes.\n")
    write('web/views.md', "---\npaths:\n  - \"**/*.tsx\"\nrequires:\n  - ../core/principles.md\n---\n" \
                          "# Views\n\nNo logic.\n")
    write('skills/helper.md', "---\nname: helper\ndescription: Help out.\nrequires:\n  - ../core/principles.md\n---\n" \
                              "# Helper\n\nList the options.\n")
    write('commands/triage.md', "---\ndescription: Triage bugs.\n---\n# Triage\n\nSet a severity.\n")
    write('recipes.yml', "recipes:\n  demo:\n    files:\n      - core/\n")
  end

  it 'writes rules, skills and commands in the native layout and nothing else' do
    written = described_class.build(corpus: RulyBench::Corpus.new(corpus_dir), into:)

    expect(written).to eq(%w[.claude/commands/triage.md .claude/rules/core-principles.md .claude/rules/web-views.md
                             .claude/skills/helper/SKILL.md])
    expect(Dir.glob('**/*', File::FNM_DOTMATCH, base: into).select { File.file?(File.join(into, _1)) }.sort)
      .to eq(written)
  end

  it 'keeps paths: and drops requires: on a path rule' do
    described_class.build(corpus: RulyBench::Corpus.new(corpus_dir), into:)
    rule = File.read(File.join(into, '.claude/rules/web-views.md'))

    expect(rule).to start_with("---\npaths:\n")
    expect(rule).to include('**/*.tsx')
    expect(rule).not_to include('requires')
    expect(rule).to include('No logic.')
  end

  it 'keeps name and description on a skill and drops requires:' do
    described_class.build(corpus: RulyBench::Corpus.new(corpus_dir), into:)
    skill = File.read(File.join(into, '.claude/skills/helper/SKILL.md'))

    expect(skill).to include('description: Help out.')
    expect(skill).to include('name: helper')
    expect(skill).not_to include('requires')
  end

  it 'writes no CLAUDE.md, CLAUDE.local.md or source files' do
    described_class.build(corpus: RulyBench::Corpus.new(corpus_dir), into:)

    expect(Dir.children(into)).to eq(['.claude'])
  end
end
