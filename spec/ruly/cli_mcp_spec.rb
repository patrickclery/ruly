# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'json'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:test_dir) { Dir.mktmpdir }
  let(:mcp_config_dir) { File.join(test_dir, '.config', 'ruly') }
  let(:mcp_config_file) { File.join(mcp_config_dir, 'mcp.json') }

  # Sample MCP server configurations
  let(:mcp_servers_config) do
    {
      'atlassian' => {
        'command' => 'npx',
        'args' => ['-y', '@anthropic/mcp-atlassian'],
        '_description' => 'Atlassian integration'
      },
      'teams' => {
        'command' => 'npx',
        'args' => ['-y', '@anthropic/mcp-teams']
      },
      'playwright' => {
        'command' => 'npx',
        'args' => ['-y', '@anthropic/mcp-playwright']
      },
      'task-master-ai' => {
        'command' => 'node',
        'args' => ['/path/to/task-master']
      }
    }
  end

  # Sample recipes configuration
  let(:recipes_config) do
    {
      'recipes' => {
        'test-recipe' => {
          'description' => 'Test recipe with MCP servers',
          'files' => [],
          'mcp_servers' => %w[atlassian teams]
        },
        'test-recipe-no-mcp' => {
          'description' => 'Test recipe without MCP servers',
          'files' => []
        }
      }
    }
  end

  around do |example|
    original_dir = Dir.pwd
    original_home = ENV.fetch('HOME', nil)

    begin
      # Set up fake HOME for mcp.json lookup
      ENV['HOME'] = test_dir
      FileUtils.mkdir_p(mcp_config_dir)
      File.write(mcp_config_file, JSON.pretty_generate(mcp_servers_config))

      # Create recipes.yml
      File.write(File.join(test_dir, 'recipes.yml'), recipes_config.to_yaml)

      Dir.chdir(test_dir)
      example.run
    ensure
      Dir.chdir(original_dir)
      ENV['HOME'] = original_home
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe '#mcp' do
    context 'with server names as arguments' do
      it 'creates .mcp.json with specified servers' do
        cli.mcp('atlassian', 'teams')

        expect(File.exist?('.mcp.json')).to be true
        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('atlassian', 'teams')
      end

      it 'adds type: stdio for servers with command' do
        cli.mcp('atlassian')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers']['atlassian']['type']).to eq('stdio')
      end

      it 'filters out fields starting with underscore' do
        cli.mcp('atlassian')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers']['atlassian']).not_to have_key('_description')
      end

      it 'warns when server is not found in config' do
        expect { cli.mcp('nonexistent') }.to output(/not found/).to_stdout
      end

      it 'creates .mcp.json even with some invalid servers' do
        expect { cli.mcp('atlassian', 'nonexistent') }.to output(/not found/).to_stdout

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to eq(['atlassian'])
      end
    end

    context 'with --append option' do
      before do
        # Create existing .mcp.json
        existing = {
          'mcpServers' => {
            'playwright' => { 'command' => 'existing', 'type' => 'stdio' }
          }
        }
        File.write('.mcp.json', JSON.pretty_generate(existing))
      end

      it 'merges with existing .mcp.json' do
        cli.options = { append: true }
        cli.mcp('atlassian')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('playwright', 'atlassian')
      end

      it 'overwrites existing server if same name' do
        cli.options = { append: true }
        cli.mcp('playwright')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers']['playwright']['args']).to eq(['-y', '@anthropic/mcp-playwright'])
      end
    end

    context 'with --recipe option' do
      before do
        allow(cli).to receive(:recipes_file).and_return(File.join(test_dir, 'recipes.yml'))
      end

      it 'loads MCP servers from recipe' do
        cli.options = { recipe: 'test-recipe' }
        cli.mcp

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('atlassian', 'teams')
      end

      it 'warns when recipe has no mcp_servers' do
        cli.options = { recipe: 'test-recipe-no-mcp' }
        expect { cli.mcp }.to output(/no MCP servers/i).to_stdout
      end

      it 'warns when recipe is not found' do
        cli.options = { recipe: 'nonexistent-recipe' }
        expect { cli.mcp }.to output(/not found/i).to_stdout
      end
    end

    context 'with --recipe and --append options combined' do
      before do
        allow(cli).to receive(:recipes_file).and_return(File.join(test_dir, 'recipes.yml'))

        existing = {
          'mcpServers' => {
            'playwright' => { 'command' => 'existing', 'type' => 'stdio' }
          }
        }
        File.write('.mcp.json', JSON.pretty_generate(existing))
      end

      it 'appends recipe servers to existing .mcp.json' do
        cli.options = { recipe: 'test-recipe', append: true }
        cli.mcp

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('playwright', 'atlassian', 'teams')
      end
    end

    context 'with servers and --recipe combined' do
      before do
        allow(cli).to receive(:recipes_file).and_return(File.join(test_dir, 'recipes.yml'))
      end

      it 'combines explicit servers with recipe servers' do
        cli.options = { recipe: 'test-recipe' }
        cli.mcp('playwright')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('atlassian', 'teams', 'playwright')
      end
    end

    context 'with no arguments and no recipe' do
      it 'shows error message' do
        cli.options = {}
        expect { cli.mcp }.to output(/no servers specified/i).to_stdout
      end
    end

    context 'when mcp.json config file does not exist' do
      before do
        FileUtils.rm_f(mcp_config_file)
      end

      it 'shows error about missing config' do
        expect { cli.mcp('atlassian') }.to output(/mcp\.json.*not found/i).to_stdout
      end
    end
  end
end
