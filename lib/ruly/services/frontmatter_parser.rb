# frozen_string_literal: true

require 'yaml'

module Ruly
  module Services
    # Pure parsing methods for YAML frontmatter in markdown files.
    # All methods are stateless and have no external dependencies.
    module FrontmatterParser
      module_function

      # Parses YAML frontmatter from content string.
      # @param content [String] The markdown content with optional frontmatter
      # @return [Array(Hash, String)] A tuple of [frontmatter_hash, content]
      def parse(content)
        return [{}, content] unless content.start_with?('---')

        # Ensure we have a mutable string
        content = content.dup.force_encoding('UTF-8')
        yaml_match = content.match(/^---\n(.+?)\n---\n?/m)
        return [{}, content] unless yaml_match

        begin
          frontmatter = YAML.safe_load(yaml_match[1]) || {}
          # Content without frontmatter (but we keep it for the output)
          [frontmatter, content]
        rescue StandardError => e
          puts "\u26a0\ufe0f  Warning: Failed to parse frontmatter: #{e.message}" if ENV['DEBUG']
          [{}, content]
        end
      end

      # Strips or filters metadata fields from frontmatter.
      # @param content [String] The markdown content with optional frontmatter
      # @param keep_frontmatter [Boolean] When false, strips all frontmatter except Claude Code
      #   directives. When true, strips only metadata fields (requires, recipes, essential, etc.)
      # @return [String] The content with frontmatter stripped/filtered
      def strip_metadata(content, keep_frontmatter: false)
        # Check if content has YAML frontmatter
        return content unless content.start_with?('---')

        # Split content into frontmatter and body
        parts = content.split(/^---\s*$/, 3)
        return content if parts.length < 3

        frontmatter = parts[1]
        body = parts[2]

        # Default behavior: strip all frontmatter EXCEPT Claude Code directives
        unless keep_frontmatter
          # Extract Claude Code directives to preserve
          claude_directives = {}
          %w[name description permissionMode allowed_tools model].each do |key|
            claude_directives[key] = Regexp.last_match(1).strip if frontmatter =~ /^#{key}:\s*(.+)$/
          end

          # If we have Claude Code directives, keep only those
          if claude_directives.any?
            preserved = claude_directives.map { |k, v| "#{k}: #{v}" }.join("\n")
            return "---\n#{preserved}\n---#{body}"
          end

          return body
        end

        # With keep_frontmatter: strip only metadata fields (requires, recipes, essential)
        # This handles both:
        # 1. Single line: "requires: value" or "requires: [value1, value2]"
        # 2. Multi-line array format:
        #    requires:
        #      - item1
        #      - item2
        # Match 'requires:' and all indented lines that follow it
        # Stop when we hit a line that starts with a letter (next YAML key) or end
        frontmatter = frontmatter.gsub(/^requires:.*?(?=^\w|\z)/m, '')

        # Remove the recipes field and its values (same format as requires)
        frontmatter = frontmatter.gsub(/^recipes:.*?(?=^\w|\z)/m, '')

        # Remove the essential field (single line: "essential: true" or "essential: false")
        frontmatter = frontmatter.gsub(/^essential:.*?(?=\n|\z)/m, '')

        # Remove the mcp_servers field and its values (same format as requires)
        frontmatter = frontmatter.gsub(/^mcp_servers:.*?(?=^\w|\z)/m, '')

        # Remove the skills field and its values (same format as requires)
        frontmatter = frontmatter.gsub(/^skills:.*?(?=^\w|\z)/m, '')

        # Remove the dispatches field and its values (same format as requires)
        frontmatter = frontmatter.gsub(/^dispatches:.*?(?=^\w|\z)/m, '')

        # Clean up any extra blank lines
        frontmatter = frontmatter.gsub(/\n\n+/, "\n").strip

        # Reconstruct the content
        if frontmatter.empty?
          # If frontmatter is empty after removing metadata, remove the frontmatter entirely
          body
        else
          "---\n#{frontmatter}\n---#{body}"
        end
      end

      # Extracts require_shell_commands from frontmatter.
      # @param content [String] The file content with potential frontmatter
      # @return [Array<String>] List of required shell commands
      def extract_require_shell_commands(content)
        return [] unless content.start_with?('---')

        parts = content.split(/^---\s*$/, 3)
        return [] if parts.length < 3

        frontmatter = YAML.safe_load(parts[1])
        commands = frontmatter&.dig('require_shell_commands')
        return [] unless commands

        # Handle both array and single string
        Array(commands)
      rescue StandardError
        []
      end
    end
  end
end
