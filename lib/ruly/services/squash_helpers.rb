# frozen_string_literal: true

require 'find'

module Ruly
  module Services
    # Helper methods for the squash pipeline that don't fit into other services.
    # Includes filtering, dispatch validation, recipe-tag scanning and output file
    # determination.
    module SquashHelpers
      module_function

      # Filter sources to only those marked as essential: true in frontmatter.
      # @param sources [Array<Hash>] source entries
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @return [Array<Hash>] filtered essential sources
      def filter_essential_sources(sources, find_rule_file:)
        sources.select do |source|
          next false unless source[:type] == 'local'

          file_path = find_rule_file.call(source[:path])
          next false unless file_path

          content = File.read(file_path, encoding: 'UTF-8')
          frontmatter, = Services::FrontmatterParser.parse(content)
          frontmatter['essential'] == true
        rescue StandardError
          false
        end
      end

      # Collect dispatches: frontmatter from processed sources.
      # @param local_sources [Array<Hash>] processed source hashes with :content/:original_content
      # @return [Hash] filename => array of dispatch target names
      def collect_dispatches_from_sources(local_sources)
        dispatches = {}

        local_sources.each do |source|
          content = source[:original_content] || source[:content]
          next unless content

          frontmatter, = Services::FrontmatterParser.parse(content)
          next unless frontmatter.is_a?(Hash) && frontmatter['dispatches'].is_a?(Array)

          filename = File.basename(source[:path])
          dispatches[filename] = frontmatter['dispatches']
        end

        dispatches
      end

      # Validate that all dispatches in source files match registered subagents.
      # @param collected_dispatches [Hash] filename => dispatch names
      # @param recipe_config [Hash] recipe configuration with 'subagents' key
      # @param recipe_name [String] recipe name (for error messages)
      # @raise [Ruly::Error] if unregistered dispatches found
      def validate_dispatches_registered!(collected_dispatches, recipe_config, recipe_name)
        return if collected_dispatches.empty?

        registered_subagents = if recipe_config['subagents'].is_a?(Array)
                                 recipe_config['subagents'].filter_map { |s| s['name'] }
                               else
                                 []
                               end

        collected_dispatches.each_value do |dispatch_names|
          dispatch_names.each do |dispatch_name|
            next if registered_subagents.include?(dispatch_name)

            raise Ruly::Error,
                  "Recipe '#{recipe_name}' dispatches: #{dispatch_name}\n       " \
                  "but does not register it as a subagent.\n       " \
                  "Add to recipe:\n         " \
                  "subagents:\n           " \
                  "- name: #{dispatch_name}\n             " \
                  "recipe: #{dispatch_name.tr('_', '-')}"
          end
        end
      end

      # Scan the rules directory for files with matching recipe tags in frontmatter.
      # @param recipe_name [String] recipe name to match
      # @param rules_dir [String] path to the rules directory
      # @return [Array<Hash>] source entries for tagged files
      def scan_files_for_recipe_tags(recipe_name, rules_dir:)
        sources = []
        return sources unless File.directory?(rules_dir)

        Find.find(rules_dir) do |path|
          next unless path.end_with?('.md', '.mdc')

          begin
            content = File.read(path, encoding: 'UTF-8')
            frontmatter, = Services::FrontmatterParser.parse(content)

            if frontmatter['recipes']&.include?(recipe_name)
              relative_path = path.sub("#{rules_dir}/", 'rules/')
              sources << {path: relative_path, type: 'local'}
            end
          rescue StandardError => e
            warn "Warning: Could not parse #{path}: #{e.message}" if ENV['DEBUG']
          end
        end

        sources.sort_by { |s| s[:path] }
      end

      # Determine output file path based on recipe type and options.
      # @param recipe_name [String] name of the recipe
      # @param recipe_value [Hash, Array] the recipe configuration
      # @param options [Hash] CLI options including :output_file
      # @return [String] path to output file
      def determine_output_file(recipe_name, recipe_value, options)
        default_output = 'CLAUDE.local.md'

        # User explicitly specified output file - use it (takes precedence)
        return options[:output_file] if options[:output_file] && options[:output_file] != default_output

        if recipe_value.is_a?(Array)
          # Array recipe = agent file goes to .claude/agents/
          ".claude/agents/#{recipe_name}.md"
        else
          default_output
        end
      end

      # Collect all local sources from the rules directory (non-recipe mode).
      # @param rules_dir [String] path to the rules directory
      # @return [Array<Hash>] source entries
      def collect_local_sources(rules_dir)
        sources = []
        Find.find(rules_dir) do |path|
          if path.end_with?('.md', '.mdc')
            relative_path = path.sub("#{rules_dir}/", 'rules/')
            sources << {path: relative_path, type: 'local'}
          end
        end
        sources.sort_by { |s| s[:path] }
      end

      # Calculate bin file target path from relative path.
      # @param relative_path [String] source relative path
      # @return [String] target filename
      def calculate_bin_target(relative_path)
        if (match = relative_path.match(%r{bin/(.+\.sh)$}))
          match[1]
        else
          File.basename(relative_path)
        end
      end
    end
  end
end
