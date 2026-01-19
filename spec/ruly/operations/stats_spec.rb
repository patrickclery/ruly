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

  describe 'orphaned files detection' do
    let(:recipes_file) { File.join(test_dir, 'recipes.yml') }
    let(:rules_dir) { File.join(test_dir, 'rules') }

    def create_recipes_file(recipes_hash)
      File.write(recipes_file, YAML.dump({ 'recipes' => recipes_hash }))
    end

    describe '#find_orphaned_files' do
      context 'when all files are used by recipes' do
        it 'returns empty array' do
          used_file = create_test_file('rules/used.md', '# Used file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [used_file]
                                }
                              })

          sources = [{ path: used_file, type: 'local' }]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when files are not used by any recipe' do
        it 'returns orphaned files' do
          used_file = create_test_file('rules/used.md', '# Used file')
          orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [used_file]
                                }
                              })

          sources = [
            { path: used_file, type: 'local' },
            { path: orphaned_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to contain_exactly(orphaned_file)
        end
      end

      context 'when recipe uses directory path' do
        it 'considers all files in directory as used' do
          FileUtils.mkdir_p(File.join(test_dir, 'rules', 'subdir'))
          file_in_dir = create_test_file('rules/subdir/file.md', '# File in dir')
          orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [File.join(test_dir, 'rules', 'subdir/')]
                                }
                              })

          sources = [
            { path: file_in_dir, type: 'local' },
            { path: orphaned_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to contain_exactly(orphaned_file)
        end
      end

      context 'when file is required by another file' do
        it 'does not consider it orphaned' do
          parent_file = create_test_file('rules/parent.md', "# Parent\n@./child.md")
          child_file = create_test_file('rules/child.md', '# Child file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [parent_file]
                                }
                              })

          sources = [
            { path: parent_file, type: 'local' },
            { path: child_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when file is required with relative path from subdirectory' do
        it 'resolves the path correctly' do
          FileUtils.mkdir_p(File.join(test_dir, 'rules', 'subdir'))
          parent_file = create_test_file('rules/subdir/parent.md', "# Parent\n@../sibling.md")
          sibling_file = create_test_file('rules/sibling.md', '# Sibling file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [parent_file]
                                }
                              })

          sources = [
            { path: parent_file, type: 'local' },
            { path: sibling_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when file has YAML frontmatter with requires' do
        it 'parses requires from frontmatter' do
          parent_file = create_test_file('rules/parent.md', <<~MARKDOWN)
            ---
            description: Test file
            requires:
              - ./child.md
            ---

            # Parent Content
          MARKDOWN
          child_file = create_test_file('rules/child.md', '# Child file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [parent_file]
                                }
                              })

          sources = [
            { path: parent_file, type: 'local' },
            { path: child_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end

        it 'resolves relative paths from subdirectory in frontmatter' do
          FileUtils.mkdir_p(File.join(test_dir, 'rules', 'subdir', 'deep'))
          parent_file = create_test_file('rules/subdir/deep/parent.md', <<~MARKDOWN)
            ---
            requires:
              - ../../sibling.md
              - ../cousin.md
            ---

            # Parent Content
          MARKDOWN
          sibling_file = create_test_file('rules/sibling.md', '# Sibling file')
          cousin_file = create_test_file('rules/subdir/cousin.md', '# Cousin file')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [parent_file]
                                }
                              })

          sources = [
            { path: parent_file, type: 'local' },
            { path: sibling_file, type: 'local' },
            { path: cousin_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end

        it 'handles both frontmatter requires and @ syntax' do
          parent_file = create_test_file('rules/parent.md', <<~MARKDOWN)
            ---
            requires:
              - ./frontmatter-child.md
            ---

            # Parent Content

            @./at-child.md
          MARKDOWN
          frontmatter_child = create_test_file('rules/frontmatter-child.md', '# Frontmatter child')
          at_child = create_test_file('rules/at-child.md', '# At-syntax child')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [parent_file]
                                }
                              })

          sources = [
            { path: parent_file, type: 'local' },
            { path: frontmatter_child, type: 'local' },
            { path: at_child, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when chained requirements exist' do
        it 'considers transitively required files as used' do
          file_a = create_test_file('rules/a.md', "# A\n@./b.md")
          file_b = create_test_file('rules/b.md', "# B\n@./c.md")
          file_c = create_test_file('rules/c.md', '# C')

          create_recipes_file({
                                'test-recipe' => {
                                  'files' => [file_a]
                                }
                              })

          sources = [
            { path: file_a, type: 'local' },
            { path: file_b, type: 'local' },
            { path: file_c, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when no recipes file exists' do
        it 'considers all files as orphaned' do
          file1 = create_test_file('rules/file1.md', '# File 1')
          file2 = create_test_file('rules/file2.md', '# File 2')

          sources = [
            { path: file1, type: 'local' },
            { path: file2, type: 'local' }
          ]
          operation = described_class.new(
            sources:,
            output_file:,
            recipes_file: '/nonexistent/recipes.yml',
            rules_dir:
          )

          orphaned = operation.find_orphaned_files

          expect(orphaned).to contain_exactly(file1, file2)
        end
      end

      context 'with multiple recipes' do
        it 'considers files used by any recipe as not orphaned' do
          file1 = create_test_file('rules/file1.md', '# File 1')
          file2 = create_test_file('rules/file2.md', '# File 2')
          orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned')

          create_recipes_file({
                                'recipe1' => { 'files' => [file1] },
                                'recipe2' => { 'files' => [file2] }
                              })

          sources = [
            { path: file1, type: 'local' },
            { path: file2, type: 'local' },
            { path: orphaned_file, type: 'local' }
          ]
          operation = described_class.new(sources:, output_file:, recipes_file:, rules_dir:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to contain_exactly(orphaned_file)
        end
      end
    end

    describe 'orphaned files in output' do
      it 'includes orphaned files section in markdown output' do
        used_file = create_test_file('rules/used.md', '# Used file')
        orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned file')

        create_recipes_file({
                              'test-recipe' => {
                                'files' => [used_file]
                              }
                            })

        sources = [
          { path: used_file, type: 'local' },
          { path: orphaned_file, type: 'local' }
        ]

        described_class.call(sources:, output_file:, recipes_file:, rules_dir:)

        content = File.read(output_file)
        expect(content).to include('## Orphaned Files')
        expect(content).to include('orphaned.md')
      end

      it 'shows count of orphaned files' do
        used_file = create_test_file('rules/used.md', '# Used')
        orphan1 = create_test_file('rules/orphan1.md', '# Orphan 1')
        orphan2 = create_test_file('rules/orphan2.md', '# Orphan 2')

        create_recipes_file({
                              'test-recipe' => { 'files' => [used_file] }
                            })

        sources = [
          { path: used_file, type: 'local' },
          { path: orphan1, type: 'local' },
          { path: orphan2, type: 'local' }
        ]

        described_class.call(sources:, output_file:, recipes_file:, rules_dir:)

        content = File.read(output_file)
        expect(content).to include('2 files not used')
      end

      it 'does not show orphaned section when all files are used' do
        used_file = create_test_file('rules/used.md', '# Used file')

        create_recipes_file({
                              'test-recipe' => { 'files' => [used_file] }
                            })

        sources = [{ path: used_file, type: 'local' }]

        described_class.call(sources:, output_file:, recipes_file:, rules_dir:)

        content = File.read(output_file)
        expect(content).not_to include('## Orphaned Files')
      end

      it 'includes orphaned files data in result' do
        used_file = create_test_file('rules/used.md', '# Used')
        orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned')

        create_recipes_file({
                              'test-recipe' => { 'files' => [used_file] }
                            })

        sources = [
          { path: used_file, type: 'local' },
          { path: orphaned_file, type: 'local' }
        ]

        result = described_class.call(sources:, output_file:, recipes_file:, rules_dir:)

        expect(result[:data][:orphaned_files]).to contain_exactly(orphaned_file)
        expect(result[:data][:orphaned_count]).to eq(1)
      end
    end
  end
end
