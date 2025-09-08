# frozen_string_literal: true

require 'English'
require 'thor'
require 'find'
require 'fileutils'
require 'date'
require 'time'
require 'yaml'
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'tiktoken_ruby'
require 'base64'
require_relative 'version'

module Ruly
  # Command Line Interface for Ruly gem
  # Provides commands for managing and compiling AI assistant rules
  class CLI < Thor # rubocop:disable Metrics/ClassLength
    def self.exit_on_failure?
      true
    end

    desc 'squash [RECIPE]', 'Combine all markdown files into one CLAUDE.local.md (recipe optional)'
    option :output_file, aliases: '-o', default: 'CLAUDE.local.md', desc: 'Output file path', type: :string
    option :agent, aliases: '-a', default: 'claude', desc: 'Target agent (claude, cursor, etc.)', type: :string
    option :cache, default: false, desc: 'Enable caching for this recipe', type: :boolean
    option :clean, aliases: '-c', default: false, desc: 'Clean existing files before squashing', type: :boolean
    option :dry_run, aliases: '-d', default: false, desc: 'Show what would be done without actually doing it',
                     type: :boolean
    option :git_ignore, aliases: '-i', default: false, desc: 'Add generated files to .gitignore', type: :boolean
    option :git_exclude, aliases: '-I', default: false, desc: 'Add generated files to .git/info/exclude', type: :boolean
    option :toc, aliases: '-t', default: false, desc: 'Generate table of contents at the beginning of the file',
                 type: :boolean
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def squash(recipe_name = nil)
      # Clean first if requested
      invoke :clean, [recipe_name], options.slice(:output_file, :agent) if options[:clean] && !options[:dry_run]

      output_file = options[:output_file]
      agent = options[:agent]
      # recipe_name is now a positional parameter
      dry_run = options[:dry_run]
      git_ignore = options[:git_ignore]
      git_exclude = options[:git_exclude]
      metadata_file = '.ruly.yml'

      # Check for cached version
      cache_used = false
      if recipe_name && options[:cache] && !dry_run
        cached_file = check_cache(recipe_name, agent)
        if cached_file && should_use_cache?
          puts "\n💾 Using cached version for recipe '#{recipe_name}'"
          FileUtils.cp(cached_file, output_file)
          cache_used = true

          # Still need to handle command files separately
          if agent == 'claude'
            command_files = extract_cached_command_files(cached_file, recipe_name, agent)
            save_command_files(command_files) unless command_files.empty?
          end
        elsif options[:cache]
          puts "\n🔄 No cache found for recipe '#{recipe_name}', fetching fresh..."
        end
      end

      unless cache_used
        ensure_parent_directory(output_file) unless dry_run
        FileUtils.rm_f(output_file) unless dry_run

        sources, recipe_config = if recipe_name
                                   load_recipe_sources(recipe_name)
                                 else
                                   [collect_local_sources, {}]
                                 end

        # Process sources and separate command files
        local_sources, command_files = process_sources_for_squash(sources, agent, recipe_config, options)

        if dry_run
          puts "\n🔍 Dry run mode - no files will be created/modified\n\n"
          puts "Would create: #{output_file}"
          puts "  → #{local_sources.size} rule files combined"
          puts "  → Output size: ~#{local_sources.sum { |s| s[:content].size }} bytes"
          puts "\nWould create: #{metadata_file}"
          puts '  → Metadata for clean command'

          if agent == 'claude' && !command_files.empty?
            puts "\nWould create command files in .claude/commands/:"
            command_files.each do |file|
              # Show subdirectory structure if present
              relative_path = get_command_relative_path(file[:path])
              puts "  → #{relative_path}"
            end
          end

          puts "\nWould cache output for recipe '#{recipe_name}'" if recipe_name && should_use_cache?

          if git_ignore
            puts "\nWould update: .gitignore"
            puts '  → Add entries for generated files'
          end

          if git_exclude
            puts "\nWould update: .git/info/exclude"
            puts '  → Add entries for generated files'
          end

          return
        end

        File.open(output_file, 'w') do |output|
          output.puts '# Combined Ruly Documentation'
          output.puts

          # Generate TOC if requested
          if options[:toc]
            toc_content = generate_toc_content(local_sources, command_files, agent)
            output.puts toc_content
            output.puts
          end

          output.puts '---'

          local_sources.each do |source|
            output.puts
            output.puts "## #{source[:path]}"
            output.puts
            output.puts source[:content]
            output.puts
            output.puts '---'
            output.puts
          end
        end

        # Save metadata file
        metadata = {
          'agent' => agent,
          'command_files' => if agent == 'claude' && !command_files.empty?
                               command_files.map { |f| ".claude/commands/#{File.basename(f[:path])}" }
                             else
                               []
                             end,
          'created_at' => Time.now.iso8601,
          'files_count' => local_sources.size,
          'output_file' => output_file,
          'recipe' => recipe_name,
          'version' => Ruly::VERSION
        }
        File.write(metadata_file, metadata.to_yaml)

        # Update git ignore files if requested
        if git_ignore || git_exclude
          ignore_patterns = generate_ignore_patterns(output_file, agent, command_files)
          update_gitignore(ignore_patterns) if git_ignore
          update_git_exclude(ignore_patterns) if git_exclude
        end

        # Cache the output if recipe has caching enabled
        save_to_cache(output_file, recipe_name, agent) if recipe_name && should_use_cache?

        # Save command files separately if agent is Claude
        save_command_files(command_files) if agent == 'claude' && !command_files.empty?

        # Update MCP settings for Claude agent
        update_claude_settings_with_mcp if agent == 'claude'
      end

      mode_desc = if cache_used
                    "cached squash mode with '#{recipe_name}' recipe"
                  elsif recipe_name
                    "squash mode with '#{recipe_name}' recipe"
                  else
                    'squash mode (combined content)'
                  end

      # Count total files from the output
      total_files = if cache_used
                      cached_file_count(output_file)
                    else
                      local_sources.size + command_files.size
                    end

      print_summary(mode_desc, output_file, total_files)

      return unless agent == 'claude' && !command_files.empty?

      puts "📁 Saved #{command_files.size} command files to .claude/commands/ (with subdirectories)"
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    desc 'clean [RECIPE]', 'Remove generated files (recipe optional, overrides metadata)'
    option :output_file, aliases: '-o', desc: 'Output file to clean (overrides metadata)', type: :string
    option :dry_run, aliases: '-d', default: false, desc: 'Show what would be deleted without actually deleting',
                     type: :boolean
    option :agent, aliases: '-a', default: 'claude', desc: 'Agent name (claude, cursor, etc.)', type: :string
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def clean(recipe_name = nil)
      dry_run = options[:dry_run]
      metadata_file = '.ruly.yml'
      files_to_remove = []
      agent = options[:agent] || 'claude'

      # Try to use metadata file if it exists and no explicit options given
      if File.exist?(metadata_file) && !options[:output_file] && !recipe_name
        metadata = YAML.load_file(metadata_file)
        output_file = metadata['output_file']
        command_files = metadata['command_files'] || []
        agent = metadata['agent'] || 'claude'

        # Add files from metadata
        files_to_remove << output_file if File.exist?(output_file)
        command_files.each do |f|
          files_to_remove << f if File.exist?(f)
        end
        # Add all agent-specific files
        add_agent_files_to_remove(agent, files_to_remove)
        files_to_remove << metadata_file
      else
        # Clean based on recipe or fall back to defaults
        output_file = options[:output_file] || "#{agent.upcase}.local.md"

        files_to_remove << output_file if File.exist?(output_file)
        # Add all agent-specific files
        add_agent_files_to_remove(agent, files_to_remove)
        files_to_remove << metadata_file if File.exist?(metadata_file)
      end

      # Remove duplicates while preserving order
      files_to_remove.uniq!

      if files_to_remove.empty?
        puts '✨ Already clean - no files to remove'
      elsif dry_run
        puts "\n🔍 Dry run mode - no files will be deleted\n\n"
        puts 'Would remove:'
        files_to_remove.each { |f| puts "   - #{f}" }
      else
        # Actually remove files
        files_to_remove.each do |file|
          if file.end_with?('/')
            FileUtils.rm_rf(file.chomp('/'))
          else
            FileUtils.rm_f(file)
          end
        end

        puts '🧹 Cleaned up files:'
        files_to_remove.each { |f| puts "   - #{f}" }
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    desc 'list-recipes', 'List all available recipes'
    def list_recipes # rubocop:disable Metrics/MethodLength
      recipes_file = File.join(gem_root, 'recipes.yml')
      unless File.exist?(recipes_file)
        puts '❌ recipes.yml not found'
        exit 1
      end

      recipes = load_all_recipes
      puts "\n📚 Available Recipes:\n"
      puts '=' * 80

      recipes.each do |name, config| # rubocop:disable Metrics/BlockLength
        puts "\n📦 #{name}"
        puts "   #{config['description']}" if config['description']
        puts

        # Collect all files from different sources
        all_files = []
        all_files.concat(config['files']) if config['files']
        all_files.concat(config['sources']) if config['sources']
        all_files.concat(config['remote_sources']) if config['remote_sources']

        if all_files.empty?
          puts '   (no files configured)'
        else
          # Build and display file tree
          tree = build_recipe_file_tree(all_files)
          display_recipe_tree(tree, '   ')
        end

        # Show summary stats
        file_count = 0
        remote_count = 0
        all_files.each do |file|
          if file.start_with?('http')
            remote_count += 1
          else
            file_count += 1
          end
        end

        puts
        puts "   📊 Summary: #{file_count} local files" if file_count > 0
        puts "   🌐 Remote: #{remote_count} remote sources" if remote_count > 0
        puts "   🎯 Plan: #{config['plan'] || 'default'}" if config['plan']
      end
      puts
    end

    no_commands do # rubocop:disable Metrics/BlockLength
      def build_recipe_file_tree(files)
        tree = {}
        files.each do |file|
          if file.start_with?('http')
            # Group remote files under a special node
            tree['[remote]'] ||= {}
            # Extract domain and path for better organization
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
            # Local files - build tree structure
            parts = file.split('/')
            current = tree
            parts.each_with_index do |part, index|
              if index == parts.length - 1
                # Leaf node (file)
                current[part] = nil
              else
                # Directory node
                current[part] ||= {}
                current = current[part]
              end
            end
          end
        end
        tree
      end

      def display_recipe_tree(tree, prefix = '')
        items = tree.to_a
        items.each_with_index do |(key, value), index|
          is_last = index == items.length - 1
          connector = is_last ? '└── ' : '├── '
          extension = is_last ? '    ' : '│   '

          # Special formatting for remote sources
          if key == '[remote]'
            puts "#{prefix}#{connector}🌐 Remote Sources"
            if value.is_a?(Hash)
              value.each_with_index do |(domain, files), domain_index|
                domain_last = domain_index == value.length - 1
                domain_connector = domain_last ? '└── ' : '├── '
                puts "#{prefix}#{extension}#{domain_connector}#{domain}"
                domain_extension = domain_last ? '    ' : '│   '
                files.each_with_index do |file, file_index|
                  file_last = file_index == files.length - 1
                  file_connector = file_last ? '└── ' : '├── '
                  puts "#{prefix}#{extension}#{domain_extension}#{file_connector}#{file}"
                end
              end
            end
          elsif value.nil?
            # File (leaf node)
            icon = key.end_with?('.md') ? '📄' : '📃'
            puts "#{prefix}#{connector}#{icon} #{key}"
          elsif value.is_a?(Hash)
            # Directory
            puts "#{prefix}#{connector}📁 #{key}/"
            display_recipe_tree(value, "#{prefix}#{extension}")
          end
        end
      end
    end

    desc 'analyze [RECIPE]', 'Analyze token usage for a recipe or all recipes'
    option :plan, aliases: '-p', desc: 'Override pricing plan', type: :string
    option :all, aliases: '-a', default: false, desc: 'Analyze all recipes', type: :boolean
    def analyze(recipe_name = nil)
      load_contexts

      if options[:all]
        analyze_all_recipes
      elsif recipe_name
        analyze_single_recipe(recipe_name)
      else
        puts '❌ Please specify a recipe or use -a for all recipes'
        raise Thor::Error, 'Recipe required'
      end
    end

    desc 'init', 'Initialize Ruly with a basic configuration'
    def init
      config_dir = File.expand_path('~/.config/ruly')
      config_file = File.join(config_dir, 'recipes.yml')

      if File.exist?(config_file)
        puts "✅ Configuration already exists at #{config_file}"
        puts '   Edit this file to customize your recipes and rule sources.'
        return
      end

      # Create directory if it doesn't exist
      FileUtils.mkdir_p(config_dir)

      # Create starter configuration
      starter_config = <<~YAML
        # Ruly Configuration
        # Add your own recipes and rule sources here

        recipes:
          starter:
            description: "Basic starter recipe - uncomment and customize the sources below"
        #{'    '}
            # Example: Add rules from GitHub repositories
            # sources:
            #   - github: patrickclery/rules
            #     branch: main
            #     rules:
            #       - ruby/common.md
            #       - testing/common.md
            ##{'   '}
            #   # Add rules from your own repository:
            #   - github: yourusername/your-rules
            #     branch: main
            #     rules:
            #       - path/to/your/rules.md
        #{'    '}
            # Example: Add local rule files
            # files:
            #   - /path/to/local/rules.md
            #   - ~/my-rules/ruby.md
      YAML

      File.write(config_file, starter_config)

      puts '🎉 Successfully initialized Ruly!'
      puts
      puts "📁 Created configuration at: #{config_file}"
      puts
      puts 'Next steps:'
      puts "  1. Edit #{config_file} to add your rule sources"
      puts '  2. Uncomment and customize the example configurations'
      puts "  3. Run 'ruly squash starter' to combine your rules"
      puts
      puts 'For more information, see: https://github.com/patrickclery/ruly'
    end

    desc 'version', 'Show version'
    def version
      puts "Ruly v#{Ruly::VERSION}"
    end

    private

    def check_cache(recipe_name, agent)
      cache_file = File.join(cache_dir, agent, "#{recipe_name}.md")
      File.exist?(cache_file) ? cache_file : nil
    end

    def cache_dir
      # Use ~/.cache/ruly for standalone mode, otherwise use gem's cache directory
      @cache_dir ||= if ENV['RULY_HOME']
                       File.expand_path('~/.cache/ruly')
                     else
                       File.join(gem_root, 'cache')
                     end
    end

    def gem_root
      # Use RULY_HOME environment variable if set (standalone mode)
      # Otherwise fall back to gem installation path
      @gem_root ||= ENV['RULY_HOME'] || File.expand_path('../..', __dir__)
    end

    def should_use_cache?
      options[:cache] == true
    end

    def extract_cached_command_files(_cached_file, _recipe_name, _agent)
      # Extract command file references from cached content
      # This is a simplified version - you might need to adjust based on actual cache format
      []
    end

    def save_command_files(command_files)
      return if command_files.empty?

      commands_dir = '.claude/commands'
      FileUtils.mkdir_p(commands_dir)

      command_files.each do |file|
        if file.is_a?(Hash)
          # From squash mode - has content
          # Preserve subdirectory structure for commands
          relative_path = get_command_relative_path(file[:path])

          # Create subdirectories if needed
          target_file = File.join(commands_dir, relative_path)
          target_dir = File.dirname(target_file)
          FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

          File.write(target_file, file[:content])
        else
          # From import mode - just path
          source_path = File.join(gem_root, file)
          if File.exist?(source_path)
            # Preserve subdirectory structure
            relative_path = get_command_relative_path(file)

            target_file = File.join(commands_dir, relative_path)
            target_dir = File.dirname(target_file)
            FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

            FileUtils.cp(source_path, target_file)
          end
        end
      end

      # Update .claude/settings.local.json with mcpServers if mcp.yml exists
      update_claude_settings_with_mcp
    end

    def get_command_relative_path(file_path)
      if file_path.include?('/commands/')
        file_path.split('/commands/').last
      else
        File.basename(file_path)
      end
    end

    def update_claude_settings_with_mcp
      mcp_file = 'mcp.yml'
      return unless File.exist?(mcp_file)

      # Load mcpServers from mcp.yml
      require 'yaml'
      require 'json'
      mcp_config = YAML.safe_load_file(mcp_file, aliases: true)
      return unless mcp_config && mcp_config['mcpServers']

      # Ensure .claude directory exists
      claude_dir = '.claude'
      FileUtils.mkdir_p(claude_dir)

      settings_file = File.join(claude_dir, 'settings.local.json')

      # Load existing settings or create new
      settings = if File.exist?(settings_file)
                   JSON.parse(File.read(settings_file))
                 else
                   {}
                 end

      # Update mcpServers
      settings['mcpServers'] = mcp_config['mcpServers']

      # Write back to settings file
      File.write(settings_file, JSON.pretty_generate(settings))
      puts '🔌 Updated .claude/settings.local.json with MCP servers'
    rescue StandardError => e
      puts "⚠️  Warning: Could not update MCP settings: #{e.message}"
    end

    def ensure_parent_directory(file_path)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
    end

    def load_recipe_sources(recipe_name)
      validate_recipes_file!

      recipes = load_all_recipes
      recipe = validate_recipe!(recipe_name, recipes)

      sources = []

      process_recipe_files(recipe, sources)
      process_recipe_sources(recipe, sources)
      process_legacy_remote_sources(recipe, sources)

      [sources, recipe]
    end

    def validate_recipes_file!
      return if File.exist?(recipes_file)

      puts '❌ recipes.yml not found'
      exit 1
    end

    def recipes_file
      @recipes_file ||= File.join(gem_root, 'recipes.yml')
    end

    def load_all_recipes
      recipes = {}

      # Load base recipes
      if File.exist?(recipes_file)
        base_config = YAML.safe_load_file(recipes_file, aliases: true) || {}
        recipes.merge!(base_config['recipes'] || {})
      end

      # Load user config recipes (highest priority)
      user_config_file = File.expand_path('~/.config/ruly/recipes.yml')
      if File.exist?(user_config_file)
        user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
        recipes.merge!(user_config['recipes'] || {})
      end

      recipes
    end

    def validate_recipe!(recipe_name, recipes)
      recipe = recipes[recipe_name]
      return recipe if recipe

      puts "❌ Recipe '#{recipe_name}' not found"
      puts "Available recipes: #{recipes.keys.join(', ')}"
      raise Thor::Error, "Recipe '#{recipe_name}' not found"
    end

    def process_recipe_files(recipe, sources)
      recipe['files']&.each do |file|
        full_path = find_rule_file(file)

        if full_path
          sources << {path: file, type: 'local'}
        else
          puts "⚠️  Warning: File not found: #{file}"
        end
      end
    end

    def find_rule_file(file)
      # Search for file or directory in multiple locations:
      # 1. Current directory
      # 2. ~/ruly/rules directory
      # 3. Gem root directory

      search_paths = [
        file, # Current directory
        File.expand_path("~/ruly/#{file}"),     # User home directory
        File.join(gem_root, file)               # Gem directory
      ]

      search_paths.each do |path|
        # Return path if it exists (either as file or directory)
        return path if File.exist?(path) || File.directory?(path)
      end

      nil # File or directory not found in any location
    end

    def process_recipe_sources(recipe, sources)
      sources_list = recipe['sources'] || []
      sources_list.each do |source_spec|
        process_source_spec(source_spec, sources)
      end
    end

    def process_source_spec(source_spec, sources)
      if source_spec.is_a?(Hash)
        process_hash_source_spec(source_spec, sources)
      elsif source_spec.is_a?(String)
        process_string_source_spec(source_spec, sources)
      end
    end

    def process_hash_source_spec(source_spec, sources)
      if source_spec['github']
        process_github_source(source_spec, sources)
      elsif source_spec['local']
        Array(source_spec['local']).each do |local_path|
          process_local_source(local_path, sources)
        end
      end
    end

    def process_github_source(source_spec, sources)
      owner_repo = source_spec['github']
      branch = source_spec['branch'] || 'main'
      rules = source_spec['rules'] || []

      rules.each do |rule_path|
        # Check if it's a file (has extension like .md or .mdc) or a directory
        if /\.\w+$/.match?(rule_path)
          # It's a file - construct blob URL
          url = "https://github.com/#{owner_repo}/blob/#{branch}/#{rule_path}"
          sources << {path: url, type: 'remote'}
        else
          # It's a directory - construct tree URL
          url = "https://github.com/#{owner_repo}/tree/#{branch}/#{rule_path}"
          process_remote_source(url, sources)
        end
      end
    end

    def process_remote_source(source, sources)
      # Check if it's a GitHub directory URL (tree) or file (blob)
      if source.include?('github.com') && source.include?('/tree/')
        # Check if it's actually a file by looking at the extension
        path_parts = source.split('/')
        last_part = path_parts.last

        # If it ends with a file extension (like .md, .mdc, .yml), treat it as a file
        if /\.\w+$/.match?(last_part)
          # It's a direct file URL that happens to use /tree/ format
          sources << {path: source, type: 'remote'}
        else
          # It's a GitHub directory - expand to all .md files
          # Extract directory name for display
          dir_name = last_part
          puts "  📂 Expanding GitHub directory: #{dir_name}/"
          dir_files = fetch_github_directory_files(source)
          if dir_files.any?
            puts "     Found #{dir_files.length} markdown files"
            dir_files.each do |file_url|
              sources << {path: file_url, type: 'remote'}
            end
          else
            puts '     ⚠️ No markdown files found or failed to access'
          end
        end
      else
        # It's a direct file URL (blob format or other)
        sources << {path: source, type: 'remote'}
      end
    end

    def fetch_github_directory_files(url)
      # Parse GitHub directory URL to extract owner, repo, branch, and path
      # Format: https://github.com/owner/repo/tree/branch/path
      return [] unless url =~ %r{github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)}

      owner = Regexp.last_match(1)
      repo = Regexp.last_match(2)
      branch = Regexp.last_match(3)
      path = Regexp.last_match(4)

      # Use gh api to list directory contents
      result = `gh api repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch} 2>/dev/null`

      if $CHILD_STATUS.success? && !result.empty?
        begin
          # Parse JSON response
          require 'json'
          items = JSON.parse(result)

          # Filter for .md files and convert to blob URLs
          md_files = items.select do |item|
            item['type'] == 'file' && item['name'].end_with?('.md')
          end

          # Convert to blob URLs for fetching content
          md_files.map do |file|
            "https://github.com/#{owner}/#{repo}/blob/#{branch}/#{path}/#{file['name']}"
          end
        rescue JSON::ParserError => e
          puts "⚠️  Error parsing GitHub directory response: #{e.message}"
          []
        end
      else
        puts "⚠️  Failed to fetch directory contents from: #{url}"
        []
      end
    rescue StandardError => e
      puts "⚠️  Error fetching GitHub directory: #{e.message}"
      []
    end

    def process_local_source(source, sources)
      full_path = find_rule_file(source)

      if full_path
        if File.directory?(full_path)
          process_local_directory(full_path, sources)
        else
          # It's a single file
          sources << {path: source, type: 'local'}
        end
      else
        puts "⚠️  Warning: File or directory not found: #{source}"
      end
    end

    def process_local_directory(directory_path, sources)
      Dir.glob(File.join(directory_path, '**', '*.md')).each do |file|
        # Store relative path from gem root or absolute path
        relative_path = if file.start_with?(gem_root)
                          file.sub("#{gem_root}/", '')
                        else
                          file
                        end
        sources << {path: relative_path, type: 'local'}
      end
    end

    def process_string_source_spec(source_spec, sources)
      if source_spec.start_with?('http://', 'https://')
        process_remote_source(source_spec, sources)
      else
        process_local_source(source_spec, sources)
      end
    end

    def process_legacy_remote_sources(recipe, sources)
      recipe['remote_sources']&.each do |url|
        sources << {path: url, type: 'remote'}
      end
    end

    def collect_local_sources
      sources = []
      Find.find(rules_dir) do |path|
        if path.end_with?('.md', '.mdc')
          relative_path = path.sub("#{rules_dir}/", 'rules/')
          sources << {path: relative_path, type: 'local'}
        end
      end
      sources.sort_by { |s| s[:path] }
    end

    def rules_dir
      @rules_dir ||= File.join(gem_root, 'rules')
    end

    def process_sources_for_squash(sources, agent, _recipe_config, _options)
      local_sources = []
      command_files = []

      # Show total count
      puts "\n📚 Processing #{sources.length} sources..."

      # Prefetch remote files using GraphQL
      prefetched_content = prefetch_remote_files(sources)

      # Process all sources in order for display
      sources.each_with_index do |source, index|
        result = process_single_source(source, index, sources.length, agent, prefetched_content)

        if result
          if result[:is_command]
            command_files << result[:data]
          else
            local_sources << result[:data]
          end
        end
      end

      puts

      [local_sources, command_files]
    end

    def prefetch_remote_files(sources)
      remote_sources = sources.select { |s| s[:type] == 'remote' }
      return {} unless remote_sources.any?

      prefetched_content = {}
      grouped_remotes = group_remote_sources_by_repo(remote_sources)

      # Batch fetch files from each repository using GraphQL
      grouped_remotes.each do |repo_key, repo_sources|
        next unless repo_sources.size > 1 # Use GraphQL for multiple files

        puts "  🔄 Batch fetching #{repo_sources.size} files from #{repo_key}..."
        batch_content = fetch_github_files_graphql(repo_key, repo_sources)
        if batch_content && !batch_content.empty?
          prefetched_content.merge!(batch_content)
          puts "    ✅ Successfully fetched #{batch_content.size} files"
        else
          puts '    ⚠️ Batch fetch failed, will fetch individually'
        end
      end

      prefetched_content
    end

    def group_remote_sources_by_repo(remote_sources)
      grouped = {}
      remote_sources.each do |source|
        next unless source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/}

        repo_key = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}"
        grouped[repo_key] ||= []
        grouped[repo_key] << source
      end
      grouped
    end

    def fetch_github_files_graphql(repo_key, repo_sources)
      owner, repo = repo_key.split('/')

      # Build GraphQL query for multiple files
      query = build_graphql_files_query(owner, repo, repo_sources)

      # Execute GraphQL query
      response = execute_github_graphql(query)
      unless response
        puts '    Debug: No response from GraphQL' if ENV['DEBUG']
        return nil
      end

      # Parse response and map to source paths
      result = parse_graphql_files_response(response, repo_sources)
      puts "    Debug: Parsed #{result.size} files from GraphQL" if ENV['DEBUG']
      result
    rescue StandardError => e
      puts "  ⚠️  GraphQL fetch failed: #{e.message}"
      nil
    end

    def build_graphql_files_query(owner, repo, sources)
      # Extract file paths and branches from sources
      file_queries = sources.map.with_index do |source, idx|
        if source[:path] =~ %r{/(?:blob|tree)/([^/]+)/(.+)}
          branch = Regexp.last_match(1)
          file_path = Regexp.last_match(2)
          "file#{idx}: object(expression: \"#{branch}:#{file_path}\") { ... on Blob { text } }"
        end
      end.compact

      <<~GRAPHQL
        query {
          repository(owner: "#{owner}", name: "#{repo}") {
            #{file_queries.join("\n    ")}
          }
        }
      GRAPHQL
    end

    def execute_github_graphql(query)
      # Try using gh CLI for GraphQL (it handles authentication)
      # Use heredoc to properly escape the query
      require 'tempfile'
      file = Tempfile.new(['graphql', '.txt'])
      file.write(query)
      file.close

      result = `gh api graphql -f query="$(cat #{file.path})" 2>&1`
      file.unlink

      return nil unless $CHILD_STATUS.success?

      # Force UTF-8 encoding
      result.force_encoding('UTF-8')

      require 'json'
      JSON.parse(result)
    rescue StandardError => e
      puts "    Debug: GraphQL execution error: #{e.message}" if ENV['DEBUG']
      nil
    end

    def parse_graphql_files_response(response, sources)
      return {} unless response['data'] && response['data']['repository']

      results = {}
      repo_data = response['data']['repository']

      sources.each_with_index do |source, idx|
        file_data = repo_data["file#{idx}"]
        results[source[:path]] = file_data['text'] if file_data && file_data['text']
      end

      results
    end

    def process_single_source(source, index, total, agent, prefetched_content)
      if source[:type] == 'local'
        process_local_file_with_progress(source, index, total, agent)
      elsif prefetched_content[source[:path]]
        # Use prefetched content from GraphQL
        display_prefetched_remote(source, index, total, agent, prefetched_content[source[:path]])
      else
        # Fallback to individual fetch
        process_remote_file_with_progress(source, index, total, agent)
      end
    end

    def process_local_file_with_progress(source, index, total, agent)
      print "  [#{index + 1}/#{total}] 📁 Local: #{source[:path]}..."
      file_path = find_rule_file(source[:path])

      if file_path
        content = File.read(file_path)
        is_command = agent == 'claude' && (file_path.include?('/commands/') || source[:path].include?('/commands/'))
        puts is_command ? ' ✅ (command)' : ' ✅'
        {data: {content:, path: source[:path]}, is_command:}
      else
        puts ' ❌ not found'
        nil
      end
    end

    def display_prefetched_remote(source, index, total, agent, content)
      # Extract domain and full path for display
      if source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        file_path = Regexp.last_match(3)
        display_name = "#{owner}/#{repo}/#{file_path}"
        icon = '🐙'
      else
        display_name = source[:path]
        icon = '📦'
      end

      print "  [#{index + 1}/#{total}] #{icon} Processing: #{display_name}..."

      # Check if remote file is a command file
      is_command = agent == 'claude' && source[:path].include?('/commands/')
      puts is_command ? ' ✅ (command)' : ' ✅'

      {data: {content:, path: source[:path]}, is_command:}
    end

    def process_remote_file_with_progress(source, index, total, agent)
      # Extract domain and full path for display
      if source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        file_path = Regexp.last_match(3)
        display_name = "#{owner}/#{repo}/#{file_path}"
        icon = '🐙'
      elsif source[:path] =~ %r{https?://([^/]+)/(.+)}
        domain = Regexp.last_match(1)
        path = Regexp.last_match(2)
        display_name = "#{domain}/#{path}"
        icon = '🌐'
      else
        display_name = source[:path]
        icon = '🌐'
      end
      print "  [#{index + 1}/#{total}] #{icon} Fetching: #{display_name}..."
      content = fetch_remote_content(source[:path])
      if content
        # Check if remote file is a command file (has /commands/ in path)
        is_command = agent == 'claude' && source[:path].include?('/commands/')
        puts is_command ? ' ✅ (command)' : ' ✅'
        {data: {content:, path: source[:path]}, is_command:}
      else
        puts ' ❌ failed'
        nil
      end
    end

    def fetch_remote_content(url)
      # Try to use gh CLI for GitHub URLs (handles authentication)
      if url.include?('github.com')
        content = fetch_via_gh_cli(url)
        return content if content
      end

      # Fallback to direct HTTP for non-GitHub or if gh fails
      raw_url = convert_to_raw_url(url)
      uri = URI(raw_url)
      response = Net::HTTP.get_response(uri)
      return response.body if response.code == '200'

      # Error message will be shown inline during processing
      nil
    rescue StandardError
      # Error message will be shown inline during processing
      nil
    end

    def fetch_via_gh_cli(url)
      # Parse GitHub URL to extract owner, repo, branch, and path
      # Format: https://github.com/owner/repo/blob/branch/path
      return nil unless url =~ %r{github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)}

      owner = Regexp.last_match(1)
      repo = Regexp.last_match(2)
      branch = Regexp.last_match(3)
      path = Regexp.last_match(4)

      # Try API fetch first
      content = fetch_via_gh_api(owner, repo, branch, path)
      return content if content

      # Fallback to shallow clone
      fetch_via_gh_clone(owner, repo, branch, path)
    rescue StandardError => e
      puts "⚠️  Error using gh CLI: #{e.message}"
      nil
    end

    def fetch_via_gh_api(owner, repo, branch, path)
      # Use gh api to fetch file content
      result = `gh api repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch} --jq .content 2>/dev/null`

      return nil unless $CHILD_STATUS.success? && !result.empty?

      # GitHub API returns base64 encoded content
      require 'base64'
      Base64.decode64(result)
    end

    def fetch_via_gh_clone(owner, repo, branch, path)
      # Get default branch name
      result = `gh repo view #{owner}/#{repo} --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null`
      return nil unless $CHILD_STATUS.success? && !result.empty?

      default_branch = result.strip
      branch_to_use = %w[master main].include?(branch) ? default_branch : branch

      # Clone and read file
      temp_dir = "/tmp/ruly_fetch_#{Process.pid}"
      clone_cmd = "gh repo clone #{owner}/#{repo} #{temp_dir} -- --depth=1 "
      clone_cmd += "--branch=#{branch_to_use} --single-branch 2>/dev/null"
      `#{clone_cmd}`

      return nil unless $CHILD_STATUS.success?

      file_path = File.join(temp_dir, path)
      content = File.exist?(file_path) ? File.read(file_path) : nil
      FileUtils.rm_rf(temp_dir)
      content
    end

    def convert_to_raw_url(url)
      # Convert GitHub blob URLs to raw URLs for direct content access
      # Example: https://github.com/user/repo/blob/master/file.md
      # Becomes: https://raw.githubusercontent.com/user/repo/master/file.md
      if url.include?('github.com') && url.include?('/blob/')
        url.sub('github.com', 'raw.githubusercontent.com').sub('/blob/', '/')
      else
        url
      end
    end

    def generate_toc_content(local_sources, command_files, agent)
      toc_lines = ['## Table of Contents', '']

      # Generate TOC for source files
      local_sources.each do |source|
        toc_lines << generate_toc_for_source(source)
      end

      # Generate slash commands section
      toc_lines.concat(generate_toc_slash_commands(command_files)) if agent == 'claude' && !command_files.empty?

      toc_lines.join("\n")
    end

    def generate_toc_for_source(source)
      toc_section = ["### #{source[:path]}", '']
      headers = extract_headers_from_content(source[:content])

      if headers.any?
        headers.each do |header|
          indent = '  ' * (header[:level] - 2) if header[:level] > 2
          toc_section << "#{indent}- [#{header[:text]}](##{header[:anchor]})"
        end
        toc_section << ''
      end

      toc_section.join("\n")
    end

    def extract_headers_from_content(content)
      headers = []
      content = content.force_encoding('UTF-8')
      content.each_line.with_index do |line, index|
        if line =~ /^(#+)\s+(.+)$/
          level = Regexp.last_match(1).length
          text = Regexp.last_match(2).strip
          anchor = generate_anchor(text)
          headers << {anchor:, level:, line: index + 1, text:}
        end
      end
      headers
    end

    def generate_anchor(text)
      text.downcase
          .gsub(/[^\w\s-]/, '')
          .gsub(/\s+/, '-').squeeze('-')
          .gsub(/^-|-$/, '')
    end

    def generate_toc_slash_commands(command_files)
      ['### Available Slash Commands', ''] +
        command_files.map do |file|
          cmd_name = extract_command_name(file[:path])
          description = extract_command_description(file[:content])
          "- `/#{cmd_name}` - #{description}"
        end + ['']
    end

    def extract_command_name(file_path)
      File.basename(file_path, '.md').gsub(/[_-]/, ':')
    end

    def extract_command_description(content)
      content = content.force_encoding('UTF-8')

      # Look for description in YAML frontmatter
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

      # Look for first paragraph after heading
      lines = content.split("\n")
      lines.each_with_index do |line, _index|
        next if line.strip.empty? || line.start_with?('#') || line.start_with?('---')

        if line.strip.length > 10
          return line.strip.gsub(/[*_`]/, '')[0..80] + (line.length > 80 ? '...' : '')
        end
      end

      'Command description not available'
    end

    def generate_ignore_patterns(output_file, agent, command_files)
      patterns = []

      # Add main output file
      patterns << output_file

      # Add metadata file
      patterns << '.ruly.yml'

      # Add command files directory for Claude
      patterns << '.claude/commands/' if agent == 'claude' && !command_files.empty?

      patterns
    end

    def update_gitignore(patterns)
      gitignore_file = '.gitignore'

      # Read existing content or start fresh
      existing_content = File.exist?(gitignore_file) ? File.read(gitignore_file) : ''
      existing_lines = existing_content.split("\n")

      # Check if we already have a Ruly section
      ruly_section_start = existing_lines.index('# Ruly generated files')

      if ruly_section_start
        # Find the end of the Ruly section
        ruly_section_end = ruly_section_start + 1
        while ruly_section_end < existing_lines.length &&
              existing_lines[ruly_section_end] &&
              !existing_lines[ruly_section_end].match(/^\s*$/) &&
              !existing_lines[ruly_section_end].start_with?('#')
          ruly_section_end += 1
        end

        # Replace the Ruly section
        new_section = ['# Ruly generated files'] + patterns
        existing_lines[ruly_section_start...ruly_section_end] = new_section
      else
        # Add new Ruly section at the end
        existing_lines << '' unless existing_lines.last && existing_lines.last.empty?
        existing_lines << '# Ruly generated files'
        existing_lines.concat(patterns)
      end

      # Write back to file
      File.write(gitignore_file, "#{existing_lines.join("\n")}\n")
      puts '📦 Updated .gitignore with generated file patterns'
    end

    def update_git_exclude(patterns)
      exclude_file = '.git/info/exclude'

      # Ensure .git/info directory exists
      unless Dir.exist?('.git/info')
        puts '⚠️  .git/info directory not found. Is this a git repository?'
        return
      end

      # Read existing content or start fresh
      existing_content = File.exist?(exclude_file) ? File.read(exclude_file) : ''
      existing_lines = existing_content.split("\n")

      # Check if we already have a Ruly section
      ruly_section_start = existing_lines.index('# Ruly generated files')

      if ruly_section_start
        # Find the end of the Ruly section
        ruly_section_end = ruly_section_start + 1
        while ruly_section_end < existing_lines.length &&
              existing_lines[ruly_section_end] &&
              !existing_lines[ruly_section_end].match(/^\s*$/) &&
              !existing_lines[ruly_section_end].start_with?('#')
          ruly_section_end += 1
        end

        # Replace the Ruly section
        new_section = ['# Ruly generated files'] + patterns
        existing_lines[ruly_section_start...ruly_section_end] = new_section
      else
        # Add new Ruly section at the end
        existing_lines << '' unless existing_lines.last && existing_lines.last.empty?
        existing_lines << '# Ruly generated files'
        existing_lines.concat(patterns)
      end

      # Write back to file
      File.write(exclude_file, "#{existing_lines.join("\n")}\n")
      puts '📦 Updated .git/info/exclude with generated file patterns'
    end

    def save_to_cache(output_file, recipe_name, agent)
      agent_cache_dir = File.join(cache_dir, agent)
      FileUtils.mkdir_p(agent_cache_dir)

      cache_file = File.join(agent_cache_dir, "#{recipe_name}.md")
      FileUtils.cp(output_file, cache_file)
    end

    def cached_file_count(output_file)
      # Count the number of sections in the output file
      return 0 unless File.exist?(output_file)

      content = File.read(output_file, encoding: 'UTF-8')
      content.scan(/^## /).size
    rescue StandardError
      # If we can't read the file for any reason, return 0
      0
    end

    def print_summary(mode, output_file, file_count)
      puts "\n✅ Successfully generated #{output_file} using #{mode}"
      puts "📊 Combined #{file_count} files"
      puts "📏 Output size: #{File.size(output_file)} bytes"

      # Add token counting
      agent = options[:agent] || 'claude'
      display_token_info(output_file, agent)
    end

    def display_token_info(output_file, agent)
      content = File.read(output_file, encoding: 'UTF-8')
      token_count = count_tokens(content)

      # Get the context limit for the agent
      limit = agent_context_limits[agent.downcase] || 100_000
      percentage = ((token_count.to_f / limit) * 100).round(1)

      # Format numbers with commas
      formatted_tokens = token_count.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      formatted_limit = limit.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      # Color code based on percentage
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

    def count_tokens(text)
      # Use cl100k_base encoding (used by GPT-4, Claude, etc.)
      encoder = Tiktoken.get_encoding('cl100k_base')
      encoder.encode(text).length
    end

    def agent_context_limits
      {
        'aider' => 128_000,       # Aider (uses GPT-4)
        'claude' => 200_000,      # Claude 3 Opus/Sonnet/Haiku
        'codeium' => 32_000,      # Codeium
        'continue' => 32_000,     # Continue.dev
        'copilot' => 32_000,      # GitHub Copilot
        'cursor' => 32_000,       # Cursor IDE (based on GPT-4)
        'gpt3' => 16_000,         # GPT-3.5 Turbo
        'gpt4' => 128_000,        # GPT-4 Turbo
        'windsurf' => 32_000      # Windsurf
      }
    end

    def add_agent_files_to_remove(agent, files_to_remove)
      agent_lower = agent.downcase
      agent_upper = agent.upcase

      # Add agent-specific directory (e.g., .claude/)
      agent_dir = ".#{agent_lower}"
      if Dir.exist?(agent_dir)
        # Determine file extension based on agent
        file_pattern = case agent_lower
                       when 'cursor'
                         "#{agent_dir}/**/*.mdc"
                       else
                         "#{agent_dir}/**/*.md"
                       end

        # Add all files recursively in the agent directory
        Dir.glob(file_pattern).each do |file|
          files_to_remove << file
        end
        # Add the directory itself for removal
        files_to_remove << "#{agent_dir}/"
      end

      # Add agent-specific local file (e.g., CLAUDE.local.md)
      # Different agents have different naming conventions
      case agent_lower
      when 'cursor'
        # Cursor doesn't use a local file, only .cursor/ directory with .mdc files
        # No local file to remove
      else
        agent_local_file = "#{agent_upper}.local.md"
        files_to_remove << agent_local_file if File.exist?(agent_local_file)
      end
    end

    def load_contexts
      contexts_file = File.join(gem_root, 'lib', 'ruly', 'contexts.yml')
      @contexts = YAML.load_file(contexts_file) if File.exist?(contexts_file)
      @load_contexts ||= {}
    end

    def analyze_all_recipes
      recipes = load_all_recipes

      puts '📊 Token Analysis for All Recipes'
      puts '=' * 60

      recipes.each_key do |name|
        sources, = load_recipe_sources(name)

        # Calculate content size
        total_content = ''
        file_count = 0

        sources.each do |source|
          if source[:type] == 'local'
            file_path = find_rule_file(source[:path])
            if file_path
              content = File.read(file_path, encoding: 'UTF-8')
              total_content += content
              file_count += 1
            end
          elsif source[:type] == 'remote'
            total_content += ' ' * 2000 # Estimate
            file_count += 1
          end
        end

        token_count = count_tokens(total_content)
        plan = get_plan_for_recipe(name)
        context_limit = get_context_limit_for_plan(plan)

        display_recipe_analysis(name, file_count, token_count, plan, context_limit, compact: true)
      rescue StandardError => e
        puts "  ❌ #{name}: Error - #{e.message}"
      end
    end

    def get_plan_for_recipe(recipe_name)
      # Priority: CLI option > recipe-level > user config > global default
      return options[:plan] if options[:plan]

      # Load recipe config
      recipes = load_all_recipes
      recipe = recipes[recipe_name]
      return recipe['plan'] if recipe && recipe['plan']

      # Check user config
      user_config_file = File.expand_path('~/.config/ruly/recipes.yml')
      if File.exist?(user_config_file)
        user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
        return user_config['plan'] if user_config['plan']
      end

      # Check global default in recipes.yml
      recipes_config = YAML.safe_load_file(recipes_file, aliases: true) || {}
      return recipes_config['plan'] if recipes_config['plan']

      # Default fallback
      'claude_pro'
    end

    def get_context_limit_for_plan(plan)
      # Handle aliases
      plan = @contexts['aliases'][plan] if @contexts['aliases'] && @contexts['aliases'][plan]

      # Parse nested plan (e.g., "claude.pro")
      if plan.include?('.')
        service, tier = plan.split('.', 2)
        context_info = @contexts.dig(service, tier)
      else
        # Search all services for the plan
        @contexts.each_value do |tiers|
          next unless tiers.is_a?(Hash)

          tiers.each_value do |info|
            next unless info.is_a?(Hash)
            return info['context'] if info['name'] == plan
          end
        end
      end

      context_info ? context_info['context'] : 100_000 # Default fallback
    end

    def display_recipe_analysis(recipe_name, file_count, token_count, plan, context_limit, compact: false) # rubocop:disable Metrics/MethodLength
      percentage = ((token_count.to_f / context_limit) * 100).round(1)

      # Format numbers
      formatted_tokens = token_count.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      formatted_limit = context_limit.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      # Status indicator
      status = if percentage < 50
                 '🟢'
               elsif percentage < 80
                 '🟡'
               elsif percentage < 95
                 '🟠'
               else
                 '🔴'
               end

      if compact
        context_label = formatted_limit
        puts format('  %-20<recipe>s %6<tokens>s tokens / %-7<context>s (%5.1<percent>f%%) %<status>s [%<plan>s]',
                    context: context_label,
                    percent: percentage,
                    plan:,
                    recipe: recipe_name,
                    status:,
                    tokens: formatted_tokens)
      else
        puts "\n📦 Recipe: #{recipe_name}"
        puts "📄 Files: #{file_count}"
        puts "🎯 Plan: #{plan}"
        puts "🧮 Tokens: #{formatted_tokens} / #{formatted_limit} (#{percentage}%) #{status}"

        if percentage > 80
          puts '⚠️  Warning: This recipe is approaching the context limit!' if percentage < 95
          puts '❌ Error: This recipe exceeds the context limit!' if percentage >= 100
        else
          puts "✅ This recipe fits comfortably within your plan's context window"
        end
      end
    end

    def analyze_single_recipe(recipe_name)
      sources, = load_recipe_sources(recipe_name)

      # Calculate content and tokens for each file
      file_details = []
      total_content = ''
      file_count = 0

      sources.each do |source|
        total_content, file_count = process_source_for_analysis(source, file_details, total_content, file_count)
      end

      # Get token count
      token_count = count_tokens(total_content)

      # Get plan and context limit
      plan = get_plan_for_recipe(recipe_name)
      context_limit = get_context_limit_for_plan(plan)

      # Display detailed analysis
      display_detailed_analysis(recipe_name, file_details, token_count, plan, context_limit)
    end

    def process_source_for_analysis(source, file_details, total_content, file_count)
      if source[:type] == 'local'
        file_path = find_rule_file(source[:path])
        if file_path
          content = File.read(file_path, encoding: 'UTF-8')
          tokens = count_tokens(content)
          file_details << {
            path: source[:path],
            size: content.bytesize,
            tokens:,
            type: 'local'
          }
          total_content += content
          file_count += 1
        end
      elsif source[:type] == 'remote'
        # For dry-run, estimate remote file size
        estimated_content = ' ' * 2000 # Estimate 2KB per remote file
        tokens = count_tokens(estimated_content)
        file_details << {
          path: source[:path],
          size: 2000,
          tokens:,
          type: 'remote'
        }
        total_content += estimated_content
        file_count += 1
      end
      [total_content, file_count]
    end

    def display_detailed_analysis(recipe_name, file_details, token_count, plan, context_limit)
      percentage = ((token_count.to_f / context_limit) * 100).round(1)
      formatted_tokens = token_count.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      formatted_limit = context_limit.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      # Status indicator
      status = if percentage < 50
                 '🟢'
               elsif percentage < 80
                 '🟡'
               elsif percentage < 95
                 '🟠'
               else
                 '🔴'
               end

      puts "\n📦 Recipe: #{recipe_name}"
      puts "🎯 Plan: #{plan}"
      puts

      # Build file tree structure
      tree = build_file_tree(file_details)
      display_file_tree(tree)

      puts
      puts '📊 Total Summary:'
      puts "   Files: #{file_details.size}"
      puts "   Tokens: #{formatted_tokens} / #{formatted_limit} (#{percentage}%) #{status}"

      if percentage > 80
        puts '   ⚠️  Warning: This recipe is approaching the context limit!' if percentage < 95
        puts '   ❌ Error: This recipe exceeds the context limit!' if percentage >= 100
      else
        puts "   ✅ This recipe fits comfortably within your plan's context window"
      end
    end

    def build_file_tree(file_details)
      tree = {}

      file_details.each do |file|
        path_parts = file[:path].split('/')
        current_level = tree

        path_parts.each_with_index do |part, index|
          if index == path_parts.length - 1
            # This is a file
            current_level[part] = file
          else
            # This is a directory
            current_level[part] ||= {}
            current_level = current_level[part]
          end
        end
      end

      tree
    end

    def display_file_tree(tree, is_root: true, prefix: '')
      items = tree.to_a
      items.each_with_index do |(key, value), index|
        is_last_item = index == items.length - 1

        if value.is_a?(Hash) && value[:path]
          # This is a file
          tokens = value[:tokens].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
          size_kb = (value[:size] / 1024.0).round(1)
          type_icon = value[:type] == 'remote' ? '🌐' : '📄'

          if is_root && items.length == 1
            puts "#{type_icon} #{key} (#{tokens} tokens, #{size_kb} KB)"
          else
            connector = is_last_item ? '└── ' : '├── '
            puts "#{prefix}#{connector}#{type_icon} #{key} (#{tokens} tokens, #{size_kb} KB)"
          end
        elsif value.is_a?(Hash)
          # This is a directory
          if is_root && items.length == 1
            puts "📁 #{key}/"
            display_file_tree(value, is_root: false, prefix: '')
          else
            connector = is_last_item ? '└── ' : '├── '
            puts "#{prefix}#{connector}📁 #{key}/"

            new_prefix = prefix + (is_last_item ? '    ' : '│   ')
            display_file_tree(value, is_root: false, prefix: new_prefix)
          end
        end
      end
    end
  end # rubocop:enable Metrics/ClassLength
end
