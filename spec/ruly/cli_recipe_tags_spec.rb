# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/ruly/cli'

RSpec.describe Ruly::CLI, '#recipe_tags' do
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
    YAML
    File.write(File.join(test_dir, 'recipes.yml'), recipes_content)
    allow(cli).to receive_messages(gem_root: test_dir, recipes_file: File.join(test_dir, 'recipes.yml'),
                                   rules_dir: File.join(test_dir, 'rules'))
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe '#scan_files_for_recipe_tags' do
    it 'finds files with matching recipe tag' do
      # Create a file with recipe tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged.md'), <<~MD)
        ---
        description: Tagged file
        recipes:
          - test_recipe
          - other_recipe
        ---
        # Tagged File
      MD

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources.length).to eq(1)
      expect(sources[0][:path]).to eq('rules/ruby/tagged.md')
      expect(sources[0][:type]).to eq('local')
    end

    it 'excludes files without matching recipe tag' do
      # Create a file without recipe tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'untagged.md'), <<~MD)
        ---
        description: Untagged file
        ---
        # Untagged File
      MD

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources).to be_empty
    end

    it 'excludes files with different recipe tag' do
      # Create a file with different recipe tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'other.md'), <<~MD)
        ---
        description: Other recipe file
        recipes:
          - other_recipe
        ---
        # Other Recipe File
      MD

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources).to be_empty
    end

    it 'handles files without frontmatter' do
      # Create a file without frontmatter
      File.write(File.join(test_dir, 'rules', 'ruby', 'no_frontmatter.md'), <<~MD)
        # No Frontmatter
        Just content
      MD

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources).to be_empty
    end

    it 'finds multiple files with matching recipe tag' do
      # Create multiple files with recipe tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged1.md'), <<~MD)
        ---
        description: Tagged file 1
        recipes:
          - test_recipe
        ---
        # Tagged File 1
      MD

      File.write(File.join(test_dir, 'rules', 'testing', 'tagged2.md'), <<~MD)
        ---
        description: Tagged file 2
        recipes:
          - test_recipe
        ---
        # Tagged File 2
      MD

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources.length).to eq(2)
      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/tagged1.md')
      expect(paths).to include('rules/testing/tagged2.md')
    end

    it 'returns empty array when rules directory does not exist' do
      allow(cli).to receive(:rules_dir).and_return('/nonexistent/path')

      sources = cli.send(:scan_files_for_recipe_tags, 'test_recipe')

      expect(sources).to be_empty
    end
  end

  describe '#load_recipe_sources with recipe tags' do
    it 'includes both recipe.yml files and tagged files' do
      # Create a file that's in recipe.yml
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common Ruby patterns
        ---
        # Common Ruby
      MD

      # Create a file with recipe tag (not in recipe.yml)
      File.write(File.join(test_dir, 'rules', 'ruby', 'tagged.md'), <<~MD)
        ---
        description: Tagged file
        recipes:
          - test_recipe
        ---
        # Tagged File
      MD

      sources, = cli.send(:load_recipe_sources, 'test_recipe')

      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/common.md')
      expect(paths).to include('rules/ruby/tagged.md')
      expect(sources.length).to eq(2)
    end

    it 'deduplicates when file is in both recipe.yml and has recipe tag' do
      # Create a file that's in recipe.yml AND has recipe tag
      File.write(File.join(test_dir, 'rules', 'ruby', 'common.md'), <<~MD)
        ---
        description: Common Ruby patterns
        recipes:
          - test_recipe
        ---
        # Common Ruby
      MD

      sources, = cli.send(:load_recipe_sources, 'test_recipe')

      paths = sources.map { |s| s[:path] }
      # Should only appear once despite being in both places
      expect(paths.count('rules/ruby/common.md')).to eq(1)
      expect(sources.length).to eq(1)
    end

    it 'includes tagged files not in recipe.yml' do
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
        recipes:
          - test_recipe
        ---
        # Extra 1
      MD

      File.write(File.join(test_dir, 'rules', 'ruby', 'extra2.md'), <<~MD)
        ---
        description: Extra file 2
        recipes:
          - test_recipe
        ---
        # Extra 2
      MD

      sources, = cli.send(:load_recipe_sources, 'test_recipe')

      paths = sources.map { |s| s[:path] }
      expect(paths).to include('rules/ruby/common.md')
      expect(paths).to include('rules/ruby/extra1.md')
      expect(paths).to include('rules/ruby/extra2.md')
      expect(sources.length).to eq(3)
    end
  end

  describe '#strip_metadata_from_frontmatter' do
    it 'strips recipes field from frontmatter' do
      content = <<~MD
        ---
        description: Test file
        recipes:
          - recipe1
          - recipe2
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('recipes:')
      expect(result).not_to include('recipe1')
      expect(result).not_to include('recipe2')
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

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).not_to include('requires:')
      expect(result).not_to include('common.md')
    end

    it 'strips both recipes and requires fields' do
      content = <<~MD
        ---
        description: Test file
        recipes:
          - test_recipe
        requires:
          - common.md
        other_field: value
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).to include('other_field: value')
      expect(result).not_to include('recipes:')
      expect(result).not_to include('requires:')
      expect(result).not_to include('test_recipe')
      expect(result).not_to include('common.md')
    end

    it 'removes frontmatter entirely if only recipes and requires remain' do
      content = <<~MD
        ---
        recipes:
          - test_recipe
        requires:
          - common.md
        ---
        # Content
        Body text
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).not_to include('---')
      expect(result).to start_with("\n# Content")
    end

    it 'handles single-line recipes format' do
      content = <<~MD
        ---
        description: Test file
        recipes: [recipe1, recipe2]
        ---
        # Content
      MD

      result = cli.send(:strip_metadata_from_frontmatter, content)

      expect(result).to include('description: Test file')
      expect(result).not_to include('recipes:')
    end
  end
end
