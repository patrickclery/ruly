# frozen_string_literal: true

module Ruly
  module Checks
    # Base class for all post-squash validation checks
    class Base
      class << self
        # Override in subclasses to perform the actual check
        # @param local_sources [Array<Hash>] Array of source hashes with :path and :content
        # @param command_files [Array<Hash>] Array of command file hashes with :path and :content
        # @return [Hash] Result hash with :passed, :errors, and :warnings keys
        def call(local_sources, command_files = [])
          raise NotImplementedError, 'Subclasses must implement .call'
        end

        protected

        def build_result(errors: [], warnings: [])
          {
            errors:,
            passed: errors.empty?,
            warnings:
          }
        end
      end
    end
  end
end
