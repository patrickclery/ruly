# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Ruly
  module Services
    # Handles subagent processing: generating agent files, validating
    # subagent configurations, and writing subagent output.
    # All methods are stateless module functions; external dependencies
    # (load_all_profiles, load_profile_sources, etc.) are injected via keyword arguments.
    module SubagentProcessor # rubocop:disable Metrics/ModuleLength
      module_function

      # Process all subagents defined in a profile configuration.
      # @param profile_config [Hash] profile configuration with optional 'subagents' key
      # @param parent_profile_name [String] name of the parent profile
      # @param top_level [Boolean] whether this is the top-level call (controls output)
      # @param visited [Set] already-visited profile names (prevents duplicates)
      # @param load_all_profiles [Proc] callable returning all profiles hash
      # @param load_profile_sources [Proc] callable(profile_name) returning [sources, ...]
      # @param process_sources_for_squash [Proc] callable(sources, agent, config, opts)
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param parse_frontmatter [Proc] callable(content) returning [frontmatter, body]
      # @param save_skill_files [Proc] callable(skill_files)
      # @param verbose [Boolean] whether to output verbose messages
      def process_subagents(
        profile_config, parent_profile_name,
        find_rule_file:, load_all_profiles:, load_profile_sources:,
        parse_frontmatter:, process_sources_for_squash:, save_skill_files:,
        top_level: true, verbose: false, visited: Set.new, profile_paths: Set.new
      )
        return [] unless profile_config['subagents'].is_a?(Array)

        puts "\n\u{1F916} Processing subagents..." if top_level

        FileUtils.mkdir_p('.claude/agents')

        deps = {
          all_skill_files: [],
          find_rule_file:,
          load_all_profiles:,
          load_profile_sources:,
          parse_frontmatter:,
          process_sources_for_squash:,
          profile_paths:,
          save_skill_files:,
          verbose:
        }

        profile_config['subagents'].each do |subagent|
          process_single_subagent(subagent, parent_profile_name, profile_config, visited, **deps)
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
      # @param subagent [Hash] subagent config with 'name' and 'profile' keys
      # @param parent_profile_name [String] parent profile name
      # @param profile_config [Hash] parent profile configuration
      # @param visited [Set] already-visited profile names
      def process_single_subagent(subagent, parent_profile_name, profile_config, visited, **deps)
        agent_name = subagent['name']
        profile_name = subagent['profile']

        return unless agent_name && profile_name
        return if visited.include?(profile_name)

        visited.add(profile_name)

        if deps[:verbose]
          puts "  \u{2192} Generating #{agent_name}.md from '#{profile_name}' profile"
        else
          puts "  \u{2192} #{agent_name}"
        end

        subagent_profile = deps[:load_all_profiles].call[profile_name]

        unless subagent_profile
          puts "    \u{26A0}\u{FE0F}  Warning: Profile '#{profile_name}' not found, skipping"
          return
        end

        validate_no_nested_subagents!(subagent_profile, agent_name, profile_name)
        validate_no_subagent_dispatches!(
          subagent_profile, agent_name, profile_name,
          find_rule_file: deps[:find_rule_file],
          load_profile_sources: deps[:load_profile_sources],
          parse_frontmatter: deps[:parse_frontmatter]
        )

        generate_agent_file(
          agent_name, profile_name, subagent_profile, parent_profile_name,
          parent_profile_config: profile_config, subagent_config: subagent, **deps
        )
      end

      # Validate that a subagent profile does not define its own subagents.
      # @param subagent_profile [Hash] the subagent's profile configuration
      # @param agent_name [String] the subagent name
      # @param profile_name [String] the subagent's profile name
      # @raise [Ruly::Error] if nested subagents are found
      def validate_no_nested_subagents!(subagent_profile, agent_name, profile_name)
        return unless subagent_profile.is_a?(Hash) &&
                      subagent_profile['subagents'].is_a?(Array) &&
                      subagent_profile['subagents'].any?

        nested_names = subagent_profile['subagents'].filter_map { |s| s['name'] }.join(', ')
        raise Ruly::Error,
              "Profile '#{profile_name}' (subagent '#{agent_name}') has its own subagents (#{nested_names}). " \
              'Claude Code subagents cannot spawn other subagents. ' \
              "Convert them to skills and reference via 'skills:' in the rule frontmatter instead."
      end

      # Validate that a subagent profile's files do not contain dispatch frontmatter.
      # @param subagent_profile [Hash] the subagent's profile configuration
      # @param agent_name [String] the subagent name
      # @param profile_name [String] the subagent's profile name
      # @param load_profile_sources [Proc] callable(profile_name) returning [sources, ...]
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param parse_frontmatter [Proc] callable(content) returning [frontmatter, body]
      # @raise [Ruly::Error] if dispatching files are found
      def validate_no_subagent_dispatches!(
        subagent_profile, agent_name, profile_name,
        find_rule_file:, load_profile_sources:, parse_frontmatter:
      )
        return unless subagent_profile.is_a?(Hash)

        sources, = load_profile_sources.call(profile_name)
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
              "Subagent '#{agent_name}' (profile: #{profile_name})\n" \
              "contains files that dispatch other subagents:\n\n" \
              "#{file_list}\n\n" \
              "Subagents cannot dispatch other subagents.\n" \
              "Remove these files from the profile, or inline\n" \
              'the functionality without subagent dispatch.'
      end

      # Generate the agent .md file for a subagent.
      # @param agent_name [String] the agent name
      # @param profile_name [String] the profile name
      # @param profile_config [Hash] the profile configuration
      # @param parent_profile_name [String] the parent profile name
      # @param parent_profile_config [Hash] the parent profile configuration
      # @param subagent_config [Hash] the subagent configuration
      def generate_agent_file(
        agent_name, profile_name, profile_config, parent_profile_name,
        parent_profile_config: {}, subagent_config: {}, **deps
      )
        agent_file = ".claude/agents/#{agent_name}.md"
        local_sources, command_files, skill_files = load_agent_sources(
          profile_name, profile_config,
          load_profile_sources: deps[:load_profile_sources],
          process_sources_for_squash: deps[:process_sources_for_squash]
        )

        mcp_servers = Services::MCPManager.collect_agent_mcp_servers(profile_config, local_sources)

        skill_names = extract_skill_names(skill_files)
        unless skill_files.empty?
          deps[:save_skill_files].call(skill_files, profile_paths: deps[:profile_paths])
          deps[:all_skill_files].concat(skill_files)
        end

        context = build_agent_context(
          agent_name, profile_name, profile_config, parent_profile_name, local_sources,
          mcp_servers:, parent_profile_config:, skill_names:, subagent_config:
        )
        write_agent_file(agent_file, context)
        unless command_files.empty?
          save_subagent_commands(command_files, agent_name, profile_config,
                                 verbose: deps[:verbose])
        end
      rescue StandardError => e
        puts "    \u{26A0}\u{FE0F}  Warning: Could not generate agent file '#{agent_name}': #{e.message}"
      end

      # Load sources for an agent profile.
      # @param profile_name [String] profile name
      # @param profile_config [Hash] profile configuration
      # @param load_profile_sources [Proc] callable(profile_name) returning [sources, ...]
      # @param process_sources_for_squash [Proc] callable(sources, agent, config, opts)
      # @return [Array] [local_sources, command_files, skill_files]
      def load_agent_sources(profile_name, profile_config, load_profile_sources:, process_sources_for_squash:)
        sources, = load_profile_sources.call(profile_name)
        local_sources, command_files, _bin_files, skill_files = process_sources_for_squash.call(
          sources, 'claude', profile_config, {}
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
        agent_name, profile_name, profile_config, parent_profile_name, local_sources,
        hooks: {}, mcp_servers: [], parent_profile_config: {}, skill_names: [], subagent_config: {}
      )
        {
          agent_name:,
          description: profile_config['description'] || "Subagent for #{profile_name}",
          hooks:,
          local_sources:,
          mcp_servers:,
          model: resolve_agent_model(subagent_config, parent_profile_config),
          parent_profile_name:,
          profile_config:,
          profile_name:,
          skill_names:,
          timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
        }
      end

      # Determine the model to use for an agent.
      # Priority: subagent model > parent profile model > 'inherit'
      # @param subagent_config [Hash] subagent configuration
      # @param parent_profile_config [Hash] parent profile configuration
      # @return [String] model name
      def resolve_agent_model(subagent_config, parent_profile_config)
        return subagent_config['model'] if subagent_config['model']
        return parent_profile_config['model'] if parent_profile_config.is_a?(Hash) && parent_profile_config['model']

        'inherit'
      end

      # Write the complete agent file.
      # @param agent_file [String] output file path
      # @param context [Hash] agent context data
      def write_agent_file(agent_file, context)
        File.open(agent_file, 'w') do |output|
          write_agent_frontmatter(output, context)
          write_agent_content(output, context)
          write_agent_footer(output, context[:timestamp], context[:profile_name])
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
        output.puts "# Auto-generated from profile: #{context[:profile_name]}"
        output.puts "# Do not edit manually - regenerate using 'ruly squash #{context[:parent_profile_name]}'"
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
        output.puts '## Profile Content'
        output.puts

        context[:local_sources].each do |source|
          next if source[:content].nil? || source[:content].strip.empty?

          output.puts source[:content]
          output.puts
          output.puts '---'
          output.puts
        end
      end

      # Write the footer section of the agent file.
      # @param output [IO] output stream
      # @param timestamp [String] generation timestamp
      # @param profile_name [String] source profile name
      def write_agent_footer(output, timestamp, profile_name)
        output.puts '---'
        output.puts "*Last generated: #{timestamp}*"
        output.puts "*Source profile: #{profile_name}*"
      end

      # Save command files for a subagent to .claude/commands/{agent_name}/.
      # @param command_files [Array<Hash>] command file hashes with :path and :content
      # @param agent_name [String] agent name
      # @param profile_config [Hash, nil] profile configuration
      # @param verbose [Boolean] whether to output verbose messages
      def save_subagent_commands(command_files, agent_name, profile_config = nil, verbose: false)
        return if command_files.empty?

        commands_dir = ".claude/commands/#{agent_name}"
        FileUtils.mkdir_p(commands_dir)

        omit_prefix = profile_config && profile_config['omit_command_prefix'] ? profile_config['omit_command_prefix'] : nil

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
