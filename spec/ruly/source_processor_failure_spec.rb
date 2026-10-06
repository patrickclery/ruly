# frozen_string_literal: true

require 'spec_helper'
require 'ruly/services/source_processor'

# Regression coverage for the "silent source drop" bug.
#
# Before this behaviour existed, a source listed explicitly in a recipe that
# could not be fetched (e.g. renamed upstream -> 404) was warned about on
# stderr and then dropped, while squash still exited 0. That produced a subtly
# degraded artifact with no machine-detectable signal.
RSpec.describe Ruly::Services::SourceProcessor do
  before { described_class.reset_failed_sources! }
  after  { described_class.reset_failed_sources! }

  describe '.reset_failed_sources!' do
    it 'starts empty' do
      expect(described_class.failed_sources).to eq([])
    end

    it 'clears previously recorded failures' do
      described_class.record_failed_source({path: 'a.md', type: 'remote'}, 'fetch failed')
      expect { described_class.reset_failed_sources! }
        .to change { described_class.failed_sources.length }.from(1).to(0)
    end
  end

  describe '.record_failed_source' do
    it 'captures path, type and reason' do
      described_class.record_failed_source({path: 'home/gone.md', type: 'remote'}, 'fetch failed')

      expect(described_class.failed_sources.first).to include(
        path: 'home/gone.md', reason: 'fetch failed', type: 'remote'
      )
    end

    it 'marks explicitly-listed sources as not from_requires' do
      described_class.record_failed_source({path: 'explicit.md', type: 'remote'}, 'fetch failed')
      expect(described_class.failed_sources.first[:from_requires]).to be(false)
    end

    it 'preserves the from_requires flag for transitive sources' do
      described_class.record_failed_source(
        {from_requires: true, path: 'dep.md', type: 'local'}, 'file not found'
      )
      expect(described_class.failed_sources.first[:from_requires]).to be(true)
    end

    it 'accumulates across calls so a parent squash sees subagent failures' do
      described_class.record_failed_source({path: 'one.md', type: 'remote'}, 'fetch failed')
      described_class.record_failed_source({path: 'two.md', type: 'remote'}, 'fetch failed')

      expect(described_class.failed_sources.map { |f| f[:path] }).to eq(%w[one.md two.md])
    end
  end

  describe '.explicit_failed_sources' do
    before do
      described_class.record_failed_source({path: 'explicit.md', type: 'remote'}, 'fetch failed')
      described_class.record_failed_source(
        {from_requires: true, path: 'transitive.md', type: 'remote'}, 'fetch failed'
      )
    end

    it 'returns only sources listed directly in a recipe' do
      expect(described_class.explicit_failed_sources.map { |f| f[:path] }).to eq(['explicit.md'])
    end

    it 'excludes transitive requires: failures, which stay non-fatal by default' do
      expect(described_class.explicit_failed_sources.map { |f| f[:path] })
        .not_to include('transitive.md')
    end

    it 'is empty when every failure came from requires:' do
      described_class.reset_failed_sources!
      described_class.record_failed_source(
        {from_requires: true, path: 'only-transitive.md', type: 'local'}, 'file not found'
      )

      expect(described_class.explicit_failed_sources).to be_empty
      expect(described_class.failed_sources).not_to be_empty
    end
  end
end
