# frozen_string_literal: true

require 'tiktoken_ruby'
require 'yaml'

module Ruly
  module Operations
    # Generate token statistics for rule files
    class Stats < Base
      attr_reader :sources, :output_file, :recipes_file, :rules_dir

      # @param sources [Array<Hash>] Array of source hashes with :path and :type keys
      # @param output_file [String] Path to output markdown file
      # @param recipes_file [String, nil] Path to recipes.yml file for orphan detection
      # @param rules_dir [String, nil] Path to rules directory for relative path resolution
      def initialize(sources:, output_file: 'stats.md', recipes_file: nil, rules_dir: nil)
        super()
        @sources = sources
        @output_file = output_file
        @recipes_file = recipes_file
        @rules_dir = rules_dir
      end

      def call
        file_stats = build_file_stats
        orphaned = find_orphaned_files
        write_markdown(file_stats, orphaned)

        build_result(
          success: true,
          data: {
            file_count: file_stats.size,
            files: file_stats,
            output_file:,
            total_tokens: file_stats.sum { |f| f[:tokens] },
            orphaned_files: orphaned,
            orphaned_count: orphaned.size
          }
        )
      rescue StandardError => e
        build_result(success: false, error: e.message)
      end

      # Build stats without writing to file (useful for testing)
      def build_file_stats
        file_stats = []

        sources.each do |source|
          next unless source[:type] == 'local'

          file_path = source[:path]
          next unless file_path && File.exist?(file_path)

          content = File.read(file_path, encoding: 'UTF-8')
          tokens = count_tokens(content)
          file_stats << {
            path: file_path,
            size: content.bytesize,
            tokens:
          }
        end

        # Sort by token count descending
        file_stats.sort_by { |f| -f[:tokens] }
      end

      # Find files not used by any recipe and not required by any other file
      # @return [Array<String>] List of orphaned file paths
      def find_orphaned_files
        all_files = sources.filter_map do |s|
          next unless s[:type] == 'local'

          path = s[:path]
          # Normalize to absolute path for comparison
          abs_path = File.expand_path(path, rules_dir&.sub(%r{/rules$}, ''))
          abs_path if File.exist?(abs_path)
        end
        return all_files if recipes_file.nil? || !File.exist?(recipes_file)

        used_files = collect_used_files.map { |f| File.expand_path(f) }
        all_files.reject { |f| used_files.include?(File.expand_path(f)) }
      end

      private

      # Collect all files used by recipes (directly or via directory inclusion)
      # and files required by other files (transitively)
      def collect_used_files
        used = Set.new

        # Get files directly referenced in recipes
        recipe_files = collect_recipe_files
        recipe_files.each { |f| used.add(f) }

        # Expand requirements transitively
        expand_requirements(used)

        used.to_a
      end

      # Parse recipes.yml and collect all referenced files
      def collect_recipe_files
        config = YAML.safe_load_file(recipes_file, aliases: true) || {}
        recipes = config['recipes'] || {}

        files = Set.new

        recipes.each_value do |recipe|
          next unless recipe.is_a?(Hash) && recipe['files']

          recipe['files'].each do |path|
            if File.directory?(path)
              # Directory reference - expand to all .md files
              Dir.glob(File.join(path, '**', '*.md')).each { |f| files.add(f) }
            elsif File.exist?(path)
              files.add(path)
            end
          end
        end

        files.to_a
      end

      # Expand file requirements transitively (files that @require other files)
      def expand_requirements(used_set)
        processed = Set.new
        to_process = used_set.to_a.dup

        while (file = to_process.shift)
          next if processed.include?(file)

          processed.add(file)
          next unless File.exist?(file)

          required_files = extract_requirements(file)
          required_files.each do |req_file|
            unless used_set.include?(req_file)
              used_set.add(req_file)
              to_process << req_file
            end
          end
        end
      end

      # Extract @./path requirements from a file
      def extract_requirements(file_path)
        content = File.read(file_path, encoding: 'UTF-8')
        base_dir = File.dirname(file_path)

        requirements = []
        content.scan(/^@(\.\.?\/[^\s]+)/).each do |match|
          relative_path = match[0]
          absolute_path = File.expand_path(relative_path, base_dir)
          requirements << absolute_path if File.exist?(absolute_path)
        end

        requirements
      end

      def write_markdown(file_stats, orphaned_files = [])
        total_tokens = file_stats.sum { |f| f[:tokens] }
        total_size = file_stats.sum { |f| f[:size] }

        File.open(output_file, 'w') do |f|
          write_header(f, file_stats.size, total_tokens, total_size)
          write_table(f, file_stats)
          write_orphaned_section(f, orphaned_files) if orphaned_files.any?
          write_footer(f)
        end
      end

      def write_header(file, file_count, total_tokens, total_size)
        file.puts '# Ruly Token Statistics'
        file.puts
        file.puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
        file.puts
        file.puts '## Summary'
        file.puts
        file.puts "- **Total Files**: #{file_count}"
        file.puts "- **Total Tokens**: #{format_number(total_tokens)}"
        file.puts "- **Total Size**: #{format_bytes(total_size)}"
        file.puts
      end

      def write_table(file, file_stats)
        file.puts '## Files by Token Count'
        file.puts
        file.puts '| # | Tokens | Size | File |'
        file.puts '|--:|-------:|-----:|:-----|'

        file_stats.each_with_index do |stat, idx|
          filename = File.basename(stat[:path])
          file.puts "| #{idx + 1} | #{format_number(stat[:tokens])} | #{format_bytes(stat[:size])} | [#{filename}](#{stat[:path]}) |"
        end

        file.puts
      end

      def write_orphaned_section(file, orphaned_files)
        file.puts '## Orphaned Files'
        file.puts
        file.puts "#{orphaned_files.size} files not used by any recipe or required by any file:"
        file.puts
        orphaned_files.sort.each do |path|
          filename = File.basename(path)
          relative_path = rules_dir ? path.sub("#{rules_dir}/", '') : path
          file.puts "- [#{filename}](#{relative_path})"
        end
        file.puts
      end

      def write_footer(file)
        file.puts '---'
        file.puts '*Generated by [ruly](https://github.com/patrickclery/ruly)*'
      end

      def count_tokens(text)
        encoder = Tiktoken.get_encoding('cl100k_base')
        utf8_text = text.encode('UTF-8', invalid: :replace, replace: '?', undef: :replace)
        encoder.encode(utf8_text).length
      end

      def format_number(num)
        num.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      def format_bytes(bytes)
        if bytes >= 1_048_576
          "#{(bytes / 1_048_576.0).round(1)} MB"
        elsif bytes >= 1024
          "#{(bytes / 1024.0).round(1)} KB"
        else
          "#{bytes} B"
        end
      end
    end
  end
end
