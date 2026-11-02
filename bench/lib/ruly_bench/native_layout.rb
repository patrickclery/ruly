# frozen_string_literal: true

module RulyBench
  # Writes the native Claude Code layout of a corpus: rules in .claude/rules/ (path rules keep `paths:`),
  # skills in .claude/skills/<name>/SKILL.md and commands in .claude/commands/. Nothing else is written.
  module NativeLayout
    module_function

    # @param corpus [RulyBench::Corpus]
    # @param into [String] target directory
    # @return [Array<String>] the written paths, relative to `into`, sorted
    def build(corpus:, into:)
      corpus.files.map do |rel|
        target, text = entry(corpus, rel)
        path = File.join(into, target)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text)
        target
      end.sort
    end

    def entry(corpus, rel)
      content = File.read(File.join(corpus.dir, rel))
      case corpus.kind(rel)
      when :skill
        name = Ruly::Services::ScriptManager.derive_skill_name(rel)
        [File.join('.claude/skills', name, 'SKILL.md'), strip(content)]
      when :command
        segments = rel.split('/')
        [File.join('.claude/commands', *segments.drop(segments.index('commands') + 1)), strip(content)]
      else
        [File.join('.claude/rules', rel.tr('/', '-')), strip(content, keep_frontmatter: true)]
      end
    end

    def strip(content, keep_frontmatter: false)
      Ruly::Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)
    end
  end
end
