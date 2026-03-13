# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative 'repo_config_reader'

module Ruly
  module Services
    # Handles subagent processing: generating agent files, validating
    # subagent configurations, and writing subagent output.
    # All methods are stateless module functions; external dependencies
    # (load_all_recipes, load_recipe_sources, etc.) are injected via keyword arguments.
    module SubagentProcessor # rubocop:disable Metrics/ModuleLength
      module_function

      # Process all subagents defined in a recipe configuration.
      # @param recipe_config [Hash] recipe configuration with optional 'subagents' key
      # @param parent_recipe_name [String] name of the parent recipe
      # @param top_level [Boolean] whether this is the top-level call (controls output)
      # @param visited [Set] already-visited recipe names (prevents duplicates)
      # @param load_all_recipes [Proc] callable returning all recipes hash
      # @param load_recipe_sources [Proc] callable(recipe_name) returning [sources, ...]
      # @param process_sources_for_squash [Proc] callable(sources, agent, config, opts)
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param parse_frontmatter [Proc] callable(content) returning [frontmatter, body]
      # @param save_skill_files [Proc] callable(skill_files)
      # @param verbose [Boolean] whether to output verbose messages
      def process_subagents(
        recipe_config, parent_recipe_name,
        find_rule_file:, load_all_recipes:, load_recipe_sources:,
        parse_frontmatter:, process_sources_for_squash:, save_skill_files:,
        top_level: true, verbose: false, visited: Set.new, recipe_paths: Set.new
      )
        return [] unless recipe_config['subagents'].is_a?(Array)

        puts "\n\u{1F916} Processing subagents..." if top_level

        FileUtils.mkdir_p('.claude/agents')

        deps = {
          all_skill_files: [],
          find_rule_file:,
          load_all_recipes:,
          load_recipe_sources:,
          parse_frontmatter:,
          process_sources_for_squash:,
          recipe_paths:,
          save_skill_files:,
          verbose:
        }

        recipe_config['subagents'].each do |subagent|
          process_single_subagent(subagent, parent_recipe_name, recipe_config, visited, **deps)
        end

        puts "\u{2705} Generated #{visited.size} subagent(s)" if top_level
        deps[:all_skill_files]
      rescue Ruly::Error
        raise
      rescue StandardError => e
        puts "\u{26A0}\u{FE0F}  Warning: Could not process subagents: #{e.message}"
        []
      end

      # Process a single subagent: load, validate, and generate its agent file.
      # @param subagent [Hash] subagent config with 'name' and 'recipe' keys
      # @param parent_recipe_name [String] parent recipe name
      # @param recipe_config [Hash] parent recipe configuration
      # @param visited [Set] already-visited recipe names
      def process_single_subagent(subagent, parent_recipe_name, recipe_config, visited, **deps)
        agent_name = subagent['name']
        recipe_name = subagent['recipe']

        return unless agent_name && recipe_name
        return if visited.include?(recipe_name)

        visited.add(recipe_name)

        if deps[:verbose]
          puts "  \u{2192} Generating #{agent_name}.md from '#{recipe_name}' recipe"
        else
          puts "  \u{2192} #{agent_name}"
        end

        subagent_recipe = deps[:load_all_recipes].call[recipe_name]

        unless subagent_recipe
          puts "    \u{26A0}\u{FE0F}  Warning: Recipe '#{recipe_name}' not found, skipping"
          return
        end

        validate_no_nested_subagents!(subagent_recipe, agent_name, recipe_name)
        validate_no_subagent_dispatches!(
          subagent_recipe, agent_name, recipe_name,
          find_rule_file: deps[:find_rule_file],
          load_recipe_sources: deps[:load_recipe_sources],
          parse_frontmatter: deps[:parse_frontmatter]
        )

        generate_agent_file(
          agent_name, recipe_name, subagent_recipe, parent_recipe_name,
          parent_recipe_config: recipe_config, subagent_config: subagent, **deps
        )
      end

      # Validate that a subagent recipe does not define its own subagents.
      # @param subagent_recipe [Hash] the subagent's recipe configuration
      # @param agent_name [String] the subagent name
      # @param recipe_name [String] the subagent's recipe name
      # @raise [Ruly::Error] if nested subagents are found
      def validate_no_nested_subagents!(subagent_recipe, agent_name, recipe_name)
        return unless subagent_recipe.is_a?(Hash) &&
                      subagent_recipe['subagents'].is_a?(Array) &&
                      subagent_recipe['subagents'].any?

        nested_names = subagent_recipe['subagents'].filter_map { |s| s['name'] }.join(', ')
        raise Ruly::Error,
              "Recipe '#{recipe_name}' (subagent '#{agent_name}') has its own subagents (#{nested_names}). " \
              'Claude Code subagents cannot spawn other subagents. ' \
              "Convert them to skills and reference via 'skills:' in the rule frontmatter instead."
      end

      # Validate that a subagent recipe's files do not contain dispatch frontmatter.
      # @param subagent_recipe [Hash] the subagent's recipe configuration
      # @param agent_name [String] the subagent name
      # @param recipe_name [String] the subagent's recipe name
      # @param load_recipe_sources [Proc] callable(recipe_name) returning [sources, ...]
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param parse_frontmatter [Proc] callable(content) returning [frontmatter, body]
      # @raise [Ruly::Error] if dispatching files are found
      def validate_no_subagent_dispatches!(
        subagent_recipe, agent_name, recipe_name,
        find_rule_file:, load_recipe_sources:, parse_frontmatter:
      )
        return unless subagent_recipe.is_a?(Hash)

        sources, = load_recipe_sources.call(recipe_name)
        dispatching_files = []

        sources.each do |source|
          next unless source[:type] == 'local'

          file_path = find_rule_file.call(source[:path])
          next unless file_path

          content = File.read(file_path, encoding: 'UTF-8')
          frontmatter, = parse_frontmatter.call(content)
          unless frontmatter.is_a?(Hash) && frontmatter['dispatches'].is_a?(Array) && frontmatter['dispatches'].any?
            next
          end

          filename = File.basename(source[:path])
          frontmatter['dispatches'].each do |dispatch_name|
            dispatching_files << {dispatch: dispatch_name, file: filename}
          end
        end

        return if dispatching_files.empty?

        file_list = dispatching_files.map { |f| "  - #{f[:file]} dispatches: #{f[:dispatch]}" }.join("\n")
        raise Ruly::Error,
              "Subagent '#{agent_name}' (recipe: #{recipe_name})\n" \
              "contains files that dispatch other subagents:\n\n" \
              "#{file_list}\n\n" \
              "Subagents cannot dispatch other subagents.\n" \
              "Remove these files from the recipe, or inline\n" \
              'the functionality without subagent dispatch.'
      end

      # Generate the agent .md file for a subagent.
      # @param agent_name [String] the agent name
      # @param recipe_name [String] the recipe name
      # @param recipe_config [Hash] the recipe configuration
      # @param parent_recipe_name [String] the parent recipe name
      # @param parent_recipe_config [Hash] the parent recipe configuration
      # @param subagent_config [Hash] the subagent configuration
      def generate_agent_file(
        agent_name, recipe_name, recipe_config, parent_recipe_name,
        parent_recipe_config: {}, subagent_config: {}, **deps
      )
        agent_file = ".claude/agents/#{agent_name}.md"
        local_sources, command_files, skill_files = load_agent_sources(
          recipe_name, recipe_config,
          load_recipe_sources: deps[:load_recipe_sources],
          process_sources_for_squash: deps[:process_sources_for_squash]
        )

        mcp_servers = Services::MCPManager.collect_agent_mcp_servers(recipe_config, local_sources)

        skill_names = extract_skill_names(skill_files)
        unless skill_files.empty?
          deps[:save_skill_files].call(skill_files, recipe_paths: deps[:recipe_paths])
          deps[:all_skill_files].concat(skill_files)
        end

        repo_content = ''
        hooks = collect_hooks(parent_recipe_config)

        if subagent_config['append'] && subagent_config['cwd']
          cwd_path = File.join(Dir.pwd, subagent_config['cwd'])
          if Dir.exist?(cwd_path)
            repo = Services::RepoConfigReader.read_repo_content(cwd_path)
            repo_content = Services::RepoConfigReader.format_repo_content(repo)
            hooks = hooks.merge(repo[:hooks]) if repo[:hooks].any?
          end
        end

        context = build_agent_context(
          agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
          mcp_servers:, parent_recipe_config:, skill_names:, subagent_config:,
          hooks:, repo_content:
        )
        write_agent_file(agent_file, context)
      rescue StandardError => e
        puts "    \u{26A0}\u{FE0F}  Warning: Could not generate agent file '#{agent_name}': #{e.message}"
      end

      # Load sources for an agent recipe.
      # @param recipe_name [String] recipe name
      # @param recipe_config [Hash] recipe configuration
      # @param load_recipe_sources [Proc] callable(recipe_name) returning [sources, ...]
      # @param process_sources_for_squash [Proc] callable(sources, agent, config, opts)
      # @return [Array] [local_sources, command_files, skill_files]
      def load_agent_sources(recipe_name, recipe_config, load_recipe_sources:, process_sources_for_squash:)
        sources, = load_recipe_sources.call(recipe_name)
        local_sources, command_files, _bin_files, skill_files = process_sources_for_squash.call(
          sources, 'claude', recipe_config, {}
        )
        [local_sources, command_files, skill_files]
      end

      # Extract skill names from skill file paths.
      # @param skill_files [Array<Hash>] array of skill file hashes with :path
      # @return [Array<String>] skill names
      def extract_skill_names(skill_files)
        skill_files.map { |file| Services::ScriptManager.derive_skill_name(file[:path]) }
      end

      # Build the context hash used for writing an agent file.
      # @return [Hash] context with all necessary data for the agent file
      def build_agent_context(
        agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
        hooks: {}, mcp_servers: [], parent_recipe_config: {}, repo_content: '',
        skill_names: [], subagent_config: {}
      )
        {
          agent_name:,
          description: recipe_config['description'] || "Subagent for #{recipe_name}",
          hooks:,
          local_sources:,
          mcp_servers:,
          model: resolve_agent_model(subagent_config, parent_recipe_config),
          parent_recipe_name:,
          recipe_config:,
          recipe_name:,
          repo_content:,
          skill_names:,
          timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
        }
      end

      # Determine the model to use for an agent.
      # Priority: subagent model > parent recipe model > 'inherit'
      # @param subagent_config [Hash] subagent configuration
      # @param parent_recipe_config [Hash] parent recipe configuration
      # @return [String] model name
      def resolve_agent_model(subagent_config, parent_recipe_config)
        return subagent_config['model'] if subagent_config['model']
        return parent_recipe_config['model'] if parent_recipe_config.is_a?(Hash) && parent_recipe_config['model']

        'inherit'
      end

      # Collect hooks from parent recipe config.
      # @param parent_recipe_config [Hash] parent recipe configuration
      # @return [Hash] hooks hash
      def collect_hooks(parent_recipe_config)
        return {} unless parent_recipe_config.is_a?(Hash)

        parent_recipe_config['hooks'] || {}
      end

      # Write the complete agent file.
      # @param agent_file [String] output file path
      # @param context [Hash] agent context data
      def write_agent_file(agent_file, context)
        File.open(agent_file, 'w') do |output|
          write_agent_frontmatter(output, context)
          write_agent_content(output, context)
          write_agent_footer(output, context[:timestamp], context[:recipe_name])
        end
      end

      # Write YAML frontmatter to agent file.
      # @param output [IO] output stream
      # @param context [Hash] agent context data
      def write_agent_frontmatter(output, context)
        frontmatter = {
          'name' => context[:agent_name],
          'description' => context[:description],
          'tools' => 'Bash, Read, Write, Edit, Glob, Grep',
          'model' => context[:model]
        }

        if context[:skill_names]&.any?
          frontmatter['skills'] = "[#{context[:skill_names].join(', ')}]"
        end
        if context[:mcp_servers]&.any?
          frontmatter['mcpServers'] = "[#{context[:mcp_servers].join(', ')}]"
        end
        frontmatter['permissionMode'] = 'bypassPermissions'

        if context[:hooks].is_a?(Hash) && context[:hooks].any?
          frontmatter['hooks'] = context[:hooks]
        end

        output.puts '---'
        output.puts YAML.dump(frontmatter).sub(/\A---\n/, '').chomp
        output.puts "# Auto-generated from recipe: #{context[:recipe_name]}"
        output.puts "# Do not edit manually - regenerate using 'ruly squash #{context[:parent_recipe_name]}'"
        output.puts '---'
        output.puts
      end

      # Write the main content section of the agent file.
      # @param output [IO] output stream
      # @param context [Hash] agent context data
      def write_agent_content(output, context)
        output.puts "# #{context[:agent_name].split('_').map(&:capitalize).join(' ')}"
        output.puts
        output.puts context[:description]
        output.puts
        output.puts '## Recipe Content'
        output.puts

        context[:local_sources].each do |source|
          next if source[:content].nil? || source[:content].strip.empty?

          output.puts source[:content]
          output.puts
          output.puts '---'
          output.puts
        end

        return unless context[:repo_content].is_a?(String) && !context[:repo_content].strip.empty?

        output.puts context[:repo_content]
        output.puts
      end

      # Write the footer section of the agent file.
      # @param output [IO] output stream
      # @param timestamp [String] generation timestamp
      # @param recipe_name [String] source recipe name
      def write_agent_footer(output, timestamp, recipe_name)
        output.puts '---'
        output.puts "*Last generated: #{timestamp}*"
        output.puts "*Source recipe: #{recipe_name}*"
      end

      # Save command files for a subagent to .claude/commands/{agent_name}/.
      # @param command_files [Array<Hash>] command file hashes with :path and :content
      # @param agent_name [String] agent name
      # @param recipe_config [Hash, nil] recipe configuration
      # @param verbose [Boolean] whether to output verbose messages
      def save_subagent_commands(command_files, agent_name, recipe_config = nil, verbose: false)
        return if command_files.empty?

        commands_dir = ".claude/commands/#{agent_name}"
        FileUtils.mkdir_p(commands_dir)

        omit_prefix = recipe_config && recipe_config['omit_command_prefix'] ? recipe_config['omit_command_prefix'] : nil

        command_files.each do |file|
          next unless file.is_a?(Hash)

          relative_path = Services::ScriptManager.get_command_relative_path(file[:path], omit_prefix)

          target_file = File.join(commands_dir, relative_path)
          target_dir = File.dirname(target_file)
          FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

          File.write(target_file, file[:content])
        end

        puts "    \u{1F4C1} Saved #{command_files.size} command file(s) to .claude/commands/#{agent_name}/" if verbose
      rescue StandardError => e
        puts "    \u{26A0}\u{FE0F}  Warning: Could not save commands for '#{agent_name}': #{e.message}"
      end
    end
  end
end
