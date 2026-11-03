# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench::TokenCounter do
  let(:stats) { Ruly::Operations::Stats.new(sources: []) }

  it 'uses the cl100k_base encoding' do
    expect(described_class::ENCODING).to eq('cl100k_base')
  end

  it 'matches Stats#count_tokens for an ASCII string' do
    text = 'Use single quotes for Ruby string literals that contain no interpolation.'
    expect(described_class.count(text)).to eq(stats.send(:count_tokens, text))
  end

  it 'matches Stats#count_tokens for a string with emoji' do
    text = "Ship it \u{1F680} then celebrate \u{1F389}"
    expect(described_class.count(text)).to eq(stats.send(:count_tokens, text))
  end

  it 'matches Stats#count_tokens for a string with an invalid UTF-8 byte' do
    text = "abc\xFFdef".dup.force_encoding('UTF-8')
    expect(text.valid_encoding?).to be(false)
    expect(described_class.count(text)).to eq(stats.send(:count_tokens, text))
  end

  it 'matches Stats#count_tokens for a binary string with a high byte' do
    text = "abc\xFFdef".b
    expect(described_class.count(text)).to eq(stats.send(:count_tokens, text))
  end
end
