# frozen_string_literal: true

module RulyBench
  # Deterministic checks on a model reply: each check is a regex that must (require) or must not (forbid) match
  # one scope of the reply.
  module Scorer
    FENCE = /\A(`{3,}|~{3,})/
    SCOPES = %w[code first_line text].freeze
    TYPES = %w[forbid require].freeze

    module_function

    # @param reply [String]
    # @param name [String] 'text' (whole reply), 'code' (fenced blocks joined, or the whole reply when there is
    #   none) or 'first_line' (first non-blank line of the code scope, stripped)
    # @return [String]
    def scope(reply, name)
      case name
      when 'text' then reply
      when 'code' then code(reply)
      when 'first_line' then code(reply).lines.map(&:strip).find { |line| !line.empty? }.to_s
      else raise Error, "unknown scope #{name.inspect}"
      end
    end

    # @param reply [String]
    # @param checks [Array<Hash>] 'type', 'scope' and 'pattern' (string keys)
    # @return [Hash] failed: descriptions of the failed checks, pass: true when none failed
    def score(reply, checks)
      failed = checks.reject { |check| passes?(reply, check) }.map { |check| describe(check) }
      {failed:, pass: failed.empty?}
    end

    def passes?(reply, check)
      matched = Regexp.new(check['pattern']).match?(scope(reply, check['scope']))
      check['type'] == 'require' ? matched : !matched
    end

    def describe(check)
      "#{check['type']} #{check['scope']} /#{check['pattern']}/"
    end

    # Contents of every fenced block (``` or ~~~, optional info string), joined by newlines.
    def code(reply)
      blocks = fenced_blocks(reply)
      blocks.empty? ? reply : blocks.map(&:chomp).join("\n")
    end

    def fenced_blocks(reply)
      blocks = []
      fence = nil
      reply.each_line do |line|
        if fence.nil?
          fence = line[FENCE, 1]
          blocks << +'' if fence
        elsif closing_fence?(line, fence)
          fence = nil
        else
          blocks.last << line
        end
      end
      blocks
    end

    def closing_fence?(line, fence)
      stripped = line.strip
      stripped.length >= fence.length && stripped.delete(fence[0]).empty?
    end
  end
end
