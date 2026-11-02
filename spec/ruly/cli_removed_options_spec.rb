# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::CLI, '.start' do
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd
    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      # CRITICAL: Always return to original directory before ANY cleanup
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  def expect_unknown_switch(args, switch)
    expect do
      expect { described_class.start(args) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end.to output(/Unknown switches "#{Regexp.escape(switch)}"/).to_stderr
  end

  context 'with the removed --cache switch' do
    it 'rejects squash --cache' do
      expect_unknown_switch(%w[squash --cache], '--cache')
    end

    it 'rejects squash --no-cache' do
      expect_unknown_switch(%w[squash --no-cache], '--no-cache')
    end
  end

  context 'with kept switches' do
    it 'still parses clean --dry-run' do
      expect { described_class.start(%w[clean --dry-run]) }.to output(/Already clean/).to_stdout
    end
  end
end
