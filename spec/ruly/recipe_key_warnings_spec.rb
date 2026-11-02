# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe Ruly::Services::RecipeLoader do
  describe '.recipe_key_warnings' do
    it 'returns nothing for a recipe using only known keys' do
      recipe = {'files' => [], 'model' => 'haiku', 'omit_command_prefix' => ['x']}
      expect(described_class.recipe_key_warnings('demo', recipe)).to eq([])
    end

    it 'returns nothing for an Array agent recipe' do
      expect(described_class.recipe_key_warnings('demo', ['a.md'])).to eq([])
    end

    it 'flags a removed key with the release that removed it' do
      warnings = described_class.recipe_key_warnings('demo', {'tier' => 'claude_max'})
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("Recipe 'demo': 'tier' was removed in ruly 0.2.0 and is ignored")
    end

    it 'flags an unknown key' do
      warnings = described_class.recipe_key_warnings('core-debugger', {'omitCommandPrefix' => 'workaxle'})
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("unknown key 'omitCommandPrefix' is ignored")
    end

    it 'never includes key values in the messages' do
      recipe = {'omitCommandPrefix' => 'workaxle', 'tier' => 'claude_max'}
      warnings = described_class.recipe_key_warnings('demo', recipe)
      expect(warnings.size).to eq(2)
      expect(warnings.join("\n")).not_to include('claude_max', 'workaxle')
    end
  end

  describe '.config_key_warnings' do
    it 'flags a top-level tier key by file and key name only' do
      warnings = described_class.config_key_warnings('/tmp/recipes.yml', {'remotes' => [], 'tier' => 'claude_max'})
      expect(warnings).to eq(["\u26A0\uFE0F  /tmp/recipes.yml: 'tier' was removed in ruly 0.2.0 and is ignored"])
    end

    it 'returns nothing for known top-level keys or a non-Hash config' do
      expect(described_class.config_key_warnings('x', {'overrides' => {}, 'recipes' => {}, 'remotes' => []})).to eq([])
      expect(described_class.config_key_warnings('x', [])).to eq([])
    end
  end

  describe 'top-level config key warnings' do
    let(:dir) { Dir.mktmpdir }
    let(:user_file) { File.join(dir, 'recipes.yml') }

    before do
      File.write(user_file, "tier: claude_max\nrecipes:\n  demo:\n    files: []\n")
    end

    after do
      described_class.instance_variable_set(:@config_warnings, nil)
      FileUtils.rm_rf(dir)
    end

    it 'records the warning when loading recipes' do
      described_class.load_all_recipes(project_recipes_file: File.join(dir, '.recipes.yml'),
                                       remotes_dir: File.join(dir, 'remotes'), user_recipes_file: user_file)
      expect(described_class.config_warnings).to eq(
        ["\u26A0\uFE0F  #{user_file}: 'tier' was removed in ruly 0.2.0 and is ignored"]
      )
    end

    it 'warns once per run from the CLI without echoing the value' do
      cli = Ruly::CLI.new
      allow(cli).to receive(:recipes_file).and_return(user_file)
      allow(described_class).to receive(:project_recipes_file).and_return(File.join(dir, '.recipes.yml'))
      allow(Ruly::Services::RemoteSync).to receive(:remotes_dir).and_return(File.join(dir, 'remotes'))

      expect do
        2.times { expect(cli.send(:load_all_recipes)).to have_key('demo') }
      end.to output(
        satisfy { |err| err.scan("'tier' was removed in ruly 0.2.0").size == 1 && !err.include?('claude_max') }
      ).to_stderr
    end
  end

  describe 'Ruly::CLI#load_sources key warnings' do
    let(:cli) { Ruly::CLI.new }
    let(:recipe) { {'description' => 'Demo', 'files' => [], 'tier' => 'claude_max'} }

    before do
      allow(cli).to receive(:load_all_recipes).and_return({'demo' => recipe})
      allow(described_class).to receive(:load_recipe_sources).and_return([[], recipe])
    end

    it 'warns once per recipe on stderr and keeps loading' do
      expect do
        2.times { expect(cli.send(:load_sources, 'demo')).to eq([[], recipe]) }
      end.to output(
        satisfy { |err| err.scan("Recipe 'demo': 'tier' was removed in ruly 0.2.0").size == 1 }
      ).to_stderr
    end

    it 'does not echo key values' do
      expect { cli.send(:load_sources, 'demo') }.not_to output(/claude_max/).to_stderr
    end
  end
end
