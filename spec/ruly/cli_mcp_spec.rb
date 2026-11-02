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
      'Ref' => {
        'args' => ['-y', '@anthropic/mcp-ref'],
        'command' => 'npx'
      },
      'atlassian' => {
        '_description' => 'Atlassian integration',
        'args' => ['-y', '@anthropic/mcp-atlassian'],
        'command' => 'npx'
      },
      'playwright' => {
        'args' => ['-y', '@anthropic/mcp-playwright'],
        'command' => 'npx'
      },
      'teams' => {
        'args' => ['-y', '@anthropic/mcp-teams'],
        'command' => 'npx'
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
    original_home = Dir.home

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

  describe '#collect_all_mcp_servers' do
    let(:recipes_with_subagents) do
      {
        'recipes' => {
          'child-a' => {
            'description' => 'Child A with MCP',
            'files' => [],
            'mcp_servers' => %w[teams playwright]
          },
          'child-b' => {
            'description' => 'Child B with nested subagent',
            'files' => [],
            'mcp_servers' => ['atlassian'],
            'subagents' => [
              {'name' => 'grandchild', 'recipe' => 'grandchild'}
            ]
          },
          'grandchild' => {
            'description' => 'Grandchild with MCP',
            'files' => [],
            'mcp_servers' => ['Ref']
          },
          'parent' => {
            'description' => 'Parent recipe',
            'files' => [],
            'mcp_servers' => ['playwright'],
            'subagents' => [
              {'name' => 'child_a', 'recipe' => 'child-a'},
              {'name' => 'child_b', 'recipe' => 'child-b'}
            ]
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
      expect(result).to include('teams', 'playwright', 'atlassian')
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
      expect(result).to eq(%w[teams playwright])
    end

    it 'handles circular references without infinite loop' do
      circular_recipes = {
        'recipes' => {
          'recipe-a' => {
            'description' => 'Recipe A',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{'name' => 'b', 'recipe' => 'recipe-b'}]
          },
          'recipe-b' => {
            'description' => 'Recipe B',
            'files' => [],
            'mcp_servers' => ['playwright'],
            'subagents' => [{'name' => 'a', 'recipe' => 'recipe-a'}]
          }
        }
      }
      File.write(File.join(test_dir, 'recipes.yml'), circular_recipes.to_yaml)

      recipe_config = circular_recipes['recipes']['recipe-a']
      result = cli.send(:collect_all_mcp_servers, recipe_config)
      expect(result).to contain_exactly('teams', 'playwright')
    end

    it 'handles missing subagent recipes gracefully' do
      missing_recipes = {
        'recipes' => {
          'parent' => {
            'description' => 'Parent',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{'name' => 'missing', 'recipe' => 'nonexistent'}]
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
          'comms-sub' => {
            'description' => 'Comms subagent with MCP servers',
            'files' => [],
            'mcp_servers' => %w[teams playwright],
            'subagents' => [
              {'name' => 'teams_dm', 'recipe' => 'teams-dm-sub'}
            ]
          },
          'parent-no-mcp' => {
            'description' => 'Parent with no MCP but subagents that have MCP',
            'files' => [],
            'subagents' => [
              {'name' => 'comms', 'recipe' => 'comms-sub'}
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
      expect(content['mcpServers'].keys).to contain_exactly('teams', 'playwright')
    end

    it 'merges parent MCP servers with subagent MCP servers' do
      recipe_config = propagation_recipes['recipes']['parent-no-mcp'].dup
      recipe_config['mcp_servers'] = ['playwright']
      all_servers = cli.send(:collect_all_mcp_servers, recipe_config)
      recipe_config_with_mcp = recipe_config.merge('mcp_servers' => all_servers)
      cli.send(:update_mcp_settings, recipe_config_with_mcp)

      content = JSON.parse(File.read('.mcp.json'))
      expect(content['mcpServers'].keys).to contain_exactly('playwright', 'teams')
    end
  end
end
