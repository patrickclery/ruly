# frozen_string_literal: true

module RulyBench
  # Counts tokens with tiktoken cl100k_base, scrubbing text to UTF-8 exactly as Ruly::Operations::Stats does.
  module TokenCounter
    ENCODING = 'cl100k_base'

    module_function

    # @param text [String]
    # @return [Integer] number of cl100k_base tokens
    def count(text)
      utf8_text = text.encode('UTF-8', invalid: :replace, replace: '?', undef: :replace)
      encoder.encode(utf8_text).length
    end

    def encoder
      @encoder ||= Tiktoken.get_encoding(ENCODING)
    end
  end
end
