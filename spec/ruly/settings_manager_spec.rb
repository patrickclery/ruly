# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'ruly/services/settings_manager'

RSpec.describe Ruly::Services::SettingsManager do
  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  describe '.write_settings' do
    context 'when recipe has hooks' do
      let(:recipe_config) do
        {
          'hooks' => {
            'WorktreeCreate' => [
              {
                'hooks' => [
                  {
                    'type' => 'command',
                    'command' => '.claude/scripts/worktree-create.sh',
                    'timeout' => 120
                  }
                ]
              }
            ]
          }
        }
      end

      it 'creates .claude/settings.local.json with hooks' do
        described_class.write_settings(recipe_config)

        expect(File.exist?('.claude/settings.local.json')).to be true
        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings).to have_key('hooks')
        expect(settings['hooks']).to have_key('WorktreeCreate')
        expect(settings['hooks']['WorktreeCreate'].first['hooks'].first['command'])
          .to eq('.claude/scripts/worktree-create.sh')
      end
    end

    context 'when recipe has model' do
      it 'writes model to settings.local.json' do
        described_class.write_settings({ 'model' => 'haiku' })

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['model']).to eq('haiku')
      end

      it 'writes both model and hooks' do
        recipe_config = {
          'model' => 'sonnet',
          'hooks' => {
            'WorktreeCreate' => [
              { 'hooks' => [{ 'type' => 'command', 'command' => 'echo hi' }] }
            ]
          }
        }

        described_class.write_settings(recipe_config)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['model']).to eq('sonnet')
        expect(settings['hooks']).to have_key('WorktreeCreate')
      end
    end

    context 'when recipe has no hooks or model' do
      it 'does not create settings.local.json' do
        described_class.write_settings({})
        expect(File.exist?('.claude/settings.local.json')).to be false
      end

      it 'does not create settings.local.json for nil config' do
        described_class.write_settings(nil)
        expect(File.exist?('.claude/settings.local.json')).to be false
      end
    end

    context 'when settings.local.json already exists' do
      before do
        FileUtils.mkdir_p('.claude')
        File.write('.claude/settings.local.json', JSON.pretty_generate(
          'enableAllProjectMcpServers' => true
        ))
      end

      it 'merges hooks into existing settings' do
        recipe_config = {
          'hooks' => {
            'WorktreeCreate' => [
              {'hooks' => [{'type' => 'command', 'command' => 'echo hi'}]}
            ]
          }
        }

        described_class.write_settings(recipe_config)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['enableAllProjectMcpServers']).to be true
        expect(settings['hooks']).to have_key('WorktreeCreate')
      end
    end

    context 'when target_dir is specified' do
      let(:recipe_config) do
        {
          'hooks' => {
            'WorktreeCreate' => [
              {
                'hooks' => [
                  { 'type' => 'command', 'command' => '.claude/scripts/worktree-create.sh', 'timeout' => 120 }
                ]
              }
            ]
          }
        }
      end

      it 'writes settings.local.json into the target directory' do
        target = File.join(Dir.pwd, 'submodule-a')
        FileUtils.mkdir_p(target)

        described_class.write_settings(recipe_config, target_dir: target)

        settings_path = File.join(target, '.claude', 'settings.local.json')
        expect(File.exist?(settings_path)).to be true
        settings = JSON.parse(File.read(settings_path))
        expect(settings['hooks']['WorktreeCreate']).to be_a(Array)
      end

      it 'merges with existing settings in target directory' do
        target = File.join(Dir.pwd, 'submodule-b')
        FileUtils.mkdir_p(File.join(target, '.claude'))
        File.write(File.join(target, '.claude', 'settings.local.json'),
                   JSON.pretty_generate('permissions' => { 'allow' => ['Bash(*)'] }))

        described_class.write_settings(recipe_config, target_dir: target)

        settings = JSON.parse(File.read(File.join(target, '.claude', 'settings.local.json')))
        expect(settings['permissions']['allow']).to eq(['Bash(*)'])
        expect(settings['hooks']).to have_key('WorktreeCreate')
      end
    end

    context 'when recipe has isolate: true' do
      it 'populates claudeMdExcludes with parent CLAUDE.md files' do
        # Create a nested directory hierarchy with CLAUDE files in ancestors
        grandparent = Dir.pwd
        parent = File.join(grandparent, 'projects')
        project = File.join(parent, 'myapp')

        FileUtils.mkdir_p(project)

        # Place CLAUDE.md and CLAUDE.local.md in ancestor directories
        File.write(File.join(grandparent, 'CLAUDE.md'), '# grandparent rules')
        File.write(File.join(grandparent, 'CLAUDE.local.md'), '# grandparent local')
        File.write(File.join(parent, 'CLAUDE.md'), '# parent rules')

        recipe_config = { 'isolate' => true }

        described_class.write_settings(recipe_config, target_dir: project)

        settings_path = File.join(project, '.claude', 'settings.local.json')
        expect(File.exist?(settings_path)).to be true
        settings = JSON.parse(File.read(settings_path))
        excludes = settings['claudeMdExcludes']
        expect(excludes).to be_a(Array)
        expect(excludes).to include(File.join(grandparent, 'CLAUDE.md'))
        expect(excludes).to include(File.join(grandparent, 'CLAUDE.local.md'))
        expect(excludes).to include(File.join(parent, 'CLAUDE.md'))
      end

      it 'does not include CLAUDE files from the project directory itself' do
        grandparent = Dir.pwd
        parent = File.join(grandparent, 'projects')
        project = File.join(parent, 'myapp')
        FileUtils.mkdir_p(project)

        # Place CLAUDE.md in the project dir AND a parent dir
        File.write(File.join(project, 'CLAUDE.md'), '# project rules')
        File.write(File.join(grandparent, 'CLAUDE.md'), '# grandparent rules')

        recipe_config = { 'isolate' => true }

        described_class.write_settings(recipe_config, target_dir: project)

        settings_path = File.join(project, '.claude', 'settings.local.json')
        settings = JSON.parse(File.read(settings_path))
        excludes = settings['claudeMdExcludes']
        expect(excludes).to be_a(Array)
        # The project's own CLAUDE.md should NOT be excluded
        expect(excludes).not_to include(File.join(project, 'CLAUDE.md'))
        # But the grandparent's CLAUDE.md SHOULD be excluded
        expect(excludes).to include(File.join(grandparent, 'CLAUDE.md'))
      end

      it 'merges claudeMdExcludes with existing settings' do
        project = Dir.pwd
        parent = File.dirname(project)

        # Create a CLAUDE.md in parent (the mktmpdir parent, e.g. /tmp)
        parent_claude = File.join(parent, 'CLAUDE.md')
        had_parent_claude = File.exist?(parent_claude)
        File.write(parent_claude, '# parent') unless had_parent_claude

        FileUtils.mkdir_p('.claude')
        File.write('.claude/settings.local.json', JSON.pretty_generate(
          'enableAllProjectMcpServers' => true
        ))

        recipe_config = { 'isolate' => true }

        described_class.write_settings(recipe_config, target_dir: project)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['enableAllProjectMcpServers']).to be true
        expect(settings).to have_key('claudeMdExcludes')
      ensure
        File.delete(parent_claude) if parent_claude && !had_parent_claude && File.exist?(parent_claude)
      end

      it 'combines isolate with hooks and model' do
        grandparent = Dir.pwd
        parent = File.join(grandparent, 'projects')
        project = File.join(parent, 'myapp')
        FileUtils.mkdir_p(project)

        File.write(File.join(grandparent, 'CLAUDE.md'), '# grandparent')

        recipe_config = {
          'isolate' => true,
          'model' => 'opus',
          'hooks' => {
            'WorktreeCreate' => [
              { 'hooks' => [{ 'type' => 'command', 'command' => 'echo hi' }] }
            ]
          }
        }

        described_class.write_settings(recipe_config, target_dir: project)

        settings_path = File.join(project, '.claude', 'settings.local.json')
        settings = JSON.parse(File.read(settings_path))
        expect(settings['model']).to eq('opus')
        expect(settings['hooks']).to have_key('WorktreeCreate')
        expect(settings['claudeMdExcludes']).to include(File.join(grandparent, 'CLAUDE.md'))
      end
    end

    context 'with multiple hook types' do
      it 'writes all hook types' do
        recipe_config = {
          'hooks' => {
            'WorktreeCreate' => [
              {'hooks' => [{'type' => 'command', 'command' => 'create.sh'}]}
            ],
            'WorktreeRemove' => [
              {'hooks' => [{'type' => 'command', 'command' => 'remove.sh'}]}
            ]
          }
        }

        described_class.write_settings(recipe_config)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['hooks'].keys).to contain_exactly('WorktreeCreate', 'WorktreeRemove')
      end
    end
  end

  describe '.propagate_hooks_to_subdirs' do
    let(:hooks) do
      {
        'WorktreeCreate' => [
          { 'hooks' => [{ 'type' => 'command', 'command' => '.claude/scripts/worktree-create.sh', 'timeout' => 120 }] }
        ]
      }
    end

    let(:recipe_config) do
      {
        'hooks' => hooks,
        'subagents' => [
          { 'name' => 'core_engineer', 'recipe' => 'core-engineer', 'cwd' => 'workaxle-core' },
          { 'name' => 'core_debugger', 'recipe' => 'core-debugger', 'cwd' => 'workaxle-core' },
          { 'name' => 'frontend_engineer', 'recipe' => 'frontend-engineer', 'cwd' => 'workaxle-desktop' },
          { 'name' => 'comms_jira', 'recipe' => 'comms-jira' }
        ]
      }
    end

    it 'writes settings.local.json into each unique cwd directory' do
      FileUtils.mkdir_p('workaxle-core')
      FileUtils.mkdir_p('workaxle-desktop')

      described_class.propagate_hooks_to_subdirs(recipe_config)

      %w[workaxle-core workaxle-desktop].each do |subdir|
        settings_path = File.join(subdir, '.claude', 'settings.local.json')
        expect(File.exist?(settings_path)).to be true
        settings = JSON.parse(File.read(settings_path))
        expect(settings['hooks']).to eq(hooks)
      end
    end

    it 'skips subagents without cwd' do
      FileUtils.mkdir_p('workaxle-core')
      FileUtils.mkdir_p('workaxle-desktop')

      described_class.propagate_hooks_to_subdirs(recipe_config)

      expect(Dir.glob('*/.claude/settings.local.json').sort)
        .to eq(%w[workaxle-core/.claude/settings.local.json workaxle-desktop/.claude/settings.local.json])
    end

    it 'does nothing when recipe has no hooks' do
      config = { 'subagents' => [{ 'name' => 'x', 'recipe' => 'y', 'cwd' => 'sub' }] }
      FileUtils.mkdir_p('sub')

      described_class.propagate_hooks_to_subdirs(config)

      expect(File.exist?('sub/.claude/settings.local.json')).to be false
    end

    it 'does nothing when no subagents have cwd' do
      config = {
        'hooks' => hooks,
        'subagents' => [{ 'name' => 'x', 'recipe' => 'y' }]
      }

      described_class.propagate_hooks_to_subdirs(config)

      expect(Dir.glob('*/.claude/settings.local.json')).to be_empty
    end

    it 'copies script files into each cwd directory' do
      FileUtils.mkdir_p('workaxle-core')
      FileUtils.mkdir_p('.claude/scripts')
      File.write('.claude/scripts/worktree-create.sh', "#!/bin/bash\necho hi")
      File.chmod(0o755, '.claude/scripts/worktree-create.sh')

      described_class.propagate_hooks_to_subdirs(recipe_config, script_files: ['.claude/scripts/worktree-create.sh'])

      target_script = 'workaxle-core/.claude/scripts/worktree-create.sh'
      expect(File.exist?(target_script)).to be true
      expect(File.executable?(target_script)).to be true
    end
  end
end
