# frozen_string_literal: true

require 'json'
require 'yaml'

module Ruly
  module Services
    # Manages MCP (Model Context Protocol) server configuration.
    # Handles loading definitions, collecting servers from recipes/sources,
    # and writing .mcp.json output files.
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

      # Load all MCP server definitions from ~/.config/ruly/mcp.json.
      # @return [Hash, nil] full server definitions hash, or nil if missing
      def load_mcp_server_definitions
        mcp_config_file = File.expand_path('~/.config/ruly/mcp.json')

        unless File.exist?(mcp_config_file)
          puts "\u274c Error: ~/.config/ruly/mcp.json not found"
          puts '   Create this file with your MCP server definitions.'
          return nil
        end

        JSON.parse(File.read(mcp_config_file))
      end

      # Collect MCP server names from a recipe specified by name.
      # @param recipe_name [String, nil] recipe name to look up
      # @param load_all_recipes [Proc] callable returning all recipes hash
      # @return [Array<String>, nil] server names, empty array if no recipe, nil if recipe not found
      def collect_recipe_mcp_servers(recipe_name, load_all_recipes:)
        return [] unless recipe_name

        recipes = load_all_recipes.call
        recipe_config = recipes[recipe_name]

        if recipe_config.nil?
          puts "\u274c Error: Recipe '#{recipe_name}' not found"
          return nil
        end

        recipe_servers = recipe_config['mcp_servers'] || []
        puts "\u26a0\ufe0f  Warning: Recipe '#{recipe_name}' has no MCP servers defined" if recipe_servers.empty?
        recipe_servers
      end

      # Filter server definitions to only requested names, cleaning metadata.
      # @param all_servers [Hash] full server definitions
      # @param requested_names [Array<String>] server names to include
      # @return [Hash] filtered server configs
      def build_selected_servers(all_servers, requested_names)
        selected_servers = {}
        requested_names.each do |name|
          if all_servers[name]
            server_config = all_servers[name].dup
            server_config.delete_if { |key, _| key.start_with?('_') } if server_config.is_a?(Hash)
            server_config['type'] = 'stdio' if server_config['command'] && !server_config['type']
            selected_servers[name] = server_config
          else
            puts "\u26a0\ufe0f  Warning: MCP server '#{name}' not found in ~/.config/ruly/mcp.json"
          end
        end
        selected_servers
      end

      # Write selected servers to .mcp.json.
      # @param selected_servers [Hash] server name => config
      # @param append [Boolean] whether to merge with existing .mcp.json
      def write_mcp_json(selected_servers, append: false)
        existing_settings = {}
        existing_settings = JSON.parse(File.read('.mcp.json')) if append && File.exist?('.mcp.json')

        existing_servers = existing_settings['mcpServers'] || {}
        merged_servers = existing_servers.merge(selected_servers)

        output = {'mcpServers' => merged_servers}
        File.write('.mcp.json', JSON.pretty_generate(output))

        if selected_servers.empty?
          puts "\u26a0\ufe0f  No valid servers found, created empty .mcp.json"
        elsif append
          puts "\u{1F50C} Appended #{selected_servers.size} server(s) to .mcp.json"
        else
          puts "\u{1F50C} Created .mcp.json with #{selected_servers.size} server(s)"
        end
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
