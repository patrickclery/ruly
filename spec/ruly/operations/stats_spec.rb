# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Operations::Stats do
  let(:test_dir) { Dir.mktmpdir }
  let(:output_file) { File.join(test_dir, 'stats.md') }

  around do |example|
    original_dir = Dir.pwd

    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  def create_test_file(name, content)
    path = File.join(test_dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  describe '.call' do
    context 'with valid sources' do
      it 'returns success with file statistics' do
        file1 = create_test_file('rules/large.md', '# Large File' + "\n\nContent " * 100)
        file2 = create_test_file('rules/small.md', '# Small File')

        sources = [
          { path: file1, type: 'local' },
          { path: file2, type: 'local' }
        ]

        result = described_class.call(sources:, output_file:)

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(2)
        expect(result[:data][:total_tokens]).to be > 0
        expect(result[:data][:output_file]).to eq(output_file)
      end

      it 'generates a markdown file' do
        file1 = create_test_file('rules/test.md', '# Test Content')

        sources = [{ path: file1, type: 'local' }]

        described_class.call(sources:, output_file:)

        expect(File.exist?(output_file)).to be(true)
        content = File.read(output_file)
        expect(content).to include('# Ruly Token Statistics')
        expect(content).to include('## Summary')
        expect(content).to include('## Files by Token Count')
      end

      it 'sorts files by token count descending' do
        large_file = create_test_file('rules/large.md', '# Large' + "\nContent " * 500)
        small_file = create_test_file('rules/small.md', '# Small')

        sources = [
          { path: small_file, type: 'local' },
          { path: large_file, type: 'local' }
        ]

        result = described_class.call(sources:, output_file:)
        files = result[:data][:files]

        expect(files.first[:tokens]).to be > files.last[:tokens]
        expect(files.first[:path]).to eq(large_file)
      end

      it 'includes file sizes in the output' do
        file1 = create_test_file('rules/test.md', 'Some test content here')

        sources = [{ path: file1, type: 'local' }]

        described_class.call(sources:, output_file:)

        content = File.read(output_file)
        expect(content).to match(/\d+(\.\d+)?\s*(B|KB|MB)/)
      end
    end

    context 'with empty sources' do
      it 'returns success with zero counts' do
        result = described_class.call(sources: [], output_file:)

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(0)
        expect(result[:data][:total_tokens]).to eq(0)
      end

      it 'generates a valid markdown file' do
        described_class.call(sources: [], output_file:)

        expect(File.exist?(output_file)).to be(true)
        content = File.read(output_file)
        expect(content).to include('**Total Files**: 0')
      end
    end

    context 'with non-local sources' do
      it 'skips remote sources' do
        local_file = create_test_file('rules/local.md', '# Local')

        sources = [
          { path: local_file, type: 'local' },
          { path: 'https://example.com/remote.md', type: 'remote' }
        ]

        result = described_class.call(sources:, output_file:)

        expect(result[:data][:file_count]).to eq(1)
      end
    end

    context 'with missing files' do
      it 'skips files that do not exist' do
        existing_file = create_test_file('rules/exists.md', '# Exists')

        sources = [
          { path: existing_file, type: 'local' },
          { path: '/nonexistent/file.md', type: 'local' }
        ]

        result = described_class.call(sources:, output_file:)

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(1)
      end
    end
  end

  describe '#build_file_stats' do
    it 'returns an array of file statistics' do
      file1 = create_test_file('rules/test.md', '# Test')

      sources = [{ path: file1, type: 'local' }]
      operation = described_class.new(sources:, output_file:)
      stats = operation.build_file_stats

      expect(stats).to be_an(Array)
      expect(stats.first).to include(:path, :tokens, :size)
    end

    it 'calculates tokens using tiktoken' do
      file1 = create_test_file('rules/test.md', 'Hello world')

      sources = [{ path: file1, type: 'local' }]
      operation = described_class.new(sources:, output_file:)
      stats = operation.build_file_stats

      # "Hello world" should be ~2 tokens
      expect(stats.first[:tokens]).to be_between(1, 5)
    end
  end

  describe 'number formatting' do
    it 'formats large numbers with commas' do
      # Create a large file to get a significant token count
      large_content = 'word ' * 10_000
      large_file = create_test_file('rules/large.md', large_content)

      sources = [{ path: large_file, type: 'local' }]

      described_class.call(sources:, output_file:)

      content = File.read(output_file)
      # Should have comma-formatted numbers
      expect(content).to match(/\d{1,3}(,\d{3})+/)
    end
  end

  describe 'byte formatting' do
    it 'formats bytes as B for small files' do
      small_file = create_test_file('rules/tiny.md', 'Hi')

      sources = [{ path: small_file, type: 'local' }]

      described_class.call(sources:, output_file:)

      content = File.read(output_file)
      expect(content).to include(' B')
    end

    it 'formats bytes as KB for medium files' do
      medium_content = 'x' * 2000
      medium_file = create_test_file('rules/medium.md', medium_content)

      sources = [{ path: medium_file, type: 'local' }]

      described_class.call(sources:, output_file:)

      content = File.read(output_file)
      expect(content).to include(' KB')
    end
  end
end
