# frozen_string_literal: true

module Ruly
  module Operations
    # Base class for all CLI operations
    class Base
      class << self
        # Override in subclasses to perform the actual operation
        # @return [Hash] Result hash with :success and optional :data keys
        def call(...)
          new(...).call
        end
      end

      def call
        raise NotImplementedError, 'Subclasses must implement #call'
      end

      protected

      def build_result(success:, data: nil, error: nil)
        {
          data:,
          error:,
          success:
        }
      end
    end
  end
end
