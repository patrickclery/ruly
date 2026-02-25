# frozen_string_literal: true

require 'spec_helper'
require 'ruly/cli'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd
    begin
      Dir.chdir(temp_dir)

      # Create a test profile file
      File.write('profiles.yml', profile_content)

      # Create test markdown files
      FileUtils.mkdir_p('rules')
      File.write('rules/test.md', '# Test Rule')

      # Create test bin files with subdirectories
      FileUtils.mkdir_p('rules/bin/testing')
      FileUtils.mkdir_p('rules/bin/common')

      File.write('rules/bin/testing/test-script.sh', '#!/bin/bash\necho "test"')
      File.write('rules/bin/common/helper.sh', '#!/bin/bash\necho "helper"')
      File.write('rules/bin/standalone.sh', '#!/bin/bash\necho "standalone"')

      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end
  end

  describe '#squash with bin files' do
    let(:profile_content) do
      <<~YAML
        profiles:
          test_with_bin:
            description: "Test profile with bin files"
            files:
              - rules/test.md
            bins:
              - rules/bin/
      YAML
    end

    before do
      allow(cli).to receive_messages(gem_root: temp_dir,
                                     profiles_file: File.join(temp_dir, 'profiles.yml'))

      profiles_content = {
        'test_with_bin' => {
          'scripts' => ['rules/bin/'],
          'description' => 'Test profile with bin files',
          'files' => ['rules/test.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    context 'when processing sources with bin files' do
      it 'copies bin files to .claude/scripts/' do
        cli.squash('test_with_bin')

        expect(Dir.exist?('.claude/scripts')).to be(true)
        expect(File.exist?('.claude/scripts/testing/test-script.sh')).to be(true)
        expect(File.exist?('.claude/scripts/common/helper.sh')).to be(true)
        expect(File.exist?('.claude/scripts/standalone.sh')).to be(true)
      end

      it 'makes bin files executable' do
        cli.squash('test_with_bin')

        expect(File.executable?('.claude/scripts/testing/test-script.sh')).to be(true)
        expect(File.executable?('.claude/scripts/common/helper.sh')).to be(true)
        expect(File.executable?('.claude/scripts/standalone.sh')).to be(true)
      end

      it 'preserves subdirectory structure' do
        cli.squash('test_with_bin')

        expect(Dir.exist?('.claude/scripts/testing')).to be(true)
        expect(Dir.exist?('.claude/scripts/common')).to be(true)
      end

      it 'outputs message about copying script files' do
        expect { cli.squash('test_with_bin') }.to output(%r{Copied 3 script files to \.claude/scripts/}).to_stdout
      end
    end

    context 'with --dry-run option' do
      it 'does not copy script files' do
        cli.options = {agent: 'claude', dry_run: true, output_file: 'CLAUDE.local.md'}
        cli.squash('test_with_bin')

        expect(Dir.exist?('.claude/scripts')).to be(false)
      end

      it 'shows what would be copied' do
        cli.options = {agent: 'claude', dry_run: true, output_file: 'CLAUDE.local.md'}

        expect { cli.squash('test_with_bin') }.to output(%r{Would copy script files to \.claude/scripts/}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(%r{testing/test-script\.sh \(executable\)}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(%r{common/helper\.sh \(executable\)}).to_stdout
        expect { cli.squash('test_with_bin') }.to output(/standalone\.sh \(executable\)/).to_stdout
      end
    end
  end

  describe '#clean with --deepclean' do
    let(:profile_content) do
      <<~YAML
        profiles:
          dummy:
            description: "Dummy profile for clean tests"
            files:
              - rules/test.md
      YAML
    end

    before do
      # Create .claude/scripts directory with files
      FileUtils.mkdir_p('.claude/scripts/testing')
      File.write('.claude/scripts/testing/script.sh', '#!/bin/bash')
      File.write('.claude/scripts/other.sh', '#!/bin/bash')
    end

    it 'removes .claude directory including script files' do
      cli.options = {deepclean: true}
      cli.clean

      expect(Dir.exist?('.claude')).to be(false)
      expect(Dir.exist?('.claude/scripts')).to be(false)
    end

    it 'lists .claude/scripts/ in cleanup message' do
      cli.options = {deepclean: true}

      expect { cli.clean }.to output(%r{\.claude/scripts/}).to_stdout
    end
  end

  describe 'processing GitHub sources with bin files' do
    let(:profile_content) do
      <<~YAML
        profiles:
          github_bin:
            description: "GitHub profile with bin files"
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
      skip 'GitHub bin file handling tests'
    end
  end

  describe 'bin file detection without bins: key' do
    let(:profile_content) do
      <<~YAML
        profiles:
          dummy:
            description: "Dummy profile for detection tests"
            files:
              - rules/test.md
      YAML
    end

    it 'does not auto-detect bin files from path' do
      sources = []
      Ruly::Services::ProfileLoader.process_local_directory('rules', sources, gem_root: temp_dir)

      # bin/*.sh files are still collected by process_local_directory
      # but they are NOT categorized as bins (no :category marker)
      sh_sources = sources.select { |s| s[:path].end_with?('.sh') }
      sh_sources.each do |source|
        expect(source[:category]).to be_nil
      end
    end
  end
end
