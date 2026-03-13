# frozen_string_literal: true

require 'json'
require 'fileutils'

module Ruly
  module Services
    # Writes .claude/settings.local.json from recipe hooks configuration.
    # Follows the same pattern as MCPManager for .mcp.json.
    module SettingsManager
      SETTINGS_FILE = '.claude/settings.local.json'

      module_function

      # Write hooks, model, and isolate settings into .claude/settings.local.json.
      # Merges with existing settings if the file already exists.
      # @param recipe_config [Hash] recipe configuration (may contain 'hooks', 'model', and 'isolate' keys)
      def write_settings(recipe_config, target_dir: nil)
        return unless recipe_config.is_a?(Hash)

        hooks = recipe_config['hooks']
        model = recipe_config['model']
        isolate = recipe_config['isolate']
        has_hooks = hooks.is_a?(Hash) && hooks.any?
        has_model = model.is_a?(String) && !model.empty?
        has_isolate = isolate == true
        return unless has_hooks || has_model || has_isolate

        base = target_dir || Dir.pwd
        settings_path = File.join(base, SETTINGS_FILE)
        FileUtils.mkdir_p(File.dirname(settings_path))

        existing = if File.exist?(settings_path)
                     JSON.parse(File.read(settings_path))
                   else
                     {}
                   end

        existing['hooks'] = hooks if has_hooks
        existing['model'] = model if has_model

        if has_isolate
          parent_files = collect_parent_claude_files(base)
          existing['claudeMdExcludes'] = parent_files if parent_files.any?
        end

        File.write(settings_path, JSON.pretty_generate(existing))
        parts = []
        parts << "#{hooks.keys.join(', ')} hook(s)" if has_hooks
        parts << "model: #{model}" if has_model
        parts << "isolate: #{parent_files&.size || 0} parent CLAUDE file(s) excluded" if has_isolate
        puts "Updated #{settings_path} with #{parts.join(', ')}"
      end

      # Collect CLAUDE.md and CLAUDE.local.md files from all ancestor directories.
      # Walks up from the parent of base_dir to the filesystem root.
      # @param base_dir [String] the project directory (files in this dir are NOT included)
      # @return [Array<String>] absolute paths of parent CLAUDE files
      def collect_parent_claude_files(base_dir)
        claude_filenames = %w[CLAUDE.md CLAUDE.local.md].freeze
        result = []
        dir = File.dirname(File.realpath(base_dir))

        while dir != File.dirname(dir) # stop at filesystem root
          claude_filenames.each do |name|
            path = File.join(dir, name)
            result << path if File.exist?(path)
          end
          dir = File.dirname(dir)
        end

        # Also check the root directory itself
        claude_filenames.each do |name|
          path = File.join(dir, name)
          result << path if File.exist?(path)
        end

        result
      end

      # Propagate parent recipe hooks into subagent cwd directories.
      # @param recipe_config [Hash] recipe configuration with 'hooks' and 'subagents'
      # @param script_files [Array<String>] paths to script files to copy into each cwd
      def propagate_hooks_to_subdirs(recipe_config, script_files: [])
        hooks = recipe_config.is_a?(Hash) && recipe_config['hooks']
        return unless hooks.is_a?(Hash) && hooks.any?

        subagents = recipe_config['subagents']
        return unless subagents.is_a?(Array)

        cwd_dirs = subagents.filter_map { |s| s['cwd'] }.uniq
        return if cwd_dirs.empty?

        cwd_dirs.each do |subdir|
          target = File.join(Dir.pwd, subdir)
          next unless Dir.exist?(target)

          write_settings(recipe_config, target_dir: target)

          script_files.each do |src|
            next unless File.exist?(src)

            dest = File.join(target, src)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(src, dest)
            File.chmod(0o755, dest)
          end
        end

        puts "Propagated hooks to #{cwd_dirs.size} submodule dir(s): #{cwd_dirs.join(', ')}"
      end
    end
  end
end
