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
        file1 = create_test_file('rules/large.md', "# Large File#{"\n\nContent " * 100}")
        file2 = create_test_file('rules/small.md', '# Small File')

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'}
        ]

        result = described_class.call(output_file:, sources:)

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(2)
        expect(result[:data][:total_tokens]).to be > 0
        expect(result[:data][:output_file]).to eq(output_file)
      end

      it 'generates a markdown file' do
        file1 = create_test_file('rules/test.md', '# Test Content')

        sources = [{path: file1, type: 'local'}]

        described_class.call(output_file:, sources:)

        expect(File.exist?(output_file)).to be(true)
        content = File.read(output_file)
        expect(content).to include('# Ruly Token Statistics')
        expect(content).to include('## Summary')
        expect(content).to include('## Files by Token Count')
      end

      it 'sorts files by token count descending' do
        large_file = create_test_file('rules/large.md', "# Large#{"\nContent " * 500}")
        small_file = create_test_file('rules/small.md', '# Small')

        sources = [
          {path: small_file, type: 'local'},
          {path: large_file, type: 'local'}
        ]

        result = described_class.call(output_file:, sources:)
        files = result[:data][:files]

        expect(files.first[:tokens]).to be > files.last[:tokens]
        expect(files.first[:path]).to eq(large_file)
      end

      it 'includes file sizes in the output' do
        file1 = create_test_file('rules/test.md', 'Some test content here')

        sources = [{path: file1, type: 'local'}]

        described_class.call(output_file:, sources:)

        content = File.read(output_file)
        expect(content).to match(/\d+(\.\d+)?\s*(B|KB|MB)/)
      end
    end

    context 'with empty sources' do
      it 'returns success with zero counts' do
        result = described_class.call(output_file:, sources: [])

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(0)
        expect(result[:data][:total_tokens]).to eq(0)
      end

      it 'generates a valid markdown file' do
        described_class.call(output_file:, sources: [])

        expect(File.exist?(output_file)).to be(true)
        content = File.read(output_file)
        expect(content).to include('**Total Files**: 0')
      end
    end

    context 'with non-local sources' do
      it 'skips remote sources' do
        local_file = create_test_file('rules/local.md', '# Local')

        sources = [
          {path: local_file, type: 'local'},
          {path: 'https://example.com/remote.md', type: 'remote'}
        ]

        result = described_class.call(output_file:, sources:)

        expect(result[:data][:file_count]).to eq(1)
      end
    end

    context 'with missing files' do
      it 'skips files that do not exist' do
        existing_file = create_test_file('rules/exists.md', '# Exists')

        sources = [
          {path: existing_file, type: 'local'},
          {path: '/nonexistent/file.md', type: 'local'}
        ]

        result = described_class.call(output_file:, sources:)

        expect(result[:success]).to be(true)
        expect(result[:data][:file_count]).to eq(1)
      end
    end
  end

  describe '#build_file_stats' do
    it 'returns an array of file statistics' do
      file1 = create_test_file('rules/test.md', '# Test')

      sources = [{path: file1, type: 'local'}]
      operation = described_class.new(output_file:, sources:)
      stats = operation.build_file_stats

      expect(stats).to be_an(Array)
      expect(stats.first).to include(:path, :tokens, :size)
    end

    it 'calculates tokens using tiktoken' do
      file1 = create_test_file('rules/test.md', 'Hello world')

      sources = [{path: file1, type: 'local'}]
      operation = described_class.new(output_file:, sources:)
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

      sources = [{path: large_file, type: 'local'}]

      described_class.call(output_file:, sources:)

      content = File.read(output_file)
      # Should have comma-formatted numbers
      expect(content).to match(/\d{1,3}(,\d{3})+/)
    end
  end

  describe 'byte formatting' do
    it 'formats bytes as B for small files' do
      small_file = create_test_file('rules/tiny.md', 'Hi')

      sources = [{path: small_file, type: 'local'}]

      described_class.call(output_file:, sources:)

      content = File.read(output_file)
      expect(content).to include(' B')
    end

    it 'formats bytes as KB for medium files' do
      medium_content = 'x' * 2000
      medium_file = create_test_file('rules/medium.md', medium_content)

      sources = [{path: medium_file, type: 'local'}]

      described_class.call(output_file:, sources:)

      content = File.read(output_file)
      expect(content).to include(' KB')
    end
  end

  describe 'orphaned files detection' do
    let(:recipes_file) { File.join(test_dir, 'recipes.yml') }
    let(:rules_dir) { File.join(test_dir, 'rules') }

    def create_recipes_file(recipes_hash)
      File.write(recipes_file, YAML.dump({'recipes' => recipes_hash}))
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

          sources = [{path: used_file, type: 'local'}]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: used_file, type: 'local'},
            {path: orphaned_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: file_in_dir, type: 'local'},
            {path: orphaned_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: parent_file, type: 'local'},
            {path: child_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: parent_file, type: 'local'},
            {path: sibling_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: parent_file, type: 'local'},
            {path: child_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: parent_file, type: 'local'},
            {path: sibling_file, type: 'local'},
            {path: cousin_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: parent_file, type: 'local'},
            {path: frontmatter_child, type: 'local'},
            {path: at_child, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
            {path: file_a, type: 'local'},
            {path: file_b, type: 'local'},
            {path: file_c, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

          orphaned = operation.find_orphaned_files

          expect(orphaned).to be_empty
        end
      end

      context 'when no recipes file exists' do
        it 'considers all files as orphaned' do
          file1 = create_test_file('rules/file1.md', '# File 1')
          file2 = create_test_file('rules/file2.md', '# File 2')

          sources = [
            {path: file1, type: 'local'},
            {path: file2, type: 'local'}
          ]
          operation = described_class.new(
            output_file:,
            recipes_file: '/nonexistent/recipes.yml',
            rules_dir:,
            sources:
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
                                'recipe1' => {'files' => [file1]},
                                'recipe2' => {'files' => [file2]}
                              })

          sources = [
            {path: file1, type: 'local'},
            {path: file2, type: 'local'},
            {path: orphaned_file, type: 'local'}
          ]
          operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

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
          {path: used_file, type: 'local'},
          {path: orphaned_file, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('## Orphaned Files')
        expect(content).to include('orphaned.md')
      end

      it 'shows count of orphaned files' do
        used_file = create_test_file('rules/used.md', '# Used')
        orphan1 = create_test_file('rules/orphan1.md', '# Orphan 1')
        orphan2 = create_test_file('rules/orphan2.md', '# Orphan 2')

        create_recipes_file({
                              'test-recipe' => {'files' => [used_file]}
                            })

        sources = [
          {path: used_file, type: 'local'},
          {path: orphan1, type: 'local'},
          {path: orphan2, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('2 files not used')
      end

      it 'does not show orphaned section when all files are used' do
        used_file = create_test_file('rules/used.md', '# Used file')

        create_recipes_file({
                              'test-recipe' => {'files' => [used_file]}
                            })

        sources = [{path: used_file, type: 'local'}]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).not_to include('## Orphaned Files')
      end

      it 'includes orphaned files data in result' do
        used_file = create_test_file('rules/used.md', '# Used')
        orphaned_file = create_test_file('rules/orphaned.md', '# Orphaned')

        create_recipes_file({
                              'test-recipe' => {'files' => [used_file]}
                            })

        sources = [
          {path: used_file, type: 'local'},
          {path: orphaned_file, type: 'local'}
        ]

        result = described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        expect(result[:data][:orphaned_files]).to contain_exactly(orphaned_file)
        expect(result[:data][:orphaned_count]).to eq(1)
      end
    end

    describe 'circular dependency detection' do
      describe '#find_circular_dependencies' do
        context 'when no circular dependencies exist' do
          it 'returns empty array' do
            file_a = create_test_file('rules/a.md', "# A\n@./b.md")
            file_b = create_test_file('rules/b.md', '# B')

            sources = [
              {path: file_a, type: 'local'},
              {path: file_b, type: 'local'}
            ]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular).to be_empty
          end
        end

        context 'when two files require each other' do
          it 'detects the circular dependency' do
            file_a = create_test_file('rules/a.md', <<~MARKDOWN)
              ---
              requires:
                - ./b.md
              ---
              # A
            MARKDOWN
            file_b = create_test_file('rules/b.md', <<~MARKDOWN)
              ---
              requires:
                - ./a.md
              ---
              # B
            MARKDOWN

            sources = [
              {path: file_a, type: 'local'},
              {path: file_b, type: 'local'}
            ]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular.size).to eq(1)
            expect(circular.first.map { |p| File.basename(p) }).to contain_exactly('a.md', 'b.md')
          end
        end

        context 'when a file requires itself' do
          it 'detects the self-referential dependency' do
            file_a = create_test_file('rules/a.md', <<~MARKDOWN)
              ---
              requires:
                - ./a.md
              ---
              # A
            MARKDOWN

            sources = [{path: file_a, type: 'local'}]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular.size).to eq(1)
            expect(circular.first.map { |p| File.basename(p) }).to eq(['a.md'])
          end
        end

        context 'when there is a longer cycle (A -> B -> C -> A)' do
          it 'detects the full cycle' do
            file_a = create_test_file('rules/a.md', "@./b.md\n# A")
            file_b = create_test_file('rules/b.md', "@./c.md\n# B")
            file_c = create_test_file('rules/c.md', "@./a.md\n# C")

            sources = [
              {path: file_a, type: 'local'},
              {path: file_b, type: 'local'},
              {path: file_c, type: 'local'}
            ]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular.size).to eq(1)
            expect(circular.first.map { |p| File.basename(p) }).to contain_exactly('a.md', 'b.md', 'c.md')
          end
        end

        context 'when there are multiple independent cycles' do
          it 'detects all cycles' do
            # Cycle 1: a <-> b
            file_a = create_test_file('rules/a.md', "@./b.md\n# A")
            file_b = create_test_file('rules/b.md', "@./a.md\n# B")
            # Cycle 2: c <-> d
            file_c = create_test_file('rules/c.md', "@./d.md\n# C")
            file_d = create_test_file('rules/d.md', "@./c.md\n# D")

            sources = [
              {path: file_a, type: 'local'},
              {path: file_b, type: 'local'},
              {path: file_c, type: 'local'},
              {path: file_d, type: 'local'}
            ]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular.size).to eq(2)
          end
        end

        context 'when dependency points to non-existent file' do
          it 'does not include it in the cycle detection' do
            file_a = create_test_file('rules/a.md', "@./nonexistent.md\n# A")

            sources = [{path: file_a, type: 'local'}]
            operation = described_class.new(output_file:, sources:)

            circular = operation.find_circular_dependencies

            expect(circular).to be_empty
          end
        end
      end

      describe 'circular dependencies in output' do
        it 'includes circular dependencies section in markdown output' do
          file_a = create_test_file('rules/a.md', "@./b.md\n# A")
          file_b = create_test_file('rules/b.md', "@./a.md\n# B")

          sources = [
            {path: file_a, type: 'local'},
            {path: file_b, type: 'local'}
          ]

          described_class.call(output_file:, sources:)

          content = File.read(output_file, encoding: 'UTF-8')
          expect(content).to include('Circular Dependencies')
          expect(content).to include('Found 1 circular dependency chain(s)')
        end

        it 'does not show circular section when no cycles exist' do
          file_a = create_test_file('rules/a.md', '# A')

          sources = [{path: file_a, type: 'local'}]

          described_class.call(output_file:, sources:)

          content = File.read(output_file)
          expect(content).not_to include('Circular Dependencies')
        end

        it 'includes circular dependencies data in result' do
          file_a = create_test_file('rules/a.md', "@./b.md\n# A")
          file_b = create_test_file('rules/b.md', "@./a.md\n# B")

          sources = [
            {path: file_a, type: 'local'},
            {path: file_b, type: 'local'}
          ]

          result = described_class.call(output_file:, sources:)

          expect(result[:data][:circular_dependencies].size).to eq(1)
          expect(result[:data][:circular_count]).to eq(1)
        end
      end
    end

    describe 'per-recipe token counts' do
      it 'generates a Files by Token Count section for each recipe' do
        file1 = create_test_file('rules/file1.md', '# File 1 content here')
        file2 = create_test_file('rules/file2.md', '# File 2 different content')
        file3 = create_test_file('rules/file3.md', '# File 3 more content')

        create_recipes_file({
                              'recipe-alpha' => {'files' => [file1, file2]},
                              'recipe-beta' => {'files' => [file2, file3]}
                            })

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'},
          {path: file3, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('## Recipe: recipe-alpha')
        expect(content).to include('## Recipe: recipe-beta')
      end

      it 'shows token counts for files in each recipe' do
        file1 = create_test_file('rules/file1.md', 'Short content')
        file2 = create_test_file('rules/file2.md', 'Much longer content ' * 50)

        create_recipes_file({
                              'test-recipe' => {'files' => [file1, file2]}
                            })

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('## Recipe: test-recipe')
        # Should contain a table with token counts
        expect(content).to match(/\|\s*#\s*\|\s*Tokens\s*\|/)
        # Should list both files under the recipe section
        expect(content).to include('file1.md')
        expect(content).to include('file2.md')
      end

      it 'shows recipe total tokens in the summary' do
        file1 = create_test_file('rules/file1.md', 'Content one')
        file2 = create_test_file('rules/file2.md', 'Content two')

        create_recipes_file({
                              'my-recipe' => {'files' => [file1, file2]}
                            })

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        # Should show total tokens for the recipe
        expect(content).to match(/## Recipe: my-recipe.*Total Tokens/m)
      end

      it 'expands directory paths in recipes' do
        FileUtils.mkdir_p(File.join(test_dir, 'rules', 'subdir'))
        file1 = create_test_file('rules/subdir/file1.md', '# File 1')
        file2 = create_test_file('rules/subdir/file2.md', '# File 2')

        create_recipes_file({
                              'dir-recipe' => {'files' => [File.join(test_dir, 'rules', 'subdir/')]}
                            })

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'}
        ]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('## Recipe: dir-recipe')
        expect(content).to include('file1.md')
        expect(content).to include('file2.md')
      end

      it 'reuses token counts from build_file_stats instead of recalculating' do
        file1 = create_test_file('rules/file1.md', '# File 1')
        file2 = create_test_file('rules/file2.md', '# File 2')

        create_recipes_file({
                              'recipe1' => {'files' => [file1]},
                              'recipe2' => {'files' => [file1, file2]}
                            })

        sources = [
          {path: file1, type: 'local'},
          {path: file2, type: 'local'}
        ]

        operation = described_class.new(output_file:, recipes_file:, rules_dir:, sources:)

        # Mock count_tokens to track calls
        call_count = 0
        allow(operation).to receive(:count_tokens).and_wrap_original do |method, *args|
          call_count += 1
          method.call(*args)
        end

        operation.call

        # Should only count tokens once per file, not once per recipe occurrence
        expect(call_count).to eq(2) # Once for file1, once for file2
      end

      it 'sorts recipes alphabetically' do
        file1 = create_test_file('rules/file1.md', '# File 1')

        create_recipes_file({
                              'alpha-recipe' => {'files' => [file1]},
                              'middle-recipe' => {'files' => [file1]},
                              'zebra-recipe' => {'files' => [file1]}
                            })

        sources = [{path: file1, type: 'local'}]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        alpha_pos = content.index('## Recipe: alpha-recipe')
        middle_pos = content.index('## Recipe: middle-recipe')
        zebra_pos = content.index('## Recipe: zebra-recipe')

        expect(alpha_pos).to be < middle_pos
        expect(middle_pos).to be < zebra_pos
      end

      it 'does not generate recipe sections when no recipes file exists' do
        file1 = create_test_file('rules/file1.md', '# File 1')

        sources = [{path: file1, type: 'local'}]

        described_class.call(output_file:, sources:)

        content = File.read(output_file)
        expect(content).not_to include('## Recipe:')
      end

      it 'handles recipes with no valid files gracefully' do
        file1 = create_test_file('rules/file1.md', '# File 1')

        create_recipes_file({
                              'empty-recipe' => {'files' => ['/nonexistent/file.md']},
                              'valid-recipe' => {'files' => [file1]}
                            })

        sources = [{path: file1, type: 'local'}]

        described_class.call(output_file:, recipes_file:, rules_dir:, sources:)

        content = File.read(output_file)
        expect(content).to include('## Recipe: valid-recipe')
        # Empty recipe should either not appear or show 0 files
        expect(content).not_to include('## Recipe: empty-recipe')
      end
    end
  end
end
