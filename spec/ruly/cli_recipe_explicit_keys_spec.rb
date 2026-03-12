# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, type: :cli do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

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

  describe 'recipe-level skills key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-skills', 'deploy.md'), <<~MD)
        ---
        description: Deploy skill
        ---
        # Deploy
        Deploy steps.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'description' => 'Test with explicit skills key',
          'files' => ['rules/core/main.md'],
          'skills' => ['rules/my-skills/deploy.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'outputs files in skills key as SKILL.md' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/skills/deploy/SKILL.md')).to be(true)
      expect(File.read('.claude/skills/deploy/SKILL.md')).to include('Deploy steps')
    end

    it 'does not include skills key files in main output' do
      cli.invoke(:squash, ['test_recipe'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Deploy steps')
      expect(content).to include('Main Rule')
    end
  end

  describe 'files in /skills/ path without skills key are squashed' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core', 'skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'skills', 'debug.md'), <<~MD)
        # Debug Skill
        Debug content that should be squashed.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'description' => 'Test without explicit skills key',
          'files' => ['rules/core/skills/debug.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'squashes files in /skills/ path into main output when in files key' do
      cli.invoke(:squash, ['test_recipe'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).to include('Debug content that should be squashed')
    end

    it 'does not create SKILL.md for files in files key' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/skills/debug/SKILL.md')).to be(false)
    end
  end

  describe 'recipe-level commands key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-commands'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-commands', 'deploy.md'), <<~MD)
        # Deploy Command
        Deploy command content.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'commands' => ['rules/my-commands/deploy.md'],
          'description' => 'Test with explicit commands key',
          'files' => ['rules/core/main.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'outputs files in commands key to .claude/commands/' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/commands/deploy.md')).to be(true)
      expect(File.read('.claude/commands/deploy.md')).to include('Deploy command content')
    end

    it 'does not include commands key files in main output' do
      cli.invoke(:squash, ['test_recipe'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).not_to include('Deploy command content')
      expect(content).to include('Main Rule')
    end
  end

  describe 'files in /commands/ path without commands key are squashed' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core', 'commands'))

      File.write(File.join(test_dir, 'rules', 'core', 'commands', 'build.md'), <<~MD)
        # Build Command
        Build content that should be squashed.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'description' => 'Test without explicit commands key',
          'files' => ['rules/core/commands/build.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'squashes files in /commands/ path into main output when in files key' do
      cli.invoke(:squash, ['test_recipe'])

      content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
      expect(content).to include('Build content that should be squashed')
    end

    it 'does not create command file for files in files key' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/commands/build.md')).to be(false)
    end
  end

  describe 'recipe-level bins key' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'my-bin'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        # Main Rule
        Some content.
      MD

      File.write(File.join(test_dir, 'rules', 'my-bin', 'deploy.sh'), "#!/bin/bash\necho deploy")

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'scripts' => ['rules/my-bin/deploy.sh'],
          'description' => 'Test with explicit bins key',
          'files' => ['rules/core/main.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'copies files in bins key to .claude/scripts/' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/scripts/deploy.sh')).to be(true)
      expect(File.executable?('.claude/scripts/deploy.sh')).to be(true)
    end
  end

  describe 'directory expansion for explicit keys' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'all-skills'))

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), '# Main')

      File.write(File.join(test_dir, 'rules', 'all-skills', 'a.md'), <<~MD)
        ---
        description: Skill A
        ---
        # Skill A
        Content A.
      MD

      File.write(File.join(test_dir, 'rules', 'all-skills', 'b.md'), <<~MD)
        ---
        description: Skill B
        ---
        # Skill B
        Content B.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'description' => 'Test with skills directory',
          'files' => ['rules/core/main.md'],
          'skills' => [File.join(test_dir, 'rules', 'all-skills/')]
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'expands directories in skills key to individual skill files' do
      cli.invoke(:squash, ['test_recipe'])

      expect(File.exist?('.claude/skills/a/SKILL.md')).to be(true)
      expect(File.exist?('.claude/skills/b/SKILL.md')).to be(true)
    end
  end

  describe 'skills: frontmatter referencing files outside /skills/ directory' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))

      File.write(File.join(test_dir, 'rules', 'shared', 'helper-skill.md'), <<~MD)
        ---
        description: Helper skill
        ---
        # Helper Skill
        Helper content.
      MD

      File.write(File.join(test_dir, 'rules', 'core', 'main.md'), <<~MD)
        ---
        skills:
          - ../shared/helper-skill.md
        ---
        # Main Rule
        References a skill.
      MD

      allow(cli).to receive_messages(
        gem_root: test_dir,
        recipes_file: File.join(test_dir, 'recipes.yml'),
        rules_dir: File.join(test_dir, 'rules')
      )

      recipes_content = {
        'test_recipe' => {
          'description' => 'Test with skill outside /skills/',
          'files' => ['rules/core/main.md']
        }
      }

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'allows skills: frontmatter to reference files outside /skills/ directory' do
      expect { cli.invoke(:squash, ['test_recipe']) }.not_to raise_error
    end

    it 'creates SKILL.md for frontmatter-referenced skills' do
      cli.invoke(:squash, ['test_recipe'])
      expect(File.exist?('.claude/skills/helper-skill/SKILL.md')).to be(true)
    end
  end
end
