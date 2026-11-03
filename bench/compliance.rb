# frozen_string_literal: true

require_relative 'lib/ruly_bench'

exit RulyBench::ComplianceCLI.new(ARGV).run
