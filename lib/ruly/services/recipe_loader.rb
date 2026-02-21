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
      # @param gem_root [String] root directory of the gem/project
      # @param scan_files_for_recipe_tags [Proc, nil] optional callback for tag scanning
      # @return [Array<(Array<Hash>, Hash)>]
      def load_recipe_sources(recipe_name, gem_root:, base_recipes_file: nil,
                              recipes: nil, scan_files_for_recipe_tags: nil)
        recipes ||= begin
          validate_recipes_file!(gem_root:)
          load_all_recipes(base_recipes_file:, gem_root:)
        end
        recipe = validate_recipe!(recipe_name, recipes)

        sources = []

        process_recipe_files(recipe, sources, gem_root:)
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

      # Validates that a recipes.yml file exists.
      #
      # @param gem_root [String]
      # @raise [SystemExit] if recipes.yml not found
      def validate_recipes_file!(gem_root:)
        return if File.exist?(recipes_file_path(gem_root))

        puts "\u274C recipes.yml not found"
        exit 1
      end

      # Returns the path to the base recipes.yml file.
      #
      # @param gem_root [String]
      # @return [String]
      def recipes_file_path(gem_root)
        File.join(gem_root, 'recipes.yml')
      end

      # Returns the path to the user's recipes.yml config file.
      #
      # @return [String]
      def user_recipes_file
        config_dir = File.join(Dir.home, '.config', 'ruly')
        FileUtils.mkdir_p(config_dir)
        File.join(config_dir, 'recipes.yml')
      end

      # Loads all recipes from base and user config files, merged.
      #
      # @param gem_root [String]
      # @param gem_root [String]
      # @param base_recipes_file [String, nil] override for the base recipes.yml path
      # @return [Hash]
      def load_all_recipes(gem_root:, base_recipes_file: nil)
        recipes = {}

        # Load base recipes
        base_file = base_recipes_file || recipes_file_path(gem_root)
        if File.exist?(base_file)
          base_config = YAML.safe_load_file(base_file, aliases: true) || {}
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

      # Processes a local directory, adding all .md and bin/*.sh files.
      #
      # @param directory_path [String]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_local_directory(directory_path, sources, gem_root:)
        # Process markdown files
        Dir.glob(File.join(directory_path, '**', '*.md')).each do |file|
          relative_path = if file.start_with?(gem_root)
                            file.sub("#{gem_root}/", '')
                          else
                            file
                          end
          sources << {path: relative_path, type: 'local'}
        end

        # Also process bin/*.sh files
        Dir.glob(File.join(directory_path, 'bin', '**', '*.sh')).each do |file|
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

      # Searches for a file or directory in multiple locations.
      #
      # @param file [String] file path to search for
      # @param gem_root [String]
      # @return [String, nil] full path if found
      def find_rule_file(file, gem_root:)
        search_paths = [
          file,                                      # Current directory / absolute
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
