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
require 'tempfile'
require 'shellwords'
require_relative 'version'
require_relative 'operations'
require_relative 'services'

module Ruly
  # Command Line Interface for Ruly gem
  # Provides commands for managing and compiling AI assistant rules
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'squash [RECIPE]', 'Combine all markdown files into one CLAUDE.local.md (recipe optional)'
    option :output_file, aliases: '-o', default: 'CLAUDE.local.md', desc: 'Output file path', type: :string
    option :agent, aliases: '-a', default: 'claude', desc: 'Target agent (claude, cursor, etc.)', type: :string
    option :cache, default: false, desc: 'Enable caching for this recipe', type: :boolean
    option :clean, aliases: '-c', default: false, desc: 'Clean existing files before squashing', type: :boolean
    option :deepclean, default: false, desc: 'Deep clean all Claude artifacts before squashing', type: :boolean
    option :dry_run, aliases: '-d', default: false, desc: 'Show what would be done without actually doing it',
                     type: :boolean
    option :git_ignore, aliases: '-i', default: false, desc: 'Add generated files to .gitignore', type: :boolean
    option :git_exclude, aliases: '-I', default: false, desc: 'Add generated files to .git/info/exclude', type: :boolean
    option :toc, aliases: '-t', default: false, desc: 'Generate table of contents at the beginning of the file',
                 type: :boolean
    option :essential, aliases: '-e', default: false,
                       desc: 'Only include files marked as essential: true in frontmatter',
                       type: :boolean
    option :taskmaster_config, aliases: '-T', default: false,
                               desc: 'Copy TaskMaster config to .taskmaster/config.json',
                               type: :boolean
    option :keep_taskmaster, default: false,
                             desc: 'When used with --clean or --deepclean, append Task Master import to output file',
                             type: :boolean
    option :front_matter, default: false,
                          desc: 'Preserve non-metadata frontmatter in output',
                          type: :boolean
    option :home_override, default: false,
                           desc: 'Allow running squash in $HOME directory (dangerous)',
                           type: :boolean
    option :verbose, aliases: '-v', default: false, desc: 'Show detailed per-file processing output', type: :boolean
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def squash(recipe_name = nil)
      # Safeguard: prevent running in $HOME to avoid deleting ~/.claude/
      if Dir.pwd == Dir.home && !options[:home_override]
        say_error "ERROR: Running 'ruly squash' in $HOME is dangerous and may delete ~/.claude/"
        say_error 'Use --home-override if you really want to do this.'
        exit 1
      end

      # Clean first if requested (deepclean takes precedence over clean)
      if options[:deepclean] && !options[:dry_run]
        invoke :clean, [], {deepclean: true, taskmaster_config: options[:taskmaster_config]}
      elsif options[:clean] && !options[:dry_run]
        invoke :clean, [recipe_name], options.slice(:output_file, :agent, :taskmaster_config)
      end

      agent = options[:agent]
      # Normalize agent aliases
      agent = 'shell_gpt' if agent == 'sgpt'
      agent = 'claude' if agent&.downcase&.gsub(/[^a-z]/, '') == 'claudecode'
      # recipe_name is now a positional parameter
      dry_run = options[:dry_run]
      git_ignore = options[:git_ignore]
      git_exclude = options[:git_exclude]

      # Load recipe early to determine output file path based on recipe type
      sources, recipe_config = if recipe_name
                                 load_recipe_sources(recipe_name)
                               else
                                 [collect_local_sources, {}]
                               end

      # Determine output file based on recipe type (Array = agent, Hash = standard)
      output_file = if recipe_name
                      determine_output_file(recipe_name, recipe_config, options)
                    else
                      options[:output_file]
                    end

      # Collect scripts from all sources
      script_files = collect_scripts_from_sources(sources)

      # Build script path mappings for rewriting references
      script_mappings = build_script_mappings(script_files)

      # Check required shell commands and warn about missing ones
      required_commands = collect_required_shell_commands(sources)
      unless required_commands.empty?
        check_result = check_required_shell_commands(required_commands)
        check_result[:missing].each do |cmd|
          puts "⚠️  Warning: Required shell command '#{cmd}' not found in PATH"
        end
      end

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
            save_command_files(command_files, recipe_config) unless command_files.empty?
          end
        elsif options[:cache]
          puts "\n🔄 No cache found for recipe '#{recipe_name}', fetching fresh..."
        end
      end

      unless cache_used
        ensure_parent_directory(output_file) unless dry_run
        FileUtils.rm_f(output_file) unless dry_run

        # Filter to only essential files if --essential flag is set
        if options[:essential]
          sources = filter_essential_sources(sources)
          puts "📌 Essential mode: filtered to #{sources.length} essential files" unless dry_run
        end

        # Process sources and separate command files and bin files
        local_sources, command_files, bin_files, skill_files = process_sources_for_squash(sources, agent,
                                                                                          recipe_config, options)

        # Validate that any dispatches: in source files match registered subagents
        if recipe_name && recipe_config.is_a?(Hash)
          collected_dispatches = collect_dispatches_from_sources(local_sources)
          validate_dispatches_registered!(collected_dispatches, recipe_config, recipe_name)
        end

        if dry_run
          puts "\n🔍 Dry run mode - no files will be created/modified\n\n"

          # Show what would be cleaned first
          if options[:deepclean]
            puts 'Would deep clean first:'
            puts '  → Remove .claude/ directory'
            puts '  → Remove CLAUDE.local.md'
            puts '  → Remove CLAUDE.md'
            puts '  → Remove .taskmaster/ directory' if options[:taskmaster_config]
            puts ''
          elsif options[:clean]
            puts 'Would clean existing files first'
            puts '  → Remove .taskmaster/ directory' if options[:taskmaster_config]
            puts ''
          end

          puts "Would create: #{output_file}"
          puts "  → #{local_sources.size} rule files combined"
          puts "  → Output size: ~#{local_sources.sum { |s| s[:content].size }} bytes"

          if agent == 'claude' && !command_files.empty?
            puts "\nWould create command files in .claude/commands/:"
            # rubocop:disable Layout/LineLength, Metrics/BlockNesting
            omit_prefix = recipe_config && recipe_config['omit_command_prefix'] ? recipe_config['omit_command_prefix'] : nil
            # rubocop:enable Layout/LineLength, Metrics/BlockNesting
            command_files.each do |file|
              # Show subdirectory structure if present
              relative_path = get_command_relative_path(file[:path], omit_prefix)
              puts "  → #{relative_path}"
            end
          end

          unless bin_files.empty?
            puts "\nWould copy bin files to .ruly/bin/:"
            bin_files.each do |file|
              target = calculate_bin_target(file[:relative_path])
              puts "  → #{target} (executable)"
            end
          end

          if agent == 'claude' && !skill_files.empty?
            puts "\nWould create skill files in .claude/skills/:"
            skill_files.each do |file|
              skill_name = file[:path].split('/skills/').last.sub(/\.md$/, '')
              puts "  → .claude/skills/#{skill_name}/SKILL.md"
            end
          end

          # Show scripts that would be copied
          if script_files[:local].any? || script_files[:remote].any?
            total_scripts = script_files[:local].size + script_files[:remote].size
            puts "\nWould copy #{total_scripts} scripts to .claude/scripts/:"
            script_files[:local].each do |script|
              puts "  → #{script[:relative_path]} (local)"
            end
            script_files[:remote].each do |script|
              puts "  → #{script[:filename]} (remote from GitHub)"
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

          copy_taskmaster_config if options[:taskmaster_config]

          return
        end

        # Write output based on agent type
        if agent == 'shell_gpt'
          write_shell_gpt_json(output_file, local_sources)
        else
          # Standard markdown output
          File.open(output_file, 'w') do |output|
            # Generate TOC if requested
            if options[:toc]
              toc_content = generate_toc_content(local_sources, command_files, agent)
              output.puts toc_content
              output.puts
            end

            local_sources.each_with_index do |source, index|
              # Rewrite script references to local .claude/scripts/ paths
              content = rewrite_script_references(source[:content], script_mappings)

              # If TOC is enabled, add anchor IDs to headers in content
              if options[:toc]
                output.puts add_anchor_ids_to_content(content, source[:path])
              else
                output.puts content
              end

              # Add blank line between sources (but not after the last one)
              output.puts if index < local_sources.length - 1
            end
          end

          # Append Task Master import if requested (when using --clean or --deepclean with --keep-taskmaster)
          if (options[:clean] || options[:deepclean]) && options[:keep_taskmaster] && agent != 'shell_gpt'
            File.open(output_file, 'a') do |file|
              file.puts
              file.puts '## Task Master AI Instructions'
              file.puts '**Import Task Master\'s development workflow commands and guidelines, ' \
                        'treat as if import is in the main CLAUDE.md file.**'
              file.puts '@./.taskmaster/CLAUDE.md'
            end
          end
        end

        # Update git ignore files if requested
        if git_ignore || git_exclude
          ignore_patterns = generate_ignore_patterns(output_file, agent, command_files)
          update_gitignore(ignore_patterns) if git_ignore
          update_git_exclude(ignore_patterns) if git_exclude
        end

        # Cache the output if recipe has caching enabled
        save_to_cache(output_file, recipe_name, agent) if recipe_name && should_use_cache?

        # Save command files separately if agent is Claude
        save_command_files(command_files, recipe_config) if agent == 'claude' && !command_files.empty?

        # Save skill files separately if agent is Claude
        save_skill_files(skill_files) if agent == 'claude' && !skill_files.empty?

        # Collect MCP servers from rule-file frontmatter and merge with recipe config
        rule_mcp_servers = collect_mcp_servers_from_sources(local_sources)
        if rule_mcp_servers.any?
          recipe_config = {} unless recipe_config.is_a?(Hash)
          existing = Array(recipe_config['mcp_servers'])
          new_servers = rule_mcp_servers - existing
          recipe_config['mcp_servers'] = (existing + rule_mcp_servers).uniq
          puts "🔌 Collected MCP servers from rule files: #{new_servers.join(', ')}" if new_servers.any?
        end

        # Collect MCP servers from subagent recipes (recursive) and merge with parent
        if recipe_config.is_a?(Hash) && recipe_config['subagents']
          original_servers = Array(recipe_config['mcp_servers'])
          all_mcp_servers = collect_all_mcp_servers(recipe_config)
          if all_mcp_servers.any?
            propagated = all_mcp_servers - original_servers
            recipe_config['mcp_servers'] = all_mcp_servers
            puts "🔌 Propagated MCP servers from subagents: #{propagated.join(', ')}" if propagated.any?
          end
        end

        # Update MCP settings (JSON for Claude, YAML for others)
        update_mcp_settings(recipe_config, agent)

        # Copy TaskMaster config if requested
        copy_taskmaster_config if options[:taskmaster_config]

        # Process subagents if defined in recipe
        process_subagents(recipe_config, recipe_name) if recipe_config.is_a?(Hash) && recipe_config['subagents']

        # Copy scripts to Claude Code directory
        copy_scripts(script_files) if script_files[:local].any? || script_files[:remote].any?

        # Run post-squash validation checks
        Ruly::Checks.run_all(local_sources, command_files)
      end

      mode_desc = if agent == 'shell_gpt'
                    'shell_gpt role JSON'
                  elsif cache_used
                    "cached squash mode with '#{recipe_name}' recipe"
                  elsif recipe_name
                    # Check if this is an agent file (array recipe)
                    if recipe_config.is_a?(Array)
                      "agent generation mode with '#{recipe_name}' recipe"
                    else
                      "squash mode with '#{recipe_name}' recipe"
                    end
                  else
                    'squash mode (combined content)'
                  end

      # Count total files from the output
      total_files = if cache_used
                      cached_file_count(output_file)
                    else
                      local_sources.size + command_files.size + skill_files.size
                    end

      print_summary(mode_desc, output_file, total_files)

      if agent == 'claude' && !command_files.empty?
        puts "📁 Saved #{command_files.size} command files to .claude/commands/ (with subdirectories)"
      end

      return unless agent == 'claude' && !skill_files.empty?

      puts "🎯 Saved #{skill_files.size} skill files to .claude/skills/"
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    desc 'import RECIPE', 'Import a recipe and copy its scripts to ~/.claude/scripts/'
    option :dry_run, aliases: '-d', default: false, desc: 'Show what would be copied without actually copying',
                     type: :boolean
    def import(recipe_name)
      dry_run = options[:dry_run]

      # Load recipe sources
      sources, _recipe_config = load_recipe_sources(recipe_name)

      puts "\n🔄 Processing recipe: #{recipe_name}"

      # Collect scripts from all sources
      script_files = collect_scripts_from_sources(sources)

      if dry_run
        puts "\n🔍 Dry run mode - no files will be copied\n\n"

        if script_files[:local].any? || script_files[:remote].any?
          total_scripts = script_files[:local].size + script_files[:remote].size
          puts "Would copy #{total_scripts} scripts to .claude/scripts/:"
          script_files[:local].each do |script|
            puts "  → #{script[:relative_path]} (local)"
          end
          script_files[:remote].each do |script|
            puts "  → #{script[:filename]} (remote from GitHub)"
          end
        else
          puts "No scripts found in recipe '#{recipe_name}'"
        end
      elsif script_files[:local].any? || script_files[:remote].any?
        # Copy scripts
        copy_scripts(script_files)
        puts "\n✨ Recipe imported successfully"
      else
        puts "No scripts found in recipe '#{recipe_name}'"
      end
    end

    desc 'clean [RECIPE]', 'Remove generated files (recipe optional, overrides metadata)'
    option :output_file, aliases: '-o', desc: 'Output file to clean (overrides metadata)', type: :string
    option :dry_run, aliases: '-d', default: false, desc: 'Show what would be deleted without actually deleting',
                     type: :boolean
    option :agent, aliases: '-a', default: 'claude', desc: 'Agent name (claude, cursor, etc.)', type: :string
    option :deepclean, default: false,
                       desc: 'Remove all generated artifacts (.claude/, CLAUDE files, MCP settings)',
                       type: :boolean
    option :taskmaster_config, aliases: '-T', default: false, desc: 'Also remove .taskmaster/ directory',
                               type: :boolean
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def clean(_recipe_name = nil)
      dry_run = options[:dry_run]
      files_to_remove = []
      agent = options[:agent] || 'claude'
      # Normalize agent aliases
      agent = 'claude' if agent&.downcase&.gsub(/[^a-z]/, '') == 'claudecode'

      # Handle deepclean option - removes all generated artifacts
      files_to_remove << '.claude/' if Dir.exist?('.claude')
      if options[:deepclean]
        # Remove entire .claude directory

        # Remove entire .ruly directory (includes bin/)
        files_to_remove << '.ruly/' if Dir.exist?('.ruly')

        # Remove all CLAUDE*.md files (including CLAUDE.md)
        files_to_remove << 'CLAUDE.local.md' if File.exist?('CLAUDE.local.md')
        files_to_remove << 'CLAUDE.md' if File.exist?('CLAUDE.md')

        # Remove MCP settings files (both JSON and YAML)
        files_to_remove << '.mcp.json' if File.exist?('.mcp.json')
        files_to_remove << '.mcp.yml' if File.exist?('.mcp.yml')
      else
        # Normal clean behavior - ALWAYS remove entire .claude directory

        # Clean based on recipe or fall back to defaults
        output_file = options[:output_file] || "#{agent.upcase}.local.md"

        files_to_remove << output_file if File.exist?(output_file)
        # Remove MCP settings based on agent
        if agent == 'claude'
          files_to_remove << '.mcp.json' if File.exist?('.mcp.json')
        elsif File.exist?('.mcp.yml')
          files_to_remove << '.mcp.yml'
        end
      end

      # Handle TaskMaster config removal if -T flag is present
      if options[:taskmaster_config]
        files_to_remove << '.taskmaster/' if Dir.exist?('.taskmaster')
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
    def list_recipes # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
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

        # Handle new sources format (array of hashes for GitHub sources)
        config['sources']&.each do |source|
          if source.is_a?(Hash)
            if source['github']
              # GitHub source - add each rule as a remote file
              source['rules']&.each do |rule|
                all_files << "https://github.com/#{source['github']}/#{rule}"
              end
            elsif source['local']
              # Local source format
              all_files.concat(source['local'])
            end
          else
            # Legacy format - simple string
            all_files << source
          end
        end

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

    desc 'introspect RECIPE SOURCE...', 'Scan directories or GitHub repos for markdown files and create/update recipe'
    option :description, aliases: '-d', desc: 'Description for the recipe', type: :string
    option :output, aliases: '-o', default: nil, desc: 'Output file path', type: :string
    option :dry_run, default: false, desc: 'Show what would be done without modifying files', type: :boolean
    option :relative, default: false, desc: 'Use relative paths instead of absolute for local files', type: :boolean
    def introspect(recipe_name, *sources) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      if sources.empty?
        puts '❌ At least one source directory or GitHub URL is required'
        exit 1
      end

      # Determine output file
      output_file = options[:output] || user_recipes_file

      puts "\n🔍 Introspecting #{sources.length} source#{'s' if sources.length > 1}..."

      all_local_files = []
      all_github_sources = []

      sources.each do |source|
        if source.start_with?('http') && source.include?('github.com')
          # GitHub source
          introspect_github_source(source, all_github_sources)
        else
          # Local directory
          introspect_local_source(source, all_local_files, options[:relative])
        end
      end

      # Build recipe structure
      recipe_data = build_introspected_recipe(
        all_local_files,
        all_github_sources,
        sources,
        options[:description]
      )

      # Merge with existing recipe to preserve keys (for both dry-run and actual save)
      if File.exist?(output_file)
        existing_config = YAML.safe_load_file(output_file, aliases: true) || {}
        if existing_config['recipes'] && existing_config['recipes'][recipe_name]
          existing_recipe = existing_config['recipes'][recipe_name]

          # Preserve all existing keys except those that introspect updates
          introspect_keys = %w[files sources]
          existing_recipe.each do |key, value|
            next if introspect_keys.include?(key)
            next if key == 'description' && recipe_data['description']

            recipe_data[key] = value
          end

          recipe_data['description'] ||= existing_recipe['description']
        end
      end

      if options[:dry_run]
        puts "\n🔍 Dry run mode - no files will be modified"
        puts "\n📝 Would update recipe '#{recipe_name}' in #{output_file}:"
        puts recipe_data.to_yaml
      else
        # Save or update recipe
        save_introspected_recipe(recipe_name, recipe_data, output_file)

        total_files = all_local_files.length
        all_github_sources.each do |github_source|
          total_files += github_source[:rules].length
        end

        puts "\n✅ Recipe '#{recipe_name}' updated in #{output_file}"
        puts "   #{total_files} total files added to recipe:"
        puts "   - #{all_local_files.length} local files" if all_local_files.any?
        if all_github_sources.any?
          github_file_count = all_github_sources.sum { |s| s[:rules].length }
          puts "   - #{github_file_count} GitHub files"
        end
      end
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

    desc 'mcp [SERVERS...]', 'Generate .mcp.json with specified MCP servers'
    option :append, aliases: '-a', default: false, desc: 'Append to existing .mcp.json instead of overwriting',
                    type: :boolean
    option :recipe, aliases: '-r', desc: 'Use MCP servers from specified recipe', type: :string
    def mcp(*servers)
      all_servers = load_mcp_server_definitions
      return unless all_servers

      recipe_servers = collect_recipe_mcp_servers
      return if recipe_servers.nil?

      all_requested = (servers + recipe_servers).uniq
      if all_requested.empty?
        puts '❌ Error: No servers specified'
        puts '   Usage: ruly mcp server1 server2 ...'
        puts '   Or:    ruly mcp -r <recipe>'
        return
      end

      selected_servers = build_selected_servers(all_servers, all_requested)
      write_mcp_json(selected_servers)
    rescue JSON::ParserError => e
      puts "❌ Error parsing JSON: #{e.message}"
    end

    desc 'stats [RECIPE]', 'Generate stats.md with file token counts sorted by size'
    option :output, aliases: '-o', default: 'stats.md', desc: 'Output file path (default: rules/stats.md)',
                    type: :string
    def stats(recipe_name = nil)
      # Collect sources and resolve paths
      sources = if recipe_name
                  sources_list, = load_recipe_sources(recipe_name)
                  sources_list
                else
                  collect_local_sources
                end

      # Resolve file paths for the operation
      resolved_sources = sources.filter_map do |source|
        next source unless source[:type] == 'local'

        resolved_path = find_rule_file(source[:path])
        source.merge(path: resolved_path) if resolved_path
      end

      puts "📊 Analyzing #{resolved_sources.size} files..."

      # Default output to rules/ directory if not explicitly specified
      output_file = options[:output]
      output_file = File.join(rules_dir, output_file) if output_file == 'stats.md'

      result = Operations::Stats.call(
        output_file:,
        recipes_file:,
        rules_dir:,
        sources: resolved_sources
      )

      display_stats_result(result)
    end

    private

    def load_recipe_sources(recipe_name)
      validate_recipes_file!

      recipes = load_all_recipes
      recipe = validate_recipe!(recipe_name, recipes)

      sources = []

      process_recipe_files(recipe, sources)
      process_recipe_sources(recipe, sources)
      process_legacy_remote_sources(recipe, sources)

      # Scan for files with matching recipe tags in frontmatter
      tagged_sources = scan_files_for_recipe_tags(recipe_name)

      # Merge tagged sources with recipe sources, deduplicating by path
      existing_paths = sources.to_set { |s| s[:path] }
      tagged_sources.each do |tagged_source|
        sources << tagged_source unless existing_paths.include?(tagged_source[:path])
      end

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

    def gem_root
      # Use RULY_HOME environment variable if set (standalone mode)
      # Otherwise fall back to gem installation path
      @gem_root ||= ENV['RULY_HOME'] || File.expand_path('../..', __dir__)
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
      # For agent recipes (arrays), the recipe itself is the list of files
      # For standard recipes (hashes), the files are in recipe['files']
      files = recipe.is_a?(Array) ? recipe : recipe['files']

      files&.each do |file|
        full_path = find_rule_file(file)

        if full_path
          # Check if the path is a directory
          if File.directory?(full_path)
            # If it's a directory, recursively find all .md files
            md_files = find_markdown_files_recursively(full_path)
            if md_files.any?
              # Add each markdown file as a separate source
              md_files.each do |md_file|
                # Use the relative path from the original file spec
                sources << {path: md_file, type: 'local'}
              end
            else
              puts "⚠️  Warning: No markdown files found in directory: #{file}"
            end
          else
            # It's a regular file, add it as before
            sources << {path: file, type: 'local'}
          end
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

    def find_markdown_files_recursively(directory)
      # Find all .md files recursively in the given directory
      md_files = Dir.glob(File.join(directory, '**', '*.md')).map do |file|
        file
      end
      md_files.sort
    end

    def process_recipe_sources(recipe, sources)
      # Agent recipes (arrays) don't have sources, only files
      return if recipe.is_a?(Array)

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
      Services::GitHubClient.fetch_github_directory_files(url)
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
      # Process markdown files
      Dir.glob(File.join(directory_path, '**', '*.md')).each do |file|
        # Store relative path from gem root or absolute path
        relative_path = if file.start_with?(gem_root)
                          file.sub("#{gem_root}/", '')
                        else
                          file
                        end
        sources << {path: relative_path, type: 'local'}
      end

      # Also process bin/*.sh files
      Dir.glob(File.join(directory_path, 'bin', '**', '*.sh')).each do |file|
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
      # Agent recipes (arrays) don't have remote_sources
      return if recipe.is_a?(Array)

      recipe['remote_sources']&.each do |url|
        sources << {path: url, type: 'remote'}
      end
    end

    def scan_files_for_recipe_tags(recipe_name)
      sources = []
      return sources unless File.directory?(rules_dir)

      Find.find(rules_dir) do |path|
        next unless path.end_with?('.md', '.mdc')

        begin
          content = File.read(path, encoding: 'UTF-8')
          frontmatter, = parse_frontmatter(content)

          # Check if this file has a recipes field that includes our recipe
          if frontmatter['recipes']&.include?(recipe_name)
            relative_path = path.sub("#{rules_dir}/", 'rules/')
            sources << {path: relative_path, type: 'local'}
          end
        rescue StandardError => e
          # Skip files that can't be read or parsed
          warn "Warning: Could not parse #{path}: #{e.message}" if ENV['DEBUG']
        end
      end

      sources.sort_by { |s| s[:path] }
    end

    def rules_dir
      @rules_dir ||= File.join(gem_root, 'rules')
    end

    def parse_frontmatter(content)
      Services::FrontmatterParser.parse(content)
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

    # Determine output file path based on recipe type and options
    # @param recipe_name [String] Name of the recipe being squashed
    # @param recipe_value [Hash, Array] The recipe value
    # @param options [Hash] CLI options including :output_file
    # @return [String] Path to output file
    def determine_output_file(recipe_name, recipe_value, options)
      default_output = 'CLAUDE.local.md'

      # User explicitly specified output file - use it (takes precedence)
      return options[:output_file] if options[:output_file] && options[:output_file] != default_output

      # Auto-detect based on recipe type
      if recipe_value.is_a?(Array)
        # Array recipe = agent file goes to .claude/agents/
        ".claude/agents/#{recipe_name}.md"
      else
        # Hash recipe = default behavior
        default_output
      end
    end

    # Collect scripts from all sources
    # Returns hash with :local and :remote arrays
    def collect_scripts_from_sources(sources)
      Services::ScriptManager.collect_scripts_from_sources(sources, find_rule_file: method(:find_rule_file))
    end

    def build_script_mappings(script_files)
      Services::ScriptManager.build_script_mappings(script_files)
    end

    def extract_scripts_from_frontmatter(content, source_path)
      Services::ScriptManager.extract_scripts_from_frontmatter(content, source_path)
    end

    def fetch_remote_scripts(remote_scripts)
      Services::ScriptManager.fetch_remote_scripts(remote_scripts)
    end

    def normalize_github_url(url)
      Services::GitHubClient.normalize_github_url(url)
    end

    # Collect all require_shell_commands from sources
    # @param sources [Array<Hash>] Array of source hashes
    # @return [Array<String>] Unique list of required commands
    def collect_required_shell_commands(sources)
      commands = Set.new

      sources.each do |source|
        next unless source[:type] == 'local'

        file_path = source[:path]
        file_path = find_rule_file(file_path) unless File.exist?(file_path)
        next unless file_path && File.exist?(file_path)

        content = File.read(file_path, encoding: 'UTF-8')
        cmds = extract_require_shell_commands_from_frontmatter(content)
        commands.merge(cmds)
      end

      commands.to_a
    end

    # Extract require_shell_commands from frontmatter
    # @param content [String] The file content with potential frontmatter
    # @return [Array<String>] List of required shell commands
    def extract_require_shell_commands_from_frontmatter(content)
      Services::FrontmatterParser.extract_require_shell_commands(content)
    end

    # Check which required shell commands are available
    # @param commands [Array<String>] List of commands to check
    # @return [Hash] Hash with :available and :missing arrays
    def check_required_shell_commands(commands)
      available = []
      missing = []

      commands.each do |cmd|
        if check_shell_command_available(cmd)
          available << cmd
        else
          missing << cmd
        end
      end

      {available:, missing:}
    end

    # Check if a shell command is available in PATH and executable
    # @param command [String] The command name to check
    # @return [Boolean] true if command is available and executable
    def check_shell_command_available(command)
      # Use 'which' to find the command in PATH
      system("which #{command.shellescape} > /dev/null 2>&1")
    end

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

    def should_use_cache?
      options[:cache] == true
    end

    def extract_cached_command_files(_cached_file, _recipe_name, _agent)
      # Extract command file references from cached content
      # This is a simplified version - you might need to adjust based on actual cache format
      []
    end

    def save_command_files(command_files, recipe_config = nil)
      Services::ScriptManager.save_command_files(command_files, recipe_config, gem_root:)
    end

    def ensure_parent_directory(file_path)
      Services::ScriptManager.ensure_parent_directory(file_path)
    end

    def filter_essential_sources(sources)
      # Filter to only include sources marked as essential: true
      essential_sources = []

      sources.each do |source|
        next unless source[:type] == 'local'

        begin
          file_path = find_rule_file(source[:path])
          next unless file_path

          content = File.read(file_path, encoding: 'UTF-8')
          frontmatter, = parse_frontmatter(content)

          # Include if marked as essential
          essential_sources << source if frontmatter['essential'] == true
        rescue StandardError => e
          # Skip files that can't be read or parsed
          warn "Warning: Could not parse #{source[:path]}: #{e.message}" if ENV['DEBUG']
        end
      end

      essential_sources
    end

    def process_sources_for_squash(sources, agent, _recipe_config, _options) # rubocop:disable Metrics/MethodLength
      local_sources = []
      command_files = []
      bin_files = []
      skill_files = []
      processed_files = Set.new
      sources_to_process = sources.dup

      # Show total count
      puts "\n📚 Processing #{sources.length} sources..." if verbose?

      # Prefetch remote files using GraphQL
      prefetched_content = prefetch_remote_files(sources)

      # Process all sources including requires
      index = 0
      until sources_to_process.empty?
        source = sources_to_process.shift

        # Check if already processed (deduplication)
        source_key = get_source_key(source)
        next if processed_files.include?(source_key)

        # Process the source
        context = {
          agent: agent, # rubocop:disable Style/HashSyntax
          keep_frontmatter: options[:front_matter],
          prefetched_content: prefetched_content, # rubocop:disable Style/HashSyntax
          processed_files: processed_files, # rubocop:disable Style/HashSyntax
          sources_to_process: sources_to_process # rubocop:disable Style/HashSyntax
        }
        result = process_single_source_with_requires(source, index, sources.length + index, context)

        if result
          processed_files.add(source_key)

          if result[:is_bin]
            bin_files << result[:data]
          elsif result[:is_skill]
            skill_files << result[:data]
          elsif result[:is_command]
            command_files << result[:data]
          else
            local_sources << result[:data]
          end
        end

        index += 1
      end

      # Copy bin files to .ruly/bin if any exist
      copy_bin_files(bin_files) unless bin_files.empty? || options[:dry_run]

      puts if verbose?

      [local_sources, command_files, bin_files, skill_files]
    end

    def verbose?
      options[:verbose] || ENV.fetch('DEBUG', nil)
    end

    def prefetch_remote_files(sources)
      Services::GitHubClient.prefetch_remote_files(sources, verbose: verbose?)
    end

    def get_source_key(source)
      # Create a unique key for deduplication
      # For local files, use the absolute canonical path
      # For remote files, use the full URL
      if source[:type] == 'local'
        # Try to find the full path
        full_path = find_rule_file(source[:path])

        # If found, use the real absolute path for deduplication
        # This ensures that "rules/commands.md", "../commands.md", "../../commands.md"
        # all resolve to the same key when they point to the same file
        if full_path
          File.realpath(full_path)
        else
          # If file not found, use the original path as-is
          source[:path]
        end
      else
        source[:path]
      end
    end

    def process_single_source_with_requires(source, index, total, context)
      # Extract context
      agent = context[:agent]
      prefetched_content = context[:prefetched_content]
      processed_files = context[:processed_files]
      sources_to_process = context[:sources_to_process]
      keep_frontmatter = context[:keep_frontmatter]

      # First process the source normally
      result = process_single_source(source, index, total, agent, prefetched_content, keep_frontmatter:)

      return nil unless result

      # If it's a regular markdown file (not bin), check for requires
      if !result[:is_bin] && result[:data] && result[:data][:content]
        # Use original content (with requires intact) for dependency resolution
        content_for_requires = result[:data][:original_content] || result[:data][:content]

        # For skill files, skip adding requires to the main queue — they'll be
        # compiled into the skill output by save_skill_files instead
        unless result[:is_skill]
          # Resolve requires for this source
          required_sources = resolve_requires_for_source(source, content_for_requires, processed_files,
                                                         sources_to_process)

          # Add required sources to the front of the queue (depth-first processing)
          unless required_sources.empty?
            puts "    → Found #{required_sources.length} requires, adding to queue..." if verbose?
            # Mark these sources as being from requires
            required_sources.each { |rs| rs[:from_requires] = true }
            sources_to_process.unshift(*required_sources)
          end
        end

        # Resolve skills: frontmatter references (with validation)
        skill_sources = resolve_skills_for_source(source, content_for_requires, processed_files)

        # Add skill sources to the queue — they'll be categorized as skill_files
        # because their paths contain /skills/
        unless skill_sources.empty?
          puts "    → Found #{skill_sources.length} skills, adding to queue..." if verbose?
          sources_to_process.unshift(*skill_sources)
        end
      end

      result
    end

    def process_single_source(source, index, total, agent, prefetched_content, keep_frontmatter: false)
      if source[:type] == 'local'
        process_local_file_with_progress(source, index, total, agent, keep_frontmatter:)
      elsif prefetched_content[source[:path]]
        # Use prefetched content from GraphQL
        display_prefetched_remote(source, index, total, agent, prefetched_content[source[:path]], keep_frontmatter:)
      else
        # Fallback to individual fetch
        process_remote_file_with_progress(source, index, total, agent, keep_frontmatter:)
      end
    end

    def process_local_file_with_progress(source, index, total, agent, keep_frontmatter: false)
      # Check if this is from requires and adjust the message
      prefix = source[:from_requires] ? '📚 Required' : '📁 Local'
      print "  [#{index + 1}/#{total}] #{prefix}: #{source[:path]}..." if verbose?
      file_path = find_rule_file(source[:path])

      unless file_path
        verbose? ? puts(' ❌ not found') : warn("  ⚠️  File not found: #{source[:path]}")
        return nil
      end

      # Check if it's a bin/*.sh file
      is_bin = source[:path].match?(%r{bin/.*\.sh$}) || file_path.match?(%r{bin/.*\.sh$})

      if is_bin
        # For bin files, we'll copy them directly
        puts ' ✅ (bin)' if verbose?
        return {data: {relative_path: source[:path], source_path: file_path}, is_bin: true}
      end

      content = File.read(file_path, encoding: 'UTF-8')
      # Store original content (with requires) for dependency resolution
      original_content = content
      # Strip metadata fields from YAML frontmatter for output
      content = strip_metadata_from_frontmatter(content, keep_frontmatter:)
      is_command = agent == 'claude' && (file_path.include?('/commands/') || source[:path].include?('/commands/'))
      is_skill = agent == 'claude' && source[:path].include?('/skills/')

      # Count tokens for the content
      tokens = count_tokens(content)
      formatted_tokens = tokens.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      print_file_progress_result(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:)
      {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
    end

    def strip_metadata_from_frontmatter(content, keep_frontmatter: false)
      Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)
    end

    def count_tokens(text)
      # Use cl100k_base encoding (used by GPT-4, Claude, etc.)
      encoder = Tiktoken.get_encoding('cl100k_base')
      # Ensure text is UTF-8 encoded to avoid encoding errors
      utf8_text = text.encode('UTF-8', invalid: :replace, replace: '?', undef: :replace)
      encoder.encode(utf8_text).length
    end

    def print_file_progress_result(formatted_tokens, from_requires:, is_command:, is_skill:)
      return unless verbose?

      label = if is_skill then 'skill'
              elsif is_command then 'command'
              elsif from_requires then 'from requires'
              end
      suffix = label ? "(#{label}, #{formatted_tokens} tokens)" : "(#{formatted_tokens} tokens)"
      puts " ✅ #{suffix}"
    end

    def display_prefetched_remote(source, index, total, agent, content, keep_frontmatter: false)
      # Extract domain and full path for display
      if source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        file_path = Regexp.last_match(3)
        display_name = "#{owner}/#{repo}/#{file_path}"
        icon = source[:from_requires] ? '📚' : '🐙'
      else
        display_name = source[:path]
        icon = source[:from_requires] ? '📚' : '📦'
      end

      prefix = source[:from_requires] ? 'Required' : 'Processing'
      print "  [#{index + 1}/#{total}] #{icon} #{prefix}: #{display_name}..." if verbose?

      # Store original content for requires resolution
      original_content = content
      # Strip metadata fields from YAML frontmatter
      content = strip_metadata_from_frontmatter(content, keep_frontmatter:)

      # Count tokens in the content
      tokens = count_tokens(content)
      formatted_tokens = tokens.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      # Check if remote file is a command file or skill file
      is_command = agent == 'claude' && source[:path].include?('/commands/')
      is_skill = agent == 'claude' && source[:path].include?('/skills/')
      print_file_progress_result(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:)

      {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
    end

    def process_remote_file_with_progress(source, index, total, agent, keep_frontmatter: false)
      display_info = parse_remote_display_info(source[:path], from_requires: source[:from_requires])
      prefix = source[:from_requires] ? 'Required' : 'Fetching'
      print "  [#{index + 1}/#{total}] #{display_info[:icon]} #{prefix}: #{display_info[:display_name]}..." if verbose?
      content = fetch_remote_content(source[:path])

      unless content
        verbose? ? puts(' ❌ failed') : warn("  ⚠️  Failed to fetch: #{source[:path]}")
        return nil
      end

      # Store original content for requires resolution
      original_content = content
      # Strip metadata fields from YAML frontmatter
      content = strip_metadata_from_frontmatter(content, keep_frontmatter:)

      # Count tokens in the content
      tokens = count_tokens(content)
      formatted_tokens = tokens.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')

      # Check if remote file is a command file or skill file
      is_command = agent == 'claude' && source[:path].include?('/commands/')
      is_skill = agent == 'claude' && source[:path].include?('/skills/')
      print_file_progress_result(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:)
      {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
    end

    def parse_remote_display_info(path, from_requires: false)
      if path =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
        display_name = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}/#{Regexp.last_match(3)}"
        icon = from_requires ? '📚' : '🐙'
      elsif path =~ %r{https?://([^/]+)/(.+)}
        display_name = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}"
        icon = from_requires ? '📚' : '🌐'
      else
        display_name = path
        icon = from_requires ? '📚' : '🌐'
      end
      {display_name:, icon:}
    end

    def fetch_remote_content(url)
      Services::GitHubClient.fetch_remote_content(url)
    end

    def resolve_requires_for_source(source, content, processed_files, all_sources)
      Services::DependencyResolver.resolve_requires_for_source(
        source, content, processed_files, all_sources,
        find_rule_file: method(:find_rule_file), gem_root:
      )
    end

    def resolve_skills_for_source(source, content, processed_files)
      Services::DependencyResolver.resolve_skills_for_source(
        source, content, processed_files,
        find_rule_file: method(:find_rule_file), gem_root:
      )
    end

    def copy_bin_files(bin_files)
      Services::ScriptManager.copy_bin_files(bin_files)
    end

    def collect_dispatches_from_sources(local_sources)
      dispatches = {}

      local_sources.each do |source|
        content = source[:original_content] || source[:content]
        next unless content

        frontmatter, = parse_frontmatter(content)
        next unless frontmatter.is_a?(Hash) && frontmatter['dispatches'].is_a?(Array)

        filename = File.basename(source[:path])
        dispatches[filename] = frontmatter['dispatches']
      end

      dispatches
    end

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

    def get_command_relative_path(file_path, omit_prefix = nil)
      Services::ScriptManager.get_command_relative_path(file_path, omit_prefix)
    end

    def convert_to_raw_url(url)
      Services::GitHubClient.convert_to_raw_url(url)
    end

    def resolve_required_path(source, required_path)
      Services::DependencyResolver.resolve_required_path(
        source, required_path,
        find_rule_file: method(:find_rule_file), gem_root:
      )
    end

    def resolve_local_require(source_path, required_path)
      Services::DependencyResolver.resolve_local_require(
        source_path, required_path,
        find_rule_file: method(:find_rule_file), gem_root:
      )
    end

    def resolve_remote_require(source_url, required_path)
      Services::DependencyResolver.resolve_remote_require(source_url, required_path)
    end

    def normalize_path(path)
      Services::DependencyResolver.normalize_path(path)
    end

    def calculate_bin_target(relative_path)
      if (match = relative_path.match(%r{bin/(.+\.sh)$}))
        match[1]
      else
        File.basename(relative_path)
      end
    end

    def copy_taskmaster_config
      source_config = File.expand_path('~/.config/ruly/taskmaster/config.json')
      target_dir = '.taskmaster'
      target_config = File.join(target_dir, 'config.json')

      unless File.exist?(source_config)
        puts "⚠️  Warning: #{source_config} not found"
        return
      end

      if options[:dry_run]
        puts "\nWould copy TaskMaster config:"
        puts "  → From: #{source_config}"
        puts "  → To: #{target_config}"
        return
      end

      # Create target directory if it doesn't exist
      FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)

      # Copy the config file
      FileUtils.cp(source_config, target_config)
      puts "🎯 Copied TaskMaster config to #{target_config}"
    rescue StandardError => e
      puts "⚠️  Warning: Could not copy TaskMaster config: #{e.message}"
    end

    def write_shell_gpt_json(output_file, local_sources)
      require 'json'

      # Extract role name from filename (remove .json extension)
      role_name = File.basename(output_file, '.json')

      # Combine all content into description
      description_parts = local_sources.map do |source|
        # Duplicate string to avoid frozen string error
        content = source[:content].dup.force_encoding('UTF-8')
        # Replace invalid UTF-8 sequences
        content.scrub('?')
      end

      # Join all parts into single description string
      description = description_parts.join("\n\n")

      # Create role JSON structure
      role_json = {
        'description' => description,
        'name' => role_name
      }

      # Write JSON with proper escaping (JSON.pretty_generate handles all escaping)
      File.write(output_file, JSON.pretty_generate(role_json))
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

    def extract_headers_from_content(content, source_path = nil)
      headers = []
      content = content.force_encoding('UTF-8')

      # Generate file prefix from source path
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

    def generate_file_prefix(source_path)
      # Convert file path to a URL-safe prefix
      # Examples:
      #   "ruby/common.md" -> "ruby-common-md"
      #   "https://github.com/user/repo/blob/main/rules/test.md" -> "rules-test-md"

      # Extract just the path portion if it's a URL
      path = if source_path.start_with?('http')
               # Extract path after blob/branch/ or tree/branch/ for GitHub URLs
               if source_path =~ %r{/(?:blob|tree)/[^/]+/(.+)$}
                 Regexp.last_match(1)
               else
                 # Fallback: use last part of URL
                 source_path.split('/').last
               end
             else
               source_path
             end

      # Sanitize the path to create a valid anchor prefix
      path.downcase
          .gsub(/\.md$/, '') # Remove .md extension
          .gsub(%r{[^\w/-]}, '') # Keep only word chars, slashes, and hyphens
          .gsub(%r{/+}, '-') # Replace slashes with hyphens
          .gsub(/^-|-$/, '') # Remove leading/trailing hyphens
    end

    def generate_anchor(text, prefix = nil)
      anchor = text.downcase
                   .gsub(/[^\w\s-]/, '')
                   .gsub(/\s+/, '-').squeeze('-')
                   .gsub(/^-|-$/, '')

      prefix ? "#{prefix}-#{anchor}" : anchor
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

    # Rewrite absolute script paths to relative .claude/scripts/ paths
    # @param content [String] The content to rewrite
    # @param script_mappings [Hash] Map of absolute path => relative filename
    # @return [String] Content with rewritten paths
    def rewrite_script_references(content, script_mappings)
      result = content.dup

      script_mappings.each do |abs_path, relative_path|
        # Replace absolute path with .claude/scripts/filename
        result.gsub!(abs_path, ".claude/scripts/#{relative_path}")
      end

      result
    end

    def add_anchor_ids_to_content(content, source_path)
      # Add HTML anchor tags before headers to make them linkable
      # This ensures the TOC links work correctly

      file_prefix = generate_file_prefix(source_path)
      modified_content = []

      content.force_encoding('UTF-8').each_line do |line|
        if line =~ /^(#+)\s+(.+)$/
          level = Regexp.last_match(1)
          text = Regexp.last_match(2).strip
          anchor = generate_anchor(text, file_prefix)

          # Add the header with an anchor that matches what's in the TOC
          # Using HTML comment style anchor that works in markdown
          modified_content << "<a id=\"#{anchor}\"></a>"
          modified_content << ''
          modified_content << "#{level} #{text}"
        else
          modified_content << line.chomp
        end
      end

      modified_content.join("\n")
    end

    def generate_ignore_patterns(output_file, agent, command_files)
      patterns = []

      # Add main output file
      patterns << output_file

      # Add command files directory for Claude
      patterns << '.claude/commands/' if agent == 'claude' && !command_files.empty?

      patterns
    end

    def update_gitignore(patterns)
      gitignore_file = '.gitignore'

      # Read existing content or start fresh
      existing_content = File.exist?(gitignore_file) ? File.read(gitignore_file, encoding: 'UTF-8') : ''
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
      existing_content = File.exist?(exclude_file) ? File.read(exclude_file, encoding: 'UTF-8') : ''
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

    def save_skill_files(skill_files)
      Services::ScriptManager.save_skill_files(
        skill_files,
        find_rule_file: method(:find_rule_file),
        parse_frontmatter: method(:parse_frontmatter),
        strip_metadata: method(:strip_metadata_from_frontmatter)
      )
    end

    def collect_mcp_servers_from_sources(local_sources)
      servers = []

      local_sources.each do |source|
        content = source[:original_content] || source[:content]
        next unless content

        frontmatter, = parse_frontmatter(content)
        next unless frontmatter.is_a?(Hash) && frontmatter['mcp_servers'].is_a?(Array)

        servers.concat(frontmatter['mcp_servers'])
      end

      servers.uniq
    end

    def collect_all_mcp_servers(recipe_config, visited = Set.new)
      servers = Array(recipe_config['mcp_servers']).dup

      return servers unless recipe_config['subagents'].is_a?(Array)

      recipes = load_all_recipes

      recipe_config['subagents'].each do |subagent|
        recipe_name = subagent['recipe']
        next unless recipe_name
        next if visited.include?(recipe_name)

        visited.add(recipe_name)
        subagent_recipe = recipes[recipe_name]
        next unless subagent_recipe

        servers.concat(collect_all_mcp_servers(subagent_recipe, visited))
      end

      servers.uniq
    end

    def update_mcp_settings(recipe_config = nil, agent = 'claude') # rubocop:disable Metrics/MethodLength
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
        # Always create .mcp.json for Claude, even if empty
        mcp_settings_file = '.mcp.json'

        # Load existing settings or create new
        existing_settings = if File.exist?(mcp_settings_file)
                              JSON.parse(File.read(mcp_settings_file))
                            else
                              {}
                            end

        # Update or create mcpServers section (can be empty object)
        existing_settings['mcpServers'] = mcp_servers

        # Write back to .mcp.json file
        File.write(mcp_settings_file, JSON.pretty_generate(existing_settings))

        if mcp_servers.empty?
          puts '🔌 Created empty .mcp.json (no MCP servers configured)'
        else
          puts '🔌 Updated .mcp.json with MCP servers'
        end
      else
        # Only create YAML file for other agents if there are servers
        return if mcp_servers.empty?

        # Output YAML for other agents
        mcp_settings_file = '.mcp.yml'

        # Load existing settings or create new
        existing_settings = if File.exist?(mcp_settings_file)
                              YAML.safe_load_file(mcp_settings_file, aliases: true) || {}
                            else
                              {}
                            end

        # Update or create mcpServers section
        existing_settings['mcpServers'] = mcp_servers

        # Write back to .mcp.yml file
        File.write(mcp_settings_file, existing_settings.to_yaml)
        puts '🔌 Updated .mcp.yml with MCP servers'
      end
    rescue StandardError => e
      puts "⚠️  Warning: Could not update MCP settings: #{e.message}"
    end

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
          puts "⚠️  Warning: MCP server '#{name}' not found in ~/.config/ruly/mcp.json"
        end
      end

      selected_servers
    rescue JSON::ParserError => e
      puts "⚠️  Warning: Could not parse MCP configuration file: #{e.message}"
      nil
    rescue StandardError => e
      puts "⚠️  Warning: Error loading MCP servers: #{e.message}"
      nil
    end

    def process_subagents(recipe_config, parent_recipe_name, top_level: true, visited: Set.new)
      return unless recipe_config['subagents'].is_a?(Array)

      puts "\n🤖 Processing subagents..." if top_level

      # Ensure .claude/agents directory exists
      FileUtils.mkdir_p('.claude/agents')

      recipe_config['subagents'].each do |subagent|
        process_single_subagent(subagent, parent_recipe_name, recipe_config, visited)
      end

      puts "✅ Generated #{visited.size} subagent(s)" if top_level
    rescue Ruly::Error
      raise # Re-raise validation errors (e.g., nested subagents)
    rescue StandardError => e
      puts "⚠️  Warning: Could not process subagents: #{e.message}"
    end

    def process_single_subagent(subagent, parent_recipe_name, recipe_config, visited)
      agent_name = subagent['name']
      recipe_name = subagent['recipe']

      return unless agent_name && recipe_name
      return if visited.include?(recipe_name)

      visited.add(recipe_name)

      if verbose?
        puts "  → Generating #{agent_name}.md from '#{recipe_name}' recipe"
      else
        puts "  → #{agent_name}"
      end

      # Load the referenced recipe
      subagent_recipe = load_all_recipes[recipe_name]

      unless subagent_recipe
        puts "    ⚠️  Warning: Recipe '#{recipe_name}' not found, skipping"
        return
      end

      # Reject subagent recipes that have their own subagents (nested subagents)
      validate_no_nested_subagents!(subagent_recipe, agent_name, recipe_name)

      # Reject subagent recipes that contain files dispatching other subagents
      validate_no_subagent_dispatches!(subagent_recipe, agent_name, recipe_name)

      # Generate the agent file
      generate_agent_file(agent_name, recipe_name, subagent_recipe, parent_recipe_name,
                          parent_recipe_config: recipe_config, subagent_config: subagent)
    end

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

    def validate_no_subagent_dispatches!(subagent_recipe, agent_name, recipe_name)
      return unless subagent_recipe.is_a?(Hash)

      # Load and process sources to check for dispatches
      sources, = load_recipe_sources(recipe_name)
      dispatching_files = []

      sources.each do |source|
        next unless source[:type] == 'local'

        file_path = find_rule_file(source[:path])
        next unless file_path

        content = File.read(file_path, encoding: 'UTF-8')
        frontmatter, = parse_frontmatter(content)
        next unless frontmatter.is_a?(Hash) && frontmatter['dispatches'].is_a?(Array) && frontmatter['dispatches'].any?

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

    def generate_agent_file(agent_name, recipe_name, recipe_config, parent_recipe_name, parent_recipe_config: {},
                            subagent_config: {})
      agent_file = ".claude/agents/#{agent_name}.md"
      local_sources, command_files, skill_files = load_agent_sources(recipe_name, recipe_config)

      # Collect MCP servers from both recipe config and rule-file frontmatter
      mcp_servers = collect_agent_mcp_servers(recipe_config, local_sources)

      # Extract skill names and save skill files
      skill_names = extract_skill_names(skill_files)
      save_skill_files(skill_files) unless skill_files.empty?

      context = build_agent_context(agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
                                    mcp_servers:, parent_recipe_config:, skill_names:, subagent_config:)
      write_agent_file(agent_file, context)
      save_subagent_commands(command_files, agent_name, recipe_config) unless command_files.empty?
    rescue StandardError => e
      puts "    ⚠️  Warning: Could not generate agent file '#{agent_name}': #{e.message}"
    end

    def load_agent_sources(recipe_name, recipe_config)
      sources, = load_recipe_sources(recipe_name)
      local_sources, command_files, _bin_files, skill_files = process_sources_for_squash(sources, 'claude',
                                                                                         recipe_config, {})
      [local_sources, command_files, skill_files]
    end

    def collect_agent_mcp_servers(recipe_config, local_sources)
      servers = []
      servers.concat(recipe_config['mcp_servers']) if recipe_config['mcp_servers'].is_a?(Array)
      servers.concat(collect_mcp_servers_from_sources(local_sources))
      servers.uniq
    end

    def extract_skill_names(skill_files)
      skill_files.map { |file| file[:path].split('/skills/').last.sub(/\.md$/, '') }
    end

    def build_agent_context(agent_name, recipe_name, recipe_config, parent_recipe_name, local_sources,
                            mcp_servers: [], parent_recipe_config: {}, skill_names: [], subagent_config: {})
      {
        agent_name:,
        description: recipe_config['description'] || "Subagent for #{recipe_name}",
        local_sources:,
        mcp_servers:,
        model: resolve_agent_model(subagent_config, parent_recipe_config),
        parent_recipe_name:,
        recipe_config:,
        recipe_name:,
        skill_names:,
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }
    end

    def resolve_agent_model(subagent_config, parent_recipe_config)
      # Priority: subagent model > parent recipe model > 'inherit'
      return subagent_config['model'] if subagent_config['model']
      return parent_recipe_config['model'] if parent_recipe_config.is_a?(Hash) && parent_recipe_config['model']

      'inherit'
    end

    def write_agent_file(agent_file, context)
      File.open(agent_file, 'w') do |output|
        write_agent_frontmatter(output, context)
        write_agent_content(output, context)
        write_agent_footer(output, context[:timestamp], context[:recipe_name])
      end
    end

    def write_agent_frontmatter(output, context)
      skills_line = if context[:skill_names]&.any?
                      "\nskills: [#{context[:skill_names].join(', ')}]"
                    else
                      ''
                    end
      mcp_line = if context[:mcp_servers]&.any?
                   "\nmcpServers: [#{context[:mcp_servers].join(', ')}]"
                 else
                   ''
                 end
      output.puts <<~YAML
        ---
        name: #{context[:agent_name]}
        description: #{context[:description]}
        tools: Bash, Read, Write, Edit, Glob, Grep
        model: #{context[:model]}#{skills_line}#{mcp_line}
        permissionMode: bypassPermissions
        # Auto-generated from recipe: #{context[:recipe_name]}
        # Do not edit manually - regenerate using 'ruly squash #{context[:parent_recipe_name]}'
        ---

      YAML
    end

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
    end

    def write_agent_footer(output, timestamp, recipe_name)
      output.puts '---'
      output.puts "*Last generated: #{timestamp}*"
      output.puts "*Source recipe: #{recipe_name}*"
    end

    def save_subagent_commands(command_files, agent_name, recipe_config = nil)
      return if command_files.empty?

      # Save commands to .claude/commands/{agent_name}/
      commands_dir = ".claude/commands/#{agent_name}"
      FileUtils.mkdir_p(commands_dir)

      omit_prefix = recipe_config && recipe_config['omit_command_prefix'] ? recipe_config['omit_command_prefix'] : nil

      command_files.each do |file|
        next unless file.is_a?(Hash)

        # Get the command relative path (without omit_prefix if specified)
        relative_path = get_command_relative_path(file[:path], omit_prefix)

        # Save to .claude/commands/{agent_name}/{relative_path}
        target_file = File.join(commands_dir, relative_path)
        target_dir = File.dirname(target_file)
        FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

        File.write(target_file, file[:content])
      end

      puts "    📁 Saved #{command_files.size} command file(s) to .claude/commands/#{agent_name}/" if verbose?
    rescue StandardError => e
      puts "    ⚠️  Warning: Could not save commands for '#{agent_name}': #{e.message}"
    end

    def copy_scripts(script_files, destination_dir = nil)
      Services::ScriptManager.copy_scripts(script_files, destination_dir)
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

    def user_recipes_file
      # Use user's home config directory for recipes
      config_dir = File.join(Dir.home, '.config', 'ruly')
      FileUtils.mkdir_p(config_dir)
      File.join(config_dir, 'recipes.yml')
    end

    def introspect_github_source(url, all_github_sources)
      # Parse GitHub URL
      # Format: https://github.com/owner/repo/tree/branch/path
      if url =~ %r{github\.com/([^/]+)/([^/]+)/tree/([^/]+)(?:/(.+))?}
        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        branch = Regexp.last_match(3)
        path = Regexp.last_match(4) || ''

        puts "  🌐 github.com/#{owner}/#{repo}..."

        # Fetch all markdown files from this GitHub location
        github_files = fetch_github_markdown_files(owner, repo, branch, path)

        if github_files.any?
          puts "     Found #{github_files.length} markdown files"

          # Check if we already have a source for this repo
          existing_source = all_github_sources.find { |s| s[:github] == "#{owner}/#{repo}" && s[:branch] == branch }

          if existing_source
            # Add to existing source
            existing_source[:rules].concat(github_files).uniq!.sort!
          else
            # Create new source entry
            all_github_sources << {
              branch:,
              github: "#{owner}/#{repo}",
              rules: github_files.sort
            }
          end
        else
          puts '     ⚠️ No markdown files found or failed to access'
        end
      else
        puts "  ⚠️  Invalid GitHub URL format: #{url}"
      end
    end

    def fetch_github_markdown_files(owner, repo, branch, path)
      Services::GitHubClient.fetch_github_markdown_files(owner, repo, branch, path)
    end

    def introspect_local_source(path, all_files, use_relative)
      expanded_path = File.expand_path(path)

      unless File.directory?(expanded_path)
        puts "  ⚠️  Skipping #{path} - not a directory"
        return
      end

      puts "  📁 #{path}..."
      found_count = 0

      Find.find(expanded_path) do |file_path|
        next unless file_path.end_with?('.md', '.mdc')

        # Store as absolute path unless relative flag is set
        stored_path = use_relative ? file_path.sub("#{Dir.pwd}/", '') : file_path
        all_files << stored_path
        found_count += 1
      end

      puts "     Found #{found_count} markdown files"
    end

    def build_introspected_recipe(local_files, github_sources, original_sources, description)
      recipe = {}

      # Add description
      if description
        recipe['description'] = description
      else
        # Auto-generate description
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

      # Add local files if any
      recipe['files'] = local_files.sort if local_files.any?

      # Add GitHub sources if any
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

    def save_introspected_recipe(recipe_name, recipe_data, output_file)
      # Load existing recipes or create new structure
      existing_config = if File.exist?(output_file)
                          YAML.safe_load_file(output_file, aliases: true) || {}
                        else
                          {}
                        end

      existing_config['recipes'] ||= {}

      # NOTE: Key preservation is now done in the introspect method before calling this
      # so it works for both dry-run and actual save modes

      # Update recipe
      existing_config['recipes'][recipe_name] = recipe_data

      # Ensure parent directory exists
      FileUtils.mkdir_p(File.dirname(output_file))

      # Write updated config with custom formatting for file paths
      yaml_content = format_yaml_without_quotes(existing_config)
      File.write(output_file, yaml_content)
    end

    def format_yaml_without_quotes(data)
      # Convert to standard YAML first
      yaml_str = data.to_yaml

      # Remove quotes from file paths (paths that start with / or ~ or contain .md)
      yaml_str.gsub(%r{(['"])(/[^'"]*|~[^'"]*|[^'"]*\.md[c]?)\1}) do |match|
        # Extract the path without quotes
        path = match[1..-2] # Remove first and last character (the quotes)
        # Return the path without quotes if it's a valid file path
        if path.match?(%r{^[/~]}) || path.match?(/\.md[c]?$/)
          path
        else
          match # Keep the quotes for non-file paths
        end
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

    # Loads MCP server definitions from ~/.config/ruly/mcp.json.
    # Returns the parsed hash, or nil if the file is missing.
    def load_mcp_server_definitions
      mcp_config_file = File.expand_path('~/.config/ruly/mcp.json')

      unless File.exist?(mcp_config_file)
        puts '❌ Error: ~/.config/ruly/mcp.json not found'
        puts '   Create this file with your MCP server definitions.'
        return nil
      end

      JSON.parse(File.read(mcp_config_file))
    end

    # Collects MCP server names from the recipe specified by --recipe option.
    # Returns an array of server names, or an empty array if no recipe specified.
    # Returns nil if the recipe was specified but not found (signals early exit).
    def collect_recipe_mcp_servers
      return [] unless options[:recipe]

      recipes = load_all_recipes
      recipe_config = recipes[options[:recipe]]

      if recipe_config.nil?
        puts "❌ Error: Recipe '#{options[:recipe]}' not found"
        return nil
      end

      recipe_servers = recipe_config['mcp_servers'] || []
      puts "⚠️  Warning: Recipe '#{options[:recipe]}' has no MCP servers defined" if recipe_servers.empty?
      recipe_servers
    end

    # Builds a hash of selected server configurations from the requested server names.
    # Filters metadata fields (underscore-prefixed) and ensures stdio type is set.
    def build_selected_servers(all_servers, requested_names)
      selected_servers = {}
      requested_names.each do |name|
        if all_servers[name]
          server_config = all_servers[name].dup
          server_config.delete_if { |key, _| key.start_with?('_') } if server_config.is_a?(Hash)
          server_config['type'] = 'stdio' if server_config['command'] && !server_config['type']
          selected_servers[name] = server_config
        else
          puts "⚠️  Warning: MCP server '#{name}' not found in ~/.config/ruly/mcp.json"
        end
      end
      selected_servers
    end

    # Writes selected servers to .mcp.json, optionally merging with existing file in append mode.
    def write_mcp_json(selected_servers)
      existing_settings = {}
      existing_settings = JSON.parse(File.read('.mcp.json')) if options[:append] && File.exist?('.mcp.json')

      existing_servers = existing_settings['mcpServers'] || {}
      merged_servers = existing_servers.merge(selected_servers)

      output = {'mcpServers' => merged_servers}
      File.write('.mcp.json', JSON.pretty_generate(output))

      if selected_servers.empty?
        puts '⚠️  No valid servers found, created empty .mcp.json'
      elsif options[:append]
        puts "🔌 Appended #{selected_servers.size} server(s) to .mcp.json"
      else
        puts "🔌 Created .mcp.json with #{selected_servers.size} server(s)"
      end
    end

    def display_stats_result(result)
      if result[:success]
        data = result[:data]
        formatted_tokens = data[:total_tokens].to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        puts "✅ Generated #{data[:output_file]}"
        puts "   #{data[:file_count]} files, #{formatted_tokens} tokens total"
        if data[:orphaned_count].positive?
          puts "   ⚠️  #{data[:orphaned_count]} orphaned files (not used by any recipe)"
        end
      else
        puts "❌ Error: #{result[:error]}"
        exit 1
      end
    end

    # Detect recipe type based on its structure
    # @param recipe_value [Hash, Array, Object] The recipe value from recipes.yml
    # @return [Symbol] :agent for Array recipes, :standard for Hash recipes, :invalid otherwise
    def recipe_type(recipe_value)
      if recipe_value.is_a?(Array)
        :agent # Array = agent file (subagent format)
      elsif recipe_value.is_a?(Hash)
        :standard # Hash = traditional recipe
      else
        :invalid
      end
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
  end # rubocop:enable Metrics/ClassLength
end
