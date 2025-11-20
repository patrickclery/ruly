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

  describe '#recipe_type' do
    context 'with array recipe' do
      it 'returns :agent' do
        recipe_value = %w[recipe1 recipe2]
        expect(cli.send(:recipe_type, recipe_value)).to eq(:agent)
      end

      it 'returns :agent for empty array' do
        recipe_value = []
        expect(cli.send(:recipe_type, recipe_value)).to eq(:agent)
      end
    end

    context 'with hash recipe' do
      it 'returns :standard' do
        recipe_value = {'description' => 'Test', 'files' => ['test.md']}
        expect(cli.send(:recipe_type, recipe_value)).to eq(:standard)
      end

      it 'returns :standard for empty hash' do
        recipe_value = {}
        expect(cli.send(:recipe_type, recipe_value)).to eq(:standard)
      end
    end

    context 'with invalid recipe type' do
      it 'returns :invalid for string' do
        recipe_value = 'invalid'
        expect(cli.send(:recipe_type, recipe_value)).to eq(:invalid)
      end

      it 'returns :invalid for nil' do
        recipe_value = nil
        expect(cli.send(:recipe_type, recipe_value)).to eq(:invalid)
      end

      it 'returns :invalid for number' do
        recipe_value = 123
        expect(cli.send(:recipe_type, recipe_value)).to eq(:invalid)
      end
    end
  end

  describe '#determine_output_file' do
    let(:default_options) { {output_file: 'CLAUDE.local.md'} }

    context 'with array recipe (agent)' do
      let(:recipe_value) { %w[recipe1 recipe2] }

      it 'routes to .claude/agents/ directory' do
        output = cli.send(:determine_output_file, 'test_agent', recipe_value, default_options)
        expect(output).to eq('.claude/agents/test_agent.md')
      end

      it 'uses recipe name in filename' do
        output = cli.send(:determine_output_file, 'my_custom_agent', recipe_value, default_options)
        expect(output).to eq('.claude/agents/my_custom_agent.md')
      end
    end

    context 'with hash recipe (standard)' do
      let(:recipe_value) { {'description' => 'Test', 'files' => ['test.md']} }

      it 'uses default output file' do
        output = cli.send(:determine_output_file, 'test_recipe', recipe_value, default_options)
        expect(output).to eq('CLAUDE.local.md')
      end
    end

    context 'with explicit output file override' do
      let(:recipe_value) { %w[recipe1 recipe2] }
      let(:custom_options) { {output_file: 'CUSTOM.md'} }

      it 'respects user override for array recipe' do
        output = cli.send(:determine_output_file, 'test_agent', recipe_value, custom_options)
        expect(output).to eq('CUSTOM.md')
      end

      it 'respects user override for hash recipe' do
        hash_recipe = {'files' => ['test.md']}
        output = cli.send(:determine_output_file, 'test_recipe', hash_recipe, custom_options)
        expect(output).to eq('CUSTOM.md')
      end
    end
  end

  describe '#squash with array recipe (agent generation)' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')
      File.write(File.join(test_dir, 'rules', 'another.md'), '# Another Rule')

      # Mock gem_root and recipes_file
      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'with array recipe' do
      before do
        # Create recipes.yml with an array recipe (agent format)
        recipes_content = {
          'test_agent' => ['rules/test.md', 'rules/another.md']
        }

        # Mock load_all_recipes - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'creates agent file in .claude/agents/ directory' do
        cli.invoke(:squash, ['test_agent'])

        expect(File.exist?('.claude/agents/test_agent.md')).to be(true)
      end

      it 'does not create default CLAUDE.local.md file' do
        cli.invoke(:squash, ['test_agent'])

        # Agent recipes should create .claude/agents/name.md, not CLAUDE.local.md
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

        expect(output).to include("agent generation mode with 'test_agent' recipe")
      end
    end

    context 'with --output-file override on array recipe' do
      before do
        recipes_content = {
          'test_agent' => ['rules/test.md']
        }

        # Mock load_all_recipes - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'respects explicit output file override' do
        cli.invoke(:squash, ['test_agent'], output_file: 'CUSTOM.md')

        expect(File.exist?('CUSTOM.md')).to be(true)
        expect(File.exist?('.claude/agents/test_agent.md')).to be(false)
      end
    end
  end

  describe '#squash backward compatibility with hash recipes' do
    before do
      # Create test rules
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test Rule')

      # Mock gem_root
      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'with traditional hash recipe' do
      before do
        # Create recipes.yml with a traditional hash recipe
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe',
            'files' => ['rules/test.md']
          }
        }

        # Mock load_all_recipes - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'creates CLAUDE.local.md as before' do
        cli.invoke(:squash, ['test_recipe'])

        expect(File.exist?('CLAUDE.local.md')).to be(true)
      end

      it 'does not create agent directory for hash recipe' do
        cli.invoke(:squash, ['test_recipe'])

        expect(File.exist?('CLAUDE.local.md')).to be(true)
        expect(Dir.exist?('.claude/agents')).to be(false)
      end

      it 'shows standard squash mode in output' do
        output = capture(:stdout) do
          cli.invoke(:squash, ['test_recipe'])
        end

        expect(output).to include("squash mode with 'test_recipe' recipe")
        expect(output).not_to include('agent generation mode')
      end

      it 'includes content from recipe files' do
        cli.invoke(:squash, ['test_recipe'])

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(content).to include('Test Rule')
      end
    end

    context 'with no recipe specified' do
      it 'uses default behavior without recipe' do
        cli.invoke(:squash)

        expect(File.exist?('CLAUDE.local.md')).to be(true)
      end
    end

    context 'with --output-file override on hash recipe' do
      before do
        recipes_content = {
          'test_recipe' => {
            'files' => ['rules/test.md']
          }
        }

        # Mock load_all_recipes - necessary due to Thor's invoke architecture
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'respects explicit output file override' do
        cli.invoke(:squash, ['test_recipe'], output_file: 'CUSTOM.md')

        expect(File.exist?('CUSTOM.md')).to be(true)
        expect(File.exist?('CLAUDE.local.md')).to be(false)
      end
    end
  end

  describe '#squash dry-run mode with array recipes' do
    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))
      File.write(File.join(test_dir, 'rules', 'test.md'), '# Test')

      recipes_content = {
        'test_agent' => ['rules/test.md']
      }

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))

      # Mock load_all_recipes - necessary due to Thor's invoke architecture
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
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
