# frozen_string_literal: true

require 'json'
require 'yaml'

module Ruly
  module Services
    # Recipe-driven MCP (Model Context Protocol) server selection.
    # Collects server names from a recipe's `mcp_servers:` key, its subagent
    # recipes and rule-file frontmatter, resolves them against
    # ~/.config/ruly/mcp.json and writes .mcp.json (or .mcp.yml) during squash.
    # All methods are stateless module functions; external dependencies
    # (load_all_recipes, etc.) are injected via keyword arguments.
    module MCPManager # rubocop:disable Metrics/ModuleLength
      module_function

      # Collect MCP servers declared in rule-file frontmatter.
      # @param local_sources [Array<Hash>] source hashes with :content or :original_content
      # @return [Array<String>] unique server names
      def collect_mcp_servers_from_sources(local_sources)
        servers = []

        local_sources.each do |source|
          content = source[:original_content] || source[:content]
          next unless content

          frontmatter, = Services::FrontmatterParser.parse(content)
          next unless frontmatter.is_a?(Hash) && frontmatter['mcp_servers'].is_a?(Array)

          servers.concat(frontmatter['mcp_servers'])
        end

        servers.uniq
      end

      # Recursively collect all MCP servers from a recipe and its subagent recipes.
      # @param recipe_config [Hash] recipe configuration with optional 'mcp_servers' and 'subagents'
      # @param visited [Set] already-visited recipe names (prevents infinite loops)
      # @param load_all_recipes [Proc] callable returning all recipes hash
      # @return [Array<String>] unique server names
      def collect_all_mcp_servers(recipe_config, load_all_recipes:, visited: Set.new)
        servers = Array(recipe_config['mcp_servers']).dup

        return servers unless recipe_config['subagents'].is_a?(Array)

        recipes = load_all_recipes.call

        recipe_config['subagents'].each do |subagent|
          recipe_name = subagent['recipe']
          next unless recipe_name
          next if visited.include?(recipe_name)

          visited.add(recipe_name)
          subagent_recipe = recipes[recipe_name]
          next unless subagent_recipe

          servers.concat(collect_all_mcp_servers(subagent_recipe, load_all_recipes:, visited:))
        end

        servers.uniq
      end

      # Add the MCP servers named in rule-file frontmatter and in subagent recipes to the recipe's
      # `mcp_servers`, printing the names each step adds.
      # @param recipe_config [Hash, nil] recipe configuration (a Hash is updated in place)
      # @param local_sources [Array<Hash>] processed rule sources
      # @param load_all_recipes [Proc] callable returning all recipes hash
      # @return [Hash, nil] the recipe configuration ({} when servers were found and it was not a Hash)
      def merge_recipe_servers(recipe_config, local_sources, load_all_recipes:)
        servers = collect_mcp_servers_from_sources(local_sources)
        if servers.any?
          recipe_config = {} unless recipe_config.is_a?(Hash)
          existing = Array(recipe_config['mcp_servers'])
          new_servers = servers - existing
          recipe_config['mcp_servers'] = (existing + servers).uniq
          puts "🔌 Collected MCP servers from rule files: #{new_servers.join(', ')}" if new_servers.any?
        end
        if recipe_config.is_a?(Hash) && recipe_config['subagents']
          orig = Array(recipe_config['mcp_servers'])
          all = collect_all_mcp_servers(recipe_config, load_all_recipes:)
          if all.any?
            propagated = all - orig
            recipe_config['mcp_servers'] = all
            puts "🔌 Propagated MCP servers from subagents: #{propagated.join(', ')}" if propagated.any?
          end
        end
        recipe_config
      end

      # Update MCP settings based on recipe config, writing .mcp.json or .mcp.yml.
      # @param recipe_config [Hash, nil] recipe configuration with optional 'mcp_servers'
      # @param agent [String] target agent name ('claude' writes JSON, others write YAML)
      def update_mcp_settings(recipe_config = nil, agent = 'claude')
        require 'yaml'
        require 'json'

        mcp_servers = {}

        # First, check for legacy mcp.yml file
        legacy_mcp_file = 'mcp.yml'
        if File.exist?(legacy_mcp_file)
          mcp_config = YAML.safe_load_file(legacy_mcp_file, aliases: true)
          mcp_servers.merge!(mcp_config['mcpServers']) if mcp_config && mcp_config['mcpServers']
        end

        # Then, load MCP servers from recipe configuration
        if recipe_config && recipe_config['mcp_servers']
          mcp_servers_from_recipe = load_mcp_servers_from_config(recipe_config['mcp_servers'])
          mcp_servers.merge!(mcp_servers_from_recipe) if mcp_servers_from_recipe
        end

        # Determine output format based on agent
        if agent == 'claude'
          write_claude_mcp_settings(mcp_servers)
        else
          write_other_agent_mcp_settings(mcp_servers)
        end
      rescue StandardError => e
        puts "\u26a0\ufe0f  Warning: Could not update MCP settings: #{e.message}"
      end

      # Load MCP server configs by name from ~/.config/ruly/mcp.json.
      # @param server_names [Array<String>] server names to load
      # @return [Hash, nil] server name => config hash, or nil on error
      def load_mcp_servers_from_config(server_names)
        return nil unless server_names&.any?

        # Load MCP server definitions from ~/.config/ruly/mcp.json
        mcp_config_file = File.expand_path('~/.config/ruly/mcp.json')
        return nil unless File.exist?(mcp_config_file)

        all_servers = JSON.parse(File.read(mcp_config_file))
        selected_servers = {}

        server_names.each do |name|
          if all_servers[name]
            # Copy server config but filter out fields starting with underscore (metadata/comments)
            server_config = all_servers[name].dup
            server_config.delete_if { |key, _| key.start_with?('_') } if server_config.is_a?(Hash)
            # Ensure 'type' field is present for stdio servers (required by Claude)
            server_config['type'] = 'stdio' if server_config['command'] && !server_config['type']
            selected_servers[name] = server_config
          else
            puts "\u26a0\ufe0f  Warning: MCP server '#{name}' not found in ~/.config/ruly/mcp.json"
          end
        end

        selected_servers
      rescue JSON::ParserError => e
        puts "\u26a0\ufe0f  Warning: Could not parse MCP configuration file: #{e.message}"
        nil
      rescue StandardError => e
        puts "\u26a0\ufe0f  Warning: Error loading MCP servers: #{e.message}"
        nil
      end

      # Collect MCP servers from both recipe config and rule-file frontmatter.
      # Used when generating agent files.
      # @param recipe_config [Hash] recipe configuration
      # @param local_sources [Array<Hash>] source hashes
      # @return [Array<String>] unique server names
      def collect_agent_mcp_servers(recipe_config, local_sources)
        servers = []
        servers.concat(recipe_config['mcp_servers']) if recipe_config['mcp_servers'].is_a?(Array)
        servers.concat(collect_mcp_servers_from_sources(local_sources))
        servers.uniq
      end

      # -- Private helpers --------------------------------------------------

      # Write Claude-format .mcp.json settings.
      # @param mcp_servers [Hash] server definitions
      def write_claude_mcp_settings(mcp_servers)
        mcp_settings_file = '.mcp.json'

        existing_settings = if File.exist?(mcp_settings_file)
                              JSON.parse(File.read(mcp_settings_file))
                            else
                              {}
                            end

        existing_settings['mcpServers'] = mcp_servers
        File.write(mcp_settings_file, JSON.pretty_generate(existing_settings))

        if mcp_servers.empty?
          puts "\u{1F50C} Created empty .mcp.json (no MCP servers configured)"
        else
          puts "\u{1F50C} Updated .mcp.json with MCP servers"
        end
      end

      # Write YAML-format .mcp.yml settings for non-Claude agents.
      # @param mcp_servers [Hash] server definitions
      def write_other_agent_mcp_settings(mcp_servers)
        return if mcp_servers.empty?

        mcp_settings_file = '.mcp.yml'

        existing_settings = if File.exist?(mcp_settings_file)
                              YAML.safe_load_file(mcp_settings_file, aliases: true) || {}
                            else
                              {}
                            end

        existing_settings['mcpServers'] = mcp_servers
        File.write(mcp_settings_file, existing_settings.to_yaml)
        puts "\u{1F50C} Updated .mcp.yml with MCP servers"
      end

      private_class_method :write_claude_mcp_settings, :write_other_agent_mcp_settings
    end
  end
end
