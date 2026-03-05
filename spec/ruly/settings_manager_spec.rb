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
    context 'when profile has hooks' do
      let(:profile_config) do
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
        described_class.write_settings(profile_config)

        expect(File.exist?('.claude/settings.local.json')).to be true
        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings).to have_key('hooks')
        expect(settings['hooks']).to have_key('WorktreeCreate')
        expect(settings['hooks']['WorktreeCreate'].first['hooks'].first['command'])
          .to eq('.claude/scripts/worktree-create.sh')
      end
    end

    context 'when profile has no hooks' do
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
        profile_config = {
          'hooks' => {
            'WorktreeCreate' => [
              {'hooks' => [{'type' => 'command', 'command' => 'echo hi'}]}
            ]
          }
        }

        described_class.write_settings(profile_config)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['enableAllProjectMcpServers']).to be true
        expect(settings['hooks']).to have_key('WorktreeCreate')
      end
    end

    context 'when target_dir is specified' do
      let(:profile_config) do
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

        described_class.write_settings(profile_config, target_dir: target)

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

        described_class.write_settings(profile_config, target_dir: target)

        settings = JSON.parse(File.read(File.join(target, '.claude', 'settings.local.json')))
        expect(settings['permissions']['allow']).to eq(['Bash(*)'])
        expect(settings['hooks']).to have_key('WorktreeCreate')
      end
    end

    context 'with multiple hook types' do
      it 'writes all hook types' do
        profile_config = {
          'hooks' => {
            'WorktreeCreate' => [
              {'hooks' => [{'type' => 'command', 'command' => 'create.sh'}]}
            ],
            'WorktreeRemove' => [
              {'hooks' => [{'type' => 'command', 'command' => 'remove.sh'}]}
            ]
          }
        }

        described_class.write_settings(profile_config)

        settings = JSON.parse(File.read('.claude/settings.local.json'))
        expect(settings['hooks'].keys).to contain_exactly('WorktreeCreate', 'WorktreeRemove')
      end
    end
  end
end
