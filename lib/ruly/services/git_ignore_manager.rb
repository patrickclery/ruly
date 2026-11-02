# frozen_string_literal: true

module Ruly
  module Services
    # Manages .gitignore and .git/info/exclude file updates with Ruly-generated
    # file patterns. Consolidates the formerly-duplicated update_gitignore and
    # update_git_exclude methods into a single implementation.
    module GitIgnoreManager
      module_function

      # Generate ignore patterns for output files and command directories.
      # @param output_file [String] the main output file path
      # @param agent [String] target agent name
      # @param command_files [Array] command file entries
      # @return [Array<String>] patterns to add
      def generate_ignore_patterns(output_file, agent, command_files)
        patterns = [output_file]
        patterns << '.claude/commands/' if agent == 'claude' && !command_files.empty?
        patterns
      end

      # Update .gitignore with Ruly-generated file patterns.
      # @param patterns [Array<String>] patterns to add
      def update_gitignore(patterns)
        update('.gitignore', patterns)
        puts '📦 Updated .gitignore with generated file patterns'
      end

      # Update .git/info/exclude with Ruly-generated file patterns.
      # @param patterns [Array<String>] patterns to add
      def update_git_exclude(patterns)
        unless Dir.exist?('.git/info')
          puts '⚠️  .git/info directory not found. Is this a git repository?'
          return
        end

        update('.git/info/exclude', patterns)
        puts '📦 Updated .git/info/exclude with generated file patterns'
      end

      # Update an ignore file (gitignore or git-exclude) with a Ruly section.
      # An existing section is merged, not replaced: its entries stay first, new patterns are
      # appended, duplicates dropped. So `-i` for one target (claude, agents) never un-ignores
      # another target's output.
      # @param file_path [String] path to the ignore file
      # @param patterns [Array<String>] patterns to add to the Ruly section
      def update(file_path, patterns)
        existing_content = File.exist?(file_path) ? File.read(file_path, encoding: 'UTF-8') : ''
        existing_lines = existing_content.split("\n")

        ruly_section_start = existing_lines.index('# Ruly generated files')

        if ruly_section_start
          # Find end of existing Ruly section
          ruly_section_end = ruly_section_start + 1
          while ruly_section_end < existing_lines.length &&
                existing_lines[ruly_section_end] &&
                !existing_lines[ruly_section_end].match(/^\s*$/) &&
                !existing_lines[ruly_section_end].start_with?('#')
            ruly_section_end += 1
          end

          # Merge into the Ruly section: kept entries first, then new ones, deduplicated
          kept = existing_lines[(ruly_section_start + 1)...ruly_section_end]
          existing_lines[ruly_section_start...ruly_section_end] = ['# Ruly generated files'] + (kept + patterns).uniq
        else
          # Append new Ruly section
          existing_lines << '' unless existing_lines.last && existing_lines.last.empty?
          existing_lines << '# Ruly generated files'
          existing_lines.concat(patterns)
        end

        File.write(file_path, "#{existing_lines.join("\n")}\n")
      end

      private_class_method :update
    end
  end
end
