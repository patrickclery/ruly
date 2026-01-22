# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }

  describe '#strip_metadata_from_frontmatter' do
    describe 'with keep_frontmatter: false (default)' do
      it 'strips all frontmatter and returns just body content' do
        content = <<~MD
          ---
          description: Test file
          author: John Doe
          ---
          # Content
          Body text
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content)

        expect(result).not_to include('---')
        expect(result).not_to include('description:')
        expect(result).not_to include('author:')
        expect(result).to start_with("\n# Content")
        expect(result).to include('Body text')
      end

      it 'strips frontmatter even when it contains non-metadata fields' do
        content = <<~MD
          ---
          title: My Rule
          version: 1.0
          custom_field: value
          ---
          # Rule content
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content)

        expect(result).not_to include('---')
        expect(result).not_to include('title:')
        expect(result).not_to include('version:')
        expect(result).not_to include('custom_field:')
        expect(result).to include('# Rule content')
      end

      it 'handles content without frontmatter' do
        content = <<~MD
          # Just a regular file
          No frontmatter here.
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content)

        expect(result).to eq(content)
      end

      it 'handles content that starts with --- but is not valid frontmatter' do
        content = <<~MD
          ---
          This is not valid YAML frontmatter
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content)

        expect(result).to eq(content)
      end
    end

    describe 'with keep_frontmatter: true' do
      it 'preserves non-metadata frontmatter' do
        content = <<~MD
          ---
          description: Test file
          author: John Doe
          ---
          # Content
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

        expect(result).to include('---')
        expect(result).to include('description: Test file')
        expect(result).to include('author: John Doe')
        expect(result).to include('# Content')
      end

      it 'strips requires field but keeps other frontmatter' do
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

      it 'strips recipes field but keeps other frontmatter' do
        content = <<~MD
          ---
          description: Test file
          recipes:
            - recipe1
            - recipe2
          ---
          # Content
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

        expect(result).to include('description: Test file')
        expect(result).not_to include('recipes:')
        expect(result).not_to include('recipe1')
        expect(result).not_to include('recipe2')
      end

      it 'strips essential field but keeps other frontmatter' do
        content = <<~MD
          ---
          description: Test file
          essential: true
          ---
          # Content
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

        expect(result).to include('description: Test file')
        expect(result).not_to include('essential:')
      end

      it 'strips all metadata fields (requires, recipes, essential) but keeps others' do
        content = <<~MD
          ---
          description: Test file
          recipes:
            - test_recipe
          requires:
            - common.md
          essential: true
          author: Jane
          ---
          # Content
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

        expect(result).to include('description: Test file')
        expect(result).to include('author: Jane')
        expect(result).not_to include('recipes:')
        expect(result).not_to include('requires:')
        expect(result).not_to include('essential:')
      end

      it 'removes frontmatter entirely if only metadata fields remain' do
        content = <<~MD
          ---
          recipes:
            - test_recipe
          requires:
            - common.md
          essential: true
          ---
          # Content
          Body text
        MD

        result = cli.send(:strip_metadata_from_frontmatter, content, keep_frontmatter: true)

        expect(result).not_to include('---')
        expect(result).to start_with("\n# Content")
      end
    end
  end

  describe '#squash with --front-matter option' do
    let(:test_dir) { Dir.mktmpdir }
    let(:rules_dir) { File.join(test_dir, 'rules') }

    before do
      FileUtils.mkdir_p(rules_dir)
      Dir.chdir(test_dir)
    end

    after do
      Dir.chdir('/')
      FileUtils.rm_rf(test_dir)
    end

    it 'strips all frontmatter by default' do
      File.write(File.join(rules_dir, 'test.md'), <<~MD)
        ---
        description: Test rule
        author: Test Author
        ---
        # Test Rule

        Some content here.
      MD

      cli = described_class.new
      cli.options = {
        output_file: File.join(test_dir, 'output.md'),
        agent: 'claude',
        cache: false,
        clean: false,
        deepclean: false,
        dry_run: false,
        git_ignore: false,
        git_exclude: false,
        toc: false,
        essential: false,
        taskmaster_config: false,
        keep_taskmaster: false,
        front_matter: false
      }

      # Stub collect_local_sources to only return our test file
      allow(cli).to receive(:collect_local_sources).and_return([{path: 'rules/test.md', type: 'local'}])
      allow(cli).to receive(:find_rule_file).with('rules/test.md').and_return(File.join(rules_dir, 'test.md'))

      # Capture output to suppress it
      expect { cli.squash }.to output.to_stdout

      output_content = File.read(File.join(test_dir, 'output.md'), encoding: 'UTF-8')
      expect(output_content).not_to include('description: Test rule')
      expect(output_content).not_to include('author: Test Author')
      expect(output_content).to include('# Test Rule')
      expect(output_content).to include('Some content here.')
    end

    it 'preserves non-metadata frontmatter when --front-matter is specified' do
      File.write(File.join(rules_dir, 'test.md'), <<~MD)
        ---
        description: Test rule
        author: Test Author
        ---
        # Test Rule

        Some content here.
      MD

      cli = described_class.new
      cli.options = {
        output_file: File.join(test_dir, 'output.md'),
        agent: 'claude',
        cache: false,
        clean: false,
        deepclean: false,
        dry_run: false,
        git_ignore: false,
        git_exclude: false,
        toc: false,
        essential: false,
        taskmaster_config: false,
        keep_taskmaster: false,
        front_matter: true
      }

      # Stub collect_local_sources to only return our test file
      allow(cli).to receive(:collect_local_sources).and_return([{path: 'rules/test.md', type: 'local'}])
      allow(cli).to receive(:find_rule_file).with('rules/test.md').and_return(File.join(rules_dir, 'test.md'))

      # Capture output to suppress it
      expect { cli.squash }.to output.to_stdout

      output_content = File.read(File.join(test_dir, 'output.md'), encoding: 'UTF-8')
      expect(output_content).to include('description: Test rule')
      expect(output_content).to include('author: Test Author')
      expect(output_content).to include('# Test Rule')
    end

    it 'still strips metadata fields even with --front-matter flag' do
      File.write(File.join(rules_dir, 'test.md'), <<~MD)
        ---
        description: Test rule
        requires:
          - other.md
        recipes:
          - some-recipe
        essential: true
        ---
        # Test Rule
      MD

      cli = described_class.new
      cli.options = {
        output_file: File.join(test_dir, 'output.md'),
        agent: 'claude',
        cache: false,
        clean: false,
        deepclean: false,
        dry_run: false,
        git_ignore: false,
        git_exclude: false,
        toc: false,
        essential: false,
        taskmaster_config: false,
        keep_taskmaster: false,
        front_matter: true
      }

      # Stub collect_local_sources to only return our test file
      allow(cli).to receive(:collect_local_sources).and_return([{path: 'rules/test.md', type: 'local'}])
      allow(cli).to receive(:find_rule_file).with('rules/test.md').and_return(File.join(rules_dir, 'test.md'))

      # Capture output to suppress it
      expect { cli.squash }.to output.to_stdout

      output_content = File.read(File.join(test_dir, 'output.md'), encoding: 'UTF-8')
      expect(output_content).to include('description: Test rule')
      expect(output_content).not_to include('requires:')
      expect(output_content).not_to include('recipes:')
      expect(output_content).not_to include('essential:')
    end
  end
end
