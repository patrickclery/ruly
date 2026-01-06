# frozen_string_literal: true

require 'spec_helper'
require 'ruly/cli'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  let(:original_dir) { Dir.pwd }

  before do
    Dir.chdir(temp_dir)

    # Create a test recipe file
    File.write('recipes.yml', recipe_content)

    # Create test markdown files
    FileUtils.mkdir_p('rules')
    File.write('rules/test.md', '# Test Rule')

    # Create test bin files with subdirectories
    FileUtils.mkdir_p('rules/bin/testing')
    FileUtils.mkdir_p('rules/bin/common')

    File.write('rules/bin/testing/test-script.sh', '#!/bin/bash\necho "test"')
    File.write('rules/bin/common/helper.sh', '#!/bin/bash\necho "helper"')
    File.write('rules/bin/standalone.sh', '#!/bin/bash\necho "standalone"')
  end

  after do
    Dir.chdir(original_dir)
    FileUtils.rm_rf(temp_dir)
  end

  describe '#squash with bin files' do
    let(:recipe_content) do
      <<~YAML
        recipes:
          test_with_bin:
            description: "Test recipe with bin files"
            sources:
              - local: rules
      YAML
    end

    context 'when processing sources with bin files' do
      it 'copies bin files to .ruly/bin/' do
        cli.squash('test_with_bin')

        expect(Dir.exist?('.ruly/bin')).to be(true)
        expect(File.exist?('.ruly/bin/testing/test-script.sh')).to be(true)
        expect(File.exist?('.ruly/bin/common/helper.sh')).to be(true)
        expect(File.exist?('.ruly/bin/standalone.sh')).to be(true)
      end

      it 'makes bin files executable' do
        cli.squash('test_with_bin')

        expect(File.executable?('.ruly/bin/testing/test-script.sh')).to be(true)
        expect(File.executable?('.ruly/bin/common/helper.sh')).to be(true)
        expect(File.executable?('.ruly/bin/standalone.sh')).to be(true)
      end

      it 'preserves subdirectory structure' do
        cli.squash('test_with_bin')

        expect(Dir.exist?('.ruly/bin/testing')).to be(true)
        expect(Dir.exist?('.ruly/bin/common')).to be(true)
      end

      it 'outputs message about copying bin files' do
        expect { cli.squash('test_with_bin') }.to output(%r{Copied 3 bin files to \.ruly/bin/}).to_stdout
      end
    end

    context 'with --dry-run option' do
      it 'does not copy bin files' do
        cli.options = {agent: 'claude', dry_run: true, output_file: 'CLAUDE.local.md'}
        cli.squash('test_with_bin')

        expect(Dir.exist?('.ruly/bin')).to be(false)
      end

      it 'shows what would be copied' do
        cli.options = {agent: 'claude', dry_run: true, output_file: 'CLAUDE.local.md'}

        expect { cli.squash('test_with_bin') }.to output(%r{Would copy bin files to \.ruly/bin/}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(%r{testing/test-script\.sh \(executable\)}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(%r{common/helper\.sh \(executable\)}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(/standalone\.sh \(executable\)/).to_stdout
      end
    end
  end

  describe '#clean with --deepclean' do
    before do
      # Create .ruly/bin directory with files
      FileUtils.mkdir_p('.ruly/bin/testing')
      File.write('.ruly/bin/testing/script.sh', '#!/bin/bash')
      File.write('.ruly/bin/other.sh', '#!/bin/bash')
    end

    it 'removes .ruly directory including bin files' do
      cli.options = {deepclean: true}
      cli.clean

      expect(Dir.exist?('.ruly')).to be(false)
      expect(Dir.exist?('.ruly/bin')).to be(false)
    end

    it 'lists .ruly/ in cleanup message' do
      cli.options = {deepclean: true}

      expect { cli.clean }.to output(%r{\.ruly/}).to_stdout
    end
  end

  describe 'processing GitHub sources with bin files' do
    let(:recipe_content) do
      <<~YAML
        recipes:
          github_bin:
            description: "GitHub recipe with bin files"
            sources:
              - github: someuser/somerepo
                branch: main
                rules:
                  - rules
      YAML
    end

    it 'handles bin files from GitHub sources' do
      # This would require mocking GitHub API calls
      # Placeholder for GitHub bin file handling tests
      pending 'GitHub bin file handling tests'
    end
  end

  describe 'bin file detection' do
    it 'correctly identifies bin/*.sh files' do
      sources = []
      cli.send(:process_local_directory, 'rules', sources)

      bin_sources = sources.select { |s| s[:path].match?(%r{bin/.*\.sh$}) }

      expect(bin_sources.size).to eq(3)
      expect(bin_sources.map { |s| s[:path] }).to include(
        'rules/bin/testing/test-script.sh',
        'rules/bin/common/helper.sh',
        'rules/bin/standalone.sh'
      )
    end

    it 'separates bin files from markdown files' do
      sources = []
      cli.send(:process_local_directory, 'rules', sources)

      md_sources = sources.select { |s| s[:path].end_with?('.md') }
      sh_sources = sources.select { |s| s[:path].end_with?('.sh') }

      expect(md_sources.size).to eq(1)
      expect(sh_sources.size).to eq(3)
    end
  end
end
