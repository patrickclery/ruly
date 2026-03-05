# frozen_string_literal: true

require 'json'
require 'fileutils'

module Ruly
  module Services
    # Writes .claude/settings.local.json from profile hooks configuration.
    # Follows the same pattern as MCPManager for .mcp.json.
    module SettingsManager
      SETTINGS_FILE = '.claude/settings.local.json'

      module_function

      # Write hooks from profile config into .claude/settings.local.json.
      # Merges with existing settings if the file already exists.
      # @param profile_config [Hash] profile configuration (may contain 'hooks' key)
      def write_settings(profile_config, target_dir: nil)
        hooks = profile_config.is_a?(Hash) && profile_config['hooks']
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
    end
  end
end
