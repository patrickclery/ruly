# frozen_string_literal: true

module RulyBench
  # Writes the native Claude Code layout of a corpus: rules in .claude/rules/ (path rules keep `paths:`),
  # skills in .claude/skills/<name>/SKILL.md and commands in .claude/commands/. Nothing else is written.
  module NativeLayout
    module_function

    # @param corpus [RulyBench::Corpus]
    # @param into [String] target directory
    # @return [Array<String>] the written paths, relative to `into`, sorted
    # @raise [RulyBench::Error] when two corpus files map to the same native path (nothing is written)
    def build(corpus:, into:)
      entries = corpus.files.to_h { |rel| [rel, entry(corpus, rel)] }
      check_collisions!(entries)
      entries.values.map do |target, text|
        path = File.join(into, target)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text)
        target
      end.sort
    end

    # Rules are flattened (a-b/c.md and a/b-c.md both become a-b-c.md) and skills are keyed by derived name, so
    # two sources can share a target; writing both would silently drop one.
    def check_collisions!(entries)
      clashes = entries.group_by { |_, (target, _)| target }.select { |_, group| group.size > 1 }
      return if clashes.empty?

      details = clashes.sort.map { |target, group| "#{target} <- #{group.map(&:first).sort.join(', ')}" }
      raise Error, "native layout collision: #{details.join('; ')}"
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
