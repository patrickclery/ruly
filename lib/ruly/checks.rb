# frozen_string_literal: true

require_relative 'checks/base'
require_relative 'checks/ambiguous_links'

module Ruly
  # Post-squash validation checks
  module Checks
    # Run all checks and return true if all passed
    def self.run_all(local_sources, command_files = []) # rubocop:disable Naming/PredicateMethod
      check_classes = [
        AmbiguousLinks
      ]

      results = check_classes.map do |check_class|
        result = check_class.call(local_sources, command_files)
        result[:passed]
      end

      results.all?
    end
  end
end
