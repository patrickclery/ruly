# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'tempfile'
require 'uri'
require 'yaml'

module Ruly
  module Services
    # Manages script collection, copying, and command/skill file operations.
    # All methods are stateless module functions; external dependencies
    # (find_rule_file, gem_root) are injected via keyword arguments.
    module ScriptManager # rubocop:disable Metrics/ModuleLength
      module_function

      # Scan all local sources for scripts declared in frontmatter.
      # @param sources [Array<Hash>] source hashes with :type and :path
      # @param find_rule_file [Proc] callable that resolves a rule path to an absolute file path
      # @return [Hash] { local: [...], remote: [...] }
      def collect_scripts_from_sources(sources, find_rule_file:)
        script_files = {local: [], remote: []}

        sources.each do |source|
          next unless source[:type] == 'local'

          file_path = find_rule_file.call(source[:path])
          next unless file_path

          content = File.read(file_path, encoding: 'UTF-8')
          scripts = extract_scripts_from_frontmatter(content, source[:path])

          collect_local_scripts(scripts[:files], source[:path], script_files, find_rule_file:)
          collect_remote_scripts(scripts[:remote], source[:path], script_files)
        end

        script_files
      end

      # Parse scripts declarations from YAML frontmatter.
      # Supports structured format ({ files: [...], remote: [...] })
      # and simplified format (array of paths, treated as files).
      # @param content [String] file content with optional frontmatter
      # @param source_path [String] path for error messages
      # @return [Hash] { files: [...], remote: [...] }
      def extract_scripts_from_frontmatter(content, source_path)
        return {files: [], remote: []} unless content.start_with?('---')

        parts = content.split(/^---\s*$/, 3)
        return {files: [], remote: []} if parts.length < 3

        frontmatter = YAML.safe_load(parts[1])
        scripts = frontmatter['scripts']
        return {files: [], remote: []} unless scripts

        if scripts.is_a?(Hash)
          {
            files: scripts['files'] || [],
            remote: scripts['remote'] || []
          }
        elsif scripts.is_a?(Array)
          {
            files: scripts,
            remote: []
          }
        else
          warn "Warning: Invalid scripts format in #{source_path}"
          {files: [], remote: []}
        end
      rescue StandardError => e
        warn "Warning: Failed to parse frontmatter for scripts in #{source_path}: #{e.message}"
        {files: [], remote: []}
      end

      # Resolve local script paths and append to script_files[:local].
      # @param script_paths [Array<String>] relative or absolute script paths
      # @param source_path [String] the rule file declaring these scripts
      # @param script_files [Hash] accumulator hash with :local and :remote keys
      # @param find_rule_file [Proc] callable to resolve relative paths
      def collect_local_scripts(script_paths, source_path, script_files, find_rule_file:)
        script_paths.each do |script_path|
          resolved_path = script_path.start_with?('/') ? script_path : find_rule_file.call(script_path)

          if resolved_path && File.exist?(resolved_path)
            script_files[:local] << {
              from_rule: source_path,
              relative_path: File.basename(script_path),
              source_path: resolved_path
            }
          else
            warn "Warning: Script not found: #{script_path} (from #{source_path})"
          end
        end
      end

      # Validate remote script URLs and append to script_files[:remote].
      # @param script_urls [Array<String>] GitHub URLs for remote scripts
      # @param source_path [String] the rule file declaring these scripts
      # @param script_files [Hash] accumulator hash with :local and :remote keys
      def collect_remote_scripts(script_urls, source_path, script_files)
        script_urls.each do |script_url|
          script_files[:remote] << {
            filename: File.basename(script_url),
            from_rule: source_path,
            url: Services::GitHubClient.normalize_github_url(script_url)
          }
        end
      end

      # Build a mapping from absolute script source paths to relative filenames.
      # Used for rewriting references in squashed output.
      # @param script_files [Hash] the { local: [...], remote: [...] } hash
      # @return [Hash] { absolute_path => relative_filename }
      def build_script_mappings(script_files)
        mappings = {}

        (script_files[:local] || []).each do |script|
          mappings[script[:source_path]] = script[:relative_path]
        end

        mappings
      end

      # Copy bin/* files to .ruly/bin/ and make them executable.
      # @param bin_files [Array<Hash>] each with :source_path and :relative_path
      def copy_bin_files(bin_files)
        return if bin_files.empty?

        ruly_bin_dir = '.ruly/bin'
        FileUtils.mkdir_p(ruly_bin_dir)

        copied_count = 0
        bin_files.each do |file|
          source_path = file[:source_path]
          relative_path = file[:relative_path]

          target_relative = if (match = relative_path.match(%r{bin/(.+\.sh)$}))
                              match[1]
                            else
                              File.basename(source_path)
                            end

          target_path = File.join(ruly_bin_dir, target_relative)
          target_dir = File.dirname(target_path)

          FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)
          FileUtils.cp(source_path, target_path)
          File.chmod(0o755, target_path)

          copied_count += 1
        end

        puts "🚀 Copied #{copied_count} bin files to .ruly/bin/ (made executable)"
      end

      # Copy collected scripts (local + remote) to destination and make executable.
      # @param script_files [Hash] { local: [...], remote: [...] }
      # @param destination_dir [String, nil] target directory (defaults to .claude/scripts/)
      def copy_scripts(script_files, destination_dir = nil)
        local_scripts = script_files[:local] || []
        remote_scripts = script_files[:remote] || []

        return if local_scripts.empty? && remote_scripts.empty?

        fetched_remote = fetch_remote_scripts(remote_scripts)

        all_scripts = local_scripts + fetched_remote
        return if all_scripts.empty?

        scripts_dir = destination_dir || File.join(Dir.pwd, '.claude', 'scripts')
        FileUtils.mkdir_p(scripts_dir)

        copied_count = 0
        all_scripts.each do |file|
          source_path = file[:source_path]
          relative_path = file[:relative_path]

          target_path = File.join(scripts_dir, relative_path)
          target_dir = File.dirname(target_path)

          FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)
          FileUtils.cp(source_path, target_path)
          File.chmod(0o755, target_path)

          type_label = file[:remote] ? 'remote' : 'local'
          puts "  ✓ #{relative_path} (#{type_label})"

          copied_count += 1
        end

        puts "🔧 Copied #{copied_count} scripts to #{scripts_dir} (made executable)"
      end

      # Download remote scripts from GitHub.
      # @param remote_scripts [Array<Hash>] each with :url, :filename, :from_rule
      # @return [Array<Hash>] fetched script metadata with temp file paths
      def fetch_remote_scripts(remote_scripts)
        return [] if remote_scripts.empty?

        puts '🔄 Fetching remote scripts...'
        fetched_scripts = []

        remote_scripts.each do |script|
          raw_url = script[:url]
                      .gsub('github.com', 'raw.githubusercontent.com')
                      .gsub('/blob/', '/')

          uri = URI(raw_url)
          response = Net::HTTP.get_response(uri)

          if response.code == '200'
            temp_file = Tempfile.new(['script', File.extname(script[:filename])])
            temp_file.write(response.body)
            temp_file.flush
            temp_file.rewind

            fetched_scripts << {
              filename: script[:filename],
              from_rule: script[:from_rule],
              relative_path: script[:filename],
              remote: true,
              source_path: temp_file.path,
              temp_file: # Keep reference to prevent GC
            }

            puts "  ✓ #{script[:filename]} (from #{URI(script[:url]).host})"
          else
            warn "  ✗ Failed to fetch #{script[:filename]}: HTTP #{response.code}"
          end
        rescue StandardError => e
          warn "  ✗ Error fetching #{script[:filename]}: #{e.message}"
        end

        fetched_scripts
      end

      # Write command files to .claude/commands/.
      # @param command_files [Array] either Hashes with :path/:content or String paths
      # @param recipe_config [Hash, nil] recipe configuration (for omit_command_prefix)
      # @param gem_root [String, nil] root path of the gem (needed for import mode paths)
      def save_command_files(command_files, recipe_config = nil, gem_root: nil) # rubocop:disable Metrics/MethodLength
        return if command_files.empty?

        commands_dir = '.claude/commands'
        FileUtils.mkdir_p(commands_dir)

        omit_prefix = recipe_config && recipe_config['omit_command_prefix'] ? recipe_config['omit_command_prefix'] : nil
        debug_warning_shown = false

        command_files.each do |file| # rubocop:disable Metrics/BlockLength
          if file.is_a?(Hash)
            relative_path = get_command_relative_path(file[:path], omit_prefix)

            if !debug_warning_shown && relative_path.split('/').include?('debug')
              puts "\n⚠️  WARNING: 'debug' is a reserved directory name in Claude Code"
              puts '   Commands in .claude/commands/debug/ will not be recognized'
              puts "   Consider renaming to 'bug' or another directory name\n\n"
              debug_warning_shown = true
            end

            target_file = File.join(commands_dir, relative_path)
            target_dir = File.dirname(target_file)
            FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

            File.write(target_file, file[:content])
          else
            source_path = File.join(gem_root, file) if gem_root
            if source_path && File.exist?(source_path)
              relative_path = get_command_relative_path(file, omit_prefix)

              if !debug_warning_shown && relative_path.split('/').include?('debug')
                puts "\n⚠️  WARNING: 'debug' is a reserved directory name in Claude Code"
                puts '   Commands in .claude/commands/debug/ will not be recognized'
                puts "   Consider renaming to 'bug' or another directory name\n\n"
                debug_warning_shown = true
              end

              target_file = File.join(commands_dir, relative_path)
              target_dir = File.dirname(target_file)
              FileUtils.mkdir_p(target_dir) if target_dir != commands_dir

              FileUtils.cp(source_path, target_file)
            end
          end
        end
      end

      # Compute the relative path for a command file under .claude/commands/.
      # @param file_path [String] original path containing /commands/
      # @param omit_prefix [String, Array, nil] prefix(es) to strip
      # @return [String] relative path for the command
      def get_command_relative_path(file_path, omit_prefix = nil)
        if file_path.include?('/commands/')
          parts = file_path.split('/commands/')
          after_commands = parts.last
          before_commands = parts.first

          path_components = before_commands.split('/')
          last_rules_index = path_components.rindex { |dir| dir.downcase.include?('rules') }

          result_path = if last_rules_index
                          dirs_after_rules = path_components[(last_rules_index + 1)..]

                          if dirs_after_rules.any? && !dirs_after_rules.empty?
                            File.join(*dirs_after_rules, after_commands)
                          else
                            after_commands
                          end
                        else
                          parent_dir = path_components.last
                          if parent_dir && !parent_dir.empty?
                            File.join(parent_dir, after_commands)
                          else
                            after_commands
                          end
                        end

          result_path = apply_omit_prefix(result_path, after_commands, omit_prefix) if omit_prefix

          result_path
        else
          File.basename(file_path)
        end
      end

      # Strip a prefix from a command relative path, choosing the best match.
      # @param result_path [String] the computed relative path
      # @param after_commands [String] the portion after /commands/
      # @param omit_prefix [String, Array] prefix(es) to strip
      # @return [String] path with prefix removed
      def apply_omit_prefix(result_path, after_commands, omit_prefix)
        prefixes = omit_prefix.is_a?(Array) ? omit_prefix : [omit_prefix]

        best_path = result_path
        best_stripped = 0

        prefixes.each do |prefix|
          prefix_parts = prefix.split('/')
          path_parts = result_path.split('/')
          stripped = 0

          while prefix_parts.any? && path_parts.any? && prefix_parts.first == path_parts.first
            prefix_parts.shift
            path_parts.shift
            stripped += 1
          end

          next unless stripped > best_stripped

          best_stripped = stripped
          best_path = if path_parts.any?
                        File.join(*path_parts)
                      else
                        File.basename(after_commands)
                      end
        end

        best_path
      end

      # Ensure a file's parent directory exists.
      # @param file_path [String] path to the file
      def ensure_parent_directory(file_path)
        dir = File.dirname(file_path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      # Save compiled skill files to .claude/skills/{name}/SKILL.md.
      # @param skill_files [Array<Hash>] each with :path, :content, and optionally :original_content
      # @param find_rule_file [Proc] callable to resolve rule paths
      # @param parse_frontmatter [Proc] callable for frontmatter parsing
      # @param strip_metadata [Proc] callable for stripping metadata from frontmatter
      def save_skill_files(skill_files, find_rule_file:, parse_frontmatter:, strip_metadata:)
        return if skill_files.empty?

        skill_files.each do |file|
          skill_name = file[:path].split('/skills/').last.sub(/\.md$/, '')
          skill_dir = ".claude/skills/#{skill_name}"
          FileUtils.mkdir_p(skill_dir)

          content = compile_skill_with_requires(file, find_rule_file:, parse_frontmatter:, strip_metadata:)
          File.write(File.join(skill_dir, 'SKILL.md'), content)
        end
      end

      # Compile a skill file by inlining its required dependencies.
      # @param file [Hash] skill file hash with :path, :content, :original_content
      # @param find_rule_file [Proc] callable to resolve rule paths
      # @param parse_frontmatter [Proc] callable for frontmatter parsing
      # @param strip_metadata [Proc] callable for stripping metadata from frontmatter
      # @return [String] compiled skill content
      def compile_skill_with_requires(file, find_rule_file:, parse_frontmatter:, strip_metadata:)
        original = file[:original_content] || file[:content]
        frontmatter, = parse_frontmatter.call(original)
        requires = frontmatter.is_a?(Hash) ? (frontmatter['requires'] || []) : []

        return file[:content] if requires.empty?

        source_full_path = find_rule_file.call(file[:path])
        return file[:content] unless source_full_path

        source_dir = File.dirname(source_full_path)
        compiled_parts = [file[:content]]

        requires.each do |required_path|
          resolved_path = File.expand_path(required_path, source_dir)
          next unless File.file?(resolved_path)

          raw_content = File.read(resolved_path, encoding: 'UTF-8')
          stripped = strip_metadata.call(raw_content)
          compiled_parts << stripped
        end

        compiled_parts.join("\n\n---\n\n")
      end
    end
  end
end
