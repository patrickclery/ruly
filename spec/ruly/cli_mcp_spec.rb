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
      },
      'mattermost' => {
        'command' => 'npx',
        'args' => ['-y', '@anthropic/mcp-mattermost']
      },
      'Ref' => {
        'command' => 'npx',
        'args' => ['-y', '@anthropic/mcp-ref']
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

  describe '#collect_all_mcp_servers' do
    let(:recipes_with_subagents) do
      {
        'recipes' => {
          'parent' => {
            'description' => 'Parent recipe',
            'files' => [],
            'mcp_servers' => ['playwright'],
            'subagents' => [
              { 'name' => 'child_a', 'recipe' => 'child-a' },
              { 'name' => 'child_b', 'recipe' => 'child-b' }
            ]
          },
          'child-a' => {
            'description' => 'Child A with MCP',
            'files' => [],
            'mcp_servers' => %w[teams mattermost]
          },
          'child-b' => {
            'description' => 'Child B with nested subagent',
            'files' => [],
            'mcp_servers' => ['atlassian'],
            'subagents' => [
              { 'name' => 'grandchild', 'recipe' => 'grandchild' }
            ]
          },
          'grandchild' => {
            'description' => 'Grandchild with MCP',
            'files' => [],
            'mcp_servers' => ['Ref']
          }
        }
      }
    end

    before do
      File.write(File.join(test_dir, 'recipes.yml'), recipes_with_subagents.to_yaml)
      allow(cli).to receive(:recipes_file).and_return(File.join(test_dir, 'recipes.yml'))
    end

    it 'collects MCP servers from direct subagents' do
      recipe_config = recipes_with_subagents['recipes']['parent']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to include('teams', 'mattermost', 'atlassian')
    end

    it 'collects MCP servers from nested subagents (grandchildren)' do
      recipe_config = recipes_with_subagents['recipes']['parent']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to include('Ref')
    end

    it 'includes parent MCP servers unchanged' do
      recipe_config = recipes_with_subagents['recipes']['parent']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to include('playwright')
    end

    it 'deduplicates MCP servers' do
      recipe_config = recipes_with_subagents['recipes']['parent']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to eq(result.uniq)
    end

    it 'returns only own servers when no subagents' do
      recipe_config = recipes_with_subagents['recipes']['child-a']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to eq(%w[teams mattermost])
    end

    it 'handles circular references without infinite loop' do
      circular_recipes = {
        'recipes' => {
          'recipe-a' => {
            'description' => 'Recipe A',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{ 'name' => 'b', 'recipe' => 'recipe-b' }]
          },
          'recipe-b' => {
            'description' => 'Recipe B',
            'files' => [],
            'mcp_servers' => ['mattermost'],
            'subagents' => [{ 'name' => 'a', 'recipe' => 'recipe-a' }]
          }
        }
      }
      File.write(File.join(test_dir, 'recipes.yml'), circular_recipes.to_yaml)

      recipe_config = circular_recipes['recipes']['recipe-a']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to contain_exactly('teams', 'mattermost')
    end

    it 'handles missing subagent recipes gracefully' do
      missing_recipes = {
        'recipes' => {
          'parent' => {
            'description' => 'Parent',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{ 'name' => 'missing', 'recipe' => 'nonexistent' }]
          }
        }
      }
      File.write(File.join(test_dir, 'recipes.yml'), missing_recipes.to_yaml)

      recipe_config = missing_recipes['recipes']['parent']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to eq(['teams'])
    end
  end

  describe 'squash MCP propagation' do
    let(:propagation_recipes) do
      {
        'recipes' => {
          'parent-no-mcp' => {
            'description' => 'Parent with no MCP but subagents that have MCP',
            'files' => [],
            'subagents' => [
              { 'name' => 'comms', 'recipe' => 'comms-sub' }
            ]
          },
          'comms-sub' => {
            'description' => 'Comms subagent with MCP servers',
            'files' => [],
            'mcp_servers' => %w[teams mattermost],
            'subagents' => [
              { 'name' => 'teams_dm', 'recipe' => 'teams-dm-sub' }
            ]
          },
          'teams-dm-sub' => {
            'description' => 'Teams DM execution subagent',
            'files' => [],
            'mcp_servers' => ['teams']
          }
        }
      }
    end

    before do
      File.write(File.join(test_dir, 'recipes.yml'), propagation_recipes.to_yaml)
      allow(cli).to receive(:recipes_file).and_return(File.join(test_dir, 'recipes.yml'))
    end

    it 'propagates subagent MCP servers into parent .mcp.json during squash' do
      recipe_config = propagation_recipes['recipes']['parent-no-mcp']
      all_servers = cli.send(:collect_all_mcp_servers, recipe_config)
      recipe_config_with_mcp = recipe_config.merge('mcp_servers' => all_servers)
      cli.send(:update_mcp_settings, recipe_config_with_mcp)

      content = JSON.parse(File.read('.mcp.json'))
      expect(content['mcpServers'].keys).to contain_exactly('teams', 'mattermost')
    end

    it 'merges parent MCP servers with subagent MCP servers' do
      recipe_config = propagation_recipes['recipes']['parent-no-mcp'].dup
      recipe_config['mcp_servers'] = ['playwright']
      all_servers = cli.send(:collect_all_mcp_servers, recipe_config)
      recipe_config_with_mcp = recipe_config.merge('mcp_servers' => all_servers)
      cli.send(:update_mcp_settings, recipe_config_with_mcp)

      content = JSON.parse(File.read('.mcp.json'))
      expect(content['mcpServers'].keys).to contain_exactly('playwright', 'teams', 'mattermost')
    end
  end
end
