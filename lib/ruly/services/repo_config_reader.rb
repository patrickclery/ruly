# frozen_string_literal: true

require 'json'

module Ruly
  module Services
    # Reads CLAUDE.md, .claude/rules/*.md, and .claude/settings.json hooks
    # from a repository directory for inclusion in subagent agent files.
    module RepoConfigReader
      module_function

      # Read all repo config from a directory.
      # @param dir [String] path to the repository directory
      # @return [Hash] { claude_md:, rules:, hooks: }
      def read_repo_content(dir)
        {
          claude_md: read_claude_md(dir),
          rules: read_rules(dir),
          hooks: read_hooks(dir)
        }
      end

      # Format repo content as markdown sections for appending to agent file.
      # @param repo [Hash] output from read_repo_content
      # @return [String] formatted markdown
      def format_repo_content(repo)
        sections = []

        if repo[:claude_md] && !repo[:claude_md].strip.empty?
          sections << "## Repository Context\n\n#{repo[:claude_md]}"
        end

        if repo[:rules].any?
          rules_content = repo[:rules].map { |r| r[:content] }.join("\n\n---\n\n")
          sections << "## Repository Rules\n\n#{rules_content}"
        end

        sections.join("\n\n---\n\n")
      end

      # @param dir [String] repo directory
      # @return [String, nil] CLAUDE.md content with frontmatter stripped
      def read_claude_md(dir)
        path = File.join(dir, 'CLAUDE.md')
        return nil unless File.exist?(path)

        strip_frontmatter(File.read(path, encoding: 'UTF-8'))
      end

      # @param dir [String] repo directory
      # @return [Array<Hash>] array of { name:, content: }
      def read_rules(dir)
        rules_dir = File.join(dir, '.claude', 'rules')
        return [] unless Dir.exist?(rules_dir)

        Dir.glob(File.join(rules_dir, '*.md')).sort.map do |path|
          {
            name: File.basename(path, '.md'),
            content: strip_frontmatter(File.read(path, encoding: 'UTF-8'))
          }
        end
      end

      # @param dir [String] repo directory
      # @return [Hash] hooks from .claude/settings.json, or empty hash
      def read_hooks(dir)
        path = File.join(dir, '.claude', 'settings.json')
        return {} unless File.exist?(path)

        settings = JSON.parse(File.read(path, encoding: 'UTF-8'))
        settings['hooks'] || {}
      rescue JSON::ParserError
        {}
      end

      # Strip YAML frontmatter (--- ... ---) from content.
      # @param content [String]
      # @return [String]
      def strip_frontmatter(content)
        content.sub(/\A---\n.*?\n---\n*/m, '').strip
      end
    end
  end
end
