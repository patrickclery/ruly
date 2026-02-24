# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Checks::DuplicateSkillRequires do
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

  describe '.call' do
    let(:find_rule_file) { ->(path) { File.join(test_dir, path) } }
    let(:parse_frontmatter) { Ruly::Services::FrontmatterParser.method(:parse) }

    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'comms', 'skills'))

      File.write(File.join(test_dir, 'rules', 'shared', 'accounts.md'), <<~MD)
        ---
        description: Team accounts
        ---
        # Accounts

        Account data here.
      MD
    end

    context 'when a file is required by 2+ skills and not in profile' do
      it 'returns a warning suggesting promotion to profile' do
        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          },
          {
            path: 'rules/comms/skills/post-comment.md',
            content: '# Post Comment',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Post Comment"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new)

        expect(result[:passed]).to be(true) # Warnings don't fail the build
        expect(result[:warnings]).not_to be_empty
        expect(result[:warnings].first[:file]).to include('accounts.md')
        expect(result[:warnings].first[:skills].size).to eq(2)
      end
    end

    context 'when a file is required by 2+ skills but IS in profile' do
      it 'returns no warnings' do
        accounts_path = File.realpath(File.join(test_dir, 'rules', 'shared', 'accounts.md'))

        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          },
          {
            path: 'rules/comms/skills/post-comment.md',
            content: '# Post Comment',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Post Comment"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new([accounts_path]))

        expect(result[:warnings]).to be_empty
      end
    end

    context 'when a file is required by only 1 skill' do
      it 'returns no warnings' do
        skill_files = [
          {
            path: 'rules/comms/skills/send-dm.md',
            content: '# Send DM',
            original_content: "---\nrequires:\n  - ../../shared/accounts.md\n---\n# Send DM"
          }
        ]

        result = described_class.call(skill_files,
                                      find_rule_file:,
                                      parse_frontmatter:,
                                      profile_paths: Set.new)

        expect(result[:warnings]).to be_empty
      end
    end
  end
end
