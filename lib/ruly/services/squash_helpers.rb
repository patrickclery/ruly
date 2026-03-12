# frozen_string_literal: true

require 'find'

module Ruly
  module Services
    # Helper methods for the squash pipeline that don't fit into other services.
    # Includes filtering, dispatch validation, recipe-tag scanning, output file
    # determination, and TaskMaster config copying.
    module SquashHelpers # rubocop:disable Metrics/ModuleLength
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

      # Copy TaskMaster config from user config to project.
      # @param dry_run [Boolean] if true, only print what would happen
      def copy_taskmaster_config(dry_run: false)
        source_config = File.expand_path('~/.config/ruly/taskmaster/config.json')
        target_dir = '.taskmaster'
        target_config = File.join(target_dir, 'config.json')

        unless File.exist?(source_config)
          puts "⚠️  Warning: #{source_config} not found"
          return
        end

        if dry_run
          puts "\nWould copy TaskMaster config:"
          puts "  → From: #{source_config}"
          puts "  → To: #{target_config}"
          return
        end

        FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)
        FileUtils.cp(source_config, target_config)
        puts "🎯 Copied TaskMaster config to #{target_config}"
      rescue StandardError => e
        puts "⚠️  Warning: Could not copy TaskMaster config: #{e.message}"
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

      # Write shell_gpt JSON output format.
      # @param output_file [String] output path
      # @param local_sources [Array<Hash>] processed sources with :content
      def write_shell_gpt_json(output_file, local_sources)
        require 'json'

        role_name = File.basename(output_file, '.json')
        description_parts = local_sources.map do |source|
          content = source[:content].dup.force_encoding('UTF-8')
          content.scrub('?')
        end

        role_json = {
          'description' => description_parts.join("\n\n"),
          'name' => role_name
        }

        File.write(output_file, JSON.pretty_generate(role_json))
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

      # Count sections in a cached output file.
      # @param output_file [String] path to the cached file
      # @return [Integer] number of sections
      def cached_file_count(output_file)
        return 0 unless File.exist?(output_file)

        content = File.read(output_file, encoding: 'UTF-8')
        content.scan(/^## /).size
      rescue StandardError
        0
      end
    end
  end
end
