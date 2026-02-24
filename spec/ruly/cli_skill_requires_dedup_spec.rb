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

  describe 'skill requires deduplication against profile' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'comms', 'skills'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))

      # Shared file that will be in the profile AND required by skills
      File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
        ---
        description: Team account IDs
        ---
        # Team Directory

        | Name | ID |
        |------|-----|
        | Alice | 123 |
        | Bob | 456 |
      MD

      # Skill that requires accounts.md
      File.write(File.join(test_dir, 'rules', 'comms', 'skills', 'send-dm.md'), <<~MD)
        ---
        name: Send DM
        description: Send a DM
        requires:
          - ../../shared/accounts.md
        ---
        # Send DM

        Look up recipient in [Team Directory](#team-directory).
      MD

      # Rule file that references the skill
      File.write(File.join(test_dir, 'rules', 'comms', 'messaging.md'), <<~MD)
        ---
        description: Messaging commands
        skills:
          - ./skills/send-dm.md
        ---
        # Messaging

        Use skills to send messages.
      MD

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when a skill requires a file already in the profile' do
      before do
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => [
              'rules/shared/accounts.md',    # In profile
              'rules/comms/messaging.md'      # Has skill with requires: accounts.md
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'does not inline the required file into the skill' do
        cli.invoke(:squash, ['test_recipe'])

        skill_content = File.read('.claude/skills/send-dm/SKILL.md', encoding: 'UTF-8')
        # Should NOT contain the accounts data since it's in the profile
        expect(skill_content).not_to include('Alice')
        expect(skill_content).not_to include('Bob')
        expect(skill_content).not_to include('| Name | ID |')
        # But should still have the skill's own content
        expect(skill_content).to include('Send DM')
        expect(skill_content).to include('Look up recipient')
      end

      it 'includes the required file in the profile' do
        cli.invoke(:squash, ['test_recipe'])

        profile_content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(profile_content).to include('Team Directory')
        expect(profile_content).to include('Alice')
      end
    end

    context 'when a skill requires a file NOT in the profile' do
      before do
        # Profile does NOT include accounts.md
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => [
              'rules/comms/messaging.md'  # Has skill, but accounts.md NOT in profile
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'still inlines the required file into the skill' do
        cli.invoke(:squash, ['test_recipe'])

        skill_content = File.read('.claude/skills/send-dm/SKILL.md', encoding: 'UTF-8')
        expect(skill_content).to include('Team Directory')
        expect(skill_content).to include('Alice')
      end
    end
  end

  describe 'skill requires deduplication in subagents' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'agent', 'skills'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'parent'))

      # Shared file
      File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
        ---
        description: Team account IDs
        ---
        # Team Directory

        | Name | ID |
        |------|-----|
        | Alice | 123 |
      MD

      # Skill requiring accounts
      File.write(File.join(test_dir, 'rules', 'agent', 'skills', 'post-comment.md'), <<~MD)
        ---
        name: Post Comment
        description: Post a Jira comment
        requires:
          - ../../shared/accounts.md
        ---
        # Post Comment

        Look up user in [Team Directory](#team-directory).
      MD

      # Agent rule referencing the skill
      File.write(File.join(test_dir, 'rules', 'agent', 'comms.md'), <<~MD)
        ---
        description: Communication rules
        skills:
          - ./skills/post-comment.md
        ---
        # Communication

        Handle all comms tasks.
      MD

      # Agent rule that includes accounts (profile content for subagent)
      File.write(File.join(test_dir, 'rules', 'shared', 'agent-base.md'), <<~MD)
        ---
        description: Base agent rules
        requires:
          - ./accounts.md
        ---
        # Agent Base

        Base content for agents.
      MD

      # Parent rule
      File.write(File.join(test_dir, 'rules', 'parent', 'main.md'), <<~MD)
        ---
        description: Parent rules
        ---
        # Parent

        Parent content.
      MD

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when subagent profile includes a file also required by its skill' do
      before do
        recipes_content = {
          'comms-recipe' => {
            'description' => 'Comms recipe',
            'files' => [
              'rules/shared/agent-base.md',  # requires accounts.md → in subagent profile
              'rules/agent/comms.md'          # has skill requiring accounts.md
            ]
          },
          'parent_recipe' => {
            'description' => 'Parent',
            'files' => ['rules/parent/main.md'],
            'subagents' => [
              { 'name' => 'comms', 'recipe' => 'comms-recipe' }
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'does not inline accounts into the subagent skill' do
        cli.invoke(:squash, ['parent_recipe'])

        skill_content = File.read('.claude/skills/post-comment/SKILL.md', encoding: 'UTF-8')
        expect(skill_content).not_to include('Alice')
        expect(skill_content).not_to include('| Name | ID |')
        expect(skill_content).to include('Post Comment')
      end
    end
  end
end
