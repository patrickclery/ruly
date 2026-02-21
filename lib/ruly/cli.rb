# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'shellwords'
require 'thor'
require 'yaml'
require_relative 'version'
require_relative 'operations'
require_relative 'services'

module Ruly
  # Command Line Interface for Ruly gem
  class CLI < Thor
    MERGE_SKIP_KEYS = %w[files sources].freeze

    def self.exit_on_failure?
      true
    end

    desc 'squash [RECIPE]', 'Combine all markdown files into one CLAUDE.local.md (recipe optional)'
    option :output_file, aliases: '-o', default: 'CLAUDE.local.md', desc: 'Output file path', type: :string
    option :agent, aliases: '-a', default: 'claude', desc: 'Target agent (claude, cursor, etc.)', type: :string
    option :cache, default: false, desc: 'Enable caching for this recipe', type: :boolean
    option :clean, aliases: '-c', default: false, desc: 'Clean existing files before squashing', type: :boolean
    option :deepclean, default: false, desc: 'Deep clean all Claude artifacts before squashing', type: :boolean
    option :dry_run, aliases: '-d', default: false, type: :boolean
    option :git_ignore, aliases: '-i', default: false, desc: 'Add generated files to .gitignore', type: :boolean
    option :git_exclude, aliases: '-I', default: false, type: :boolean
    option :toc, aliases: '-t', default: false, type: :boolean
    option :essential, aliases: '-e', default: false, type: :boolean
    option :taskmaster_config, aliases: '-T', default: false, type: :boolean
    option :keep_taskmaster, default: false, type: :boolean
    option :front_matter, default: false, type: :boolean
    option :home_override, default: false, type: :boolean
    option :verbose, aliases: '-v', default: false, type: :boolean
    def squash(recipe_name = nil) # rubocop:disable Metrics/MethodLength
      guard_home_directory!
      invoke_clean_if_requested(recipe_name)
      agent = normalize_agent(options[:agent])

      sources, recipe_config = load_sources(recipe_name)
      output_file = if recipe_name
                      Services::SquashHelpers.determine_output_file(recipe_name, recipe_config,
                                                                    options)
                    else
                      options[:output_file]
                    end
      script_files = Services::ScriptManager.collect_scripts_from_sources(sources,
                                                                          find_rule_file: method(:find_rule_file))
      script_mappings = Services::ScriptManager.build_script_mappings(script_files)
      Services::ShellCommandChecker.check_and_warn(sources, find_rule_file: method(:find_rule_file))

      cache_used = recipe_name && options[:cache] && !options[:dry_run] &&
                   cached?(recipe_name, agent, output_file, recipe_config)

      unless cache_used
        prepare_output(output_file) unless options[:dry_run]
        sources = filter_essential(sources) if options[:essential] && !options[:dry_run]
        local_sources, command_files, bin_files, skill_files = process_squash_sources(sources, agent)
        validate_squash_dispatches(local_sources, recipe_config, recipe_name)

        if options[:dry_run]
          Services::Display.squash_dry_run(local_sources, command_files, bin_files, skill_files, script_files,
                                           output_file, agent, recipe_name, recipe_config, options)
          return
        end

        write_squash_output(output_file, agent, local_sources, command_files, script_mappings)
        post_squash(output_file, agent, recipe_name, recipe_config, local_sources, command_files, skill_files,
                    script_files)
      end

      Services::Display.squash_summary(agent, recipe_name, recipe_config, output_file, cache_used,
                                       cache_used ? nil : local_sources, cache_used ? nil : command_files,
                                       cache_used ? nil : skill_files)
    end

    desc 'import RECIPE', 'Import a recipe and copy its scripts to ~/.claude/scripts/'
    option :dry_run, aliases: '-d', default: false, type: :boolean
    def import(recipe_name)
      sources, = load_sources(recipe_name)
      puts "\n🔄 Processing recipe: #{recipe_name}"
      script_files = Services::ScriptManager.collect_scripts_from_sources(sources,
                                                                          find_rule_file: method(:find_rule_file))

      if options[:dry_run]
        Services::Display.import_dry_run(script_files, recipe_name)
      elsif script_files[:local].any? || script_files[:remote].any?
        Services::ScriptManager.copy_scripts(script_files)
        puts "\n✨ Recipe imported successfully"
      else
        puts "No scripts found in recipe '#{recipe_name}'"
      end
    end

    desc 'clean [RECIPE]', 'Remove generated files (recipe optional, overrides metadata)'
    option :output_file, aliases: '-o', type: :string
    option :dry_run, aliases: '-d', default: false, type: :boolean
    option :agent, aliases: '-a', default: 'claude', type: :string
    option :deepclean, default: false, type: :boolean
    option :taskmaster_config, aliases: '-T', default: false, type: :boolean
    def clean(_recipe_name = nil)
      agent = normalize_agent(options[:agent] || 'claude')
      files = collect_files_to_clean(agent)

      if files.empty? then puts '✨ Already clean - no files to remove'
      elsif options[:dry_run]
        puts "\n🔍 Dry run mode - no files will be deleted\n\nWould remove:"
        files.each { |f| puts "   - #{f}" }
      else
        files.each { |f| f.end_with?('/') ? FileUtils.rm_rf(f.chomp('/')) : FileUtils.rm_f(f) }
        puts '🧹 Cleaned up files:'
        files.each { |f| puts "   - #{f}" }
      end
    end

    desc 'list-recipes', 'List all available recipes'
    def list_recipes
      recipes = Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:)
      puts "\n📚 Available Recipes:\n\n#{'=' * 80}"
      recipes.each { |name, config| Services::Display.recipe_listing(name, config) }
      puts
    end

    desc 'introspect RECIPE SOURCE...', 'Scan directories or GitHub repos for markdown files and create/update recipe'
    option :description, aliases: '-d', type: :string
    option :output, aliases: '-o', default: nil, type: :string
    option :dry_run, default: false, type: :boolean
    option :relative, default: false, type: :boolean
    def introspect(recipe_name, *sources)
      abort('❌ At least one source directory or GitHub URL is required') if sources.empty?

      output_file = options[:output] || Services::RecipeLoader.user_recipes_file
      puts "\n🔍 Introspecting #{sources.length} source#{'s' if sources.length > 1}..."

      all_local_files, all_github_sources = [], []
      sources.each do |source|
        if source.start_with?('http') && source.include?('github.com')
          Services::RecipeIntrospector.introspect_github_source(source, all_github_sources)
        else
          Services::RecipeIntrospector.introspect_local_source(source, all_local_files, options[:relative])
        end
      end

      introspected = Services::RecipeIntrospector.build_introspected_recipe(
        all_local_files, all_github_sources, sources, options[:description]
      )
      recipe_data = merge_with_existing_recipe(recipe_name, introspected, output_file)

      if options[:dry_run]
        puts "\n🔍 Dry run mode - no files will be modified\n\n📝 Would update recipe '#{recipe_name}' in #{output_file}:"
        puts recipe_data.to_yaml
      else
        Services::RecipeIntrospector.save_introspected_recipe(recipe_name, recipe_data, output_file)
        Services::Display.introspect_summary(recipe_name, output_file, all_local_files, all_github_sources)
      end
    end

    no_commands do
      def build_recipe_file_tree(files) = Services::RecipeIntrospector.build_recipe_file_tree(files)
      def display_recipe_tree(tree, prefix = '') = Services::RecipeIntrospector.display_recipe_tree(tree, prefix)
    end

    desc 'analyze [RECIPE]', 'Analyze token usage for a recipe or all recipes'
    option :plan, aliases: '-p', type: :string
    option :all, aliases: '-a', default: false, type: :boolean
    def analyze(recipe_name = nil)
      if !options[:all] && !recipe_name && puts('❌ Please specify a recipe or use -a for all recipes')
        raise Thor::Error,
              'Recipe required'
      end

      result = Operations::Analyzer.call(analyze_all: options[:all], gem_root:, plan_override: options[:plan],
                                         recipe_name:, recipes_file:)
      return if result[:success]

      puts "❌ Error: #{result[:error]}"
      exit 1
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

      FileUtils.mkdir_p(config_dir)
      File.write(config_file, Services::Display.starter_config_yaml)
      Services::Display.init_success(config_file)
    end

    desc 'version', 'Show version'
    def version = puts("Ruly v#{Ruly::VERSION}")

    desc 'mcp [SERVERS...]', 'Generate .mcp.json with specified MCP servers'
    option :append, aliases: '-a', default: false, type: :boolean
    option :recipe, aliases: '-r', type: :string
    def mcp(*servers)
      all_servers = Services::MCPManager.load_mcp_server_definitions
      return unless all_servers

      load_recipes = -> { Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:) }
      recipe_servers = Services::MCPManager.collect_recipe_mcp_servers(
        options[:recipe], load_all_recipes: load_recipes
      )
      return if recipe_servers.nil?

      all_requested = (servers + recipe_servers).uniq
      if all_requested.empty?
        puts '❌ Error: No servers specified'
        return puts('   Usage: ruly mcp server1 server2 ...  Or: ruly mcp -r <recipe>')
      end

      Services::MCPManager.write_mcp_json(Services::MCPManager.build_selected_servers(all_servers, all_requested),
                                          append: options[:append])
    rescue JSON::ParserError => e
      puts "❌ Error parsing JSON: #{e.message}"
    end

    desc 'stats [RECIPE]', 'Generate stats.md with file token counts sorted by size'
    option :output, aliases: '-o', default: 'stats.md', type: :string
    def stats(recipe_name = nil)
      sources = recipe_name ? load_sources(recipe_name).first : Services::SquashHelpers.collect_local_sources(rules_dir)
      resolved = sources.filter_map { |s| s[:type] == 'local' ? (p = find_rule_file(s[:path])) && s.merge(path: p) : s }
      puts "📊 Analyzing #{resolved.size} files..."
      out = options[:output]
      out = File.join(rules_dir, out) if out == 'stats.md'
      Operations::Analyzer.display_stats_result(Operations::Stats.call(output_file: out, recipes_file:, rules_dir:,
                                                                       sources: resolved))
    end

    private

    # --- Squash pipeline ---

    def guard_home_directory!
      return unless Dir.pwd == Dir.home && !options[:home_override]

      say_error "ERROR: Running 'ruly squash' in $HOME is dangerous and may delete ~/.claude/"
      say_error 'Use --home-override if you really want to do this.'
      exit 1
    end

    def invoke_clean_if_requested(recipe_name)
      return if options[:dry_run]

      if options[:deepclean]
        invoke :clean, [], {deepclean: true, taskmaster_config: options[:taskmaster_config]}
      elsif options[:clean]
        invoke :clean, [recipe_name], options.slice(:output_file, :agent, :taskmaster_config)
      end
    end

    def normalize_agent(agent)
      agent = 'shell_gpt' if agent == 'sgpt'
      agent = 'claude' if agent&.downcase&.gsub(/[^a-z]/, '') == 'claudecode'
      agent
    end

    def load_sources(recipe_name)
      if recipe_name
        Services::RecipeLoader.load_recipe_sources(
          recipe_name, gem_root:, recipes: load_all_recipes,
                       scan_files_for_recipe_tags: ->(name) { Services::SquashHelpers.scan_files_for_recipe_tags(name, rules_dir:) }
        )
      else
        [collect_local_sources, {}]
      end
    end

    # --- Core helpers ---

    def gem_root = @gem_root ||= ENV['RULY_HOME'] || File.expand_path('../..', __dir__)
    def load_all_recipes = Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:)

    def recipes_file = @recipes_file ||= Services::RecipeLoader.recipes_file_path(gem_root)
    def rules_dir = @rules_dir ||= File.join(gem_root, 'rules')
    def collect_local_sources = Services::SquashHelpers.collect_local_sources(rules_dir)

    def cached?(recipe_name, agent, output_file, _recipe_config)
      cache_file = File.join(cache_dir, agent, "#{recipe_name}.md")
      return false unless File.exist?(cache_file) && options[:cache]

      puts "\n💾 Using cached version for recipe '#{recipe_name}'"
      FileUtils.cp(cache_file, output_file)
      true
    end

    def cache_dir = @cache_dir ||= ENV['RULY_HOME'] ? File.expand_path('~/.cache/ruly') : File.join(gem_root, 'cache')

    def prepare_output(output_file)
      Services::ScriptManager.ensure_parent_directory(output_file)
      FileUtils.rm_f(output_file)
    end

    def filter_essential(sources)
      filtered = Services::SquashHelpers.filter_essential_sources(sources, find_rule_file: method(:find_rule_file))
      puts "📌 Essential mode: filtered to #{filtered.length} essential files"
      filtered
    end

    def process_squash_sources(sources, agent)
      Services::SourceProcessor.process_for_squash(
        sources, agent, dry_run: options[:dry_run], find_rule_file: method(:find_rule_file),
                        gem_root:, keep_frontmatter: options[:front_matter], verbose: verbose?
      )
    end

    def verbose? = options[:verbose] || ENV.fetch('DEBUG', nil)

    def validate_squash_dispatches(local_sources, recipe_config, recipe_name)
      return unless recipe_name && recipe_config.is_a?(Hash)

      dispatches = Services::SquashHelpers.collect_dispatches_from_sources(local_sources)
      Services::SquashHelpers.validate_dispatches_registered!(dispatches, recipe_config, recipe_name)
    end

    def write_squash_output(output_file, agent, local_sources, command_files, script_mappings)
      if agent == 'shell_gpt'
        Services::SquashHelpers.write_shell_gpt_json(output_file, local_sources)
      else
        write_markdown_output(output_file, agent, local_sources, command_files, script_mappings)
        if (options[:clean] || options[:deepclean]) && options[:keep_taskmaster] && agent != 'shell_gpt'
          append_taskmaster_import(output_file)
        end
      end
    end

    def write_markdown_output(output_file, agent, local_sources, command_files, script_mappings)
      File.open(output_file, 'w') do |output|
        if options[:toc]
          output.puts Services::TOCGenerator.generate_toc_content(local_sources, command_files, agent)
          output.puts
        end
        local_sources.each_with_index do |source, i|
          content = Services::TOCGenerator.rewrite_script_references(source[:content], script_mappings)
          content = Services::TOCGenerator.add_anchor_ids_to_content(content, source[:path]) if options[:toc]
          output.puts content
          output.puts if i < local_sources.length - 1
        end
      end
    end

    def append_taskmaster_import(output_file)
      File.open(output_file, 'a') do |f|
        f.puts "\n## Task Master AI Instructions"
        f.puts '**Import Task Master development workflow commands and guidelines, ' \
               'treat as if import is in the main CLAUDE.md file.**'
        f.puts '@./.taskmaster/CLAUDE.md'
      end
    end

    def post_squash(output_file, agent, recipe_name, recipe_config, # rubocop:disable Metrics/ParameterLists
                    local_sources, command_files, skill_files, script_files)
      update_git_ignores(output_file, agent, command_files)
      save_to_cache(output_file, recipe_name, agent) if recipe_name && options[:cache]
      if agent == 'claude' && !command_files.empty?
        Services::ScriptManager.save_command_files(command_files, recipe_config,
                                                   gem_root:)
      end
      save_skill_files(skill_files) if agent == 'claude' && !skill_files.empty?
      recipe_config = merge_mcp_servers(recipe_config, local_sources)
      Services::MCPManager.update_mcp_settings(recipe_config, agent)
      Services::SquashHelpers.copy_taskmaster_config(dry_run: false) if options[:taskmaster_config]
      process_subagents(recipe_config, recipe_name) if recipe_config.is_a?(Hash) && recipe_config['subagents']
      Services::ScriptManager.copy_scripts(script_files) if script_files[:local].any? || script_files[:remote].any?
      Ruly::Checks.run_all(local_sources, command_files)
    end

    def update_git_ignores(output_file, agent, command_files)
      return unless options[:git_ignore] || options[:git_exclude]

      patterns = Services::GitIgnoreManager.generate_ignore_patterns(output_file, agent, command_files)
      Services::GitIgnoreManager.update_gitignore(patterns) if options[:git_ignore]
      Services::GitIgnoreManager.update_git_exclude(patterns) if options[:git_exclude]
    end

    def save_to_cache(output_file, recipe_name, agent)
      dir = File.join(cache_dir, agent)
      FileUtils.mkdir_p(dir)
      FileUtils.cp(output_file, File.join(dir, "#{recipe_name}.md"))
    end

    def save_skill_files(skill_files)
      Services::ScriptManager.save_skill_files(skill_files, find_rule_file: method(:find_rule_file),
                                                            parse_frontmatter: Services::FrontmatterParser.method(:parse),
                                                            strip_metadata: Services::FrontmatterParser.method(:strip_metadata))
    end

    def merge_mcp_servers(recipe_config, local_sources)
      servers = Services::MCPManager.collect_mcp_servers_from_sources(local_sources)
      if servers.any?
        recipe_config = {} unless recipe_config.is_a?(Hash)
        existing = Array(recipe_config['mcp_servers'])
        new_servers = servers - existing
        recipe_config['mcp_servers'] = (existing + servers).uniq
        puts "🔌 Collected MCP servers from rule files: #{new_servers.join(', ')}" if new_servers.any?
      end
      if recipe_config.is_a?(Hash) && recipe_config['subagents']
        orig = Array(recipe_config['mcp_servers'])
        all = Services::MCPManager.collect_all_mcp_servers(recipe_config, load_all_recipes: load_recipes_proc)
        if all.any?
          propagated = all - orig
          recipe_config['mcp_servers'] = all
          puts "🔌 Propagated MCP servers from subagents: #{propagated.join(', ')}" if propagated.any?
        end
      end
      recipe_config
    end

    def load_recipes_proc = -> { load_all_recipes }

    def process_subagents(recipe_config, recipe_name)
      Services::SubagentProcessor.process_subagents(
        recipe_config, recipe_name,
        find_rule_file: method(:find_rule_file),
        load_all_recipes: load_recipes_proc,
        load_recipe_sources: ->(name) { load_sources(name) },
        parse_frontmatter: Services::FrontmatterParser.method(:parse),
        process_sources_for_squash: method(:process_sources_for_squash),
        save_skill_files: method(:save_skill_files), verbose: verbose?
      )
    end

    # --- Clean helpers ---

    def collect_files_to_clean(agent)
      files = []
      files << '.claude/' if Dir.exist?('.claude')
      if options[:deepclean]
        files << '.ruly/' if Dir.exist?('.ruly')
        %w[CLAUDE.local.md CLAUDE.md .mcp.json .mcp.yml].each { |f| files << f if File.exist?(f) }
      else
        out = options[:output_file] || "#{agent.upcase}.local.md"
        files << out if File.exist?(out)
        if File.exist?(agent == 'claude' ? '.mcp.json' : '.mcp.yml')
          files << (agent == 'claude' ? '.mcp.json' : '.mcp.yml')
        end
      end
      files << '.taskmaster/' if options[:taskmaster_config] && Dir.exist?('.taskmaster')
      files.uniq
    end

    # --- Introspect helpers ---

    def merge_with_existing_recipe(recipe_name, recipe_data, output_file)
      return recipe_data unless File.exist?(output_file)

      existing = (YAML.safe_load_file(output_file, aliases: true) || {}).dig('recipes', recipe_name)
      return recipe_data unless existing

      existing.each do |k, v|
        recipe_data[k] = v unless MERGE_SKIP_KEYS.include?(k) || (k == 'description' && recipe_data['description'])
      end
      recipe_data['description'] ||= existing['description']
      recipe_data
    end

    def find_rule_file(file) = Services::RecipeLoader.find_rule_file(file, gem_root:)

    def process_sources_for_squash(sources, agent, _recipe_config, _options)
      process_squash_sources(sources, agent)
    end

    # --- Backward-compatible delegators for specs ---
    # rubocop:disable Layout/LineLength
    def load_recipe_sources(name) = load_sources(name)
    def parse_frontmatter(content) = Services::FrontmatterParser.parse(content)
    def strip_metadata_from_frontmatter(content, keep_frontmatter: false) = Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)
    def convert_to_raw_url(url) = Services::GitHubClient.convert_to_raw_url(url)
    def fetch_remote_content(url) = Services::GitHubClient.fetch_remote_content(url)
    def normalize_github_url(url) = Services::GitHubClient.normalize_github_url(url)
    def normalize_path(path) = Services::DependencyResolver.normalize_path(path)
    def get_command_relative_path(path, omit_prefix = nil) = Services::ScriptManager.get_command_relative_path(path, omit_prefix)
    def save_command_files(files, config = nil) = Services::ScriptManager.save_command_files(files, config, gem_root:)
    def get_source_key(source) = Services::SourceProcessor.get_source_key(source, find_rule_file: method(:find_rule_file))
    def determine_output_file(name, val, opts) = Services::SquashHelpers.determine_output_file(name, val, opts)
    def scan_files_for_recipe_tags(name) = Services::SquashHelpers.scan_files_for_recipe_tags(name, rules_dir:)
    def filter_essential_sources(sources) = Services::SquashHelpers.filter_essential_sources(sources, find_rule_file: method(:find_rule_file))
    def collect_scripts_from_sources(sources) = Services::ScriptManager.collect_scripts_from_sources(sources, find_rule_file: method(:find_rule_file))
    def build_script_mappings(files) = Services::ScriptManager.build_script_mappings(files)
    def extract_scripts_from_frontmatter(content, path) = Services::ScriptManager.extract_scripts_from_frontmatter(content, path)
    def fetch_remote_scripts(scripts) = Services::ScriptManager.fetch_remote_scripts(scripts)
    def copy_scripts(files, dest = nil) = Services::ScriptManager.copy_scripts(files, dest)
    def rewrite_script_references(content, mappings) = Services::TOCGenerator.rewrite_script_references(content, mappings)
    def write_shell_gpt_json(file, sources) = Services::SquashHelpers.write_shell_gpt_json(file, sources)
    def collect_required_shell_commands(sources) = Services::ShellCommandChecker.collect_required_commands(sources, find_rule_file: method(:find_rule_file))
    def check_required_shell_commands(cmds) = Services::ShellCommandChecker.check_commands(cmds)
    def check_shell_command_available(cmd) = system("which #{cmd.shellescape} > /dev/null 2>&1")
    def extract_require_shell_commands_from_frontmatter(content) = Services::FrontmatterParser.extract_require_shell_commands(content)
    def update_mcp_settings(config = nil, agent = 'claude') = Services::MCPManager.update_mcp_settings(config, agent)
    def collect_all_mcp_servers(config, visited = Set.new) = Services::MCPManager.collect_all_mcp_servers(config, load_all_recipes: load_recipes_proc, visited:)
    def resolve_requires_for_source(source, content, processed, all) = Services::DependencyResolver.resolve_requires_for_source(source, content, processed, all, find_rule_file: method(:find_rule_file), gem_root:)
    def resolve_local_require(source_path, required_path) = Services::DependencyResolver.resolve_local_require(source_path, required_path, find_rule_file: method(:find_rule_file), gem_root:)
    def resolve_remote_require(source_url, required_path) = Services::DependencyResolver.resolve_remote_require(source_url, required_path)
    def validate_recipe!(name, recipes) = Services::RecipeLoader.validate_recipe!(name, recipes)
    # rubocop:enable Layout/LineLength

    def recipe_type(val)
      return :agent if val.is_a?(Array)
      return :standard if val.is_a?(Hash)

      :invalid
    end

    def add_agent_files_to_remove(agent, files_to_remove)
      agent_dir = ".#{agent.downcase}"
      if Dir.exist?(agent_dir)
        pattern = agent.downcase == 'cursor' ? "#{agent_dir}/**/*.mdc" : "#{agent_dir}/**/*.md"
        Dir.glob(pattern).each { |f| files_to_remove << f }
        files_to_remove << "#{agent_dir}/"
      end
      local_file = "#{agent.upcase}.local.md" unless agent.downcase == 'cursor'
      files_to_remove << local_file if local_file && File.exist?(local_file)
    end
  end
end
