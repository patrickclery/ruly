# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

RSpec.describe RulyBench::Scorer do
  def check(type, scope, pattern)
    {'pattern' => pattern, 'scope' => scope, 'type' => type}
  end

  describe '.scope' do
    it 'joins the contents of every fenced block with a newline, whatever the fence' do
      reply = "Here:\n```ruby\nputs 1\n```\nand\n~~~\nputs 2\n~~~\nDone.\n"
      expect(described_class.scope(reply, 'code')).to eq("puts 1\nputs 2")
    end

    it 'falls back to the whole reply when there is no fence' do
      expect(described_class.scope("plain reply\n", 'code')).to eq("plain reply\n")
    end

    it 'takes the first non-blank line of the code scope, stripped' do
      expect(described_class.scope("\n\n  feat(api): add retry  \nbody\n", 'first_line')).to eq('feat(api): add retry')
    end

    it 'returns the whole reply for text' do
      expect(described_class.scope("a\n```\nb\n```\n", 'text')).to eq("a\n```\nb\n```\n")
    end

    it 'raises on an unknown scope' do
      expect { described_class.scope('x', 'title') }.to raise_error(RulyBench::Error, /unknown scope/)
    end
  end

  describe '.score' do
    it 'passes a forbid check when the pattern does not match' do
      expect(described_class.score('ok', [check('forbid', 'text', 'puts')])).to eq(failed: [], pass: true)
    end

    it 'passes a require check when the pattern matches' do
      expect(described_class.score('expect(x)', [check('require', 'text', 'expect')])[:pass]).to be(true)
    end

    it 'names type, scope and pattern of every failed check' do
      result = described_class.score('puts 1', [check('forbid', 'code', '\bputs\b'), check('require', 'text', 'zzz')])
      expect(result).to eq(failed: ['forbid code /\bputs\b/', 'require text /zzz/'], pass: false)
    end
  end
end
