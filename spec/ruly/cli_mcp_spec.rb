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
      'mattermost' => {
        'args' => ['-y', '@anthropic/mcp-mattermost'],
        'command' => 'npx'
      },
      'playwright' => {
        'args' => ['-y', '@anthropic/mcp-playwright'],
        'command' => 'npx'
      },
      'task-master-ai' => {
        'args' => ['/path/to/task-master'],
        'command' => 'node'
      },
      'teams' => {
        'args' => ['-y', '@anthropic/mcp-teams'],
        'command' => 'npx'
      }
    }
  end

  # Sample profiles configuration
  let(:profiles_config) do
    {
      'profiles' => {
        'test-profile' => {
          'description' => 'Test profile with MCP servers',
          'files' => [],
          'mcp_servers' => %w[atlassian teams]
        },
        'test-profile-no-mcp' => {
          'description' => 'Test profile without MCP servers',
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

      # Create profiles.yml
      File.write(File.join(test_dir, 'profiles.yml'), profiles_config.to_yaml)

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

        expect(File.exist?('.mcp.json')).to be(true)
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
            'playwright' => {'command' => 'existing', 'type' => 'stdio'}
          }
        }
        File.write('.mcp.json', JSON.pretty_generate(existing))
      end

      it 'merges with existing .mcp.json' do
        cli.options = {append: true}
        cli.mcp('atlassian')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('playwright', 'atlassian')
      end

      it 'overwrites existing server if same name' do
        cli.options = {append: true}
        cli.mcp('playwright')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers']['playwright']['args']).to eq(['-y', '@anthropic/mcp-playwright'])
      end
    end

    context 'with --profile option' do
      before do
        allow(cli).to receive(:profiles_file).and_return(File.join(test_dir, 'profiles.yml'))
      end

      it 'loads MCP servers from profile' do
        cli.options = {profile: 'test-profile'}
        cli.mcp

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('atlassian', 'teams')
      end

      it 'warns when profile has no mcp_servers' do
        cli.options = {profile: 'test-profile-no-mcp'}
        expect { cli.mcp }.to output(/no MCP servers/i).to_stdout
      end

      it 'warns when profile is not found' do
        cli.options = {profile: 'nonexistent-profile'}
        expect { cli.mcp }.to output(/not found/i).to_stdout
      end
    end

    context 'with --profile and --append options combined' do
      before do
        allow(cli).to receive(:profiles_file).and_return(File.join(test_dir, 'profiles.yml'))

        existing = {
          'mcpServers' => {
            'playwright' => {'command' => 'existing', 'type' => 'stdio'}
          }
        }
        File.write('.mcp.json', JSON.pretty_generate(existing))
      end

      it 'appends profile servers to existing .mcp.json' do
        cli.options = {append: true, profile: 'test-profile'}
        cli.mcp

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('playwright', 'atlassian', 'teams')
      end
    end

    context 'with servers and --profile combined' do
      before do
        allow(cli).to receive(:profiles_file).and_return(File.join(test_dir, 'profiles.yml'))
      end

      it 'combines explicit servers with profile servers' do
        cli.options = {profile: 'test-profile'}
        cli.mcp('playwright')

        content = JSON.parse(File.read('.mcp.json'))
        expect(content['mcpServers'].keys).to contain_exactly('atlassian', 'teams', 'playwright')
      end
    end

    context 'with no arguments and no profile' do
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
    let(:profiles_with_subagents) do
      {
        'profiles' => {
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
              {'name' => 'grandchild', 'profile' => 'grandchild'}
            ]
          },
          'grandchild' => {
            'description' => 'Grandchild with MCP',
            'files' => [],
            'mcp_servers' => ['Ref']
          },
          'parent' => {
            'description' => 'Parent profile',
            'files' => [],
            'mcp_servers' => ['playwright'],
            'subagents' => [
              {'name' => 'child_a', 'profile' => 'child-a'},
              {'name' => 'child_b', 'profile' => 'child-b'}
            ]
          }
        }
      }
    end

    before do
      File.write(File.join(test_dir, 'profiles.yml'), profiles_with_subagents.to_yaml)
      allow(cli).to receive(:profiles_file).and_return(File.join(test_dir, 'profiles.yml'))
    end

    it 'collects MCP servers from direct subagents' do
      profile_config = profiles_with_subagents['profiles']['parent']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to include('teams', 'mattermost', 'atlassian')
    end

    it 'collects MCP servers from nested subagents (grandchildren)' do
      profile_config = profiles_with_subagents['profiles']['parent']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to include('Ref')
    end

    it 'includes parent MCP servers unchanged' do
      profile_config = profiles_with_subagents['profiles']['parent']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to include('playwright')
    end

    it 'deduplicates MCP servers' do
      profile_config = profiles_with_subagents['profiles']['parent']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to eq(result.uniq)
    end

    it 'returns only own servers when no subagents' do
      profile_config = profiles_with_subagents['profiles']['child-a']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to eq(%w[teams mattermost])
    end

    it 'handles circular references without infinite loop' do
      circular_profiles = {
        'profiles' => {
          'profile-a' => {
            'description' => 'Profile A',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{'name' => 'b', 'profile' => 'profile-b'}]
          },
          'profile-b' => {
            'description' => 'Profile B',
            'files' => [],
            'mcp_servers' => ['mattermost'],
            'subagents' => [{'name' => 'a', 'profile' => 'profile-a'}]
          }
        }
      }
      File.write(File.join(test_dir, 'profiles.yml'), circular_profiles.to_yaml)

      profile_config = circular_profiles['profiles']['profile-a']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to contain_exactly('teams', 'mattermost')
    end

    it 'handles missing subagent profiles gracefully' do
      missing_profiles = {
        'profiles' => {
          'parent' => {
            'description' => 'Parent',
            'files' => [],
            'mcp_servers' => ['teams'],
            'subagents' => [{'name' => 'missing', 'profile' => 'nonexistent'}]
          }
        }
      }
      File.write(File.join(test_dir, 'profiles.yml'), missing_profiles.to_yaml)

      profile_config = missing_profiles['profiles']['parent']
      result = cli.send(:collect_all_mcp_servers, profile_config)
      expect(result).to eq(['teams'])
    end
  end

  describe 'squash MCP propagation' do
    let(:propagation_profiles) do
      {
        'profiles' => {
          'comms-sub' => {
            'description' => 'Comms subagent with MCP servers',
            'files' => [],
            'mcp_servers' => %w[teams mattermost],
            'subagents' => [
              {'name' => 'teams_dm', 'profile' => 'teams-dm-sub'}
            ]
          },
          'parent-no-mcp' => {
            'description' => 'Parent with no MCP but subagents that have MCP',
            'files' => [],
            'subagents' => [
              {'name' => 'comms', 'profile' => 'comms-sub'}
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
      File.write(File.join(test_dir, 'profiles.yml'), propagation_profiles.to_yaml)
      allow(cli).to receive(:profiles_file).and_return(File.join(test_dir, 'profiles.yml'))
    end

    it 'propagates subagent MCP servers into parent .mcp.json during squash' do
      profile_config = propagation_profiles['profiles']['parent-no-mcp']
      all_servers = cli.send(:collect_all_mcp_servers, profile_config)
      profile_config_with_mcp = profile_config.merge('mcp_servers' => all_servers)
      cli.send(:update_mcp_settings, profile_config_with_mcp)

      content = JSON.parse(File.read('.mcp.json'))
      expect(content['mcpServers'].keys).to contain_exactly('teams', 'mattermost')
    end

    it 'merges parent MCP servers with subagent MCP servers' do
      profile_config = propagation_profiles['profiles']['parent-no-mcp'].dup
      profile_config['mcp_servers'] = ['playwright']
      all_servers = cli.send(:collect_all_mcp_servers, profile_config)
      profile_config_with_mcp = profile_config.merge('mcp_servers' => all_servers)
      cli.send(:update_mcp_settings, profile_config_with_mcp)

      content = JSON.parse(File.read('.mcp.json'))
      expect(content['mcpServers'].keys).to contain_exactly('playwright', 'teams', 'mattermost')
    end
  end
end
