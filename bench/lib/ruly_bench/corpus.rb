# frozen_string_literal: true

module RulyBench
  # A rules repository on disk: its recipes, its markdown files and how each file maps to the native layout.
  class Corpus
    ROOT_SKIPS = %w[AGENTS.md CHANGELOG.md CLAUDE.local.md CLAUDE.md LICENSE.md README.md].freeze
    SOURCE_KEYS = %w[commands files skills].freeze
    REMOTE_URL = %r{\Ahttps?://}i

    attr_reader :dir

    # @param content [String] markdown with optional frontmatter
    # @param fallback_name [String] name used when frontmatter has no `name`
    # @return [String] "name: description", or the name alone when there is no description
    def self.descriptor(content, fallback_name)
      frontmatter, = Ruly::Services::FrontmatterParser.parse(content)
      frontmatter = {} unless frontmatter.is_a?(Hash)
      name = frontmatter['name'].to_s.strip
      name = fallback_name if name.empty?
      description = frontmatter['description'].to_s.strip
      description.empty? ? name : "#{name}: #{description}"
    end

    # @param dir [String] corpus root (holds recipes.yml)
    def initialize(dir)
      @dir = File.expand_path(dir)
    end

    # @return [Hash] the `recipes:` hash of <dir>/recipes.yml
    # @raise [RulyBench::Error] when the file or the key is missing
    def recipes
      @recipes ||= begin
        path = File.join(dir, 'recipes.yml')
        raise Error, "no recipes.yml in corpus #{File.basename(dir)}" unless File.file?(path)

        data = YAML.safe_load_file(path, aliases: true)
        recipes = data.is_a?(Hash) ? data['recipes'] : nil
        raise Error, 'recipes.yml has no recipes: key' unless recipes.is_a?(Hash)

        recipes
      end
    end

    # @return [Array<String>] every counted markdown file, dir-relative, sorted
    def files
      @files ||= Dir.glob('**/*.md', base: dir).reject { |rel| skipped_file?(rel) }.sort
    end

    # @param rel [String] dir-relative path
    # @return [Symbol] :skill, :command, :path_rule or :rule
    def kind(rel)
      segments = rel.split('/')
      return :skill if segments.include?('skills')
      return :command if segments.include?('commands')

      frontmatter, = Ruly::Services::FrontmatterParser.parse(read(rel))
      frontmatter.is_a?(Hash) && frontmatter.key?('paths') ? :path_rule : :rule
    end

    # @return [String] file content with frontmatter stripped exactly as squash strips it
    def body(rel)
      Ruly::Services::FrontmatterParser.strip_metadata(read(rel))
    end

    # @see Corpus.descriptor
    def descriptor(content, fallback_name)
      self.class.descriptor(content, fallback_name)
    end

    # @return [String] the up-front descriptor of a corpus skill or command file
    def source_descriptor(rel)
      descriptor(read(rel), Ruly::Services::ScriptManager.derive_skill_name(rel))
    end

    # @param recipe [Hash] one recipe's config
    # @return [Boolean] true when the recipe pulls remote sources (a `sources:` key or an http(s) entry)
    def remote?(recipe)
      return false unless recipe.is_a?(Hash)
      return true if recipe.key?('sources')

      SOURCE_KEYS.any? { |key| Array(recipe[key]).any? { |entry| entry.to_s.strip.match?(REMOTE_URL) } }
    end

    def fixture?
      dir == File.expand_path(FIXTURE_CORPUS)
    end

    # Join bodies the way SquashHelpers.write_sources writes them: each body newline-terminated,
    # one blank line between bodies.
    # @param bodies [Array<String>]
    # @return [String]
    def concat(bodies)
      bodies.map { |b| b.end_with?("\n") ? b : "#{b}\n" }.join("\n")
    end

    private

    def skipped_file?(rel)
      segments = rel.split('/')
      return true if segments.any? { |s| s.start_with?('.') }
      return true if segments.last == 'stats.md'

      segments.size == 1 && ROOT_SKIPS.include?(rel)
    end

    def read(rel)
      File.read(File.join(dir, rel))
    end
  end
end
