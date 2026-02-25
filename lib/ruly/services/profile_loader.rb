# frozen_string_literal: true

module Ruly
  module Services
    # Handles profile YAML loading, validation, and source processing.
    # Extracted from CLI to keep profile logic self-contained.
    module ProfileLoader # rubocop:disable Metrics/ModuleLength
      module_function

      # Main entry point: loads and processes a profile's sources.
      # Returns [sources_array, profile_config].
      #
      # @param profile_name [String]
      # @param gem_root [String] root directory of the gem/project
      # @param scan_files_for_profile_tags [Proc, nil] optional callback for tag scanning
      # @return [Array<(Array<Hash>, Hash)>]
      def load_profile_sources(profile_name, gem_root:, base_profiles_file: nil,
                              profiles: nil, scan_files_for_profile_tags: nil)
        profiles ||= begin
          validate_profiles_file!(gem_root:)
          load_all_profiles(base_profiles_file:, gem_root:)
        end
        profile = validate_profile!(profile_name, profiles)

        sources = []

        process_profile_files(profile, sources, gem_root:)
        process_profile_skills(profile, sources, gem_root:)
        process_profile_commands(profile, sources, gem_root:)
        process_profile_scripts(profile, sources, gem_root:)
        process_profile_sources(profile, sources, gem_root:)
        process_legacy_remote_sources(profile, sources)

        # Scan for files with matching profile tags in frontmatter
        if scan_files_for_profile_tags
          tagged_sources = scan_files_for_profile_tags.call(profile_name)

          # Merge tagged sources with profile sources, deduplicating by path
          existing_paths = sources.to_set { |s| s[:path] }
          tagged_sources.each do |tagged_source|
            sources << tagged_source unless existing_paths.include?(tagged_source[:path])
          end
        end

        [sources, profile]
      end

      # Validates that a profiles.yml file exists.
      #
      # @param gem_root [String]
      # @raise [SystemExit] if profiles.yml not found
      def validate_profiles_file!(gem_root:)
        return if File.exist?(profiles_file_path(gem_root))

        puts "\u274C profiles.yml not found"
        exit 1
      end

      # Returns the path to the base profiles.yml file.
      #
      # @param gem_root [String]
      # @return [String]
      def profiles_file_path(gem_root)
        File.join(gem_root, 'profiles.yml')
      end

      # Returns the path to the user's profiles.yml config file.
      #
      # @return [String]
      def user_profiles_file
        config_dir = File.join(Dir.home, '.config', 'ruly')
        FileUtils.mkdir_p(config_dir)
        File.join(config_dir, 'profiles.yml')
      end

      # Loads all profiles from base and user config files, merged.
      #
      # @param gem_root [String]
      # @param gem_root [String]
      # @param base_profiles_file [String, nil] override for the base profiles.yml path
      # @return [Hash]
      def load_all_profiles(gem_root:, base_profiles_file: nil)
        profiles = {}

        # Load base profiles
        base_file = base_profiles_file || profiles_file_path(gem_root)
        if File.exist?(base_file)
          base_config = YAML.safe_load_file(base_file, aliases: true) || {}
          profiles.merge!(base_config['profiles'] || {})
        end

        # Load user config profiles (highest priority)
        user_config_file = File.expand_path('~/.config/ruly/profiles.yml')
        if File.exist?(user_config_file)
          user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
          profiles.merge!(user_config['profiles'] || {})
        end

        resolve_extends!(profiles)

        profiles
      end

      # Validates that a profile exists in the loaded config.
      #
      # @param profile_name [String]
      # @param profiles [Hash]
      # @return [Hash, Array] the profile config
      # @raise [Thor::Error] if profile not found
      def validate_profile!(profile_name, profiles)
        profile = profiles[profile_name]
        return profile if profile

        puts "\u274C Profile '#{profile_name}' not found"
        puts "Available profiles: #{profiles.keys.join(', ')}"
        raise Thor::Error, "Profile '#{profile_name}' not found"
      end

      # Processes the 'files' key from a profile config.
      #
      # @param profile [Hash, Array] profile config (Array for agent profiles)
      # @param sources [Array<Hash>] accumulator for sources
      # @param gem_root [String]
      def process_profile_files(profile, sources, gem_root:)
        # For agent profiles (arrays), the profile itself is the list of files
        # For standard profiles (hashes), the files are in profile['files']
        files = profile.is_a?(Array) ? profile : profile['files']

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

      # Processes the 'skills' key from a profile config.
      def process_profile_skills(profile, sources, gem_root:)
        process_categorized_key(profile, sources, category: :skill, gem_root:, key: 'skills')
      end

      # Processes the 'commands' key from a profile config.
      def process_profile_commands(profile, sources, gem_root:)
        process_categorized_key(profile, sources, category: :command, gem_root:, key: 'commands')
      end

      # Processes a categorized profile key (skills or commands) into sources.
      # Both keys share the same logic: resolve files, expand directories to .md files,
      # and tag with the appropriate category marker.
      #
      # @param profile [Hash, Array] profile config
      # @param sources [Array<Hash>] accumulator for sources
      # @param key [String] profile key name ('skills' or 'commands')
      # @param category [Symbol] category marker (:skill or :command)
      # @param gem_root [String]
      def process_categorized_key(profile, sources, category:, gem_root:, key:)
        return if profile.is_a?(Array)

        profile[key]&.each do |file|
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

      # Processes the 'scripts' key from a profile config.
      #
      # @param profile [Hash, Array] profile config
      # @param sources [Array<Hash>] accumulator for sources
      # @param gem_root [String]
      def process_profile_scripts(profile, sources, gem_root:)
        return if profile.is_a?(Array)

        profile['scripts']&.each do |file|
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

      # Processes the 'sources' key from a profile config.
      #
      # @param profile [Hash, Array]
      # @param sources [Array<Hash>]
      # @param gem_root [String]
      def process_profile_sources(profile, sources, gem_root:)
        # Agent profiles (arrays) don't have sources, only files
        return if profile.is_a?(Array)

        sources_list = profile['sources'] || []
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
      # Script files are no longer auto-included; use the explicit 'scripts' profile key instead.
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

      # Handles legacy 'remote_sources' key from profile config.
      #
      # @param profile [Hash, Array]
      # @param sources [Array<Hash>]
      def process_legacy_remote_sources(profile, sources)
        # Agent profiles (arrays) don't have remote_sources
        return if profile.is_a?(Array)

        profile['remote_sources']&.each do |url|
          sources << {path: url, type: 'remote'}
        end
      end

      # Array keys that get merged via union (concat + uniq).
      ARRAY_MERGE_KEYS = %w[files skills commands scripts sources remote_sources mcp_servers omit_command_prefix].freeze

      # Resolve all `extends:` declarations in the profiles hash, in-place.
      #
      # @param profiles [Hash] all loaded profiles (mutated in place)
      # @raise [Ruly::Error] on circular extends references or missing parent
      def resolve_extends!(profiles)
        resolved = Set.new

        profiles.each_key do |name|
          resolve_single_extends!(name, profiles, resolved, Set.new)
        end
      end

      # Recursively resolve extends for a single profile.
      #
      # @param name [String] profile name
      # @param profiles [Hash] all profiles
      # @param resolved [Set] already fully-resolved profile names
      # @param in_progress [Set] currently being resolved (cycle detection)
      def resolve_single_extends!(name, profiles, resolved, in_progress)
        return if resolved.include?(name)

        profile = profiles[name]
        return unless profile.is_a?(Hash) && profile['extends']

        parent_name = profile['extends']

        if in_progress.include?(name)
          raise Ruly::Error, "Circular extends detected: #{in_progress.to_a.join(' -> ')} -> #{name}"
        end

        unless profiles.key?(parent_name)
          raise Ruly::Error,
                "Profile '#{name}' extends '#{parent_name}', but '#{parent_name}' does not exist"
        end

        in_progress.add(name)

        # Resolve parent first (handles transitive extends)
        resolve_single_extends!(parent_name, profiles, resolved, in_progress)

        parent = profiles[parent_name]
        merge_profile!(profile, parent)
        profile.delete('extends')

        in_progress.delete(name)
        resolved.add(name)
      end

      # Merge parent profile keys into child profile (in-place).
      #
      # @param child [Hash] child profile (mutated)
      # @param parent [Hash] parent profile (read-only)
      def merge_profile!(child, parent)
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
