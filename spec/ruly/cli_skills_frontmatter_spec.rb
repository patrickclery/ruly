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

  describe 'skills: frontmatter resolution' do
    before do
      # Create rules directory with a skill file
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'core', 'skills'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'shared'))

      # Create a skill file in a /skills/ directory
      File.write(File.join(test_dir, 'rules', 'core', 'skills', 'deploy.md'), <<~MD)
        ---
        description: Deploy to production skill
        ---
        # Deploy to Production

        Steps to deploy safely.
      MD

      # Create another skill file
      File.write(File.join(test_dir, 'rules', 'core', 'skills', 'rollback.md'), <<~MD)
        ---
        description: Rollback deployment skill
        ---
        # Rollback Deployment

        Steps to rollback safely.
      MD

      # Create a rule file that references skills via frontmatter
      File.write(File.join(test_dir, 'rules', 'core', 'deployment.md'), <<~MD)
        ---
        description: Deployment workflow
        skills:
          - ./skills/deploy.md
          - ./skills/rollback.md
        ---
        # Deployment Workflow

        Follow the deployment process.
      MD

      # Create a rule file without skills
      File.write(File.join(test_dir, 'rules', 'core', 'basics.md'), <<~MD)
        ---
        description: Basic rules
        ---
        # Basic Rules

        Some basic content.
      MD

      # Create a non-skill file (not in /skills/ directory)
      File.write(File.join(test_dir, 'rules', 'shared', 'helpers.md'), <<~MD)
        ---
        description: Helper utilities
        ---
        # Helpers

        Shared helper content.
      MD

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when a rule file has skills: frontmatter' do
      before do
        recipes_content = {
          'test_recipe' => {
            'description' => 'Test recipe with skill references',
            'files' => ['rules/core/deployment.md', 'rules/core/basics.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'generates skill files to .claude/skills/' do
        cli.invoke(:squash, ['test_recipe'])

        expect(File.exist?('.claude/skills/deploy/SKILL.md')).to be(true)
        expect(File.exist?('.claude/skills/rollback/SKILL.md')).to be(true)
      end

      it 'preserves skill file content' do
        cli.invoke(:squash, ['test_recipe'])

        deploy_content = File.read('.claude/skills/deploy/SKILL.md', encoding: 'UTF-8')
        expect(deploy_content).to include('Deploy to Production')
        expect(deploy_content).to include('Steps to deploy safely')

        rollback_content = File.read('.claude/skills/rollback/SKILL.md', encoding: 'UTF-8')
        expect(rollback_content).to include('Rollback Deployment')
        expect(rollback_content).to include('Steps to rollback safely')
      end

      it 'strips skills: from squashed output' do
        cli.invoke(:squash, ['test_recipe'])

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(content).not_to include('skills:')
        expect(content).not_to include('- ./skills/deploy.md')
        expect(content).not_to include('- ./skills/rollback.md')
        # But the rule content should still be there
        expect(content).to include('Deployment Workflow')
      end

      it 'does not include skill content in the main squashed output' do
        cli.invoke(:squash, ['test_recipe'])

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        # Skill content should be in .claude/skills/, not in CLAUDE.local.md
        expect(content).not_to include('Steps to deploy safely')
        expect(content).not_to include('Steps to rollback safely')
      end
    end

    context 'when skills: references a non-existent file' do
      before do
        # Create a rule file that references a skill that does not exist
        File.write(File.join(test_dir, 'rules', 'core', 'bad_skill_ref.md'), <<~MD)
          ---
          description: Rule with bad skill reference
          skills:
            - ./skills/nonexistent.md
          ---
          # Bad Skill Reference

          This references a skill that does not exist.
        MD

        recipes_content = {
          'test_bad_ref' => {
            'description' => 'Test recipe with bad skill reference',
            'files' => ['rules/core/bad_skill_ref.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises an error for non-existent skill files' do
        expect { cli.invoke(:squash, ['test_bad_ref']) }.to raise_error(
          Ruly::Error, /skill file not found.*nonexistent/i
        )
      end
    end

    context 'when skills: references a file not in a /skills/ directory' do
      before do
        File.write(File.join(test_dir, 'rules', 'core', 'bad_skill_path.md'), <<~MD)
          ---
          description: Rule referencing non-skill path
          skills:
            - ../shared/helpers.md
          ---
          # Bad Skill Path

          This references a file that is not in a skills directory.
        MD

        recipes_content = {
          'test_bad_path' => {
            'description' => 'Test recipe with non-skill path',
            'files' => ['rules/core/bad_skill_path.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises an error for files not in a /skills/ directory' do
        expect { cli.invoke(:squash, ['test_bad_path']) }.to raise_error(
          Ruly::Error, /must be in a \/skills\/ directory/i
        )
      end
    end

    context 'with keep_frontmatter option' do
      before do
        recipes_content = {
          'test_keep_fm' => {
            'description' => 'Test with keep_frontmatter',
            'files' => ['rules/core/deployment.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'strips skills: even when keep_frontmatter is enabled' do
        cli.invoke(:squash, ['test_keep_fm'], front_matter: true)

        content = File.read('CLAUDE.local.md', encoding: 'UTF-8')
        expect(content).not_to include('skills:')
        # But description should be kept (it's not metadata)
        expect(content).to include('description:')
      end
    end
  end

  describe 'skills: in agent frontmatter' do
    before do
      # Create rules directory with skill files
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'agent', 'skills'))
      FileUtils.mkdir_p(File.join(test_dir, 'rules', 'parent'))

      # Create skill files
      File.write(File.join(test_dir, 'rules', 'agent', 'skills', 'context-downloader-jira.md'), <<~MD)
        ---
        description: Downloads Jira context
        ---
        # Context Downloader Jira

        Fetches Jira ticket details.
      MD

      File.write(File.join(test_dir, 'rules', 'agent', 'skills', 'context-downloader-github.md'), <<~MD)
        ---
        description: Downloads GitHub PR context
        ---
        # Context Downloader GitHub

        Fetches GitHub PR details.
      MD

      # Create a rule file that references skills via frontmatter
      File.write(File.join(test_dir, 'rules', 'agent', 'fetcher.md'), <<~MD)
        ---
        description: Context fetching rules
        skills:
          - ./skills/context-downloader-jira.md
          - ./skills/context-downloader-github.md
        ---
        # Context Fetching

        Use the skills to fetch context.
      MD

      # Create a plain rule file (no skills)
      File.write(File.join(test_dir, 'rules', 'agent', 'basics.md'), <<~MD)
        ---
        description: Basic agent rules
        ---
        # Basic Agent Rules

        Some basic agent content.
      MD

      # Create a parent rule file
      File.write(File.join(test_dir, 'rules', 'parent', 'main.md'), <<~MD)
        ---
        description: Parent recipe rules
        ---
        # Parent Rules

        Parent recipe content.
      MD

      allow(cli).to receive_messages(gem_root: test_dir,
                                     recipes_file: File.join(test_dir, 'recipes.yml'),
                                     rules_dir: File.join(test_dir, 'rules'))
    end

    context 'when subagent rule files have skills: frontmatter' do
      before do
        recipes_content = {
          'parent_recipe' => {
            'description' => 'Parent recipe with subagent',
            'files' => ['rules/parent/main.md'],
            'subagents' => [
              { 'name' => 'context_grabber', 'recipe' => 'grabber-recipe' }
            ]
          },
          'grabber-recipe' => {
            'description' => 'Orchestrates context fetching',
            'files' => ['rules/agent/fetcher.md', 'rules/agent/basics.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'includes skills: in agent frontmatter' do
        cli.invoke(:squash, ['parent_recipe'])

        agent_content = File.read('.claude/agents/context_grabber.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        expect(frontmatter_match).not_to be_nil

        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter['skills']).to be_an(Array)
        expect(frontmatter['skills']).to include('context-downloader-jira')
        expect(frontmatter['skills']).to include('context-downloader-github')
      end

      it 'generates .claude/skills/ files alongside the agent' do
        cli.invoke(:squash, ['parent_recipe'])

        expect(File.exist?('.claude/skills/context-downloader-jira/SKILL.md')).to be(true)
        expect(File.exist?('.claude/skills/context-downloader-github/SKILL.md')).to be(true)

        jira_content = File.read('.claude/skills/context-downloader-jira/SKILL.md', encoding: 'UTF-8')
        expect(jira_content).to include('Context Downloader Jira')
      end

      it 'places skills: before mcpServers: in frontmatter' do
        cli.invoke(:squash, ['parent_recipe'])

        agent_content = File.read('.claude/agents/context_grabber.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        raw_frontmatter = frontmatter_match[1]

        # skills should appear before mcpServers (if both exist) or before permissionMode
        skills_pos = raw_frontmatter.index('skills:')
        permission_pos = raw_frontmatter.index('permissionMode:')
        expect(skills_pos).not_to be_nil
        expect(skills_pos).to be < permission_pos
      end
    end

    context 'when subagent rule files have no skills: frontmatter' do
      before do
        recipes_content = {
          'parent_recipe' => {
            'description' => 'Parent recipe with subagent',
            'files' => ['rules/parent/main.md'],
            'subagents' => [
              { 'name' => 'plain_worker', 'recipe' => 'plain-recipe' }
            ]
          },
          'plain-recipe' => {
            'description' => 'Plain worker recipe',
            'files' => ['rules/agent/basics.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'omits skills: from agent frontmatter when there are no skills' do
        cli.invoke(:squash, ['parent_recipe'])

        agent_content = File.read('.claude/agents/plain_worker.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        expect(frontmatter_match).not_to be_nil

        frontmatter = YAML.safe_load(frontmatter_match[1])
        expect(frontmatter).not_to have_key('skills')
      end
    end

    context 'when subagent has both skills and mcp_servers' do
      before do
        # Create a rule file with both skills and mcp_servers
        File.write(File.join(test_dir, 'rules', 'agent', 'full.md'), <<~MD)
          ---
          description: Full agent rules
          skills:
            - ./skills/context-downloader-jira.md
          mcp_servers:
            - teams
          ---
          # Full Agent Rules

          Agent with skills and MCP.
        MD

        # Create MCP config file
        mcp_config_dir = File.join(Dir.home, '.config', 'ruly')
        FileUtils.mkdir_p(mcp_config_dir)
        @mcp_config_file = File.join(mcp_config_dir, 'mcp.json')
        @mcp_config_backup = nil
        if File.exist?(@mcp_config_file)
          @mcp_config_backup = File.read(@mcp_config_file)
        end

        File.write(@mcp_config_file, JSON.generate({
          'teams' => {'type' => 'stdio', 'command' => 'teams-mcp'}
        }))

        recipes_content = {
          'parent_recipe' => {
            'description' => 'Parent recipe with subagent',
            'files' => ['rules/parent/main.md'],
            'subagents' => [
              { 'name' => 'full_agent', 'recipe' => 'full-recipe' }
            ]
          },
          'full-recipe' => {
            'description' => 'Full recipe with skills and MCP',
            'files' => ['rules/agent/full.md']
          }
        }

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:load_all_recipes).and_return(recipes_content)
        # rubocop:enable RSpec/AnyInstance
      end

      after do
        if @mcp_config_backup
          File.write(@mcp_config_file, @mcp_config_backup)
        end
      end

      it 'includes both skills: and mcpServers: in agent frontmatter' do
        cli.invoke(:squash, ['parent_recipe'])

        agent_content = File.read('.claude/agents/full_agent.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        frontmatter = YAML.safe_load(frontmatter_match[1])

        expect(frontmatter['skills']).to include('context-downloader-jira')
        expect(frontmatter['mcpServers']).to include('teams')
      end

      it 'places skills: before mcpServers: in frontmatter' do
        cli.invoke(:squash, ['parent_recipe'])

        agent_content = File.read('.claude/agents/full_agent.md', encoding: 'UTF-8')
        frontmatter_match = agent_content.match(/\A---\n(.*?)\n---/m)
        raw_frontmatter = frontmatter_match[1]

        skills_pos = raw_frontmatter.index('skills:')
        mcp_pos = raw_frontmatter.index('mcpServers:')
        expect(skills_pos).to be < mcp_pos
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
