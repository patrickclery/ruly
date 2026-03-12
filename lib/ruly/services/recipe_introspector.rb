# frozen_string_literal: true

require 'find'
require 'fileutils'
require 'yaml'

module Ruly
  module Services
    # Introspection methods for scanning directories and GitHub repos to discover
    # markdown files and create/update recipe definitions. Also provides tree
    # display helpers used by both introspect and list-recipes commands.
    module RecipeIntrospector # rubocop:disable Metrics/ModuleLength
      module_function

      # Scan a GitHub URL for markdown files and add them to the collection.
      # @param url [String] GitHub tree URL (e.g., https://github.com/owner/repo/tree/branch/path)
      # @param all_github_sources [Array<Hash>] Accumulator for discovered GitHub sources
      def introspect_github_source(url, all_github_sources)
        if url =~ %r{github\.com/([^/]+)/([^/]+)/tree/([^/]+)(?:/(.+))?}
          owner = Regexp.last_match(1)
          repo = Regexp.last_match(2)
          branch = Regexp.last_match(3)
          path = Regexp.last_match(4) || ''

          puts "  \u{1F310} github.com/#{owner}/#{repo}..."

          github_files = Services::GitHubClient.fetch_github_markdown_files(owner, repo, branch, path)

          if github_files.any?
            puts "     Found #{github_files.length} markdown files"

            existing_source = all_github_sources.find { |s| s[:github] == "#{owner}/#{repo}" && s[:branch] == branch }

            if existing_source
              existing_source[:rules].concat(github_files).uniq!.sort!
            else
              all_github_sources << {
                branch:,
                github: "#{owner}/#{repo}",
                rules: github_files.sort
              }
            end
          else
            puts "     \u26A0\uFE0F No markdown files found or failed to access"
          end
        else
          puts "  \u26A0\uFE0F  Invalid GitHub URL format: #{url}"
        end
      end

      # Scan a local directory for markdown files and add them to the collection.
      # @param path [String] Directory path to scan
      # @param all_files [Array<String>] Accumulator for discovered file paths
      # @param use_relative [Boolean] Whether to store relative paths instead of absolute
      def introspect_local_source(path, all_files, use_relative)
        expanded_path = File.expand_path(path)

        unless File.directory?(expanded_path)
          puts "  \u26A0\uFE0F  Skipping #{path} - not a directory"
          return
        end

        puts "  \u{1F4C1} #{path}..."
        found_count = 0

        Find.find(expanded_path) do |file_path|
          next unless file_path.end_with?('.md', '.mdc')

          stored_path = use_relative ? file_path.sub("#{Dir.pwd}/", '') : file_path
          all_files << stored_path
          found_count += 1
        end

        puts "     Found #{found_count} markdown files"
      end

      # Build a recipe data hash from introspected local and GitHub sources.
      # @param local_files [Array<String>] Discovered local file paths
      # @param github_sources [Array<Hash>] Discovered GitHub source entries
      # @param original_sources [Array<String>] Original source arguments from user
      # @param description [String, nil] User-provided description, or nil for auto-generated
      # @return [Hash] Recipe data suitable for YAML serialization
      def build_introspected_recipe(local_files, github_sources, original_sources, description)
        recipe = {}

        if description
          recipe['description'] = description
        else
          source_count = original_sources.length
          if source_count == 1
            recipe['description'] = "Auto-generated from #{original_sources.first}"
          else
            local_count = original_sources.count { |s| !s.start_with?('http') }
            github_count = source_count - local_count

            parts = []
            parts << "#{local_count} local" if local_count > 0
            parts << "#{github_count} GitHub" if github_count > 0
            recipe['description'] = "Auto-generated from #{parts.join(' and ')} source#{'s' if source_count > 1}"
          end
        end

        recipe['files'] = local_files.sort if local_files.any?

        if github_sources.any?
          recipe['sources'] = github_sources.map do |source|
            {
              'branch' => source[:branch],
              'github' => source[:github],
              'rules' => source[:rules]
            }
          end
        end

        recipe
      end

      # Save an introspected recipe to a recipes YAML file.
      # @param recipe_name [String] Name of the recipe
      # @param recipe_data [Hash] Recipe data hash
      # @param output_file [String] Path to the recipes YAML file
      def save_introspected_recipe(recipe_name, recipe_data, output_file)
        existing_config = if File.exist?(output_file)
                            YAML.safe_load_file(output_file, aliases: true) || {}
                          else
                            {}
                          end

        existing_config['recipes'] ||= {}

        existing_config['recipes'][recipe_name] = recipe_data

        FileUtils.mkdir_p(File.dirname(output_file))

        yaml_content = format_yaml_without_quotes(existing_config)
        File.write(output_file, yaml_content)
      end

      # Format YAML output with unquoted file paths for readability.
      # @param data [Hash] Data to convert to YAML
      # @return [String] YAML string with unquoted file paths
      def format_yaml_without_quotes(data)
        yaml_str = data.to_yaml

        yaml_str.gsub(%r{(['"])(/[^'"]*|~[^'"]*|[^'"]*\.md[c]?)\1}) do |match|
          path = match[1..-2]
          if path.match?(%r{^[/~]}) || path.match?(/\.md[c]?$/)
            path
          else
            match
          end
        end
      end

      # Build a tree structure from a list of file paths for display.
      # Used by both introspect and list-recipes commands.
      # @param files [Array<String>] List of file paths (local or remote URLs)
      # @return [Hash] Nested hash representing the file tree
      def build_recipe_file_tree(files)
        tree = {}
        files.each do |file|
          if file.start_with?('http')
            tree['[remote]'] ||= {}
            if file =~ %r{https?://([^/]+)/(.+)}
              domain = Regexp.last_match(1)
              path = Regexp.last_match(2)
              tree['[remote]'][domain] ||= []
              tree['[remote]'][domain] << path.split('/').last
            else
              tree['[remote]']['urls'] ||= []
              tree['[remote]']['urls'] << file
            end
          else
            parts = file.split('/')
            current = tree
            parts.each_with_index do |part, index|
              if index == parts.length - 1
                current[part] = nil
              else
                current[part] ||= {}
                current = current[part]
              end
            end
          end
        end
        tree
      end

      # Render a file tree with box-drawing characters for display.
      # Used by both introspect and list-recipes commands.
      # @param tree [Hash] Nested hash from build_recipe_file_tree
      # @param prefix [String] Indentation prefix for the current level
      def display_recipe_tree(tree, prefix = '')
        items = tree.to_a
        items.each_with_index do |(key, value), index|
          is_last = index == items.length - 1
          connector = is_last ? "\u2514\u2500\u2500 " : "\u251C\u2500\u2500 "
          extension = is_last ? '    ' : "\u2502   "

          if key == '[remote]'
            puts "#{prefix}#{connector}\u{1F310} Remote Sources"
            if value.is_a?(Hash)
              value.each_with_index do |(domain, files), domain_index|
                domain_last = domain_index == value.length - 1
                domain_connector = domain_last ? "\u2514\u2500\u2500 " : "\u251C\u2500\u2500 "
                puts "#{prefix}#{extension}#{domain_connector}#{domain}"
                domain_extension = domain_last ? '    ' : "\u2502   "
                files.each_with_index do |file, file_index|
                  file_last = file_index == files.length - 1
                  file_connector = file_last ? "\u2514\u2500\u2500 " : "\u251C\u2500\u2500 "
                  puts "#{prefix}#{extension}#{domain_extension}#{file_connector}#{file}"
                end
              end
            end
          elsif value.nil?
            icon = key.end_with?('.md') ? "\u{1F4C4}" : "\u{1F4C3}"
            puts "#{prefix}#{connector}#{icon} #{key}"
          elsif value.is_a?(Hash)
            puts "#{prefix}#{connector}\u{1F4C1} #{key}/"
            display_recipe_tree(value, "#{prefix}#{extension}")
          end
        end
      end
    end
  end
end
