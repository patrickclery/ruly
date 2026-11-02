# frozen_string_literal: true

require_relative '../../lib/ruly'
require 'tiktoken_ruby'
require 'json'
require 'yaml'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'optparse'
require 'rbconfig'
require 'shellwords'

# Benchmark harness for ruly: token counts of squashed output versus load-all and native layouts.
module RulyBench
  REPO_ROOT = File.expand_path('../..', __dir__)
  FIXTURE_CORPUS = File.join(REPO_ROOT, 'bench/fixtures/corpus')

  # Raised for harness failures (bad corpus, failed squash, invalid recipe name).
  class Error < StandardError; end
end

require_relative 'ruly_bench/token_counter'
require_relative 'ruly_bench/corpus'
require_relative 'ruly_bench/squash_runner'
require_relative 'ruly_bench/token_benchmark'
require_relative 'ruly_bench/tokens_cli'
require_relative 'ruly_bench/scorer'
require_relative 'ruly_bench/native_layout'
require_relative 'ruly_bench/claude_command'
require_relative 'ruly_bench/compliance_tasks'
require_relative 'ruly_bench/compliance_run'
require_relative 'ruly_bench/compliance_cli'
