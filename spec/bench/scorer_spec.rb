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

    it 'reads fences indented by up to three spaces and strips that indentation from the content' do
      reply = "I avoided puts here.\n   ```ruby\n   logger.info('x')\n     nested\n   ```\nDone.\n"
      expect(described_class.scope(reply, 'code')).to eq("logger.info('x')\n  nested")
      expect(described_class.score(reply, [check('forbid', 'code', '\\bputs\\b')])[:pass]).to be(true)
    end

    it 'does not treat a line indented by four spaces as a fence' do
      expect(described_class.scope("    ```\nputs 1\n    ```\n", 'code')).to eq("    ```\nputs 1\n    ```\n")
    end

    it 'closes a fence only with the same character, at least as long, indented at most three spaces' do
      reply = "````\na\n```\n~~~~\n    ````\nb\n   `````  \nprose\n"
      expect(described_class.scope(reply, 'code')).to eq("a\n```\n~~~~\n    ````\nb")
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

  describe 'the committed ruby-single-quotes check' do
    tasks = YAML.safe_load_file(RulyBench::ComplianceCLI::DEFAULT_TASKS)['tasks']
    checks = tasks.find { _1['id'] == 'ruby-single-quotes' }['checks']

    # One Ruby line per case; the heredocs keep `#{` literal.
    passing = <<~'RUBY'.lines(chomp: true)
      log("#{a}", "#{b}")
      line = "total\n"
      say = "a \"quoted\" word"
      x = 'ok' # never "double" here
      v = "#{h["key"]}"
      LABELS = ['draft', 'sent'].freeze
    RUBY
    failing = <<~'RUBY'.lines(chomp: true)
      name = "draft"
      log("#{a}", "b")
      pair = ['a', "b"]
    RUBY

    passing.each do |code|
      it "passes #{code}" do
        expect(described_class.score("```ruby\n#{code}\n```\n", checks)[:pass]).to be(true)
      end
    end

    failing.each do |code|
      it "fails #{code}" do
        expect(described_class.score("```ruby\n#{code}\n```\n", checks)[:pass]).to be(false)
      end
    end
  end

  describe 'the committed react-named-export checks' do
    tasks = YAML.safe_load_file(RulyBench::ComplianceCLI::DEFAULT_TASKS)['tasks']
    checks = tasks.find { _1['id'] == 'react-named-export' }['checks']

    {
      'an export list' => "function UserBadge() { return null; }\nexport { UserBadge };",
      'export const' => 'export const UserBadge = () => null;',
      'export function' => 'export function UserBadge() { return null; }'
    }.each do |name, code|
      it "passes #{name}" do
        expect(described_class.score("```tsx\n#{code}\n```\n", checks)[:pass]).to be(true)
      end
    end

    {
      'an export list renaming to default' => "function UserBadge() { return null; }\nexport { UserBadge as default };",
      'export default' => 'export default function UserBadge() { return null; }',
      'no export' => 'function UserBadge() { return null; }'
    }.each do |name, code|
      it "fails #{name}" do
        expect(described_class.score("```tsx\n#{code}\n```\n", checks)[:pass]).to be(false)
      end
    end
  end
end
