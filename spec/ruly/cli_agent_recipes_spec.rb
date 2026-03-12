# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Ruly::CLI, type: :cli do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    # Store the original directory
    original_dir = Dir.pwd

    begin
      # Change to test directory for the test
      Dir.chdir(test_dir)

      # Run the test
      example.run
    ensure
      # CRITICAL: Always return to original directory before ANY cleanup
      Dir.chdir(original_dir)

      # Only NOW clean up the test directory
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe '#profile_type' do
    context 'with array profile' do
      it 'returns :agent' do
        profile_value = %w[profile1 profile2]
        expect(cli.send(:profile_type, profile_value)).to eq(:agent)
      end

      it 'returns :agent for empty array' do
        profile_value = []
        expect(cli.send(:profile_type, profile_value)).to eq(:agent)
      end
    end

    context 'with hash profile' do
      it 'returns :standard' do
        profile_value = {'description' => 'Test', 'files' => ['test.md']}
        expect(cli.send(:profile_type, profile_value)).to eq(:standard)
      end

      it 'returns :standard for empty hash' do
        profile_value = {}
        expect(cli.send(:profile_type, profile_value)).to eq(:standard)
      end
    end

    context 'with invalid profile type' do
      it 'returns :invalid for string' do
        profile_value = 'invalid'
        expect(cli.send(:profile_type, profile_value)).to eq(:invalid)
      end

      it 'returns :invalid for nil' do
        profile_value = nil
        expect(cli.send(:profile_type, profile_value)).to eq(:invalid)
      end

      it 'returns :invalid for number' do
        profile_value = 123
        expect(cli.send(:profile_type, profile_value)).to eq(:invalid)
      end
    end
  end

  describe '#determine_output_file' do
    let(:default_options) { {output_file: 'CLAUDE.local.md'} }

    context 'with array profile (agent)' do
      let(:profile_value) { %w[profile1 profile2] }

      it 'routes to .claude/agents/ directory' do
        output = cli.send(:determine_output_file, 'test_agent', profile_value, default_options)
        expect(output).to eq('.claude/agents/test_agent.md')
      end

      it 'uses profile name in filename' do
        output = cli.send(:determine_output_file, 'my_custom_agent', profile_value, default_options)
        expect(output).to eq('.claude/agents/my_custom_agent.md')
      end
    end

    context 'with hash profile (standard)' do
      let(:profile_value) { {'description' => 'Test', 'files' => ['test.md']} }

      it 'uses default output file' do
        output = cli.send(:determine_output_file, 'test_profile', profile_value, default_options)
        expect(output).to eq('CLAUDE.local.md')
      end
    end

    context 'with explicit output file override' do
      let(:profile_value) { %w[profile1 profile2] }
      let(:custom_options) { {output_file: 'CUSTOM.md'} }

      it 'respects user override for array profile' do
        output = cli.send(:determine_output_file, 'test_agent', profile_value, custom_options)
        expect(output).to eq('CUSTOM.md')
      end

      it 'respects user override for hash profile' do
        hash_profile = {'files' => ['test.md']}
        output = cli.send(:determine_output_file, 'test_profile', hash_profile, custom_options)
        expect(output).to eq('CUSTOM.md')
      end
    end
  end

  describe '#squash with array profile (agent generation)' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')
      File.write(File.join(test_dir, 'rules', 'another.md'), '# Another Rule')

      # Mock gem_root and profiles_file
      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'with array profile' do
      before do
        # Create profiles.yml with an array profile (agent format)
        profiles_content = {
          'test_agent' => ['rules/test.md', 'rules/another.md']
        }

        # Mock load_all_profiles - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'creates agent file in .claude/agents/ directory' do
        cli.invoke(:squash, ['test_agent'])

        expect(File.exist?('.claude/agents/test_agent.md')).to be(true)
      end

      it 'does not create default CLAUDE.local.md file' do
        cli.invoke(:squash, ['test_agent'])

        # Agent profiles should create .claude/agents/name.md, not CLAUDE.local.md
        expect(File.exist?('CLAUDE.local.md')).to be(false)
      end

      it 'creates .claude/agents/ directory automatically' do
        expect(Dir.exist?('.claude/agents')).to be(false)

        cli.invoke(:squash, ['test_agent'])

        expect(Dir.exist?('.claude/agents')).to be(true)
      end

      it 'includes content from all referenced files' do
        cli.invoke(:squash, ['test_agent'])

        content = File.read('.claude/agents/test_agent.md', encoding: 'UTF-8')
        expect(content).to include('Test Rule')
        expect(content).to include('Another Rule')
      end

      it 'shows agent generation mode in output' do
        output = capture(:stdout) do
          cli.invoke(:squash, ['test_agent'])
        end

        expect(output).to include("agent generation mode with 'test_agent' profile")
      end
    end

    context 'with --output-file override on array profile' do
      before do
        profiles_content = {
          'test_agent' => ['rules/test.md']
        }

        # Mock load_all_profiles - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'respects explicit output file override' do
        cli.invoke(:squash, ['test_agent'], output_file: 'CUSTOM.md')

        expect(File.exist?('CUSTOM.md')).to be(true)
        expect(File.exist?('.claude/agents/test_agent.md')).to be(false)
      end
    end
  end

  describe '#squash backward compatibility with hash profiles' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      # Mock gem_root
      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'with traditional hash profile' do
      before do
        # Create profiles.yml with a traditional hash profile
        profiles_content = {
          'test_profile' => {
            'description' => 'Test profile',
            'files' => ['rules/test.md']
          }
        }

        # Mock load_all_profiles - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'creates CLAUDE.local.md as before' do
        cli.invoke(:squash, ['test_profile'])

        expect(File.exist?('CLAUDE.local.md')).to be(true)
      end

      it 'does not create agent directory for hash profile' do
        cli.invoke(:squash, ['test_profile'])

        expect(File.exist?('CLAUDE.local.md')).to be(true)
        expect(Dir.exist?('.claude/agents')).to be(false)
      end

      it 'shows standard squash mode in output' do
        output = capture(:stdout) do
          cli.invoke(:squash, ['test_profile'])
        end

        expect(output).to include("squash mode with 'test_profile' profile")
        expect(output).not_to include('agent generation mode')
      end

      it 'includes content from profile files' do
        cli.invoke(:squash, ['test_profile'])

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(content).to include('Test Rule')
      end
    end

    context 'with no profile specified' do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return({})
        allow_any_instance_of(described_class).to receive(:rules_dir).and_return(File.join(test_dir, 'rules'))
        allow_any_instance_of(described_class).to receive(:gem_root).and_return(test_dir)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'uses default behavior without profile' do
        cli.invoke(:squash)

        expect(File.exist?('CLAUDE.local.md')).to be(true)
      end
    end

    context 'with --output-file override on hash profile' do
      before do
        profiles_content = {
          'test_profile' => {
            'files' => ['rules/test.md']
          }
        }

        # Mock load_all_profiles - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'respects explicit output file override' do
        cli.invoke(:squash, ['test_profile'], output_file: 'CUSTOM.md')

        expect(File.exist?('CUSTOM.md')).to be(true)
        expect(File.exist?('CLAUDE.local.md')).to be(false)
      end
    end
  end

  describe '#squash dry-run mode with array profiles' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test')

      profiles_content = {
        'test_agent' => ['rules/test.md']
      }

      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))

      # Mock load_all_profiles - necessary due to Thor's invoke architecture
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'shows what would be created without creating files' do
      output = capture(:stdout) do
        cli.invoke(:squash, ['test_agent'], dry_run: true)
      end

      expect(output).to include('.claude/agents/test_agent.md')
      expect(File.exist?('.claude/agents/test_agent.md')).to be(false)
    end
  end

  # Helper method to capture stdout
  def capture(stream)
    original_stream = stream == :stdout ? $stdout : $stderr
    stream_io = StringIO.new
    stream == :stdout ? $stdout = stream_io : $stderr = stream_io
    yield
    stream_io.string
  ensure
    stream == :stdout ? $stdout = original_stream : $stderr = original_stream
  end
end
