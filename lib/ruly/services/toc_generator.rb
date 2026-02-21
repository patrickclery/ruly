# frozen_string_literal: true

module Ruly
  module Services
    # Generates table-of-contents markup and display/output utilities
    # for the squash pipeline.
    module TOCGenerator # rubocop:disable Metrics/ModuleLength
      # Context-window limits per agent (tokens)
      AGENT_CONTEXT_LIMITS = {
        'aider' => 128_000,       # Aider (uses GPT-4)
        'claude' => 200_000,      # Claude 3 Opus/Sonnet/Haiku
        'codeium' => 32_000,      # Codeium
        'continue' => 32_000,     # Continue.dev
        'copilot' => 32_000,      # GitHub Copilot
        'cursor' => 32_000,       # Cursor IDE (based on GPT-4)
        'gpt3' => 16_000,         # GPT-3.5 Turbo
        'gpt4' => 128_000,        # GPT-4 Turbo
        'windsurf' => 32_000      # Windsurf
      }.freeze

      module_function

      # Build the full table-of-contents string for the squashed output.
      # @param local_sources [Array<Hash>] processed source entries
      # @param command_files [Array<Hash>] command file entries
      # @param agent [String] target agent name
      # @return [String] rendered TOC markdown
      def generate_toc_content(local_sources, command_files, agent)
        toc_lines = ['## Table of Contents', '']

        local_sources.each do |source|
          toc_lines << generate_toc_for_source(source)
        end

        toc_lines.concat(generate_toc_slash_commands(command_files)) if agent == 'claude' && !command_files.empty?

        toc_lines.join("\n")
      end

      # Generate TOC entries for a single source file.
      # @param source [Hash] a processed source with :content and :path
      # @return [String] TOC lines for that source
      def generate_toc_for_source(source)
        toc_section = []
        headers = extract_headers_from_content(source[:content], source[:path])

        if headers.any?
          headers.each do |header|
            indent = '  ' * (header[:level] - 1) if header[:level] > 1
            toc_section << "#{indent}- [#{header[:text]}](##{header[:anchor]})"
          end
        end

        toc_section.join("\n")
      end

      # Parse markdown headers from content.
      # @param content [String] markdown content
      # @param source_path [String, nil] file path used for anchor prefixes
      # @return [Array<Hash>] list of header hashes with :level, :text, :anchor, :line
      def extract_headers_from_content(content, source_path = nil)
        headers = []
        content = content.force_encoding('UTF-8')

        file_prefix = (generate_file_prefix(source_path) if source_path)

        content.each_line.with_index do |line, index|
          if line =~ /^(#+)\s+(.+)$/
            level = Regexp.last_match(1).length
            text = Regexp.last_match(2).strip
            anchor = generate_anchor(text, file_prefix)
            headers << {anchor:, level:, line: index + 1, text:}
          end
        end
        headers
      end

      # Create a URL-safe anchor from header text.
      # @param text [String] the header text
      # @param prefix [String, nil] optional prefix derived from file path
      # @return [String] anchor slug
      def generate_anchor(text, prefix = nil)
        anchor = text.downcase
                     .gsub(/[^\w\s-]/, '')
                     .gsub(/\s+/, '-').squeeze('-')
                     .gsub(/^-|-$/, '')

        prefix ? "#{prefix}-#{anchor}" : anchor
      end

      # Build TOC entries for slash commands.
      # @param command_files [Array<Hash>] command file entries with :path and :content
      # @return [Array<String>] lines to append to the TOC
      def generate_toc_slash_commands(command_files)
        ['### Available Slash Commands', ''] +
          command_files.map do |file|
            cmd_name = extract_command_name(file[:path])
            description = extract_command_description(file[:content])
            "- `/#{cmd_name}` - #{description}"
          end + ['']
      end

      # Derive the command name from a file path.
      # @param file_path [String] path to the command file
      # @return [String] command name with colons as separators
      def extract_command_name(file_path)
        File.basename(file_path, '.md').gsub(/[_-]/, ':')
      end

      # Extract a short description from a command file's content.
      # @param content [String] the command file content
      # @return [String] a description string
      def extract_command_description(content)
        content = content.force_encoding('UTF-8')

        if content.start_with?('---')
          yaml_match = content.match(/^---\n(.+?)\n---/m)
          if yaml_match
            begin
              yaml_data = YAML.safe_load(yaml_match[1])
              return yaml_data['description'] if yaml_data&.key?('description')
            rescue StandardError
              # Continue to fallback methods
            end
          end
        end

        lines = content.split("\n")
        lines.each do |line|
          next if line.strip.empty? || line.start_with?('#') || line.start_with?('---')

          if line.strip.length > 10
            return line.strip.gsub(/[*_`]/, '')[0..80] + (line.length > 80 ? '...' : '')
          end
        end

        'Command description not available'
      end

      # Add HTML anchor IDs before headers so TOC links resolve.
      # @param content [String] markdown content
      # @param source_path [String] the source file path
      # @return [String] content with anchor tags inserted
      def add_anchor_ids_to_content(content, source_path)
        file_prefix = generate_file_prefix(source_path)
        modified_content = []

        content.force_encoding('UTF-8').each_line do |line|
          if line =~ /^(#+)\s+(.+)$/
            level = Regexp.last_match(1)
            text = Regexp.last_match(2).strip
            anchor = generate_anchor(text, file_prefix)

            modified_content << "<a id=\"#{anchor}\"></a>"
            modified_content << ''
            modified_content << "#{level} #{text}"
          else
            modified_content << line.chomp
          end
        end

        modified_content.join("\n")
      end

      # Convert a source path into a URL-safe prefix for anchors.
      # @param source_path [String] absolute or relative file path (or URL)
      # @return [String] sanitised prefix string
      def generate_file_prefix(source_path)
        path = if source_path.start_with?('http')
                 if source_path =~ %r{/(?:blob|tree)/[^/]+/(.+)$}
                   Regexp.last_match(1)
                 else
                   source_path.split('/').last
                 end
               else
                 source_path
               end

        path.downcase
            .gsub(/\.md$/, '')
            .gsub(%r{[^\w/-]}, '')
            .gsub(%r{/+}, '-')
            .gsub(/^-|-$/, '')
      end

      # Rewrite absolute script paths to relative .claude/scripts/ paths.
      # @param content [String] the content to rewrite
      # @param script_mappings [Hash] map of absolute path => relative filename
      # @return [String] content with rewritten paths
      def rewrite_script_references(content, script_mappings)
        result = content.dup

        script_mappings.each do |abs_path, relative_path|
          result.gsub!(abs_path, ".claude/scripts/#{relative_path}")
        end

        result
      end

      # Print a summary after squash completes.
      # @param mode [String] description of the mode used
      # @param output_file [String] path to the generated file
      # @param file_count [Integer] total number of files combined
      # @param agent [String] target agent name (for token display)
      def print_summary(mode, output_file, file_count, agent: 'claude')
        puts "\n✅ Successfully generated #{output_file} using #{mode}"
        puts "📊 Combined #{file_count} files"
        puts "📏 Output size: #{File.size(output_file)} bytes"

        display_token_info(output_file, agent)
      end

      # Display token count with colour-coded status.
      # @param output_file [String] path to the generated file
      # @param agent [String] target agent name
      def display_token_info(output_file, agent)
        content = File.read(output_file, encoding: 'UTF-8')
        token_count = Services::SourceProcessor.count_tokens(content)

        limit = AGENT_CONTEXT_LIMITS[agent.downcase] || 100_000
        percentage = ((token_count.to_f / limit) * 100).round(1)

        formatted_tokens = token_count.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        formatted_limit = limit.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

        status = if percentage < 50
                   '🟢'
                 elsif percentage < 80
                   '🟡'
                 elsif percentage < 95
                   '🟠'
                 else
                   '🔴'
                 end

        puts "🧮 Token count: #{formatted_tokens} / #{formatted_limit} (#{percentage}%) #{status}"

        if percentage > 80
          puts "⚠️  Warning: Approaching context limit for #{agent}!" if percentage < 95
          puts "❌ Error: Exceeds context limit for #{agent}!" if percentage >= 100
        end
      rescue StandardError => e
        puts "⚠️  Could not count tokens: #{e.message}"
      end
    end
  end
end
