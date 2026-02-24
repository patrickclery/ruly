# frozen_string_literal: true

module Ruly
  module Checks
    # Warns when a file is required by multiple skills but not in the profile.
    # Suggests promoting the file to the recipe's files: list to avoid duplication.
    class DuplicateSkillRequires < Base
      class << self
        def call(skill_files, find_rule_file:, parse_frontmatter:, profile_paths: Set.new)
          require_map = build_require_map(skill_files, find_rule_file:, parse_frontmatter:)
          warnings = detect_duplicates(require_map, profile_paths)

          result = build_result(warnings:)
          report(warnings) if warnings.any?
          result
        end

        private

        def build_require_map(skill_files, find_rule_file:, parse_frontmatter:)
          require_map = Hash.new { |h, k| h[k] = [] }

          skill_files.each do |file|
            original = file[:original_content] || file[:content]
            frontmatter, = parse_frontmatter.call(original)
            requires = frontmatter.is_a?(Hash) ? (frontmatter['requires'] || []) : []
            next if requires.empty?

            source_full_path = find_rule_file.call(file[:path])
            next unless source_full_path

            source_dir = File.dirname(source_full_path)

            requires.each do |required_path|
              resolved = File.expand_path(required_path, source_dir)
              next unless File.file?(resolved)

              canonical = begin
                File.realpath(resolved)
              rescue StandardError
                resolved
              end

              skill_name = Services::ScriptManager.derive_skill_name(file[:path])
              require_map[canonical] << skill_name
            end
          end

          require_map
        end

        def detect_duplicates(require_map, profile_paths)
          require_map.filter_map do |file_path, skills|
            next if skills.size < 2
            next if profile_paths.include?(file_path)

            {
              file: file_path,
              skills:
            }
          end
        end

        def report(warnings)
          puts "\n\u{1F4A1} Skill requires optimization suggestion:"
          puts '   These files are required by multiple skills but not in the profile.'
          puts "   Adding them to the recipe's files: list would make the dependency explicit.\n\n"

          warnings.each do |warning|
            puts "   \u{1F4C4} #{warning[:file]}"
            puts "      \u{2514}\u{2500} required by #{warning[:skills].size} skills: #{warning[:skills].join(', ')}"
          end

          puts "\n   Add these files to the recipe's `files:` list."
          puts ''
        end
      end
    end
  end
end
