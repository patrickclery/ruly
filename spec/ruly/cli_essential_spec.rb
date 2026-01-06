# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/ruly/cli'

RSpec.describe Ruly::CLI, '#essential' do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

  before do
    # Mock the gem_root to use our test directory

    # Create test directory structure
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'ruby'))
    FileUtils.mkdir_p(File.join(test_dir, 'rules', 'testing'))

    # Create recipes.yml
    recipes_content = <<~YAML
      recipes:
        test_recipe:
          description: Test recipe
          files:
            - rules/ruby/common.md
            - rules/ruby/extra.md
    YAML
    File.write(File.join(test_dir, 'recipes.yml'), recipes_content)
    allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'),
                                   rules_dir: File.join(test_dir, 'rules'))
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe '#filter_essential_sources' do
    it 'filters to only files with essential: true' do
      # Create essential file
      File.write(File.join(test_dir, 'rules', 'ruby', 'essential.md'), <<~MD)
        ---
        description: Essential file
        essential: true
        ---
        # Essential Content
      MD

      # Create non-essential file
      File.write(File.join(test_dir, 'rules', 'ruby', 'optional.md'), <<~MD)
        ---
        description: Optional file
        ---
        # Optional Content
      MD

      sources = [
        {path: 'rules/ruby/essential.md', type: 'local'},
        {path: 'rules/ruby/optional.md', type: 'local'}
      ]

      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered.length).to eq(1)
      expect(filtered[0][:path]).to eq('rules/ruby/essential.md')
    end

    it 'excludes files without essential field' do
      File.write(File.join(test_dir, 'rules', 'ruby', 'no_essential.md'), <<~MD)
        ---
        description: File without essential field
        ---
        # Content
      MD

      sources = [{path: 'rules/ruby/no_essential.md', type: 'local'}]
      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered).to be_empty
    end

    it 'excludes files with essential: false' do
      File.write(File.join(test_dir, 'rules', 'ruby', 'not_essential.md'), <<~MD)
        ---
        description: Explicitly not essential
        essential: false
        ---
        # Content
      MD

      sources = [{path: 'rules/ruby/not_essential.md', type: 'local'}]
      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered).to be_empty
    end

    it 'handles files without frontmatter' do
      File.write(File.join(test_dir, 'rules', 'ruby', 'no_frontmatter.md'), <<~MD)
        # No Frontmatter
        Just content
      MD

      sources = [{path: 'rules/ruby/no_frontmatter.md', type: 'local'}]
      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered).to be_empty
    end

    it 'filters multiple files correctly' do
      # Create multiple files with mixed essential status
      File.write(File.join(test_dir, 'rules', 'ruby', 'essential1.md'), <<~MD)
        ---
        description: Essential 1
        essential: true
        ---
        # Essential 1
      MD

      File.write(File.join(test_dir, 'rules', 'ruby', 'optional1.md'), <<~MD)
        ---
        description: Optional 1
        ---
        # Optional 1
      MD

      File.write(File.join(test_dir, 'rules', 'testing', 'essential2.md'), <<~MD)
        ---
        description: Essential 2
        essential: true
        ---
        # Essential 2
      MD

      sources = [
        {path: 'rules/ruby/essential1.md', type: 'local'},
        {path: 'rules/ruby/optional1.md', type: 'local'},
        {path: 'rules/testing/essential2.md', type: 'local'}
      ]

      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered.length).to eq(2)
      paths = filtered.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/essential1.md')
      expect(paths).to include('rules/testing/essential2.md')
      expect(paths).not_to include('rules/ruby/optional1.md')
    end

    it 'skips remote sources' do
      sources = [
        {path: 'https://example.com/file.md', type: 'remote'}
      ]

      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered).to be_empty
    end

    it 'returns empty array when no files are essential' do
      File.write(File.join(test_dir, 'rules', 'ruby', 'optional.md'), <<~MD)
        ---
        description: Optional file
        ---
        # Optional Content
      MD

      sources = [{path: 'rules/ruby/optional.md', type: 'local'}]
      filtered = cli.send(:filter_essential_sources, sources)

      expect(filtered).to be_empty
    end
  end

  describe 'integration: squash with --essential and requires' do
    it 'includes essential files and their required dependencies' do
      # Create base file (not essential)
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common patterns
        ---
        # Common Ruby
      MD

      # Create essential file that requires common.md
      File.write(File.join(test_dir, 'rules', 'ruby', 'essential.md'), <<~MD)
        ---
        description: Essential patterns
        essential: true
        requires:
          - common.md
        ---
        # Essential Ruby
      MD

      # Create non-essential file
      File.write(File.join(test_dir, 'rules', 'ruby', 'extra.md'), <<~MD)
        ---
        description: Extra patterns
        ---
        # Extra Ruby
      MD

      options = {
        agent: 'claude',
        cache: false,
        clean: false,
        deepclean: false,
        dry_run: false,
        essential: true,
        git_exclude: false,
        git_ignore: false,
        output_file: 'output.md',
        toc: false
      }
      allow(cli).to receive(:options).and_return(options)

      sources = [
        {path: 'rules/ruby/common.md', type: 'local'},
        {path: 'rules/ruby/essential.md', type: 'local'},
        {path: 'rules/ruby/extra.md', type: 'local'}
      ]

      # First filter to essential only
      filtered_sources = cli.send(:filter_essential_sources, sources)
      expect(filtered_sources.length).to eq(1)
      expect(filtered_sources[0][:path]).to eq('rules/ruby/essential.md')

      # Then process with requires (which should add common.md)
      local_sources, = cli.send(:process_sources_for_squash, filtered_sources, 'claude', {}, options)

      paths = local_sources.map { |s| s[:path] }

      # Should have essential.md
      expect(paths).to include('rules/ruby/essential.md')
      # Should have common.md pulled in by requires (even though not essential)
      expect(paths.any? { |p| p.end_with?('common.md') }).to be(true)
      # Should NOT have extra.md (not essential, not required)
      expect(paths).not_to include('rules/ruby/extra.md')
    end

    it 'excludes non-essential files even if they are in recipe' do
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common patterns
        ---
        # Common Ruby (in recipe but not essential)
      MD

      File.write(File.join(test_dir, 'rules', 'ruby', 'extra.md'), <<~MD)
        ---
        description: Extra patterns
        essential: true
        ---
        # Extra Ruby (essential)
      MD

      options = {
        agent: 'claude',
        cache: false,
        clean: false,
        deepclean: false,
        dry_run: false,
        essential: true,
        git_exclude: false,
        git_ignore: false,
        output_file: 'output.md',
        toc: false
      }
      allow(cli).to receive(:options).and_return(options)

      sources, = cli.send(:load_recipe_sources, 'test_recipe')

      # Both files should be in sources from recipe
      expect(sources.length).to eq(2)

      # After filtering, only essential file remains
      filtered_sources = cli.send(:filter_essential_sources, sources)
      expect(filtered_sources.length).to eq(1)
      expect(filtered_sources[0][:path]).to eq('rules/ruby/extra.md')
    end
  end

  describe '#strip_metadata_from_frontmatter with essential' do
    it 'strips essential: true from frontmatter' do
      content = <<~MD
        ---
        description: Test file
        essential: true
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('essential:')
      expect(result).not_to include('essential: true')
    end

    it 'strips essential: false from frontmatter' do
      content = <<~MD
        ---
        description: Test file
        essential: false
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).not_to include('essential:')
    end

    it 'strips essential along with recipes and requires' do
      content = <<~MD
        ---
        description: Test file
        recipes:
          - test_recipe
        requires:
          - common.md
        essential: true
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('recipes:')
      expect(result).not_to include('requires:')
      expect(result).not_to include('essential:')
    end

    it 'removes frontmatter entirely if only essential remains' do
      content = <<~MD
        ---
        essential: true
        ---
        # Content
        Body text
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).not_to include('---')
      expect(result).to start_with("\n# Content")
    end
  end
end
