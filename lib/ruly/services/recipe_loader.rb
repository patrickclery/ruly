# frozen_string_literal: true

module Ruly
  module Services
    # Handles recipe YAML loading, validation, and source processing.
    # Extracted from CLI to keep recipe logic self-contained.
    module RecipeLoader # rubocop:disable Metrics/ModuleLength
      module_function

      # Main entry point: loads and processes a recipe's sources.
      # Returns [sources_array, recipe_config].
      #
      # @param recipe_name [String]
      # @param gem_root [String] root directory of the gem/project (used to resolve relative rule paths)
      # @param recipes [Hash, nil] already-loaded recipes (loaded via the config chain when nil)
      # @param scan_files_for_recipe_tags [Proc, nil] optional callback for tag scanning
      # @param user_recipes_file [String, nil] override for ~/.config/ruly/recipes.yml
      # @return [Array<(Array<Hash>, Hash)>]
      def load_recipe_sources(recipe_name, gem_root:, recipes: nil, scan_files_for_recipe_tags: nil,
                              user_recipes_file: nil)
        recipes ||= load_all_recipes(user_recipes_file:)
        recipe = validate_recipe!(recipe_name, recipes)

        sources = []

        process_recipe_files(recipe, sources, gem_root:)
        process_recipe_skills(recipe, sources, gem_root:)
        process_recipe_commands(recipe, sources, gem_root:)
        process_recipe_scripts(recipe, sources, gem_root:)
        process_recipe_sources(recipe, sources, gem_root:)
        process_legacy_remote_sources(recipe, sources)

        # Scan for files with matching recipe tags in frontmatter
        if scan_files_for_recipe_tags
          tagged_sources = scan_files_for_recipe_tags.call(recipe_name)

          # Merge tagged sources with recipe sources, deduplicating by path
          existing_paths = sources.to_set { |s| s[:path] }
          tagged_sources.each do |tagged_source|
            sources << tagged_source unless existing_paths.include?(tagged_source[:path])
          end
        end

        [sources, recipe]
      end

      # File name of the project-local recipes file, looked up in the current directory.
      PROJECT_RECIPES_FILE = '.recipes.yml'

      # Returns the path to the user's recipes.yml config file.
      #
      # @return [String]
      def user_recipes_file
        config_dir = File.join(Dir.home, '.config', 'ruly')
        FileUtils.mkdir_p(config_dir)
        File.join(config_dir, 'recipes.yml')
      end

      # Returns the path to the project-local recipes file ($CWD/.recipes.yml).
      #
      # @param cwd [String]
      # @return [String]
      def project_recipes_file(cwd = Dir.pwd)
        File.join(cwd, PROJECT_RECIPES_FILE)
      end

      # Human-readable origin of each loaded recipe (name => origin), set by load_all_recipes.
      # @return [Hash{String => String}]
      def recipe_origins
        @recipe_origins ||= {}
      end

      # Base directory of each mirrored recipe (name => mirror dir), used to rebase override entries.
      # @return [Hash{String => String}]
      def recipe_base_dirs
        @recipe_base_dirs ||= {}
      end

      # Which source won the fallback chain in the last load: :remotes, :project or :user.
      # @return [Symbol, nil]
      def source_origin
        @source_origin
      end

      # Loads recipes through the fallback chain, first hit wins:
      #   1. mirrored remotes  (~/.config/ruly/remotes/<owner>/<repo>/recipes.yml, see RemoteSync)
      #   2. project file      ($CWD/.recipes.yml)
      #   3. user config       (~/.config/ruly/recipes.yml)
      #
      # `remotes:` and `overrides:` are settings, so they are read from BOTH the user and
      # project files regardless of which source wins. Overrides merge additively on top
      # of the winning recipes (arrays union, scalars replaced, subagents by name).
      #
      # @param user_recipes_file [String, nil] override for ~/.config/ruly/recipes.yml
      # @param project_recipes_file [String, nil] override for $CWD/.recipes.yml
      # @param remotes_dir [String, nil] override for ~/.config/ruly/remotes
      # @param sync [Boolean] mirror every declared remote before loading
      # @return [Hash] recipe name => recipe config
      # @raise [Ruly::Error] when no recipe source exists or an override targets an unknown recipe
      def load_all_recipes(project_recipes_file: nil, remotes_dir: nil, sync: false, user_recipes_file: nil)
        user_file = user_recipes_file || self.user_recipes_file
        project_file = project_recipes_file || self.project_recipes_file
        remotes_dir ||= RemoteSync.remotes_dir
        user_config = read_config_file(user_file)
        project_config = read_config_file(project_file)

        remotes = (Array(user_config['remotes']) + Array(project_config['remotes']))
                  .map { |r| RemoteSync.normalize_remote(r, remotes_dir:) }
                  .uniq { |r| r[:github] }
        RemoteSync.sync_all!(remotes) if sync

        recipes = select_recipe_source(remotes, project_config:, project_file:, remotes_dir:, user_config:, user_file:)
        apply_overrides!(recipes, user_config['overrides'], origin: user_file)
        apply_overrides!(recipes, project_config['overrides'], origin: project_file)

        resolve_extends!(recipes)

        recipes
      end

      # Parses a YAML config file, returning {} when it does not exist.
      #
      # @param path [String, nil]
      # @return [Hash]
      def read_config_file(path)
        return {} unless path && File.exist?(path)

        YAML.safe_load_file(path, aliases: true) || {}
      end

      # Picks the recipe definitions from the first existing source in the chain.
      #
      # @return [Hash] recipes (mutable, origins recorded in recipe_origins)
      # @raise [Ruly::Error] when nothing in the chain exists
      def select_recipe_source(remotes, project_config:, project_file:, remotes_dir:, user_config:, user_file:)
        @recipe_origins = {}
        @recipe_base_dirs = {}

        mirrored, unmirrored = remotes.partition { |r| RemoteSync.mirrored?(r) }
        unmirrored.each do |r|
          warn "\u26A0\uFE0F  Remote #{r[:github]} is not mirrored yet; run `ruly squash --sync` to fetch it"
        end
        mirrors = mirrored + RemoteSync.undeclared_mirrors(remotes, remotes_dir:)

        if mirrors.any?
          @source_origin = :remotes
          mirrors.each_with_object({}) { |remote, acc| acc.merge!(load_mirror(remote)) }
        elsif File.exist?(project_file)
          @source_origin = :project
          tag_origins(project_config['recipes'] || {}, project_file)
        elsif File.exist?(user_file)
          @source_origin = :user
          tag_origins(user_config['recipes'] || {}, user_file)
        else
          looked = remotes.map { |r| RemoteSync.mirror_recipes_file(r) } + [project_file, user_file]
          raise Ruly::Error,
                "No recipes found. Looked for:\n#{looked.map { |l| "  - #{l}" }.join("\n")}\n" \
                'Add `remotes:` to ~/.config/ruly/recipes.yml and run `ruly squash --sync`, or run `ruly init`.'
        end
      end

      # Loads a mirrored recipes file, rebasing repo-relative entries onto the mirror dir.
      #
      # @param remote [Hash] normalized remote spec
      # @return [Hash] recipes
      def load_mirror(remote)
        recipes = read_config_file(RemoteSync.mirror_recipes_file(remote))['recipes'] || {}
        recipes.each do |name, recipe|
          rebase_relative_entries!(recipe, remote[:mirror_dir])
          recipe_origins[name] = "remote #{remote[:github]}"
          recipe_base_dirs[name] = remote[:mirror_dir]
        end
        recipes
      end

      # Records the file each recipe came from.
      #
      # @param recipes [Hash]
      # @param file [String]
      # @return [Hash] the same recipes
      def tag_origins(recipes, file)
        recipes.each_key { |name| recipe_origins[name] = file }
        recipes
      end

      # Rewrites repo-relative entries (files/skills/commands/scripts) to live under base_dir.
      # Absolute paths, `~` paths and URLs are left untouched.
      #
      # @param recipe [Hash, Array] recipe config (Array for agent recipes)
      # @param base_dir [String]
      # @return [Hash, Array] the same recipe, mutated
      def rebase_relative_entries!(recipe, base_dir)
        if recipe.is_a?(Array)
          recipe.map! { |entry| rebase_entry(entry, base_dir) }
        elsif recipe.is_a?(Hash)
          RemoteSync::RULE_KEYS.each do |key|
            next unless recipe[key].is_a?(Array)

            recipe[key] = recipe[key].map { |entry| rebase_entry(entry, base_dir) }
          end
        end
        recipe
      end

      # @param entry [Object]
      # @param base_dir [String]
      # @return [Object]
      def rebase_entry(entry, base_dir)
        RemoteSync.relative_entry?(entry) ? File.join(base_dir, entry) : entry
      end

      # Merges an `overrides:` block additively into already-loaded recipes.
      #
      # @param recipes [Hash] loaded recipes (mutated)
      # @param overrides [Hash, nil] recipe name => partial recipe
      # @param origin [String] file the overrides came from (for messages)
      # @raise [Ruly::Error] when an override targets a recipe that is not loaded
      def apply_overrides!(recipes, overrides, origin:)
        return unless overrides.is_a?(Hash)

        overrides.each do |name, override|
          target = recipes[name]
          unless target.is_a?(Hash) && override.is_a?(Hash)
            raise Ruly::Error,
                  "overrides: '#{name}' in #{origin} does not match a loaded recipe " \
                  "(available: #{recipes.keys.join(', ')})"
          end

          merged = override.dup
          rebase_relative_entries!(merged, recipe_base_dirs[name]) if recipe_base_dirs[name]
          merged['extends'] ||= target['extends'] if target['extends']
          merge_recipe!(merged, target)
          target.replace(merged)
          recipe_origins[name] = "#{recipe_origins[name]} + overrides (#{origin})"
        end
      end

      # Validates that a recipe exists in the loaded config.
      #
      # @param recipe_name [String]
      # @param recipes [Hash]
      # @return [Hash, Array] the recipe config
      # @raise [Thor::Error] if recipe not found
      def validate_recipe!(recipe_name, recipes)
        recipe = recipes[recipe_name]
        return recipe if recipe

        puts "\u274C Recipe '#{recipe_name}' not found"
        puts "Available recipes: #{recipes.keys.join(', ')}"
        raise Thor::Error, "Recipe '#{recipe_name}' not found"
      end

      # Processes the 'files' key from a recipe config.
      #
      # @param recipe [Hash, Array] recipe config (Array for agent recipes)
      # @param sources [Array<Hash>] accumulator for sources
      # @param gem_root [String]
      def process_recipe_files(recipe, sources, gem_root:)
        # For agent recipes (arrays), the recipe itself is the list of files
        # For standard recipes (hashes), the files are in recipe['files']
        files = recipe.is_a?(Array) ? recipe : recipe['files']

        files&.each do |file|
          full_path = find_rule_file(file, gem_root:)

          if full_path
            if File.directory?(full_path)
              md_files = find_markdown_files_recursively(full_path)
              if md_files.any?
                md_files.each do |md_file|
                  sources << {path: md_file, type: 'local'}
                end
              else
                puts "\u26A0\uFE0F  Warning: No markdown files found in directory: #{file}"
              end
            else
              sources << {path: file, type: 'local'}
            end
          else
            puts "\u26A0\uFE0F  Warning: File not found: #{file}"
          end
        end
      end

      # Processes the 'skills' key from a recipe config.
      def process_recipe_skills(recipe, sources, gem_root:)
        process_categorized_key(recipe, sources, category: :skill, gem_root:, key: 'skills')
      end

      # Processes the 'commands' key from a recipe config.
      def process_recipe_commands(recipe, sources, gem_root:)
        process_categorized_key(recipe, sources, category: :command, gem_root:, key: 'commands')
      end

      # Processes a categorized recipe key (skills or commands) into sources.
      # Both keys share the same logic: resolve files, expand directories to .md files,
      # and tag with the appropriate category marker.
      #
      # @param recipe [Hash, Array] recipe config
      # @param sources [Array<Hash>] accumulator for sources
      # @param key [String] recipe key name ('skills' or 'commands')
      # @param category [Symbol] category marker (:skill or :command)
      # @param gem_root [String]
      def process_categorized_key(recipe, sources, category:, gem_root:, key:)
        return if recipe.is_a?(Array)

        recipe[key]&.each do |file|
          full_path = find_rule_file(file, gem_root:)
          if full_path
            if File.directory?(full_path)
              find_markdown_files_recursively(full_path).each do |md_file|
                sources << {category:, path: md_file, type: 'local'}
              end
            else
              sources << {category:, path: file, type: 'local'}
            end
          else
            puts "\u26A0\uFE0F  Warning: #{key.capitalize.delete_suffix('s')} file not found: #{file}"
          end
        end
      end

      # Processes the 'scripts' key from a recipe config.
      #
      # @param recipe [Hash, Array] recipe config
      # @param sources [Array<Hash>] accumulator for sources
      # @param gem_root [String]
      def process_recipe_scripts(recipe, sources, gem_root:)
        return if recipe.is_a?(Array)

        recipe['scripts']&.each do |file|
          full_path = find_rule_file(file, gem_root:)
          if full_path
            if File.directory?(full_path)
              Dir.glob(File.join(full_path, '**', '*.sh')).each do |sh_file|
                relative = sh_file.start_with?(gem_root) ? sh_file.sub("#{gem_root}/", '') : sh_file
                sources << {category: :script, path: relative, type: 'local'}
              end
            else
              sources << {category: :script, path: file, type: 'local'}
            end
          else
            puts "\u26A0\uFE0F  Warning: Script file not found: #{file}"
          end
        end
      end

      # Processes the 'sources' key from a recipe config.
      #
      # @param recipe [Hash, Array]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_recipe_sources(recipe, sources, gem_root:)
        # Agent recipes (arrays) don't have sources, only files
        return if recipe.is_a?(Array)

        sources_list = recipe['sources'] || []
        sources_list.each do |source_spec|
          process_source_spec(source_spec, sources, gem_root:)
        end
      end

      # Dispatches a source spec by type (Hash or String).
      #
      # @param source_spec [Hash, String]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_source_spec(source_spec, sources, gem_root:)
        if source_spec.is_a?(Hash)
          process_hash_source_spec(source_spec, sources, gem_root:)
        elsif source_spec.is_a?(String)
          process_string_source_spec(source_spec, sources, gem_root:)
        end
      end

      # Handles hash-style source specs (github or local).
      #
      # @param source_spec [Hash]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_hash_source_spec(source_spec, sources, gem_root:)
        if source_spec['github']
          process_github_source(source_spec, sources)
        elsif source_spec['local']
          Array(source_spec['local']).each do |local_path|
            process_local_source(local_path, sources, gem_root:)
          end
        end
      end

      # Expands GitHub paths into source entries.
      #
      # @param source_spec [Hash] with 'github', 'branch', 'rules' keys
      # @param sources [Array<Hash>]
      def process_github_source(source_spec, sources)
        owner_repo = source_spec['github']
        branch = source_spec['branch'] || 'main'
        rules = source_spec['rules'] || []

        rules.each do |rule_path|
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

      # Handles remote (URL) source entries, expanding GitHub directories.
      #
      # @param source [String] URL
      # @param sources [Array<Hash>]
      def process_remote_source(source, sources)
        if source.include?('github.com') && source.include?('/tree/')
          path_parts = source.split('/')
          last_part = path_parts.last

          if /\.\w+$/.match?(last_part)
            # It's a direct file URL that happens to use /tree/ format
            sources << {path: source, type: 'remote'}
          else
            # It's a GitHub directory - expand to all .md files
            dir_name = last_part
            puts "  \u{1F4C2} Expanding GitHub directory: #{dir_name}/"
            dir_files = Services::GitHubClient.fetch_github_directory_files(source)
            if dir_files.any?
              puts "     Found #{dir_files.length} markdown files"
              dir_files.each do |file_url|
                sources << {path: file_url, type: 'remote'}
              end
            else
              puts "     \u26A0\uFE0F No markdown files found or failed to access"
            end
          end
        else
          # It's a direct file URL (blob format or other)
          sources << {path: source, type: 'remote'}
        end
      end

      # Handles local path sources, expanding directories.
      #
      # @param source [String] local file or directory path
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_local_source(source, sources, gem_root:)
        full_path = find_rule_file(source, gem_root:)

        if full_path
          if File.directory?(full_path)
            process_local_directory(full_path, sources, gem_root:)
          else
            sources << {path: source, type: 'local'}
          end
        else
          puts "\u26A0\uFE0F  Warning: File or directory not found: #{source}"
        end
      end

      # Processes a local directory, adding all .md files.
      # Script files are no longer auto-included; use the explicit 'scripts' recipe key instead.
      #
      # @param directory_path [String]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_local_directory(directory_path, sources, gem_root:)
        Dir.glob(File.join(directory_path, '**', '*.md')).each do |file|
          relative_path = if file.start_with?(gem_root)
                            file.sub("#{gem_root}/", '')
                          else
                            file
                          end
          sources << {path: relative_path, type: 'local'}
        end
      end

      # Handles string-style source specs (URL or local path).
      #
      # @param source_spec [String]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_string_source_spec(source_spec, sources, gem_root:)
        if source_spec.start_with?('http://', 'https://')
          process_remote_source(source_spec, sources)
        else
          process_local_source(source_spec, sources, gem_root:)
        end
      end

      # Handles legacy 'remote_sources' key from recipe config.
      #
      # @param recipe [Hash, Array]
      # @param sources [Array<Hash>]
      def process_legacy_remote_sources(recipe, sources)
        # Agent recipes (arrays) don't have remote_sources
        return if recipe.is_a?(Array)

        recipe['remote_sources']&.each do |url|
          sources << {path: url, type: 'remote'}
        end
      end

      # Array keys that get merged via union (concat + uniq).
      ARRAY_MERGE_KEYS = %w[files skills commands scripts sources remote_sources mcp_servers omit_command_prefix].freeze

      # Resolve all `extends:` declarations in the recipes hash, in-place.
      #
      # @param recipes [Hash] all loaded recipes (mutated in place)
      # @raise [Ruly::Error] on circular extends references or missing parent
      def resolve_extends!(recipes)
        resolved = Set.new

        recipes.each_key do |name|
          resolve_single_extends!(name, recipes, resolved, Set.new)
        end
      end

      # Recursively resolve extends for a single recipe.
      #
      # @param name [String] recipe name
      # @param recipes [Hash] all recipes
      # @param resolved [Set] already fully-resolved recipe names
      # @param in_progress [Set] currently being resolved (cycle detection)
      def resolve_single_extends!(name, recipes, resolved, in_progress)
        return if resolved.include?(name)

        recipe = recipes[name]
        return unless recipe.is_a?(Hash) && recipe['extends']

        parent_name = recipe['extends']

        if in_progress.include?(name)
          raise Ruly::Error, "Circular extends detected: #{in_progress.to_a.join(' -> ')} -> #{name}"
        end

        unless recipes.key?(parent_name)
          raise Ruly::Error,
                "Recipe '#{name}' extends '#{parent_name}', but '#{parent_name}' does not exist"
        end

        in_progress.add(name)

        # Resolve parent first (handles transitive extends)
        resolve_single_extends!(parent_name, recipes, resolved, in_progress)

        parent = recipes[parent_name]
        merge_recipe!(recipe, parent)
        recipe.delete('extends')

        in_progress.delete(name)
        resolved.add(name)
      end

      # Merge parent recipe keys into child recipe (in-place).
      #
      # @param child [Hash] child recipe (mutated)
      # @param parent [Hash] parent recipe (read-only)
      def merge_recipe!(child, parent)
        parent.each do |key, parent_value|
          next if key == 'extends'

          if key == 'subagents'
            child[key] = merge_subagents(parent_value, child[key])
          elsif ARRAY_MERGE_KEYS.include?(key)
            child_value = child[key] || []
            child[key] = (Array(parent_value) + Array(child_value)).uniq
          elsif !child.key?(key)
            child[key] = parent_value
          end
        end
      end

      # Merge subagent arrays by name, child entries win on conflict.
      #
      # @param parent_subagents [Array<Hash>, nil]
      # @param child_subagents [Array<Hash>, nil]
      # @return [Array<Hash>]
      def merge_subagents(parent_subagents, child_subagents)
        parent_list = Array(parent_subagents)
        child_list = Array(child_subagents)

        merged = {}
        parent_list.each { |s| merged[s['name']] = s if s['name'] }
        child_list.each { |s| merged[s['name']] = s if s['name'] }
        merged.values
      end

      # Searches for a file or directory in multiple locations.
      #
      # @param file [String] file path to search for
      # @param gem_root [String]
      # @return [String, nil] full path if found
      def find_rule_file(file, gem_root:)
        search_paths = [
          file,                                      # Current directory / absolute
          File.expand_path(file),                    # ~/... paths
          File.expand_path("~/ruly/#{file}"),        # User home directory
          File.join(gem_root, file) # Gem directory
        ]

        search_paths.each do |path|
          return path if File.exist?(path) || File.directory?(path)
        end

        nil
      end

      # Finds all .md files recursively in a directory.
      #
      # @param directory [String]
      # @return [Array<String>] sorted list of file paths
      def find_markdown_files_recursively(directory)
        Dir.glob(File.join(directory, '**', '*.md'))
      end
    end
  end
end
