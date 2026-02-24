# frozen_string_literal: true

require_relative 'checks/base'
require_relative 'checks/ambiguous_links'
require_relative 'checks/duplicate_skill_requires'

module Ruly
  # Post-squash validation checks
  module Checks
    # Run all checks and return true if all passed
    def self.run_all(local_sources, command_files = [], skill_files: [], # rubocop:disable Naming/PredicateMethod,Metrics/ParameterLists
                     find_rule_file: nil, parse_frontmatter: nil, profile_paths: Set.new)
      check_classes = [
        AmbiguousLinks
      ]

      results = check_classes.map do |check_class|
        result = check_class.call(local_sources, command_files)
        result[:passed]
      end

      # Skill-specific checks (only if we have the deps)
      if skill_files.any? && find_rule_file && parse_frontmatter
        DuplicateSkillRequires.call(skill_files, find_rule_file:, parse_frontmatter:,
                                                 profile_paths:)
      end

      results.all?
    end
  end
end
