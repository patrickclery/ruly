# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'json'

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

  describe 'mcp_servers in rule-file frontmatter' do
    let(:mcp_config_file) { File.join(Dir.home, '.config', 'ruly', 'mcp.json') }
    let(:mcp_config_backup) { File.exist?(mcp_config_file) ? File.read(mcp_config_file) : nil }

    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))

      # Create a rule file with mcp_servers in frontmatter
      File.write(File.join(test_dir, 'rules', 'with_mcp.md'), <<~MD)
        ---
        description: Rule with MCP servers
        mcp_servers:
          - playwright
          - teams
        ---
        # Rule With MCP Servers

        This rule needs playwright and teams MCP servers.
      MD

      # Create a rule file without mcp_servers
      File.write(File.join(test_dir, 'rules', 'without_mcp.md'), <<~MD)
        ---
        description: Rule without MCP servers
        ---
        # Rule Without MCP Servers

        This rule has no MCP server requirements.
      MD

      # Create a rule file with mcp_servers that overlap with profile-level
      File.write(File.join(test_dir, 'rules', 'overlap_mcp.md'), <<~MD)
        ---
        description: Rule with overlapping MCP servers
        mcp_servers:
          - teams
          - atlassian
        ---
        # Rule With Overlapping MCP Servers

        This rule shares some MCP servers with the profile.
      MD

      # Create MCP config file
      mcp_config_dir = File.join(Dir.home, '.config', 'ruly')
      FileUtils.mkdir_p(mcp_config_dir)
      # Trigger let to capture backup before overwriting
      mcp_config_backup

      File.write(mcp_config_file, JSON.generate({
        'Ref' => {'type' => 'http', 'url' => 'https://api.ref.tools/mcp'},
        'atlassian' => {'type' => 'sse', 'url' => 'https://mcp.atlassian.com/v1/sse'},
        'playwright' => {'command' => 'playwright-mcp', 'type' => 'stdio'},
        'teams' => {'command' => 'teams-mcp', 'type' => 'stdio'}
      }))

      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    after do
      # Restore MCP config
      File.write(mcp_config_file, mcp_config_backup) if mcp_config_backup
    end

    context 'when squashing a profile with rule-file mcp_servers' do
      before do
        profiles_content = {
          'test_profile' => {
            'description' => 'Test profile with rule-level MCP',
            'files' => ['rules/with_mcp.md', 'rules/without_mcp.md'],
            'mcp_servers' => ['Ref']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'strips mcp_servers from squashed rule content in CLAUDE.local.md' do
        cli.invoke(:squash, ['test_profile'])

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        # mcp_servers should be stripped from the output
        expect(content).not_to include('mcp_servers:')
        expect(content).not_to include('- playwright')
        expect(content).not_to include('- teams')
        # But the rule content should still be there
        expect(content).to include('Rule With MCP Servers')
        expect(content).to include('Rule Without MCP Servers')
      end

      it 'collects MCP servers from rule frontmatter into .mcp.json' do
        cli.invoke(:squash, ['test_profile'])

        expect(File.exist?('.mcp.json')).to be(true)
        mcp_json = JSON.parse(File.read('.mcp.json'))

        # Should include servers from both profile-level AND rule-file frontmatter
        expect(mcp_json['mcpServers']).to have_key('Ref')
        expect(mcp_json['mcpServers']).to have_key('playwright')
        expect(mcp_json['mcpServers']).to have_key('teams')
      end
    end

    context 'when rule-file mcp_servers overlap with profile-level servers' do
      before do
        profiles_content = {
          'test_overlap' => {
            'description' => 'Test profile with overlapping MCP',
            'files' => ['rules/with_mcp.md', 'rules/overlap_mcp.md'],
            'mcp_servers' => ['teams']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'deduplicates MCP servers in .mcp.json' do
        cli.invoke(:squash, ['test_overlap'])

        mcp_json = JSON.parse(File.read('.mcp.json'))
        server_names = mcp_json['mcpServers'].keys

        # 'teams' appears in both profile and rule frontmatter — should only appear once
        expect(server_names.count('teams')).to eq(1)
        # All unique servers should be present
        expect(server_names).to include('teams', 'playwright', 'atlassian')
      end
    end

    context 'when rule has mcp_servers but no profile-level mcp_servers' do
      before do
        profiles_content = {
          'test_no_profile_mcp' => {
            'description' => 'Test profile without profile-level MCP',
            'files' => ['rules/with_mcp.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'creates .mcp.json with only rule-level MCP servers' do
        cli.invoke(:squash, ['test_no_profile_mcp'])

        mcp_json = JSON.parse(File.read('.mcp.json'))
        expect(mcp_json['mcpServers']).to have_key('playwright')
        expect(mcp_json['mcpServers']).to have_key('teams')
      end
    end

    context 'with keep_frontmatter option' do
      before do
        profiles_content = {
          'test_keep_fm' => {
            'description' => 'Test with keep_frontmatter',
            'files' => ['rules/with_mcp.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'strips mcp_servers even when keep_frontmatter is enabled' do
        cli.invoke(:squash, ['test_keep_fm'], front_matter: true)

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        # mcp_servers should be stripped even when keeping other frontmatter
        expect(content).not_to include('mcp_servers:')
        # But description should be kept (it's not metadata)
        expect(content).to include('description:')
      end
    end
  end

  describe 'mcpServers in agent frontmatter' do
    let(:mcp_config_file) { File.join(Dir.home, '.config', 'ruly', 'mcp.json') }
    let(:mcp_config_backup) { File.exist?(mcp_config_file) ? File.read(mcp_config_file) : nil }

    before do
      FileUtils.mkdir_p(File.join(test_dir, 'rules'))

      # Create a rule file with mcp_servers in frontmatter
      File.write(File.join(test_dir, 'rules', 'agent_rule_with_mcp.md'), <<~MD)
        ---
        description: Agent rule with MCP servers
        mcp_servers:
          - Ref
        ---
        # Agent Rule With MCP

        This rule needs Ref MCP server.
      MD

      # Create a rule file without mcp_servers
      File.write(File.join(test_dir, 'rules', 'agent_rule_plain.md'), <<~MD)
        ---
        description: Plain agent rule
        ---
        # Plain Agent Rule

        No MCP servers here.
      MD

      # Create MCP config file
      mcp_config_dir = File.join(Dir.home, '.config', 'ruly')
      FileUtils.mkdir_p(mcp_config_dir)
      # Trigger let to capture backup before overwriting
      mcp_config_backup

      File.write(mcp_config_file, JSON.generate({
        'Ref' => {'type' => 'http', 'url' => 'https://api.ref.tools/mcp'},
        'atlassian' => {'type' => 'sse', 'url' => 'https://mcp.atlassian.com/v1/sse'},
        'playwright' => {'command' => 'playwright-mcp', 'type' => 'stdio'},
        'teams' => {'command' => 'teams-mcp', 'type' => 'stdio'}
      }))

      allow(cli).to receive_messages(gem_root: test_dir,
                                     profiles_file: File.join(test_dir, 'profiles.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    after do
      # Restore MCP config
      File.write(mcp_config_file, mcp_config_backup) if mcp_config_backup
    end

    context 'when subagent profile has mcp_servers and rule files also have mcp_servers' do
      before do
        profiles_content = {
          'parent_profile' => {
            'description' => 'Parent profile with subagent',
            'files' => ['rules/agent_rule_plain.md'],
            'subagents' => [
              {'name' => 'worker', 'profile' => 'worker-profile'}
            ]
          },
          'worker-profile' => {
            'description' => 'Worker profile with MCP',
            'files' => ['rules/agent_rule_with_mcp.md', 'rules/agent_rule_plain.md'],
            'mcp_servers' => ['playwright']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'includes mcpServers in agent frontmatter from both profile and rule-file sources' do
        cli.invoke(:squash, ['parent_profile'])

        agent_content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
        # Extract frontmatter
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        expect(frontmatter_match).not_to be_nil

        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter['mcpServers']).to be_an(Array)
        expect(frontmatter['mcpServers']).to include('playwright')
        expect(frontmatter['mcpServers']).to include('Ref')
      end

      it 'does not include MCP servers section in the agent body' do
        cli.invoke(:squash, ['parent_profile'])

        agent_content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
        # The old markdown body section should not be present
        expect(agent_content).not_to include('## MCP Servers')
        expect(agent_content).not_to include('This subagent has access to the following MCP servers:')
      end
    end

    context 'when subagent profile has no mcp_servers and rule files have none' do
      before do
        profiles_content = {
          'parent_profile' => {
            'description' => 'Parent profile with subagent',
            'files' => ['rules/agent_rule_plain.md'],
            'subagents' => [
              {'name' => 'worker', 'profile' => 'worker-profile'}
            ]
          },
          'worker-profile' => {
            'description' => 'Worker profile without MCP',
            'files' => ['rules/agent_rule_plain.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'omits mcpServers from agent frontmatter when there are no servers' do
        cli.invoke(:squash, ['parent_profile'])

        agent_content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        expect(frontmatter_match).not_to be_nil

        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter).not_to have_key('mcpServers')
      end
    end

    context 'when only profile-level mcp_servers are configured' do
      before do
        profiles_content = {
          'parent_profile' => {
            'description' => 'Parent profile with subagent',
            'files' => ['rules/agent_rule_plain.md'],
            'subagents' => [
              {'name' => 'worker', 'profile' => 'worker-profile'}
            ]
          },
          'worker-profile' => {
            'description' => 'Worker profile with MCP',
            'files' => ['rules/agent_rule_plain.md'],
            'mcp_servers' => ['teams']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'includes only profile-level mcpServers in agent frontmatter' do
        cli.invoke(:squash, ['parent_profile'])

        agent_content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter['mcpServers']).to eq(['teams'])
      end
    end

    context 'when mcp_servers overlap between profile and rule files' do
      before do
        # Create a rule file that also declares playwright (overlapping with profile)
        File.write(File.join(test_dir, 'rules', 'agent_rule_overlap.md'), <<~MD)
          ---
          description: Agent rule with overlapping MCP
          mcp_servers:
            - playwright
            - Ref
          ---
          # Overlapping MCP Rule
        MD

        profiles_content = {
          'parent_profile' => {
            'description' => 'Parent profile with subagent',
            'files' => ['rules/agent_rule_plain.md'],
            'subagents' => [
              {'name' => 'worker', 'profile' => 'worker-profile'}
            ]
          },
          'worker-profile' => {
            'description' => 'Worker profile with MCP',
            'files' => ['rules/agent_rule_overlap.md'],
            'mcp_servers' => ['playwright']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_profiles).and_return(profiles_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'deduplicates mcpServers in agent frontmatter' do
        cli.invoke(:squash, ['parent_profile'])

        agent_content = File.read('.claude/agents/worker.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter['mcpServers'].count('playwright')).to eq(1)
        expect(frontmatter['mcpServers']).to include('playwright', 'Ref')
      end
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
