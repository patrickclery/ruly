# frozen_string_literal: true

require 'spec_helper'
require_relative '../../bench/lib/ruly_bench'

# Guards the published token figures against drift: the committed results must equal a fresh run, and the
# figures copied by hand into the docs, the README and the patterns note must equal the committed results.
RSpec.describe 'published token benchmark figures' do # rubocop:disable RSpec/DescribeClass
  root = RulyBench::REPO_ROOT
  read = ->(rel) { File.read(File.join(root, rel), encoding: 'UTF-8') }
  committed = JSON.parse(read.call('bench/results/tokens.json'))
  docs = read.call('docs/benchmarks.md')
  readme = read.call('README.md')
  patterns = read.call('.claude/ruly-recipes-mcp-patterns.md')
  pct = ->(value) { format('%.1f%%', value) }
  tokens = ->(num) { Ruly::Operations::Stats.format_number(num) }
  stats = lambda do |summary, baseline|
    s = summary["reduction_vs_#{baseline}_pct"]
    [s['median'], s['min'], s['max']].map(&pct)
  end
  names = {'load_all' => 'vs load-all', 'native_ceiling' => 'vs native ceiling', 'native_floor' => 'vs native floor'}
  # Table rows as arrays of stripped cells, so column padding does not matter.
  table_rows = ->(text) { text.lines.grep(/\A\|/).map { |line| line.strip.delete_prefix('|').split('|').map(&:strip) } }

  it 'commits tokens.json and tokens.md equal to a fresh fixture run, ruly version aside' do
    Dir.mktmpdir('ruly-bench-fresh') do |out_dir|
      status = RulyBench::TokensCLI.new(['--output-dir', out_dir], err: StringIO.new, out: StringIO.new).run
      expect(status).to eq(0)

      fresh = JSON.parse(File.read(File.join(out_dir, 'tokens.json')))
      expect(fresh.except('ruly_version')).to eq(committed.except('ruly_version'))
      version = /ruly \d+\.\d+\.\d+\S*\./
      expect(File.read(File.join(out_dir, 'tokens.md'), encoding: 'UTF-8').sub(version, 'ruly X.'))
        .to eq(read.call('bench/results/tokens.md').sub(version, 'ruly X.'))
    end
  end

  describe 'docs/benchmarks.md' do
    rows = table_rows.call(docs)

    it 'holds every per-recipe row of tokens.json' do
      committed['recipes'].each do |r|
        cells = [r['name']] + RulyBench::TokenBenchmark::TOKEN_COLUMNS.map { tokens.call(r[_1]) } +
                RulyBench::TokenBenchmark::REDUCTION_KEYS.values.map { pct.call(r[_1]) }
        expect(rows).to include(cells)
      end
    end

    it 'gives the summary medians and ranges of tokens.json' do
      RulyBench::TokenBenchmark::BASELINES.each do |b|
        expect(rows).to include([names[b], *stats.call(committed['summary'], b)])
      end
    end

    it 'gives the baselines and reductions without the files in no recipe' do
      excl = committed['excluding_unreferenced']
      RulyBench::TokenBenchmark::BASELINES.each do |b|
        expect(rows).to include([names[b], tokens.call(excl['baselines'][b]), *stats.call(excl['summary'], b)])
      end
      expect(docs).to include("(#{tokens.call(excl['tokens'])} tokens)")
      excl['files'].each { |f| expect(docs).to include("`#{f}`") }
    end

    it 'states the headline medians and ranges in prose' do
      s = committed['summary']
      la, floor, ceiling = %w[load_all native_floor native_ceiling].map { stats.call(s, _1) }
      expect(docs).to include("a median of #{la[0]} smaller than loading every rule (range #{la[1]} to #{la[2]} ")
      expect(docs).to include("a median of #{floor[0]} smaller than the native floor (range #{floor[1]} to " \
                              "#{floor[2]}) and #{ceiling[0]} smaller than the native ceiling " \
                              "(range #{ceiling[1]} to #{ceiling[2]})")
    end
  end

  it 'gives the README token row the tokens.json medians' do
    s = committed['summary']
    excl = committed['excluding_unreferenced']['summary']
    expect(readme).to include("was #{pct.call(s['reduction_vs_load_all_pct']['median'])} smaller than loading " \
                              "every rule (median), and #{pct.call(s['reduction_vs_native_floor_pct']['median'])} " \
                              "smaller than a native layout's always-loaded set " \
                              "(#{pct.call(excl['reduction_vs_native_floor_pct']['median'])} if")
  end

  it 'gives every benchmark line of the patterns note the load-all median' do
    lines = patterns.lines.grep(%r{docs/benchmarks\.md})
    expect(lines.size).to eq(3)
    median = pct.call(committed['summary']['reduction_vs_load_all_pct']['median'])
    lines.each do |line|
      expect(line).to include(median)
      expect(line.scan(/\d+\.\d%/)).to eq([median])
      expect(line).to include('synthetic fixture corpus')
    end
  end
end
