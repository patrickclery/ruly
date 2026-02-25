# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/ruly/cli'

RSpec.describe Ruly::CLI, '#profile_tags' do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

  before do
    # Mock the gem_root to use our test directory

    # Create test directory structure
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'ruby'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'testing'))

    # Create profiles.yml
    profiles_content = <<~YAML
      profiles:
        test_profile:
          description: Test profile
          files:
            - rules/ruby/common.md
    YAML
    File.write(File.join(test_dir, 'profiles.yml'), profiles_content)
    allow(cli).to receive_messages(gem_root: test_dir, profiles_file: File.join(test_dir, 'profiles.yml'),
                                   rules_dir: File.join(test_dir, 'rules'))
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe '#scan_files_for_profile_tags' do
    it 'finds files with matching profile tag' do
      # Create a file with profile tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged.md'), <<~MD)
        ---
        description: Tagged file
        profiles:
          - test_profile
          - other_profile
        ---
        # Tagged File
      MD

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources.length).to eq(1)
      expect(sources[0][:path]).to eq('rules/ruby/tagged.md')
      expect(sources[0][:type]).to eq('local')
    end

    it 'excludes files without matching profile tag' do
      # Create a file without profile tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'untagged.md'), <<~MD)
        ---
        description: Untagged file
        ---
        # Untagged File
      MD

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources).to be_empty
    end

    it 'excludes files with different profile tag' do
      # Create a file with different profile tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'other.md'), <<~MD)
        ---
        description: Other profile file
        profiles:
          - other_profile
        ---
        # Other Profile File
      MD

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources).to be_empty
    end

    it 'handles files without frontmatter' do
      # Create a file without frontmatter
      File.write(File.join(test_dir, 'rules', 'ruby', 'no_frontmatter.md'), <<~MD)
        # No Frontmatter
        Just content
      MD

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources).to be_empty
    end

    it 'finds multiple files with matching profile tag' do
      # Create multiple files with profile tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged1.md'), <<~MD)
        ---
        description: Tagged file 1
        profiles:
          - test_profile
        ---
        # Tagged File 1
      MD

      File.write(File.join(test_dir, 'rules', 'testing', 'tagged2.md'), <<~MD)
        ---
        description: Tagged file 2
        profiles:
          - test_profile
        ---
        # Tagged File 2
      MD

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources.length).to eq(2)
      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/tagged1.md')
      expect(paths).to include('rules/testing/tagged2.md')
    end

    it 'returns empty array when rules directory does not exist' do
      allow(cli).to receive(:rules_dir).and_return('/nonexistent/path')

      sources = cli.send(:scan_files_for_profile_tags, 'test_profile')

      expect(sources).to be_empty
    end
  end

  describe '#load_profile_sources with profile tags' do
    it 'includes both profile.yml files and tagged files' do
      # Create a file that's in profile.yml
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common Ruby patterns
        ---
        # Common Ruby
      MD

      # Create a file with profile tag (not in profile.yml)
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged.md'), <<~MD)
        ---
        description: Tagged file
        profiles:
          - test_profile
        ---
        # Tagged File
      MD

      sources, = cli.send(:load_profile_sources, 'test_profile')

      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/common.md')
      expect(paths).to include('rules/ruby/tagged.md')
      expect(sources.length).to eq(2)
    end

    it 'deduplicates when file is in both profile.yml and has profile tag' do
      # Create a file that's in profile.yml AND has profile tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common Ruby patterns
        profiles:
          - test_profile
        ---
        # Common Ruby
      MD

      sources, = cli.send(:load_profile_sources, 'test_profile')

      paths = sources.map { |s| s[:path] }
      # Should only appear once despite being in both places
      expect(paths.count('rules/ruby/common.md')).to eq(1)
      expect(sources.length).to eq(1)
    end

    it 'includes tagged files not in profile.yml' do
      # Create multiple tagged files
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common Ruby patterns
        ---
        # Common Ruby
      MD

      File.write(File.join(test_dir, 'rules', 'ruby', 'extra1.md'), <<~MD)
        ---
        description: Extra file 1
        profiles:
          - test_profile
        ---
        # Extra 1
      MD

      File.write(File.join(test_dir, 'rules', 'ruby', 'extra2.md'), <<~MD)
        ---
        description: Extra file 2
        profiles:
          - test_profile
        ---
        # Extra 2
      MD

      sources, = cli.send(:load_profile_sources, 'test_profile')

      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/common.md')
      expect(paths).to include('rules/ruby/extra1.md')
      expect(paths).to include('rules/ruby/extra2.md')
      expect(sources.length).to eq(3)
    end
  end

  describe '#strip_metadata_from_frontmatter' do
    it 'strips profiles field from frontmatter' do
      content = <<~MD
        ---
        description: Test file
        profiles:
          - profile1
          - profile2
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('profiles:')
      expect(result).not_to include('profile1')
      expect(result).not_to include('profile2')
    end

    it 'strips requires field from frontmatter' do
      content = <<~MD
        ---
        description: Test file
        requires:
          - common.md
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

      expect(result).to include('description: Test file')
      expect(result).not_to include('requires:')
      expect(result).not_to include('common.md')
    end

    it 'strips both profiles and requires fields' do
      content = <<~MD
        ---
        description: Test file
        profiles:
          - test_profile
        requires:
          - common.md
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('profiles:')
      expect(result).not_to include('requires:')
      expect(result).not_to include('test_profile')
      expect(result).not_to include('common.md')
    end

    it 'removes frontmatter entirely if only profiles and requires remain' do
      content = <<~MD
        ---
        profiles:
          - test_profile
        requires:
          - common.md
        ---
        # Content
        Body text
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

      expect(result).not_to include('---')
      expect(result).to start_with("\n# Content")
    end

    it 'handles single-line profiles format' do
      content = <<~MD
        ---
        description: Test file
        profiles: [profile1, profile2]
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

      expect(result).to include('description: Test file')
      expect(result).not_to include('profiles:')
    end
  end
end
