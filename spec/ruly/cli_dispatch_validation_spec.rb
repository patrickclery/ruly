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

  describe 'dispatch validation' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))

      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when a file dispatches a subagent not registered in the profile (Validation 1)' do
      before do
        # Create a rule file with dispatches: frontmatter
        File.write(File.join(test_dir, 'rules', 'dispatching.md'), <<~MARKDOWN)
          ---
          dispatches:
            - context_grabber
          ---
          # Dispatching Rule

          This rule dispatches the context_grabber subagent.
        MARKDOWN

        profiles_content = {
          'parent' => {
            'description' => 'Parent profile with no subagents',
            'files' => ['rules/dispatching.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises an error about unregistered dispatch' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /dispatches: context_grabber/)
      end

      it 'includes guidance to add subagent registration' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /subagents/)
      end
    end

    context 'when a file dispatches a subagent that IS registered in the profile (Validation 1)' do
      before do
        # Create rule files
        File.write(File.join(test_dir, 'rules', 'dispatching.md'), <<~MARKDOWN)
          ---
          dispatches:
            - context_grabber
          ---
          # Dispatching Rule

          This rule dispatches the context_grabber subagent.
        MARKDOWN

        File.write(File.join(test_dir, 'rules', 'grabber.md'), '# Grabber Rule')

        profiles_content = {
          'context-grabber' => {
            'description' => 'Context grabber profile',
            'files' => ['rules/grabber.md']
          },
          'parent' => {
            'description' => 'Parent profile with registered subagent',
            'files' => ['rules/dispatching.md'],
            'subagents' => [
              {'name' => 'context_grabber', 'profile' => 'context-grabber'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'does not raise an error' do
        expect { cli.invoke(:squash, ['parent']) }.not_to raise_error
      end
    end

    context 'when a subagent profile contains files with dispatches: (Validation 2)' do
      before do
        # Create rule files
        File.write(File.join(test_dir, 'rules', 'parent-rule.md'), '# Parent Rule')

        File.write(File.join(test_dir, 'rules', 'reviewing-prs.md'), <<~MARKDOWN)
          ---
          dispatches:
            - context_grabber
          ---
          # Reviewing PRs

          This dispatches context_grabber.
        MARKDOWN

        File.write(File.join(test_dir, 'rules', 'use-context-grabber.md'), <<~MARKDOWN)
          ---
          dispatches:
            - context_grabber
          ---
          # Use Context Grabber

          This also dispatches context_grabber.
        MARKDOWN

        profiles_content = {
          'core-reviewer' => {
            'description' => 'Core reviewer profile',
            'files' => ['rules/reviewing-prs.md', 'rules/use-context-grabber.md']
          },
          'parent' => {
            'description' => 'Parent profile',
            'files' => ['rules/parent-rule.md'],
            'subagents' => [
              {'name' => 'core_reviewer', 'profile' => 'core-reviewer'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises an error about subagent dispatching' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /Subagent 'core_reviewer'.*dispatch/m)
      end

      it 'lists the files that dispatch' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /reviewing-prs\.md.*context_grabber/m)
      end

      it 'includes the cannot dispatch message' do
        expect do
          cli.invoke(:squash, ['parent'])
        end.to raise_error(Ruly::Error, /Subagents cannot dispatch other subagents/)
      end
    end

    context 'when a subagent profile has no files with dispatches: (Validation 2)' do
      before do
        File.write(File.join(test_dir, 'rules', 'parent-rule.md'), '# Parent Rule')
        File.write(File.join(test_dir, 'rules', 'clean-rule.md'), '# Clean Rule')

        profiles_content = {
          'clean-profile' => {
            'description' => 'Clean profile with no dispatches',
            'files' => ['rules/clean-rule.md']
          },
          'parent' => {
            'description' => 'Parent profile',
            'files' => ['rules/parent-rule.md'],
            'subagents' => [
              {'name' => 'clean_agent', 'profile' => 'clean-profile'}
            ]
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'does not raise an error' do
        expect { cli.invoke(:squash, ['parent']) }.not_to raise_error
      end

      it 'creates the subagent file' do
        cli.invoke(:squash, ['parent'])

        expect(File.exist?('.claude/agents/clean_agent.md')).to be(true)
      end
    end
  end
end
