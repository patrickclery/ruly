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

      # Write hooks from recipe config into .claude/settings.local.json.
      # Merges with existing settings if the file already exists.
      # @param recipe_config [Hash] recipe configuration (may contain 'hooks' key)
      def write_settings(recipe_config, target_dir: nil)
        hooks = recipe_config.is_a?(Hash) && recipe_config['hooks']
        return unless hooks.is_a?(Hash) && hooks.any?

        base = target_dir || Dir.pwd
        settings_path = File.join(base, SETTINGS_FILE)
        FileUtils.mkdir_p(File.dirname(settings_path))

        existing = if File.exist?(settings_path)
                     JSON.parse(File.read(settings_path))
                   else
                     {}
                   end

        existing['hooks'] = hooks
        File.write(settings_path, JSON.pretty_generate(existing))
        puts "Updated #{settings_path} with #{hooks.keys.join(', ')} hook(s)"
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
