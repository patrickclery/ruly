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
      def write_settings(profile_config)
        hooks = profile_config.is_a?(Hash) && profile_config['hooks']
        return unless hooks.is_a?(Hash) && hooks.any?

        FileUtils.mkdir_p('.claude')

        existing = if File.exist?(SETTINGS_FILE)
                     JSON.parse(File.read(SETTINGS_FILE))
                   else
                     {}
                   end

        existing['hooks'] = hooks
        File.write(SETTINGS_FILE, JSON.pretty_generate(existing))
        puts "Updated #{SETTINGS_FILE} with #{hooks.keys.join(', ')} hook(s)"
      end
    end
  end
end
