# frozen_string_literal: true

require 'shellwords'

module Ruly
  module Services
    # Checks for required shell commands declared in rule-file frontmatter.
    module ShellCommandChecker
      module_function

      # Collect all require_shell_commands from sources.
      # @param sources [Array<Hash>] source entries with :type and :path
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @return [Array<String>] unique list of required commands
      def collect_required_commands(sources, find_rule_file:)
        commands = Set.new

        sources.each do |source|
          next unless source[:type] == 'local'

          file_path = source[:path]
          file_path = find_rule_file.call(file_path) unless File.exist?(file_path)
          next unless file_path && File.exist?(file_path)

          content = File.read(file_path, encoding: 'UTF-8')
          cmds = Services::FrontmatterParser.extract_require_shell_commands(content)
          commands.merge(cmds)
        end

        commands.to_a
      end

      # Check which required shell commands are available in PATH.
      # @param commands [Array<String>] list of commands to check
      # @return [Hash] hash with :available and :missing arrays
      def check_commands(commands)
        available = []
        missing = []

        commands.each do |cmd|
          if system("which #{cmd.shellescape} > /dev/null 2>&1")
            available << cmd
          else
            missing << cmd
          end
        end

        {available:, missing:}
      end

      # Collect and check required shell commands, printing warnings for missing ones.
      # @param sources [Array<Hash>] source entries
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      def check_and_warn(sources, find_rule_file:)
        required = collect_required_commands(sources, find_rule_file:)
        return if required.empty?

        result = check_commands(required)
        result[:missing].each do |cmd|
          puts "⚠️  Warning: Required shell command '#{cmd}' not found in PATH"
        end
      end
    end
  end
end
